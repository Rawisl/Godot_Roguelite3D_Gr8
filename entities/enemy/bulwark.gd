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

	var towers := tree.get_nodes_in_group(&"tower")
	for tw in towers:
		var tw_node := tw as Node3D
		if tw_node != null and is_instance_valid(tw_node):
			var diff := tw_node.global_position - global_position
			diff.y = 0.0
			if diff.length_squared() <= radius_sq:
				targets.append(tw_node)

	var fortresses := tree.get_nodes_in_group(&"fortress")
	for ft in fortresses:
		var ft_node := ft as Node3D
		if ft_node != null and is_instance_valid(ft_node):
			var diff := ft_node.global_position - global_position
			diff.y = 0.0
			if diff.length_squared() <= radius_sq:
				targets.append(ft_node)

	var barricades := tree.get_nodes_in_group(&"barricade")
	for bc in barricades:
		var bc_node := bc as Node3D
		if bc_node != null and is_instance_valid(bc_node):
			var diff := bc_node.global_position - global_position
			diff.y = 0.0
			if diff.length_squared() <= radius_sq:
				targets.append(bc_node)

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
