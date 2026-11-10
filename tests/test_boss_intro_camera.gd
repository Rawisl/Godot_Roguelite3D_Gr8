extends Node3D
## Test for the camera during BOSS_INTRO: it pans to the boss spawn point over the intro on game
## time, ignores the move keys and mode changes, holds while paused, cuts with reduced motion,
## and glides to the next state's frame when the intro ends or is skipped. Not shipped.
## Run with F6, prints OK/FAIL per case then quits.

const NEAR := 0.05

var _pass := 0
var _fail := 0
var _rig: CameraRig
var _camera: Camera3D
var _commander: Node3D
var _marker: Marker3D


func _ready() -> void:
	_commander = Node3D.new()
	_commander.add_to_group(&"commander")
	add_child(_commander)
	_marker = Marker3D.new()
	_marker.add_to_group(&"boss_spawn_point")
	add_child(_marker)
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
	_marker.global_position = Vector3(12, 0, 1)


## Advances the clocks the way TimeManager does: real time always, game time scaled and
## stopped while paused.
func _step(seconds: float, game_scale := 1.0, tick := 0.016) -> void:
	var left := seconds
	while left > 0.0:
		var dt := minf(tick, left)
		TimeManager.real_time += dt
		TimeManager.game_time += dt * game_scale
		_rig._process(dt)
		_rig._follow(dt)
		left -= tick


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _at(p: Vector3) -> bool:
	return _flat(_rig.position).distance_to(_flat(p)) < NEAR


func _enter_intro() -> void:
	EventBus.state_changed.emit(&"PREP")
	_step(0.6)
	EventBus.state_changed.emit(&"BOSS_INTRO")


func _run() -> void:
	var intro := GameConfig.boss_intro_duration
	var boss := Vector3(12, 0, 1)

	# The pan: eases out to the boss over the whole intro, on game time.
	_new_rig()
	_enter_intro()
	_check("BOSS_INTRO starts the intro pan", _rig.is_in_boss_intro())
	_check("the boss focus is the boss_spawn_point marker", _flat(_rig.get_boss_focus()).distance_to(boss) < NEAR)
	_step(0.2)
	var early := _flat(_rig.position).distance_to(boss)
	_check("the pan glides, it does not cut", early > 1.0 and early < 12.0)
	_step(intro * 0.5 - 0.2)
	_check("halfway through the intro the boss is nearly framed (ease-out)", _flat(_rig.position).distance_to(boss) < 12.0 * 0.2)
	_step(intro * 0.5 + 0.1)
	_check("by the end of the intro the camera is on the boss", _at(boss))
	_check("the intro uses the close Frontline size", is_equal_approx(_camera.size, _rig.bounds.camera_size_frontline))
	_step(1.0)
	_check("it holds on the boss until the intro ends", _at(boss) and _rig.is_in_boss_intro())

	# Locked input: no panning, no recenter, mode changes do not move it.
	_new_rig()
	_enter_intro()
	_check("panning is off during the intro", not _rig.is_panning_enabled())
	Input.action_press(&"move_left")
	EventBus.mode_changed.emit(&"COMMANDER")
	_step(intro + 0.1)
	Input.action_release(&"move_left")
	_check("move keys and a mode change do not pull it off the boss", _at(boss))
	EventBus.mode_changed.emit(&"FRONTLINE")

	# Game time: pause holds it, x3 finishes sooner.
	_new_rig()
	_enter_intro()
	_step(0.5)
	var before_pause := _rig.position
	_step(2.0, 0.0)
	_check("the pan holds still while paused", _rig.position.distance_to(before_pause) < 0.001)
	_step(intro - 0.5 + 0.1)
	_check("after the pause it still reaches the boss", _at(boss))
	_new_rig()
	_enter_intro()
	_step(intro / 3.0 + 0.05, 3.0)
	_check("at x3 game speed it reaches the boss in a third of the real time", _at(boss))

	# Reduced motion: a cut.
	_new_rig()
	EventBus.settings_changed.emit(&"reduced_motion", true)
	_enter_intro()
	_step(0.016)
	_check("reduced motion cuts straight to the boss", _at(boss))
	EventBus.settings_changed.emit(&"reduced_motion", false)

	# Leaving the intro: glide in 0.5 s real time to the next frame.
	_new_rig()
	_enter_intro()
	_step(intro + 0.1)
	EventBus.state_changed.emit(&"BOSS_COMBAT")
	_check("BOSS_COMBAT ends the intro", not _rig.is_in_boss_intro())
	_step(0.1)
	_check("it glides back, it does not cut", _rig.is_gliding() and not _at(_commander.global_position))
	_step(0.5)
	_check("Frontline: back on the commander after 0.5 s", _at(_commander.global_position))

	# Skipped early, in Commander mode: back to the commander, overview size.
	_new_rig()
	EventBus.state_changed.emit(&"PREP")
	_step(0.6)
	EventBus.mode_changed.emit(&"COMMANDER")
	_step(0.6)
	EventBus.state_changed.emit(&"BOSS_INTRO")
	_step(1.5)
	EventBus.state_changed.emit(&"BOSS_COMBAT")
	_step(0.6)
	_check("a skipped intro returns to the commander", _at(_commander.global_position) and not _rig.is_in_boss_intro())
	_check("Commander mode gets the overview size back", is_equal_approx(_camera.size, _rig.bounds.camera_size_overview))
	EventBus.mode_changed.emit(&"FRONTLINE")

	# Fallbacks and bounds.
	_new_rig()
	_marker.global_position = Vector3(40, 0, 6)
	_check("a boss point outside the bounds is clamped", _flat(_rig.get_boss_focus()).is_equal_approx(Vector3(16, 0, 2)))
	_marker.remove_from_group(&"boss_spawn_point")
	var zone := Area3D.new()
	zone.add_to_group(&"spawn_zone")
	add_child(zone)
	zone.global_position = Vector3(10, 2, 0)
	_check("without the marker it frames the spawn zone", _flat(_rig.get_boss_focus()).is_equal_approx(Vector3(10, 0, 0)))
	zone.free()
	_marker.add_to_group(&"boss_spawn_point")


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("[test] OK   %s" % label)
	else:
		_fail += 1
		print("[test] FAIL %s" % label)
