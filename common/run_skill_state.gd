# TODO(week 10): move into RunState once it exists (RunState).
class_name RunSkillState
extends RefCounted

var active: Array[StringName] = []  # size GameConfig.skill_slots_active, &"" = empty slot
var passive: Array[StringName] = []
var levels: Dictionary[StringName, int] = {}  # skill or stat id -> level / stacks

func _init() -> void:
	reset()

func reset() -> void:
	active.clear()
	passive.clear()
	active.resize(GameConfig.skill_slots_active)
	passive.resize(GameConfig.skill_slots_passive)
	active.fill(&"")
	passive.fill(&"")
	levels.clear()

func get_level(id: StringName) -> int:
	return levels.get(id, 0)

func is_maxed(data: SkillData) -> bool:
	return get_level(data.id) >= data.get_max_level()

## Lowest empty slot index of the matching kind, -1 when full or for STAT.
func free_slot_index(kind: SkillData.Kind) -> int:
	match kind:
		SkillData.Kind.ACTIVE:
			return active.find(&"")
		SkillData.Kind.PASSIVE:
			return passive.find(&"")
	return -1

## Slotted skills already in a slot can level up; a slotted skill without a slot, owned or not, needs a free slot.
func can_take(data: SkillData) -> bool:
	if is_maxed(data):
		return false
	if not data.is_slotted() or _slot_array(data.kind).has(data.id):
		return true
	return free_slot_index(data.kind) != -1

## Pure state change, no signal. Returns {"slot_kind": &"ACTIVE"/&"PASSIVE"/&"STAT", "slot_index": int, "new_level": int}, {} when refused.
# TODO(week 9): apply_pick emits reward_picked and skill_slots_changed after take().
func take(data: SkillData) -> Dictionary:
	if not can_take(data):
		return {}
	var slot_index := -1
	if data.is_slotted():
		slot_index = _slot_array(data.kind).find(data.id)
		if slot_index == -1:
			slot_index = free_slot_index(data.kind)
			if slot_index == -1:
				return {}
			_slot_array(data.kind)[slot_index] = data.id
	var new_level := get_level(data.id) + 1
	levels[data.id] = new_level
	return {
		"slot_kind": StringName(SkillData.Kind.keys()[data.kind]),
		"slot_index": slot_index,
		"new_level": new_level,
	}

func _slot_array(kind: SkillData.Kind) -> Array[StringName]:
	return active if kind == SkillData.Kind.ACTIVE else passive

func to_dict() -> Dictionary:
	return {"active": active.duplicate(), "passive": passive.duplicate(), "levels": levels.duplicate()}

func from_dict(d: Dictionary) -> void:
	reset()
	for i in mini(active.size(), d.get("active", []).size()):
		active[i] = StringName(d["active"][i])
	for i in mini(passive.size(), d.get("passive", []).size()):
		passive[i] = StringName(d["passive"][i])
	var saved: Dictionary = d.get("levels", {})
	for key in saved:
		levels[StringName(key)] = int(saved[key])
