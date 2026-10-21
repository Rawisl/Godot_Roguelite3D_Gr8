class_name CameraRig
extends Node3D
## Camera focus on the ground plane. In Commander mode and PREP the move keys pan it;
## in Frontline it returns to its home position. Runs on real time, so panning ignores
## the game speed and keeps working while paused.

const MOVE_ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right"]
const CONTEXT_FRONTLINE := &"FRONTLINE"
const CONTEXT_COMMANDER := &"COMMANDER"
const CONTEXT_PREP := &"PREP"

@export var camera_pan_speed: float = 14.0
## Seconds to reach full pan speed, so starting and stopping does not jerk.
@export var accel_time: float = 0.1
## Seconds for the focus to glide to its default when the context changes.
@export var transition_time: float = 0.5
@export var recenter_time: float = 0.3
## Set by hand in the level. Limits the focus on the ground plane (x, z). No area means no limit.
@export var camera_bounds: Rect2 = Rect2()

var _home: Vector3
var _velocity: Vector3 = Vector3.ZERO
var _commander_mode: bool = false
var _in_prep: bool = false
var _blocked: Dictionary = {}  # move actions held when the context changed
var _glide_from: Vector3
var _glide_to: Vector3
var _glide_total: float = 0.0
var _glide_left: float = 0.0
var _camera: Camera3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_home = position
	_camera = find_child("*", true, false) as Camera3D
	EventBus.mode_changed.connect(_on_mode_changed)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.pause_changed.connect(func(_paused: bool) -> void: _clear_held())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_held()


func is_panning_enabled() -> bool:
	return _context() != CONTEXT_FRONTLINE


func is_gliding() -> bool:
	return _glide_left > 0.0


func _unhandled_input(event: InputEvent) -> void:
	if is_panning_enabled() and event.is_action_pressed(&"camera_recenter", false):
		_glide_to_focus(get_default_focus(), recenter_time)


## Where the camera goes when entering a context: the commander in Commander mode,
## the middle of the bounds in PREP, home in Frontline.
func get_default_focus() -> Vector3:
	match _context():
		CONTEXT_COMMANDER:
			var commander := get_tree().get_first_node_in_group(&"commander") as Node3D
			if commander != null:
				return _clamped(Vector3(commander.global_position.x, _home.y, commander.global_position.z))
		CONTEXT_PREP:
			if camera_bounds.has_area():
				var center := camera_bounds.get_center()
				return Vector3(center.x, _home.y, center.y)
	return _home


func _process(delta: float) -> void:
	# delta is scaled by Engine.time_scale; the camera must not follow the game speed.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if _glide_left > 0.0:
		_update_glide(real_delta)
		return

	var target := Vector3.ZERO
	if is_panning_enabled():
		target = _screen_to_ground(_move_vector()) * camera_pan_speed
	var step := camera_pan_speed / maxf(accel_time, 0.001) * real_delta
	_velocity = _velocity.move_toward(target, step)
	if _velocity.is_zero_approx():
		return
	position = _clamped(position + _velocity * real_delta)


func _update_glide(real_delta: float) -> void:
	_glide_left = maxf(_glide_left - real_delta, 0.0)
	var progress := 1.0 - _glide_left / _glide_total
	# Ease-out: fast at first, settling at the end.
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	position = _clamped(_glide_from.lerp(_glide_to, eased))


func _glide_to_focus(focus: Vector3, duration: float) -> void:
	_velocity = Vector3.ZERO
	_glide_from = position
	_glide_to = _clamped(focus)
	_glide_total = maxf(duration, 0.001)
	_glide_left = _glide_total


func _context() -> StringName:
	if _commander_mode:
		return CONTEXT_COMMANDER
	if _in_prep:
		return CONTEXT_PREP
	return CONTEXT_FRONTLINE


func _move_vector() -> Vector2:
	var strength := func(action: StringName) -> float:
		if _blocked.has(action):
			if Input.is_action_pressed(action):
				return 0.0
			_blocked.erase(action)
		return Input.get_action_strength(action)
	var vector := Vector2(
			strength.call(&"move_right") - strength.call(&"move_left"),
			strength.call(&"move_down") - strength.call(&"move_up"))
	return vector.limit_length(1.0)


## Held keys are ignored until released, so a context change never leaves the camera drifting.
func _clear_held() -> void:
	for action in MOVE_ACTIONS:
		if Input.is_action_pressed(action):
			_blocked[action] = true


func _screen_to_ground(input: Vector2) -> Vector3:
	var camera := _camera if _camera != null else get_viewport().get_camera_3d()
	if camera == null or input == Vector2.ZERO:
		return Vector3.ZERO
	var cam_basis := camera.global_transform.basis
	var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	return right * input.x + forward * (-input.y)


func _clamped(focus: Vector3) -> Vector3:
	if not camera_bounds.has_area():
		return focus
	focus.x = clampf(focus.x, camera_bounds.position.x, camera_bounds.end.x)
	focus.z = clampf(focus.z, camera_bounds.position.y, camera_bounds.end.y)
	return focus


func _on_mode_changed(mode: StringName) -> void:
	var before := _context()
	_commander_mode = (mode == &"COMMANDER")
	_clear_held()
	if _context() != before:
		_glide_to_focus(get_default_focus(), transition_time)


func _on_state_changed(new_state: StringName) -> void:
	var before := _context()
	_in_prep = (new_state == &"PREP")
	_clear_held()
	# Every PREP starts from the default focus, even when Commander mode carried over.
	if _context() != before or new_state == &"PREP":
		_glide_to_focus(get_default_focus(), transition_time)
