class_name CameraRig
extends Node3D
## Camera focus on the ground plane. Frontline follows the commander, Commander mode and PREP
## let the move keys pan it. Runs on TimeManager's real-time clock, so it ignores the game
## speed and keeps working while paused. The boss intro pan is the exception: it runs on game
## time, so it holds still while paused and lasts as long as the intro itself.
## In the Hazard Trial the view cuts to ChaseCamera, a perspective camera the rig builds itself.
## It stands behind the commander and over its right shoulder (chase_shoulder_offset), starting at
## the corridor camera's yaw (numbers on the HazardRoom), and follows the commander smoothly on
## real time; the move keys and C do not move it. The mouse turns it: while the room has the
## cursor, the cursor is captured and mouse motion turns the yaw and the pitch (within the room's
## limits, and it can look up past the horizon); the wheel zooms in, never farther than the normal
## distance. The camera orbits a pivot just above the commander and looks a few degrees above it,
## so the commander stays a little below the middle of the screen, marked by a crosshair, which
## points at the ground in front of the commander, and the commander's aim follows it. Looking up
## brings the camera nearer so it stays above chase_min_height over the floor. The cursor comes
## back while the game is paused, a dialog is open or free_cursor_key is held. Leaving cuts back
## to the PREP frame on the corridor camera. Every frame change is sent on
## EventBus.camera_frame_changed.

const MOVE_ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right"]
const CONTEXT_FRONTLINE := &"FRONTLINE"
const CONTEXT_COMMANDER := &"COMMANDER"
const CONTEXT_PREP := &"PREP"
const STATE_BOSS_INTRO := &"BOSS_INTRO"
const STATE_REWARD_PICK := &"REWARD_PICK"
const STATE_HAZARD_TRIAL := &"HAZARD_TRIAL"
const FRAME_FRONTLINE := &"FRONTLINE"
const FRAME_OVERVIEW := &"OVERVIEW"
const FRAME_BOSS_INTRO := &"BOSS_INTRO"
const FRAME_HAZARD_TRIAL := &"HAZARD_TRIAL"

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

@export_group("Screen shake")
## Cap of the shake in metres on screen, reached when trauma is 1.
@export var shake_max_offset: float = 0.35
## Trauma lost per real second. Trauma 1 settles in 1 / shake_decay seconds.
@export var shake_decay: float = 2.0
## How fast the camera wobbles, in cycles per second.
@export var shake_frequency: float = 15.0
## 1 normal, 0.5 reduced, 0 off, from the Accessibility tab. Also set through the "screen_shake" setting.
@export_range(0.0, 1.0) var shake_scale: float = 1.0

@export_group("Boss intro")
## Where the boss appears. Empty = the node in group "boss_spawn_point", then the spawn zone.
@export var boss_spawn_point: Node3D

@export_group("Hazard aim")
## Degrees the chase camera turns per screen pixel of mouse motion.
@export var mouse_sensitivity: float = 0.15
## Held, it gives the cursor back in the room, for the Leave button.
@export var free_cursor_key: Key = KEY_ALT
@export var crosshair_color := Color(1, 1, 1, 0.85)
## Length of each arm of the crosshair and its thickness, in pixels of the 1920x1080 screen.
@export var crosshair_size: float = 16.0
@export var crosshair_thickness: float = 2.0

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
var _trauma: float = 0.0
var _shake_time: float = 0.0
var _intro: bool = false
var _intro_from: Vector3
var _intro_to: Vector3
var _intro_total: float = 0.0
var _intro_left: float = 0.0
var _last_game_time: float = 0.0
var _hazard: bool = false
var _frame: StringName = &""
var _chase: Camera3D
## True while ChaseCamera is the view in the Hazard Trial room.
var _chase_on: bool = false
var _room: HazardRoom
var _orbit := ChaseCameraOrbit.new()
## True while the rig holds the cursor captured.
var _captured: bool = false
var _crosshair: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# After the commander's move_and_slide, so the follow reads this tick's position.
	process_physics_priority = 100
	_home = position
	_camera = find_child("*", true, false) as Camera3D
	_make_chase_camera()
	_make_crosshair()
	_last_real_time = TimeManager.real_time
	_last_game_time = TimeManager.game_time
	# Settings changed in the menus before this run started.
	reduced_motion = bool(GameState.get_setting(&"reduced_motion", reduced_motion))
	shake_scale = clampf(float(GameState.get_setting(&"screen_shake", shake_scale)), 0.0, 1.0)
	if _camera != null and bounds != null:
		_camera.size = _target_size()
	EventBus.mode_changed.connect(_on_mode_changed)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.screen_shake_requested.connect(_on_screen_shake_requested)
	EventBus.pause_changed.connect(_on_pause_changed)
	EventBus.hazard_trial_entered.connect(_on_hazard_trial_entered)
	EventBus.hazard_trial_exited.connect(_on_hazard_trial_exited)
	ScreenManager.dialog_context_changed.connect(_clear_held)
	_update_frame()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_held()


## Never leaves the cursor captured behind, for example when the run scene is freed.
func _exit_tree() -> void:
	if not _captured:
		return
	_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Panning is off in Frontline and while the boss intro, a reward pick or a dialog owns input.
func is_panning_enabled() -> bool:
	if _hazard or _context() == CONTEXT_FRONTLINE or ScreenManager.has_dialog():
		return false
	return _state != STATE_BOSS_INTRO and _state != STATE_REWARD_PICK \
			and not TimeManager.has_pause_reason(TimeManager.REASON_REWARD_PICK)


func is_gliding() -> bool:
	return _glide_left > 0.0 or _size_left > 0.0


## True from the start of BOSS_INTRO until the state after it begins.
func is_in_boss_intro() -> bool:
	return _intro


## True from entering the Hazard Trial room until leaving it.
func is_in_hazard_trial() -> bool:
	return _hazard


## True while the rig holds the cursor captured for the chase view.
func is_cursor_captured() -> bool:
	return _captured


## The frame sent last on camera_frame_changed: FRONTLINE, OVERVIEW, BOSS_INTRO or HAZARD_TRIAL.
func get_frame() -> StringName:
	return _frame


## Where the boss appears, on the camera's ground plane: the boss_spawn_point marker, else the
## spawn zone, else the camera's home.
func get_boss_focus() -> Vector3:
	var marker := boss_spawn_point
	if marker == null and is_inside_tree():
		marker = get_tree().get_first_node_in_group(&"boss_spawn_point") as Node3D
		if marker == null:
			marker = get_tree().get_first_node_in_group(&"spawn_zone") as Node3D
	if marker == null:
		return _home
	var p := marker.global_position
	var focus := Vector3(p.x, _home.y, p.z)
	return bounds.clamp_focus(focus, false) if bounds != null else focus


## Adds trauma in 0..1; hits close together stack up to the cap instead of adding up.
func add_shake(intensity: float) -> void:
	if shake_scale <= 0.0 or intensity <= 0.0:
		return
	_trauma = minf(_trauma + intensity, 1.0)


func get_shake_offset() -> Vector2:
	var cam := _view_camera()
	if cam == null:
		return Vector2.ZERO
	return Vector2(cam.h_offset, cam.v_offset)


## Mouse motion turns the chase view and the wheel zooms it while the cursor is captured. Read in
## _input so a GUI control in the middle of the screen cannot swallow it.
func _input(event: InputEvent) -> void:
	if not _captured:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		_turn_chase(motion.screen_relative)
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	# Touchpads send part notches through factor; a plain wheel sends 0 or 1.
	var notches := button.factor if button.factor > 0.0 else 1.0
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_chase(-notches)
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_chase(notches)


func _unhandled_input(event: InputEvent) -> void:
	for action in _blocked.keys():
		if event.is_action_released(action):
			_blocked.erase(action)
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
	_update_cursor()
	var real_delta := _real_delta()
	var game_delta := _game_delta()
	_update_shake(real_delta)
	_update_size(real_delta)
	if _hazard:
		_velocity = Vector3.ZERO
		return
	if _intro:
		_update_intro(game_delta)
		return
	if _glide_left > 0.0:
		_update_glide(real_delta)
		return

	if not is_panning_enabled():
		_velocity = Vector3.ZERO
		return

	var target := _screen_to_ground(_move_vector()) * camera_pan_speed
	var step := camera_pan_speed / maxf(accel_time, 0.001) * real_delta
	_velocity = _velocity.move_toward(target, step)
	if _velocity.is_zero_approx():
		return
	position = _clamped(position + _velocity * real_delta)


func _physics_process(_delta: float) -> void:
	# Real seconds covered by one physics tick.
	_follow(get_physics_process_delta_time() / maxf(Engine.time_scale, 0.001))


## Frontline follow, and the chase view in the Hazard Trial room. It must step with the
## commander's physics ticks: sampling the commander once per rendered frame mixes two clocks
## and makes it shake on screen.
func _follow(real_delta: float) -> void:
	if _hazard:
		_follow_chase(real_delta)
		return
	if _intro or _context() != CONTEXT_FRONTLINE or _glide_left > 0.0:
		return
	var weight := 1.0 - exp(-real_delta / maxf(follow_smoothing, 0.001))
	position = _clamped(position.lerp(get_default_focus(), weight))


func _real_delta() -> float:
	var now := TimeManager.real_time
	var real_delta := maxf(now - _last_real_time, 0.0)
	_last_real_time = now
	return real_delta


## Game seconds since the last frame: stops while paused and follows x2 / x3.
func _game_delta() -> float:
	var now := TimeManager.game_time
	var game_delta := maxf(now - _last_game_time, 0.0)
	_last_game_time = now
	return game_delta


## Pans from where the camera was to the boss over the whole intro, easing out, so the boss is
## framed early and the camera settles while the intro card is up.
func _start_intro() -> void:
	_intro = true
	_velocity = Vector3.ZERO
	_glide_left = 0.0
	_intro_from = position
	_intro_to = get_boss_focus()
	_intro_total = maxf(GameConfig.boss_intro_duration, 0.001)
	_intro_left = _intro_total
	_last_game_time = TimeManager.game_time
	if reduced_motion:
		position = _intro_to
		_intro_left = 0.0
	_glide_size()


func _update_intro(game_delta: float) -> void:
	if _intro_left <= 0.0:
		position = _intro_to
		return
	_intro_left = maxf(_intro_left - game_delta, 0.0)
	var progress := 1.0 - _intro_left / _intro_total
	position = _intro_from.lerp(_intro_to, _ease_out(progress))


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


## Moves the view through the camera's h_offset and v_offset, so the focus, the follow and the
## glides never see the shake. Squared trauma keeps small hits subtle. It acts on the camera
## that shows the game now.
func _update_shake(real_delta: float) -> void:
	var cam := _view_camera()
	if cam == null:
		return
	if _trauma <= 0.0:
		if cam.h_offset != 0.0 or cam.v_offset != 0.0:
			cam.h_offset = 0.0
			cam.v_offset = 0.0
		return
	_trauma = maxf(_trauma - shake_decay * real_delta, 0.0)
	_shake_time += real_delta
	var amount := shake_max_offset * shake_scale * _trauma * _trauma
	var phase := _shake_time * TAU * shake_frequency
	cam.h_offset = amount * (0.6 * sin(phase) + 0.4 * sin(phase * 2.3 + 1.7))
	cam.v_offset = amount * (0.6 * sin(phase * 1.3 + 0.5) + 0.4 * sin(phase * 2.9 + 2.9))


## Clears the offset of both cameras, since the view may be about to switch between them.
func _stop_shake() -> void:
	_trauma = 0.0
	for cam: Camera3D in [_camera, _chase]:
		if cam == null:
			continue
		cam.h_offset = 0.0
		cam.v_offset = 0.0


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


## Fast at first, settling at the end.
func _ease_out(progress: float) -> float:
	return 1.0 - pow(1.0 - progress, 3.0)


func _glide_to_focus(duration: float) -> void:
	_velocity = Vector3.ZERO
	_glide_from = position
	_glide_to = get_default_focus()
	# Already there (for example right after a cut): no glide, so panning is free at once.
	if reduced_motion or _flat_distance(_glide_from, _glide_to) < 0.01:
		position = _glide_to
		_glide_left = 0.0
		return
	_glide_total = maxf(duration, 0.001)
	_glide_left = _glide_total


func _glide_size() -> void:
	if _camera == null or bounds == null:
		return
	_size_to = _target_size()
	if reduced_motion or absf(_camera.size - _size_to) < 0.01:
		_camera.size = _size_to
		_size_left = 0.0
		return
	_size_from = _camera.size
	_size_total = maxf(transition_time, 0.001)
	_size_left = _size_total


func _target_size() -> float:
	# The intro frames the boss up close in either mode.
	if _intro or _context() == CONTEXT_FRONTLINE:
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
	_velocity = Vector3.ZERO
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
	return bounds.clamp_focus(focus, _context() == CONTEXT_FRONTLINE) if bounds != null else focus


func _on_mode_changed(mode: StringName) -> void:
	var before := _context()
	_commander_mode = (mode == &"COMMANDER")
	_clear_held()
	# The intro and the Hazard Trial keep their frame whatever the mode; the frame follows after.
	if _intro or _hazard:
		return
	if _context() != before:
		_glide_to_focus(transition_time)
		_glide_size()
	_update_frame()


func _on_state_changed(new_state: StringName) -> void:
	var before := _context()
	_state = new_state
	_in_prep = (new_state == &"PREP")
	_clear_held()
	if new_state == STATE_HAZARD_TRIAL:
		_enter_hazard()
		return
	if _hazard:
		# Leaving the room, whichever signal comes first. PREP is the normal way out; any other
		# state (a reset or a recovery) cuts to that state's own frame instead.
		_leave_hazard(new_state == &"PREP")
		if new_state == STATE_BOSS_INTRO:
			_start_intro()
			_update_frame()
		return
	if new_state == STATE_BOSS_INTRO:
		_start_intro()
		_update_frame()
		return
	var was_intro := _intro
	_intro = false
	# Every PREP starts from the default focus, even when Commander mode carried over.
	# After the intro the camera glides to the next state's frame.
	if was_intro or _context() != before or new_state == &"PREP":
		_glide_to_focus(transition_time)
		_glide_size()
	_update_frame()


## The wave side sends hazard_trial_entered and the HAZARD_TRIAL state; either one switches the
## frame, and the second one only puts the chase view back on the commander.
func _on_hazard_trial_entered(_wave_index: int, _enemy_types: Array) -> void:
	_enter_hazard()
	# The wave side moves the commander into the room right before this signal, after the
	# HAZARD_TRIAL state that may have cut in first, so the view jumps onto it here.
	_snap_chase()


func _on_hazard_trial_exited(_result: StringName, _kills: int, _gold: int, _xp: float, _mithril: int) -> void:
	if _hazard:
		_leave_hazard(true)


## Cuts to the room: a hard cut, since the room is far from the corridor and a glide would fly
## over the void. The room is the node in group "hazard_room" (HazardRoom); it gives the chase
## camera settings, the fallback focus (CameraFrame) and the orthographic size kept on the
## corridor camera.
func _enter_hazard() -> void:
	if _hazard:
		return
	_hazard = true
	_intro = false
	_velocity = Vector3.ZERO
	_glide_left = 0.0
	_size_left = 0.0
	_clear_held()
	# A hard cut of 100 m: shake left from the corridor would jolt the new frame.
	_stop_shake()
	_room = null
	if is_inside_tree():
		_room = get_tree().get_first_node_in_group(&"hazard_room") as HazardRoom
	if _room == null:
		push_warning("CameraRig: no hazard_room in the level, the camera stays where it is")
		_update_frame()
		return
	var focus := _room.get_camera_focus()
	position = Vector3(focus.x, _home.y, focus.z)
	if _camera != null and _room.camera_size > 0.0:
		_camera.size = _room.camera_size
	_start_chase()
	_update_frame()


## Reads the room's chase settings once and makes ChaseCamera the view.
func _start_chase() -> void:
	if _chase == null:
		return
	_orbit.configure(_chase, _room.get_chase_settings(),
			_camera.global_rotation.y if _camera != null else global_rotation.y)
	_chase_on = true
	_snap_chase()
	_chase.current = true
	_update_cursor()


## Puts the chase view on the commander at once, or on CameraFrame while there is none.
func _snap_chase() -> void:
	if not _chase_on:
		return
	position = _chase_focus()
	_orbit.place(global_position)


## Smooth follow of the commander in the room, on real seconds.
func _follow_chase(real_delta: float) -> void:
	if not _chase_on:
		return
	position = _orbit.follow(position, _chase_focus(), real_delta)
	_orbit.advance(real_delta, global_position)


## The commander on the camera's ground plane, else the room's CameraFrame, else where the rig is.
func _chase_focus() -> Vector3:
	var commander := get_tree().get_first_node_in_group(&"commander") as Node3D
	if commander != null:
		return Vector3(commander.global_position.x, _home.y, commander.global_position.z)
	if is_instance_valid(_room):
		var focus := _room.get_camera_focus()
		return Vector3(focus.x, _home.y, focus.z)
	return position


## Turns the chase view by a mouse motion in screen pixels: right turns right, up looks up.
func _turn_chase(screen_motion: Vector2) -> void:
	if not _chase_on:
		return
	_orbit.turn(screen_motion, mouse_sensitivity, global_position)


## Zooms the chase view by wheel notches: negative comes nearer. It never goes past the normal
## distance, so the camera cannot leave the sky. Glides there unless reduced motion is on.
func _zoom_chase(notches: float) -> void:
	if not _chase_on:
		return
	_orbit.change_zoom(notches, reduced_motion, global_position)


## The room keeps the cursor captured unless the game is paused, a dialog is open or
## free_cursor_key is held, so the pause menu, dialogs and the Leave button can be clicked.
func _wants_captured_cursor() -> bool:
	if not _chase_on:
		return false
	if TimeManager.is_paused or ScreenManager.has_dialog():
		return false
	return not Input.is_physical_key_pressed(free_cursor_key)


## Captures or frees the cursor when the wanted state changes. Only the state this rig set is
## undone, so the rig never fights other code over the mouse mode outside the room.
func _update_cursor() -> void:
	var want := _wants_captured_cursor()
	if want == _captured:
		return
	_captured = want
	if _crosshair != null:
		_crosshair.visible = want
	if not want:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	# Start from the middle, where the aim ray is taken.
	var viewport := get_viewport()
	viewport.warp_mouse(viewport.get_visible_rect().size * 0.5)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## A small cross in the middle of the screen, shown while the cursor is captured.
func _make_crosshair() -> void:
	_crosshair = CanvasLayer.new()
	_crosshair.name = "Crosshair"
	_crosshair.visible = false
	add_child(_crosshair)
	_add_crosshair_bar(Vector2(crosshair_size, crosshair_thickness))
	_add_crosshair_bar(Vector2(crosshair_thickness, crosshair_size))


func _add_crosshair_bar(bar_size: Vector2) -> void:
	var bar := ColorRect.new()
	bar.color = crosshair_color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_CENTER)
	bar.offset_left = -bar_size.x * 0.5
	bar.offset_right = bar_size.x * 0.5
	bar.offset_top = -bar_size.y * 0.5
	bar.offset_bottom = bar_size.y * 0.5
	_crosshair.add_child(bar)


## Hands the view back to the corridor camera.
func _stop_chase() -> void:
	_room = null
	if not _chase_on:
		return
	_chase_on = false
	_update_cursor()
	if _camera != null:
		_camera.current = true


## The camera that shows the game now: ChaseCamera in the room, the corridor camera otherwise.
func _view_camera() -> Camera3D:
	return _chase if _chase_on else _camera


## The Hazard Trial view, built here so every rig has one. Off until the room.
func _make_chase_camera() -> void:
	_chase = Camera3D.new()
	_chase.name = "ChaseCamera"
	_chase.projection = Camera3D.PROJECTION_PERSPECTIVE
	add_child(_chase)


## Cuts out of the room. Back to PREP: the default PREP frame, the middle of the corridor at
## the overview size, whatever the mode (a pan made before entering is not restored). Into any
## other state: that state's default frame. Either way the view goes back to the corridor camera.
func _leave_hazard(to_prep: bool) -> void:
	_hazard = false
	if to_prep:
		_in_prep = true
	_velocity = Vector3.ZERO
	_glide_left = 0.0
	_size_left = 0.0
	_clear_held()
	_stop_shake()
	_stop_chase()
	position = _prep_focus() if to_prep else get_default_focus()
	if _camera != null and bounds != null:
		_camera.size = bounds.camera_size_overview if to_prep else _target_size()
	_update_frame()


## The middle of the camera bounds, the PREP frame's focus.
func _prep_focus() -> Vector3:
	if bounds == null:
		return _home
	var center := bounds.global_position
	return Vector3(center.x, _home.y, center.z)


func _current_frame() -> StringName:
	if _hazard:
		return FRAME_HAZARD_TRIAL
	if _intro:
		return FRAME_BOSS_INTRO
	return FRAME_FRONTLINE if _context() == CONTEXT_FRONTLINE else FRAME_OVERVIEW


## Sends camera_frame_changed when the frame starts to change, once per change.
func _update_frame() -> void:
	var frame := _current_frame()
	if frame == _frame:
		return
	_frame = frame
	EventBus.camera_frame_changed.emit(frame)


func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"reduced_motion":
		reduced_motion = bool(value)
	elif key == &"screen_shake":
		shake_scale = clampf(float(value), 0.0, 1.0)
		if shake_scale <= 0.0:
			_stop_shake()


func _on_screen_shake_requested(intensity: float, _source: StringName) -> void:
	add_shake(intensity)


## A paused frame holds still, so the shake is dropped rather than frozen mid-swing.
func _on_pause_changed(paused: bool) -> void:
	_clear_held()
	if paused:
		_stop_shake()
	_update_cursor()
