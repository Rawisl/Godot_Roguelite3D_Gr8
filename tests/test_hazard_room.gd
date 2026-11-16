extends Node
## Automated checks for the Hazard Trial room and tower on the real corridor level: groups and
## markers, the navmesh from every spawn pad to the middle (normal and large agent), the room
## cut off from the corridor, the tower on the click layer and picked from the PREP camera, and
## the sun turning to the room light and back. Not shipped. Run with F6 or headless; prints a
## summary and quits with 1 on a failure.

const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")
const CLICK_LAYER := 1 << 6
const NAV_NORMAL := 1
const NAV_LARGE := 2

var _pass := 0
var _fail := 0
var _level: Node3D


func _ready() -> void:
	# The game's window shape; a headless run would otherwise frame a square.
	get_tree().root.size = Vector2i(1920, 1080)
	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	await _wait_for_navmesh()
	await get_tree().physics_frame

	_test_room_markers()
	_test_room_navmesh()
	await _test_portal_click()
	await _test_room_light()

	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


## The first map sync can hold the regions without polygons, so wait until a point in the spawn
## zone snaps onto the navmesh (an empty map answers the origin).
func _wait_for_navmesh() -> void:
	var map := _level.get_world_3d().navigation_map
	var probe := Vector3(15, 0, 0)
	for i in 120:
		await get_tree().physics_frame
		if i >= 4 and NavigationServer3D.map_get_closest_point(map, probe).distance_to(probe) < 1.0:
			return


func _room() -> HazardRoom:
	return get_tree().get_first_node_in_group(&"hazard_room") as HazardRoom


func _test_room_markers() -> void:
	var room := _room()
	_check("the room is in group hazard_room", room != null)
	if room == null:
		return
	_check("the room has a CommanderSpawn marker", room.get_commander_spawn() != null)
	var spawns := room.get_enemy_spawns()
	_check("the room has five spawn pads S1..S5", spawns.size() == 5 and spawns[0].name == "S1" and spawns[4].name == "S5")
	var centre := room.get_commander_spawn().global_position
	var facing := true
	for s in spawns:
		var to_centre := (centre - s.global_position)
		to_centre.y = 0.0
		facing = facing and (-s.global_basis.z).dot(to_centre.normalized()) > 0.99
	_check("every pad faces the middle of the room", facing)
	var boss := room.get_boss_spawn()
	_check("the boss pad is S3 and in group hazard_boss_spawn", boss != null and boss.name == "S3" and boss.is_in_group(&"hazard_boss_spawn"))
	_check("the camera frame has a size", room.camera_size > 0.0)


func _test_room_navmesh() -> void:
	var room := _room()
	if room == null:
		return
	var map := _level.get_world_3d().navigation_map
	var centre := room.get_commander_spawn().global_position
	var reach_all := true
	for s in room.get_enemy_spawns():
		reach_all = reach_all and _reaches(map, s.global_position, centre, NAV_NORMAL)
	_check("every pad reaches the middle on the normal navmesh", reach_all)
	_check("the boss pad reaches the middle on the large-agent navmesh", _reaches(map, room.get_boss_spawn().global_position, centre, NAV_LARGE))
	_check("the corridor does not reach the room", not _reaches(map, Vector3(10, 0, 0), centre, NAV_NORMAL))
	_check("the commander spawn is on the navmesh", NavigationServer3D.map_get_closest_point(map, centre).distance_to(centre) < 1.0)


func _reaches(map: RID, from: Vector3, to: Vector3, layers: int) -> bool:
	var path := NavigationServer3D.map_get_path(map, from, to, true, layers)
	return not path.is_empty() and Vector2(path[-1].x, path[-1].z).distance_to(Vector2(to.x, to.z)) < 1.0


func _test_portal_click() -> void:
	var portals := get_tree().get_nodes_in_group(&"hazard_portal")
	_check("one tower is in group hazard_portal", portals.size() == 1)
	if portals.is_empty():
		return
	var portal := portals[0] as Node3D
	var area := portal.get_node_or_null("ClickArea") as Area3D
	_check("the tower has a ClickArea on layer 7 only", area != null and area.collision_layer == CLICK_LAYER)
	# Frame the corridor the way PREP does, then click the middle of the tower on screen.
	EventBus.state_changed.emit(&"PREP")
	await get_tree().create_timer(0.8, true, false, true).timeout
	await get_tree().physics_frame
	var cam := get_viewport().get_camera_3d()
	var point := portal.global_position + Vector3.UP * 2.5
	var screen := cam.unproject_position(point)
	var on_screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).has_point(screen)
	_check("the tower is on screen in the PREP frame", on_screen and not cam.is_position_behind(point))
	var from := cam.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(screen) * 500.0, CLICK_LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := _level.get_world_3d().direct_space_state.intersect_ray(query)
	var picked: Node = (hit.collider as Node).get_parent() if not hit.is_empty() else null
	_check("a click on the tower picks the hazard_portal node", picked == portal)


func _test_room_light() -> void:
	var room := _room()
	if room == null or room.sun == null:
		_check("the room knows the level's sun", false)
		return
	var sun := room.sun
	var before_color := sun.light_color
	var before_energy := sun.light_energy
	EventBus.hazard_trial_entered.emit(5, [])
	await get_tree().create_timer(room.fade_time + 0.2, true, false, true).timeout
	_check("entering turns the sun to the room light", sun.light_color.is_equal_approx(room.sun_color) and is_equal_approx(sun.light_energy, room.sun_energy))
	EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
	# Entering again in the middle of the fade back must not take the half-faded light as the level's.
	await get_tree().create_timer(room.fade_time * 0.4, true, false, true).timeout
	EventBus.hazard_trial_entered.emit(5, [])
	await get_tree().create_timer(room.fade_time + 0.2, true, false, true).timeout
	EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
	await get_tree().create_timer(room.fade_time + 0.2, true, false, true).timeout
	_check("leaving brings back the level's own light, even after a quick re-entry",
		sun.light_color.is_equal_approx(before_color) and is_equal_approx(sun.light_energy, before_energy))


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("OK   ", label)
	else:
		_fail += 1
		print("FAIL ", label)
