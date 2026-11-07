extends Node

## Automated test runner for the 23.5 m corridor (levels/corridor/level.tscn):
## - the walls stand at the corridor edges and the floor reaches them, so the commander can walk
##   the full width
## - the spawn zone is the last 12 m of the corridor and covers its full width
## - the Fortress and its wing walls close the corridor end: nothing walks round the Fortress
## - both navmeshes reach the gate (normal agents) and boss_melee_point (large agent) from
##   anywhere across the spawn zone
## - lane_curve, the return zone and the command post sit inside the corridor at the gate
## - Grunts spawned across the spawn zone all reach the gate
## Headless it runs the checks and quits.

const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")
const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const HALF_WIDTH := 11.75
const SPAWN_LENGTH := 12.0
const NAV_LAYER_NORMAL := 1
const NAV_LAYER_LARGE := 2

@export var quit_when_done := DisplayServer.get_name() == "headless"

var passes: int = 0
var fails: int = 0
var _level: Node3D


func _ready() -> void:
	print("\n=======================================================")
	print("       CORRIDOR LAYOUT TEST                            ")
	print("=======================================================")
	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	# The navigation map only answers path queries once it has synced the level's regions.
	var map := _level.get_world_3d().navigation_map
	var start_iteration := NavigationServer3D.map_get_iteration_id(map)
	for i in 120:
		await get_tree().physics_frame
		if i >= 4 and NavigationServer3D.map_get_iteration_id(map) > start_iteration:
			break

	test_walls_and_floor()
	test_spawn_zone()
	test_corridor_end_closed()
	test_nav_paths()
	test_markers()
	await test_grunts_reach_gate()

	Engine.time_scale = 1.0
	_level.queue_free()
	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")
	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


#region Tests
func test_walls_and_floor() -> void:
	var walls_ok := true
	var floor_ok := true
	for x in [-12.0, 0.0, 10.0, 19.0]:
		for side in [-1.0, 1.0]:
			var hit := _ray(Vector3(x, 1, 0), Vector3(x, 1, side * 20.0))
			walls_ok = walls_ok and not hit.is_empty() and absf(absf(hit.position.z) - HALF_WIDTH) < 0.01
			var down := _ray(Vector3(x, 2, side * (HALF_WIDTH - 0.25)), Vector3(x, -2, side * (HALF_WIDTH - 0.25)))
			floor_ok = floor_ok and not down.is_empty() and absf(down.position.y) < 0.01
	assert_true(walls_ok, "both walls stand 11.75 m from the centre line: corridor 23.5 m wide")
	assert_true(floor_ok, "the floor reaches both walls, so the commander can walk the full width")


func test_spawn_zone() -> void:
	var zone: Area3D = _level.get_node("SpawnZone")
	var box := (zone.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	var near_end := zone.global_position.x - box.size.x * 0.5
	var far_end := zone.global_position.x + box.size.x * 0.5
	var floor_end := _ray(Vector3(30, 1, 0), Vector3(0, 1, 0))
	assert_true(box.size.z >= HALF_WIDTH * 2.0 and absf(zone.global_position.z) < 0.01,
		"the spawn zone covers the full corridor width (%.2f m)" % box.size.z)
	assert_true(is_equal_approx(box.size.x, SPAWN_LENGTH) and far_end >= 19.5,
		"the spawn zone is the last 12 m of the corridor (%.1f to %.1f)" % [near_end, far_end])
	assert_true(floor_end.is_empty(), "nothing blocks the corridor between the spawn zone and the centre")


func test_corridor_end_closed() -> void:
	var closed := true
	for z in [-11.5, -9.5, -8.2, 0.0, 8.2, 9.5, 11.5]:
		var hit := _ray(Vector3(0, 1, z), Vector3(-25, 1, z))
		closed = closed and not hit.is_empty() and hit.position.x > -15.1 and hit.position.x < -14.9
	assert_true(closed, "the Fortress and its wing walls close the corridor end across the full width")
	var behind := _path(Vector3(14, 0, 9), Vector3(-19, 0, 10), NAV_LAYER_NORMAL)
	assert_true(behind.is_empty() or behind[-1].x > -15.6,
		"no navmesh path leads round the Fortress")


func test_nav_paths() -> void:
	var gate := Vector3(-14.3, 0, 0)
	var boss_point: Marker3D = _level.get_node("Markers/BossMeleePoint")
	var normal_ok := true
	var large_ok := true
	for z in [-10.5, 0.0, 10.5]:
		var from := Vector3(15, 0, z)
		var to_gate := _path(from, gate, NAV_LAYER_NORMAL)
		normal_ok = normal_ok and not to_gate.is_empty() and _flat(to_gate[-1]).distance_to(_flat(gate)) < 0.6
		var to_point := _path(from, boss_point.global_position, NAV_LAYER_LARGE)
		large_ok = large_ok and not to_point.is_empty() \
			and _flat(to_point[-1]).distance_to(_flat(boss_point.global_position)) < 0.6
	assert_true(normal_ok, "normal navmesh reaches the gate from across the spawn zone")
	assert_true(large_ok, "large-agent navmesh reaches boss_melee_point from across the spawn zone")
	var large_region: NavigationRegion3D = _level.get_node("NavigationRegionLarge")
	var zs := Array(large_region.navigation_mesh.get_vertices()).filter(func(v: Vector3) -> bool: return v.y < 1.0).map(func(v: Vector3) -> float: return v.z)
	assert_true(zs.max() - zs.min() >= 3.2, "the large-agent lane is at least 3.2 m wide (%.1f m)" % (zs.max() - zs.min()))


func test_markers() -> void:
	var lane: Path3D = _level.get_node("LaneCurve")
	var inside := true
	for i in lane.curve.point_count:
		var p := lane.to_global(lane.curve.get_point_position(i))
		inside = inside and absf(p.z) < HALF_WIDTH
	var gate_end := lane.to_global(lane.curve.get_point_position(lane.curve.point_count - 1))
	assert_true(inside and gate_end.x <= -14.5 and gate_end.x >= -15.5, "lane_curve runs inside the corridor and ends at the gate")
	var zone: Area3D = _level.get_node("Markers/ReturnZone")
	var radius := ((zone.get_node("CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D).radius
	assert_true(_flat(zone.global_position).distance_to(Vector2(-15, 0)) <= radius and is_equal_approx(radius, 5.0),
		"the return zone is 5 m round the gate")
	var post: Marker3D = _level.get_node("Markers/CommandPost")
	assert_true(absf(post.global_position.z) < HALF_WIDTH and post.global_position.x < -15.0,
		"the command post stands on the Fortress wall")


func test_grunts_reach_gate() -> void:
	EventBus.state_changed.emit(&"COMBAT")
	var grunts: Array[Enemy] = []
	for i in 7:
		var g := GRUNT_SCENE.instantiate() as Enemy
		g.data = g.data.duplicate()
		g.data.target_rules = [&"FORTRESS"] as Array[StringName]
		g.position = Vector3(15, 0.1, -10.5 + i * 3.5)
		_level.add_child(g)
		g.spawn_grace = false
		g.is_in_spawn_zone = false
		g.change_state(Enums.EnemyState.ADVANCE)
		grunts.append(g)
	Engine.time_scale = 3.0
	var elapsed := 0.0
	while elapsed < 30.0:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		if grunts.all(func(g: Enemy) -> bool: return g.global_position.x < -10.0):
			break
	Engine.time_scale = 1.0
	var at_gate := grunts.filter(func(g: Enemy) -> bool: return g.global_position.x < -10.0).size()
	assert_true(at_gate == grunts.size(),
		"Grunts spawned across the spawn zone all reach the gate (%d / %d in %.1f s game time)" % [at_gate, grunts.size(), elapsed])
	EventBus.state_changed.emit(&"PREP")
#endregion


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	return _level.get_world_3d().direct_space_state.intersect_ray(query)


func _path(from: Vector3, to: Vector3, layers: int) -> PackedVector3Array:
	var map := _level.get_world_3d().navigation_map
	return NavigationServer3D.map_get_path(map, from, to, true, layers)


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)
