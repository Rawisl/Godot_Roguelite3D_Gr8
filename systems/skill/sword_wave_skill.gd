class_name SwordWaveSkill
extends RefCounted
## Sword Wave: one instant strike along the aim. Hits every enemy in a rectangle that starts at the
## caster and runs range metres forward, width metres across. A barricade or a wall in the way
## shortens the rectangle, and so does the edge of the spawn zone. The flying slash is only a visual and is drawn by the VFX.

const SkillHitOrder = preload("res://systems/skill/skill_hit_order.gd")
const WORLD_MASK := 1
## Height of the blocker ray above the caster's feet.
const RAY_HEIGHT := 0.6
## A ray that keeps hitting towers (not barricades) is cut off after this many hits.
const MAX_RAY_HITS := 8


## Returns how many enemies were hit. aim_dir is flattened to the ground; a zero vector aims forward.
## damage_mult is the caster's skill damage multiplier (1.0 = none).
static func cast(caster: Node3D, data: SkillData, level: int, damage_mult: float, aim_dir: Vector3) -> int:
	if caster == null or not is_instance_valid(caster) or not caster.is_inside_tree() or data == null:
		return 0
	return strike(caster, aim_dir, data.get_value(&"damage", level), data.get_value(&"width", level),
			data.get_value(&"range", level), 0.0, data.damage_type, damage_mult)


## Hits every enemy whose distance along dir is in [start_offset, start_offset + reach] and within half
## the width to either side. The wall, barricade and spawn zone clip run over start_offset + reach from the
## caster, so a blocker between the caster and start_offset also stops the strike.
## Returns how many enemies were hit. dir is flattened to the ground; a zero vector aims forward.
static func strike(caster: Node3D, dir: Vector3, base_damage: float, width: float, reach: float,
		start_offset: float, damage_type: Enums.DamageType, damage_mult: float) -> int:
	if caster == null or not is_instance_valid(caster) or not caster.is_inside_tree():
		return 0
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
	var half_width := width * 0.5
	var end := clear_distance(caster, flat, start_offset + reach)
	end = minf(end, spawn_zone_distance(caster, flat, end))
	var hits := 0
	for node in SkillHitOrder.targets(caster.get_tree(), caster, flat):
		var enemy := node as Node3D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.get("is_dead") == true or not enemy.has_method("take_damage"):
			continue
		var offset := enemy.global_position - caster.global_position
		offset.y = 0.0
		var along := offset.dot(flat)
		var across := offset.dot(Vector3.UP.cross(flat))
		if along < start_offset or along > end or absf(across) > half_width:
			continue
		enemy.call(&"take_damage", DamageInfo.skill_hit(base_damage, damage_mult, damage_type, caster, flat))
		hits += 1
	return hits


## Distance along dir to the first spawn zone edge, limit when the path stays clear of every zone.
static func spawn_zone_distance(caster: Node3D, dir: Vector3, limit: float) -> float:
	var result := limit
	for node in caster.get_tree().get_nodes_in_group(&"spawn_zone"):
		var shape_node := SkillGeometry.find_box_shape(node as Area3D)
		if shape_node == null:
			continue
		var origin := shape_node.to_local(caster.global_position)
		var local_dir := shape_node.global_transform.basis.inverse() * dir
		var half := (shape_node.shape as BoxShape3D).size * 0.5
		var enter := 0.0
		var leave := INF
		for axis in [Vector3.AXIS_X, Vector3.AXIS_Z]:
			if absf(local_dir[axis]) < 0.00001:
				if absf(origin[axis]) > half[axis]:
					leave = -1.0
				continue
			var t1: float = (-half[axis] - origin[axis]) / local_dir[axis]
			var t2: float = (half[axis] - origin[axis]) / local_dir[axis]
			enter = maxf(enter, minf(t1, t2))
			leave = minf(leave, maxf(t1, t2))
		if enter <= leave and enter < result:
			result = enter
	return result


## How far the wave gets before the first wall or barricade. Towers other than barricades let it through.
static func clear_distance(caster: Node3D, dir: Vector3, distance: float) -> float:
	var world := caster.get_world_3d()
	if world == null or distance <= 0.0:
		return distance
	var from := caster.global_position + Vector3.UP * RAY_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * distance, WORLD_MASK)
	var excluded: Array[RID] = []
	for i in MAX_RAY_HITS:
		query.exclude = excluded
		var hit := world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return distance
		var collider := hit.get("collider") as Node
		if collider != null and collider.is_in_group(&"tower") and not collider.is_in_group(&"barricade"):
			excluded.append(hit["rid"])
			continue
		return from.distance_to(hit["position"])
	return distance
