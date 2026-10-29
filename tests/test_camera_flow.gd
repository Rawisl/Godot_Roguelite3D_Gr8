extends Node
## Camera in the real game: loads main.tscn and drives the wave manager and the commander's
## ModeSwitch (Tab, Recall, Deploy) instead of sending signals by hand. Not shipped.
## Run with F6, prints OK/FAIL per case then quits.

const MAIN_SCENE := "res://main.tscn"
## The rig moves the focus on the ground, so it is compared on X and Z only.
const NEAR := 0.15

var _pass := 0
var _fail := 0
var _main: Node
var _rig: CameraRig
var _camera: Camera3D
var _commander: Node3D
var _switch: ModeSwitch
var _waves: WaveManager


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child(_main)
	await _frames(5)
	_rig = _main.find_child("CameraRig", true, false) as CameraRig
	_waves = _main.find_child("WaveManager", true, false) as WaveManager
	_commander = get_tree().get_first_node_in_group(&"commander") as Node3D
	if _commander == null:
		_commander = _spawn_commander()
		await _frames(2)
	_switch = _commander.find_child("ModeSwitch", true, false) as ModeSwitch if _commander != null else null
	if _rig == null or _waves == null or _switch == null or _rig.bounds == null:
		print("[test] FAIL main.tscn is missing the camera rig, its bounds, the wave manager or the commander")
		get_tree().quit(1)
		return
	_camera = _rig.find_child("*", true, false) as Camera3D
	await _run()
	_release_moves()
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _run() -> void:
	var bounds := _rig.bounds
	var centre := _flat(bounds.global_position)

	# Entering PREP: overview, middle of the corridor.
	_waves.start_prep()
	_check("entering PREP starts a glide", _rig.is_gliding())
	await _wait(0.6)
	_check("PREP focus is the middle of the bounds", _near(_focus(), centre))
	_check("PREP uses the overview size", is_equal_approx(_camera.size, bounds.camera_size_overview))

	# The bounds reach both ends of the map.
	var fortress := get_tree().get_first_node_in_group(&"fortress") as Node3D
	var spawn := get_tree().get_first_node_in_group(&"spawn_zone") as Node3D
	if fortress != null:
		_check("Fortress is in frame with the focus at the left end", _in_frame_at_end(fortress.global_position, -1))
	if spawn != null:
		_check("spawn zone is in frame with the focus at the right end", _in_frame_at_end(spawn.global_position, 1))

	# Pan, then C brings it back.
	await _hold(&"move_right", 0.4)
	var panned := _focus()
	_check("WASD pans in PREP", panned.distance_to(centre) > 1.0)
	_press(&"camera_recenter")
	await _wait(0.1)
	_check("recenter glides, it does not jump", _rig.is_gliding() and _focus().distance_to(centre) > NEAR)
	await _wait(0.3)
	_check("C returns to the middle in 0.3 s", _near(_focus(), centre))

	# Pan still works while paused, on the real-time clock.
	TimeManager.request_pause(TimeManager.REASON_USER)
	await _hold(&"move_left", 0.3)
	_check("WASD pans while paused", _focus().distance_to(centre) > 1.0)
	TimeManager.release_pause(TimeManager.REASON_USER)
	_press(&"camera_recenter")
	await _wait(0.4)

	# Tab in PREP: free switch to Commander mode, focus on the commander at the command post.
	_switch.request()
	await _frames(1)
	_check("Tab in PREP enters Commander mode", _commander.is_commander_mode)
	_check("Tab starts a 0.5 s glide", _rig.is_gliding())
	# Keys pressed during the glide are ignored; released before it ends.
	Input.action_press(&"move_up")
	await _wait(0.4)
	Input.action_release(&"move_up")
	await _wait(0.2)
	var post := _flat(bounds.clamp_focus(_commander.global_position))
	_check("Commander mode focuses the commander, kept in the bounds", _near(_focus(), post))
	_check("keys held through the glide did not move the camera", _near(_focus(), post))

	# Pan away, Tab back to PREP, Tab into Commander again: no remembered pan.
	await _hold(&"move_right", 0.4)
	_switch.request()
	await _wait(0.6)
	_check("Deploy in PREP goes back to the middle", _near(_focus(), centre))
	_switch.request()
	await _wait(0.6)
	_check("entering Commander again does not keep the old pan", _near(_focus(), post))
	_switch.request()
	await _wait(0.6)

	# COMBAT in Frontline: follow the commander at the Frontline size, no pan, no recenter.
	_waves.start_combat()
	await _wait(0.6)
	_check("COMBAT uses the Frontline size", is_equal_approx(_camera.size, bounds.camera_size_frontline))
	_check("Frontline focuses the commander", _near(_focus(), _flat(bounds.clamp_focus(_commander.global_position)), 0.5))
	# The headless viewport is not 16:9, so the view width is only measured in a real window.
	if DisplayServer.get_name() != "headless":
		var reach := _ground_half_width()
		print("[test] Frontline shows %.1f m left and %.1f m right of the focus along the corridor" % [reach.x, reach.y])
		_check("Frontline shows about 12-14 m each side", reach.x >= 12.0 and reach.y >= 12.0 and reach.x <= 14.0 and reach.y <= 14.0)
	var before := _focus()
	await _hold(&"move_up", 0.3)
	_check("WASD moved the commander, so the camera moved with it", _focus().distance_to(before) > 0.3)
	# The follow is smoothed over 0.15 s, so it settles shortly after the commander stops.
	await _wait(0.6)
	_check("Frontline follows the commander when it walks", _near(_focus(), _flat(bounds.clamp_focus(_commander.global_position))))
	var stand := _focus()
	_press(&"camera_recenter")
	await _wait(0.2)
	_check("C does nothing in Frontline", _near(_focus(), stand))

	# Recall in COMBAT: after the channel, Commander mode at the command post.
	_switch.request()
	_check("Recall starts a channel in COMBAT", _switch.is_recalling())
	while _switch.is_recalling():
		await _frames(1)
	await _wait(0.6)
	_check("after Recall the camera is on the command post", _near(_focus(), _flat(bounds.clamp_focus(_commander.global_position))))
	_check("after Recall the size is overview", is_equal_approx(_camera.size, bounds.camera_size_overview))

	# Deploy in COMBAT: back to Frontline on the landing point.
	await _wait(maxf(_switch.cooldown_left, 0.0) / maxf(Engine.time_scale, 0.001) + 0.1)
	_switch.request()
	await _frames(1)
	_check("Deploy leaves Commander mode", not _commander.is_commander_mode)
	_check("Deploy starts a glide", _rig.is_gliding())
	await _wait(0.6)
	_check("after Deploy the camera is on the commander", _near(_focus(), _flat(bounds.clamp_focus(_commander.global_position)), 0.5))
	_check("after Deploy the size is Frontline", is_equal_approx(_camera.size, bounds.camera_size_frontline))

	# Reduced motion turns the glides into cuts.
	EventBus.settings_changed.emit(&"reduced_motion", true)
	_waves.start_prep()
	await _frames(1)
	_check("reduced motion: PREP is an instant cut", not _rig.is_gliding() and _near(_focus(), centre))
	EventBus.settings_changed.emit(&"reduced_motion", false)


## main.tscn has no commander until the run spawns one; place it at the Fortress spawn marker.
func _spawn_commander() -> Node3D:
	var commander := (load("res://entities/commander/commander.tscn") as PackedScene).instantiate() as Node3D
	var level := _main.find_child("Level", true, false)
	(level if level != null else _main).add_child(commander)
	var marker := _main.find_child("FortressSpawn", true, false) as Node3D
	if marker != null:
		commander.global_position = marker.global_position
	return commander


## Metres along the corridor (X) from the focus, on the ground, before each side leaves the frame.
func _ground_half_width() -> Vector2:
	var focus := _flat(_rig.global_position)
	var reach := func(dir: Vector3) -> float:
		var d := 0.0
		while d < 60.0 and _camera.is_position_in_frustum(focus + dir * (d + 0.1)):
			d += 0.1
		return d
	return Vector2(reach.call(Vector3.LEFT), reach.call(Vector3.RIGHT))


## Is the point inside the overview frame when the focus sits at one end of the bounds?
func _in_frame_at_end(point: Vector3, side: int) -> bool:
	var r := _rig.bounds.get_rect()
	var focus := Vector3(r.end.x if side > 0 else r.position.x, 0.0, r.get_center().y)
	var saved_pos := _rig.global_position
	var saved_size := _camera.size
	_rig.global_position = Vector3(focus.x, _rig.global_position.y, focus.z)
	_camera.size = _rig.bounds.camera_size_overview
	var inside := false
	if not _camera.is_position_behind(point):
		var p := _camera.unproject_position(point)
		inside = get_viewport().get_visible_rect().has_point(p)
	_rig.global_position = saved_pos
	_camera.size = saved_size
	return inside


func _focus() -> Vector3:
	return _flat(_rig.global_position)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _near(a: Vector3, b: Vector3, tolerance := NEAR) -> bool:
	return a.distance_to(b) <= tolerance


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Waits real seconds, on the same clock the rig uses.
func _wait(seconds: float) -> void:
	var end := TimeManager.real_time + seconds
	while TimeManager.real_time < end:
		await get_tree().process_frame


func _hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await _wait(seconds)
	Input.action_release(action)
	await _frames(1)


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _release_moves() -> void:
	for action in CameraRig.MOVE_ACTIONS:
		Input.action_release(action)


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("[test] OK   ", label)
	else:
		_fail += 1
		print("[test] FAIL ", label)
