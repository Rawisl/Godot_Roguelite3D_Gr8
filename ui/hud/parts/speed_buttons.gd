extends HBoxContainer
## One button cycles x1, x2 and x3.
## Always shows the real time_scale, also after an automatic reset to x1.

## Wave states where only x1 is allowed.
const LOCKED_STATES: Array[StringName] = [&"BOSS_INTRO", &"SUMMARY", &"REWARD_PICK"]

@onready var _cycle: Button = %Cycle
var _wave_locked := false
var _paused := false

func _ready() -> void:
	_cycle.focus_mode = Control.FOCUS_NONE
	_cycle.pressed.connect(_on_pressed)
	EventBus.time_scale_changed.connect(func(_scale: int) -> void: _refresh())
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.pause_changed.connect(_on_pause_changed)
	_refresh()

func _on_pressed() -> void:
	if not _cycle.disabled:
		TimeManager.set_time_scale(TimeManager.get_time_scale() % TimeManager.SCALE_MAX + 1)

func _on_state_changed(new_state: StringName) -> void:
	_wave_locked = new_state in LOCKED_STATES
	_refresh()

func _on_pause_changed(is_paused: bool) -> void:
	_paused = is_paused
	_refresh()

func _refresh() -> void:
	var level := TimeManager.get_time_scale()
	_cycle.text = tr(StringName("hud.speed.symbol%d" % level))
	_cycle.disabled = _wave_locked or _paused
	if _paused:
		_cycle.tooltip_text = tr(&"hud.speed.paused")
	elif _wave_locked:
		_cycle.tooltip_text = tr(&"hud.speed.locked")
	else:
		_cycle.tooltip_text = tr(StringName("hud.speed.x%d" % level))
