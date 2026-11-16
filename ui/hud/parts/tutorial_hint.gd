class_name TutorialHint
extends PanelContainer
## The tutorial's hint box under the wave counter. Each step reads at a glance: dots for the
## progress, one large line for what to do, a gold line for where, and key caps for the keys,
## with no sentence punctuation. It only shows what TutorialService (a run system in main.tscn,
## found by its group) says; the hint never blocks the game (the Start wave lock lives in the
## service). A reminder adds a tag and a short pulse. Without a service it stays hidden.
# TODO(kiezroth): the build steps say the starter towers are free; that is only true once BuildService.build_starter() lands (see tutorial_service.gd).
# TODO(WhoKeng): add "Xem lại hướng dẫn" to the Gameplay tab once that tab exists; it shows these hints again without clearing tutorial_done.

## Keys shown under each step: [key cap text, what it does], both locale keys.
const STEP_KEYS := {
	TutorialService.BUILD_ARROW: [[&"tutorial.key.wasd", &"tutorial.key.camera"]],
	TutorialService.BUILD_CANNON: [],
	TutorialService.START_WAVE: [],
	TutorialService.FIGHT: [[&"tutorial.key.wasd", &"tutorial.key.move"], [&"tutorial.key.mouse", &"tutorial.key.attack"],
		[&"tutorial.key.space", &"tutorial.key.dodge"]],
}
## Done, current and waiting dots.
const DOT_DONE := Color(0.9098039, 0.7607843, 0.3529412, 1)
const DOT_NOW := Color(0.9490196, 0.9372549, 0.9019608, 1)
const DOT_WAIT := Color(0.2784314, 0.3019608, 0.3529412, 1)

## How long the reminder pulse lasts, in real seconds.
@export var pulse_time := 0.6

var _pulse: Tween

var _service: TutorialService
@onready var _title: Label = %Title
@onready var _step: Label = %StepCount
@onready var _dots: HBoxContainer = %StepDots
@onready var _action: Label = %Action
@onready var _where: Label = %Where
@onready var _keys: HBoxContainer = %Keys
@onready var _remind: Label = %RemindTag
@onready var _skip: Button = %SkipButton

func _ready() -> void:
	_title.text = tr(&"tutorial.title")
	_remind.text = tr(&"tutorial.remind")
	_skip.text = tr(&"tutorial.skip")
	_skip.focus_mode = Control.FOCUS_NONE
	visible = false
	_service = get_tree().get_first_node_in_group(&"tutorial") as TutorialService
	if _service == null:
		return
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
	var index := TutorialService.STEPS.find(step)
	_step.text = UiFormat.tr_fmt(&"tutorial.step", {"n": index + 1, "total": TutorialService.STEPS.size()})
	var dots := _dots.get_children()
	for i in dots.size():
		var dot := dots[i] as Panel
		var box := (dot.get_theme_stylebox(&"panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		box.bg_color = DOT_DONE if i < index else (DOT_NOW if i == index else DOT_WAIT)
		dot.add_theme_stylebox_override(&"panel", box)
	_action.text = tr(StringName("tutorial.%s.action" % step))
	_where.text = tr(StringName("tutorial.%s.where" % step))
	var keys: Array = STEP_KEYS.get(step, [])
	var chips := _keys.get_children()
	for i in chips.size():
		var chip := chips[i] as HBoxContainer
		chip.visible = i < keys.size()
		if chip.visible:
			# Each chip is the key cap (a panel holding its label), then what the key does.
			(chip.get_child(0).get_child(0) as Label).text = tr(keys[i][0])
			(chip.get_child(1) as Label).text = tr(keys[i][1])
	_keys.visible = not keys.is_empty()

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
