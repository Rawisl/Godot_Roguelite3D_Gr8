extends Node
## Automated checks for the Hazard Trial room and tower on the real corridor level: groups and
## markers, the navmesh from every spawn pad to the middle (normal and large agent), the room
## cut off from the corridor, the tower on the click layer and picked from the PREP camera, and
## the sun turning to the room light and back, and the sky sphere shown only in the room, hiding
## the corridor and holding the whole island. Not shipped. Run with F6 or headless; prints a
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
	_test_room_sky()

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
	_check("the room is available through hazard_room", room != null)
	if room == null:
		return
	_check("the room has a CommanderSpawn marker", room.get_commander_spawn() != null)
	var spawns := room.get_enemy_spawns()
	_check("the room has five spawn pads S1..S5", spawns.size() == 5 and spawns[0].name == "S1" and spawns[4].name == "S5")
	var boss := room.get_boss_spawn()
	_check("the boss pad is S3 and in group hazard_boss_spawn", boss != null and boss.name == "S3" and boss.is_in_group(&"hazard_boss_spawn"))


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
	_check("the tower is on screen and pickable in PREP", on_screen and not cam.is_position_behind(point))
	var from := cam.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(screen) * 500.0, CLICK_LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := _level.get_world_3d().direct_space_state.intersect_ray(query)
	var picked: Node = (hit.collider as Node).get_parent() if not hit.is_empty() else null
	_check("the tower's click ray picks the portal", picked == portal)


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


## Runs after the light test, which leaves the room.
func _test_room_sky() -> void:
	var room := _room()
	if room == null:
		return
	var sky := room.get_node_or_null("SkySphere") as MeshInstance3D
	var sphere := sky.mesh as SphereMesh if sky != null else null
	_check("the room has a SkySphere mesh", sphere != null)
	if sphere == null:
		return
	_check("the sky sphere is 60 m around the camera", is_equal_approx(sphere.radius, 60.0) and is_equal_approx(sphere.height, 120.0))
	var mat := sphere.material as ShaderMaterial
	var picture := mat.get_shader_parameter(&"sky_image") as Texture2D if mat != null else null
	_check("the sky uses the hazard sky shader and the vortex picture",
		mat != null and mat.shader != null and mat.shader.resource_path == "res://art/shaders/hazard_sky.gdshader"
		and picture != null and picture.resource_path == "res://contents/assets/environment/hazard_room/hazard_backdrop.png")
	_check("the sky casts no shadow", sky.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_check("the sky is hidden in the corridor", not sky.visible)
	EventBus.hazard_trial_entered.emit(5, [])
	_check("entering shows the sky", sky.visible)
	var chase := _level.get_node_or_null("CameraRig/ChaseCamera") as Camera3D
	var rig := _level.get_node_or_null("CameraRig") as CameraRig
	_check("the level rig is in the chase view in the room",
		rig != null and rig.is_in_hazard_trial() and chase != null and get_viewport().get_camera_3d() == chase)
	var reach := _sky_reach(room)
	_check("the whole island sits inside the sky from anywhere the camera can stand",
		_island_inside_sky(room, sky, reach, sphere.radius))
	_check("the corridor stays behind the sky from anywhere the camera can stand",
		_corridor_behind_sky(room, reach.x, sphere.radius))
	EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
	_check("leaving hides the sky", not sky.visible)
	_check("the chase camera reaches beyond the sky and hands control back on exit",
		room.chase_far > sphere.radius and chase != null
		and get_viewport().get_camera_3d() != chase)


## Worst case reach of the chase camera around the island, measured on the level's rig at every
## pitch with the wheel zoomed all the way out: x is how far it can stand from the room's middle
## on the ground, y is its highest height above the room's floor. Each is a maximum of its own
## (an over-estimate, which is the safe side). The rig has to be in the chase view.
func _sky_reach(room: HazardRoom) -> Vector2:
	var arena_radius := 15.0
	var builder_constants: Dictionary = (load("res://levels/corridor/hazard_room_builder.gd") as Script).get_script_constant_map()
	if builder_constants.has("ARENA_RADIUS"):
		arena_radius = float(builder_constants["ARENA_RADIUS"])
	else:
		print("[test] warning: ARENA_RADIUS not readable, using 15.0")
	var rig := _level.get_node("CameraRig") as CameraRig
	var chase := rig.get_node("ChaseCamera") as Camera3D
	var back := 0.0
	var up := 0.0
	var pitch: float = rig._orbit.pitch_min
	rig._orbit.zoom = 1.0
	while pitch <= rig._orbit.pitch_max + 0.001:
		rig._orbit.pitch_deg = pitch
		rig._orbit.place(rig.global_position)
		var offset := chase.global_position - rig.global_position
		back = maxf(back, Vector2(offset.x, offset.z).length())
		up = maxf(up, chase.global_position.y - room.global_position.y)
		pitch += 1.0
	rig._orbit.pitch_deg = room.chase_pitch_deg
	rig._orbit.place(rig.global_position)
	return Vector2(arena_radius + back, up)


func _island_inside_sky(room: HazardRoom, sky: MeshInstance3D, reach: Vector2, radius: float) -> bool:
	var to_room := room.global_transform.affine_inverse()
	for node in room.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == sky or mi.mesh == null:
			continue
		for vertex in mi.mesh.get_faces():
			var v: Vector3 = to_room * (mi.global_transform * vertex)
			var flat := Vector2(v.x, v.z).length() + reach.x
			if sqrt(flat * flat + (reach.y - v.y) * (reach.y - v.y)) >= radius:
				print("[test] island vertex outside the sky: ", mi.name, " ", v)
				return false
	return true


func _corridor_behind_sky(room: HazardRoom, horizontal: float, radius: float) -> bool:
	var middle := room.global_position
	var rig := _level.get_node_or_null("CameraRig")
	for node in _level.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		if room.is_ancestor_of(gi) or (rig != null and rig.is_ancestor_of(gi)):
			continue
		var box := gi.global_transform * gi.get_aabb()
		var nearest := Vector2(clampf(middle.x, box.position.x, box.end.x), clampf(middle.z, box.position.z, box.end.z))
		var dist := nearest.distance_to(Vector2(middle.x, middle.z)) - horizontal
		if dist <= radius:
			print("[test] corridor node inside the sky: ", gi.get_path(), " ", dist)
			return false
	return true


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("OK   ", label)
	else:
		_fail += 1
		print("FAIL ", label)
