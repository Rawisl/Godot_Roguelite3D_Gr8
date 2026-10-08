class_name DamageInfo
extends RefCounted

var amount: int = 0
var damage_type: Enums.DamageType = Enums.DamageType.SLASH
var source: Node = null
var knockback_force: float = 0.0
var hit_direction: Vector3 = Vector3.ZERO


func _init(
	p_amount: int = 0,
	p_damage_type: Enums.DamageType = Enums.DamageType.SLASH,
	p_source: Node = null,
	p_knockback_force: float = 0.0,
	p_hit_direction: Vector3 = Vector3.ZERO
) -> void:
	amount = p_amount
	damage_type = p_damage_type
	source = p_source
	knockback_force = p_knockback_force
	hit_direction = p_hit_direction
