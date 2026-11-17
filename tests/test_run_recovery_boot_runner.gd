extends Node

## Automated test runner verifying the interrupted run recovery through the real Boot screen:
## - the notice is still on screen once the main menu has faded in, not closed by the fade
## - no notice appears when no run was left in progress
## Writes only under user://test_save_recovery/, the real save is put back afterwards.

const TEST_DIR := "user://test_save_recovery"
const TEST_PATH := "user://test_save_recovery/endlesswar_save.json"
const TITLE_KEY := &"dialog.run_recovered.title"

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0

var _recovered: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("        AUTOMATED RUN RECOVERY BOOT RUNNER TEST        ")
	print("=======================================================")

	# The root is still setting up its children in the first frame, so Boot cannot be added yet.
	await get_tree().process_frame
	var real_repository := SaveManager.repository
	var real_data := SaveManager.data.duplicate(true)
	var real_can_write := SaveManager.can_write
	var real_loaded_from := SaveManager.loaded_from
	var real_load_failure := SaveManager.load_failure
	var real_checked := SaveManager._recovery_checked
	EventBus.run_recovered.connect(_on_run_recovered)

	await test_boot_shows_notice_after_fade()
	await test_boot_without_flag_no_notice()

	EventBus.run_recovered.disconnect(_on_run_recovered)
	ScreenManager.close_all_dialogs()
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


func test_boot_shows_notice_after_fade() -> void:
	print("\n[CASE] test_boot_shows_notice_after_fade")
	_clear_test_dir()
	SaveManager.set_repository(LocalSaveRepository.new(TEST_PATH))
	SaveManager.load_save()
	SaveManager.can_write = true
	SaveManager._recovery_checked = false
	SaveManager.record_run_start(1, 1.0)
	SaveManager.record_wave_summary(6, 40, 1, 1.0)
	# Reopening the game: the held data is dropped and read again from disk.
	SaveManager.load_save()
	_recovered = 0
	_start_boot()
	var reached := await _wait_main_menu()
	var notices := _notices_in_holder()
	assert_true(reached, "main menu reached")
	assert_true(notices.size() == 1, "one notice on screen after the fade")
	assert_true(notices.size() == 1 and notices[0].get("_params")["value"] == PrestigeCalc.prestige_gain(40, 0, 1.0), "notice shows the gain")
	assert_true(_pending_notices().is_empty(), "no notice left waiting")
	var run_flag := _disk(&"run_flag")
	assert_true(run_flag["run_in_progress"] == false, "run flag cleared on disk")
	assert_true(int(_disk(&"profile")["max_wave_cleared"]) == 6, "max_wave_cleared from wave 6")


func test_boot_without_flag_no_notice() -> void:
	print("\n[CASE] test_boot_without_flag_no_notice")
	ScreenManager.close_all_dialogs()
	await get_tree().process_frame
	GameState.current = GameState.AppState.BOOT
	SaveManager._recovery_checked = false
	_clear_test_dir()
	SaveManager.set_repository(LocalSaveRepository.new(TEST_PATH))
	SaveManager.load_save()
	_recovered = 0
	_start_boot()
	var reached := await _wait_main_menu()
	assert_true(reached, "main menu reached")
	assert_true(_notices_in_holder().is_empty() and _pending_notices().is_empty(), "no notice")
	assert_true(_recovered == 0, "run_recovered not sent")


func _start_boot() -> void:
	var boot := (load("res://ui/screens/boot.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(boot)
	get_tree().current_scene = boot


## Waits for the main menu to be the current screen and the fade to be over. False when it never gets there.
func _wait_main_menu() -> bool:
	var menu_path: String = GameState.SCENES[GameState.AppState.MAIN_MENU]
	for i in 600:
		await get_tree().process_frame
		if _menu_ready(menu_path):
			for j in 2:
				await get_tree().process_frame
			return true
	return false


func _menu_ready(menu_path: String) -> bool:
	if GameState.current != GameState.AppState.MAIN_MENU:
		return false
	if ScreenManager.is_fading():
		return false
	var screen := get_tree().current_scene
	return screen != null and screen.scene_file_path == menu_path


func _notices_in_holder() -> Array:
	var found: Array = []
	for node in ScreenManager._dialog_holder.get_children():
		if node.get("_title_key") == TITLE_KEY:
			found.append(node)
	return found


func _pending_notices() -> Array:
	var found: Array = []
	for node in ScreenManager._pending_notices:
		if node.get("_title_key") == TITLE_KEY:
			found.append(node)
	return found


func _disk(section: StringName) -> Dictionary:
	var envelope := LocalSaveRepository.new(TEST_PATH).load_data()
	var stored: Dictionary = envelope.get("data", {})
	return stored.get(String(section), {})


func _clear_test_dir() -> void:
	var local := LocalSaveRepository.new(TEST_PATH)
	for file_path in [TEST_PATH, local.path_of(SaveRepository.Source.TEMP),
			local.path_of(SaveRepository.Source.BACKUP), local.corrupt_path(),
			local.corrupt_path(SaveRepository.Source.TEMP), local.corrupt_path(SaveRepository.Source.BACKUP)]:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
	if DirAccess.dir_exists_absolute(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR)


func _on_run_recovered(_prestige_gain: int) -> void:
	_recovered += 1
