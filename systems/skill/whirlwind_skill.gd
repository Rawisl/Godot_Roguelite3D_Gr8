class_name WhirlwindSkill
extends RefCounted
## Whirlwind: one 360 degree sweep around the caster that hits every enemy in range.

const SkillHitOrder = preload("res://systems/skill/skill_hit_order.gd")


## Returns how many enemies were hit. Distance is measured on the ground plane, centre to centre.
## damage_mult is the caster's skill damage multiplier (1.0 = none).
static func cast(caster: Node3D, data: SkillData, level: int, damage_mult: float = 1.0) -> int:
	if caster == null or not is_instance_valid(caster) or not caster.is_inside_tree() or data == null:
		return 0
	var base_damage := data.get_value(&"damage", level)
	var hits := 0
	for enemy in targets_in_radius(caster, data.get_value(&"radius", level)):
		enemy.call(&"take_damage", DamageInfo.skill_hit(base_damage, damage_mult, data.damage_type, caster, hit_direction(caster, enemy)))
		hits += 1
	return hits


## Live, damageable enemies within radius of the caster on the ground plane, in hit order.
static func targets_in_radius(caster: Node3D, radius: float) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if caster == null or not is_instance_valid(caster) or not caster.is_inside_tree():
		return result
	var radius_sq := radius * radius
	for node in SkillHitOrder.targets(caster.get_tree(), caster, SkillHitOrder.caster_aim(caster)):
		var enemy := node as Node3D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.get("is_dead") == true or not enemy.has_method("take_damage"):
			continue
		var offset := enemy.global_position - caster.global_position
		offset.y = 0.0
		if offset.length_squared() > radius_sq:
			continue
		result.append(enemy)
	return result


## Ground-plane direction from the caster to the enemy, forward when they overlap.
static func hit_direction(caster: Node3D, enemy: Node3D) -> Vector3:
	var offset := enemy.global_position - caster.global_position
	offset.y = 0.0
	return offset.normalized() if not offset.is_zero_approx() else Vector3.FORWARD
