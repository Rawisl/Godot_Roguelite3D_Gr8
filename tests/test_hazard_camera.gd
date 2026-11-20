extends Node3D
## Test for the camera in the Hazard Trial: entering cuts to the chase view behind the commander,
## the chase camera follows the commander smoothly and keeps its angle, the move keys, C and Tab
## do not move it, leaving cuts back to the PREP frame on the corridor camera, either signal order
## works, and camera_frame_changed reports every frame once. The mouse turns the chase view within
## the pitch limits while the cursor is captured, the middle of the screen lands ahead of the
## commander, and the cursor comes back on pause, a dialog, the free-cursor key and leaving.
## The camera stands over the commander's right shoulder, the wheel zooms it in within limits, and
## looking up brings it nearer so it stays above the floor.
## Uses the real hazard_room.tscn. Not shipped. Run with F6, prints OK/FAIL per case then quits.

const ROOM_SCENE: PackedScene = preload("res://levels/corridor/hazard_room.tscn")
const NEAR := 0.05

var _pass := 0
var _fail := 0
var _rig: CameraRig
var _camera: Camera3D
var _commander: Node3D
var _room: Node3D
var _frames: Array[StringName] = []


func _ready() -> void:
	_commander = Node3D.new()
	_commander.add_to_group(&"commander")
	add_child(_commander)
	EventBus.camera_frame_changed.connect(func(frame: StringName) -> void: _frames.append(frame))
	_run()
	await _run_cursor_events()
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _new_rig() -> void:
	if _rig != null:
		_rig.bounds.free()
		_rig.free()
	_rig = CameraRig.new()
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_rig.add_child(_camera)
	var bounds := CameraBounds.new()
	add_child(bounds)
	_rig.bounds = bounds
	add_child(_rig)
	_camera.look_at_from_position(Vector3(16, 16, 16), Vector3.ZERO)
	_camera.current = true
	_commander.global_position = Vector3(-6, 0, 0)
	_frames.clear()


func _add_room() -> void:
	_room = ROOM_SCENE.instantiate() as Node3D
	_room.position = Vector3(0, 0, 100)
	_room.rotation_degrees.y = 20.0
	add_child(_room)


func _remove_room() -> void:
	if _room != null:
		_room.free()
		_room = null


## Advances real and game time the way TimeManager does and runs the rig's loops.
func _step(seconds: float, tick := 0.016) -> void:
	var left := seconds
	while left > 0.0:
		var dt := minf(tick, left)
		TimeManager.real_time += dt
		TimeManager.game_time += dt
		_rig._process(dt)
		_rig._follow(dt)
		left -= tick


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _at(p: Vector3) -> bool:
	return _flat(_rig.position).distance_to(_flat(p)) < NEAR


func _room_focus() -> Vector3:
	return _room.call(&"get_camera_focus")


func _room_size() -> float:
	return float(_room.get(&"camera_size"))


func _chase_cam() -> Camera3D:
	return _rig.get_node("ChaseCamera") as Camera3D


func _spawn_in_room() -> Vector3:
	return (_room as HazardRoom).get_commander_spawn().global_position


func _view() -> Camera3D:
	return get_viewport().get_camera_3d()


## True when the chase camera sits the orbit distance for its pitch from the point beside the
## pivot (the shoulder point) and looks the aim tilt above it.
func _chase_geometry_ok() -> bool:
	var room := _room as HazardRoom
	var fwd := -_chase_cam().global_basis.z
	var to_point := _shoulder_point() - _chase_cam().global_position
	var tilt := rad_to_deg(fwd.angle_to(to_point))
	return absf(to_point.length() - _expected_distance(_orbit_pitch_deg())) < 0.01 \
			and absf(tilt - room.chase_aim_tilt_deg) < 0.05


## The point the chase camera orbits.
func _pivot() -> Vector3:
	return _rig.global_position + Vector3.UP * (_room as HazardRoom).chase_pivot_height


## The pivot moved to the right by the shoulder offset: the camera's distance is measured to it.
func _shoulder_point() -> Vector3:
	return _pivot() + Vector3.RIGHT.rotated(Vector3.UP, _yaw()) * (_room as HazardRoom).chase_shoulder_offset


## The room's camera-to-pivot distance at an orbit pitch and the rig's zoom, worked out from the
## room's numbers alone.
func _expected_distance(pitch_deg: float) -> float:
	var room := _room as HazardRoom
	var d := room.chase_distance
	if pitch_deg < room.chase_far_pitch_deg:
		d = lerpf(room.chase_distance, room.chase_distance_near,
				inverse_lerp(room.chase_far_pitch_deg, room.chase_pitch_min_deg, pitch_deg))
	elif pitch_deg > room.chase_far_pitch_deg:
		d = lerpf(room.chase_distance, room.chase_distance_up,
				inverse_lerp(room.chase_far_pitch_deg, room.chase_pitch_max_deg, pitch_deg))
	d *= _rig._chase_zoom
	var drop := sin(deg_to_rad(pitch_deg))
	if drop > 0.0:
		d = minf(d, maxf(room.chase_pivot_height - room.chase_min_height, 0.0) / drop)
	return d


## The chase camera's facing on the ground.
func _flat_forward() -> Vector3:
	var f := -_chase_cam().global_basis.z
	return Vector3(f.x, 0.0, f.z).normalized()


func _yaw() -> float:
	return _chase_cam().global_rotation.y


func _pitch_deg() -> float:
	return rad_to_deg(asin(-_chase_cam().global_basis.z.y))


## The pitch of the orbit: the camera's facing pitch less the aim tilt.
func _orbit_pitch_deg() -> float:
	return _pitch_deg() - (_room as HazardRoom).chase_aim_tilt_deg


func _motion(screen_px: Vector2) -> InputEventMouseMotion:
	var m := InputEventMouseMotion.new()
	m.relative = screen_px
	m.screen_relative = screen_px
	return m


func _wheel(button: MouseButton, factor := 1.0, pressed := true) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.factor = factor
	e.pressed = pressed
	return e


## Where the ray through the middle of the screen meets the ground at the commander's feet.
func _centre_hit() -> Variant:
	var cam := _chase_cam()
	var centre := cam.get_viewport().get_visible_rect().size * 0.5
	return Plane(Vector3.UP, _commander.global_position.y).intersects_ray(
			cam.project_ray_origin(centre), cam.project_ray_normal(centre))


func _crosshair_shown() -> bool:
	return (_rig.get_node("Crosshair") as CanvasLayer).visible


## True when the middle of the screen lands ahead of the commander along the camera's facing.
func _centre_ahead_ok() -> bool:
	var hit: Variant = _centre_hit()
	if hit == null:
		return false
	var offset := _flat(hit) - _flat(_commander.global_position)
	var forward := _flat_forward()
	var right := forward.cross(Vector3.UP)
	return offset.dot(forward) > 1.0 \
			and absf(offset.dot(right) - (_room as HazardRoom).chase_shoulder_offset) < 0.01


## Enters a fresh rig into the room with the commander at the spawn.
func _enter_room() -> void:
	_new_rig()
	_enter_prep()
	_commander.global_position = _spawn_in_room()
	EventBus.hazard_trial_entered.emit(5, [])


func _enter_prep() -> void:
	EventBus.state_changed.emit(&"PREP")
	_step(0.6)
	_frames.clear()


func _run() -> void:
	_add_room()

	# Entering from PREP with hazard_trial_entered: a cut on the same frame onto the commander.
	_new_rig()
	_enter_prep()
	_commander.global_position = _spawn_in_room()
	EventBus.hazard_trial_entered.emit(5, [])
	_check("entering cuts onto the commander at once", _at(_spawn_in_room()))
	_check("the chase camera is the view in the room",
		_view() == _chase_cam() and _chase_cam().projection == Camera3D.PROJECTION_PERSPECTIVE)
	_check("the chase camera keeps the corridor camera's yaw",
		absf(angle_difference(_chase_cam().global_rotation.y, _camera.global_rotation.y)) < 0.01)
	var room := _room as HazardRoom
	_check("the chase camera orbits at the room pitch",
		absf(_orbit_pitch_deg() - room.chase_pitch_deg) < 0.5)
	_check("the chase camera sits the room distance from the pivot above the commander", _chase_geometry_ok())
	_check("the chase camera uses the room fov and far",
		is_equal_approx(_chase_cam().fov, room.chase_fov) and is_equal_approx(_chase_cam().far, room.chase_far))
	_check("the chase camera sees past the sky",
		_chase_cam().far > ((_room.get_node("SkySphere") as MeshInstance3D).mesh as SphereMesh).radius)
	_check("entering sets the room camera size at once", is_equal_approx(_camera.size, _room_size()))
	_check("entering reports HAZARD_TRIAL once", _frames == [&"HAZARD_TRIAL"])
	_check("the rig says it is in the Hazard Trial", _rig.is_in_hazard_trial() and _rig.get_frame() == &"HAZARD_TRIAL")
	_check("panning is off in the room", not _rig.is_panning_enabled())

	# The second signal of the pair (the HAZARD_TRIAL state) changes nothing.
	EventBus.state_changed.emit(&"HAZARD_TRIAL")
	_check("the HAZARD_TRIAL state after the signal sends nothing more", _frames.size() == 1)

	# The chase follows the commander smoothly; the move keys, C and Tab do not move it.
	_commander.global_position = _spawn_in_room() + Vector3(8, 0, 4)
	_step(0.016)
	var left := _flat(_rig.position).distance_to(_flat(_commander.global_position))
	_check("the chase follow is smooth, not a jump", left > 0.80 * 8.944 and left < 0.95 * 8.944)
	_step(1.0)
	_check("the camera follows the commander in the room", _at(_commander.global_position))
	_check("the chase camera moves with the focus", _chase_geometry_ok())
	Input.action_press(&"move_right")
	Input.action_press(&"move_up")
	_step(0.8)
	Input.action_release(&"move_right")
	Input.action_release(&"move_up")
	_check("the move keys do not pan the camera in the room", _at(_commander.global_position))
	var recenter := InputEventAction.new()
	recenter.action = &"camera_recenter"
	recenter.pressed = true
	_rig._unhandled_input(recenter)
	_step(0.5)
	_check("C does nothing in the room", _at(_commander.global_position) and is_equal_approx(_camera.size, _room_size()))
	EventBus.mode_changed.emit(&"COMMANDER")
	_step(0.6)
	EventBus.mode_changed.emit(&"FRONTLINE")
	_step(0.6)
	_check("a mode change keeps the chase view", _at(_commander.global_position) and _view() == _chase_cam())
	_check("a mode change in the room sends no frame", _frames.size() == 1)

	# Shake rides on the camera that shows the game.
	_rig.add_shake(1.0)
	_step(0.05)
	_check("screen shake moves the chase camera", _chase_cam().h_offset != 0.0 or _chase_cam().v_offset != 0.0)
	_check("screen shake leaves the corridor camera alone", _camera.h_offset == 0.0 and _camera.v_offset == 0.0)
	_check("get_shake_offset reports the chase camera",
		_rig.get_shake_offset() == Vector2(_chase_cam().h_offset, _chase_cam().v_offset))

	# Leaving with hazard_trial_exited first: a cut to the PREP frame, then PREP changes nothing.
	EventBus.hazard_trial_exited.emit(&"LEFT", 2, 10, 4.0, 0)
	_check("leaving cuts back to the middle of the corridor", _at(Vector3.ZERO))
	_check("leaving sets the overview size at once", is_equal_approx(_camera.size, _rig.bounds.camera_size_overview))
	_check("leaving reports OVERVIEW once", _frames == [&"HAZARD_TRIAL", &"OVERVIEW"])
	_check("leaving gives the view back to the corridor camera", _view() == _camera)
	_check("leaving clears the shake on both cameras",
		_camera.h_offset == 0.0 and _camera.v_offset == 0.0
		and _chase_cam().h_offset == 0.0 and _chase_cam().v_offset == 0.0)
	EventBus.state_changed.emit(&"PREP")
	_step(0.6)
	_check("the PREP state after leaving keeps the PREP frame", _at(Vector3.ZERO) and is_equal_approx(_camera.size, _rig.bounds.camera_size_overview))
	_check("the PREP state after leaving sends nothing more", _frames.size() == 2)
	_check("panning works again in PREP", _rig.is_panning_enabled())

	# The other order: the HAZARD_TRIAL state first (the commander is still in the corridor), then
	# the commander is moved into the room, then hazard_trial_entered; PREP before hazard_trial_exited.
	_new_rig()
	_enter_prep()
	_commander.global_position = Vector3(-6, 0, 0)
	EventBus.state_changed.emit(&"HAZARD_TRIAL")
	_commander.global_position = _spawn_in_room()
	EventBus.hazard_trial_entered.emit(5, [])
	_check("state first: one HAZARD_TRIAL, then the signal snaps onto the commander in the room",
		_at(_spawn_in_room()) and _frames == [&"HAZARD_TRIAL"])
	EventBus.state_changed.emit(&"PREP")
	EventBus.hazard_trial_exited.emit(&"WON", 5, 30, 12.0, 1)
	_check("PREP first: back to the corridor, one OVERVIEW", _at(Vector3.ZERO) and _frames == [&"HAZARD_TRIAL", &"OVERVIEW"])
	_check("PREP first: overview size", is_equal_approx(_camera.size, _rig.bounds.camera_size_overview))

	# Panned away in PREP before entering: leaving still returns to the default focus.
	_new_rig()
	_enter_prep()
	_rig.position = Vector3(10, 0, 1)
	EventBus.hazard_trial_entered.emit(5, [])
	EventBus.hazard_trial_exited.emit(&"DIED", 0, 0, 0.0, 0)
	_check("a pan made before entering is not restored", _at(Vector3.ZERO))

	# The other frames are reported too: OVERVIEW in PREP, FRONTLINE in COMBAT, BOSS_INTRO.
	_new_rig()
	EventBus.state_changed.emit(&"PREP")
	EventBus.state_changed.emit(&"COMBAT")
	EventBus.mode_changed.emit(&"COMMANDER")
	EventBus.mode_changed.emit(&"FRONTLINE")
	EventBus.state_changed.emit(&"BOSS_INTRO")
	EventBus.state_changed.emit(&"BOSS_COMBAT")
	_check("frames follow the context: %s" % [_frames], _frames == [&"OVERVIEW", &"FRONTLINE", &"OVERVIEW", &"FRONTLINE", &"BOSS_INTRO", &"FRONTLINE"])
	EventBus.state_changed.emit(&"BOSS_COMBAT")
	_check("the same frame again sends nothing", _frames.size() == 6)

	# Panning is free at once after leaving, in both signal orders: no hidden glide.
	for order in [["exited", "prep"], ["prep", "exited"]]:
		_new_rig()
		_enter_prep()
		EventBus.hazard_trial_entered.emit(5, [])
		for step in order:
			if step == "exited":
				EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
			else:
				EventBus.state_changed.emit(&"PREP")
		_check("%s then %s: no glide left and panning works at once" % order, not _rig.is_gliding() and _rig.is_panning_enabled())
		Input.action_press(&"move_right")
		_step(0.3)
		Input.action_release(&"move_right")
		_check("%s then %s: the move keys pan right away" % order, not _at(Vector3.ZERO))

	# Commander mode set while in the room: leaving still frames the PREP middle.
	_new_rig()
	_enter_prep()
	EventBus.hazard_trial_entered.emit(5, [])
	EventBus.mode_changed.emit(&"COMMANDER")
	EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
	_check("Commander mode across the room: back to the PREP middle at overview size",
		_at(Vector3.ZERO) and is_equal_approx(_camera.size, _rig.bounds.camera_size_overview))
	EventBus.mode_changed.emit(&"FRONTLINE")

	# Game speed and Pause in the room do not move the chase off the commander.
	_new_rig()
	_enter_prep()
	_commander.global_position = _spawn_in_room()
	EventBus.hazard_trial_entered.emit(5, [])
	Engine.time_scale = 3.0
	_step(0.5)
	TimeManager.request_pause(TimeManager.REASON_USER)
	_step(0.5)
	TimeManager.release_pause(TimeManager.REASON_USER)
	Engine.time_scale = 1.0
	_check("x3 and Pause in the room keep the chase view on the commander",
		_at(_commander.global_position) and _view() == _chase_cam())

	# The follow runs on real seconds: a physics tick at x3 covers about a third of one at x1.
	_new_rig()
	_enter_prep()
	_commander.global_position = _spawn_in_room()
	EventBus.hazard_trial_entered.emit(5, [])
	var smoothing := room.chase_smoothing
	var ticks := float(Engine.physics_ticks_per_second)
	_commander.global_position += Vector3(6, 0, 0)
	Engine.time_scale = 3.0
	var before3 := _flat(_rig.position).distance_to(_flat(_commander.global_position))
	_rig._follow(1.0 / ticks / Engine.time_scale)
	var moved3 := before3 - _flat(_rig.position).distance_to(_flat(_commander.global_position))
	Engine.time_scale = 1.0
	_rig._snap_chase()
	_commander.global_position += Vector3(6, 0, 0)
	var before1 := _flat(_rig.position).distance_to(_flat(_commander.global_position))
	_rig._follow(1.0 / ticks / Engine.time_scale)
	var moved1 := before1 - _flat(_rig.position).distance_to(_flat(_commander.global_position))
	var expected := (1.0 - exp(-1.0 / (ticks * 3.0) / smoothing)) / (1.0 - exp(-1.0 / ticks / smoothing))
	_check("the chase follow runs on real seconds: a tick at x3 covers about a third",
		moved1 > 0.0 and absf(moved3 / moved1 - expected) < 0.02)

	# The mouse turns the chase view while the cursor is captured.
	_enter_room()
	var s := _rig.mouse_sensitivity
	_check("entering captures the cursor", _rig.is_cursor_captured())
	_check("entering shows the crosshair", _crosshair_shown())
	_check("entering starts at the room pitch", absf(_orbit_pitch_deg() - room.chase_pitch_deg) < 0.5)
	var hit: Variant = _centre_hit()
	_check("the middle of the screen lands on the ground", hit != null)
	_check("the middle of the screen lands ahead of the commander, along the camera", _centre_ahead_ok())
	var y0 := _yaw()
	_rig._input(_motion(Vector2(100, 0)))
	_check("moving the mouse right turns the view right",
			absf(angle_difference(y0, _yaw()) + deg_to_rad(100.0 * s)) < 0.001)
	_check("turning keeps the camera distance and facing", _chase_geometry_ok())
	_check("the move keys follow the turned camera",
			_flat_forward().dot(Vector3.FORWARD.rotated(Vector3.UP, _yaw())) > 0.999)
	_check("the aim follows the turned camera", _centre_ahead_ok())
	var p0 := _orbit_pitch_deg()
	_rig._input(_motion(Vector2(0, -40)))
	_check("moving the mouse up looks up", absf(_orbit_pitch_deg() - (p0 + 40.0 * s)) < 0.05)
	_rig._input(_motion(Vector2(0, -100000)))
	_check("the pitch stops at the room's highest angle", absf(_orbit_pitch_deg() - room.chase_pitch_max_deg) < 0.05)
	_rig._input(_motion(Vector2(0, 100000)))
	_check("the pitch stops at the room's lowest angle", absf(_orbit_pitch_deg() - room.chase_pitch_min_deg) < 0.05)
	_check("at the lowest pitch the camera is the near distance from the shoulder point",
			absf((_shoulder_point() - _chase_cam().global_position).length() - room.chase_distance_near) < 0.01)
	_rig._chase_pitch_deg = room.chase_far_pitch_deg
	_rig._place_chase()
	_check("at the far pitch the camera stands chase_distance from the shoulder point",
			absf((_shoulder_point() - _chase_cam().global_position).length() - room.chase_distance) < 0.01)
	_rig._input(_motion(Vector2(0, -100000)))
	_check("at the highest pitch the camera is pulled in to stay above the floor",
			absf((_shoulder_point() - _chase_cam().global_position).length()
					- _expected_distance(room.chase_pitch_max_deg)) < 0.01
			and _expected_distance(room.chase_pitch_max_deg) < room.chase_distance_up)
	# The commander keeps its place on the screen over the whole pitch range.
	var screen_h := _chase_cam().get_viewport().get_visible_rect().size.y
	var ys: Array[float] = []
	for pitch in [room.chase_far_pitch_deg, (room.chase_far_pitch_deg + room.chase_pitch_min_deg) * 0.5,
			room.chase_pitch_min_deg]:
		_rig._chase_pitch_deg = pitch
		_rig._place_chase()
		ys.append(_chase_cam().unproject_position(_pivot()).y)
		_check("pitch %.0f: geometry holds" % pitch, _chase_geometry_ok())
		var gh: Variant = _centre_hit()
		var along := 0.0
		if gh != null:
			along = (_flat(gh) - _flat(_commander.global_position)).dot(
					Vector3.FORWARD.rotated(Vector3.UP, _yaw()))
		_check("pitch %.0f: the middle of the screen lands on the ground before the commander" % pitch,
				gh != null and along > 1.0)
	_check("the commander keeps its height on the screen from the lowest pitch to the far pitch",
			absf(ys[0] - ys[1]) <= screen_h * 0.02 and absf(ys[1] - ys[2]) <= screen_h * 0.02)
	_rig._chase_pitch_deg = room.chase_pitch_max_deg
	_rig._place_chase()
	_check("the commander keeps its height on the screen at the highest pitch too",
			absf(_chase_cam().unproject_position(_pivot()).y - ys[0]) <= screen_h * 0.02)
	_check("at the highest pitch the middle of the screen no longer meets the ground", _centre_hit() == null)
	_check_shoulder_and_pitch(room)
	_check_zoom(room)
	_rig._chase_pitch_deg = room.chase_pitch_min_deg
	_rig._input(_motion(Vector2(100000, 0)))
	_check("a long turn keeps the yaw finite and in one turn", is_finite(_yaw()) and absf(_yaw()) <= PI + 0.001)
	TimeManager.request_pause(TimeManager.REASON_USER)
	_check("pause gives the cursor back", not _rig.is_cursor_captured() and not _crosshair_shown())
	var y1 := _yaw()
	_rig._input(_motion(Vector2(200, 0)))
	_check("mouse motion does nothing while paused", is_equal_approx(_yaw(), y1))
	TimeManager.release_pause(TimeManager.REASON_USER)
	_check("closing the pause captures the cursor again", _rig.is_cursor_captured() and _crosshair_shown())
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var y2 := _yaw()
	_rig._input(click)
	_check("a click does not turn the view", is_equal_approx(_yaw(), y2))
	EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
	EventBus.state_changed.emit(&"PREP")
	_check("leaving gives the cursor back", not _rig.is_cursor_captured() and not _crosshair_shown())
	var cy := _camera.global_rotation.y
	_rig._input(_motion(Vector2(300, 0)))
	_check("mouse motion does not turn the corridor camera", is_equal_approx(_camera.global_rotation.y, cy))
	_commander.global_position = _spawn_in_room()
	EventBus.hazard_trial_entered.emit(5, [])
	_check("entering again starts at the corridor yaw and the room pitch",
			absf(angle_difference(_yaw(), _camera.global_rotation.y)) < 0.01
			and absf(_orbit_pitch_deg() - room.chase_pitch_deg) < 0.5)
	EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)

	# No commander: the chase view looks at CameraFrame.
	_new_rig()
	_enter_prep()
	_commander.remove_from_group(&"commander")
	EventBus.hazard_trial_entered.emit(5, [])
	_check("no commander: the chase view looks at CameraFrame", _at(_room_focus()) and _view() == _chase_cam())
	EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
	_commander.add_to_group(&"commander")

	# Leaving into another state than PREP (a reset or a recovery): that state's own frame.
	_new_rig()
	_enter_prep()
	EventBus.hazard_trial_entered.emit(5, [])
	_frames.clear()
	EventBus.state_changed.emit(&"COMBAT")
	_check("leaving into COMBAT frames the commander in Frontline",
		_at(_rig.bounds.clamp_focus(Vector3(-6, 0, 0), true)) and _frames == [&"FRONTLINE"])
	_check("leaving into COMBAT uses the Frontline size", is_equal_approx(_camera.size, _rig.bounds.camera_size_frontline))
	_check("leaving into COMBAT is not taken for PREP", not _rig.is_panning_enabled())
	_check("leaving into COMBAT gives the view back to the corridor camera", _view() == _camera)

	# Without a room the frame still locks and reports, and leaving restores PREP.
	_remove_room()
	_new_rig()
	_enter_prep()
	EventBus.hazard_trial_entered.emit(5, [])
	_step(0.3)
	_check("no room: the camera stays where it was", _at(Vector3.ZERO))
	_check("no room: still reports HAZARD_TRIAL and locks panning", _frames == [&"HAZARD_TRIAL"] and not _rig.is_panning_enabled())
	_check("no room: the corridor camera stays the view", _view() == _camera)
	_check("no room: the cursor stays free", not _rig.is_cursor_captured())
	EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
	_check("no room: leaving reports OVERVIEW", _frames == [&"HAZARD_TRIAL", &"OVERVIEW"])

	# Freeing the rig while it holds the cursor must not error.
	_add_room()
	_enter_room()
	_rig.bounds.free()
	_rig.free()
	_rig = null
	_remove_room()


## Shoulder offset, the pitch range with the floor clamp, from the entry pitch onwards.
func _check_shoulder_and_pitch(room: HazardRoom) -> void:
	_rig._chase_pitch_deg = room.chase_pitch_deg
	_rig._place_chase()
	var yaw_basis := Basis(Vector3.UP, _yaw())
	var orbit := Basis.from_euler(Vector3(deg_to_rad(room.chase_pitch_deg), _yaw(), 0.0))
	var expected := _pivot() + orbit.z * _expected_distance(room.chase_pitch_deg) \
			+ yaw_basis.x * room.chase_shoulder_offset
	_check("the camera stands over the commander's right shoulder",
			_chase_cam().global_position.distance_to(expected) < 0.01)
	_check("the middle of the screen lands ahead, offset to the right by the shoulder", _centre_ahead_ok())
	_check("the move keys follow the camera with the shoulder offset",
			_flat_forward().dot(Vector3.FORWARD.rotated(Vector3.UP, _yaw())) > 0.999)

	_rig._input(_motion(Vector2(0, -100000)))
	_check("the camera looks up to the room's highest pitch",
			absf(_orbit_pitch_deg() - 30.0) < 0.05 and room.chase_pitch_max_deg == 30.0)
	var floor_ok := true
	var pitch := room.chase_pitch_min_deg
	while pitch <= room.chase_pitch_max_deg + 0.001:
		for zoom in [1.0, room.chase_zoom_min]:
			_rig._chase_pitch_deg = pitch
			_rig._chase_zoom = zoom
			_rig._place_chase()
			var height := _chase_cam().global_position.y - _rig.global_position.y
			floor_ok = floor_ok and height >= room.chase_min_height - 0.001
		pitch += 5.0
	_rig._chase_zoom = 1.0
	_check("the camera never goes below the minimum height at any pitch and zoom", floor_ok)
	var last := INF
	var nearer := true
	for p in [0.0, 15.0, 30.0]:
		_rig._chase_pitch_deg = p
		_rig._place_chase()
		var dist := (_shoulder_point() - _chase_cam().global_position).length()
		nearer = nearer and dist < last and absf(dist - _expected_distance(p)) < 0.01
		last = dist
	_check("looking up brings the camera nearer", nearer)
	_rig._chase_pitch_deg = room.chase_pitch_max_deg
	_rig._place_chase()
	_check("at the highest pitch the middle of the screen misses the ground", _centre_hit() == null)


func _notch(button: MouseButton, count: int) -> void:
	for i in count:
		_rig._input(_wheel(button))


func _reset_zoom() -> void:
	_rig._chase_zoom = 1.0
	_rig._chase_zoom_target = 1.0
	_rig._place_chase()


func _cam_distance() -> float:
	return (_shoulder_point() - _chase_cam().global_position).length()


## Mouse wheel zoom: glide, limits, touchpad notches, free cursor, reduced motion and re-entering.
func _check_zoom(room: HazardRoom) -> void:
	_rig._chase_pitch_deg = room.chase_far_pitch_deg
	_reset_zoom()
	var far_dist := _cam_distance()
	_rig._input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	_check("the wheel glides: nothing moves on the event itself", is_equal_approx(_cam_distance(), far_dist))
	_step(0.016)
	var mid := _cam_distance()
	_check("after one tick the zoom is between old and new", mid < far_dist - 0.001 and mid > room.chase_distance * (1.0 - room.chase_zoom_step) + 0.001)
	_step(1.0)
	_check("one notch up zooms in by the step",
			absf(_cam_distance() - room.chase_distance * (1.0 - room.chase_zoom_step)) < 0.01
			and absf(_cam_distance() - _expected_distance(room.chase_far_pitch_deg)) < 0.01)
	_check("zooming keeps the shoulder and the tilt", _chase_geometry_ok())

	_reset_zoom()
	_notch(MOUSE_BUTTON_WHEEL_UP, 100)
	_step(1.0)
	_check("zoom stops at the nearest zoom", absf(_rig._chase_zoom - room.chase_zoom_min) < 0.001)
	_reset_zoom()
	_notch(MOUSE_BUTTON_WHEEL_DOWN, 100)
	_step(1.0)
	_check("zoom never goes out past the normal distance",
			absf(_rig._chase_zoom - 1.0) < 0.001 and absf(_cam_distance() - room.chase_distance) < 0.01)

	_reset_zoom()
	_rig._input(_wheel(MOUSE_BUTTON_WHEEL_UP, 0.5))
	_check("a touchpad notch zooms by its factor",
			absf(_rig._chase_zoom_target - (1.0 - 0.5 * room.chase_zoom_step)) < 0.0001)

	_reset_zoom()
	TimeManager.request_pause(TimeManager.REASON_USER)
	_step(0.016)
	_rig._input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	_check("the wheel does nothing while the cursor is free", _rig._chase_zoom_target == 1.0)
	TimeManager.release_pause(TimeManager.REASON_USER)
	_step(0.016)

	_reset_zoom()
	_rig._input(_wheel(MOUSE_BUTTON_WHEEL_UP, 1.0, false))
	_rig._input(_wheel(MOUSE_BUTTON_LEFT))
	_check("a released wheel or another button does not zoom", _rig._chase_zoom_target == 1.0)

	_reset_zoom()
	_rig.reduced_motion = true
	_rig._input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	var instant := absf(_cam_distance() - room.chase_distance * (1.0 - room.chase_zoom_step)) < 0.01
	_rig.reduced_motion = false
	_check("reduced motion zooms at once", instant)

	_notch(MOUSE_BUTTON_WHEEL_UP, 3)
	EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
	EventBus.state_changed.emit(&"PREP")
	_commander.global_position = _spawn_in_room()
	EventBus.hazard_trial_entered.emit(5, [])
	_check("entering the room again resets the zoom", _rig._chase_zoom == 1.0 and _rig._chase_zoom_target == 1.0)


## Cases that need the input stream or a frame: real events and a dialog leaving its holder.
func _run_cursor_events() -> void:
	_add_room()
	_enter_room()
	await get_tree().process_frame
	var y0 := _yaw()
	Input.parse_input_event(_motion(Vector2(50, 0)))
	Input.flush_buffered_events()
	_check("the rig reads mouse motion from the input stream", absf(angle_difference(_yaw(), y0)) > 0.001)

	Input.parse_input_event(_wheel(MOUSE_BUTTON_WHEEL_UP))
	Input.flush_buffered_events()
	_check("the rig reads the wheel from the input stream", _rig._chase_zoom_target < 1.0)

	var key := InputEventKey.new()
	key.physical_keycode = _rig.free_cursor_key
	key.keycode = _rig.free_cursor_key
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	_step(0.016)
	_check("holding the free-cursor key gives the cursor back", not _rig.is_cursor_captured())
	var y1 := _yaw()
	_rig._input(_motion(Vector2(200, 0)))
	_check("mouse motion does nothing while the cursor is free", is_equal_approx(_yaw(), y1))
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	_step(0.016)
	_check("letting go of the key captures the cursor again", _rig.is_cursor_captured())

	ScreenManager.open_dialog(Control.new())
	_step(0.016)
	_check("a dialog gives the cursor back", not _rig.is_cursor_captured())
	ScreenManager.close_all_dialogs()
	await get_tree().process_frame
	_step(0.016)
	_check("closing the dialog captures the cursor again", _rig.is_cursor_captured())

	EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
	_rig.bounds.free()
	_rig.free()
	_rig = null
	_remove_room()


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("OK   ", label)
	else:
		_fail += 1
		print("FAIL ", label)
