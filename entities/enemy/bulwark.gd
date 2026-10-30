class_name Bulwark
extends Enemy

var stomp_damage: int:
	get:
		var boss_data := data as BossData
		return boss_data.stomp_damage if boss_data != null else 45

var stomp_radius: float:
	get:
		var boss_data := data as BossData
		return boss_data.stomp_radius if boss_data != null else 3.0

var stomp_knockback: float:
	get:
		var boss_data := data as BossData
		return boss_data.stomp_knockback if boss_data != null else 3.0

var stomp_stun_duration: float:
	get:
		var boss_data := data as BossData
		return boss_data.stomp_stun_duration if boss_data != null else 1.5

var current_phase: Enums.BossPhase = Enums.BossPhase.ARMORED


func _ready() -> void:
	super._ready()
	add_to_group(&"boss")


func get_resist(dmg_type: Enums.DamageType) -> float:
	var boss_data := data as BossData
	if boss_data == null:
		return 1.0
	return boss_data.get_resist(dmg_type, current_phase)


func _on_died() -> void:
	super._on_died()
	EventBus.boss_defeated.emit()


func _execute_attack_action() -> void:
	execute_stomp()


func execute_stomp() -> void:
	if is_dead:
		return

	var tree := get_tree()
	if tree == null:
		return

	var radius := stomp_radius
	var stomp_pos := global_position
	var targets: Array[Node3D] = []

	var commander := tree.get_first_node_in_group(&"commander") as Node3D
	if commander != null and is_instance_valid(commander):
		if _get_distance_to_target(commander, stomp_pos) <= radius:
			targets.append(commander)

	var structure_groups: Array[StringName] = [&"tower", &"fortress", &"barricade"]
	for grp in structure_groups:
		var nodes := tree.get_nodes_in_group(grp)
		for node in nodes:
			var node3d := node as Node3D
			if node3d != null and is_instance_valid(node3d) and not targets.has(node3d):
				if _get_distance_to_target(node3d, stomp_pos) <= radius:
					targets.append(node3d)

	for tgt in targets:
		if not is_instance_valid(tgt) or not tgt.has_method("take_damage"):
			continue

		var diff := tgt.global_position - global_position
		diff.y = 0.0
		var hit_dir := diff.normalized() if diff.length_squared() > 0.001 else Vector3.FORWARD

		var is_cmd := tgt.is_in_group(&"commander")
		var kb: float = stomp_knockback if is_cmd else 0.0
		var info := DamageInfo.new(stomp_damage, Enums.DamageType.BLAST, self, kb, hit_dir)

		tgt.take_damage(info)

		if is_cmd and tgt.has_method("apply_stun") and stomp_stun_duration > 0.0:
			tgt.apply_stun(stomp_stun_duration)


func _get_distance_to_target(target: Node3D, from_pos: Vector3) -> float:
	var col_shape := target.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape == null:
		for child in target.get_children():
			if child is CollisionShape3D:
				col_shape = child
				break

	if col_shape != null and col_shape.shape != null:
		if col_shape.shape is BoxShape3D:
			var box := col_shape.shape as BoxShape3D
			var half_extents := box.size * 0.5
			var local_pos := col_shape.global_transform.affine_inverse() * from_pos
			var clamped_local := Vector3(
				clampf(local_pos.x, -half_extents.x, half_extents.x),
				clampf(local_pos.y, -half_extents.y, half_extents.y),
				clampf(local_pos.z, -half_extents.z, half_extents.z)
			)
			var closest_world := col_shape.global_transform * clamped_local
			var diff := closest_world - from_pos
			diff.y = 0.0
			return diff.length()
		elif col_shape.shape is CylinderShape3D:
			var cyl := col_shape.shape as CylinderShape3D
			var local_pos := col_shape.global_transform.affine_inverse() * from_pos
			var local_xz := Vector2(local_pos.x, local_pos.z)
			var clamped_xz := local_xz.limit_length(cyl.radius)
			var clamped_y := clampf(local_pos.y, -cyl.height * 0.5, cyl.height * 0.5)
			var closest_world := col_shape.global_transform * Vector3(clamped_xz.x, clamped_y, clamped_xz.y)
			var diff := closest_world - from_pos
			diff.y = 0.0
			return diff.length()
		elif col_shape.shape is SphereShape3D:
			var sph := col_shape.shape as SphereShape3D
			var diff := col_shape.global_position - from_pos
			diff.y = 0.0
			return maxf(0.0, diff.length() - sph.radius)

	var diff := target.global_position - from_pos
	diff.y = 0.0
	return diff.length()
