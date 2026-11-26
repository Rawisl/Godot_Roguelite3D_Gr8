extends Node
## Focused regression checks for the locked view: the aim follows the camera, the model
## follows the movement, and attacks and skills still turn it to the aim.

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
	_test_standing_keeps_facing_when_camera_turns()
	_test_moving_faces_the_move_direction()
	_test_run_clip_never_plays_backwards()
	_test_skill_facing_is_taken_at_the_start()
	_test_top_down_skill_follows_the_aim()
	_test_no_input_dodge_facing_holds()
	_test_lock_from_the_third_person_view_signal()
	_test_dodge_follows_the_move_direction()
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
	var facing: float = commander._aim_pivot.rotation.y
	_check(commander.is_attacking and commander._attack_strike_dir.dot(expected) > 0.9999
			and absf(angle_difference(facing, atan2(expected.x, expected.z))) < deg_to_rad(1.0),
			"a turn and attack in the same tick strike along the new camera direction and face it")
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


func _test_standing_keeps_facing_when_camera_turns() -> void:
	EventBus.camera_frame_changed.emit(&"HAZARD_TRIAL")
	commander.velocity = Vector3.ZERO
	commander._aim_pivot.rotation.y = 1.0
	var unchanged := true
	var aim_follows := true
	for yaw in [0.0, 70.0, 150.0, -110.0]:
		_place_camera(Vector3(0, 4, 4), yaw, -35)
		commander._update_aim(camera)
		for i in 30:
			commander._update_model_facing(0.016)
		unchanged = unchanged and absf(angle_difference(commander._aim_pivot.rotation.y, 1.0)) < 0.001
		aim_follows = aim_follows and commander.aim_dir.dot(CommanderScript.flat_forward(camera.global_basis)) > 0.9999
	_check(unchanged and aim_follows,
			"turning the camera while standing leaves the model's facing alone, and the aim follows the camera")


func _test_moving_faces_the_move_direction() -> void:
	_place_camera(Vector3(0, 4, 4), 40, -35)
	commander._update_aim(camera)
	var forward := CommanderScript.flat_forward(camera.global_basis)
	var side := Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z).normalized()
	commander._aim_pivot.rotation.y = 0.0
	var faces_move := true
	for direction in [side, -forward, -side]:
		commander.velocity = direction * 6.0
		for i in 80:
			commander._update_model_facing(0.016)
		var yaw: float = commander._aim_pivot.rotation.y
		faces_move = faces_move and absf(angle_difference(yaw, atan2(direction.x, direction.z))) < deg_to_rad(1.0)
	_check(faces_move and commander.aim_dir.dot(forward) > 0.9999,
			"moving in the locked view faces the move direction, strafing or backwards, while the aim stays on the camera")
	commander.velocity = Vector3.ZERO


func _test_run_clip_never_plays_backwards() -> void:
	_place_camera(Vector3(0, 4, 4), 40, -35)
	var forward := CommanderScript.flat_forward(camera.global_basis)
	commander.aim_dir = forward
	commander.velocity = -forward * 6.0
	commander._anim_player.play(&"advance/Dodge_Forward")
	commander._play_run()
	_check(commander._anim_player.current_animation == CommanderScript.ANIM_RUN
			and commander._anim_player.get_playing_speed() > 0.0 and not commander.has_method(&"_run_clip_speed"),
			"running away from the camera plays the run clip forwards")
	commander.velocity = Vector3.ZERO


func _facing_toward(direction: Vector3) -> bool:
	return absf(angle_difference(commander._aim_pivot.rotation.y,
			atan2(direction.x, direction.z))) < deg_to_rad(1.0)


func _test_skill_facing_is_taken_at_the_start() -> void:
	EventBus.camera_frame_changed.emit(&"HAZARD_TRIAL")
	var slot: int = commander.skill_runner.set_skill_level(&"firebomb", 1)
	commander.skill_runner.tick(60.0)
	_place_camera(Vector3(1, 4, 4), 25, -35)
	commander._update_aim(camera)
	var cast_dir: Vector3 = commander.aim_dir
	commander._aim_pivot.rotation.y = 2.0
	commander._try_skill(slot)
	var started: bool = commander.is_using_skill
	for i in 80:
		commander._turn_model(0.016, Vector3.ZERO)
	var turned := _facing_toward(cast_dir)
	_place_camera(Vector3(1, 4, 4), -100, -35)
	commander._update_aim(camera)
	for i in 80:
		commander._turn_model(0.016, Vector3.ZERO)
	var held: bool = _facing_toward(cast_dir) and commander.aim_dir.dot(cast_dir) < 0.9
	commander._end_skill()
	for i in 80:
		commander._update_model_facing(0.016)
	var stays := _facing_toward(cast_dir)
	var zone := get_node_or_null("FirebombZone") as FirebombZone
	if zone != null:
		zone.free()
	_check(started and turned and held and stays,
			"a skill turns the model to the aim taken at its start, the camera turning mid-skill does not move it, and it holds after")


func _test_top_down_skill_follows_the_aim() -> void:
	EventBus.camera_frame_changed.emit(&"OVERVIEW")
	EventBus.camera_view_changed.emit(&"TOP_DOWN")
	commander.is_using_skill = true
	commander._skill_cast_dir = Vector3.FORWARD
	commander.aim_dir = Vector3(1, 0, 0)
	for i in 80:
		commander._turn_model(0.016, Vector3.ZERO)
	var first := _facing_toward(Vector3(1, 0, 0))
	commander.aim_dir = Vector3(0, 0, 1)
	for i in 80:
		commander._turn_model(0.016, Vector3.ZERO)
	commander.is_using_skill = false
	_check(first and _facing_toward(Vector3(0, 0, 1)),
			"without the lock a skill still turns the model to the aim as it moves")


func _test_no_input_dodge_facing_holds() -> void:
	_place_camera(Vector3(0, 4, 4), 40, -35)
	commander._update_aim(camera)
	var aim: Vector3 = commander.aim_dir
	commander._dodge_cooldown_timer = 0.0
	commander._start_dodge(camera)
	commander._turn_model(0.016, Vector3.ZERO)
	var faces_aim: bool = _facing_toward(aim) and commander._dodge_dir.dot(-aim) > 0.999
	commander._end_dodge()
	_place_camera(Vector3(0, 4, 4), -70, -35)
	commander._update_aim(camera)
	for i in 10:
		commander._turn_model(0.016, Vector3.ZERO)
	var holds_after := _facing_toward(aim)
	commander._post_action_timer = 0.0
	for i in 40:
		commander._update_model_facing(0.016)
	_check(faces_aim and holds_after and _facing_toward(aim),
			"a dodge with no move key faces the aim and keeps that facing while the commander stands still")
	commander._dodge_cooldown_timer = 0.0


func _test_lock_from_the_third_person_view_signal() -> void:
	EventBus.camera_frame_changed.emit(&"OVERVIEW")
	EventBus.camera_view_changed.emit(&"THIRD_PERSON")
	commander.velocity = Vector3.ZERO
	commander._aim_pivot.rotation.y = 1.0
	var steady := true
	for yaw in [10.0, 120.0]:
		_place_camera(Vector3(0, 4, 4), yaw, -35)
		commander._update_aim(camera)
		for i in 30:
			commander._update_model_facing(0.016)
		steady = steady and absf(angle_difference(commander._aim_pivot.rotation.y, 1.0)) < 0.001 \
				and commander.aim_dir.dot(CommanderScript.flat_forward(camera.global_basis)) > 0.9999
	var locked: bool = commander._is_view_locked()
	EventBus.camera_view_changed.emit(&"TOP_DOWN")
	_check(locked and steady and not commander._is_view_locked(),
			"the third-person view signal locks the aim and leaves the facing alone, like the room frame")


func _test_dodge_follows_the_move_direction() -> void:
	_place_camera(Vector3(0, 4, 4), 40, -35)
	commander._update_aim(camera)
	var forward := CommanderScript.flat_forward(camera.global_basis)
	Input.action_press(&"move_down")
	commander._start_dodge(camera)
	var along_move: bool = commander._dodge_dir.dot(-forward) > 0.999 and not commander._is_backstep_dodge
	var faces_move: bool = true
	commander._turn_model(0.016, Vector3.ZERO)
	faces_move = absf(angle_difference(commander._aim_pivot.rotation.y, atan2(-forward.x, -forward.z))) < deg_to_rad(1.0)
	Input.action_release(&"move_down")
	commander._end_dodge()
	_check(along_move and faces_move, "a dodge with a move key goes and faces along the move direction")
	commander._dodge_cooldown_timer = 0.0
	commander._start_dodge(camera)
	var fallback: bool = commander._dodge_dir.dot(-commander.aim_dir) > 0.999 and commander._is_backstep_dodge
	commander._end_dodge()
	commander._dodge_cooldown_timer = 0.0
	_check(fallback, "a dodge with no move key still backsteps away from the aim")


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
