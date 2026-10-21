extends Node3D
## Manual test for CameraRig bounds, acceleration, context reset and recenter. Not shipped.
## Run with F6, prints OK/FAIL per case then quits.

var _pass := 0
var _fail := 0
var _rig: CameraRig
var _commander: Node3D

func _ready() -> void:
	_commander = Node3D.new()
	_commander.add_to_group(&"commander")
	add_child(_commander)
	_run()
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func _new_rig() -> void:
	if _rig != null:
		_rig.free()
	_rig = CameraRig.new()
	add_child(_rig)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_rig.add_child(camera)
	camera.look_at_from_position(Vector3(16, 16, 16), Vector3.ZERO)
	camera.current = true
	_rig._camera = camera

func _step(seconds: float, tick := 0.016) -> void:
	var left := seconds
	while left > 0.0:
		_rig._process(minf(tick, left))
		left -= tick

func _release_all() -> void:
	for action in CameraRig.MOVE_ACTIONS:
		Input.action_release(action)

func _run() -> void:
	_new_rig()
	Input.action_press(&"move_right")
	_step(1.0)
	_check("frontline ignores the keys", _rig.position.is_zero_approx())
	_release_all()

	# Pan in PREP: ramps up, moves in screen space, never leaves the bounds.
	EventBus.state_changed.emit(&"PREP")
	_step(0.6)
	_check("transition into PREP finishes", not _rig.is_gliding())
	_release_all()
	Input.action_press(&"move_right")
	_step(0.05)
	var early := _rig.position.length()
	_step(0.05)
	_check("pan accelerates instead of jumping", early > 0.0 and early < 14.0 * 0.05)
	_step(10.0)
	_check("pan stops at the bounds", _rig.position.x <= 20.0 + 0.001 and _rig.position.z <= 10.0 + 0.001)
	_check("pan reached the bounds edge", is_equal_approx(_rig.position.x, 20.0) or is_equal_approx(_rig.position.z, 10.0))
	_release_all()
	_step(0.5)

	# Pan speed is real time: the game speed does not change it.
	_new_rig()
	EventBus.state_changed.emit(&"PREP")
	_step(0.6)
	_release_all()
	Input.action_press(&"move_left")
	_step(0.5)
	var at_x1 := _rig.position
	_release_all()
	_new_rig()
	EventBus.state_changed.emit(&"PREP")
	_step(0.6)
	_release_all()
	Engine.time_scale = 3.0
	Input.action_press(&"move_left")
	for i in 31:
		_rig._process(0.016 * 3.0)
	Engine.time_scale = 1.0
	_release_all()
	_check("pan distance is the same at x3", _rig.position.distance_to(at_x1) < 0.5)

	# Entering PREP resets the focus, nothing is remembered.
	_new_rig()
	EventBus.state_changed.emit(&"PREP")
	_step(0.6)
	_release_all()
	Input.action_press(&"move_right")
	_step(0.5)
	_release_all()
	_step(0.5)
	_check("camera was panned away", _rig.position.x > 1.0)
	EventBus.state_changed.emit(&"COMBAT")
	_step(0.6)
	_check("back in frontline the camera is home", _rig.position.is_zero_approx())
	EventBus.state_changed.emit(&"PREP")
	_step(0.6)
	_check("PREP starts from the middle of the bounds", _rig.position.is_zero_approx())

	# Commander mode starts at the commander, clamped to the bounds.
	_commander.global_position = Vector3(8, 0, 3)
	EventBus.mode_changed.emit(&"COMMANDER")
	_step(0.6)
	_check("commander mode focuses the commander", _rig.position.distance_to(Vector3(8, 0, 3)) < 0.01)
	_commander.global_position = Vector3(60, 0, 0)
	EventBus.mode_changed.emit(&"FRONTLINE")
	EventBus.state_changed.emit(&"COMBAT")
	_step(0.6)
	EventBus.mode_changed.emit(&"COMMANDER")
	_step(0.6)
	_check("commander focus is clamped to the bounds", is_equal_approx(_rig.position.x, 20.0))

	# Input is ignored during the glide, and held keys must be released and pressed again.
	_new_rig()
	Input.action_press(&"move_right")
	EventBus.state_changed.emit(&"PREP")
	_step(0.6)
	_check("held key at context change does not drift", _rig.position.is_zero_approx())
	_release_all()
	_step(0.05)
	Input.action_press(&"move_right")
	_step(0.3)
	_check("pressing again pans", _rig.position.length() > 0.1)
	_release_all()

	# Recenter takes recenter_time on real time, not an instant snap.
	_step(0.5)
	Input.action_press(&"move_right")
	_step(0.5)
	_release_all()
	_step(0.3)
	_rig._unhandled_input(_action_event(&"camera_recenter"))
	_step(0.1)
	_check("recenter is not instant", _rig.is_gliding() and _rig.position.length() > 0.01)
	_step(0.3)
	_check("recenter ends at the default focus", not _rig.is_gliding() and _rig.position.is_zero_approx())

func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event

func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("[test] %s %s" % [label, "OK" if ok else "FAIL"])
