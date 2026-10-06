extends MarginContainer
## Lives on GameState's pause layer while the tree is paused.

const SETTINGS_SCENE := preload("res://ui/screens/settings.tscn")
const DIALOG_SCENE := preload("res://ui/screens/confirm_dialog.tscn")

var _settings_overlay: Control

@onready var _resume: Button = %Resume
@onready var _settings: Button = %Settings
@onready var _abandon: Button = %Abandon
@onready var _quit: Button = %Quit

func _ready() -> void:
	_resume.text = tr(&"menu.resume")
	_settings.text = tr(&"menu.settings")
	_abandon.text = tr(&"menu.abandon")
	_quit.text = tr(&"menu.quit")
	_resume.pressed.connect(GameState.resume)
	_settings.pressed.connect(_open_settings)
	_abandon.pressed.connect(_confirm.bind(&"dialog.abandon.title", &"dialog.abandon.body", GameState.abandon_run))
	_quit.pressed.connect(_confirm.bind(&"dialog.quit_run.title", &"dialog.quit_run.body", GameState.quit_from_run))
	_resume.grab_focus()

## Esc closes Settings first, then resumes.
func go_back() -> void:
	if is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()
		_settings_overlay = null
		_resume.grab_focus()
	else:
		GameState.resume()

## The run stays frozen while Settings is open.
func _open_settings() -> void:
	_settings_overlay = SETTINGS_SCENE.instantiate()
	_settings_overlay.is_overlay = true
	_settings_overlay.closed.connect(go_back)
	get_parent().add_child(_settings_overlay)

## System dialog: not bound to PREP rules.
func _confirm(title_key: StringName, body_key: StringName, on_confirm: Callable) -> void:
	var dialog := DIALOG_SCENE.instantiate()
	dialog.setup(title_key, body_key)
	dialog.confirmed.connect(on_confirm)
	ScreenManager.open_dialog(dialog)
