extends Node
## Tests how the Commander faces, runs, dodges and aims while the chase camera holds the mouse
## (locked view). Headless cannot capture the mouse, so the locked behaviour is reached through
## the helper functions with explicit arguments instead of through _is_view_locked.

const CommanderScript := preload("res://entities/commander/commander.gd")

var passes := 0
var fails := 0
var _commander: CharacterBody3D
var _camera: Camera3D


func _ready() -> void:
	_commander = preload("res://entities/commander/commander.tscn").instantiate()
	add_child(_commander)
	_commander.set_physics_process(false)
	for child in _commander.get_children():
		child.set_physics_process(false)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.current = true
	await get_tree().process_frame
	_commander.global_position = Vector3.ZERO
	_commander._anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	test_k1_backward_straight()
	test_k2_backward_diagonal()
	test_k3_sideways_and_forward_are_not_backward()
	test_k4_zero_vectors()
	test_k5_flat_forward()
	test_k6_run_backwards_from_idle()
	test_k7_flip_keeps_position()
	test_k8_same_direction_does_not_restart()
	test_k9_locked_sideways_faces_aim()
	test_k10_unlocked_sideways_faces_move()
	test_k11_locked_standing_faces_aim()
	test_k12_unlocked_standing_keeps_yaw()
	test_k13_attack_snaps_to_strike_dir()
	test_k14_post_action_returns_to_aim()
	test_k15_aim_along_camera_looking_down()
	test_k16_aim_along_camera_looking_up()
	test_k17_firebomb_without_aim_point()
	test_k18_unlocked_update_aim_keeps_mouse_branch()
	test_k19_headless_is_not_locked()
	_camera.free()
	_commander.free()
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	get_tree().quit(0 if fails == 0 else 1)


func assert_true(condition: bool, label: String) -> void:
	if condition:
		passes += 1
		print("[PASS] %s" % label)
	else:
		fails += 1
		printerr("[FAIL] %s" % label)


func _place_camera(pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	_camera.global_transform = Transform3D(
			Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Basis(Vector3.RIGHT, deg_to_rad(pitch_deg)), pos)


func _yaw() -> float:
	return _commander._aim_pivot.rotation.y


func _yaw_of(dir: Vector3) -> float:
	return atan2(dir.x, dir.z)


func _yaw_close(dir: Vector3, tolerance_deg: float) -> bool:
	return absf(angle_difference(_yaw(), _yaw_of(dir))) <= deg_to_rad(tolerance_deg)


func _turn_for(frames: int, free_dir: Vector3) -> void:
	for i in frames:
		_commander._turn_model(0.016, free_dir)


func _reset_actions() -> void:
	_commander.is_attacking = false
	_commander.is_dodging = false
	_commander.is_using_skill = false
	_commander._was_pushed = false
	_commander._post_action_timer = 0.0
	_commander._post_action_facing_dir = Vector3.ZERO
	_commander.velocity = Vector3.ZERO


func _reset_run_clip() -> void:
	var anim: AnimationPlayer = _commander._anim_player
	anim.play(CommanderScript.ANIM_IDLE, 0.0)
	anim.advance(0.0)


func test_k1_backward_straight() -> void:
	assert_true(CommanderScript.moves_backward(Vector3.BACK, Vector3.FORWARD), "K1 straight back counts as backward")


func test_k2_backward_diagonal() -> void:
	var diagonal := Vector3(1.0, 0.0, 1.0)
	assert_true(CommanderScript.moves_backward(diagonal, Vector3.FORWARD), "K2 backward diagonal counts as backward")


func test_k3_sideways_and_forward_are_not_backward() -> void:
	assert_true(not CommanderScript.moves_backward(Vector3.RIGHT, Vector3.FORWARD), "K3 sideways is not backward")
	assert_true(not CommanderScript.moves_backward(Vector3.FORWARD, Vector3.FORWARD), "K3 forward is not backward")
	var slightly_back := Vector3(1.0, 0.0, 0.2).normalized()
	assert_true(not CommanderScript.moves_backward(slightly_back, Vector3.FORWARD), "K3 dot -0.2 is not backward")


func test_k4_zero_vectors() -> void:
	assert_true(not CommanderScript.moves_backward(Vector3.ZERO, Vector3.FORWARD), "K4 zero move is not backward")
	assert_true(not CommanderScript.moves_backward(Vector3.BACK, Vector3.ZERO), "K4 zero facing is not backward")


func test_k5_flat_forward() -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(40.0)) * Basis(Vector3.RIGHT, deg_to_rad(-35.0))
	var expected := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(40.0))
	assert_true(CommanderScript.flat_forward(basis).dot(expected) > 0.9999, "K5 flat forward of a tilted camera matches its yaw")
	var down := Basis(Vector3.RIGHT, deg_to_rad(-90.0))
	assert_true(CommanderScript.flat_forward(down) == Vector3.ZERO, "K5 flat forward of a camera looking straight down is zero")


func test_k6_run_backwards_from_idle() -> void:
	_reset_run_clip()
	_commander._play_run(-1.0)
	var anim: AnimationPlayer = _commander._anim_player
	assert_true(anim.current_animation == CommanderScript.ANIM_RUN and anim.get_playing_speed() < 0.0,
			"K6 run plays in reverse from idle")


func test_k7_flip_keeps_position() -> void:
	var anim: AnimationPlayer = _commander._anim_player
	_reset_run_clip()
	_commander._play_run(1.0)
	anim.advance(0.3)
	_commander._play_run(-1.0)
	anim.advance(0.1)
	var before := anim.current_animation_position
	_commander._play_run(1.0)
	assert_true(anim.get_playing_speed() > 0.0 and before > 0.05 and absf(anim.current_animation_position - before) < 0.02,
			"K7 flipping from reverse to forward keeps the clip position")


func test_k8_same_direction_does_not_restart() -> void:
	var anim: AnimationPlayer = _commander._anim_player
	_reset_run_clip()
	_commander._play_run(1.0)
	anim.advance(0.1)
	var before := anim.current_animation_position
	_commander._play_run(1.0)
	assert_true(before > 0.05 and absf(anim.current_animation_position - before) < 0.001,
			"K8 playing run in the same direction again does not restart it")


func test_k9_locked_sideways_faces_aim() -> void:
	_reset_actions()
	_place_camera(Vector3(0.0, 4.0, 4.0), 40.0, -35.0)
	var aim := CommanderScript.flat_forward(_camera.global_basis)
	var right := Vector3(_camera.global_basis.x.x, 0.0, _camera.global_basis.x.z).normalized()
	_commander.aim_dir = aim
	_commander.velocity = right * 6.0
	_commander._aim_pivot.rotation.y = 0.0
	_turn_for(60, aim)
	assert_true(_yaw_close(aim, 1.0), "K9 locked, strafing, the model faces the camera")
	_reset_actions()


func test_k10_unlocked_sideways_faces_move() -> void:
	_reset_actions()
	_place_camera(Vector3(0.0, 4.0, 4.0), 40.0, -35.0)
	var right := Vector3(_camera.global_basis.x.x, 0.0, _camera.global_basis.x.z).normalized()
	_commander.velocity = right * 6.0
	_commander._aim_pivot.rotation.y = 0.0
	_turn_for(60, _commander._move_facing())
	assert_true(_yaw_close(right, 1.0), "K10 unlocked, strafing, the model faces the way it moves")
	_reset_actions()


func test_k11_locked_standing_faces_aim() -> void:
	_reset_actions()
	var aim := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(-70.0))
	_commander._aim_pivot.rotation.y = 0.0
	_turn_for(60, aim)
	assert_true(_yaw_close(aim, 1.0), "K11 locked, standing still, the model turns to the camera")


func test_k12_unlocked_standing_keeps_yaw() -> void:
	_reset_actions()
	_commander._aim_pivot.rotation.y = 0.7
	_turn_for(30, _commander._move_facing())
	assert_true(is_equal_approx(_yaw(), 0.7), "K12 unlocked, standing still, the model keeps its yaw")


func test_k13_attack_snaps_to_strike_dir() -> void:
	_reset_actions()
	var aim := Vector3.FORWARD
	var strike := Vector3.RIGHT
	_commander.is_attacking = true
	_commander._attack_strike_dir = strike
	_commander._aim_pivot.rotation.y = 0.0
	_commander._turn_model(0.016, aim)
	assert_true(_yaw_close(strike, 0.1), "K13 an attack turns the model to the strike direction at once")
	_reset_actions()


func test_k14_post_action_returns_to_aim() -> void:
	_reset_actions()
	var aim := Vector3.FORWARD
	_commander._aim_pivot.rotation.y = _yaw_of(Vector3.RIGHT)
	_commander._post_action_facing_dir = Vector3.RIGHT
	_commander._post_action_timer = CommanderScript.POST_ACTION_DURATION
	for i in 7:
		_commander._turn_model(0.016, aim)
		_commander._post_action_timer = maxf(_commander._post_action_timer - 0.016, 0.0)
	_turn_for(60, aim)
	assert_true(_yaw_close(aim, 1.0), "K14 after an action the model settles on the camera facing")
	_reset_actions()


func test_k15_aim_along_camera_looking_down() -> void:
	_reset_actions()
	_commander.global_position = Vector3.ZERO
	_place_camera(Vector3(1.0, 4.0, 4.0), 25.0, -35.0)
	_commander._aim_along_camera(_camera)
	var expected := CommanderScript.flat_forward(_camera.global_basis)
	var point: Vector3 = _commander.aim_point
	assert_true(_commander.aim_dir.dot(expected) > 0.9999, "K15 aim direction is the camera's flat forward")
	assert_true(point.is_finite() and is_equal_approx(point.y, _commander.global_position.y)
			and (point - _commander.global_position).dot(_commander.aim_dir) > 0.0,
			"K15 aim point is on the ground ahead of the commander")


func test_k16_aim_along_camera_looking_up() -> void:
	_reset_actions()
	_place_camera(Vector3(1.0, 1.0, 4.0), 25.0, 20.0)
	_commander._aim_along_camera(_camera)
	var expected := CommanderScript.flat_forward(_camera.global_basis)
	assert_true(not _commander.aim_point.is_finite(), "K16 looking above the horizon leaves no aim point")
	assert_true(_commander.aim_dir.dot(expected) > 0.9999, "K16 aim direction still follows the camera")


func test_k17_firebomb_without_aim_point() -> void:
	var aim: Vector3 = _commander.aim_dir
	var landing := FirebombSkill.landing_point(_commander, Vector3.INF, aim)
	var expected: Vector3 = _commander.global_position + aim * GameConfig.skill_firebomb_cast_range
	assert_true(landing.distance_to(expected) < 0.01, "K17 firebomb with no aim point lands the full range along the aim")


func test_k18_unlocked_update_aim_keeps_mouse_branch() -> void:
	_place_camera(Vector3(0.0, 4.0, 4.0), 0.0, -35.0)
	_commander.aim_point = Vector3(1.0, 2.0, 3.0)
	_commander._update_aim(_camera)
	assert_true(_commander.aim_point.is_finite(), "K18 unlocked, the aim does not take the locked branch")


func test_k19_headless_is_not_locked() -> void:
	# Headless cannot capture the mouse; the locked cases above call the helpers directly.
	assert_true(not _commander._is_view_locked(), "K19 headless run is not a locked view")
