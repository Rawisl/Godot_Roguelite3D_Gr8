class_name WeaponData
extends Resource
## One sword variant: range, model, VFX and one effect with its numbers. Loaded from data/weapons/<id>.tres.

@export var id: StringName
@export var name_key: StringName  # locale key, UI calls tr(name_key)
@export var model: PackedScene
@export var vfx: PackedScene
## Multiplies the sword range of the base sword. 1.0 = unchanged.
@export var range_mult: float = 1.0
## What the weapon does on a hit: none, slow, chain, burn, rampage or swift.
@export var effect_id: StringName = &"none"
## Numbers of the effect, for example frost_slow_pct. Keys depend on effect_id.
@export var params: Dictionary[StringName, float] = {}


func get_param(key: StringName, default: float = 0.0) -> float:
	return params.get(key, default)
