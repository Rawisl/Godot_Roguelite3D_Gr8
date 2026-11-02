class_name EmergencyRepair
extends Node
## Emergency repair (key R, Commander mode only): heals the Fortress for free.
## A run starts with 3 charges and no cooldown. Each use costs one charge and starts a fixed
## cooldown that runs in game time across waves. Killing a boss gives one charge back when
## the wave reaches SUMMARY; the cooldown is not touched by that.
##
## The node keeps working while the game is paused so it can refuse the key with a reason.
## It is a child of the commander and finds the Fortress through the "fortress" group.

const SKILL_ID: StringName = &"emg_repair"
const FORTRESS_GROUP: StringName = &"fortress"

# Refusal reasons sent on EventBus.emergency_repair_denied, in the order they are checked.
const REASON_PAUSED: StringName = &"PAUSED"
const REASON_NOT_COMMANDER: StringName = &"NOT_COMMANDER"
const REASON_NO_CHARGES: StringName = &"NO_CHARGES"
const REASON_COOLDOWN: StringName = &"COOLDOWN"
const REASON_FORTRESS_UNAVAILABLE: StringName = &"FORTRESS_UNAVAILABLE"
const REASON_FORTRESS_FULL: StringName = &"FORTRESS_FULL"

var charges: int = 0
## Extra share of max HP healed on top of the base. The run setup sets it from the meta shop.
## Charges and cooldown have no such hook on purpose: nothing may change them.
var heal_bonus_pct: float = 0.0

var _cooldown_left: float = 0.0
var _last_game_time: float = 0.0
var _last_whole_second: int = 0
var _commander_mode: bool = false
var _boss_killed_this_wave: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var commander := get_parent()
	_commander_mode = commander != null and commander.get("is_commander_mode") == true
	EventBus.mode_changed.connect(func(mode: StringName) -> void: _commander_mode = (mode == &"COMMANDER"))
	EventBus.run_started.connect(reset)
	EventBus.run_ended.connect(func(_end_type: StringName, _summary: Dictionary) -> void: _boss_killed_this_wave = false)
	EventBus.wave_started.connect(func(_wave_index: int) -> void: _boss_killed_this_wave = false)
	EventBus.boss_defeated.connect(func() -> void: _boss_killed_this_wave = true)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	reset.call_deferred()


## Start of a run: full charges, no cooldown.
func reset() -> void:
	charges = GameConfig.emg_repair_charges_start
	_cooldown_left = 0.0
	_last_game_time = TimeManager.game_time
	_last_whole_second = 0
	_boss_killed_this_wave = false
	_emit_state()
	_emit_cooldown()


func get_cooldown_left() -> float:
	return _cooldown_left


func get_heal_pct() -> float:
	return GameConfig.emg_repair_base_heal_pct + heal_bonus_pct


func _process(_delta: float) -> void:
	# Game time already stops on Pause and follows the speed, so the cooldown does too.
	var now := TimeManager.game_time
	var elapsed := maxf(0.0, now - _last_game_time)
	_last_game_time = now
	if _cooldown_left <= 0.0 or elapsed <= 0.0:
		return
	_cooldown_left = maxf(0.0, _cooldown_left - elapsed)
	var whole := ceili(_cooldown_left)
	if _cooldown_left == 0.0 or whole != _last_whole_second:
		_last_whole_second = whole
		_emit_cooldown()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"emergency_repair", false):
		try_use()


## Empty when the repair can run now, otherwise the first failing reason.
func get_denial_reason() -> StringName:
	if TimeManager.is_paused or get_tree().paused:
		return REASON_PAUSED
	if not _commander_mode:
		return REASON_NOT_COMMANDER
	if charges <= 0:
		return REASON_NO_CHARGES
	if _cooldown_left > 0.0:
		return REASON_COOLDOWN
	var fortress := get_tree().get_first_node_in_group(FORTRESS_GROUP) as Fortress
	if fortress == null or fortress.is_destroyed():
		return REASON_FORTRESS_UNAVAILABLE
	if fortress.is_full():
		return REASON_FORTRESS_FULL
	return &""


## Heals the Fortress and spends one charge. Returns the HP healed, 0 when refused (nothing is spent then).
func try_use() -> int:
	var reason := get_denial_reason()
	if reason != &"":
		EventBus.emergency_repair_denied.emit(reason)
		return 0
	var fortress := get_tree().get_first_node_in_group(FORTRESS_GROUP) as Fortress
	var healed := fortress.emergency_repair(get_heal_pct())
	charges -= 1
	_cooldown_left = GameConfig.emergency_repair_cooldown
	_last_whole_second = ceili(_cooldown_left)
	_emit_state()
	_emit_cooldown()
	return healed


## One charge back, capped at the maximum; a spare charge is lost. The cooldown keeps running.
func grant_charge() -> bool:
	if charges >= GameConfig.emg_repair_charges_max:
		return false
	charges = mini(charges + GameConfig.emg_repair_boss_refund, GameConfig.emg_repair_charges_max)
	EventBus.emergency_repair_charge_granted.emit(charges)
	_emit_state()
	return true


func _on_wave_cleared(_wave_index: int) -> void:
	if _boss_killed_this_wave:
		grant_charge()
	_boss_killed_this_wave = false


func _emit_state() -> void:
	EventBus.emergency_repair_state_changed.emit(charges, _cooldown_left, get_heal_pct())


func _emit_cooldown() -> void:
	EventBus.skill_cooldown_changed.emit(SKILL_ID, _cooldown_left, GameConfig.emergency_repair_cooldown)
