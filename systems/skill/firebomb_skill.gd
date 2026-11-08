class_name FirebombSkill
extends RefCounted
## Firebomb: a bomb lands at the aim point and leaves a burning zone (see FirebombZone).
## The landing point is the mouse point held to the cast range and kept out of the spawn zone.


## Where the bomb lands for a given mouse point on the ground. A point that is not finite (the
## mouse has not been seen yet) lands the full cast range ahead of the caster.
static func landing_point(caster: Node3D, aim_point: Vector3, aim_dir: Vector3 = Vector3.FORWARD) -> Vector3:
	var origin := caster.global_position
	var max_range: float = GameConfig.skill_firebomb_cast_range
	var target := aim_point
	if not aim_point.is_finite():
		var flat := Vector3(aim_dir.x, 0.0, aim_dir.z)
		target = origin + (flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD) * max_range
	target.y = origin.y
	var offset := target - origin
	if offset.length() > max_range:
		target = origin + offset.normalized() * max_range
	for node in caster.get_tree().get_nodes_in_group(&"spawn_zone"):
		target = _push_out_of_zone(node as Area3D, target)
	return target


## Creates the zone at point and adds it beside the caster. Returns it, null when nothing was cast.
static func cast(caster: Node3D, data: SkillData, level: int, damage_mult: float, point: Vector3) -> FirebombZone:
	if caster == null or not is_instance_valid(caster) or not caster.is_inside_tree() or data == null:
		return null
	var parent := caster.get_parent()
	if parent == null:
		return null
	var zone := FirebombZone.new()
	zone.name = "FirebombZone"
	zone.setup(caster, data, level, damage_mult)
	parent.add_child(zone)
	zone.global_position = point
	return zone


## First box shape among the children of an area, whatever the node is called. Null when there is none.
static func find_box_shape(area: Area3D) -> CollisionShape3D:
	if area == null:
		return null
	for child in area.get_children():
		var shape_node := child as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			return shape_node
	return null


## A point inside the zone box moves to the nearest face of the box; any other point stays.
static func _push_out_of_zone(area: Area3D, point: Vector3) -> Vector3:
	if area == null:
		return point
	var shape_node := find_box_shape(area)
	if shape_node == null:
		return point
	var local := shape_node.to_local(point)
	var half := (shape_node.shape as BoxShape3D).size * 0.5
	if absf(local.x) >= half.x or absf(local.z) >= half.z:
		return point
	var to_x := half.x - absf(local.x)
	var to_z := half.z - absf(local.z)
	if to_x <= to_z:
		local.x = half.x * signf(local.x if local.x != 0.0 else -1.0)
	else:
		local.z = half.z * signf(local.z if local.z != 0.0 else -1.0)
	var pushed := shape_node.to_global(local)
	pushed.y = point.y
	return pushed
