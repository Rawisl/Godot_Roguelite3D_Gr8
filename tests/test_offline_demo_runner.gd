extends Node

const RUN_SCENE := "res://main.tscn"
const MENU_SCENE := "res://ui/screens/main_menu.tscn"
const END_SCENE := "res://ui/screens/run_end.tscn"
const LEADERBOARD_SCENE := "res://ui/screens/leaderboard.tscn"
const SHOP_SCENE := "res://ui/screens/meta_shop.tscn"
const SHOP_ITEM := preload("res://data/config/meta_shop/fort_hp.tres")
const REMAINING_PRESTIGE := 3

var _repository: LocalSaveRepository
var _keep_for_reload := false


func _ready() -> void:
	GameConfig.online_enabled = false
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	var online := "--unreachable-backend" in args
	var verify_reload := "--verify-reload" in args
	var run_id := ""
	for argument in args:
		if argument.begins_with("--run-id="):
			run_id = argument.trim_prefix("--run-id=")
	_keep_for_reload = not run_id.is_empty() and not verify_reload
	if run_id.is_empty() and not verify_reload:
		run_id = "run_" + Crypto.new().generate_random_bytes(12).hex_encode()
	if not run_id.is_valid_identifier():
		_finish(false, "Use --run-id with a fresh identifier for a run and its reload")
		return
	var mode := "unreachable" if online else "disabled"
	var repository := LocalSaveRepository.new("user://offline_demo_%s_%s.json" % [mode, run_id])
	if verify_reload != repository.has_data() or (not verify_reload and not _profile_files(repository).is_empty()):
		_finish(false, "The requested profile is missing for reload or already exists for a new run")
		return
	_repository = repository
	GameConfig.online_enabled = online
	GameConfig.backend_url = "https://127.0.0.1:1"
	GameConfig.backend_public_key = "offline-demo-test"
	SaveManager.set_repository(repository)
	if SaveManager.load_save() != OK:
		_finish(false, "The dedicated profile could not be loaded")
		return
	if verify_reload:
		_finish(_total_runs() == 1 and _shop_purchase_saved()
			and bool(SaveManager.get_section(SaveManager.FLAGS)["tutorial_done"])
			and not bool(SaveManager.get_section(SaveManager.RUN_FLAG)["run_in_progress"]),
			"A new process loads the completed run, tutorial and shop purchase")
		return

	reparent(get_tree().root)
	GameState.change_state(GameState.AppState.MAIN_MENU)
	if not await _wait_for_scene(MENU_SCENE):
		_finish(false, "MainMenu did not open")
		return

	var leaderboard := get_tree().current_scene.get_node("%Leaderboard") as Button
	var account := get_tree().current_scene.get_node("%Account") as Button
	if leaderboard.visible != online or account.visible != online or AuthService.is_signed_in():
		_finish(false, "MainMenu did not show the expected guest controls")
		return
	if online:
		leaderboard.pressed.emit()
		if not await _wait_for_scene(LEADERBOARD_SCENE):
			_finish(false, "Leaderboard did not open")
			return
		var leaderboard_failure := await _check_leaderboard_error()
		if not leaderboard_failure.is_empty():
			_finish(false, leaderboard_failure)
			return
		_press("%Back")
		if not await _wait_for_scene(MENU_SCENE):
			_finish(false, "MainMenu did not reopen after the leaderboard error")
			return

	_press("%Play")
	if not await _wait_for_scene(RUN_SCENE):
		_finish(false, "RunLoading did not open the production run")
		return

	var tutorial := get_tree().current_scene.find_child("TutorialService", true, false) as TutorialService
	if tutorial == null:
		_finish(false, "The production run has no tutorial service")
		return
	tutorial.skip()
	var waves := get_tree().get_first_node_in_group(&"wave_manager") as WaveManager
	if waves == null:
		_finish(false, "The production run has no WaveManager")
		return
	EventBus.wave_start_requested.emit()
	if waves.wave_state != Enums.WaveState.COMBAT:
		_finish(false, "The guest could not start combat")
		return
	for _step in 30 * Engine.physics_ticks_per_second:
		if waves.spawn_queue.is_empty():
			break
		await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not waves.spawn_queue.is_empty():
		_finish(false, "The first offline wave did not finish spawning")
		return
	if waves.enemies_alive == 0:
		_finish(false, "No enemy spawned during the offline run")
		return

	GameState.abandon_run()
	if not await _wait_for_scene(END_SCENE):
		_finish(false, "RunEnd did not open")
		return
	if _total_runs() != 1 or not SaveManager.is_run_end_saved(GameState.last_run_summary):
		_finish(false, "RunEnd did not save exactly one completed run")
		return
	_finish(await _purchase_upgrade(), "The guest can play, save and purchase a local upgrade")


func _check_leaderboard_error() -> String:
	var screen := get_tree().current_scene
	var deadline := Time.get_ticks_msec() + 15000
	while screen.is_loading() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if screen.is_loading():
		return "Timed out after 15 seconds waiting for the leaderboard to finish loading"
	var status := screen.get_node("%Status") as Label
	var retry := screen.get_node("%Retry") as Button
	if not status.is_visible_in_tree() or status.text != tr(&"lbd.offline") or not retry.is_visible_in_tree():
		return "Leaderboard did not display the connection error and retry button"
	return ""


func _purchase_upgrade() -> bool:
	SaveManager.get_section(SaveManager.PROFILE)["prestige_balance"] = SHOP_ITEM.get_next_cost(0) + REMAINING_PRESTIGE
	if SaveManager.save_now() != OK:
		return false
	_press("%MetaShop")
	if not await _wait_for_scene(SHOP_SCENE):
		return false
	var row := get_tree().current_scene.get_node("%Rows").get_child(0) as ShopRow
	var buy := row.get_node("%BuyButton") as Button
	if buy.disabled:
		return false
	buy.pressed.emit()
	return _shop_purchase_saved()


func _shop_purchase_saved() -> bool:
	return int(SaveManager.get_section(SaveManager.META)["levels"].get(String(SHOP_ITEM.id), 0)) == 1 \
		and int(SaveManager.get_section(SaveManager.PROFILE)["prestige_balance"]) == REMAINING_PRESTIGE


func _press(path: NodePath) -> void:
	var button := get_tree().current_scene.get_node(path) as Button
	button.pressed.emit()


func _wait_for_scene(path: String) -> bool:
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == path and not ScreenManager.is_fading():
			return true
	return false


func _total_runs() -> int:
	return int(SaveManager.get_section(SaveManager.PROFILE)["stats"]["total_runs"])


func _finish(ok: bool, message: String) -> void:
	if _repository != null and (not _keep_for_reload or not ok):
		for path in _profile_files(_repository):
			if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
				ok = false
				message = "Could not remove runner profile file: " + path
	print("OFFLINE DEMO %s: %s" % ["PASS" if ok else "FAIL", message])
	var tree := get_tree()
	queue_free()
	tree.quit.call_deferred(0 if ok else 1)


func _profile_files(repository: LocalSaveRepository) -> Array[String]:
	var files: Array[String] = []
	for source: SaveRepository.Source in [SaveRepository.Source.MAIN, SaveRepository.Source.TEMP, SaveRepository.Source.BACKUP]:
		for path in [repository.path_of(source), repository.corrupt_path(source)]:
			if FileAccess.file_exists(path):
				files.append(path)
	return files
