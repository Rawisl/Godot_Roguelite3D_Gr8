class_name RangeRing
extends MeshInstance3D
## Flat ring at a tower's attack range, drawn over walls. With a tower scene it also shows a
## translucent ghost of that tower on the slot: white when the build is allowed, red when it would
## seal the path. The ghost keeps the meshes only; no script, collision or animation runs from it.

@export var color: Color = Color(1, 1, 1, 0.6)
## Shown when a build would seal the path (ghost preview in the forbidden colour). Palette `danger`.
@export var blocked_color: Color = Color("#FF2D2D", 0.6)
## Palette `build_ring` (#FFFFFF 60% alpha) for the ghost of an allowed build, and `danger` when blocked.
@export var ghost_color: Color = Color(1, 1, 1, 0.4)
@export var ghost_blocked_color: Color = Color("#FF2D2D", 0.45)
@export var width: float = 0.12

var _ghost: Node3D = null

func _ready() -> void:
	visible = false
	mesh = TorusMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_color = color
	material_override = mat

func show_at(pos: Vector3, radius: float, blocked: bool = false, tower_scene: PackedScene = null) -> void:
	var torus := mesh as TorusMesh
	torus.outer_radius = radius
	torus.inner_radius = maxf(radius - width, 0.01)
	(material_override as StandardMaterial3D).albedo_color = blocked_color if blocked else color
	global_position = pos + Vector3.UP * 0.05
	scale = Vector3(1.0, 0.05, 1.0)
	visible = true
	_show_ghost(pos, blocked, tower_scene)

func hide_ring() -> void:
	visible = false
	_clear_ghost()

func _show_ghost(pos: Vector3, blocked: bool, tower_scene: PackedScene) -> void:
	_clear_ghost()
	if tower_scene == null or get_parent() == null:
		return
	var ghost := tower_scene.instantiate() as Node3D
	if ghost == null:
		return
	_strip_logic(ghost)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = ghost_blocked_color if blocked else ghost_color
	for node in ghost.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = mat
	get_parent().add_child(ghost)
	ghost.global_position = pos
	_ghost = ghost

func _clear_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null

## Removes everything that would act on its own: scripts, collisions and autoplay.
func _strip_logic(root: Node3D) -> void:
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for node in nodes:
		node.set_script(null)
		if node is CollisionObject3D:
			(node as CollisionObject3D).collision_layer = 0
			(node as CollisionObject3D).collision_mask = 0
		if node is AnimationPlayer:
			(node as AnimationPlayer).autoplay = ""
	root.process_mode = Node.PROCESS_MODE_DISABLED
