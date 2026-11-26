extends Node3D
## Integration checks for the third-person view in the corridor: the key toggle, where it is
## allowed, the views sent on the bus, the cursor and the commander's aim.

const ROOM_SCENE := preload("res://levels/corridor/hazard_room.tscn")
const CommanderScene := preload("res://entities/commander/commander.tscn")
const CommanderScript := preload("res://entities/commander/commander.gd")

var passes := 0
var fails := 0
var commander_mock: Node3D
var rig: CameraRig
var corridor_camera: Camera3D
var bounds: CameraBounds
var frames: Array[StringName] = []
var views: Array[StringName] = []
var commander_mesh: MeshInstance3D


func _ready() -> void:
	commander_mock = Node3D.new()
	commander_mock.add_to_group(&"commander")
	add_child(commander_mock)
	# A stand-in for the model: one mesh on a dither material, like the fox's.
	commander_mesh = MeshInstance3D.new()
	commander_mesh.mesh = BoxMesh.new()
	var dither := ShaderMaterial.new()
	dither.shader = load("res://art/shaders/toon_dither.gdshader") as Shader
	commander_mesh.material_override = dither
	commander_mock.add_child(commander_mesh)
	EventBus.camera_frame_changed.connect(func(frame: StringName) -> void: frames.append(frame))
	EventBus.camera_view_changed.connect(func(view: StringName) -> void: views.append(view))
	test_f5_toggles_in_frontline()
	test_uses_corridor_settings()
	test_f5_ignored_in_prep()
	test_prep_forces_top_down_then_restores()
	test_commander_mode_orbits_on_wall()
	test_boss_intro_restores_choice()
	test_hazard_unchanged()
	test_cursor_captured_in_corridor_chase()
	test_summary_frees_cursor()
	test_run_end_frees_cursor()
	test_wasd_and_c_do_not_pan_in_chase()
	test_toggle_during_glide()
	test_recall_then_f5_before_follow_converges()
	test_deploy_keeps_chase()
	await test_f5_ignored_when_paused_or_dialog()
	await test_wall_free_distance()
	await test_wall_blocks_camera()
	await test_wall_layers()
	await test_commander_body_ignored()
	await test_camera_eases_back_out()
	await test_min_distance_kept()
	await test_camera_never_inside_collider()
	await test_alternating_wall_does_not_flicker()
	test_sub_margin_change_never_moves_camera()
	await test_hazard_room_uses_wall_settings()
	await test_commander_fades_near_wall()
	await test_commander_fade_between_and_release()
	await test_commander_fade_reduced_motion_and_chase_off()
	await test_commander_fade_follows_model_changes()
	test_commander_hides_when_very_close()
	await test_shoulder_narrows_near_wall()
	await test_shoulder_eases_back_out()
	await test_framing_with_several_obstacles()
	await test_framing_while_commander_strafes_and_jumps()
	await test_framing_after_min_distance_push()
	await test_framing_when_resweeps_are_cut_short()
	await test_push_dropped_to_keep_commander_framed()
	await test_final_check_accept_restarts_release_delay()
	await test_commander_fade_with_real_settings()
	test_commander_materials_use_dither()
	_clear_rig()
	commander_mock.free()
	await test_commander_aims_along_camera()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	get_tree().quit(0 if fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("[PASS] %s" % label)
	else:
		fails += 1
		printerr("[FAIL] %s" % label)


func _new_rig() -> void:
	_clear_rig()
	commander_mock.global_position = Vector3.ZERO
	bounds = CameraBounds.new()
	add_child(bounds)
	rig = CameraRig.new()
	rig.bounds = bounds
	corridor_camera = Camera3D.new()
	corridor_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	rig.add_child(corridor_camera)
	add_child(rig)
	corridor_camera.look_at_from_position(Vector3(16, 16, 16), Vector3.ZERO)
	corridor_camera.current = true
	frames.clear()
	views.clear()


func _clear_rig() -> void:
	if rig != null:
		rig.free()
		rig = null
	if bounds != null:
		bounds.free()
		bounds = null


func _chase() -> Camera3D:
	return rig.get_node("ChaseCamera") as Camera3D


func _step(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		var dt := minf(0.016, seconds - elapsed)
		TimeManager.real_time += dt
		TimeManager.game_time += dt
		rig._process(dt)
		rig._follow(dt)
		elapsed += dt


func _press_f5() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = rig.view_toggle_key
	key.pressed = true
	rig._unhandled_input(key)


func _combat_rig() -> void:
	_new_rig()
	EventBus.state_changed.emit(&"COMBAT")
	frames.clear()
	views.clear()


func test_f5_toggles_in_frontline() -> void:
	_combat_rig()
	_press_f5()
	_check(rig.is_third_person() and _chase().current and views == [&"THIRD_PERSON"]
			and frames.is_empty(), "f5_toggles_in_frontline: on cuts to the chase camera once")
	_press_f5()
	_check(not rig.is_third_person() and corridor_camera.current
			and views == [&"THIRD_PERSON", &"TOP_DOWN"]
			and is_equal_approx(corridor_camera.size, bounds.camera_size_frontline)
			and not rig.is_gliding(), "f5_toggles_in_frontline: off cuts back without a glide")


func test_uses_corridor_settings() -> void:
	_combat_rig()
	var settings := rig.corridor_chase.duplicate() as ChaseCameraSettings
	settings.fov = 72.0
	rig.corridor_chase = settings
	_press_f5()
	var look := -_chase().global_basis.z
	var flat := Vector3(look.x, 0.0, look.z).normalized()
	_check(is_equal_approx(_chase().fov, 72.0) and flat.x > 0.9,
			"uses_corridor_settings: fov from the resource, looking along the corridor")


func test_f5_ignored_in_prep() -> void:
	_new_rig()
	EventBus.state_changed.emit(&"PREP")
	views.clear()
	rig.toggle_view()
	_check(not rig.is_third_person_chosen() and views.is_empty(),
			"f5_ignored_in_prep: no choice and no signal")


func test_prep_forces_top_down_then_restores() -> void:
	_combat_rig()
	rig.toggle_view()
	EventBus.state_changed.emit(&"PREP")
	_check(rig.get_view() == &"TOP_DOWN" and corridor_camera.current
			and rig.is_third_person_chosen(), "prep_forces_top_down: PREP shows top-down, choice kept")
	EventBus.state_changed.emit(&"COMBAT")
	_check(rig.get_view() == &"THIRD_PERSON" and _chase().current,
			"prep_forces_top_down: the view returns after PREP")


func test_commander_mode_orbits_on_wall() -> void:
	_new_rig()
	commander_mock.global_position = Vector3(-19, 4, 0)
	EventBus.state_changed.emit(&"COMBAT")
	rig.toggle_view()
	_step(1.5)
	EventBus.mode_changed.emit(&"COMMANDER")
	_step(0.5)
	_check(rig.is_third_person() and not rig.is_panning_enabled() and not rig.is_gliding()
			and _chase().global_position.y > 4.0 + rig.corridor_chase.pivot_height,
			"commander_mode_orbits_on_wall: orbits the commander at its real height")
	rig.toggle_view()
	_check(not rig.is_third_person() and is_equal_approx(rig.position.y, 0.0)
			and is_equal_approx(corridor_camera.size, bounds.camera_size_overview),
			"commander_mode_orbits_on_wall: off restores the ortho camera and size")


func test_boss_intro_restores_choice() -> void:
	_combat_rig()
	rig.toggle_view()
	views.clear()
	EventBus.state_changed.emit(&"BOSS_INTRO")
	_check(rig.get_view() == &"TOP_DOWN" and rig.is_in_boss_intro()
			and rig.get_frame() == &"BOSS_INTRO", "boss_intro_restores_choice: the intro cuts to top-down")
	rig.toggle_view()
	_check(rig.is_third_person_chosen() and not rig.is_third_person(),
			"boss_intro_restores_choice: f5 does nothing in the intro")
	EventBus.state_changed.emit(&"BOSS_COMBAT")
	_check(rig.is_third_person() and views == [&"TOP_DOWN", &"THIRD_PERSON"],
			"boss_intro_restores_choice: the view returns after the intro")


func test_hazard_unchanged() -> void:
	var room := ROOM_SCENE.instantiate() as HazardRoom
	room.position = Vector3(0, 0, 100)
	add_child(room)
	_new_rig()
	EventBus.state_changed.emit(&"PREP")
	views.clear()
	commander_mock.global_position = room.get_commander_spawn().global_position
	EventBus.hazard_trial_entered.emit(5, [])
	rig.toggle_view()
	_check(views == [&"THIRD_PERSON"] and not rig.is_third_person_chosen(),
			"hazard_unchanged: the room is third person and f5 does nothing there")
	EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
	EventBus.state_changed.emit(&"PREP")
	_check(views == [&"THIRD_PERSON", &"TOP_DOWN"] and corridor_camera.current,
			"hazard_unchanged: leaving goes back to top-down")
	_combat_rig()
	rig.toggle_view()
	commander_mock.global_position = room.get_commander_spawn().global_position
	EventBus.hazard_trial_entered.emit(5, [])
	EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
	EventBus.state_changed.emit(&"PREP")
	_check(rig.get_view() == &"TOP_DOWN", "hazard_unchanged: PREP after the room is top-down")
	EventBus.state_changed.emit(&"COMBAT")
	_check(rig.is_third_person() and _chase().current,
			"hazard_unchanged: the chosen view returns after PREP")
	_clear_rig()
	room.free()


func test_cursor_captured_in_corridor_chase() -> void:
	_combat_rig()
	rig.toggle_view()
	rig._update_cursor()
	_check(rig.is_cursor_captured() and (rig.get_node("Crosshair") as CanvasLayer).visible,
			"cursor_captured_in_corridor_chase: captured with a crosshair")
	rig.toggle_view()
	_check(not rig.is_cursor_captured() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
			"cursor_captured_in_corridor_chase: freed when off")


func test_summary_frees_cursor() -> void:
	_combat_rig()
	rig.toggle_view()
	_step(0.1)
	var held := rig.is_cursor_captured()
	EventBus.state_changed.emit(&"SUMMARY")
	_step(0.1)
	_check(held and not rig.is_cursor_captured() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
			and not (rig.get_node("Crosshair") as CanvasLayer).visible and rig.is_third_person(),
			"summary_frees_cursor: the panel can be clicked, the view stays")
	EventBus.state_changed.emit(&"COMBAT")
	_step(0.1)
	_check(rig.is_cursor_captured(), "summary_frees_cursor: the next wave captures again")


func test_run_end_frees_cursor() -> void:
	_combat_rig()
	rig.toggle_view()
	_step(0.1)
	rig._on_run_ended(&"ABANDONED", {})
	_check(not rig.is_cursor_captured() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
			"run_end_frees_cursor: the end screens get the cursor")


func _press_move_and_recenter() -> void:
	Input.action_press(&"move_right")
	_step(0.5)
	Input.action_release(&"move_right")
	var recenter := InputEventAction.new()
	recenter.action = &"camera_recenter"
	recenter.pressed = true
	rig._unhandled_input(recenter)
	_step(0.3)


func _on_commander(point: Vector2) -> bool:
	return Vector2(rig.position.x, rig.position.z).distance_to(point) < 0.1


func test_wasd_and_c_do_not_pan_in_chase() -> void:
	_combat_rig()
	commander_mock.global_position = Vector3(5, 0, 0)
	rig.toggle_view()
	_step(1.5)
	_press_move_and_recenter()
	_check(not rig.is_panning_enabled() and not rig.is_gliding() and _on_commander(Vector2(5, 0)),
			"wasd_and_c_do_not_pan_in_chase: Frontline, the rig stays on the commander")
	EventBus.mode_changed.emit(&"COMMANDER")
	_step(0.7)
	_press_move_and_recenter()
	_check(rig.is_third_person() and not rig.is_panning_enabled() and not rig.is_gliding()
			and _on_commander(Vector2(5, 0)),
			"wasd_and_c_do_not_pan_in_chase: Commander mode, the rig stays on the commander")
	rig.toggle_view()
	EventBus.mode_changed.emit(&"COMMANDER")
	_step(0.7)
	var before := rig.position
	Input.action_press(&"move_right")
	_step(0.5)
	Input.action_release(&"move_right")
	_check(rig.is_panning_enabled() and rig.position.distance_to(before) > 1.0,
			"wasd_and_c_do_not_pan_in_chase: control, Commander mode without the chase pans")


func test_toggle_during_glide() -> void:
	_combat_rig()
	commander_mock.global_position = Vector3(-10, 0, 0)
	EventBus.mode_changed.emit(&"COMMANDER")
	var gliding := rig.is_gliding()
	rig.toggle_view()
	_check(gliding and rig.is_third_person() and not rig.is_gliding(),
			"toggle_during_glide: on cancels the glide")
	rig.toggle_view()
	_check(not rig.is_third_person() and not rig.is_gliding()
			and is_equal_approx(corridor_camera.size, bounds.camera_size_overview),
			"toggle_during_glide: off is a hard cut at the overview size")


func test_recall_then_f5_before_follow_converges() -> void:
	_combat_rig()
	rig.toggle_view()
	_step(0.5)
	commander_mock.global_position = Vector3(-15, 4, 0)
	EventBus.mode_changed.emit(&"COMMANDER")
	rig.toggle_view()
	_check(is_equal_approx(rig.position.x, -15.0) and is_equal_approx(rig.position.z, 0.0)
			and is_equal_approx(rig.position.y, 0.0) and corridor_camera.current,
			"recall_then_f5: the ortho camera stands on the commander, not on the smoothed rig")


func test_deploy_keeps_chase() -> void:
	_combat_rig()
	commander_mock.global_position = Vector3(-15, 4, 0)
	EventBus.mode_changed.emit(&"COMMANDER")
	rig.toggle_view()
	_step(0.2)
	views.clear()
	frames.clear()
	EventBus.mode_changed.emit(&"FRONTLINE")
	_step(0.1)
	_check(rig.is_third_person() and not rig.is_gliding() and views.is_empty()
			and rig.is_cursor_captured() and frames == [&"FRONTLINE"],
			"deploy_keeps_chase: no glide, no view change, cursor kept, frame follows the mode")
	rig.toggle_view()
	_check(is_equal_approx(corridor_camera.size, bounds.camera_size_frontline),
			"deploy_keeps_chase: off uses the Frontline size")


func test_f5_ignored_when_paused_or_dialog() -> void:
	_combat_rig()
	TimeManager.request_pause(TimeManager.REASON_USER)
	rig.toggle_view()
	TimeManager.release_pause(TimeManager.REASON_USER)
	_check(not rig.is_third_person_chosen(), "f5_ignored_when_paused_or_dialog: pause")
	var dialog := (preload("res://ui/screens/confirm_dialog.tscn").instantiate()) as Control
	dialog.setup(&"reward.skip.title", &"reward.skip.body")
	ScreenManager.open_dialog(dialog)
	rig.toggle_view()
	var chosen := rig.is_third_person_chosen()
	ScreenManager.close_all_dialogs()
	await get_tree().process_frame
	_check(not chosen, "f5_ignored_when_paused_or_dialog: dialog")


func _orbit_basis() -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(rig._orbit.pitch_deg), rig._orbit.yaw, 0.0))


func _pivot() -> Vector3:
	return rig.global_position + Vector3.UP * rig._orbit.pivot_height


func _shoulder_point() -> Vector3:
	return _pivot() + _orbit_basis().x * rig._orbit.shoulder


func _wanted() -> Vector3:
	var basis := _orbit_basis()
	return _pivot() + basis.z * rig._orbit.orbit_distance() + basis.x * rig._orbit.shoulder


func _add_box(center: Vector3, box_size: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = center
	return body


## A chase view on a commander at the origin, with nothing around it.
func _chase_rig() -> void:
	_combat_rig()
	rig.toggle_view()


## Lets the physics server see bodies added or removed, then cuts the camera onto the commander.
func _resnap() -> void:
	await get_tree().physics_frame
	rig._snap_chase()


func test_wall_free_distance() -> void:
	_chase_rig()
	await _resnap()
	_check(_chase().global_position.distance_to(_wanted()) < 0.01,
			"wall_free_distance: without an obstacle the camera is at the full orbit distance")


func test_wall_blocks_camera() -> void:
	_chase_rig()
	var middle := (_shoulder_point() + _wanted()) * 0.5
	var along := (_wanted() - _shoulder_point()).normalized()
	var wall := _add_box(middle, Vector3.ONE, 1)
	await _resnap()
	var camera := _chase().global_position
	_check(camera.distance_to(_pivot()) < _wanted().distance_to(_pivot()) - 0.5
			and (camera - middle).dot(along) < -0.5 - 0.001,
			"wall_blocks_camera: a wall on layer 1 pulls the camera in front of it in the same frame")
	wall.free()


func test_wall_layers() -> void:
	_chase_rig()
	var middle := (_shoulder_point() + _wanted()) * 0.5
	var structure := _add_box(middle, Vector3.ONE, 8)
	await _resnap()
	var blocked := _chase().global_position.distance_to(_wanted()) > 0.5
	structure.free()
	var enemy := _add_box(middle, Vector3.ONE, 4)
	await _resnap()
	var passed := _chase().global_position.distance_to(_wanted()) < 0.01
	enemy.free()
	_check(blocked and passed,
			"wall_layers: structure (layer 4) blocks, enemy (layer 3) does not")


func test_commander_body_ignored() -> void:
	_chase_rig()
	commander_mock.remove_from_group(&"commander")
	# A body on the wall layer around the pivot, the way the commander's own body sits there.
	var body := _add_box(Vector3(0, 1.0, 0), Vector3(1.0, 2.5, 1.0), 1)
	body.add_to_group(&"commander")
	await _resnap()
	var camera := _chase().global_position
	body.free()
	commander_mock.add_to_group(&"commander")
	_check(camera.distance_to(_wanted()) < 0.01,
			"commander_body_ignored: the followed body does not block its own camera")


func test_camera_eases_back_out() -> void:
	_chase_rig()
	var middle := (_shoulder_point() + _wanted()) * 0.5
	var wall := _add_box(middle, Vector3.ONE, 1)
	await _resnap()
	var blocked := _chase().global_position.distance_to(_pivot())
	wall.free()
	await get_tree().physics_frame
	_step(0.016)
	var after_one := _chase().global_position.distance_to(_pivot())
	var full := _wanted().distance_to(_pivot())
	_check(is_equal_approx(after_one, blocked),
			"camera_eases_back_out: the first clear frame holds still, waiting out the release delay")
	_step(0.2)
	var later := _chase().global_position.distance_to(_pivot())
	_check(later > blocked and later < full - 0.5,
			"camera_eases_back_out: after the delay it moves out a little, not all the way")
	_step(2.0)
	_check(_chase().global_position.distance_to(_pivot()) > full - 0.05,
			"camera_eases_back_out: reaches the full distance within the return time")
	rig.reduced_motion = true
	var again := _add_box(middle, Vector3.ONE, 1)
	await _resnap()
	again.free()
	await get_tree().physics_frame
	_step(0.016)
	_check(_chase().global_position.distance_to(_wanted()) < 0.05,
			"camera_eases_back_out: reduced motion cuts back out at once")


func test_min_distance_kept() -> void:
	_chase_rig()
	rig._orbit.min_distance = 12.0
	await _resnap()
	_check(absf(_chase().global_position.distance_to(_pivot()) - 12.0) < 0.01,
			"min_distance_kept: a free camera nearer than the minimum is pushed out to it")


func _camera_overlaps_collider() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = rig._orbit.probe_radius - 0.01
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, _chase().global_position)
	query.collision_mask = rig._orbit.collision_mask
	return not _chase().get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func test_camera_never_inside_collider() -> void:
	_chase_rig()
	rig._orbit.min_distance = 2.5
	var along := (_wanted() - _shoulder_point()).normalized()
	# The wall face is 0.4 m ahead of the shoulder point: the sweep stops right in front of it and
	# the point at the minimum distance lies inside it.
	var wall := _add_box(_shoulder_point() + along * 0.9, Vector3.ONE, 1)
	await _resnap()
	var overlaps := _camera_overlaps_collider()
	var gap := _chase().global_position.distance_to(_pivot())
	wall.free()
	_check(not overlaps and gap < 2.5,
			"camera_never_inside_collider: a wall wins over the minimum distance")


func test_sub_margin_change_never_moves_camera() -> void:
	_chase_rig()
	var orbit := rig._orbit
	var half := orbit.release_margin * 0.5
	orbit._clearance = 0.5
	_check(is_equal_approx(orbit._next_clearance(0.5 + half, 0.0), 0.5),
			"sub_margin: a slightly clearer way does not move the camera, even without time")
	var highest := 0.0
	for i in 30:
		orbit._clearance = orbit._next_clearance(0.5 if i % 2 == 1 else 0.5 + half, 0.016)
		highest = maxf(highest, orbit._clearance)
	_check(is_equal_approx(highest, 0.5),
			"sub_margin: free flickering inside the margin never raises the clearance")


func test_alternating_wall_does_not_flicker() -> void:
	_chase_rig()
	var middle := (_shoulder_point() + _wanted()) * 0.5
	var wall := _add_box(middle, Vector3.ONE, 1)
	await _resnap()
	var last := _chase().global_position.distance_to(_pivot())
	var worst := 0.0
	for i in 30:
		if wall != null:
			wall.free()
			wall = null
		else:
			wall = _add_box(middle, Vector3.ONE, 1)
		await get_tree().physics_frame
		_step(0.016)
		var gap := _chase().global_position.distance_to(_pivot())
		worst = maxf(worst, gap - last)
		last = gap
	_check(worst < 0.1, "alternating_wall: the camera never pops out between blocked frames")
	if wall != null:
		wall.free()
		wall = null
	await get_tree().physics_frame
	_step(0.5)
	_check(last < _wanted().distance_to(_pivot()) - 0.5
			and _chase().global_position.distance_to(_pivot()) > last + 0.5,
			"alternating_wall: once clear for longer than the delay it eases out")


func test_hazard_room_uses_wall_settings() -> void:
	var room := ROOM_SCENE.instantiate() as HazardRoom
	room.position = Vector3(0, 0, 100)
	add_child(room)
	room.chase_probe_radius = 0.45
	room.chase_max_screen_offset = 0.4
	room.chase_fade_hide_distance = 0.7
	room.chase_teleport_snap_distance = 5.0
	_new_rig()
	EventBus.state_changed.emit(&"PREP")
	commander_mock.global_position = room.get_commander_spawn().global_position
	EventBus.hazard_trial_entered.emit(5, [])
	await get_tree().physics_frame
	_check(rig.is_third_person() and is_equal_approx(rig._orbit.probe_radius, 0.45)
			and rig._orbit.collision_mask == room.chase_collision_mask
			and is_equal_approx(rig._orbit.max_screen_offset, 0.4)
			and is_equal_approx(rig._fade.hide_distance, 0.7)
			and is_equal_approx(rig._teleport_snap_distance, 5.0),
			"hazard_room_uses_wall_settings: the room's numbers reach the orbit")
	_clear_rig()
	room.free()


func _mesh_alpha() -> float:
	return float(commander_mesh.get_instance_shader_parameter(&"dither_alpha"))


## Fade thresholds that read the full orbit distance as clear and a wall in the middle of the way
## as fully faded.
func _set_fade_range() -> void:
	var full := _wanted().distance_to(_pivot())
	rig._fade.start_distance = full - 0.1
	rig._fade.end_distance = full * 0.6
	rig._fade.hide_distance = full * 0.5


func test_commander_fades_near_wall() -> void:
	_chase_rig()
	_set_fade_range()
	await _resnap()
	_step(0.3)
	_check(is_equal_approx(_mesh_alpha(), 1.0),
			"commander_fade: the camera at full distance leaves the model solid")
	var wall := _add_box((_shoulder_point() + _wanted()) * 0.5, Vector3.ONE, 1)
	await _resnap()
	_step(0.016)
	var first := _mesh_alpha()
	_step(0.3)
	_check(first < 1.0 and first > 0.0 and is_equal_approx(_mesh_alpha(), 0.0),
			"commander_fade: a wall fades the model over the fade time, not in one frame")
	wall.free()


func test_commander_fade_between_and_release() -> void:
	_chase_rig()
	var full := _wanted().distance_to(_pivot())
	rig._fade.start_distance = full + 1.0
	rig._fade.end_distance = full - 1.0
	await _resnap()
	_step(0.3)
	var middle := lerpf(rig._fade.min_alpha, 1.0, 0.5)
	_check(absf(_mesh_alpha() - middle) < 0.02,
			"commander_fade: between the two distances the model is partly faded")
	_set_fade_range()
	var wall := _add_box((_shoulder_point() + _wanted()) * 0.5, Vector3.ONE, 1)
	await _resnap()
	_step(0.3)
	var faded := _mesh_alpha()
	wall.free()
	await get_tree().physics_frame
	_step(3.0)
	_check(is_equal_approx(faded, 0.0) and is_equal_approx(_mesh_alpha(), 1.0),
			"commander_fade: removing the wall brings the model back to solid")


func test_commander_fade_reduced_motion_and_chase_off() -> void:
	_chase_rig()
	_set_fade_range()
	rig.reduced_motion = true
	var wall := _add_box((_shoulder_point() + _wanted()) * 0.5, Vector3.ONE, 1)
	await _resnap()
	_step(0.016)
	_check(is_equal_approx(_mesh_alpha(), 0.0),
			"commander_fade: reduced motion fades in one frame")
	rig.toggle_view()
	_check(is_equal_approx(_mesh_alpha(), 1.0),
			"commander_fade: turning the chase off restores the model at once")
	wall.free()


func _dither_mesh(parent: Node) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var material := ShaderMaterial.new()
	material.shader = load("res://art/shaders/toon_dither.gdshader") as Shader
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh


func test_commander_fade_follows_model_changes() -> void:
	_chase_rig()
	_set_fade_range()
	var wall := _add_box((_shoulder_point() + _wanted()) * 0.5, Vector3.ONE, 1)
	await _resnap()
	_step(0.3)
	var mount := Node3D.new()
	commander_mock.add_child(mount)
	var swapped := _dither_mesh(mount)
	_step(0.016)
	_check(is_equal_approx(float(swapped.get_instance_shader_parameter(&"dither_alpha")), 0.0),
			"commander_fade_model_change: a mesh added deep under the commander gets the current fade")
	mount.free()
	_step(0.3)
	_check(is_equal_approx(_mesh_alpha(), 0.0) and rig.is_third_person(),
			"commander_fade_model_change: removing a mesh breaks nothing")
	wall.free()


func test_commander_fade_with_real_settings() -> void:
	_chase_rig()
	_check(is_equal_approx(rig._fade.start_distance, 2.0) and is_equal_approx(rig._fade.end_distance, 1.0)
			and is_equal_approx(rig._fade.alpha_for(1.5), lerpf(rig._fade.min_alpha, 1.0, 0.5)),
			"commander_fade_real_settings: the resource gives the 2 m to 1 m mapping")
	# A small block right behind the camera's start: the way to the camera is blocked at once, so
	# the camera stands at the shoulder point, about the shoulder offset from the pivot.
	var along := (_wanted() - _shoulder_point()).normalized()
	var block := _add_box(_shoulder_point() + along * 0.35, Vector3.ONE * 0.2, 1)
	await _resnap()
	_step(0.5)
	var gap := rig._orbit.get_pivot_gap()
	_check(gap <= 1.05 and is_equal_approx(_mesh_alpha(), rig._fade.alpha_for(gap))
			and _mesh_alpha() <= rig._fade.min_alpha + 0.0001,
			"commander_fade_real_settings: a camera pulled in close fades the model down to the minimum")
	block.free()


func test_commander_hides_when_very_close() -> void:
	var fade := ChaseCameraFade.new()
	fade.start_distance = 2.0
	fade.end_distance = 1.0
	fade.hide_distance = 0.6
	fade.min_alpha = 0.3
	fade.update(commander_mock, 0.5, 0.016, false)
	var first := _mesh_alpha()
	for i in 20:
		fade.update(commander_mock, 0.5, 0.016, false)
	_check(first < 1.0 and first > 0.0 and is_equal_approx(_mesh_alpha(), 0.0),
			"commander_hide: at the hide distance the model fades to nothing over the fade time")
	for i in 20:
		fade.update(commander_mock, 0.8, 0.016, false)
	_check(is_equal_approx(_mesh_alpha(), 0.15),
			"commander_hide: between the hide and end distances it is between nothing and the minimum")
	for i in 40:
		fade.update(commander_mock, 3.0, 0.016, false)
	_check(is_equal_approx(_mesh_alpha(), 1.0), "commander_hide: backing off brings the model back")
	fade.update(commander_mock, 0.1, 0.016, true)
	_check(is_equal_approx(_mesh_alpha(), 0.0), "commander_hide: reduced motion hides in one frame")
	fade.restore()
	_check(is_equal_approx(_mesh_alpha(), 1.0), "commander_hide: restore shows the model at once")


## Horizontal screen position of the pivot over the screen width, 0 left, 0.5 the middle.
func _pivot_screen_x() -> float:
	var width := get_viewport().get_visible_rect().size.x
	return _chase().unproject_position(_pivot()).x / width


func _shoulder_now() -> float:
	return (_chase().global_position - _pivot()).dot(_orbit_basis().x)


func test_shoulder_narrows_near_wall() -> void:
	_chase_rig()
	await _resnap()
	_check(absf(_shoulder_now() - rig._orbit.shoulder) < 0.01
			and _pivot_screen_x() >= 0.5 * (1.0 - rig._orbit.max_screen_offset) - 0.001
			and _pivot_screen_x() <= 0.5,
			"shoulder_narrows: with no wall the shoulder is the full offset and the commander is inside the limit")
	var along := (_wanted() - _shoulder_point()).normalized()
	var wall := _add_box(_shoulder_point() + along * 0.9, Vector3.ONE, 1)
	await _resnap()
	var x := _pivot_screen_x()
	var left_limit := 0.5 * (1.0 - rig._orbit.max_screen_offset)
	_check(_shoulder_now() < rig._orbit.shoulder and x >= left_limit - 0.002 and x <= 0.5 + 0.002
			and not _camera_overlaps_collider(),
			"shoulder_narrows: a wall close behind keeps the commander between the limit and the middle, camera clear")
	var screen := get_viewport().get_visible_rect().size
	var pivot_point := _chase().unproject_position(_pivot())
	_check(pivot_point.y > 0.0 and pivot_point.y < screen.y,
			"shoulder_narrows: the commander is also inside the vertical frame when pulled in")
	wall.free()


func test_shoulder_eases_back_out() -> void:
	_chase_rig()
	var along := (_wanted() - _shoulder_point()).normalized()
	var wall := _add_box(_shoulder_point() + along * 0.9, Vector3.ONE, 1)
	await _resnap()
	wall.free()
	await get_tree().physics_frame
	var last := _shoulder_now()
	var biggest := 0.0
	for i in 150:
		_step(0.016)
		var now := _shoulder_now()
		biggest = maxf(biggest, absf(now - last))
		last = now
	_check(biggest < 0.35 and absf(last - rig._orbit.shoulder) < 0.01,
			"shoulder_eases: it comes back out with the clearance, in steps, to the full offset")


## Whether the commander's real point is between the left limit and the middle of the screen.
func _commander_framed(slack: float) -> bool:
	var width := get_viewport().get_visible_rect().size.x
	var point := commander_mock.global_position + Vector3.UP * rig._orbit.pivot_height
	var x := _chase().unproject_position(point).x / width
	var left_limit := 0.5 * (1.0 - rig._orbit.max_screen_offset)
	return x >= left_limit - slack and x <= 0.5 + slack


func test_framing_with_several_obstacles() -> void:
	# Each row: along-distance and sideways offset of two boxes around the way back.
	var layouts := [
		[0.9, 0.0, 1.8, 0.7], [1.5, -0.6, 2.2, 0.5], [1.0, 0.5, 1.4, -0.6],
		[2.0, 0.0, 2.6, 0.8], [1.2, 0.8, 1.2, -0.8], [0.9, -0.7, 1.6, 0.7]]
	var bad := 0
	for layout in layouts:
		_chase_rig()
		var along := (_wanted() - _shoulder_point()).normalized()
		var side := _orbit_basis().x
		var boxes: Array[StaticBody3D] = [
			_add_box(_shoulder_point() + along * layout[0] + side * layout[1], Vector3.ONE * 0.8, 1),
			_add_box(_shoulder_point() + along * layout[2] + side * layout[3], Vector3.ONE * 0.8, 8)]
		await _resnap()
		_step(0.1)
		if not _commander_framed(0.003) or _camera_overlaps_collider():
			bad += 1
		for box in boxes:
			box.free()
	_check(bad == 0, "framing_obstacles: with two obstacles the commander stays framed and the camera clear")


func test_framing_while_commander_strafes_and_jumps() -> void:
	_chase_rig()
	var along := (_wanted() - _shoulder_point()).normalized()
	# A wall that pulls the camera in about halfway; one right behind the pivot leaves no depth to frame with.
	var wall := _add_box(_shoulder_point() + along * 3.5, Vector3.ONE, 1)
	await _resnap()
	var side := _orbit_basis().x
	var framed := true
	for direction in [1.0, -1.0]:
		for i in 60:
			commander_mock.global_position += side * direction * 0.1
			_step(0.016)
			framed = framed and _commander_framed(0.01)
	_check(framed, "framing_strafe: a strafing commander stays between the limit and the middle")
	commander_mock.global_position += Vector3(10, 0, 0)
	_step(0.016)
	var rig_flat := Vector2(rig.position.x, rig.position.z)
	var commander_flat := Vector2(commander_mock.global_position.x, commander_mock.global_position.z)
	_check(rig_flat.distance_to(commander_flat) < 0.01 and _commander_framed(0.01),
			"framing_strafe: a 10 m jump cuts the camera onto the commander, framed")
	wall.free()


## Puts the rig's smoothed focus an offset to the side of the commander and cuts the chase there.
func _resnap_with_lag(sideways: float) -> void:
	await get_tree().physics_frame
	rig.position = commander_mock.global_position - _orbit_basis().x * sideways
	rig._sync_orbit()
	rig._orbit.snap(rig.global_position)


func test_framing_after_min_distance_push() -> void:
	var bad := 0
	for sideways in [-0.3, 0.3, 0.8]:
		for distance in [1.0, 1.3, 1.6]:
			_chase_rig()
			var along := (_wanted() - _shoulder_point()).normalized()
			var wall := _add_box(_shoulder_point() + along * distance, Vector3.ONE, 1)
			await _resnap_with_lag(sideways)
			if not _commander_framed(0.003) or _camera_overlaps_collider():
				bad += 1
			wall.free()
	_check(bad == 0,
			"framing_min_distance: a commander off to the side with a short way back stays framed")


func test_framing_when_resweeps_are_cut_short() -> void:
	_chase_rig()
	rig._orbit.max_resweeps = 0
	var along := (_wanted() - _shoulder_point()).normalized()
	var wall := _add_box(_shoulder_point() + along * 0.9, Vector3.ONE, 1)
	await _resnap_with_lag(0.0)
	_check(_commander_framed(0.003) and not _camera_overlaps_collider(),
			"framing_final_check: without any re-sweep the final check still frames the commander")
	wall.free()


## Moves the rig's smoothed focus an offset to the side of the commander, without cutting yet.
func _lag_rig(sideways: float) -> void:
	rig.position = commander_mock.global_position - _orbit_basis().x * sideways
	rig._sync_orbit()


func test_push_dropped_to_keep_commander_framed() -> void:
	var reached := 0
	var bad := 0
	for distance in [0.9, 1.0, 1.1]:
		_chase_rig()
		# The commander 0.3 m to the left of the smoothed pivot, a wall close behind the full
		# shoulder: the back segment is short, then the narrowed shoulder walks out of the wall's
		# way, leaving a short way back with a free path out to the minimum distance.
		_lag_rig(-0.3)
		var along := (_wanted() - _shoulder_point()).normalized()
		var wall := _add_box(_shoulder_point() + along * distance, Vector3.ONE, 1)
		var orbit := rig._orbit
		orbit.push_rejected_by_frame = false
		await get_tree().physics_frame
		orbit.snap(rig.global_position)
		var before_push := orbit._path_start + _orbit_basis().z * orbit.orbit_distance() * orbit._clearance
		if orbit.push_rejected_by_frame and before_push.distance_to(_pivot()) < orbit.min_distance:
			reached += 1
		if not _commander_framed(0.003) or _camera_overlaps_collider():
			bad += 1
		wall.free()
	_check(reached > 0 and bad == 0,
			"framing_push_dropped: a push out to the minimum distance that would unframe the commander is dropped")


func test_final_check_accept_restarts_release_delay() -> void:
	_chase_rig()
	# The commander stands right of the pivot, so any depth frames it and the final check accepts.
	_lag_rig(1.5)
	var wall := _add_box(_pivot() + _orbit_basis().x * 1.5 + _orbit_basis().z * 1.4, Vector3.ONE, 1)
	await get_tree().physics_frame
	var orbit := rig._orbit
	orbit.snap(rig.global_position)
	orbit._clearance = 0.5
	orbit._releasing = true
	orbit._clear_time = 1.0
	var view := Basis.from_euler(Vector3(deg_to_rad(orbit.pitch_deg + orbit.aim_tilt_deg), orbit.yaw, 0.0))
	var back := _orbit_basis().z * orbit.orbit_distance()
	orbit._frame_by_narrowing(orbit._space(), _pivot(), _pivot(), _orbit_basis().x, back, -view.z, 1.0)
	var lowered := orbit._clearance
	_check(lowered < 0.5 and not orbit._releasing and is_zero_approx(orbit._clear_time),
			"final_check_accept: a closer accepted path restarts the release delay")
	wall.free()
	await get_tree().physics_frame
	for i in 5:
		_step(0.016)
	_check(is_equal_approx(orbit._clearance, lowered),
			"final_check_accept: the following frames hold until the release delay has passed")


func test_commander_materials_use_dither() -> void:
	var ok := true
	for path in ["res://contents/assets/characters/fox_commander/fox_material.tres",
			"res://contents/assets/characters/commander/Textures/commander_material.tres"]:
		var material := load(path) as ShaderMaterial
		ok = ok and material != null \
				and material.shader.resource_path == "res://art/shaders/toon_dither.gdshader" \
				and material.get_shader_parameter(&"albedo_texture") != null
	_check(ok, "commander_materials: fox and sword use the dither shader and keep their texture")


func test_commander_aims_along_camera() -> void:
	var commander := CommanderScene.instantiate() as CharacterBody3D
	add_child(commander)
	commander.set_physics_process(false)
	for child in commander.get_children():
		child.set_physics_process(false)
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	await get_tree().process_frame
	commander.global_position = Vector3.ZERO
	camera.global_transform = Transform3D(
			Basis(Vector3.UP, deg_to_rad(25)) * Basis(Vector3.RIGHT, deg_to_rad(-35)), Vector3(1, 4, 4))
	EventBus.camera_frame_changed.emit(&"OVERVIEW")
	EventBus.camera_view_changed.emit(&"THIRD_PERSON")
	commander._update_aim(camera)
	var expected := CommanderScript.flat_forward(camera.global_basis)
	_check(commander._is_view_locked() and commander.aim_dir.dot(expected) > 0.9999,
			"commander_aims_along_camera: aim follows the camera in third person")
	EventBus.camera_view_changed.emit(&"TOP_DOWN")
	_check(not commander._is_view_locked(),
			"commander_aims_along_camera: top-down frees the aim")
	camera.free()
	commander.free()
