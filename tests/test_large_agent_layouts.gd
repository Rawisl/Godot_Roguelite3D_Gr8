extends Node3D
## Large agents on the real corridor with three grid buildings. Every legal layout of three
## ground buildings is listed with the build rule (the 3.2 m path check); the tightest ones (those
## that would fail with a wider margin) are built for real, the navmesh is rebaked, and a 1.6 m
## agent must still reach both the Fortress gate and the Bulwark standing point on the
## large-agent navmesh. Not shipped. Headless: prints a summary and quits. With F6: shows the
## corridor from above with each layout and the agent path while it runs (about 2 minutes), then
## stays open.

const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")
const ARROW: TowerData = preload("res://data/towers/arrow.tres")
const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
## Extra widths tried in turn; the tight layouts are the ones refused at the first extra width
## that refuses any.
const TIGHT_MARGINS: Array[float] = [0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0]
## Layouts built for real, spread over the tight ones.
const SAMPLES := 8
## Legal layouts scanned for the tight ones, taken evenly from all of them (there are ~50 000).
const SCAN := 4000
const WAIT_FRAMES := 300
const MAP_SYNC_FRAMES := 10
const GOAL_TOLERANCE := 0.3
const GATE_TOLERANCE := 1.0

var _pass := 0
var _fail := 0
var _level: Node3D
var _service: BuildService
var _rebaker: NavRebaker
var _large: NavigationRegion3D
var _grid: GroundGrid
var _label: Label
var _path_mesh: MeshInstance3D


func _ready() -> void:
	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	var gold := GoldManager.new()
	add_child(gold)
	_service = BuildService.new()
	_service.towers = [ARROW]
	_service.tower_scenes = {&"arrow": ARROW_SCENE}
	add_child(_service)
	_rebaker = _level.get_node("Slots/NavRebaker") as NavRebaker
	_large = _level.get_node("NavigationRegionLarge") as NavigationRegion3D
	_grid = _level.get_node("Slots/GroundGrid") as GroundGrid
	_make_view()
	for i in 5:
		await get_tree().physics_frame
	gold.gold = 1000000
	EventBus.state_changed.emit(&"PREP")

	_check("the large-agent navmesh is for a 1.6 m agent", is_equal_approx(_large.navigation_mesh.agent_radius, 1.6) or _large.navigation_mesh.agent_radius >= 1.6)
	_status("Listing the legal layouts of three ground buildings...")
	var layouts: Array = await _tight_layouts()
	_check("there are legal three-building layouts to try (%d tight)" % layouts.size(), not layouts.is_empty())
	var step := maxi(1, layouts.size() / SAMPLES)
	var tried := 0
	for i in range(0, layouts.size(), step):
		if tried >= SAMPLES:
			break
		await _try(layouts[i])
		tried += 1

	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	_status("Done: %d passed, %d failed" % [_pass, _fail])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if _fail > 0 else 0)


## Every set of three valid cells the build rule allows; the tight ones are those refused at the
## smallest extra width that refuses any: the narrowest lanes a player can leave.
func _tight_layouts() -> Array:
	var data := _grid.grid_data
	var cells := _grid.get_valid_cells()
	var spawn := _grid.spawn_zone.global_position
	var gate := _gate()
	var width := GameConfig.path_check_min_width
	var goals: Array[Vector3] = [data.gate_goal(gate, width), _grid.get_boss_point()]
	var legal: Array = []
	for i in cells.size():
		for j in range(i + 1, cells.size()):
			for k in range(j + 1, cells.size()):
				var obstacles: Array[Vector2i] = [cells[i], cells[j], cells[k]]
				if data.is_path_open(obstacles, spawn, gate, goals, width):
					legal.append(obstacles)
		# Let the window draw between rows of the scan.
		_status("Listing layouts: %d / %d cells, %d legal so far" % [i + 1, cells.size(), legal.size()])
		await get_tree().process_frame
	var scan: Array = []
	var stride := maxi(1, legal.size() / SCAN)
	for i in range(0, legal.size(), stride):
		scan.append(legal[i])
	for margin in TIGHT_MARGINS:
		_status("Looking for the tightest layouts (%.1f m more width)..." % margin)
		await get_tree().process_frame
		var w := width + margin
		var wide_goals: Array[Vector3] = [data.gate_goal(gate, w), _grid.get_boss_point()]
		var tight: Array = []
		for obstacles: Array[Vector2i] in scan:
			if not data.is_path_open(obstacles, spawn, gate, wide_goals, w):
				tight.append(obstacles)
		if not tight.is_empty():
			print("[layouts] %d cells, %d legal layouts, %d scanned, %d refused with %.1f m more width" % [cells.size(), legal.size(), scan.size(), tight.size(), margin])
			return tight
	print("[layouts] %d cells, %d legal layouts, none refused even with %.1f m more" % [cells.size(), legal.size(), TIGHT_MARGINS[-1]])
	return legal


func _try(cells: Array) -> void:
	await _clear_ground()
	var ids: Array[StringName] = []
	for c: Vector2i in cells:
		ids.append(StringName(GridData.cell_id(c.x, c.y)))
	var built := 0
	for id in ids:
		if _service.build(id, &"arrow", 1):
			built += 1
	_check("%s: all three built" % [ids], built == 3)
	_status("Layout %s: rebaking the navmesh..." % [ids])
	_check("%s: rebake finished" % [ids], await _wait_rebake())
	var map := _level.get_world_3d().navigation_map
	var spawn := _grid.spawn_zone.global_position
	var boss_point := _grid.get_boss_point()
	var gate_goal := _grid.grid_data.gate_goal(_gate(), GameConfig.path_check_min_width)
	var to_boss := NavigationServer3D.map_get_path(map, spawn, boss_point, true, _large.navigation_layers)
	var to_gate := NavigationServer3D.map_get_path(map, spawn, gate_goal, true, _large.navigation_layers)
	var boss_gap := _end_gap(to_boss, boss_point)
	var gate_gap := _end_gap(to_gate, gate_goal)
	_show_path(to_boss)
	_status("Layout %s: Bulwark point %.2f m off, gate %.2f m off" % [ids, boss_gap, gate_gap])
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(1.5).timeout
	_check("%s: a 1.6 m agent reaches the Bulwark point (%.2f m off)" % [ids, boss_gap], boss_gap <= GOAL_TOLERANCE)
	_check("%s: a 1.6 m agent reaches the gate (%.2f m off)" % [ids, gate_gap], gate_gap <= GATE_TOLERANCE)


func _end_gap(path: PackedVector3Array, goal: Vector3) -> float:
	if path.is_empty():
		return INF
	var end := path[path.size() - 1]
	return Vector2(end.x - goal.x, end.z - goal.z).length()


func _gate() -> Vector3:
	var lane := _grid.lane
	return lane.global_transform * lane.curve.get_point_position(lane.curve.point_count - 1)


func _clear_ground() -> void:
	for node in _grid.cells.values():
		var slot := node as Slot
		if slot.state == Enums.SlotState.OCCUPIED:
			_service.sell(slot.slot_id)
		elif slot.state == Enums.SlotState.RUINED:
			_service.clear_rubble(slot.slot_id)
	await _wait_rebake()


func _wait_rebake() -> bool:
	var waited := 0
	while not _rebaker.is_idle():
		if waited >= WAIT_FRAMES:
			return false
		await get_tree().physics_frame
		waited += 1
	for i in MAP_SYNC_FRAMES:
		await get_tree().physics_frame
	return true


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("OK   ", label)
	else:
		_fail += 1
		print("FAIL ", label)


## A camera over the corridor, a status line and a line for the agent path; nothing headless.
func _make_view() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 30.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 40, 0.01), Vector3.ZERO, Vector3.FORWARD)
	cam.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_label)
	_path_mesh = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.no_depth_test = true
	_path_mesh.material_override = mat
	add_child(_path_mesh)


func _status(text: String) -> void:
	if _label != null:
		_label.text = text


## The 1.6 m agent's path to the Bulwark point, drawn as a yellow line.
func _show_path(path: PackedVector3Array) -> void:
	if _path_mesh == null or path.size() < 2:
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in path:
		mesh.surface_add_vertex(p + Vector3.UP * 0.3)
	mesh.surface_end()
	_path_mesh.mesh = mesh
