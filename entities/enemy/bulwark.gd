class_name Bulwark
extends Enemy

const STOMP_DAMAGE: int = 45
const STOMP_RADIUS: float = 3.0
const STOMP_KNOCKBACK: float = 3.0
const STOMP_STUN_DURATION: float = 1.5


func _ready() -> void:
	super._ready()
	add_to_group(&"boss")


func _execute_attack_action() -> void:
	execute_stomp()


func execute_stomp() -> void:
	if is_dead:
		return

	var radius_sq := STOMP_RADIUS * STOMP_RADIUS
	var tree := get_tree()
	if tree == null:
		return

	var targets: Array[Node3D] = []

	var commander := tree.get_first_node_in_group(&"commander") as Node3D
	if commander != null and is_instance_valid(commander):
		var diff := commander.global_position - global_position
		diff.y = 0.0
		if diff.length_squared() <= radius_sq:
			targets.append(commander)

	var structure_groups: Array[StringName] = [&"tower", &"fortress", &"barricade"]
	for grp in structure_groups:
		var nodes := tree.get_nodes_in_group(grp)
		for node in nodes:
			var node3d := node as Node3D
			if node3d != null and is_instance_valid(node3d) and not targets.has(node3d):
				var diff := node3d.global_position - global_position
				diff.y = 0.0
				if diff.length_squared() <= radius_sq:
					targets.append(node3d)

	for tgt in targets:
		if not is_instance_valid(tgt) or not tgt.has_method("take_damage"):
			continue

		var diff := tgt.global_position - global_position
		diff.y = 0.0
		var hit_dir := diff.normalized() if diff.length_squared() > 0.001 else Vector3.FORWARD

		var is_cmd := tgt.is_in_group(&"commander")
		var kb: float = STOMP_KNOCKBACK if is_cmd else 0.0
		var info := DamageInfo.new(STOMP_DAMAGE, Enums.DamageType.BLAST, self, kb, hit_dir)

		tgt.take_damage(info)

		if is_cmd and tgt.has_method("apply_stun"):
			tgt.apply_stun(STOMP_STUN_DURATION)
