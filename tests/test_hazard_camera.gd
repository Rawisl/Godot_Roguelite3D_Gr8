extends Node3D
## Integration checks for entering and leaving the chase view, camera motion and cursor ownership.

const ROOM_SCENE := preload("res://levels/corridor/hazard_room.tscn")

var passes := 0
var fails := 0
var room: HazardRoom
var commander: Node3D
var rig: CameraRig
var corridor_camera: Camera3D
var bounds: CameraBounds
var frames: Array[StringName] = []


func _ready() -> void:
	commander = Node3D.new()
	commander.add_to_group(&"commander")
	add_child(commander)
	room = ROOM_SCENE.instantiate() as HazardRoom
	room.position = Vector3(0, 0, 100)
	add_child(room)
	EventBus.camera_frame_changed.connect(func(frame: StringName) -> void: frames.append(frame))
	_test_entry_and_motion()
	_test_cursor_and_zoom()
	_test_exit_orders()
	_clear_rig()
	room.free()
	commander.free()
	print("[test] done: %d passed, %d failed" % [passes, fails])
	get_tree().quit(0 if fails == 0 else 1)


func _new_rig() -> void:
	_clear_rig()
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


func _clear_rig() -> void:
	if rig != null:
		rig.free()
		rig = null
	if bounds != null:
		bounds.free()
		bounds = null


func _chase() -> Camera3D:
	return rig.get_node("ChaseCamera") as Camera3D


func _check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("[test] OK %s" % label)
	else:
		fails += 1
		printerr("[test] FAIL %s" % label)


func _step(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		var dt := minf(0.016, seconds - elapsed)
		TimeManager.real_time += dt
		TimeManager.game_time += dt
		rig._process(dt)
		rig._follow(dt)
		elapsed += dt


func _motion(relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.screen_relative = relative
	return event


func _wheel(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _enter() -> void:
	commander.global_position = room.get_commander_spawn().global_position
	EventBus.state_changed.emit(&"PREP")
	frames.clear()
	EventBus.hazard_trial_entered.emit(5, [])


func _test_entry_and_motion() -> void:
	_new_rig()
	_enter()
	var chase := _chase()
	_check(get_viewport().get_camera_3d() == chase
			and chase.projection == Camera3D.PROJECTION_PERSPECTIVE
			and frames == [&"HAZARD_TRIAL"], "entering cuts to the perspective frame once")
	_check(rig._orbit.zoom == 1.0 and absf(rig._orbit.pitch_deg - room.chase_camera.pitch_deg) < 0.01
			and not rig.is_panning_enabled(), "entry resets orbit and disables map panning")
	var start := rig.position
	# Steps below the teleport distance, so the chase follows instead of cutting.
	for i in 5:
		commander.global_position += Vector3(1.6, 0, 0.8)
		_step(0.016)
	_check(rig.position.distance_to(start) > 0.0
			and rig.position.distance_to(commander.global_position) > 1.0,
			"the camera follows the commander smoothly")
	_step(1.0)
	_check(rig.position.distance_to(commander.global_position) < 0.05,
			"the chase catches the commander")
	var yaw := rig._orbit.yaw
	rig._input(_motion(Vector2(100, -100000)))
	_check(absf(angle_difference(rig._orbit.yaw, yaw) - deg_to_rad(100 * rig.mouse_sensitivity)) < 0.001
			and absf(rig._orbit.pitch_deg - room.chase_camera.pitch_max_deg) < 0.01,
			"mouse look turns yaw and clamps pitch")
	var floor_ok := true
	for pitch in [room.chase_camera.pitch_min_deg, room.chase_camera.far_pitch_deg, room.chase_camera.pitch_max_deg]:
		rig._orbit.pitch_deg = pitch
		for zoom in [room.chase_camera.zoom_min, 1.0]:
			rig._orbit.zoom = zoom
			rig._orbit.place(rig.global_position)
			floor_ok = floor_ok and chase.global_position.y - rig.global_position.y >= room.chase_camera.min_height - 0.001
	_check(floor_ok, "the camera stays above the floor across pitch and zoom limits")


func _test_cursor_and_zoom() -> void:
	rig._orbit.pitch_deg = room.chase_camera.far_pitch_deg
	rig._orbit.zoom = 1.0
	rig._orbit.zoom_target = 1.0
	rig._orbit.place(rig.global_position)
	rig._input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	_step(1.0)
	_check(absf(rig._orbit.zoom - (1.0 - room.chase_camera.zoom_step)) < 0.01,
			"the wheel zooms toward the camera")
	for i in 30:
		rig._input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	_step(1.0)
	_check(absf(rig._orbit.zoom - room.chase_camera.zoom_min) < 0.01,
			"zoom stops at the room's minimum")
	var key := InputEventKey.new()
	key.physical_keycode = rig.free_cursor_key
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	_step(0.016)
	var yaw := rig._orbit.yaw
	rig._input(_motion(Vector2(100, 0)))
	_check(not rig.is_cursor_captured() and is_equal_approx(rig._orbit.yaw, yaw),
			"holding Alt frees the cursor without turning the view")
	var released := InputEventKey.new()
	released.physical_keycode = rig.free_cursor_key
	released.pressed = false
	Input.parse_input_event(released)
	Input.flush_buffered_events()
	_step(0.016)
	_check(rig.is_cursor_captured(), "releasing Alt recaptures the cursor")
	TimeManager.request_pause(TimeManager.REASON_USER)
	_check(not rig.is_cursor_captured() and not rig.get_node("Crosshair").visible,
			"pause frees the cursor and hides the crosshair")
	yaw = rig._orbit.yaw
	rig._input(_motion(Vector2(100, 0)))
	_check(is_equal_approx(rig._orbit.yaw, yaw), "free cursor does not turn the view")
	TimeManager.release_pause(TimeManager.REASON_USER)
	_check(rig.is_cursor_captured(), "unpausing captures the cursor")


func _test_exit_orders() -> void:
	EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
	EventBus.state_changed.emit(&"PREP")
	_check(get_viewport().get_camera_3d() == corridor_camera
			and frames == [&"HAZARD_TRIAL", &"OVERVIEW"]
			and rig.is_panning_enabled(), "leaving restores the corridor once")
	_new_rig()
	EventBus.state_changed.emit(&"PREP")
	frames.clear()
	EventBus.state_changed.emit(&"HAZARD_TRIAL")
	commander.global_position = room.get_commander_spawn().global_position
	EventBus.hazard_trial_entered.emit(5, [])
	EventBus.state_changed.emit(&"PREP")
	EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
	_check(frames == [&"HAZARD_TRIAL", &"OVERVIEW"]
			and get_viewport().get_camera_3d() == corridor_camera,
			"the opposite signal order also restores the corridor once")
