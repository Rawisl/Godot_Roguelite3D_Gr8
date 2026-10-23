extends HBoxContainer
## Speed buttons x1/x2/x3, the only way to change speed (there is no hotkey).
## Always shows the real time_scale, also after an automatic reset to x1.

## Wave states where only x1 is allowed.
const LOCKED_STATES: Array[StringName] = [&"BOSS_INTRO", &"SUMMARY", &"REWARD_PICK"]

var _buttons: Array[Button] = []
var _wave_locked := false
var _paused := false

func _ready() -> void:
	_buttons = [%X1, %X2, %X3]
	for i in _buttons.size():
		var b := _buttons[i]
		b.text = tr(StringName("hud.speed.x%d" % (i + 1)))
		b.toggle_mode = true
		# No keyboard focus, so Space and Enter can never press a speed button.
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_pressed.bind(i + 1))
	EventBus.time_scale_changed.connect(func(_scale: int) -> void: _refresh())
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.pause_changed.connect(_on_pause_changed)
	_refresh()

func _on_pressed(level: int) -> void:
	TimeManager.toggle_time_scale(level)
	# A refused change must not leave the button looking pressed.
	_refresh()

func _on_state_changed(new_state: StringName) -> void:
	_wave_locked = new_state in LOCKED_STATES
	_refresh()

func _on_pause_changed(is_paused: bool) -> void:
	_paused = is_paused
	_refresh()

# TODO: add the lock icon once the icon set has one.
func _refresh() -> void:
	var current := TimeManager.get_time_scale()
	for i in _buttons.size():
		var b := _buttons[i]
		var level := i + 1
		var locked := _wave_locked and level > TimeManager.SCALE_MIN
		b.set_pressed_no_signal(level == current)
		b.disabled = locked or _paused
		if locked:
			b.tooltip_text = tr(&"hud.speed.locked")
		elif _paused:
			b.tooltip_text = tr(&"hud.speed.paused")
		else:
			b.tooltip_text = ""
