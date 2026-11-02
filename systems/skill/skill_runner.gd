class_name SkillRunner
extends Node
## Active skill slots of the commander: keys 1-3, slot assignment, levels from
## reward_picked, and cooldowns in game time. Child of the commander; it never reads input
## itself, the commander passes a slot index once CommanderInput has chosen the command.

const SKILLS: Array[SkillData] = [
	preload("res://data/skills/whirlwind.tres"),
]
const SLOT_IDS: Array[StringName] = [&"skill_1", &"skill_2", &"skill_3"]

## Skill cards the runner knows about. Tests may replace it.
var catalog: Array[SkillData] = SKILLS.duplicate()
var state := RunSkillState.new()
var caster: Node3D
var stat_block: StatBlock

var _cooldowns: Dictionary[StringName, float] = {}


func _ready() -> void:
	reset()
	EventBus.run_started.connect(reset)
	EventBus.reward_picked.connect(_on_reward_picked)


func _exit_tree() -> void:
	if EventBus.run_started.is_connected(reset):
		EventBus.run_started.disconnect(reset)
	if EventBus.reward_picked.is_connected(_on_reward_picked):
		EventBus.reward_picked.disconnect(_on_reward_picked)


## Start of a run: empty slots, no cooldowns.
func reset() -> void:
	state.reset()
	_cooldowns.clear()


func _physics_process(delta: float) -> void:
	tick(delta)


## delta is game time (scaled by TimeManager, stopped by Pause).
func tick(delta: float) -> void:
	for skill_id in _cooldowns:
		var current: float = _cooldowns[skill_id]
		if current <= 0.0:
			continue
		var next := maxf(0.0, current - delta)
		_cooldowns[skill_id] = next
		if next == 0.0 or ceili(current) != ceili(next):
			var slot := state.active.find(skill_id)
			if slot != -1:
				_emit_cooldown(slot)


func get_skill_id(slot: int) -> StringName:
	return state.active[slot] if _valid_slot(slot) else &""


func get_level(slot: int) -> int:
	return state.get_level(get_skill_id(slot))


func get_cooldown_left(slot: int) -> float:
	var skill_id := get_skill_id(slot)
	return _cooldowns.get(skill_id, 0.0) if skill_id != &"" else 0.0


## False for an empty slot, a skill on cooldown, or when the commander cannot act:
## Commander mode, Stunned, dead.
func can_use(slot: int) -> bool:
	var skill_id := get_skill_id(slot)
	if skill_id == &"" or _cooldowns.get(skill_id, 0.0) > 0.0:
		return false
	return _caster_can_act()


## Casts the skill in the slot and starts its cooldown. Returns the SkillData used, null when refused.
func activate(slot: int) -> SkillData:
	if not can_use(slot):
		return null
	var data := _find(get_skill_id(slot))
	if data == null:
		return null
	var level := get_level(slot)
	var total := data.get_value(&"cooldown", level)
	_cooldowns[data.id] = total
	_emit_cooldown(slot)
	var mult := 1.0 + (stat_block.get_mul_total(&"skill_damage") if stat_block != null else 0.0)
	match data.id:
		&"whirlwind":
			WhirlwindSkill.cast(caster, data, level, mult)
	EventBus.skill_cast.emit(data.id, slot, level, caster.global_position, data.get_value(&"radius", level))
	return data


## Puts an active skill at an absolute level. A new skill takes the lowest empty slot.
## Returns the slot index, -1 when the card is not an owned-able active skill or no slot is free.
func set_skill_level(skill_id: StringName, new_level: int) -> int:
	var data := _find(skill_id)
	if data == null or data.kind != SkillData.Kind.ACTIVE:
		return -1
	var slot := state.active.find(skill_id)
	if slot == -1:
		slot = state.free_slot_index(SkillData.Kind.ACTIVE)
		if slot == -1:
			return -1
		state.active[slot] = skill_id
		if not _cooldowns.has(skill_id):
			_cooldowns[skill_id] = 0.0
	state.levels[skill_id] = clampi(new_level, 1, data.get_max_level())
	# A level-up keeps the time left but never above the new total.
	var total := data.get_value(&"cooldown", state.get_level(skill_id))
	if _cooldowns.get(skill_id, 0.0) > total:
		_cooldowns[skill_id] = total
		_emit_cooldown(slot)
	return slot


func _on_reward_picked(card_id: StringName, slot_kind: StringName, new_level: int) -> void:
	if String(slot_kind).to_upper() != "ACTIVE":
		return
	set_skill_level(card_id, new_level)


func _caster_can_act() -> bool:
	if caster == null:
		return true
	if caster.get("is_commander_mode") == true or caster.get("is_stunned") == true:
		return false
	return caster.get("is_dead") != true


func _find(skill_id: StringName) -> SkillData:
	for data in catalog:
		if data != null and data.id == skill_id:
			return data
	return null


func _valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < state.active.size()


func _emit_cooldown(slot: int) -> void:
	if not _valid_slot(slot) or slot >= SLOT_IDS.size():
		return
	var skill_id := state.active[slot]
	var data := _find(skill_id)
	if data == null:
		return
	EventBus.skill_cooldown_changed.emit(SLOT_IDS[slot], _cooldowns.get(skill_id, 0.0), data.get_value(&"cooldown", get_level(slot)))
