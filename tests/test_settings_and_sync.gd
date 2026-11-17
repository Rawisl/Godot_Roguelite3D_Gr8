extends Control
## settings.cfg, the Graphics and Accessibility tabs, SyncService with a fake account API, and the
## save error notices. Press F6: the checks run first and print a summary, then click the window
## once and use the keys:
## 1: Settings on the Graphics tab. 2: a new resolution, the "Keep changes?" box counts down.
## 3: Settings on the Accessibility tab. 4: the next sync state on the Account tab.
## 5: the "upload the local profile?" dialog. 6: the "data from another machine" notice.
## 7: the unreadable save notice with "New save". 8: the failed write notice with "Retry".
## 9: the newer save notice.
## Nothing here reaches the network or the real save and settings files.

const SETTINGS_SCENE := preload("res://ui/screens/settings.tscn")
const TEST_SETTINGS := "user://test_settings_and_sync.cfg"
const TEST_SAVE := "user://test_settings_and_sync_save.json"
const TEST_NEWER_SAVE := "user://test_settings_and_sync_newer.json"
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
			SyncService.show_other_device_notice()
		KEY_7:
			EventBus.save_failed.emit(SaveManager.REASON_CORRUPT)
		KEY_8:
			EventBus.save_failed.emit(SaveManager.REASON_WRITE_ERROR)
		KEY_9:
			EventBus.save_failed.emit(SaveManager.REASON_VERSION_TOO_NEW)

func _run_checks() -> void:
	_check_settings_file()
	await _check_settings_screen()
	await _check_graphics_keep()
	await _check_accessibility()
	await _check_sync()
	await _check_save_notices()
	await _check_notice_layout()
	await _check_leaving_settings()
	_check_invalid_window_values()

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

	# Never during a run, also in PREP and SUMMARY, so the run keeps the profile it started with.
	_fake.pull_result = {"ok": true, "revision": SaveManager.get_revision(), "device_id": SaveManager.get_device_id(), "data": {}}
	var pulls := _fake.pulls
	var app_state := GameState.current
	GameState.current = GameState.AppState.RUN
	for wave_state in [&"COMBAT", &"PREP", &"SUMMARY"]:
		GameState.wave_state = wave_state
		SyncService.request_sync()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_fake.pulls == pulls, "sync: nothing is sent during a run, in combat, PREP or SUMMARY")
	GameState.current = GameState.AppState.RUN_END
	GameState.app_state_changed.emit(GameState.AppState.RUN_END, GameState.AppState.RUN)
	await _wait_sync()
	_expect(_fake.pulls == pulls + 1, "sync: a sync held during the run goes out when the run ends")
	GameState.current = app_state
	GameState.wave_state = &""

	# The Sync now button is ready again once a sync ends.
	await _open_settings(&"account")
	var sync_now := _settings.find_child("SyncNow", true, false) as Button
	await _sync()
	await get_tree().process_frame
	_expect(not sync_now.disabled, "sync: Sync now is ready again after a sync")
	_settings.queue_free()
	await get_tree().process_frame

	# An upload question closed by a screen change is asked again, not taken as "Để sau".
	_fake.pull_result = {"ok": true, "revision": 0, "device_id": "", "data": {}}
	SyncService._declined_user = ""
	SyncService.upload_prompt = _real_prompt
	ScreenManager.close_all_dialogs()
	await get_tree().process_frame
	SyncService.request_sync()
	for i in 5:
		await get_tree().process_frame
	ScreenManager.close_all_dialogs()
	await _wait_sync()
	_expect(SyncService._declined_user == "" and SyncService.state == &"OFFLINE", "sync: a closed upload question is asked again later")
	SyncService.upload_prompt = func() -> Variant:
		_prompt_calls += 1
		return _prompt_answer
	_fake.pull_result = {"ok": true, "revision": SaveManager.get_revision(), "device_id": SaveManager.get_device_id(), "data": {}}

	# Shop purchases sync too; the run end path is the same deferred call.
	pulls = _fake.pulls
	EventBus.meta_item_purchased.emit(&"FORT_HP", 1)
	await get_tree().process_frame
	await _wait_sync()
	_expect(_fake.pulls == pulls + 1, "sync: a shop purchase syncs")
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

	EventBus.save_failed.emit(SaveManager.REASON_VERSION_TOO_NEW)
	await get_tree().process_frame
	await get_tree().process_frame
	var notice := _shown_notice()
	_expect(notice != null and notice._title_text == tr(&"dialog.save_too_new.title")
		and notice._lines == [tr(&"dialog.save_too_new.line1"), tr(&"dialog.save_too_new.line2")]
		and notice._note_text == tr(&"dialog.save_too_new.note") and notice._tone == NoticeDialog.WARNING
		and notice.is_notice() and _dialog_has(tr(&"dialog.ok")), "save: a newer save asks to update the game")
	ScreenManager.close_all_dialogs()
	await get_tree().process_frame

	EventBus.save_failed.emit(SaveManager.REASON_WRITE_BLOCKED)
	await get_tree().process_frame
	await get_tree().process_frame
	notice = _shown_notice()
	_expect(notice != null and notice._title_text == tr(&"dialog.save_blocked.title")
		and notice._note_text == tr(&"dialog.save_blocked.note"), "save: a blocked write keeps the general notice")
	ScreenManager.close_all_dialogs()
	await get_tree().process_frame

	await _check_startup_notices()
	await _check_newer_save_file()

## The first load runs before ScreenManager listens, so it shows what was left in load_failure
## after the first screen change, once.
func _check_startup_notices() -> void:
	SaveManager.load_failure = SaveManager.REASON_VERSION_TOO_NEW
	ScreenManager._watch_startup_load_failure()
	await get_tree().process_frame
	await get_tree().process_frame
	var before_screen := _shown_notice()
	ScreenManager.screen_changed.emit("res://ui/screens/main_menu.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	var notice := _shown_notice()
	_expect(before_screen == null and notice != null and notice._title_text == tr(&"dialog.save_too_new.title"),
		"save: a newer save found while loading is shown once after the first screen")
	ScreenManager.close_all_dialogs()
	await get_tree().process_frame
	ScreenManager.screen_changed.emit("res://ui/screens/main_menu.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_shown_notice() == null and not ScreenManager.has_dialog(), "save: the startup notice is not shown a second time")

	SaveManager.load_failure = SaveManager.REASON_CORRUPT
	ScreenManager._watch_startup_load_failure()
	ScreenManager.screen_changed.emit("res://ui/screens/main_menu.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_dialog_has(tr(&"dialog.save_corrupt.new")),
		"save: an unreadable save found while loading offers New save after the first screen")
	ScreenManager.close_all_dialogs()
	await get_tree().process_frame

	SaveManager.load_failure = &""
	ScreenManager._watch_startup_load_failure()
	ScreenManager.screen_changed.emit("res://ui/screens/main_menu.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_shown_notice() == null and not ScreenManager.screen_changed.is_connected(ScreenManager._show_startup_load_failure),
		"save: nothing is shown after the first screen when loading went fine")

	SaveManager.load_failure = SaveManager.REASON_CORRUPT
	ScreenManager._watch_startup_load_failure()
	SaveManager.load_failure = &""
	ScreenManager.screen_changed.emit("res://ui/screens/main_menu.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_shown_notice() == null, "save: a failure cleared before the first screen shows nothing")
	if ScreenManager.screen_changed.is_connected(ScreenManager._show_startup_load_failure):
		ScreenManager.screen_changed.disconnect(ScreenManager._show_startup_load_failure)
	ScreenManager.close_all_dialogs()
	await get_tree().process_frame

## A save from a newer game is refused, the update notice shows, and a later blocked write queues its own notice.
func _check_newer_save_file() -> void:
	var file := FileAccess.open(TEST_NEWER_SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"save_version": SaveManager.SAVE_VERSION + 1,
		"data": {"profile": {"prestige_balance": 999}}}))
	file.close()
	SaveManager.set_repository(LocalSaveRepository.new(TEST_NEWER_SAVE))
	SaveManager.load_save()
	await get_tree().process_frame
	await get_tree().process_frame
	var notice := _shown_notice()
	_expect(notice != null and notice._title_text == tr(&"dialog.save_too_new.title")
		and SaveManager.load_failure == SaveManager.REASON_VERSION_TOO_NEW
		and int(SaveManager.get_section(SaveManager.PROFILE)["prestige_balance"]) == 0,
		"save: a newer save file on disk is refused, shown and left as it was")
	SaveManager.save()
	ScreenManager.close_all_dialogs()
	await get_tree().process_frame
	await get_tree().process_frame
	notice = _shown_notice()
	_expect(notice != null and notice._title_text == tr(&"dialog.save_blocked.title"),
		"save: the blocked write notice is queued behind the update notice")
	ScreenManager.close_all_dialogs()
	await get_tree().process_frame

	SaveManager.set_repository(LocalSaveRepository.new(TEST_SAVE))
	SaveManager.load_save()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(SaveManager.load_failure == &"" and SaveManager.can_write and _shown_notice() == null,
		"save: a save of the supported version shows no notice")
	if FileAccess.file_exists(TEST_NEWER_SAVE):
		DirAccess.remove_absolute(TEST_NEWER_SAVE)

## The one NoticeDialog open under ScreenManager, or null when there is none or several.
func _shown_notice() -> NoticeDialog:
	var shown := ScreenManager.find_children("*", "NoticeDialog", true, false)
	if shown.size() != 1:
		return null
	return shown[0] as NoticeDialog

func _check_notice_layout() -> void:
	_set_progress()
	var dialog := SyncService.make_upload_dialog()
	add_child(dialog)
	var lines := dialog.get_node("%Lines").get_children()
	var rows := dialog.get_node("%Rows").get_children()
	_expect((lines[0] as Label).text == tr(&"dialog.sync_upload.line_empty") and (lines[1] as Label).text == tr(&"dialog.sync_upload.line_take")
		and not (lines[2] as Label).visible, "notice: the upload dialog says the account is empty on its own line, then what it uploads")
	var first_row := rows[0].get_child(0).get_children()
	_expect((first_row[0] as Label).text == tr(&"dialog.sync_upload.row_balance") and (first_row[1] as Label).text == "120"
		and (rows[2] as Control).visible, "notice: each uploaded value is its own row")
	_expect(not (lines[0] as Label).text.ends_with("."), "notice: the lines end without a full stop")
	dialog.cancel()
	await get_tree().process_frame
	ScreenManager.close_all_dialogs()
	await get_tree().process_frame
	EventBus.save_failed.emit(SaveManager.REASON_CORRUPT)
	await get_tree().process_frame
	await get_tree().process_frame
	var shown := ScreenManager.find_children("*", "NoticeDialog", true, false)
	_expect(shown.size() == 1 and (shown[0] as NoticeDialog)._tone == NoticeDialog.DANGER and (shown[0].get_node("%Note") as Label).visible,
		"notice: an unreadable save is a danger notice with a note")
	ScreenManager.close_all_dialogs()
	await get_tree().process_frame

## Esc from the pause menu and closing the window both treat a window change not kept as no answer.
func _check_leaving_settings() -> void:
	var before: Variant = DisplaySettings.current(&"resolution")
	var other: Vector2i = DisplaySettings.RESOLUTIONS[1] if before != DisplaySettings.RESOLUTIONS[1] else DisplaySettings.RESOLUTIONS[0]
	var holder := Control.new()
	add_child(holder)
	var pause: Control = load("res://ui/screens/pause_menu.tscn").instantiate()
	holder.add_child(pause)
	await get_tree().process_frame
	pause._open_settings()
	await get_tree().process_frame
	var graphics: Node = pause._settings_overlay.find_child("TabGraphics", true, false)
	graphics._change_window(&"resolution", other)
	pause.go_back()
	await get_tree().process_frame
	_expect(DisplaySettings.current(&"resolution") == before and _file_value("resolution") == before and pause._settings_overlay == null,
		"settings: Esc from the pause menu goes back on a window change not kept and writes settings.cfg")
	pause._open_settings()
	await get_tree().process_frame
	graphics = pause._settings_overlay.find_child("TabGraphics", true, false)
	graphics._change_window(&"resolution", other)
	GameState._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	_expect(_file_value("resolution") == before, "settings: closing the window does not save a window change not kept")
	pause._settings_overlay.queue_free()
	holder.queue_free()
	await get_tree().process_frame

func _check_invalid_window_values() -> void:
	EventBus.settings_changed.emit(&"window_mode", 7)
	EventBus.settings_changed.emit(&"resolution", Vector2i(123, 45))
	EventBus.settings_changed.emit(&"max_fps", 33)
	_expect(DisplaySettings.current(&"window_mode") == DisplaySettings.WINDOWED and DisplaySettings.current(&"resolution") == DisplaySettings.DEFAULTS[&"resolution"]
		and Engine.max_fps == 0, "settings: values a window cannot use are ignored")
	for key: StringName in DisplaySettings.DEFAULTS:
		EventBus.settings_changed.emit(key, DisplaySettings.DEFAULTS[key])

func _file_value(key: String) -> Variant:
	var config := ConfigFile.new()
	if config.load(TEST_SETTINGS) != OK:
		return null
	return config.get_value("settings", key, null)

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
	for path in [TEST_SETTINGS, TEST_SETTINGS + ".corrupt", TEST_SAVE, TEST_NEWER_SAVE, CONFLICT_FILE]:
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
