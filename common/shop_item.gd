class_name ShopItem
extends Resource
## One permanent upgrade in the meta shop: its cost per level and what each level adds.
## Edited by hand in data/config/meta_shop/ (not generated from the balance sheet).

## Same id as the key in the save's meta.levels, for example &"FORT_HP".
@export var id: StringName
@export var name_key: StringName
## Effect line, filled with {value}: the total at a level, effect_base + level x effect_step.
@export var effect_key: StringName
## Fixed note under the effect, for limits such as the 3 Emergency repair charges. Optional.
@export var note_key: StringName
## Prestige cost of each level, in order. Its size is the max level.
@export var costs: PackedInt32Array = PackedInt32Array()
@export var effect_base: float = 0.0
@export var effect_step: float = 0.0

func get_max_level() -> int:
	return costs.size()

## Cost of the next level, -1 at max level.
func get_next_cost(level: int) -> int:
	return costs[level] if level >= 0 and level < costs.size() else -1

func get_effect(level: int) -> float:
	return effect_base + effect_step * clampi(level, 0, costs.size())
