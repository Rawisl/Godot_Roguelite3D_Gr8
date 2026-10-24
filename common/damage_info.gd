class_name DamageInfo
extends RefCounted

var amount: int = 0
var damage_type: Enums.DamageType = Enums.DamageType.SLASH
var source: Node = null
var knockback_force: float = 0.0
var hit_direction: Vector3 = Vector3.ZERO
var hit_by_commander: bool = false


func _init(
	p_amount: int = 0,
	p_damage_type: Enums.DamageType = Enums.DamageType.SLASH,
	p_source: Variant = null,
	p_knockback_force: float = 0.0,
	p_hit_direction: Vector3 = Vector3.ZERO,
	p_hit_by_commander: bool = false
) -> void:
	amount = p_amount
	damage_type = p_damage_type
	source = (p_source as Node) if is_instance_valid(p_source) else null
	knockback_force = p_knockback_force
	hit_direction = p_hit_direction
	hit_by_commander = p_hit_by_commander or _check_is_commander_source(p_source)


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
