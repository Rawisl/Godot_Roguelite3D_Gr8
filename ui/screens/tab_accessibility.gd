extends Control
## Accessibility tab. Each change is broadcast on EventBus.settings_changed right away;
## saving to settings.cfg happens when the Settings screen closes.
##   screen_shake: 1.0 normal, 0.5 reduced, 0.0 off
##   reduced_motion: true when shake is off; camera glides become instant cuts
##   reduce_flash: no white flash, static warning borders
##   hold_toggle: keys that are held (E to heal) work as press on, press off instead
# TODO(Rawisl): read GameState.get_setting(&"hold_toggle") in commander_input.gd and follow settings_changed, so one E press starts the heal channel and the next one stops it.

const SHAKE_LEVELS: Array[float] = [1.0, 0.5, 0.0]
const SHAKE_KEYS: Array[StringName] = [&"settings.acc.shake_normal", &"settings.acc.shake_half", &"settings.acc.shake_off"]

@onready var _shake_label: Label = %ShakeLabel
@onready var _shake: OptionButton = %Shake
@onready var _flash: CheckButton = %ReduceFlash
@onready var _hold: CheckButton = %HoldToggle

func _ready() -> void:
	_shake_label.text = tr(&"settings.acc.shake")
	for key in SHAKE_KEYS:
		_shake.add_item(tr(key))
	# Opens on the values in use, so a saved choice is what the player sees.
	_shake.select(maxi(SHAKE_LEVELS.find(float(GameState.get_setting(&"screen_shake", 1.0))), 0))
	_flash.text = tr(&"settings.acc.reduce_flash")
	_flash.set_pressed_no_signal(bool(GameState.get_setting(&"reduce_flash", false)))
	_hold.text = tr(&"settings.acc.hold_toggle")
	_hold.tooltip_text = tr(&"settings.acc.hold_toggle_tip")
	_hold.set_pressed_no_signal(bool(GameState.get_setting(&"hold_toggle", false)))
	_shake.item_selected.connect(_on_shake_selected)
	_flash.toggled.connect(func(on: bool) -> void: EventBus.settings_changed.emit(&"reduce_flash", on))
	_hold.toggled.connect(func(on: bool) -> void: EventBus.settings_changed.emit(&"hold_toggle", on))

func _on_shake_selected(index: int) -> void:
	var level := SHAKE_LEVELS[index]
	EventBus.settings_changed.emit(&"screen_shake", level)
	EventBus.settings_changed.emit(&"reduced_motion", is_zero_approx(level))
