class_name LostOverlay
extends CanvasLayer
## Full-screen LOST screen: dims the running game, holds, fades to black, then returns to the main menu.
## Listens only to EventBus. Timing uses real time so pause and time scale do not affect it.

## Seconds the LOST text stays on screen before the fade starts.
@export var hold_time: float = 3.0
## Seconds of the fade to black.
@export var fade_time: float = 1.0
@export var text_color: Color = Color(0.85, 0.12, 0.12)
@export var font_size: int = 160
@export var fade_color: Color = Color(0, 0, 0)
## Dim behind the LOST text, same value as the pause menu backdrop.
@export var dim_color: Color = Color(0.06666667, 0.06666667, 0.06666667, 0.5019608)

@onready var _dim: ColorRect = $Dim
@onready var _fade: ColorRect = $Fade
@onready var _title: Label = $Title

var _lost := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim.color = dim_color
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.hide()
	_fade.color = fade_color
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.text = tr(&"lost.title")
	_title.add_theme_color_override(&"font_color", text_color)
	_title.add_theme_font_size_override(&"font_size", font_size)
	_fade.hide()
	_title.hide()
	EventBus.fortress_destroyed.connect(_on_run_lost)
	EventBus.commander_died.connect(_on_run_lost)

## Swallows every input once the run is lost.
func _input(_event: InputEvent) -> void:
	if _lost:
		get_viewport().set_input_as_handled()

func _on_run_lost() -> void:
	if _lost:
		return
	_lost = true
	_dim.show()
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade.show()
	_title.show()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.tween_interval(hold_time)
	tween.tween_property(_fade, "modulate:a", 1.0, fade_time)
	tween.tween_callback(_leave_run)

## GameState refuses while a screen fade runs; try again next frame.
func _leave_run() -> void:
	while not GameState.change_state(GameState.AppState.MAIN_MENU):
		if not ScreenManager.is_fading():
			return
		await get_tree().process_frame
