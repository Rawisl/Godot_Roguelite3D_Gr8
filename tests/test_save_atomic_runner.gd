extends Node

## Automated test runner verifying:
## - save() goes through .tmp, a read-back check and a .bak copy, and stores a checksum
## - load order main -> temp -> backup, a damaged main file never replaces a good backup
## - an unreadable save is refused until start_new_save() keeps it aside as .corrupt
## - saves are held back during combat, coalesced by request_save(), and clamped on load
## Writes only under user://test_save_atomic/, the real save is put back afterwards.

const TEST_DIR := "user://test_save_atomic"
const TEST_PATH := "user://test_save_atomic/endlesswar_save.json"
## Performance target for one save.
const SAVE_BUDGET_USEC := 50000

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []

var _completed: int = 0
var _failed_reasons: Array[StringName] = []
var _loaded: int = 0
var _local: LocalSaveRepository

## Keeps the envelope in memory; fail_with makes every write fail with that error.
class MemorySaveRepository extends SaveRepository:
	var stored: Dictionary = {}
	var fail_with: Error = OK

	func has_data() -> bool:
		return not stored.is_empty()

	func load_data() -> Dictionary:
		last_error = OK if has_data() else ERR_FILE_NOT_FOUND
		return stored.duplicate(true)

	func save_data(envelope: Dictionary) -> Error:
		if fail_with != OK:
			return fail_with
		stored = envelope.duplicate(true)
		return OK

## Reads the .tmp back with a wrong checksum, as if the write got damaged on disk.
class TamperTempRepository extends LocalSaveRepository:
	func _read_envelope(file_path: String) -> Dictionary:
		var envelope := super(file_path)
		if file_path.ends_with("." + TEMP_EXTENSION) and envelope.has("checksum"):
			envelope["checksum"] = SaveChecksum.PREFIX + "0"
		return envelope

func _ready() -> void:
	print("\n=======================================================")
	print("          AUTOMATED SAVE ATOMIC RUNNER TEST            ")
	print("=======================================================")

	var real_repository := SaveManager.repository
	var real_data := SaveManager.data.duplicate(true)
	var real_can_write := SaveManager.can_write
	var real_loaded_from := SaveManager.loaded_from
	var real_load_failure := SaveManager.load_failure
	EventBus.save_completed.connect(_on_save_completed)
	EventBus.save_failed.connect(_on_save_failed)
	SaveManager.save_loaded.connect(_on_save_loaded)

	test_write_steps()
	test_checksum_written()
	test_checksum_survives_reload()
	test_load_order_main_tmp_bak()
	test_legacy_save_without_checksum()
	test_newer_version_stops_fallback()
	test_start_new_save()
	test_start_new_save_refused_when_fine()
	test_orphan_tmp_removed()
	test_temp_bad_keeps_old()
	test_write_error_keeps_memory()
	await test_request_save_coalesces()
	test_save_deferred_in_combat()
	test_save_now_in_combat()
	test_combat_flag_cleared_on_run_end()
	test_pending_flushed_on_run_end()
	test_blocked_not_queued_in_combat()
	test_clamp_values()
	test_defaults_without_file()
	test_save_under_50ms()

	EventBus.save_completed.disconnect(_on_save_completed)
	EventBus.save_failed.disconnect(_on_save_failed)
	SaveManager.save_loaded.disconnect(_on_save_loaded)
	_clear_test_dir()
	EventBus.state_changed.emit(&"PREP")
	SaveManager.repository = real_repository
	SaveManager.data = real_data
	SaveManager.can_write = real_can_write
	SaveManager.loaded_from = real_loaded_from
	SaveManager.load_failure = real_load_failure

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")

	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)

func test_write_steps() -> void:
	print("\n--- Write steps ---")
	_begin()
	_set_balance(1)
	SaveManager.save()
	_set_balance(2)
	SaveManager.save()
	assert_true(_exists(SaveRepository.Source.MAIN), "main file written")
	assert_true(_exists(SaveRepository.Source.BACKUP), "backup file written")
	assert_true(_balance_of(SaveRepository.Source.BACKUP) == 1, "backup holds the previous save")
	assert_true(_balance_of(SaveRepository.Source.MAIN) == 2, "main file holds the latest save")
	assert_true(not _exists(SaveRepository.Source.TEMP), "no temp file left")
	assert_true(_completed == 2, "save_completed emitted twice")

func test_checksum_written() -> void:
	print("\n--- Checksum written ---")
	_begin()
	SaveManager.save()
	var envelope := _read_file(SaveRepository.Source.MAIN)
	assert_true(envelope.get("checksum") is String
			and String(envelope["checksum"]).begins_with(SaveChecksum.PREFIX), "checksum has the prefix")
	assert_true(SaveChecksum.matches(envelope), "checksum matches the data on disk")
	assert_true(int(envelope.get("save_version", 0)) == SaveManager.SAVE_VERSION, "save_version written")

func test_checksum_survives_reload() -> void:
	print("\n--- Checksum survives reload ---")
	_begin()
	var profile := SaveManager.get_section(SaveManager.PROFILE)
	profile["prestige_balance"] = 9
	profile["extra_int"] = 5
	profile["extra_float"] = 0.1
	profile["extra_nested"] = {"a": {"b": 3}}
	profile["extra_list"] = [1, 2.5]
	SaveManager.save()
	_reset_counters()
	SaveManager.load_save()
	profile = SaveManager.get_section(SaveManager.PROFILE)
	assert_true(SaveManager.loaded_from == &"MAIN", "loaded from the main file")
	assert_true(_failed_reasons.is_empty(), "no save_failed after reload")
	assert_true(profile["extra_int"] == 5, "int field survives")
	assert_true(is_equal_approx(profile["extra_float"], 0.1), "float field survives")
	assert_true(profile["extra_nested"]["a"]["b"] == 3, "nested field survives")
	assert_true(profile["extra_list"].size() == 2 and is_equal_approx(profile["extra_list"][1], 2.5),
			"list field survives")
	assert_true(typeof(profile["prestige_balance"]) == TYPE_INT, "prestige_balance stays int")

func test_load_order_main_tmp_bak() -> void:
	print("\n--- Load order ---")
	# a: main broken, temp and backup good -> temp wins and becomes the main file
	_begin()
	_write_text(SaveRepository.Source.MAIN, '{"save_version": 1, "data": {')
	_write_envelope_file(SaveRepository.Source.TEMP, _data_with(7))
	_write_envelope_file(SaveRepository.Source.BACKUP, _data_with(3))
	SaveManager.load_save()
	assert_true(SaveManager.loaded_from == &"TEMP", "temp copy used when main is broken")
	assert_true(_balance() == 7, "temp value loaded")
	assert_true(not _exists(SaveRepository.Source.TEMP), "temp file gone after promotion")
	assert_true(_balance_of(SaveRepository.Source.MAIN) == 7, "temp promoted to the main file")
	assert_true(_balance_of(SaveRepository.Source.BACKUP) == 3, "backup untouched")

	# b: only the backup exists
	_begin()
	_write_envelope_file(SaveRepository.Source.BACKUP, _data_with(3))
	SaveManager.load_save()
	assert_true(SaveManager.loaded_from == &"BACKUP", "backup used when the main file is missing")
	assert_true(_balance() == 3, "backup value loaded")
	assert_true(SaveManager.can_write and _failed_reasons.is_empty(), "no failure reported")

	# c: main edited by hand (checksum no longer matches) -> backup, and the backup survives the next save
	_begin()
	_write_envelope_file(SaveRepository.Source.MAIN, _data_with(4))
	var edited := _read_file(SaveRepository.Source.MAIN)
	edited["data"]["profile"]["prestige_balance"] = 99
	_write_raw_envelope(SaveRepository.Source.MAIN, edited)
	_write_envelope_file(SaveRepository.Source.BACKUP, _data_with(3))
	SaveManager.load_save()
	assert_true(SaveManager.loaded_from == &"BACKUP", "backup used when the main checksum is wrong")
	_set_balance(8)
	SaveManager.save()
	assert_true(_balance_of(SaveRepository.Source.BACKUP) == 3, "damaged main did not replace the backup")
	var fresh := _read_file(SaveRepository.Source.MAIN)
	assert_true(SaveChecksum.matches(fresh) and _balance_of(SaveRepository.Source.MAIN) == 8,
			"new main file is valid")

	# d: every copy broken
	_begin()
	var broken := '{"save_version": 1, "data": {'
	_write_text(SaveRepository.Source.MAIN, broken)
	_write_text(SaveRepository.Source.TEMP, broken + "1")
	_write_text(SaveRepository.Source.BACKUP, broken + "2")
	var error := SaveManager.load_save()
	assert_true(error != OK, "load_save() reports an error")
	assert_true(_only_reason(SaveManager.REASON_CORRUPT), "save_failed(CORRUPT) emitted once")
	assert_true(not SaveManager.can_write, "can_write is false")
	assert_true(SaveManager.loaded_from == SaveManager.SOURCE_DEFAULTS, "loaded_from is the defaults")
	assert_true(SaveManager.load_failure == SaveManager.REASON_CORRUPT, "load_failure is CORRUPT")
	assert_true(SaveManager.data == SaveManager.DEFAULT_DATA, "runs on defaults")
	assert_true(not FileAccess.file_exists(_local.corrupt_path()), "no .corrupt file yet")
	assert_true(_text_of(SaveRepository.Source.MAIN) == broken
			and _text_of(SaveRepository.Source.TEMP) == broken + "1"
			and _text_of(SaveRepository.Source.BACKUP) == broken + "2", "all three files left as they were")

func test_legacy_save_without_checksum() -> void:
	print("\n--- Save without checksum ---")
	_begin()
	_write_envelope_file(SaveRepository.Source.MAIN, _data_with(6), false)
	SaveManager.load_save()
	assert_true(SaveManager.loaded_from == &"MAIN" and _failed_reasons.is_empty(), "accepted without failure")
	assert_true(_balance() == 6, "value loaded")
	SaveManager.save()
	assert_true(SaveChecksum.matches(_read_file(SaveRepository.Source.MAIN))
			and _read_file(SaveRepository.Source.MAIN).has("checksum"), "next save carries a checksum")

func test_newer_version_stops_fallback() -> void:
	print("\n--- Newer version stops the fallback ---")
	_begin()
	_write_envelope_file(SaveRepository.Source.MAIN, _data_with(50), true, SaveManager.SAVE_VERSION + 1)
	_write_envelope_file(SaveRepository.Source.BACKUP, _data_with(3))
	var main_text := _text_of(SaveRepository.Source.MAIN)
	SaveManager.load_save()
	assert_true(_only_reason(SaveManager.REASON_VERSION_TOO_NEW), "save_failed(VERSION_TOO_NEW) emitted once")
	assert_true(SaveManager.data == SaveManager.DEFAULT_DATA, "backup not loaded")
	assert_true(SaveManager.save() == ERR_UNAVAILABLE, "save() refuses")
	assert_true(SaveManager.start_new_save() == ERR_UNAVAILABLE, "start_new_save() refuses")
	assert_true(_text_of(SaveRepository.Source.MAIN) == main_text, "main file untouched")
	assert_true(not FileAccess.file_exists(_local.corrupt_path()), "no .corrupt file")

func test_start_new_save() -> void:
	print("\n--- Start new save ---")
	_begin()
	var broken := '{"save_version": 1, "data": {'
	_write_text(SaveRepository.Source.MAIN, broken)
	_write_text(SaveRepository.Source.TEMP, broken + "1")
	_write_text(SaveRepository.Source.BACKUP, broken + "2")
	SaveManager.load_save()
	_reset_counters()
	var error := SaveManager.start_new_save()
	assert_true(error == OK, "start_new_save() returns OK")
	assert_true(FileAccess.get_file_as_string(_local.corrupt_path()) == broken, ".corrupt holds the broken main file")
	assert_true(not _exists(SaveRepository.Source.TEMP), "no temp file left")
	assert_true(not _exists(SaveRepository.Source.BACKUP), "broken backup removed")
	assert_true(SaveChecksum.matches(_read_file(SaveRepository.Source.MAIN)), "new main file is valid")
	assert_true(SaveManager.can_write and SaveManager.load_failure == &"", "writing allowed again")
	assert_true(_loaded == 1, "save_loaded emitted once")
	assert_true(_completed == 1, "save_completed emitted once")
	SaveManager.load_save()
	assert_true(SaveManager.loaded_from == &"MAIN" and SaveManager.data == SaveManager.DEFAULT_DATA,
			"new file holds the defaults")

	# Only a broken backup, no main file: nothing is kept
	_begin()
	_write_text(SaveRepository.Source.BACKUP, broken)
	SaveManager.load_save()
	assert_true(SaveManager.start_new_save() == OK, "start_new_save() with only a backup returns OK")
	assert_true(not FileAccess.file_exists(_local.corrupt_path()), "no .corrupt without a main file")
	assert_true(not _exists(SaveRepository.Source.BACKUP), "broken backup removed")
	assert_true(SaveChecksum.matches(_read_file(SaveRepository.Source.MAIN)), "new main file is valid")

func test_start_new_save_refused_when_fine() -> void:
	print("\n--- Start new save refused ---")
	_begin()
	_set_balance(2)
	SaveManager.save()
	SaveManager.load_save()
	var text := _text_of(SaveRepository.Source.MAIN)
	assert_true(SaveManager.start_new_save() == ERR_UNAVAILABLE, "start_new_save() refuses a good save")
	assert_true(_text_of(SaveRepository.Source.MAIN) == text, "main file untouched")

func test_orphan_tmp_removed() -> void:
	print("\n--- Orphan temp file ---")
	_begin()
	_write_envelope_file(SaveRepository.Source.MAIN, _data_with(1))
	_write_envelope_file(SaveRepository.Source.TEMP, _data_with(2))
	SaveManager.load_save()
	assert_true(SaveManager.loaded_from == &"MAIN" and _balance() == 1, "main file used")
	assert_true(not _exists(SaveRepository.Source.TEMP), "leftover temp file removed")

func test_temp_bad_keeps_old() -> void:
	print("\n--- Bad temp keeps the old save ---")
	_begin()
	_set_balance(1)
	SaveManager.save()
	SaveManager.set_repository(TamperTempRepository.new(TEST_PATH))
	_reset_counters()
	_set_balance(2)
	var error := SaveManager.save()
	assert_true(error == ERR_FILE_CORRUPT, "save() fails when the temp read-back is wrong")
	assert_true(_only_reason(SaveManager.REASON_WRITE_ERROR), "save_failed(WRITE_ERROR) emitted once")
	assert_true(_balance_of(SaveRepository.Source.MAIN) == 1, "main file keeps the old value")
	assert_true(not _exists(SaveRepository.Source.TEMP), "no temp file left")
	assert_true(not _exists(SaveRepository.Source.BACKUP), "no backup made")

func test_write_error_keeps_memory() -> void:
	print("\n--- Write error keeps memory ---")
	_begin()
	var memory := MemorySaveRepository.new()
	memory.fail_with = ERR_FILE_CANT_WRITE
	SaveManager.set_repository(memory)
	_set_balance(5)
	assert_true(SaveManager.save() == ERR_FILE_CANT_WRITE, "save() returns the write error")
	assert_true(_only_reason(SaveManager.REASON_WRITE_ERROR), "save_failed(WRITE_ERROR) emitted")
	assert_true(_balance() == 5, "data still in memory")
	memory.fail_with = OK
	assert_true(SaveManager.save() == OK, "retry succeeds")
	assert_true(memory.stored.get("data", {}).get("profile", {}).get("prestige_balance") == 5, "stored has the value")

func test_request_save_coalesces() -> void:
	print("\n--- request_save coalesces ---")
	_begin()
	for value in range(1, 6):
		_set_balance(value)
		SaveManager.request_save()
	assert_true(_completed == 0, "nothing written yet")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(_completed == 1, "one write for five requests")
	assert_true(_balance_of(SaveRepository.Source.MAIN) == 5, "latest data written")

func test_save_deferred_in_combat() -> void:
	print("\n--- Save deferred in combat ---")
	for combat_state in [&"COMBAT", &"BOSS_COMBAT"]:
		_begin()
		_set_balance(1)
		SaveManager.save()
		_reset_counters()
		EventBus.state_changed.emit(combat_state)
		_set_balance(2)
		assert_true(SaveManager.save() == ERR_BUSY, "%s: save() returns ERR_BUSY" % combat_state)
		assert_true(_completed == 0 and _failed_reasons.is_empty(), "%s: nothing written, no signal" % combat_state)
		assert_true(_balance_of(SaveRepository.Source.MAIN) == 1, "%s: disk unchanged" % combat_state)
		EventBus.state_changed.emit(&"SUMMARY")
		assert_true(_completed == 1, "%s: written on leaving combat" % combat_state)
		assert_true(_balance_of(SaveRepository.Source.MAIN) == 2, "%s: disk has the new value" % combat_state)
		EventBus.state_changed.emit(&"PREP")
		assert_true(_completed == 1, "%s: not written twice" % combat_state)
	_begin()
	EventBus.state_changed.emit(&"BOSS_INTRO")
	assert_true(SaveManager.save() == OK, "BOSS_INTRO does not hold saves back")

func test_save_now_in_combat() -> void:
	print("\n--- save_now in combat ---")
	_begin()
	EventBus.state_changed.emit(&"COMBAT")
	SaveManager.save()
	assert_true(SaveManager.save_now() == OK, "save_now() writes during combat")
	assert_true(_completed == 1, "save_completed emitted once")
	EventBus.state_changed.emit(&"PREP")
	assert_true(_completed == 1, "pending write was cleared")

func test_combat_flag_cleared_on_run_end() -> void:
	print("\n--- Run end clears combat ---")
	_begin()
	EventBus.state_changed.emit(&"COMBAT")
	EventBus.run_ended.emit(&"FORTRESS_DESTROYED", {})
	_reset_counters()
	assert_true(SaveManager.save() == OK and _completed == 1, "save() writes right away after the run ended")

func test_pending_flushed_on_run_end() -> void:
	print("\n--- Run end flushes the pending save ---")
	_begin()
	EventBus.state_changed.emit(&"COMBAT")
	_set_balance(4)
	SaveManager.save()
	EventBus.run_ended.emit(&"COMMANDER_DIED", {})
	assert_true(_completed == 1, "pending write done on run end")
	assert_true(_balance_of(SaveRepository.Source.MAIN) == 4, "disk has the value")

func test_blocked_not_queued_in_combat() -> void:
	print("\n--- Blocked save not queued ---")
	_begin()
	_write_text(SaveRepository.Source.MAIN, "{")
	SaveManager.load_save()
	_reset_counters()
	EventBus.state_changed.emit(&"COMBAT")
	assert_true(SaveManager.save() == ERR_UNAVAILABLE, "save() refuses at once")
	assert_true(_only_reason(SaveManager.REASON_WRITE_BLOCKED), "save_failed(WRITE_BLOCKED) emitted at once")
	EventBus.state_changed.emit(&"PREP")
	assert_true(_failed_reasons.size() == 1, "no extra save_failed after combat")

func test_clamp_values() -> void:
	print("\n--- Clamp values ---")
	_begin()
	var damaged := {
		"profile": {"prestige_balance": -5, "max_wave_cleared": -1, "best_by_start": {"1": -3}},
		"meta": {"levels": {"FORT_HP": -2}},
		"run_flag": {"start_wave": 0, "start_mult": -1.0},
	}
	_write_envelope_file(SaveRepository.Source.MAIN, damaged)
	SaveManager.load_save()
	var profile := SaveManager.get_section(SaveManager.PROFILE)
	var run_flag := SaveManager.get_section(SaveManager.RUN_FLAG)
	assert_true(profile["prestige_balance"] == 0 and profile["max_wave_cleared"] == 0, "negative counters set to 0")
	assert_true(SaveManager.get_section(SaveManager.META)["levels"]["FORT_HP"] == 0, "negative meta level set to 0")
	assert_true(run_flag["start_wave"] == 1 and run_flag["start_mult"] == 1.0, "start_wave and start_mult reset")
	assert_true(profile["best_by_start"]["1"] == 0, "negative best_by_start set to 0")

	var bad := SaveManager.DEFAULT_DATA.duplicate(true)
	bad["profile"]["prestige_balance"] = -5
	bad["profile"]["max_wave_cleared"] = -1
	bad["profile"]["best_by_start"] = {"1": -3}
	bad["meta"]["levels"]["FORT_HP"] = -2
	bad["run_flag"]["start_wave"] = 0
	bad["run_flag"]["start_mult"] = -1.0
	var changed := SaveManager._clamp_values(bad)
	var expected := ["profile.prestige_balance", "profile.max_wave_cleared", "meta.levels.FORT_HP",
			"run_flag.start_wave", "run_flag.start_mult", "profile.best_by_start.1"]
	var all_listed := changed.size() == expected.size()
	for field_path in expected:
		all_listed = all_listed and field_path in changed
	assert_true(all_listed, "all six clamped fields reported")
	assert_true(SaveManager._clamp_values(SaveManager.DEFAULT_DATA.duplicate(true)).is_empty(),
			"valid data reports nothing")

func test_defaults_without_file() -> void:
	print("\n--- Defaults without a file ---")
	_begin()
	SaveManager.load_save()
	assert_true(SaveManager.get_section(SaveManager.FLAGS)["tutorial_done"] == false, "tutorial_done defaults to false")
	assert_true(SaveManager.get_section(SaveManager.RUN_FLAG)["start_wave"]
			== SaveManager.DEFAULT_DATA["run_flag"]["start_wave"], "start_wave defaults")
	assert_true(SaveManager.loaded_from == SaveManager.SOURCE_DEFAULTS, "loaded_from is the defaults")
	assert_true(_failed_reasons.is_empty(), "no save_failed")

func test_save_under_50ms() -> void:
	print("\n--- Save time ---")
	_begin()
	var best: Dictionary = SaveManager.get_section(SaveManager.PROFILE)["best_by_start"]
	for wave in range(1, 31):
		best[str(wave)] = wave
	SaveManager.save()
	var start := Time.get_ticks_usec()
	var error := SaveManager.save()
	var took := Time.get_ticks_usec() - start
	print("  save() with backup copy took %.2f ms" % (took / 1000.0))
	assert_true(error == OK and took < SAVE_BUDGET_USEC, "second save() under the budget")

func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		failed_names.append(test_name)
		printerr("  [FAIL] %s" % test_name)

## Clean slate: no files, local repository on the test path, defaults loaded, outside combat.
func _begin() -> void:
	_clear_test_dir()
	EventBus.state_changed.emit(&"PREP")
	_local = LocalSaveRepository.new(TEST_PATH)
	SaveManager.set_repository(_local)
	SaveManager.load_save()
	_reset_counters()

func _only_reason(reason: StringName) -> bool:
	return _failed_reasons.size() == 1 and _failed_reasons[0] == reason

func _reset_counters() -> void:
	_completed = 0
	_loaded = 0
	_failed_reasons.clear()

func _set_balance(value: int) -> void:
	SaveManager.get_section(SaveManager.PROFILE)["prestige_balance"] = value

func _balance() -> int:
	return SaveManager.get_section(SaveManager.PROFILE)["prestige_balance"]

func _data_with(balance: int) -> Dictionary:
	var result := SaveManager.DEFAULT_DATA.duplicate(true)
	result["profile"]["prestige_balance"] = balance
	return result

func _exists(source: SaveRepository.Source) -> bool:
	return FileAccess.file_exists(_local.path_of(source))

func _text_of(source: SaveRepository.Source) -> String:
	return FileAccess.get_file_as_string(_local.path_of(source))

func _read_file(source: SaveRepository.Source) -> Dictionary:
	var parsed: Variant = JSON.parse_string(_text_of(source))
	return parsed if parsed is Dictionary else {}

func _balance_of(source: SaveRepository.Source) -> int:
	return int(_read_file(source).get("data", {}).get("profile", {}).get("prestige_balance", -1))

func _write_text(source: SaveRepository.Source, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var file := FileAccess.open(_local.path_of(source), FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _write_raw_envelope(source: SaveRepository.Source, envelope: Dictionary) -> void:
	_write_text(source, JSON.stringify(envelope, "\t"))

func _write_envelope_file(source: SaveRepository.Source, data: Dictionary, with_checksum := true,
		version: int = SaveManager.SAVE_VERSION) -> void:
	var envelope := {"save_version": version, "data": data}
	if with_checksum:
		envelope["checksum"] = SaveChecksum.compute(data)
	_write_raw_envelope(source, envelope)

func _clear_test_dir() -> void:
	var local := LocalSaveRepository.new(TEST_PATH)
	for file_path in [TEST_PATH, local.path_of(SaveRepository.Source.TEMP),
			local.path_of(SaveRepository.Source.BACKUP), local.corrupt_path()]:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
	if DirAccess.dir_exists_absolute(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR)

func _on_save_completed() -> void:
	_completed += 1

func _on_save_failed(reason: StringName) -> void:
	_failed_reasons.append(reason)

func _on_save_loaded() -> void:
	_loaded += 1
