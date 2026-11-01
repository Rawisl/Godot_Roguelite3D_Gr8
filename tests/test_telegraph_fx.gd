extends Node3D

## Test for the Stomp telegraph and the screen shake:
## - telegraph_started puts a ring at the given point with the given radius
## - the ring fills over the wind-up on game time: faster at x2, held while paused
## - it fades after the hit and frees itself; two telegraphs live side by side
## - leaving BOSS_COMBAT clears every ring at once
## - the material draws on top (no depth test)
## - screen_shake_requested moves the camera by h_offset / v_offset, never past the cap,
##   then settles; 50% halves it, Off and Pause stop it
## Headless it runs the checks and quits. F6 in the editor runs the checks, then loops a Bulwark
## Stomp behind a wall with buttons for the shake level and the game speed.

const BULWARK := preload("res://contents/assets/characters/enemy and boss/boss_bulwark_model.tscn")
const SLAM := "melee/Melee_2H_Slam"
const IDLE := "general/Idle_A"
const WINDUP := 1.0 # game time
const CADENCE := 2.5
const CLIP_RECOVERED := 2.37 # art/models_animations.md, Boss Bulwark
const STOMP_RADIUS := 3.0
const STOMP_SHAKE := 0.6
const BLEND := 0.15

@export var quit_when_done := DisplayServer.get_name() == "headless"

var passes: int = 0
var fails: int = 0
var _fx: TelegraphFxManager
var _rig: CameraRig


func _ready() -> void:
	print("\n[telegraph fx] start")
	_make_world()
	_fx = TelegraphFxManager.new()
	add_child(_fx)

	await test_ring_placed()
	await test_ring_fills_on_game_time()
	await test_ring_fades_and_frees()
	await test_rings_cleared_after_boss()
	test_draws_on_top()
	await test_shake_capped_and_settles()
	await test_shake_settings()
	await test_shake_pause()

	TimeManager.reset()
	print("[telegraph fx] done: %d passed, %d failed" % [passes, fails])
	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)
		return
	_run_demo()


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


#region Tests
func test_ring_placed() -> void:
	EventBus.telegraph_started.emit(&"stomp", Vector3(2, 0, -1), STOMP_RADIUS, WINDUP)
	await _frames(1)
	assert_true(_fx.get_active_count() == 1, "telegraph_started adds one ring")
	var ring := _ring(0)
	assert_true(ring != null and ring.global_position.distance_to(Vector3(2, _fx.ring_lift, -1)) < 0.001,
		"the ring sits on the given point, just above the floor")
	assert_true(ring != null and is_equal_approx(ring.get_instance_shader_parameter(&"radius"), STOMP_RADIUS),
		"the ring uses the given radius")
	var plane := ring.mesh as PlaneMesh if ring != null else null
	assert_true(plane != null and plane.size.x >= 2.0 * STOMP_RADIUS, "the plane is wide enough for the radius")
	await _clear()


func test_ring_fills_on_game_time() -> void:
	EventBus.telegraph_started.emit(&"stomp", Vector3.ZERO, STOMP_RADIUS, WINDUP)
	await _frames(1)
	assert_true(_progress(0) < 0.1, "the fill starts near empty")
	await TimeManager.wait_game(0.5)
	assert_true(absf(_progress(0) - 0.5) < 0.1, "half way through the wind-up the fill is half way")
	await _clear()

	TimeManager.set_time_scale(2)
	EventBus.telegraph_started.emit(&"stomp", Vector3.ZERO, STOMP_RADIUS, WINDUP)
	await TimeManager.wait_real(0.25)
	assert_true(absf(_progress(0) - 0.5) < 0.12, "at x2 the fill is half way after 0.25 s real time")
	TimeManager.request_pause(TimeManager.REASON_USER)
	var held := _progress(0)
	await TimeManager.wait_real(0.3)
	assert_true(is_equal_approx(_progress(0), held), "while paused the fill holds")
	TimeManager.release_pause(TimeManager.REASON_USER)
	TimeManager.set_time_scale(1)
	await _clear()


func test_ring_fades_and_frees() -> void:
	EventBus.telegraph_started.emit(&"stomp", Vector3(-3, 0, 0), STOMP_RADIUS, WINDUP)
	EventBus.telegraph_started.emit(&"stomp", Vector3(3, 0, 0), 2.0, WINDUP * 2.0)
	await _frames(1)
	assert_true(_fx.get_active_count() == 2, "two telegraphs live side by side")
	await TimeManager.wait_game(WINDUP + _fx.fade_time * 0.5)
	assert_true(_fx.get_active_count() == 2 and _progress(0) == 1.0 and _fade(0) < 1.0,
		"after the hit the first ring is full and fading")
	await TimeManager.wait_game(_fx.fade_time)
	await _frames(2)
	assert_true(_fx.get_active_count() == 1, "the first ring frees itself after the fade")
	assert_true(_progress(0) < 1.0, "the longer telegraph is still filling")
	await _clear()


func test_rings_cleared_after_boss() -> void:
	EventBus.state_changed.emit(&"BOSS_COMBAT")
	EventBus.telegraph_started.emit(&"stomp", Vector3.ZERO, STOMP_RADIUS, WINDUP)
	await TimeManager.wait_game(WINDUP * 0.3)
	EventBus.state_changed.emit(&"BOSS_COMBAT")
	assert_true(_fx.get_active_count() == 1, "staying in BOSS_COMBAT keeps the ring")
	EventBus.state_changed.emit(&"SUMMARY")
	await _frames(2)
	assert_true(_fx.get_active_count() == 0 and _ring(0) == null, "leaving BOSS_COMBAT mid wind-up clears the ring")


func test_draws_on_top() -> void:
	var code := _fx.ring_material.shader.code
	assert_true(code.contains("depth_test_disabled"), "the telegraph shader ignores depth, so nothing hides it")
	assert_true(_fx.ring_material.render_priority > 0, "the telegraph draws after other transparent things")


func test_shake_capped_and_settles() -> void:
	_rig.shake_scale = 1.0
	EventBus.screen_shake_requested.emit(STOMP_SHAKE, &"stomp")
	EventBus.screen_shake_requested.emit(STOMP_SHAKE, &"stomp")
	var peak := await _peak_offset(0.3)
	assert_true(peak > 0.05, "a shake request moves the camera")
	assert_true(peak <= _rig.shake_max_offset * 1.001, "two hits together stay under the cap")
	await TimeManager.wait_real(1.0 / _rig.shake_decay + 0.1)
	assert_true(_rig.get_shake_offset() == Vector2.ZERO, "the shake settles back to zero")
	assert_true(_rig.position.is_equal_approx(_rig_home()), "the shake never moves the focus")


func test_shake_settings() -> void:
	EventBus.settings_changed.emit(&"screen_shake", 0.5)
	EventBus.screen_shake_requested.emit(1.0, &"stomp")
	var half := await _peak_offset(0.3)
	assert_true(half > 0.0 and half <= _rig.shake_max_offset * 0.5 * 1.001, "50% keeps the shake under half the cap")
	await TimeManager.wait_real(1.0 / _rig.shake_decay + 0.1)

	EventBus.settings_changed.emit(&"screen_shake", 0.0)
	EventBus.screen_shake_requested.emit(1.0, &"stomp")
	var off := await _peak_offset(0.2)
	assert_true(off == 0.0, "Off: a request does not move the camera")
	EventBus.settings_changed.emit(&"screen_shake", 1.0)


func test_shake_pause() -> void:
	EventBus.screen_shake_requested.emit(1.0, &"stomp")
	await _frames(3)
	TimeManager.request_pause(TimeManager.REASON_USER)
	await _frames(2)
	assert_true(_rig.get_shake_offset() == Vector2.ZERO, "Pause drops the shake at once")
	TimeManager.release_pause(TimeManager.REASON_USER)
#endregion


#region Helpers
func _make_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.7, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.5
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	ground.material_override = preload("res://art/materials/env_grass.tres")
	add_child(ground)

	# Same camera as level.tscn: the rig holds the focus, the camera sits on the iso offset.
	_rig = CameraRig.new()
	_rig.name = "CameraRig"
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 14.0
	cam.position = Vector3(20, 20, 20)
	_rig.add_child(cam)
	add_child(_rig)
	cam.look_at(_rig.global_position)
	cam.current = true


func _rig_home() -> Vector3:
	return Vector3.ZERO


func _ring(index: int) -> MeshInstance3D:
	var rings := _fx.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	return rings[index] as MeshInstance3D if index < rings.size() else null


func _progress(index: int) -> float:
	var ring := _ring(index)
	return ring.get_instance_shader_parameter(&"progress") if ring != null else -1.0


func _fade(index: int) -> float:
	var ring := _ring(index)
	return ring.get_instance_shader_parameter(&"fade") if ring != null else -1.0


func _clear() -> void:
	await TimeManager.wait_game(WINDUP * 2.0 + _fx.fade_time)
	await _frames(2)


func _peak_offset(seconds: float) -> float:
	var peak := 0.0
	var end := TimeManager.real_time + seconds
	while TimeManager.real_time < end:
		await get_tree().process_frame
		peak = maxf(peak, _rig.get_shake_offset().length())
	return peak


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
#endregion


#region Demo
## A Bulwark stomps every 2.5 s behind a wall: the ring must show through the wall, the fill and
## the arc reach the edge as the mace lands, and the camera shakes at that moment.
func _run_demo() -> void:
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(7.0, 1.6, 0.6)
	wall.mesh = box
	wall.material_override = preload("res://art/materials/struct_stone.tres")
	wall.position = Vector3(-1.5, 0.8, 2.6)
	add_child(wall)

	var boss := BULWARK.instantiate() as Node3D
	boss.rotation.y = atan2(1.0, 1.0) # face the camera, KayKit looks down +Z
	add_child(boss)
	var ap := boss.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_build_demo_ui()

	var clock := 0.0
	var impacted := false
	var idle := false
	ap.play(SLAM)
	EventBus.telegraph_started.emit(&"stomp", boss.global_position, STOMP_RADIUS, WINDUP)
	while is_inside_tree():
		await get_tree().process_frame
		clock += get_process_delta_time()
		if clock >= CADENCE:
			clock -= CADENCE
			impacted = false
			idle = false
			ap.play(SLAM, BLEND)
			EventBus.telegraph_started.emit(&"stomp", boss.global_position, STOMP_RADIUS, WINDUP)
		elif clock >= WINDUP and not impacted:
			impacted = true
			EventBus.screen_shake_requested.emit(STOMP_SHAKE, &"stomp")
		if impacted and not idle and ap.current_animation_position >= CLIP_RECOVERED:
			idle = true
			ap.play(IDLE, BLEND)


func _build_demo_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bar := HBoxContainer.new()
	bar.position = Vector2(16, 16)
	layer.add_child(bar)
	var shake_levels := {"Rung 100%": 1.0, "Rung 50%": 0.5, "Tắt rung": 0.0}
	for label in shake_levels:
		_button(bar, label, func() -> void:
			EventBus.settings_changed.emit(&"screen_shake", shake_levels[label]))
	for level in [1, 2, 3]:
		_button(bar, "x%d" % level, func() -> void: TimeManager.set_time_scale(level))
	_button(bar, "Dừng / chạy", func() -> void:
		if TimeManager.has_pause_reason(TimeManager.REASON_USER):
			TimeManager.release_pause(TimeManager.REASON_USER)
		else:
			TimeManager.request_pause(TimeManager.REASON_USER))


func _button(parent: Control, text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(on_pressed)
	parent.add_child(button)
#endregion
