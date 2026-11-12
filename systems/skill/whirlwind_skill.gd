class_name WhirlwindSkill
extends RefCounted
## Whirlwind: one 360 degree sweep around the caster that hits every enemy in range.

const ENEMY_GROUP: StringName = &"enemy"


## Returns how many enemies were hit. Distance is measured on the ground plane, centre to centre.
## damage_mult is the caster's skill damage multiplier (1.0 = none).
static func cast(caster: Node3D, data: SkillData, level: int, damage_mult: float = 1.0) -> int:
	if caster == null or not is_instance_valid(caster) or not caster.is_inside_tree() or data == null:
		return 0
	var radius := data.get_value(&"radius", level)
	var base_damage := data.get_value(&"damage", level)
	var radius_sq := radius * radius
	var hits := 0
	for node in caster.get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as Node3D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.get("is_dead") == true or not enemy.has_method("take_damage"):
			continue
		var offset := enemy.global_position - caster.global_position
		offset.y = 0.0
		if offset.length_squared() > radius_sq:
			continue
		var direction := offset.normalized() if not offset.is_zero_approx() else Vector3.FORWARD
		enemy.call(&"take_damage", DamageInfo.skill_hit(base_damage, damage_mult, data.damage_type, caster, direction))
		hits += 1
	return hits
