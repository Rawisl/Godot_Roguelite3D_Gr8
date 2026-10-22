class_name CameraRig
extends Node3D
## Camera focus on the ground plane. Frontline follows the commander, Commander mode and PREP
## let the move keys pan it. Runs on TimeManager's real-time clock, so it ignores the game
## speed and keeps working while paused.

const MOVE_ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right"]
const CONTEXT_FRONTLINE := &"FRONTLINE"
const CONTEXT_COMMANDER := &"COMMANDER"
const CONTEXT_PREP := &"PREP"
const STATE_BOSS_INTRO := &"BOSS_INTRO"
const STATE_REWARD_PICK := &"REWARD_PICK"

@export var camera_pan_speed: float = 14.0
## Seconds to reach full pan speed, so starting and stopping does not jerk.
@export var accel_time: float = 0.1
## Seconds for the focus and the ortho size to glide when the context changes.
@export var transition_time: float = 0.5
@export var recenter_time: float = 0.3
## Smoothing time constant of the Frontline follow.
@export var follow_smoothing: float = 0.15
## Limits the focus and supplies the ortho sizes. Without it the focus is unlimited
## and the camera size is left alone.
@export var bounds: CameraBounds
## Replaces every glide with an instant cut. Also set through the "reduced_motion" setting.
@export var reduced_motion: bool = false

var _home: Vector3
var _velocity: Vector3 = Vector3.ZERO
var _commander_mode: bool = false
var _in_prep: bool = false
var _state: StringName = &""
var _blocked: Dictionary = {}  # move actions held when the context changed
var _glide_from: Vector3
var _glide_to: Vector3
var _glide_total: float = 0.0
var _glide_left: float = 0.0
var _size_from: float = 0.0
var _size_to: float = 0.0
var _size_total: float = 0.0
var _size_left: float = 0.0
var _last_real_time: float = 0.0
var _camera: Camera3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# After the commander's move_and_slide, so the follow reads this tick's position.
	process_physics_priority = 100
	_home = position
	_camera = find_child("*", true, false) as Camera3D
	_last_real_time = TimeManager.real_time
	if _camera != null and bounds != null:
		_camera.size = _target_size()
	EventBus.mode_changed.connect(_on_mode_changed)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.pause_changed.connect(func(_paused: bool) -> void: _clear_held())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_held()


## Panning is off in Frontline and while the boss intro or a reward pick owns the screen.
func is_panning_enabled() -> bool:
	if _context() == CONTEXT_FRONTLINE:
		return false
	return _state != STATE_BOSS_INTRO and _state != STATE_REWARD_PICK \
			and not TimeManager.has_pause_reason(TimeManager.REASON_REWARD_PICK)


func is_gliding() -> bool:
	return _glide_left > 0.0 or _size_left > 0.0


func _unhandled_input(event: InputEvent) -> void:
	if is_panning_enabled() and event.is_action_pressed(&"camera_recenter", false):
		_glide_to_focus(recenter_time)


## Where the camera goes when entering a context: the commander in Frontline and Commander
## mode, the middle of the bounds in PREP.
func get_default_focus() -> Vector3:
	match _context():
		CONTEXT_PREP:
			if bounds != null:
				var center := bounds.global_position
				return Vector3(center.x, _home.y, center.z)
		_:
			var commander := get_tree().get_first_node_in_group(&"commander") as Node3D
			if commander != null:
				return _clamped(Vector3(commander.global_position.x, _home.y, commander.global_position.z))
	return _home


func _process(_delta: float) -> void:
	var real_delta := _real_delta()
	_update_size(real_delta)
	if _glide_left > 0.0:
		_update_glide(real_delta)
		return

	if _context() == CONTEXT_FRONTLINE:
		_velocity = Vector3.ZERO
		return

	var target := Vector3.ZERO
	if is_panning_enabled():
		target = _screen_to_ground(_move_vector()) * camera_pan_speed
	var step := camera_pan_speed / maxf(accel_time, 0.001) * real_delta
	_velocity = _velocity.move_toward(target, step)
	if _velocity.is_zero_approx():
		return
	position = _clamped(position + _velocity * real_delta)


func _physics_process(_delta: float) -> void:
	# Real seconds covered by one physics tick.
	_follow(get_physics_process_delta_time() / maxf(Engine.time_scale, 0.001))


## Frontline follow. It must step with the commander's physics ticks: sampling the
## commander once per rendered frame mixes two clocks and makes it shake on screen.
func _follow(real_delta: float) -> void:
	if _context() != CONTEXT_FRONTLINE or _glide_left > 0.0:
		return
	var weight := 1.0 - exp(-real_delta / maxf(follow_smoothing, 0.001))
	position = _clamped(position.lerp(get_default_focus(), weight))


func _real_delta() -> float:
	var now := TimeManager.real_time
	var real_delta := maxf(now - _last_real_time, 0.0)
	_last_real_time = now
	return real_delta


func _update_glide(real_delta: float) -> void:
	_glide_left = maxf(_glide_left - real_delta, 0.0)
	var progress := 1.0 - _glide_left / _glide_total
	# The target moves with the commander, so it is read again every frame.
	_glide_to = get_default_focus()
	position = _clamped(_glide_from.lerp(_glide_to, _ease_out(progress)))


func _update_size(real_delta: float) -> void:
	if _size_left <= 0.0 or _camera == null:
		return
	_size_left = maxf(_size_left - real_delta, 0.0)
	var progress := 1.0 - _size_left / _size_total
	_camera.size = lerpf(_size_from, _size_to, _ease_out(progress))


## Fast at first, settling at the end.
func _ease_out(progress: float) -> float:
	return 1.0 - pow(1.0 - progress, 3.0)


func _glide_to_focus(duration: float) -> void:
	_velocity = Vector3.ZERO
	_glide_from = position
	_glide_to = get_default_focus()
	if reduced_motion:
		position = _glide_to
		_glide_left = 0.0
		return
	_glide_total = maxf(duration, 0.001)
	_glide_left = _glide_total


func _glide_size() -> void:
	if _camera == null or bounds == null:
		return
	_size_to = _target_size()
	if reduced_motion:
		_camera.size = _size_to
		_size_left = 0.0
		return
	_size_from = _camera.size
	_size_total = maxf(transition_time, 0.001)
	_size_left = _size_total


func _target_size() -> float:
	if _context() == CONTEXT_FRONTLINE:
		return bounds.camera_size_frontline
	return bounds.camera_size_overview


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
	return bounds.clamp_focus(focus) if bounds != null else focus


func _on_mode_changed(mode: StringName) -> void:
	var before := _context()
	_commander_mode = (mode == &"COMMANDER")
	_clear_held()
	if _context() != before:
		_glide_to_focus(transition_time)
		_glide_size()


func _on_state_changed(new_state: StringName) -> void:
	var before := _context()
	_state = new_state
	_in_prep = (new_state == &"PREP")
	_clear_held()
	# Every PREP starts from the default focus, even when Commander mode carried over.
	if _context() != before or new_state == &"PREP":
		_glide_to_focus(transition_time)
		_glide_size()


func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"reduced_motion":
		reduced_motion = bool(value)
