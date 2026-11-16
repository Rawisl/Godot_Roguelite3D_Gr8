extends MarginContainer
## Lives on GameState's pause layer while the tree is paused.

const SETTINGS_SCENE := preload("res://ui/screens/settings.tscn")
const DIALOG_SCENE := preload("res://ui/screens/confirm_dialog.tscn")

var _settings_overlay: Control
## The run when the menu opened; empty outside a run (F6 on this scene).
var _snapshot: Dictionary = {}

@onready var _title: Label = %Title
@onready var _run_info: Label = %RunInfo
@onready var _resume: Button = %Resume
@onready var _settings: Button = %Settings
@onready var _abandon: Button = %Abandon
@onready var _quit: Button = %Quit

func _ready() -> void:
	_title.text = tr(&"menu.paused")
	_resume.text = tr(&"menu.resume")
	_settings.text = tr(&"menu.settings")
	_abandon.text = tr(&"menu.abandon")
	_quit.text = tr(&"menu.quit")
	_resume.pressed.connect(GameState.resume)
	_settings.pressed.connect(_open_settings)
	_abandon.pressed.connect(_confirm_end.bind(&"dialog.abandon.title", "dialog.abandon", GameState.abandon_run))
	_quit.pressed.connect(_confirm_end.bind(&"dialog.quit_run.title", "dialog.quit_run", GameState.quit_from_run))
	show_run_info(GameState.run_snapshot())
	for button: Button in [_resume, _settings, _abandon, _quit]:
		# Hovering moves keyboard focus too, so only one button is ever highlighted.
		button.mouse_entered.connect(button.grab_focus)
	_resume.grab_focus()

## Esc closes Settings first, then resumes. Settings closes through its own Back, so a window
## change not kept goes back and settings.cfg is written, the same as pressing Back.
func go_back() -> void:
	if is_instance_valid(_settings_overlay):
		_settings_overlay.go_back()
	else:
		GameState.resume()

func _on_settings_closed() -> void:
	if is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()
	_settings_overlay = null
	_resume.grab_focus()

## The run stays frozen while Settings is open.
func _open_settings() -> void:
	_settings_overlay = SETTINGS_SCENE.instantiate()
	_settings_overlay.is_overlay = true
	_settings_overlay.closed.connect(_on_settings_closed)
	get_parent().add_child(_settings_overlay)

## Wave and fight time of the run under the title, hidden outside a run.
func show_run_info(snapshot: Dictionary) -> void:
	_snapshot = snapshot
	_run_info.visible = not snapshot.is_empty()
	if _run_info.visible:
		_run_info.text = UiFormat.tr_fmt(&"menu.paused_info", {"wave": int(snapshot.get("wave_index", 0)),
			"time": UiFormat.time_mmss(float(snapshot.get("run_elapsed", 0.0)))})

## Ending the run says what it gives: the wave, defeat or survived, and the prestige.
func _confirm_end(title_key: StringName, body_prefix: String, on_confirm: Callable) -> void:
	if _snapshot.is_empty():
		_confirm(title_key, StringName(body_prefix + ".body"), on_confirm)
		return
	var survived := bool(_snapshot.get("victory_reached", false))
	_confirm(title_key, StringName(body_prefix + (".body_survived" if survived else ".body_run")), on_confirm,
		{"wave": int(_snapshot.get("wave_index", 0)), "gain": int(_snapshot.get("prestige_gain", 0))})

## System dialog: not bound to PREP rules.
func _confirm(title_key: StringName, body_key: StringName, on_confirm: Callable, params: Dictionary = {}) -> void:
	var dialog := DIALOG_SCENE.instantiate()
	dialog.setup(title_key, body_key, params)
	dialog.confirmed.connect(on_confirm)
	ScreenManager.open_dialog(dialog)
