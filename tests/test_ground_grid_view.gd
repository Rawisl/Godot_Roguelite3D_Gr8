extends Node

## Visual check of the ground grid in the real corridor level: every grid slot shows its ring
## and its cell_id, plus the no_build_lane strip, spawn_zone, return_zone and command_post,
## seen from above. Keys: 1 top-down whole map, 2 game camera (overview size).

const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")
const REFERENCE_CELLS := [&"G_0_1", &"G_0_2", &"G_1_1", &"G_1_2"]

var _cam: Camera3D
var _level: Node3D

func _ready() -> void:
	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	await get_tree().process_frame

	var grid: GroundGrid = _level.get_node("Slots/GroundGrid")
	var mgr: SlotManager = _level.get_node("Slots")
	mgr.set_rings_visible(true)
	for id in grid.cells:
		var slot: Slot = grid.cells[id]
		_label(slot.global_position + Vector3(0, 0.1, 0), String(id),
				Color("#E8C25A") if id in REFERENCE_CELLS else Color.WHITE, 26)

	var data := grid.grid_data
	var lane_y := 0.03
	_flat_box(Vector3(0, lane_y, 0), Vector2(40, data.no_build_lane_width), Color(0.9, 0.3, 0.3, 0.25))
	_label(Vector3(9, 0.1, 0), "no_build_lane %.0f m" % data.no_build_lane_width, Color("#FF9A9A"), 32)
	var spawn: Area3D = grid.spawn_zone
	var box := (spawn.get_child(0) as CollisionShape3D).shape as BoxShape3D
	_flat_box(Vector3(spawn.global_position.x, 0.04, spawn.global_position.z), Vector2(box.size.x, box.size.z), Color(0.5, 0.3, 0.8, 0.3))
	_label(spawn.global_position + Vector3(0, -1.9, -6), "spawn_zone", Color("#D9BFF2"), 32)
	var ret: Area3D = grid.return_zone
	var cyl := (ret.get_child(0) as CollisionShape3D).shape as CylinderShape3D
	_flat_disc(Vector3(ret.global_position.x, 0.05, ret.global_position.z), cyl.radius, Color(0.3, 0.6, 1.0, 0.3))
	_label(Vector3(ret.global_position.x, 0.1, ret.global_position.z), "return_zone", Color("#9FC8FF"), 32)
	_label(grid.command_post.global_position + Vector3(0, 0.5, 0), "command_post", Color("#9FFFB0"), 32)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(_cam)
	_cam.current = true
	_view(1)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_view(1)
		elif event.keycode == KEY_2:
			_view(2)


func _view(n: int) -> void:
	if n == 1:
		_cam.size = 22.0
		_cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-90), 0, 0)), Vector3(0, 40, 0))
	else:
		var bounds: CameraBounds = _level.get_node("CameraBounds")
		_cam.size = 26.0
		_cam.global_basis = Basis.from_euler(Vector3(deg_to_rad(-45), deg_to_rad(20), 0))
		_cam.global_position = bounds.global_position + _cam.global_basis.z * 30.0


func _label(at: Vector3, text: String, color: Color, size: int) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.font_size = size
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.012
	l.position = at
	add_child(l)


func _flat_box(at: Vector3, size: Vector2, color: Color) -> void:
	var m := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	m.mesh = plane
	m.material_override = _mat(color)
	m.position = at
	add_child(m)


func _flat_disc(at: Vector3, radius: float, color: Color) -> void:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	m.mesh = cyl
	m.material_override = _mat(color)
	m.position = at
	add_child(m)


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	return mat
