class_name TutorialHint
extends PanelContainer
## The tutorial's hint box under the wave counter: step n of m, what to do, and Skip. It only
## shows what TutorialService says; the hint never blocks the game (the Start wave lock lives in
## the service). A reminder shows the same text again with a tag and a short pulse.

## How long the reminder pulse lasts, in real seconds.
@export var pulse_time := 0.6

var _pulse: Tween

@onready var _service: TutorialService = %TutorialService
@onready var _title: Label = %Title
@onready var _step: Label = %StepCount
@onready var _text: Label = %HintText
@onready var _remind: Label = %RemindTag
@onready var _skip: Button = %SkipButton

func _ready() -> void:
	_title.text = tr(&"tutorial.title")
	_remind.text = tr(&"tutorial.remind")
	_skip.text = tr(&"tutorial.skip")
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.pressed.connect(_service.skip)
	_service.step_changed.connect(show_step)
	_service.reminded.connect(_on_reminded)
	show_step(_service.step)

## Kept apart from the signal so the test scene can draw any step.
func show_step(step: StringName) -> void:
	visible = step != TutorialService.OFF
	_remind.visible = false
	if not visible:
		return
	_step.text = UiFormat.tr_fmt(&"tutorial.step", {"n": TutorialService.STEPS.find(step) + 1, "total": TutorialService.STEPS.size()})
	_text.text = tr(StringName("tutorial." + String(step)))

func _on_reminded(_step_id: StringName) -> void:
	_remind.visible = true
	if _pulse != null:
		_pulse.kill()
	# One soft pulse, well under three flashes a second, and none with reduced flashing.
	if bool(GameState.get_setting(&"reduce_flash", false)):
		return
	_pulse = create_tween().set_ignore_time_scale()
	_pulse.tween_property(self, "modulate:a", 0.55, pulse_time * 0.5)
	_pulse.tween_property(self, "modulate:a", 1.0, pulse_time * 0.5)
