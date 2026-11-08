class_name SwordWaveSkill
extends RefCounted
## Sword Wave: one instant strike along the aim. Hits every enemy in a rectangle that starts at the
## caster and runs range metres forward, width metres across. A barricade or a wall in the way
## shortens the rectangle. The flying slash is only a visual and is drawn by the VFX.

const ENEMY_GROUP: StringName = &"enemy"
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
	var dir := Vector3(aim_dir.x, 0.0, aim_dir.z)
	dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD
	var base_damage := data.get_value(&"damage", level)
	var half_width := data.get_value(&"width", level) * 0.5
	var reach := clear_distance(caster, dir, data.get_value(&"range", level))
	var hits := 0
	for node in caster.get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as Node3D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.get("is_dead") == true or not enemy.has_method("take_damage"):
			continue
		var offset := enemy.global_position - caster.global_position
		offset.y = 0.0
		var along := offset.dot(dir)
		var across := offset.dot(Vector3.UP.cross(dir))
		if along < 0.0 or along > reach or absf(across) > half_width:
			continue
		enemy.call(&"take_damage", DamageInfo.outgoing(base_damage, damage_mult, data.damage_type, caster, 0.0, dir))
		hits += 1
	return hits


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
