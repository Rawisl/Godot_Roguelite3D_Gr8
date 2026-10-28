class_name SkillData
extends Resource

enum Kind { ACTIVE, PASSIVE, STAT }

@export var id: StringName
@export var kind: Kind = Kind.ACTIVE
@export var name_key: StringName  # locale key, UI calls tr(name_key)
@export var description_key: StringName
@export var icon: Texture2D
@export var damage_type: Enums.DamageType = Enums.DamageType.SLASH  # only read for ACTIVE
@export var tags: Array[StringName] = []
## 0 = use GameConfig (skill_max_level, or stat_max_stacks for STAT).
@export var max_level_override: int = 0
## Run flag that must be true before the card can be offered, e.g. &"heal_station_built". Empty = always.
# TODO(week 8): RewardOfferGenerator filters by this flag and GameConfig reward weights.
@export var requires_flag: StringName = &""
## Per-level numbers: key -> one value per level (index 0 = level 1).
@export var values: Dictionary[StringName, PackedFloat32Array] = {}

func get_max_level() -> int:
	if max_level_override > 0:
		return max_level_override
	return GameConfig.stat_max_stacks if kind == Kind.STAT else GameConfig.skill_max_level

## Level 0 or below means the skill is not owned and gives 0.0; levels past the table read the last value.
func get_value(key: StringName, level: int) -> float:
	if not values.has(key):
		push_warning("SkillData '%s' has no value '%s'" % [id, key])
		return 0.0
	var arr: PackedFloat32Array = values[key]
	if arr.is_empty() or level < 1:
		return 0.0
	return arr[mini(level, arr.size()) - 1]

## ACTIVE and PASSIVE take a slot; STAT only stacks.
func is_slotted() -> bool:
	return kind != Kind.STAT

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("empty id")
	var max_level := get_max_level()
	for key in values:
		var size: int = values[key].size()
		if size != max_level:
			errors.append("'%s' has %d values, expected %d" % [key, size, max_level])
	return errors
