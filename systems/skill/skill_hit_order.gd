extends RefCounted


static func targets(tree: SceneTree, caster: Node3D, aim: Vector3) -> Array[Node]:
	var enemies := tree.get_nodes_in_group(&"enemy")
	if caster == null or not caster.has_method(&"can_start_weapon_chain") or not caster.call(&"can_start_weapon_chain"):
		return enemies

	var ranked: Array[Dictionary] = []
	for node in enemies:
		var enemy := node as Node3D
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		var offset := enemy.global_position - caster.global_position
		offset.y = 0.0
		ranked.append({
			"enemy": enemy,
			"distance": offset.length(),
			"angle": offset.angle_to(aim) if not offset.is_zero_approx() else 0.0,
			"id": int(enemy.get(&"entity_id")) if &"entity_id" in enemy else enemy.get_instance_id(),
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(a.distance, b.distance):
			return a.distance < b.distance
		if not is_equal_approx(a.angle, b.angle):
			return a.angle < b.angle
		return a.id < b.id)

	var ordered: Array[Node] = []
	for entry in ranked:
		ordered.append(entry.enemy)
	return ordered


static func caster_aim(caster: Node3D) -> Vector3:
	return caster.get(&"aim_dir") if caster != null and &"aim_dir" in caster else Vector3.FORWARD
