extends Control
## Accessibility tab. Each change is broadcast on EventBus.settings_changed right away;
## saving to settings.cfg happens when the Settings screen closes.
##   screen_shake: 1.0 normal, 0.5 reduced, 0.0 off
##   reduced_motion: true when shake is off; camera glides become instant cuts
##   reduce_flash: no white flash, static warning borders

const SHAKE_LEVELS: Array[float] = [1.0, 0.5, 0.0]
const SHAKE_KEYS: Array[StringName] = [&"settings.acc.shake_normal", &"settings.acc.shake_half", &"settings.acc.shake_off"]

@onready var _shake_label: Label = %ShakeLabel
@onready var _shake: OptionButton = %Shake
@onready var _flash: CheckButton = %ReduceFlash

func _ready() -> void:
	_shake_label.text = tr(&"settings.acc.shake")
	for key in SHAKE_KEYS:
		_shake.add_item(tr(key))
	_shake.select(0)
	_flash.text = tr(&"settings.acc.reduce_flash")
	_shake.item_selected.connect(_on_shake_selected)
	_flash.toggled.connect(func(on: bool) -> void: EventBus.settings_changed.emit(&"reduce_flash", on))

func _on_shake_selected(index: int) -> void:
	var level := SHAKE_LEVELS[index]
	EventBus.settings_changed.emit(&"screen_shake", level)
	EventBus.settings_changed.emit(&"reduced_motion", is_zero_approx(level))
