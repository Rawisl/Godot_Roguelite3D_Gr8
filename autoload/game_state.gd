extends Node

signal app_state_changed(new_state: AppState, old_state: AppState)

enum AppState { BOOT, MAIN_MENU, RUN_LOADING, RUN, RUN_END, META_SHOP, SETTINGS }

const SCENES := {
	AppState.MAIN_MENU: "res://ui/screens/main_menu.tscn",
	AppState.RUN_LOADING: "res://ui/screens/run_loading.tscn",
	AppState.RUN: "res://main.tscn",
	AppState.RUN_END: "res://ui/screens/run_end.tscn",
	AppState.META_SHOP: "res://ui/screens/meta_shop.tscn",
	AppState.SETTINGS: "res://ui/screens/settings.tscn",
}

## Allowed transitions (SRS 3.1). MVP: Play goes straight to RunLoading (FLOW-06).
const TRANSITIONS := {
	AppState.BOOT: [AppState.MAIN_MENU],
	AppState.MAIN_MENU: [AppState.RUN_LOADING, AppState.META_SHOP, AppState.SETTINGS],
	AppState.RUN_LOADING: [AppState.RUN],
	AppState.RUN: [AppState.RUN_END],
	AppState.RUN_END: [AppState.RUN_LOADING, AppState.META_SHOP, AppState.MAIN_MENU],
	AppState.META_SHOP: [AppState.MAIN_MENU],
	AppState.SETTINGS: [AppState.MAIN_MENU],
}

const PAUSE_MENU_SCENE := preload("res://ui/screens/pause_menu.tscn")

var current: AppState = AppState.BOOT
## Result of the last run, read by the RunEnd screen (3.2.4).
var last_run_end_type: StringName = &""
var last_run_summary: Dictionary = {}

var _pause_layer: CanvasLayer
var _pause_menu: Control

func _ready() -> void:
	# Pause input and the pause menu must work while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 50
	add_child(_pause_layer)
	EventBus.run_ended.connect(_on_run_ended)
	_sync_with_current_scene.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if current != AppState.RUN or not event.is_action_pressed(&"pause"):
		return
	# INP-03 step 4: reached only when no dialog, panel or selection used Esc first.
	if _pause_menu == null:
		open_pause()
	else:
		_pause_menu.go_back()
	get_viewport().set_input_as_handled()

## Returns false if the transition is not in SRS 3.1 or a fade is running.
func change_state(new_state: AppState) -> bool:
	if ScreenManager.is_fading():
		return false
	if new_state not in TRANSITIONS[current]:
		push_warning("GameState: %s -> %s is not allowed (SRS 3.1)"
				% [AppState.keys()[current], AppState.keys()[new_state]])
		return false
	var old_state := current
	current = new_state
	if old_state == AppState.RUN:
		resume()
	app_state_changed.emit(new_state, old_state)
	ScreenManager.change_scene(SCENES[new_state])
	return true

func open_pause() -> void:
	# TODO(TIME-02): pause through TimeManager once it exists.
	get_tree().paused = true
	_pause_menu = PAUSE_MENU_SCENE.instantiate()
	_pause_layer.add_child(_pause_menu)

func resume() -> void:
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null
	get_tree().paused = false

## Abandon from Pause (SCR-08).
## TODO: request it from RunState (TV2, systems/run) so it emits run_ended (EVB-21).
func abandon_run() -> void:
	_on_run_ended(&"ABANDONED", {})

## Quit during Run (FLOW-04): settle the run as ABANDONED, then exit.
## TODO(FLOW-04): settle through RunState and wait for the save before quitting.
func quit_from_run() -> void:
	last_run_end_type = &"ABANDONED"
	get_tree().quit()

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
