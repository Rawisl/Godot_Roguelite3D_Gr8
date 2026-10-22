extends Node

## Automated test runner verifying:
## - no save file gives default data and the game can still save
## - save() writes save.json with save_version and data, load_save() reads it back as int
## - missing fields fall back to defaults, extra fields are kept when written back
## - a newer save_version or an unreadable file is refused and never overwritten
## - swapping the repository (in-memory double) needs no change at the call site
## Writes only under user://test_save/, the real save is put back afterwards.

const TEST_DIR := "user://test_save"
const TEST_PATH := "user://test_save/save.json"

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []

var _completed: int = 0
var _failed_reasons: Array[StringName] = []

## Keeps the envelope in memory, stands in for a cloud repository.
class MemorySaveRepository extends SaveRepository:
	var stored: Dictionary = {}

	func has_data() -> bool:
		return not stored.is_empty()

	func load_data() -> Dictionary:
		last_error = OK if has_data() else ERR_FILE_NOT_FOUND
		return stored.duplicate(true)

	func save_data(envelope: Dictionary) -> Error:
		stored = envelope.duplicate(true)
		return OK

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED SAVE REPOSITORY RUNNER TEST           ")
	print("=======================================================")

	var real_repository := SaveManager.repository
	EventBus.save_completed.connect(_on_save_completed)
	EventBus.save_failed.connect(_on_save_failed)
	_clear_test_dir()

	test_no_file_gives_defaults()
	test_save_then_load_round_trip()
	test_missing_fields_use_defaults()
	test_extra_fields_are_kept()
	test_newer_version_is_not_overwritten()
	test_corrupt_file_is_not_overwritten()
	test_memory_repository_swap()

	EventBus.save_completed.disconnect(_on_save_completed)
	EventBus.save_failed.disconnect(_on_save_failed)
	_clear_test_dir()
	SaveManager.set_repository(real_repository)
	SaveManager.load_save()

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")

	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)

func test_no_file_gives_defaults() -> void:
	print("\n--- No save file ---")
	_use_local()
	var error := SaveManager.load_save()
	assert_true(error == OK, "load_save() returns OK without a file")
	assert_true(not SaveManager.repository.has_data(), "has_data() is false")
	assert_true(SaveManager.data == SaveManager.DEFAULT_DATA, "data equals DEFAULT_DATA")
	assert_true(SaveManager.can_write, "can_write stays true")
	assert_true(_failed_reasons.is_empty(), "no save_failed emitted")

func test_save_then_load_round_trip() -> void:
	print("\n--- Save then load ---")
	_use_local()
	SaveManager.load_save()
	var profile := SaveManager.get_section(SaveManager.PROFILE)
	profile["prestige_balance"] = 120
	var meta := SaveManager.get_section(SaveManager.META)
	meta["levels"]["FORT_HP"] = 2
	var flags := SaveManager.get_section(SaveManager.FLAGS)
	flags["tutorial_done"] = true
	var start := Time.get_ticks_usec()
	var error := SaveManager.save()
	var took_ms := (Time.get_ticks_usec() - start) / 1000.0
	assert_true(error == OK, "save() returns OK")
	assert_true(_completed == 1, "save_completed emitted once")
	assert_true(took_ms < 50.0, "save() took %.2f ms (< 50 ms)" % took_ms)
	assert_true(FileAccess.file_exists(TEST_PATH), "save.json written")

	var raw := _read_raw()
	assert_true(raw.get("save_version") == 1.0, "file has save_version 1")
	assert_true(raw.get("data", {}).get("profile", {}).get("prestige_balance") == 120.0,
			"file has prestige_balance 120")

	SaveManager.data = {}
	SaveManager.load_save()
	profile = SaveManager.get_section(SaveManager.PROFILE)
	assert_true(profile["prestige_balance"] == 120, "prestige_balance read back as 120")
	assert_true(typeof(profile["prestige_balance"]) == TYPE_INT, "prestige_balance read back as int")
	assert_true(SaveManager.get_section(SaveManager.META)["levels"]["FORT_HP"] == 2, "meta level read back")
	assert_true(SaveManager.get_section(SaveManager.FLAGS)["tutorial_done"] == true, "flag read back")
	assert_true(typeof(SaveManager.get_section(SaveManager.RUN_FLAG)["start_mult"]) == TYPE_FLOAT,
			"start_mult stays float")

func test_missing_fields_use_defaults() -> void:
	print("\n--- Missing fields ---")
	_write_raw('{"save_version": 1, "data": {"profile": {"prestige_balance": 5}, "meta": {"levels": {"FORT_HP": 3}}}}')
	_use_local()
	var error := SaveManager.load_save()
	assert_true(error == OK and SaveManager.can_write, "partial save loads normally")
	assert_true(_failed_reasons.is_empty(), "missing fields are not treated as corrupt")
	var profile := SaveManager.get_section(SaveManager.PROFILE)
	assert_true(profile["prestige_balance"] == 5, "stored value kept")
	assert_true(profile["max_wave_cleared"] == 0, "missing max_wave_cleared defaults to 0")
	assert_true(profile["stats"]["total_runs"] == 0, "missing stats default to 0")
	var levels: Dictionary = SaveManager.get_section(SaveManager.META)["levels"]
	assert_true(levels["FORT_HP"] == 3 and levels["GOLD_PCT"] == 0, "missing meta level defaults to 0")
	var run_flag := SaveManager.get_section(SaveManager.RUN_FLAG)
	assert_true(run_flag["run_in_progress"] == false and run_flag["start_wave"] == 1
			and run_flag["start_mult"] == 1.0, "missing run_flag uses defaults")
	assert_true(SaveManager.get_section(SaveManager.FLAGS)["tutorial_done"] == false,
			"missing flags use defaults")

func test_extra_fields_are_kept() -> void:
	print("\n--- Extra fields ---")
	_write_raw('{"save_version": 1, "revision": 7, "device_id": "abc", "checksum": "sha256:old", "data": {"profile": {"prestige_balance": 1, "future_field": "keep"}, "future_section": {"x": 1}}}')
	_use_local()
	SaveManager.load_save()
	var profile := SaveManager.get_section(SaveManager.PROFILE)
	profile["prestige_balance"] = 2
	SaveManager.save()
	var raw := _read_raw()
	var data: Dictionary = raw.get("data", {})
	assert_true(data.get("profile", {}).get("future_field") == "keep", "unknown profile field written back")
	assert_true(data.has("future_section"), "unknown section written back")
	assert_true(raw.get("revision") == 7.0 and raw.get("device_id") == "abc",
			"fields outside data written back")
	assert_true(not raw.has("checksum"), "stale checksum not copied")
	assert_true(data.get("profile", {}).get("prestige_balance") == 2.0, "changed value written")

func test_newer_version_is_not_overwritten() -> void:
	print("\n--- Newer save_version ---")
	var text := '{"save_version": 2, "data": {"profile": {"prestige_balance": 999}}}'
	_write_raw(text)
	_use_local()
	var error := SaveManager.load_save()
	assert_true(error != OK, "load_save() reports an error")
	assert_true(_only_reason(SaveManager.REASON_VERSION_TOO_NEW), "save_failed(VERSION_TOO_NEW) emitted")
	assert_true(SaveManager.data == SaveManager.DEFAULT_DATA, "runs on defaults")
	assert_true(not SaveManager.can_write, "can_write is false")
	_failed_reasons.clear()
	var profile := SaveManager.get_section(SaveManager.PROFILE)
	profile["prestige_balance"] = 1
	assert_true(SaveManager.save() != OK, "save() refuses")
	assert_true(_only_reason(SaveManager.REASON_WRITE_BLOCKED), "save_failed(WRITE_BLOCKED) emitted")
	assert_true(_completed == 0, "save_completed not emitted")
	assert_true(FileAccess.get_file_as_string(TEST_PATH) == text, "file left untouched")

func test_corrupt_file_is_not_overwritten() -> void:
	print("\n--- Unreadable file ---")
	var text := '{"save_version": 1, "data": {'
	_write_raw(text)
	_use_local()
	var error := SaveManager.load_save()
	assert_true(error != OK, "load_save() reports an error")
	assert_true(_only_reason(SaveManager.REASON_CORRUPT), "save_failed(CORRUPT) emitted")
	assert_true(SaveManager.data == SaveManager.DEFAULT_DATA, "runs on defaults")
	assert_true(SaveManager.save() != OK, "save() refuses")
	assert_true(FileAccess.get_file_as_string(TEST_PATH) == text, "file left untouched")

	_write_raw('{"data": {}}')
	_use_local()
	SaveManager.load_save()
	assert_true(_only_reason(SaveManager.REASON_CORRUPT), "missing save_version treated as corrupt")

func test_memory_repository_swap() -> void:
	print("\n--- Repository swap ---")
	_clear_test_dir()
	_reset_counters()
	var memory := MemorySaveRepository.new()
	SaveManager.set_repository(memory)
	SaveManager.load_save()
	assert_true(SaveManager.data == SaveManager.DEFAULT_DATA, "empty memory repository gives defaults")
	var profile := SaveManager.get_section(SaveManager.PROFILE)
	profile["max_wave_cleared"] = 11
	assert_true(SaveManager.save() == OK and _completed == 1, "save() through memory repository")
	assert_true(memory.stored.get("save_version") == SaveManager.SAVE_VERSION, "envelope has save_version")
	assert_true(memory.stored.get("data", {}).get("profile", {}).get("max_wave_cleared") == 11,
			"envelope has the data")
	assert_true(not FileAccess.file_exists(TEST_PATH), "no file written")
	SaveManager.data = {}
	SaveManager.load_save()
	assert_true(SaveManager.get_section(SaveManager.PROFILE)["max_wave_cleared"] == 11,
			"load_save() reads back from memory repository")

func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		failed_names.append(test_name)
		printerr("  [FAIL] %s" % test_name)

func _only_reason(reason: StringName) -> bool:
	return _failed_reasons.size() == 1 and _failed_reasons[0] == reason

func _use_local() -> void:
	_reset_counters()
	SaveManager.set_repository(LocalSaveRepository.new(TEST_PATH))

func _reset_counters() -> void:
	_completed = 0
	_failed_reasons.clear()

func _write_raw(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _read_raw() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	return parsed if parsed is Dictionary else {}

func _clear_test_dir() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	if DirAccess.dir_exists_absolute(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR)

func _on_save_completed() -> void:
	_completed += 1

func _on_save_failed(reason: StringName) -> void:
	_failed_reasons.append(reason)
