extends Node

signal app_state_changed(new_state: AppState, old_state: AppState)
signal session_restore_failed(error: StringName)

enum AppState { BOOT, MAIN_MENU, RUN_LOADING, RUN, RUN_END, META_SHOP, SETTINGS, LEADERBOARD }

const SCENES := {
	AppState.MAIN_MENU: "res://ui/screens/main_menu.tscn",
	AppState.RUN_LOADING: "res://ui/screens/run_loading.tscn",
	AppState.RUN: "res://main.tscn",
	AppState.RUN_END: "res://ui/screens/run_end.tscn",
	AppState.META_SHOP: "res://ui/screens/meta_shop.tscn",
	AppState.SETTINGS: "res://ui/screens/settings.tscn",
	AppState.LEADERBOARD: "res://ui/screens/leaderboard.tscn",
}

## Allowed transitions. Play goes straight to RunLoading (no StartSelect yet).
const TRANSITIONS := {
	AppState.BOOT: [AppState.MAIN_MENU],
	AppState.MAIN_MENU: [AppState.RUN_LOADING, AppState.META_SHOP, AppState.SETTINGS, AppState.LEADERBOARD],
	AppState.RUN_LOADING: [AppState.RUN],
	AppState.RUN: [AppState.RUN_END],
	AppState.RUN_END: [AppState.RUN_LOADING, AppState.META_SHOP, AppState.MAIN_MENU],
	AppState.META_SHOP: [AppState.MAIN_MENU],
	AppState.SETTINGS: [AppState.MAIN_MENU],
	AppState.LEADERBOARD: [AppState.MAIN_MENU],
}

const PAUSE_MENU_SCENE := preload("res://ui/screens/pause_menu.tscn")
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "settings"

var current: AppState = AppState.BOOT
## Result of the last run, read by the RunEnd screen.
var last_run_end_type: StringName = &""
var last_run_summary: Dictionary = {}
## Last value sent for each setting on EventBus.settings_changed. Parts created later, such as
## the HUD of a new run, read it here instead of starting from a default.
var _settings: Dictionary = {}
## Where settings are kept, apart from the save. Tests point it at a scratch file.
var settings_path: String = SETTINGS_PATH
## A setting changed since settings.cfg was last written.
var _settings_dirty := false
## Last wave state sent on EventBus.state_changed, so HUD parts created after the first PREP
## still know it.
var wave_state: StringName = &""
## Why the saved sign-in could not be restored at start, empty when it was fine.
var session_restore_error: StringName = &""
## Tab the Settings screen opens on next time, then cleared. Empty opens the first tab.
var settings_tab: StringName = &""
## Last state sent on EventBus.sync_state_changed: GUEST, SYNCED, SYNCING, OFFLINE or ERROR.
var sync_state: StringName = &"GUEST"
var sync_detail: String = ""

var _pause_layer: CanvasLayer
var _pause_menu: Control

func _ready() -> void:
	# Pause input and the pause menu must work while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 50
	add_child(_pause_layer)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.state_changed.connect(_on_wave_state_changed)
	EventBus.sync_state_changed.connect(_on_sync_state_changed)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	_sync_with_current_scene.call_deferred()
	# Deferred so every autoload that applies a setting (AudioManager) is listening already.
	load_settings.call_deferred()
	_restore_session.call_deferred()

## Tab is mode_switch in a run and never moves focus, even in the pause menu or a dialog.
## Nothing to block when nothing has focus, so Tab still reaches the commander.
func _input(event: InputEvent) -> void:
	if current != AppState.RUN or get_viewport().gui_get_focus_owner() == null:
		return
	if event.is_action(&"ui_focus_next") or event.is_action(&"ui_focus_prev"):
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if current != AppState.RUN or not event.is_action_pressed(&"pause"):
		return
	# Reached only when no dialog, panel or selection used Esc first.
	if _pause_menu == null:
		open_pause()
	else:
		_pause_menu.go_back()
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	# Regaining focus does not resume: the player closes the pause menu.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and current == AppState.RUN and _pause_menu == null:
		open_pause()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and _settings_dirty:
		# A window change still waiting for Keep counts as no answer, so it is not saved.
		get_tree().call_group(&"pending_window_change", &"revert_pending")
		save_settings()

## Returns false if the transition is not allowed or a fade is running.
func change_state(new_state: AppState) -> bool:
	if ScreenManager.is_fading():
		return false
	if new_state not in TRANSITIONS[current]:
		push_warning("GameState: %s -> %s is not allowed"
				% [AppState.keys()[current], AppState.keys()[new_state]])
		return false
	var old_state := current
	current = new_state
	if old_state == AppState.RUN:
		resume()
		TimeManager.reset()
	app_state_changed.emit(new_state, old_state)
	ScreenManager.change_scene(SCENES[new_state])
	return true

func open_pause() -> void:
	TimeManager.request_pause(TimeManager.REASON_USER)
	_pause_menu = PAUSE_MENU_SCENE.instantiate()
	_pause_layer.add_child(_pause_menu)

func resume() -> void:
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null
	TimeManager.release_pause(TimeManager.REASON_USER)

## Run HUD buttons give focus back right away so Space and Enter never press them again.
## Dialogs and anything shown while the run is paused (pause menu, Settings)
## keep focus for arrow and Enter navigation.
func _on_gui_focus_changed(control: Control) -> void:
	if current != AppState.RUN or TimeManager.is_paused or ScreenManager.has_dialog():
		return
	(func() -> void:
		if is_instance_valid(control) and control.has_focus():
			control.release_focus()).call_deferred()

## Concludes the active run as abandoned and transitions to run end.
func abandon_run() -> void:
	var rs := _get_run_state()
	if rs != null and is_instance_valid(rs):
		rs.end_run(&"ABANDONED")
	else:
		_on_run_ended(&"ABANDONED", {})


## Settles the run as abandoned through runtime state and exits application.
func quit_from_run() -> void:
	var rs := _get_run_state()
	if rs != null and is_instance_valid(rs):
		rs.end_run(&"ABANDONED")
	else:
		last_run_end_type = &"ABANDONED"
	get_tree().quit()


## The run as it stands, for the pause and victory screens: the run end summary as if the run were
## abandoned now, plus owned_weapons. Empty outside a run.
func run_snapshot() -> Dictionary:
	var rs := _get_run_state()
	if rs == null or not is_instance_valid(rs):
		return {}
	var snapshot := rs.build_summary(&"ABANDONED", rs.get_run_result())
	snapshot["owned_weapons"] = rs.owned_weapons.duplicate()
	return snapshot


func _get_run_state() -> RunState:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"run_state") as RunState


func _on_run_ended(end_type: StringName, summary: Dictionary) -> void:
	last_run_end_type = end_type
	last_run_summary = summary
	change_state(AppState.RUN_END)

## Lets F6 on any screen start from the matching state.
func _sync_with_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for state in SCENES:
		if SCENES[state] == scene.scene_file_path:
			current = state
			return

func get_setting(key: StringName, default_value: Variant = null) -> Variant:
	return _settings.get(key, default_value)

## Sends every stored setting on EventBus.settings_changed, so each part applies it the same way
## as a change in the Settings tabs. A file that cannot be read is kept as .corrupt and the game
## runs on defaults; the save is never touched.
func load_settings() -> Error:
	if not FileAccess.file_exists(settings_path):
		return OK
	var config := ConfigFile.new()
	var error := config.load(settings_path)
	if error != OK:
		push_warning("GameState: %s cannot be read (error %d), using defaults" % [settings_path, error])
		DirAccess.rename_absolute(settings_path, settings_path + ".corrupt")
		return error
	if config.has_section(SETTINGS_SECTION):
		for key in config.get_section_keys(SETTINGS_SECTION):
			EventBus.settings_changed.emit(StringName(key), config.get_value(SETTINGS_SECTION, key))
	_settings_dirty = false
	return OK

## Written when the Settings screen closes, not on every change.
func save_settings() -> Error:
	var config := ConfigFile.new()
	for key: StringName in _settings:
		config.set_value(SETTINGS_SECTION, String(key), _settings[key])
	var error := config.save(settings_path)
	if error != OK:
		push_warning("GameState: cannot write %s (error %d)" % [settings_path, error])
		return error
	_settings_dirty = false
	return OK

func _on_settings_changed(key: StringName, value: Variant) -> void:
	_settings[key] = value
	_settings_dirty = true
	DisplaySettings.apply(key, value)
	QualitySettings.apply(key, value)

## Runs in the background, so a slow network never holds the boot screen. A failure only
## leaves a hint on the menu; the player keeps playing as before.
func _restore_session() -> void:
	AuthService.session_changed.connect(_on_session_changed)
	var result: Dictionary = await AuthService.restore_session()
	if not result["ok"]:
		session_restore_error = result.get("error", AuthService.ERR_SERVER)
		session_restore_failed.emit(session_restore_error)

## A sign in or a sign out replaces whatever went wrong while restoring. SyncService reports
## the sync state that follows.
func _on_session_changed(_signed_in: bool) -> void:
	session_restore_error = &""

func _on_wave_state_changed(new_state: StringName) -> void:
	wave_state = new_state

func _on_sync_state_changed(state: StringName, detail: String) -> void:
	sync_state = state
	sync_detail = detail
