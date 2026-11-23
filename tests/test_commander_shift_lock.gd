extends Node
## Focused regression checks for the room frame, aim and combat direction.

const CommanderScene := preload("res://entities/commander/commander.tscn")
const CommanderScript := preload("res://entities/commander/commander.gd")

var passes := 0
var fails := 0
var commander: CharacterBody3D
var camera: Camera3D


func _ready() -> void:
	commander = CommanderScene.instantiate()
	add_child(commander)
	commander.set_physics_process(false)
	for child in commander.get_children():
		child.set_physics_process(false)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	await get_tree().process_frame
	commander.global_position = Vector3.ZERO
	commander._anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_test_room_aim_with_free_cursor()
	_test_turn_and_attack_in_one_tick()
	_test_turn_and_skill_in_one_tick()
	_test_ground_and_sky_targets()
	_test_backpedal_and_facing()
	_test_leave_restores_mouse_aim()
	EventBus.camera_frame_changed.emit(&"OVERVIEW")
	camera.free()
	commander.free()
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	get_tree().quit(0 if fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("[PASS] %s" % label)
	else:
		fails += 1
		printerr("[FAIL] %s" % label)


func _place_camera(pos: Vector3, yaw: float, pitch: float) -> void:
	camera.global_transform = Transform3D(
			Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(pitch)), pos)


func _test_room_aim_with_free_cursor() -> void:
	EventBus.camera_frame_changed.emit(&"OVERVIEW")
	_check(not commander._is_view_locked(), "outside the room the view is free")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.camera_frame_changed.emit(&"HAZARD_TRIAL")
	_place_camera(Vector3(1, 4, 4), 25, -35)
	commander._update_aim(camera)
	var direction: Vector3 = commander.aim_dir
	var point: Vector3 = commander.aim_point
	get_viewport().warp_mouse(get_viewport().get_visible_rect().size * 0.9)
	commander._update_aim(camera)
	_check(commander._is_view_locked() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
			and direction.dot(CommanderScript.flat_forward(camera.global_basis)) > 0.9999,
			"the room frame locks aim with a visible cursor")
	_check(point.is_finite() and commander.aim_dir.is_equal_approx(direction)
			and commander.aim_point.is_equal_approx(point),
			"moving the free cursor does not move the ground target")


func _test_turn_and_attack_in_one_tick() -> void:
	_place_camera(Vector3(1, 4, 4), -55, -35)
	commander.aim_dir = Vector3.FORWARD
	commander._cmd_input.register_press(&"attack")
	commander._physics_process(0.016)
	var expected := CommanderScript.flat_forward(camera.global_basis)
	_check(commander.is_attacking and commander._attack_strike_dir.dot(expected) > 0.9999,
			"a turn and attack in the same tick strike along the new camera direction")
	commander._interrupt_attack()


func _test_turn_and_skill_in_one_tick() -> void:
	var slot: int = commander.skill_runner.set_skill_level(&"firebomb", 1)
	_check(slot >= 0, "Firebomb can be assigned to an active slot")
	if slot < 0:
		return
	_place_camera(Vector3(1, 4, 4), 70, -35)
	commander.aim_dir = Vector3.FORWARD
	commander.aim_point = Vector3.INF
	var cast_origin := commander.global_position
	var screen_centre := get_viewport().get_visible_rect().get_center()
	var target: Variant = Plane(Vector3.UP, cast_origin.y).intersects_ray(
			camera.project_ray_origin(screen_centre), camera.project_ray_normal(screen_centre))
	var expected := FirebombSkill.landing_point(commander, target,
			CommanderScript.flat_forward(camera.global_basis))
	commander._cmd_input.register_press([&"skill_1", &"skill_2", &"skill_3"][slot])
	commander._physics_process(0.016)
	var zone := get_node_or_null("FirebombZone") as FirebombZone
	_check(zone != null and zone.global_position.distance_to(expected) < 0.01,
			"a turn and Firebomb in the same tick use the new center-ray target")
	if zone != null:
		zone.free()
	commander.is_using_skill = false


func _test_ground_and_sky_targets() -> void:
	_place_camera(Vector3(1, 4, 4), 25, -35)
	commander._update_aim(camera)
	_check(commander.aim_point.is_finite()
			and absf(commander.aim_point.y - commander.global_position.y) < 0.01,
			"the center ray reaches the ground at the commander's feet")
	_place_camera(Vector3(1, 1, 4), 25, 20)
	commander._update_aim(camera)
	var landing := FirebombSkill.landing_point(commander, commander.aim_point, commander.aim_dir)
	var expected: Vector3 = commander.global_position + commander.aim_dir * GameConfig.skill_firebomb_cast_range
	_check(not commander.aim_point.is_finite() and landing.distance_to(expected) < 0.01,
			"looking above the horizon makes Firebomb land at maximum range")


func _test_backpedal_and_facing() -> void:
	_place_camera(Vector3(0, 4, 4), 40, -35)
	var forward := CommanderScript.flat_forward(camera.global_basis)
	var side := Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z).normalized()
	commander.aim_dir = forward
	commander.velocity = -forward * 6.0
	_check(commander._run_clip_speed() < 0.0 and CommanderScript.moves_backward(-forward, forward),
			"moving away from the camera uses the reverse run")
	commander.velocity = side * 6.0
	commander._aim_pivot.rotation.y = 0.0
	for i in 60:
		commander._update_model_facing(0.016)
	var yaw: float = commander._aim_pivot.rotation.y
	_check(absf(angle_difference(yaw, atan2(forward.x, forward.z))) < deg_to_rad(1.0),
			"strafing with the cursor free still faces the camera")
	commander.velocity = Vector3.ZERO


func _test_leave_restores_mouse_aim() -> void:
	EventBus.camera_frame_changed.emit(&"OVERVIEW")
	_place_camera(Vector3(0, 4, 4), 0, -75)
	var motion := InputEventMouseMotion.new()
	motion.position = get_viewport().get_visible_rect().size * Vector2(0.75, 0.3)
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	var mouse := get_viewport().get_mouse_position()
	var hit: Variant = Plane(Vector3.UP, commander.global_position.y).intersects_ray(
			camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	var centre := get_viewport().get_visible_rect().get_center()
	var centre_hit: Variant = Plane(Vector3.UP, commander.global_position.y).intersects_ray(
			camera.project_ray_origin(centre), camera.project_ray_normal(centre))
	commander.aim_point = Vector3.INF
	commander._update_aim(camera)
	_check(not commander._is_view_locked() and hit != null and centre_hit != null
			and (hit as Vector3).distance_to(centre_hit) > 0.1
			and commander.aim_point.is_finite()
			and commander.aim_point.distance_to(hit) < 0.01,
			"leaving the room restores the mouse ray's ground point")
