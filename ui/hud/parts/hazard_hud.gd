class_name HazardHud
extends VBoxContainer
const HAZARD := &"HAZARD_TRIAL"
const RESULT_KEYS := {&"WON": &"alert.hazard.won", &"LEFT": &"alert.hazard.left", &"DIED": &"alert.hazard.died"}

var _in_room := false
var _paused := false
var _sent := false
@onready var _leave: Button = %LeaveButton

func _ready() -> void:
	_leave.text = tr(&"hud.hazard.leave")
	_leave.focus_mode = Control.FOCUS_NONE
	_leave.pressed.connect(_on_leave_pressed)
	EventBus.run_started.connect(_on_run_started)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.pause_changed.connect(_on_pause_changed)
	EventBus.hazard_trial_exited.connect(_on_exited)
	_in_room = GameState.wave_state == HAZARD
	_refresh()

func _refresh() -> void:
	visible = _in_room
	_leave.disabled = _sent or _paused
	_leave.tooltip_text = tr(&"hud.hazard.paused") if _paused else ""

## One request per room; the wave side ends the room and sends hazard_trial_exited.
func _on_leave_pressed() -> void:
	if _sent or _paused or not _in_room:
		return
	_sent = true
	_refresh()
	EventBus.hazard_leave_requested.emit()

func _on_run_started() -> void:
	_in_room = false
	_sent = false
	_refresh()

func _on_state_changed(new_state: StringName) -> void:
	_in_room = new_state == HAZARD
	if not _in_room:
		_sent = false
	_refresh()

func _on_pause_changed(is_paused: bool) -> void:
	_paused = is_paused
	_refresh()

## Rewards come from the signal, so the toast shows what RunState actually added.
func _on_exited(result: StringName, _kills: int, gold: int, xp: float, mithril: int) -> void:
	var key: StringName = RESULT_KEYS.get(result, &"alert.hazard.left")
	EventBus.alert_requested.emit(int(Enums.AlertTier.T3), key,
		{"gold": gold, "xp": UiFormat.num(xp), "mithril": mithril})
