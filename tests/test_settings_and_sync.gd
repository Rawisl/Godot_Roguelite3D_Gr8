extends Control
## settings.cfg, the Graphics and Accessibility tabs, SyncService with a fake account API, and the
## save error notices. Press F6: the checks run first and print a summary, then click the window
## once and use the keys:
## 1: Settings on the Graphics tab. 2: a new resolution, the "Keep changes?" box counts down.
## 3: Settings on the Accessibility tab. 4: the next sync state on the Account tab.
## 5: the "upload the local profile?" dialog. 6: the "data from another machine" notice.
## 7: the unreadable save notice with "New save". 8: the failed write notice with "Retry".
## Nothing here reaches the network or the real save and settings files.

const SETTINGS_SCENE := preload("res://ui/screens/settings.tscn")
const TEST_SETTINGS := "user://test_settings_and_sync.cfg"
const TEST_SAVE := "user://test_settings_and_sync_save.json"
const CONFLICT_FILE := "user://save.conflict.bak"
const SYNC_STATES: Array[StringName] = [&"GUEST", &"SYNCED", &"SYNCING", &"OFFLINE", &"ERROR"]

## Same calls as AccountApi; answers what the test sets and remembers the pushes.
class FakeApi:
	extends RefCounted
	var pull_result: Dictionary = {}
	var push_result: Dictionary = {"ok": true, "conflict": false}
	var pulls := 0
	var pushes: Array[int] = []

	func pull_save() -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		pulls += 1
		return pull_result.duplicate(true)

	func push_save(revision: int, _device_id: String, _data: Dictionary) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		pushes.append(revision)
		var result := push_result.duplicate(true)
		result["revision"] = revision
		return result

var _passed := 0
var _failed := 0
var _sync_index := 0
var _settings: Control
var _fake := FakeApi.new()
var _prompt_calls := 0
var _prompt_answer: Variant = true
var _real_api: Variant
var _real_prompt: Callable
var _real_settings_path := ""

func _ready() -> void:
	_real_settings_path = GameState.settings_path
	GameState.settings_path = TEST_SETTINGS
	_remove_files()
	_real_api = SyncService.api
	_real_prompt = SyncService.upload_prompt
	SyncService.api = _fake
	SyncService.upload_prompt = func() -> Variant:
		_prompt_calls += 1
		return _prompt_answer
	SaveManager.set_repository(LocalSaveRepository.new(TEST_SAVE))
	SaveManager.load_save()
	await get_tree().process_frame
	await _run_checks()
	print("test_settings_and_sync: %d passed, %d failed" % [_passed, _failed])
	# Manual keys show the real dialogs.
	SyncService.upload_prompt = _real_prompt
	_open_settings(&"graphics")

func _exit_tree() -> void:
	GameState.settings_path = _real_settings_path
	SyncService.api = _real_api
	SyncService.upload_prompt = _real_prompt
	_sign_out_fake()
	SaveManager.set_repository(LocalSaveRepository.new())
	SaveManager.load_save()
	_remove_files()

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_open_settings(&"graphics")
		KEY_2:
			await _open_settings(&"graphics")
			var other: Vector2i = DisplaySettings.RESOLUTIONS[1]
			if DisplaySettings.current(&"resolution") == other:
				other = DisplaySettings.RESOLUTIONS[0]
			_graphics()._change_window(&"resolution", other)
		KEY_3:
			_open_settings(&"accessibility")
		KEY_4:
			await _open_settings(&"account")
			_sync_index = (_sync_index + 1) % SYNC_STATES.size()
			EventBus.sync_state_changed.emit(SYNC_STATES[_sync_index], "")
		KEY_5:
			_set_progress()
			SyncService._ask_upload()
		KEY_6:
			ScreenManager.show_notice(&"dialog.sync_other_device.title", &"dialog.sync_other_device.body")
		KEY_7:
			EventBus.save_failed.emit(SaveManager.REASON_CORRUPT)
		KEY_8:
			EventBus.save_failed.emit(SaveManager.REASON_WRITE_ERROR)

func _run_checks() -> void:
	_check_settings_file()
	await _check_settings_screen()
	await _check_graphics_keep()
	await _check_accessibility()
	await _check_sync()
	await _check_save_notices()

func _check_settings_file() -> void:
	EventBus.settings_changed.emit(&"volume_music", 0.35)
	EventBus.settings_changed.emit(&"resolution", Vector2i(1600, 900))
	_expect(GameState.save_settings() == OK and FileAccess.file_exists(TEST_SETTINGS), "settings: settings.cfg is written")
	EventBus.settings_changed.emit(&"volume_music", 0.9)
	_expect(GameState.load_settings() == OK and is_equal_approx(float(GameState.get_setting(&"volume_music")), 0.35)
		and is_equal_approx(float(AudioManager.get_setting(&"volume_music")), 0.35), "settings: loading sends the stored values again")
	_expect(GameState.get_setting(&"resolution") == Vector2i(1600, 900), "settings: a resolution comes back as Vector2i")
	var file := FileAccess.open(TEST_SETTINGS, FileAccess.WRITE)
	file.store_string("[settings\nnot a config file ===")
	file.close()
	_expect(GameState.load_settings() != OK and FileAccess.file_exists(TEST_SETTINGS + ".corrupt")
		and not FileAccess.file_exists(TEST_SETTINGS), "settings: an unreadable file is kept as .corrupt")
	_expect(SaveManager.can_write, "settings: an unreadable settings.cfg leaves the save alone")

func _check_settings_screen() -> void:
	await _open_settings(&"audio")
	var tabs := _settings.get_node("%Tabs") as TabContainer
	_expect(tabs.get_tab_count() == 5 and tabs.current_tab == 1 and tabs.get_tab_title(1) == tr(&"settings.tab.audio"),
		"settings: five tabs, Controls and Data are gone")
	EventBus.settings_changed.emit(&"volume_sfx", 0.25)
	_expect(not _file_has("volume_sfx"), "settings: a change alone does not write the file")
	_settings.go_back()
	_expect(_file_has("volume_sfx"), "settings: leaving the screen writes the file")

func _check_graphics_keep() -> void:
	await _open_settings(&"graphics")
	var graphics := _graphics()
	var before: Variant = DisplaySettings.current(&"resolution")
	var other: Vector2i = DisplaySettings.RESOLUTIONS[2]
	if before == other:
		other = DisplaySettings.RESOLUTIONS[0]
	graphics._change_window(&"resolution", other)
	_expect(graphics.has_pending() and (graphics.get_node("%KeepPanel") as Control).visible
		and DisplaySettings.current(&"resolution") == other, "graphics: a new resolution applies and asks to keep it")
	graphics.revert_pending()
	_expect(DisplaySettings.current(&"resolution") == before and not graphics.has_pending(), "graphics: Back goes to the old resolution")
	var seconds := GameConfig.settings_keep_seconds
	GameConfig.settings_keep_seconds = 0.2
	graphics._change_window(&"resolution", other)
	await TimeManager.wait_real(0.4)
	_expect(DisplaySettings.current(&"resolution") == before, "graphics: no answer in time goes back by itself")
	graphics._change_window(&"resolution", other)
	graphics.keep_changes()
	await TimeManager.wait_real(0.4)
	_expect(DisplaySettings.current(&"resolution") == other, "graphics: Keep keeps the new resolution")
	GameConfig.settings_keep_seconds = seconds
	graphics._change_window(&"resolution", before)
	_settings.go_back()
	_expect(GameState.get_setting(&"resolution") == other, "graphics: leaving Settings undoes a change not kept")
	EventBus.settings_changed.emit(&"resolution", before)
	EventBus.settings_changed.emit(&"max_fps", 60)
	_expect(Engine.max_fps == 60, "graphics: the FPS limit applies at once")
	EventBus.settings_changed.emit(&"max_fps", 0)

func _check_accessibility() -> void:
	EventBus.settings_changed.emit(&"screen_shake", 0.5)
	EventBus.settings_changed.emit(&"hold_toggle", true)
	await _open_settings(&"accessibility")
	var tab := _settings.find_child("TabAccessibility", true, false)
	_expect((tab.get_node("%Shake") as OptionButton).selected == 1 and (tab.get_node("%HoldToggle") as CheckButton).button_pressed,
		"accessibility: the tab opens on the values in use")
	(tab.get_node("%HoldToggle") as CheckButton).button_pressed = false
	_expect(GameState.get_setting(&"hold_toggle") == false, "accessibility: hold or toggle is a setting")
	EventBus.settings_changed.emit(&"screen_shake", 1.0)

func _check_sync() -> void:
	_sign_out_fake()
	SyncService.request_sync()
	_expect(SyncService.state == &"GUEST", "sync: a guest stays GUEST")
	_sign_in_fake()

	# The account has newer data from another machine.
	_set_progress()
	SaveManager.save_now()
	var local_revision := SaveManager.get_revision()
	_fake.pull_result = {"ok": true, "revision": local_revision + 5, "device_id": "other-machine",
		"data": {"profile": {"prestige_balance": 777}, "meta": {}, "flags": {"tutorial_done": true}}}
	await _sync()
	_expect(int(SaveManager.get_section(&"profile")["prestige_balance"]) == 777
		and bool(SaveManager.get_section(&"flags")["tutorial_done"]), "sync: newer cloud data replaces profile and tutorial_done")
	_expect(SaveManager.get_revision() == local_revision + 5, "sync: the local revision matches the cloud")
	_expect(FileAccess.file_exists(CONFLICT_FILE), "sync: the copy from this machine is kept in save.conflict.bak")
	_expect(SyncService.state == &"SYNCED" and _fake.pushes.is_empty(), "sync: pulled data is not pushed back")
	ScreenManager.close_all_dialogs()

	# This machine is ahead.
	SaveManager.save_now()
	_fake.pull_result = {"ok": true, "revision": SaveManager.get_revision() - 1, "device_id": SaveManager.get_device_id(), "data": {}}
	await _sync()
	_expect(_fake.pushes == [SaveManager.get_revision()] and SyncService.state == &"SYNCED", "sync: a newer local save is pushed")

	# An empty account asks first.
	_fake.pushes.clear()
	_fake.pull_result = {"ok": true, "revision": 0, "device_id": "", "data": {}}
	_prompt_answer = false
	await _sync()
	_expect(_prompt_calls == 1 and _fake.pushes.is_empty() and SyncService.state == &"OFFLINE", "sync: declining the upload pushes nothing")
	await _sync()
	_expect(_prompt_calls == 1, "sync: a declined upload is not asked again this session")
	SyncService._declined_user = ""
	_prompt_answer = true
	await _sync()
	_expect(_prompt_calls == 2 and _fake.pushes.size() == 1 and SyncService.state == &"SYNCED", "sync: accepting uploads the local profile")

	# Errors never block.
	_fake.pull_result = {"ok": false, "error": AuthService.ERR_OFFLINE}
	await _sync()
	_expect(SyncService.state == &"OFFLINE", "sync: no network shows OFFLINE")
	_fake.pull_result = {"ok": false, "error": AuthService.ERR_SERVER}
	await _sync()
	_expect(SyncService.state == &"ERROR", "sync: a server error shows ERROR")

	# Never in combat.
	_fake.pull_result = {"ok": true, "revision": SaveManager.get_revision(), "device_id": SaveManager.get_device_id(), "data": {}}
	var pulls := _fake.pulls
	var app_state := GameState.current
	GameState.current = GameState.AppState.RUN
	GameState.wave_state = &"COMBAT"
	SyncService.request_sync()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_fake.pulls == pulls, "sync: nothing is sent in combat")
	GameState.wave_state = &"SUMMARY"
	EventBus.state_changed.emit(&"SUMMARY")
	await _wait_sync()
	_expect(_fake.pulls == pulls + 1, "sync: a sync held in combat goes out when combat ends")
	GameState.current = app_state
	GameState.wave_state = &""

	# Shop purchases sync too; the run end path is the same deferred call.
	EventBus.meta_item_purchased.emit(&"FORT_HP", 1)
	await get_tree().process_frame
	await _wait_sync()
	_expect(_fake.pulls == pulls + 2, "sync: a shop purchase syncs")
	_sign_out_fake()

func _check_save_notices() -> void:
	ScreenManager.close_all_dialogs()
	await get_tree().process_frame
	EventBus.save_failed.emit(SaveManager.REASON_CORRUPT)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_dialog_has(tr(&"dialog.save_corrupt.new")), "save: an unreadable save offers New save")
	ScreenManager.close_all_dialogs()
	await get_tree().process_frame
	EventBus.save_failed.emit(SaveManager.REASON_WRITE_ERROR)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_dialog_has(tr(&"dialog.save_failed.retry")), "save: a failed write offers Retry")
	ScreenManager.close_all_dialogs()
	await get_tree().process_frame

func _sync() -> void:
	SyncService.request_sync()
	await _wait_sync()

func _wait_sync() -> void:
	for i in 10:
		await get_tree().process_frame
		if not SyncService.is_busy():
			return

func _open_settings(tab: StringName) -> void:
	if is_instance_valid(_settings):
		_settings.queue_free()
		await get_tree().process_frame
	GameState.settings_tab = tab
	_settings = SETTINGS_SCENE.instantiate()
	_settings.is_overlay = true
	var settings := _settings
	_settings.closed.connect(func() -> void: settings.queue_free())
	add_child(_settings)

func _graphics() -> Control:
	return _settings.get_node("%TabGraphics")

func _set_progress() -> void:
	var profile := SaveManager.get_section(&"profile")
	profile["prestige_balance"] = 120
	profile["max_wave_cleared"] = 14
	profile["stats"]["total_runs"] = 3

func _sign_in_fake() -> void:
	AuthService._access_token = "test-token"
	AuthService.user_id = "test-user"

func _sign_out_fake() -> void:
	AuthService._access_token = ""
	AuthService.user_id = ""

func _remove_files() -> void:
	for path in [TEST_SETTINGS, TEST_SETTINGS + ".corrupt", TEST_SAVE, CONFLICT_FILE]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _file_has(key: String) -> bool:
	var config := ConfigFile.new()
	return config.load(TEST_SETTINGS) == OK and config.has_section_key("settings", key)

func _dialog_has(text: String) -> bool:
	for node in ScreenManager.find_children("*", "Button", true, false):
		if (node as Button).text == text and (node as Button).is_visible_in_tree():
			return true
	return false

func _expect(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		push_error("test_settings_and_sync FAILED: " + what)
