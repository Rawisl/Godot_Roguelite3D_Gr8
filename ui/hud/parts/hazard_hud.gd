class_name HazardHud
extends VBoxContainer
## Hazard Trial room HUD, shown only in HAZARD_TRIAL: enemies left, the gold and XP earned so far,
## the Mithril for a win, a note that room stats stay in the room, and the Leave button (one
## click, no confirmation). When the room ends it sends the result toast with the rewards.

const HAZARD := &"HAZARD_TRIAL"
const RESULT_KEYS := {&"WON": &"alert.hazard.won", &"LEFT": &"alert.hazard.left", &"DIED": &"alert.hazard.died"}

var _in_room := false
var _paused := false
var _sent := false
var _remaining := 0
var _total := 0
var _gold := 0
var _xp := 0.0
var _mithril := 0

@onready var _enemies: Label = %Enemies
@onready var _loot: Label = %Loot
@onready var _reward: Label = %Reward
@onready var _note: Label = %Note
@onready var _leave: Button = %LeaveButton

func _ready() -> void:
	_note.text = tr(&"hud.hazard.note")
	_leave.text = tr(&"hud.hazard.leave")
	_leave.focus_mode = Control.FOCUS_NONE
	_leave.pressed.connect(_on_leave_pressed)
	EventBus.run_started.connect(_on_run_started)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.pause_changed.connect(_on_pause_changed)
	EventBus.hazard_trial_offered.connect(_on_offered)
	EventBus.hazard_trial_entered.connect(_on_entered)
	EventBus.hazard_trial_progress.connect(_on_progress)
	EventBus.hazard_trial_exited.connect(_on_exited)
	_in_room = GameState.wave_state == HAZARD
	_refresh()

func _refresh() -> void:
	visible = _in_room
	_enemies.text = UiFormat.tr_fmt(&"hud.hazard.enemies", {"value": _remaining, "max": _total})
	_loot.text = UiFormat.tr_fmt(&"hud.hazard.loot", {"gold": _gold, "xp": UiFormat.num(_xp)})
	_reward.visible = _mithril > 0
	_reward.text = UiFormat.tr_fmt(&"hud.hazard.reward", {"mithril": _mithril})
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
	_mithril = 0
	_reset_room(0)

func _reset_room(total: int) -> void:
	_sent = false
	_total = total
	_remaining = total
	_gold = 0
	_xp = 0.0
	_refresh()

func _on_state_changed(new_state: StringName) -> void:
	_in_room = new_state == HAZARD
	if not _in_room:
		_sent = false
	_refresh()

func _on_pause_changed(is_paused: bool) -> void:
	_paused = is_paused
	_refresh()

func _on_offered(_wave_index: int, _enemy_types: Array, mithril: int) -> void:
	_mithril = mithril
	_refresh()

func _on_entered(_wave_index: int, enemy_types: Array) -> void:
	_reset_room(enemy_types.size())

# TODO(Ender-Via): emit hazard_trial_progress(remaining, total, gold, xp) whenever an enemy in the room is done, so the counts move.
func _on_progress(remaining: int, total: int, gold: int, xp: float) -> void:
	_remaining = remaining
	_total = total
	_gold = gold
	_xp = xp
	_refresh()

## Rewards come from the signal, so the toast shows what RunState actually added.
func _on_exited(result: StringName, _kills: int, gold: int, xp: float, mithril: int) -> void:
	var key: StringName = RESULT_KEYS.get(result, &"alert.hazard.left")
	EventBus.alert_requested.emit(int(Enums.AlertTier.T3), key,
		{"gold": gold, "xp": UiFormat.num(xp), "mithril": mithril})
