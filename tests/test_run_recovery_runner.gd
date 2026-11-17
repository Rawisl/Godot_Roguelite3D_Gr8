extends Node

## Automated test runner verifying how a run left in progress is settled at the start of the game:
## - prestige comes from the last wave SUMMARY, without the unfinished wave's buffer
## - best waves are updated, the flag is cleared and saved, the notice is shown once
## - nothing is settled when the save cannot be written or no run was in progress
## - no run_ended is sent, so the score is never submitted, and the next run starts with full repairs
## Writes only under user://test_save_recovery/, the real save is put back afterwards.

const TEST_DIR := "user://test_save_recovery"
const TEST_PATH := "user://test_save_recovery/endlesswar_save.json"

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0

var _repo: LocalSaveRepository
var _recovered: Array[int] = []
var _ended: int = 0
var _balances: Array[int] = []
var _failed_reasons: Array[StringName] = []
var _completed: int = 0


## Writes fail while fail_writes is on, to see how the recovery copes with a full disk.
class FailingRepository extends LocalSaveRepository:
	var fail_writes := false

	func save_data(envelope: Dictionary) -> Error:
		if fail_writes:
			return ERR_FILE_CANT_WRITE
		return super(envelope)


## Auth that records the requests instead of sending them.
class FakeAuth:
	extends "res://systems/auth/auth_service.gd"
	var calls: Array[Dictionary] = []

	func is_signed_in() -> bool:
		return not user_id.is_empty()

	func rest(method: int, path: String, body: Variant = null, _signed_in: bool = true, _prefer: String = "") -> Dictionary:
		calls.append({"method": method, "path": path, "body": body})
		return {"ok": true, "data": [body]}


func _ready() -> void:
	print("\n=======================================================")
	print("          AUTOMATED RUN RECOVERY RUNNER TEST           ")
	print("=======================================================")

	var real_repository := SaveManager.repository
	var real_data := SaveManager.data.duplicate(true)
	var real_can_write := SaveManager.can_write
	var real_loaded_from := SaveManager.loaded_from
	var real_load_failure := SaveManager.load_failure
	var real_checked := SaveManager._recovery_checked
	EventBus.run_recovered.connect(_on_run_recovered)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.prestige_balance_changed.connect(_on_balance_changed)
	EventBus.save_failed.connect(_on_save_failed)
	EventBus.save_completed.connect(_on_save_completed)

	test_power_loss_wave7()
	test_hazard_prep_wave7()
	test_recovery_emits_no_run_ended()
	test_recovery_formula_start_mult()
	test_recovery_skipped_when_write_blocked()
	test_corrupt_main_uses_backup()
	test_all_copies_corrupt()
	await test_run_recovered_signal_once()
	await test_no_flag_no_dialog()
	test_zero_waves_cleared()
	test_best_by_start_keeps_max()
	test_late_start_recovery()
	test_write_error_keeps_memory()
	await test_recovered_run_not_submitted()
	await test_next_run_full_repair()
	test_load_save_does_not_recover()

	EventBus.run_recovered.disconnect(_on_run_recovered)
	EventBus.run_ended.disconnect(_on_run_ended)
	EventBus.prestige_balance_changed.disconnect(_on_balance_changed)
	EventBus.save_failed.disconnect(_on_save_failed)
	EventBus.save_completed.disconnect(_on_save_completed)
	_clear_notices()
	_clear_test_dir()
	EventBus.state_changed.emit(&"PREP")
	SaveManager.repository = real_repository
	SaveManager.data = real_data
	SaveManager.can_write = real_can_write
	SaveManager.loaded_from = real_loaded_from
	SaveManager.load_failure = real_load_failure
	SaveManager._recovery_checked = real_checked

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")

	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


# ---------------------------------------------------------------- cases

func test_power_loss_wave7() -> void:
	print("\n[CASE] test_power_loss_wave7")
	_begin()
	_seed_profile(100, 4, {"1": 4})
	SaveManager.record_run_start(1, 1.0)
	SaveManager.record_wave_summary(6, 40, 1, 1.0)
	EventBus.state_changed.emit(&"COMBAT")
	SaveManager.get_section(SaveManager.PROFILE)["prestige_balance"] = 999
	SaveManager.save()
	_power_cut()
	var gain := SaveManager.recover_interrupted_run()
	var profile := _disk(&"profile")
	var stats: Dictionary = profile["stats"]
	assert_true(gain == _gain(40, 1.0), "gain comes from the summary of wave 6")
	assert_true(int(profile["prestige_balance"]) == 100 + _gain(40, 1.0), "balance on disk has the gain, not the held-back write")
	assert_true(int(profile["max_wave_cleared"]) == 6, "max_wave_cleared is wave 6")
	assert_true(int(profile["best_by_start"]["1"]) == 6, "best for start wave 1 is wave 6")
	assert_true(_disk(&"run_flag")["run_in_progress"] == false, "run flag cleared on disk")
	assert_true(int(stats["total_runs"]) == 2 and int(stats["total_kills"]) == 50 and int(stats["bosses_defeated"]) == 1, "stats not counted")
	assert_true(_recovered == [gain], "run_recovered sent once with the gain")


func test_hazard_prep_wave7() -> void:
	print("\n[CASE] test_hazard_prep_wave7")
	_begin()
	SaveManager.record_run_start(1, 1.0)
	SaveManager.record_wave_summary(6, 40, 1, 1.0)
	EventBus.state_changed.emit(&"PREP")
	EventBus.state_changed.emit(&"HAZARD_TRIAL")
	SaveManager.mark_tutorial_done()
	_power_cut()
	var gain := SaveManager.recover_interrupted_run()
	var profile := _disk(&"profile")
	assert_true(gain == _gain(40, 1.0), "gain from the summary of wave 6")
	assert_true(int(profile["max_wave_cleared"]) == 6 and int(profile["best_by_start"]["1"]) == 6, "best waves from wave 6")
	assert_true(_disk(&"run_flag")["run_in_progress"] == false, "run flag cleared")
	assert_true(_disk(&"flags")["tutorial_done"] == true, "write made in the prep room is kept")


func test_recovery_emits_no_run_ended() -> void:
	print("\n[CASE] test_recovery_emits_no_run_ended")
	_begin()
	SaveManager.record_run_start(1, 1.0)
	SaveManager.record_wave_summary(6, 40, 1, 1.0)
	_power_cut()
	var state_before := GameState.current
	var summary_before := GameState.last_run_summary.duplicate(true)
	SaveManager.recover_interrupted_run()
	assert_true(_ended == 0, "run_ended not sent")
	assert_true(GameState.current == state_before, "app state unchanged")
	assert_true(GameState.last_run_summary == summary_before, "last run summary unchanged")
	assert_true(not SaveManager.is_run_end_saved({}), "no run end marked as saved")


func test_recovery_formula_start_mult() -> void:
	print("\n[CASE] test_recovery_formula_start_mult")
	_begin()
	SaveManager.record_run_start(1, 0.6)
	SaveManager.record_wave_summary(6, 50, 1, 0.6)
	_power_cut()
	var gain := SaveManager.recover_interrupted_run()
	assert_true(gain == PrestigeCalc.prestige_gain(50, 0, 0.6), "gain matches PrestigeCalc without buffer")
	assert_true(gain == WaveRewardTable.floor_gold(50.0 * GameConfig.conversion_rate * 0.6), "gain is pending x rate x start multiplier")
	_begin()
	SaveManager.record_run_start(1, 0.7)
	SaveManager.record_wave_summary(6, 300, 1, 0.7)
	_power_cut()
	gain = SaveManager.recover_interrupted_run()
	assert_true(gain == WaveRewardTable.floor_gold(300.0 * GameConfig.conversion_rate * 0.7), "float rounding does not lose one prestige")


func test_recovery_skipped_when_write_blocked() -> void:
	print("\n[CASE] test_recovery_skipped_when_write_blocked")
	_begin()
	var newer := _data_with_run(true, 1, 1.0, 6, 40)
	_write_envelope(SaveRepository.Source.MAIN, newer, SaveManager.SAVE_VERSION + 1)
	SaveManager.load_save()
	var text := _file_text()
	_reset_counters()
	assert_true(SaveManager.recover_interrupted_run() == SaveManager.NO_RECOVERY, "newer save: nothing settled")
	assert_true(_file_text() == text, "newer save: file untouched")
	assert_true(_recovered.is_empty() and _balances.is_empty(), "newer save: no signals")

	_begin()
	SaveManager.record_run_start(1, 1.0)
	SaveManager.record_wave_summary(6, 40, 1, 1.0)
	_power_cut()
	SaveManager.can_write = false
	text = _file_text()
	var balance := int(SaveManager.get_section(SaveManager.PROFILE)["prestige_balance"])
	assert_true(SaveManager.recover_interrupted_run() == SaveManager.NO_RECOVERY, "blocked write: nothing settled")
	assert_true(SaveManager.get_section(SaveManager.RUN_FLAG)["run_in_progress"] == true, "blocked write: flag kept")
	assert_true(int(SaveManager.get_section(SaveManager.PROFILE)["prestige_balance"]) == balance, "blocked write: balance unchanged")
	assert_true(_file_text() == text, "blocked write: file untouched")
	assert_true(_recovered.is_empty(), "blocked write: no notice")
	assert_true(_failed_reasons.is_empty(), "blocked write: no save_failed")


func test_corrupt_main_uses_backup() -> void:
	print("\n[CASE] test_corrupt_main_uses_backup")
	_begin()
	var backup_data := _data_with_run(true, 1, 1.0, 5, 30)
	backup_data["profile"]["max_wave_cleared"] = 3
	_write_envelope(SaveRepository.Source.BACKUP, backup_data)
	_write_text(SaveRepository.Source.MAIN, "{not json")
	SaveManager.load_save()
	assert_true(SaveManager.loaded_from == &"BACKUP", "loaded from the backup")
	assert_true(SaveManager.recover_interrupted_run() == _gain(30, 1.0), "settled from the backup's run flag")
	var envelope := _repo.load_data()
	assert_true(not envelope.is_empty() and SaveChecksum.matches(envelope), "main file readable again")
	var data: Dictionary = envelope.get("data", {})
	assert_true(data.get("run_flag", {}).get("run_in_progress") == false, "flag cleared in the main file")
	assert_true(int(data.get("profile", {}).get("max_wave_cleared", 0)) == 5, "max_wave_cleared from the backup's run")


func test_all_copies_corrupt() -> void:
	print("\n[CASE] test_all_copies_corrupt")
	_begin()
	_write_text(SaveRepository.Source.MAIN, "{not json")
	_write_text(SaveRepository.Source.BACKUP, "{not json either")
	SaveManager.load_save()
	var main_text := _file_text()
	var backup_text := FileAccess.get_file_as_string(_repo.path_of(SaveRepository.Source.BACKUP))
	_reset_counters()
	assert_true(SaveManager.load_failure == SaveManager.REASON_CORRUPT, "load failure is CORRUPT")
	assert_true(SaveManager.recover_interrupted_run() == SaveManager.NO_RECOVERY, "nothing settled")
	assert_true(_file_text() == main_text, "main file untouched")
	assert_true(FileAccess.get_file_as_string(_repo.path_of(SaveRepository.Source.BACKUP)) == backup_text, "backup untouched")
	assert_true(_recovered.is_empty(), "no notice")


func test_run_recovered_signal_once() -> void:
	print("\n[CASE] test_run_recovered_signal_once")
	_begin()
	SaveManager.record_run_start(1, 1.0)
	SaveManager.record_wave_summary(6, 40, 1, 1.0)
	_power_cut()
	SaveManager.recover_interrupted_run()
	await _frames(2)
	var notices := _recovered_notices()
	assert_true(_recovered.size() == 1, "first call: run_recovered sent once")
	assert_true(notices.size() == 1, "first call: one notice queued or shown")
	assert_true(notices.size() == 1 and notices[0].get("_params")["value"] == _gain(40, 1.0), "notice shows the gain")
	var revision := int(_repo.load_data()["revision"])
	var balance_signals := _balances.size()
	assert_true(SaveManager.recover_interrupted_run() == SaveManager.NO_RECOVERY, "second call: nothing settled")
	await _frames(2)
	assert_true(_recovered.size() == 1, "second call: no second run_recovered")
	assert_true(_balances.size() == balance_signals, "second call: no balance signal")
	assert_true(int(_repo.load_data()["revision"]) == revision, "second call: nothing written")
	assert_true(_recovered_notices().size() == 1, "second call: still one notice")
	_clear_notices()


func test_no_flag_no_dialog() -> void:
	print("\n[CASE] test_no_flag_no_dialog")
	_begin()
	_seed_profile(100, 4, {"1": 4})
	var text := _file_text()
	_reset_counters()
	assert_true(SaveManager.recover_interrupted_run() == SaveManager.NO_RECOVERY, "nothing settled")
	assert_true(_file_text() == text, "file untouched")
	assert_true(_recovered.is_empty() and _balances.is_empty() and _completed == 0, "no signals, no write")
	await _frames(1)
	assert_true(_recovered_notices().is_empty(), "no notice")


func test_zero_waves_cleared() -> void:
	print("\n[CASE] test_zero_waves_cleared")
	_begin()
	_seed_profile(100, 4, {"1": 4})
	SaveManager.record_run_start(1, 1.0)
	_power_cut()
	var gain := SaveManager.recover_interrupted_run()
	var profile := _disk(&"profile")
	assert_true(gain == 0, "gain is 0")
	assert_true(_recovered == [0], "run_recovered sent with 0")
	assert_true(_balances == [100], "balance signal carries the unchanged balance")
	assert_true(int(profile["prestige_balance"]) == 100, "balance unchanged on disk")
	assert_true(int(profile["max_wave_cleared"]) == 4 and int(profile["best_by_start"]["1"]) == 4, "best waves unchanged")
	assert_true(_disk(&"run_flag")["run_in_progress"] == false, "flag cleared")
	assert_true(_recovered_notices().size() == 1 and _recovered_notices()[0].get("_params")["value"] == 0, "notice shows 0")
	_clear_notices()


func test_best_by_start_keeps_max() -> void:
	print("\n[CASE] test_best_by_start_keeps_max")
	_begin()
	_seed_profile(10, 9, {"1": 9})
	SaveManager.record_run_start(1, 1.0)
	SaveManager.record_wave_summary(6, 40, 1, 1.0)
	_power_cut()
	SaveManager.recover_interrupted_run()
	var profile := _disk(&"profile")
	assert_true(int(profile["max_wave_cleared"]) == 9, "max_wave_cleared keeps the better value")
	assert_true(int(profile["best_by_start"]["1"]) == 9, "best for start wave 1 keeps the better value")
	assert_true(int(profile["prestige_balance"]) == 10 + _gain(40, 1.0), "gain added to the balance")


func test_late_start_recovery() -> void:
	print("\n[CASE] test_late_start_recovery")
	_begin()
	_seed_profile(0, 12, {"1": 12})
	SaveManager.record_run_start(11, 0.6)
	SaveManager.record_wave_summary(13, 40, 11, 0.6)
	_power_cut()
	var gain := SaveManager.recover_interrupted_run()
	var profile := _disk(&"profile")
	assert_true(gain == PrestigeCalc.prestige_gain(40, 0, 0.6), "gain uses the recorded start multiplier")
	assert_true(int(profile["best_by_start"]["11"]) == 13, "best for start wave 11 recorded")
	assert_true(int(profile["best_by_start"]["1"]) == 12, "best for start wave 1 untouched")
	assert_true(int(profile["max_wave_cleared"]) == 13, "max_wave_cleared updated")


func test_write_error_keeps_memory() -> void:
	print("\n[CASE] test_write_error_keeps_memory")
	var failing := FailingRepository.new(TEST_PATH)
	_begin(failing)
	var before := int(SaveManager.get_section(SaveManager.PROFILE)["prestige_balance"])
	SaveManager.record_run_start(1, 1.0)
	SaveManager.record_wave_summary(6, 40, 1, 1.0)
	_power_cut()
	failing.fail_writes = true
	var text := _file_text()
	var gain := SaveManager.recover_interrupted_run()
	var profile := SaveManager.get_section(SaveManager.PROFILE)
	assert_true(gain == _gain(40, 1.0), "gain still returned")
	assert_true(_failed_reasons == [SaveManager.REASON_WRITE_ERROR], "save_failed(WRITE_ERROR) sent once")
	assert_true(_recovered == [gain], "run_recovered still sent")
	assert_true(SaveManager.get_section(SaveManager.RUN_FLAG)["run_in_progress"] == false, "flag cleared in memory")
	assert_true(int(profile["prestige_balance"]) == before + gain, "balance updated in memory")
	assert_true(_file_text() == text, "file untouched")
	failing.fail_writes = false
	SaveManager.save()
	assert_true(_disk(&"run_flag")["run_in_progress"] == false, "retry writes the cleared flag")
	assert_true(int(_disk(&"profile")["prestige_balance"]) == before + gain, "retry writes the gain once")


func test_recovered_run_not_submitted() -> void:
	print("\n[CASE] test_recovered_run_not_submitted")
	_begin()
	var auth := FakeAuth.new()
	add_child(auth)
	auth.user_id = "account-a"
	auth._on_score_run_started()
	SaveManager.record_run_start(1, 1.0)
	SaveManager.record_wave_summary(6, 40, 1, 1.0)
	_power_cut()
	SaveManager.recover_interrupted_run()
	await _frames(3)
	assert_true(auth._recovered_run == true, "auth treats the run as recovered")
	assert_true(auth.calls.is_empty(), "no request sent")
	assert_true(auth._pending_scores.is_empty(), "no score queued")
	assert_true(_ended == 0, "run_ended not sent")
	auth.queue_free()
	_clear_notices()


func test_next_run_full_repair() -> void:
	print("\n[CASE] test_next_run_full_repair")
	_begin()
	var repair := EmergencyRepair.new()
	add_child(repair)
	await _frames(1)
	repair.charges = 0
	SaveManager.record_run_start(1, 1.0)
	SaveManager.record_wave_summary(6, 40, 1, 1.0)
	_power_cut()
	SaveManager.recover_interrupted_run()
	SaveManager.record_run_start(1, 1.0)
	EventBus.run_started.emit()
	assert_true(repair.charges == GameConfig.emg_repair_charges_start, "next run starts with the starting charges")
	assert_true(repair.charges == GameConfig.emg_repair_charges_max, "starting charges are the maximum")
	var disk_keys: Array = _disk(&"run_flag").keys()
	var default_keys: Array = SaveManager.DEFAULT_DATA["run_flag"].keys()
	disk_keys.sort()
	default_keys.sort()
	assert_true(disk_keys == default_keys, "save keeps no repair state in the run flag")
	assert_true(_disk(&"run_flag")["run_in_progress"] == true and int(_disk(&"run_flag")["waves_cleared"]) == 0, "new run flagged from scratch")
	repair.free()
	_clear_notices()


func test_load_save_does_not_recover() -> void:
	print("\n[CASE] test_load_save_does_not_recover")
	_begin()
	SaveManager.record_run_start(1, 1.0)
	SaveManager.record_wave_summary(6, 40, 1, 1.0)
	var text := _file_text()
	_reset_counters()
	SaveManager.load_save()
	SaveManager.load_save()
	assert_true(_file_text() == text, "file untouched")
	assert_true(_recovered.is_empty(), "no notice")
	assert_true(SaveManager.get_section(SaveManager.RUN_FLAG)["run_in_progress"] == true, "flag still set")


# ---------------------------------------------------------------- helpers

## Fresh save in the test folder, nothing held back, recovery not yet checked.
func _begin(repo: LocalSaveRepository = null) -> void:
	_clear_test_dir()
	EventBus.state_changed.emit(&"PREP")
	_repo = repo if repo != null else LocalSaveRepository.new(TEST_PATH)
	SaveManager.set_repository(_repo)
	SaveManager.load_save()
	SaveManager.can_write = true
	SaveManager._recovery_checked = false
	_clear_notices()
	_reset_counters()
	# Same signal the game sends when a run begins; lets the next run be recorded again.
	GameState.app_state_changed.emit(GameState.AppState.RUN, GameState.AppState.RUN_LOADING)


## Power cut and restart: the held-back write is lost, combat is over, the counters start again.
func _power_cut() -> void:
	SaveManager.load_save()
	EventBus.state_changed.emit(&"PREP")
	SaveManager._recovery_checked = false
	_reset_counters()


func _reset_counters() -> void:
	_recovered.clear()
	_ended = 0
	_balances.clear()
	_failed_reasons.clear()
	_completed = 0


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _disk(section: StringName) -> Dictionary:
	var envelope := LocalSaveRepository.new(TEST_PATH).load_data()
	var stored: Dictionary = envelope.get("data", {})
	return stored.get(String(section), {})


func _file_text() -> String:
	return FileAccess.get_file_as_string(TEST_PATH)


func _recovered_notices() -> Array:
	var found: Array = []
	var candidates: Array = ScreenManager._pending_notices.duplicate()
	candidates.append_array(ScreenManager._dialog_holder.get_children())
	for node: Node in candidates:
		if node.get("_title_key") == &"dialog.run_recovered.title":
			found.append(node)
	return found


func _clear_notices() -> void:
	for notice in ScreenManager._pending_notices:
		notice.queue_free()
	ScreenManager._pending_notices.clear()
	ScreenManager.close_all_dialogs()


func _seed_profile(balance: int, max_wave: int, best: Dictionary) -> void:
	var profile := SaveManager.get_section(SaveManager.PROFILE)
	profile["prestige_balance"] = balance
	profile["max_wave_cleared"] = max_wave
	profile["best_by_start"] = best.duplicate()
	profile["stats"] = {"total_runs": 2, "total_kills": 50, "bosses_defeated": 1}
	SaveManager.save_now()


func _gain(pending: int, mult: float) -> int:
	return PrestigeCalc.prestige_gain(pending, 0, mult)


func _data_with_run(in_progress: bool, start_wave: int, start_mult: float, waves_cleared: int, pending: int) -> Dictionary:
	var data: Dictionary = SaveManager.DEFAULT_DATA.duplicate(true)
	data["run_flag"] = {
		"run_in_progress": in_progress,
		"start_wave": start_wave,
		"start_mult": start_mult,
		"waves_cleared": waves_cleared,
		"prestige_pending": pending,
	}
	return data


func _write_envelope(source: SaveRepository.Source, data: Dictionary, version: int = SaveManager.SAVE_VERSION) -> void:
	var envelope := {"save_version": version, "data": data, "checksum": SaveChecksum.compute(data)}
	_write_text(source, JSON.stringify(envelope, "\t"))


func _write_text(source: SaveRepository.Source, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var file := FileAccess.open(_repo.path_of(source), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _clear_test_dir() -> void:
	var local := LocalSaveRepository.new(TEST_PATH)
	for file_path in [TEST_PATH, local.path_of(SaveRepository.Source.TEMP),
			local.path_of(SaveRepository.Source.BACKUP), local.corrupt_path(),
			local.corrupt_path(SaveRepository.Source.TEMP), local.corrupt_path(SaveRepository.Source.BACKUP)]:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
	if DirAccess.dir_exists_absolute(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR)


func _on_run_recovered(prestige_gain: int) -> void:
	_recovered.append(prestige_gain)


func _on_run_ended(_end_type: StringName, _summary: Dictionary) -> void:
	_ended += 1


func _on_balance_changed(value: int) -> void:
	_balances.append(value)


func _on_save_failed(reason: StringName) -> void:
	_failed_reasons.append(reason)


func _on_save_completed() -> void:
	_completed += 1
