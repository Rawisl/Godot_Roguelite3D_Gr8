extends Node3D
## Test for the camera in the Hazard Trial (CAM-16, HZT-11, EVB-35): entering cuts to the room's
## fixed frame and size, nothing moves it there (follow, move keys, C, Tab), leaving cuts back to
## the PREP frame, either signal order works, and camera_frame_changed reports every frame once.
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


func _enter_prep() -> void:
	EventBus.state_changed.emit(&"PREP")
	_step(0.6)
	_frames.clear()


func _run() -> void:
	_add_room()
	var overview := 18.0

	# Entering from PREP with hazard_trial_entered: a cut on the same frame, room size, one signal.
	_new_rig()
	_enter_prep()
	EventBus.hazard_trial_entered.emit(5, [])
	_check("entering cuts to the room focus at once", _at(_room_focus()))
	_check("entering sets the room camera size at once", is_equal_approx(_camera.size, _room_size()))
	_check("entering reports HAZARD_TRIAL once", _frames == [&"HAZARD_TRIAL"])
	_check("the rig says it is in the Hazard Trial", _rig.is_in_hazard_trial() and _rig.get_frame() == &"HAZARD_TRIAL")
	_check("panning is off in the room", not _rig.is_panning_enabled())

	# The second signal of the pair (the HAZARD_TRIAL state) changes nothing.
	EventBus.state_changed.emit(&"HAZARD_TRIAL")
	_check("the HAZARD_TRIAL state after the signal sends nothing more", _frames.size() == 1)

	# Nothing moves the frame in the room: the commander walking, the move keys, C, Tab.
	_commander.global_position = _room_focus() + Vector3(8, 0, 4)
	_step(1.0)
	_check("the camera does not follow the commander in the room", _at(_room_focus()))
	Input.action_press(&"move_right")
	Input.action_press(&"move_up")
	_step(0.8)
	Input.action_release(&"move_right")
	Input.action_release(&"move_up")
	_check("the move keys do not pan the camera in the room", _at(_room_focus()))
	var recenter := InputEventAction.new()
	recenter.action = &"camera_recenter"
	recenter.pressed = true
	_rig._unhandled_input(recenter)
	_step(0.5)
	_check("C does nothing in the room", _at(_room_focus()) and is_equal_approx(_camera.size, _room_size()))
	EventBus.mode_changed.emit(&"COMMANDER")
	_step(0.6)
	EventBus.mode_changed.emit(&"FRONTLINE")
	_step(0.6)
	_check("a mode change keeps the room frame", _at(_room_focus()) and is_equal_approx(_camera.size, _room_size()))
	_check("a mode change in the room sends no frame", _frames.size() == 1)

	# Leaving with hazard_trial_exited first: a cut to the PREP frame, then PREP changes nothing.
	EventBus.hazard_trial_exited.emit(&"LEFT", 2, 10, 4.0, 0)
	_check("leaving cuts back to the middle of the corridor", _at(Vector3.ZERO))
	_check("leaving sets the overview size at once", is_equal_approx(_camera.size, overview))
	_check("leaving reports OVERVIEW once", _frames == [&"HAZARD_TRIAL", &"OVERVIEW"])
	EventBus.state_changed.emit(&"PREP")
	_step(0.6)
	_check("the PREP state after leaving keeps the PREP frame", _at(Vector3.ZERO) and is_equal_approx(_camera.size, overview))
	_check("the PREP state after leaving sends nothing more", _frames.size() == 2)
	_check("panning works again in PREP", _rig.is_panning_enabled())

	# The other order: the HAZARD_TRIAL state first, PREP before hazard_trial_exited.
	_new_rig()
	_enter_prep()
	EventBus.state_changed.emit(&"HAZARD_TRIAL")
	EventBus.hazard_trial_entered.emit(5, [])
	_check("state first: cut to the room, one HAZARD_TRIAL", _at(_room_focus()) and _frames == [&"HAZARD_TRIAL"])
	EventBus.state_changed.emit(&"PREP")
	EventBus.hazard_trial_exited.emit(&"WON", 5, 30, 12.0, 1)
	_check("PREP first: back to the corridor, one OVERVIEW", _at(Vector3.ZERO) and _frames == [&"HAZARD_TRIAL", &"OVERVIEW"])
	_check("PREP first: overview size", is_equal_approx(_camera.size, overview))

	# Panned away in PREP before entering: leaving still returns to the default focus (CAM-07).
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

	# Without a room the frame still locks and reports, and leaving restores PREP.
	_remove_room()
	_new_rig()
	_enter_prep()
	EventBus.hazard_trial_entered.emit(5, [])
	_step(0.3)
	_check("no room: the camera stays where it was", _at(Vector3.ZERO))
	_check("no room: still reports HAZARD_TRIAL and locks panning", _frames == [&"HAZARD_TRIAL"] and not _rig.is_panning_enabled())
	EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
	_check("no room: leaving reports OVERVIEW", _frames == [&"HAZARD_TRIAL", &"OVERVIEW"])

	_rig.bounds.free()
	_rig.free()
	_rig = null


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("OK   ", label)
	else:
		_fail += 1
		print("FAIL ", label)
