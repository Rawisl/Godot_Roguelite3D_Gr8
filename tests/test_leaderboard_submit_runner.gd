extends Node

class FakeAuth:
	extends "res://systems/auth/auth_service.gd"
	var calls: Array[Dictionary] = []
	var offline := false
	var hold := false
	var released := false
	var responses: Array[Dictionary] = []
	var local_save_complete := false
	var use_real_saves := false

	func _is_score_saved(summary: Dictionary) -> bool:
		return super._is_score_saved(summary) if use_real_saves else local_save_complete

	func is_signed_in() -> bool:
		return not user_id.is_empty()

	func rest(method: int, path: String, body: Variant = null, _signed_in: bool = true, _prefer: String = "") -> Dictionary:
		calls.append({"method": method, "path": path, "body": body.duplicate(true) if body is Dictionary else body})
		while hold and not released:
			await get_tree().process_frame
		if not responses.is_empty():
			return responses.pop_front()
		if offline:
			return {"ok": false, "error": ERR_OFFLINE, "status": 0}
		if path.contains("leaderboard_top"):
			return {"ok": true, "data": [{"rank": 1, "display_name": "tester", "waves_cleared": 10, "run_elapsed": 149.0}]}
		if path.contains("leaderboard_my_rank"):
			return {"ok": true, "data": [{"rank": 51, "display_name": "own", "waves_cleared": 1, "run_elapsed": 15.0}]}
		return {"ok": true, "data": [body]}

class MemorySaveRepository:
	extends SaveRepository
	var stored: Dictionary = {}

	func load_data() -> Dictionary:
		last_error = OK if not stored.is_empty() else ERR_FILE_NOT_FOUND
		return stored.duplicate(true)

	func save_data(envelope: Dictionary) -> Error:
		stored = envelope.duplicate(true)
		return OK

var _failed := 0
var _passed := 0
var _auth: FakeAuth


func _ready() -> void:
	_auth = FakeAuth.new()
	add_child(_auth)
	_auth.user_id = "account-a"
	await _run()
	_auth.queue_free()
	print("[leaderboard-submit] %d passed, %d FAILED" % [_passed, _failed])
	get_tree().quit(1 if _failed else 0)


func _run() -> void:
	var summary := {"start_wave": 1, "waves_cleared": 10, "run_elapsed": 149.0, "run_seed": 42}
	_queue_run_end(&"ABANDONED", summary)
	_save_completed()
	await _frames()
	_check(_auth.calls.is_empty(), "startup recovery without a new run is excluded")
	for end_type in [&"FORTRESS_DESTROYED", &"COMMANDER_DIED", &"ABANDONED"]:
		_auth._on_score_run_started()
		_queue_run_end(end_type, summary)
		await _frames()
		_check(_auth.calls.is_empty(), "waits for local save: %s" % end_type)
		_save_completed()
		await _frames()
		_check(_auth.calls.size() == 1 and _auth._pending_scores.is_empty(), "submits saved run: %s" % end_type)
		_auth.calls.clear()

	_save_completed()
	_auth._on_score_run_ended(&"ABANDONED", summary)
	await _frames()
	_check(_auth.calls.size() == 1, "save inside an earlier run_ended listener is observed")
	_auth.calls.clear()
	_queue_run_end(&"ABANDONED", summary)
	await _frames()
	_check(_auth.calls.is_empty(), "failed save does not submit")
	_save_completed()
	await _frames()
	_check(_auth.calls.size() == 1, "later successful save releases the score")
	_auth.calls.clear()

	var skipped := summary.duplicate()
	skipped["start_wave"] = 5
	_queue_run_end(&"ABANDONED", skipped)
	_auth._on_score_run_recovered(10)
	_queue_run_end(&"ABANDONED", summary)
	_auth._on_score_run_started()
	skipped = summary.duplicate()
	skipped["interrupted"] = true
	_queue_run_end(&"ABANDONED", skipped)
	_auth.user_id = ""
	_queue_run_end(&"ABANDONED", summary)
	_save_completed()
	await _frames()
	_check(_auth.calls.is_empty() and _auth._pending_scores.is_empty(), "guest, later start and interrupted runs are excluded")
	_auth.user_id = "account-a"
	_auth.offline = true
	_queue_run_end(&"ABANDONED", summary)
	_save_completed()
	await _frames()
	_check(_auth._pending_scores.size() == 1, "offline score remains queued")
	_auth.calls.clear()
	_auth.offline = false
	_auth._on_score_meta_purchased(&"FORT_HP", 1)
	await _frames()
	_check(_auth.calls.size() == 1 and _auth._pending_scores.is_empty(), "purchase retries queued score")
	_auth.calls.clear()
	_auth.offline = true
	_queue_run_end(&"ABANDONED", summary)
	_save_completed()
	await _frames()
	_auth.calls.clear()
	_auth.offline = false
	_queue_run_end(&"ABANDONED", skipped)
	await _frames()
	_check(_auth.calls.size() == 1 and _auth._pending_scores.is_empty(), "next run end retries even when that run is ineligible")
	_auth.calls.clear()
	var board := await _auth.fetch_leaderboard(500)
	_check(board["ok"] and board["own"]["rank"] == 51 and _auth.calls.size() == 2, "top and own rank use two RPC calls")
	_check(_auth.calls[0]["body"] == {"version": GameConfig.game_version, "top_n": 50}, "RPC is bounded and version filtered")
	_auth.calls.clear()
	_auth.user_id = ""
	board = await _auth.fetch_leaderboard(10)
	_check(board["ok"] and board["own"].is_empty() and _auth.calls.size() == 1, "guest reads top with one call")

	var local := {"profile": {"prestige_balance": 10}, "meta": {"levels": {}},
		"flags": {"tutorial_done": true}, "run_flag": {"run_in_progress": true}}
	var synced := AccountApi.data_for_sync(local)
	synced["profile"]["prestige_balance"] = 20
	_check(synced.size() == 3 and synced["flags"]["tutorial_done"] and not synced.has("run_flag"), "sync includes flags and excludes run state")
	_check(local["profile"]["prestige_balance"] == 10, "sync payload is detached from local data")
	await _test_account_api(local)
	await _test_submission_concurrency(summary)
	await _test_event_bus_order(summary)
	await _test_unexpected_responses(summary)
	await _test_main_run_start()


func _test_account_api(local: Dictionary) -> void:
	_auth.user_id = "account-a"
	_auth.calls.clear()
	var api := AccountApi.new(_auth)
	_auth.responses = [{"ok": true, "data": []}]
	var empty := await api.pull_save()
	_check(empty["ok"] and empty["revision"] == 0 and empty["data"].is_empty(), "absent cloud save has revision zero")
	_auth.responses = [{"ok": true, "data": []}, {"ok": true, "data": [{"revision": 1}]}]
	_auth.calls.clear()
	var pushed := await api.push_save(1, "device-a", local)
	_check(pushed["ok"] and pushed["revision"] == 1 and _auth.calls.size() == 2, "first save patches then inserts")
	_check(not _auth.calls[0]["body"].has("user_id") and _auth.calls[1]["body"]["user_id"] == "account-a", "save updates do not require ownership column permission")
	_check(_auth.calls[1]["body"]["data"] == AccountApi.data_for_sync(local), "save writes filter the cloud payload")
	_auth.responses = [{"ok": false, "status": 409, "data": {"code": "PT409"}, "error": &"HTTP_409"}]
	var stale := await api.push_save(1, "device-a", local)
	_check(not stale["ok"] and stale["conflict"], "stale revision maps to a conflict")
	_auth.responses = [{"ok": true, "data": []}, {"ok": false, "status": 409, "data": {"code": "23505"}}]
	var raced := await api.push_save(1, "device-a", local)
	_check(not raced["ok"] and raced["conflict"], "concurrent first save maps to a conflict")
	_auth.responses = [{"ok": false, "status": 0, "error": &"OFFLINE"}]
	var offline := await api.push_save(2, "device-a", local)
	_check(not offline["ok"] and not offline["conflict"] and offline["error"] == &"OFFLINE", "network failure is distinct from revision conflict")
	_auth.user_id = ""
	_auth.calls.clear()
	var guest := await api.pull_save()
	var guest_push := await api.push_save(1, "device-a", local)
	_check(not guest["ok"] and not guest_push["ok"] and _auth.calls.is_empty(), "guests cannot read or write account saves")


func _test_submission_concurrency(summary: Dictionary) -> void:
	_auth.user_id = "account-a"
	_auth.calls.clear()
	_auth.hold = true
	_auth.released = false
	_queue_run_end(&"ABANDONED", summary)
	_save_completed()
	await _frames()
	_auth._on_score_meta_purchased(&"FORT_HP", 1)
	await _frames()
	_check(_auth.calls.size() == 1, "concurrent retry triggers share one request")
	_auth._forget_memory()
	_auth.user_id = "account-b"
	_auth.released = true
	await _frames()
	_check(_auth._pending_scores.is_empty() and _auth.calls.size() == 1, "account change discards old pending scores")
	_auth.hold = false
	_auth.calls.clear()
	_queue_run_end(&"ABANDONED", summary)
	_auth.responses = [{"ok": true, "data": []}, {"ok": true, "data": [{}]}]
	_save_completed()
	await _frames()
	_check(_auth.calls.size() == 2 and _auth.calls[1]["method"] == HTTPClient.METHOD_POST, "first leaderboard score inserts after an empty update")
	_auth.calls.clear()
	_queue_run_end(&"ABANDONED", summary)
	var next := summary.duplicate()
	next["run_seed"] = 43
	_queue_run_end(&"ABANDONED", next)
	_auth.responses = [{"ok": false, "status": 400, "error": &"HTTP_400"}, {"ok": true, "data": [{}]}]
	_save_completed()
	await _frames()
	_check(_auth.calls.size() == 2 and _auth._pending_scores.is_empty(), "server rejection does not block another saved score")
	_auth._pending_scores.clear()


func _test_event_bus_order(summary: Dictionary) -> void:
	var repository := MemorySaveRepository.new()
	var original := SaveManager.repository
	SaveManager.set_repository(repository)
	SaveManager.load_save()
	SaveManager.record_run_start(1, 1.0)
	_auth.calls.clear()
	_auth.use_real_saves = true
	EventBus.run_ended.disconnect(GameState._on_run_ended)
	EventBus.run_started.emit()
	EventBus.run_ended.emit(&"ABANDONED", summary)
	_check(_auth.calls.is_empty() and not repository.stored["data"]["run_flag"]["run_in_progress"], "real EventBus saves RunEnd before starting network work")
	EventBus.save_failed.disconnect(ScreenManager._on_save_failed)
	EventBus.save_failed.emit(&"WRITE_ERROR")
	EventBus.save_failed.connect(ScreenManager._on_save_failed)
	_check(SaveManager.is_run_end_saved(summary) and _auth._pending_scores[0]["saved"], "later failure in the same frame does not revoke a saved score")
	await _frames()
	_check(_auth.calls.size() == 1 and _auth._pending_scores.is_empty(), "real nested save_completed releases the queued score")
	EventBus.run_ended.connect(GameState._on_run_ended)
	_auth.use_real_saves = false
	SaveManager.set_repository(original)
	SaveManager.load_save()


func _test_unexpected_responses(summary: Dictionary) -> void:
	_auth.user_id = "account-a"
	var api := AccountApi.new(_auth)
	for malformed in [null, {}, [null], [42], [{"revision": -1, "device_id": null, "updated_at": "now", "data": {}}],
			[{"revision": 1, "device_id": null, "updated_at": null, "data": {}}],
			[{"revision": 1, "device_id": null, "updated_at": "now", "data": []}]]:
		_auth.responses = [{"ok": true, "data": malformed}]
		var pulled := await api.pull_save()
		_check(not pulled["ok"] and pulled["error"] == AuthService.ERR_SERVER, "malformed cloud save fails without a runtime error")
	_auth.responses = [{"ok": true, "data": [{"revision": 1, "device_id": null, "updated_at": "now", "data": {}}]}]
	var nullable := await api.pull_save()
	_check(nullable["ok"] and nullable["device_id"] == "", "null device_id is normalized")
	for malformed in [null, {}]:
		_auth.calls.clear()
		_auth.responses = [{"ok": true, "data": malformed}]
		var pushed := await api.push_save(1, "device", {})
		_check(not pushed["ok"] and _auth.calls.size() == 1, "malformed update response never falls through to insert")
	_auth.responses = [{"ok": true, "data": []}, {"ok": true, "data": null}]
	var inserted := await api.push_save(1, "device", {})
	_check(not inserted["ok"], "null insert response is rejected")

	_auth._pending_scores = [{"user_id": _auth.user_id, "saved": true, "summary": {}, "row": summary}]
	_auth.calls.clear()
	_auth.responses = [{"ok": true, "data": null}]
	var invalid := await _auth.submit_score()
	_check(not invalid["ok"] and _auth.calls.size() == 1 and _auth._pending_scores.size() == 1, "malformed score response remains retryable")
	_auth._pending_scores.append({"user_id": _auth.user_id, "saved": true, "summary": {}, "row": summary})
	_auth.calls.clear()
	_auth.responses = [{"ok": false, "status": 503, "error": AuthService.ERR_SERVER}]
	var outage := await _auth.submit_score()
	_check(not outage["ok"] and _auth.calls.size() == 1 and _auth._pending_scores.size() == 2, "server outage stops the batch and retains queued scores")
	_auth._pending_scores.clear()
	var service := (load("res://systems/auth/auth_service.gd") as Script).new() as Node
	service._access_token = "test-token"
	_check(not service.is_signed_in(), "a token without user_id is not a signed-in session")
	service.free()
	var configured_top := GameConfig.lbd_top_n
	GameConfig.lbd_top_n = 7
	_auth.calls.clear()
	await _auth.fetch_leaderboard(100)
	_check(_auth.calls[0]["body"]["top_n"] == 7, "client top count follows GameConfig")
	GameConfig.lbd_top_n = configured_top


func _test_main_run_start() -> void:
	var original_scene := get_tree().current_scene
	var original_repository := SaveManager.repository
	var repository := MemorySaveRepository.new()
	SaveManager.set_repository(repository)
	SaveManager.load_save()
	_auth._recovered_run = true
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await _frames()
	var state := get_tree().get_first_node_in_group(&"run_state") as RunState
	_check(not _auth._recovered_run and repository.stored["data"]["run_flag"]["run_in_progress"], "production main emits run_started and writes the run flag")
	var revision: int = repository.stored["revision"]
	state.start_run()
	_check(repository.stored["revision"] == revision, "starting an initialized run twice is idempotent")
	scene.queue_free()
	await _frames()
	get_tree().current_scene = original_scene
	SaveManager.set_repository(original_repository)
	SaveManager.load_save()


func _queue_run_end(end_type: StringName, summary: Dictionary) -> void:
	_auth.local_save_complete = false
	_auth._on_score_run_ended(end_type, summary)


func _save_completed() -> void:
	_auth.local_save_complete = true
	_auth._on_score_save_completed()


func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[leaderboard-submit] %s: %s" % ["OK" if ok else "FAILED", label])
