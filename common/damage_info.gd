class_name DamageInfo
extends RefCounted

var amount: int = 0
var damage_type: Enums.DamageType = Enums.DamageType.SLASH
var source: Node = null
var knockback_force: float = 0.0
var hit_direction: Vector3 = Vector3.ZERO
var hit_by_commander: bool = false
## Pre-multiplier damage and the attacker's total dealt multiplier, read by DamageCalc.resolve.
var raw: float = 0.0
var dealt_mult: float = 1.0
var is_dot: bool = false
## Written by DamageCalc.resolve.
var resist: float = 1.0
var immune: bool = false


func _init(
	p_amount: int = 0,
	p_damage_type: Enums.DamageType = Enums.DamageType.SLASH,
	p_source: Variant = null,
	p_knockback_force: float = 0.0,
	p_hit_direction: Vector3 = Vector3.ZERO,
	p_hit_by_commander: bool = false
) -> void:
	amount = p_amount
	raw = float(p_amount)
	damage_type = p_damage_type
	source = (p_source as Node) if is_instance_valid(p_source) else null
	knockback_force = p_knockback_force
	hit_direction = p_hit_direction
	hit_by_commander = p_hit_by_commander or _check_is_commander_source(p_source)


## Unresolved hit: the receiver applies resist, taken_mult and rounding once.
static func outgoing(
	p_raw: float,
	p_dealt_mult: float,
	p_damage_type: Enums.DamageType,
	p_source: Variant = null,
	p_knockback_force: float = 0.0,
	p_hit_direction: Vector3 = Vector3.ZERO,
	p_is_dot: bool = false
) -> DamageInfo:
	var info := DamageInfo.new(0, p_damage_type, p_source, p_knockback_force, p_hit_direction)
	info.raw = p_raw
	info.dealt_mult = p_dealt_mult
	info.is_dot = p_is_dot
	info.amount = maxi(1, roundi(p_raw * p_dealt_mult)) if p_raw > 0.0 else 0
	return info


func is_from_commander() -> bool:
	if hit_by_commander:
		return true
	if source != null and is_instance_valid(source) and source.is_in_group(&"commander"):
		return true
	return false


func _check_is_commander_source(p_source: Variant) -> bool:
	if p_source is Node and is_instance_valid(p_source):
		return p_source.is_in_group(&"commander")
	if (p_source is String or p_source is StringName) and str(p_source).to_lower() == "commander":
		return true
	return false
