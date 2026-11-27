extends Node3D

## Test for the active skill visuals (SkillFxManager):
## - Whirlwind: the blades sit on the cast point at the skill radius and spin on game time (faster
##   at x2, held while paused), then free themselves with their sparks; the sparks fly in towards
##   the commander, and reduced flashing turns the flicker off
## - Sword Wave: flies along the commander's aim for its distance, stops early at a wall; its
##   plane leaves room for the glow, sparks follow the wave and stop with it, the band runs on
##   game time (held while paused), and reduced flashing turns the pulse off, capped at 3 per second
## - Firebomb: the bomb flies first, then the burn area shows at the cast point for the burn
##   time; reduced flashing turns the flicker off, and the flicker is capped at 3 per second
## - every skill shader keeps the depth test, so walls hide the effects
## - over the particle budget the effects still play without sparks or embers
## - run_started clears everything
## Headless it runs the checks and quits. F6 in the editor runs the checks, then casts the three
## skills together every 2 s, each in its own spot around a wall, with buttons for the game
## speed and reduced flashing.

const WHIRLWIND_RADIUS := 3.0
const FIRE_RADIUS := 2.5
const BURN_TIME := 1.0
const WALL_X := 2.5

@export var quit_when_done := DisplayServer.get_name() == "headless"

var passes: int = 0
var fails: int = 0
var _fx: SkillFxManager
var _commander: Node3D


func _ready() -> void:
	print("\n[skill fx] start")
	_make_world()
	_fx = SkillFxManager.new()
	add_child(_fx)
	await _frames(2)

	await test_whirlwind_placed()
	await test_whirlwind_on_game_time()
	await test_whirlwind_fades_and_frees()
	await test_whirlwind_sparks()
	await test_whirlwind_flicker()
	await test_sword_wave_flies_along_aim()
	await test_sword_wave_stops_at_wall()
	await test_sword_wave_plane_fits_halo()
	await test_sword_wave_sparks()
	await test_sword_wave_on_game_time()
	await test_sword_wave_flicker()
	await test_firebomb_lands_and_burns()
	await test_firebomb_flicker()
	test_depth_test_kept()
	test_whirlwind_shader_rules()
	await test_particle_budget()
	await test_run_started_clears()

	TimeManager.reset()
	print("[skill fx] done: %d passed, %d failed" % [passes, fails])
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
func test_whirlwind_placed() -> void:
	_cast(&"whirlwind", Vector3(1, 0, -2), WHIRLWIND_RADIUS)
	await _frames(1)
	var mesh := _fx.get_effect_mesh(&"whirlwind")
	assert_true(_fx.get_active_count(&"whirlwind") == 1, "skill_cast whirlwind adds one ring of blades")
	assert_true(mesh != null and mesh.global_position.distance_to(Vector3(1, _fx.ground_lift, -2)) < 0.001,
		"the blades sit on the cast point, just above the floor")
	assert_true(mesh != null and is_equal_approx(mesh.get_instance_shader_parameter(&"radius"), WHIRLWIND_RADIUS),
		"the blades use the skill radius")
	var plane := mesh.mesh as PlaneMesh if mesh != null else null
	assert_true(plane != null and plane.size.x >= 2.0 * WHIRLWIND_RADIUS, "the plane is wide enough for the radius")
	var wisp: float = _fx.whirlwind_material.get_shader_parameter(&"wisp_offset")
	assert_true(plane != null and plane.size.x >= 2.0 * WHIRLWIND_RADIUS * wisp, "the plane fits the outer wisps")
	await _clear()


func test_whirlwind_on_game_time() -> void:
	_cast(&"whirlwind", Vector3.ZERO, WHIRLWIND_RADIUS)
	await TimeManager.wait_game(0.2)
	assert_true(absf(_age_ms() - 200.0) < 60.0, "after 0.2 s of game time the blades are 200 ms old")
	await _clear()

	TimeManager.set_time_scale(2)
	_cast(&"whirlwind", Vector3.ZERO, WHIRLWIND_RADIUS)
	await TimeManager.wait_real(0.1)
	assert_true(absf(_age_ms() - 200.0) < 80.0, "at x2 the blades are 200 ms old after 0.1 s")
	TimeManager.request_pause(TimeManager.REASON_USER)
	var held := _age_ms()
	await TimeManager.wait_real(0.2)
	assert_true(is_equal_approx(_age_ms(), held), "while paused the blades hold")
	TimeManager.release_pause(TimeManager.REASON_USER)
	TimeManager.set_time_scale(1)
	await _clear()


func test_whirlwind_fades_and_frees() -> void:
	_cast(&"whirlwind", Vector3.ZERO, WHIRLWIND_RADIUS)
	var unravel: float = _fx.whirlwind_material.get_shader_parameter(&"unravel_ms")
	await TimeManager.wait_game(_fx.whirlwind_time() - 0.05)
	assert_true(_fx.get_active_count(&"whirlwind") == 1 and _age_ms() > unravel,
		"just before the end time the blades are still there and unravelling")
	await TimeManager.wait_game(0.3)
	assert_true(_fx.get_active_count() == 0, "the blades and their sparks free themselves")
	await _clear()


func test_whirlwind_sparks() -> void:
	_cast(&"whirlwind", Vector3.ZERO, WHIRLWIND_RADIUS)
	await _frames(1)
	var sparks := _fx.get_effect_particles(&"whirlwind")
	assert_true(sparks != null, "the whirlwind throws sparks")
	if sparks == null:
		await _clear()
		return
	assert_true(sparks.amount == _fx.whirlwind_spark_count, "one spark per start point")
	assert_true(sparks.emission_shape == CPUParticles3D.EMISSION_SHAPE_DIRECTED_POINTS, "the sparks leave from points with a direction")
	var inward := sparks.emission_normals.size() == sparks.emission_points.size() and not sparks.emission_points.is_empty()
	for i in sparks.emission_points.size():
		inward = inward and sparks.emission_normals[i].dot(sparks.emission_points[i]) < 0.0
	assert_true(inward, "every spark flies in towards the commander")
	# Counter-clockwise seen from above: the tangent at (x, z) is (z, 0, -x), as for the blades.
	var with_spin := not sparks.emission_points.is_empty()
	for i in sparks.emission_points.size():
		var point := sparks.emission_points[i]
		with_spin = with_spin and sparks.emission_normals[i].dot(Vector3(point.z, 0.0, -point.x)) > 0.0
	assert_true(with_spin, "every spark swirls the same way the blades spin")
	assert_true(sparks.lifetime <= 0.18 and sparks.gravity == Vector3.ZERO and sparks.particle_flag_align_y,
		"the sparks are short, fly straight and stretch along the flight")
	assert_true(_fx.active_particles() > 0, "the sparks count against the particle budget while they fly")
	await _clear()


func test_whirlwind_flicker() -> void:
	EventBus.settings_changed.emit(&"reduce_flash", true)
	_cast(&"whirlwind", Vector3.ZERO, WHIRLWIND_RADIUS)
	await _frames(2)
	var mesh := _fx.get_effect_mesh(&"whirlwind")
	assert_true(mesh != null and mesh.get_instance_shader_parameter(&"flicker") == 0.0,
		"reduced flashing turns the centre burst and the extra brightness off")
	EventBus.settings_changed.emit(&"reduce_flash", false)
	await _frames(2)
	assert_true(mesh != null and mesh.get_instance_shader_parameter(&"flicker") == 1.0,
		"turning it back off brings the flicker back")
	await _clear()


func test_sword_wave_flies_along_aim() -> void:
	_aim(Vector3.LEFT)
	_cast(&"sword_wave", _commander.global_position, 0.0)
	await _frames(1)
	var mesh := _fx.get_effect_mesh(&"sword_wave")
	assert_true(mesh != null, "skill_cast sword_wave adds one wave")
	if mesh == null:
		return
	var forward := -mesh.global_basis.z
	assert_true(forward.dot(Vector3.LEFT) > 0.99, "the wave faces the commander's aim")
	var flight := (_fx.fallback_wave_distance - _fx.wave_start_offset) / _fx.fallback_wave_speed
	await TimeManager.wait_game(flight + _fx.fade_time * 0.5)
	var travelled := _flat_distance(mesh.global_position, _commander.global_position)
	assert_true(absf(travelled - _fx.fallback_wave_distance) < 0.05, "the wave stops at its distance")
	await _clear()
	assert_true(_fx.get_active_count() == 0, "the wave frees itself after the fade")


func test_sword_wave_stops_at_wall() -> void:
	_aim(Vector3.RIGHT)
	_cast(&"sword_wave", _commander.global_position, 0.0)
	# Past the full flight time, before the fade ends.
	var flight := (_fx.fallback_wave_distance - _fx.wave_start_offset) / _fx.fallback_wave_speed
	await TimeManager.wait_game(flight + _fx.fade_time * 0.5)
	var mesh := _fx.get_effect_mesh(&"sword_wave")
	var travelled := _flat_distance(mesh.global_position, _commander.global_position) if mesh != null else INF
	assert_true(travelled <= WALL_X + 0.01 and travelled > WALL_X - 0.5, "the wave stops at the wall instead of passing through it")
	await _clear()


func test_sword_wave_plane_fits_halo() -> void:
	_aim(Vector3.LEFT)
	_cast(&"sword_wave", _commander.global_position, 0.0)
	await _frames(1)
	var mesh := _fx.get_effect_mesh(&"sword_wave")
	var plane := mesh.mesh as PlaneMesh if mesh != null else null
	var halo: float = _fx.wave_material.get_shader_parameter(&"halo_width")
	assert_true(plane != null and plane.size.x >= _fx.fallback_wave_width + 2.0 * halo,
		"the wave plane leaves room for the glow")
	await _clear()


func test_sword_wave_sparks() -> void:
	_aim(Vector3.LEFT)
	_cast(&"sword_wave", _commander.global_position, 0.0)
	await _frames(1)
	var mesh := _fx.get_effect_mesh(&"sword_wave")
	var sparks := _fx.get_effect_particles(&"sword_wave")
	assert_true(sparks != null and sparks.emitting and sparks.gravity == Vector3.ZERO and _fx.active_particles() > 0,
		"the wave throws sparks back")
	if sparks == null or mesh == null:
		await _clear()
		return
	var start := mesh.global_position
	var flight := (_fx.fallback_wave_distance - _fx.wave_start_offset) / _fx.fallback_wave_speed
	await TimeManager.wait_game(flight * 0.5)
	assert_true(sparks.global_position.distance_to(mesh.global_position) < 0.01, "the sparks follow the wave")
	assert_true(sparks.global_position.distance_to(start) > 0.1, "the sparks have left the start point")
	await TimeManager.wait_game(flight * 0.5 + _fx.fade_time * 0.5)
	assert_true(not sparks.emitting and _fx.active_particles() == 0, "the sparks stop when the wave stops")
	await _clear()
	assert_true(_fx.get_active_count() == 0, "the wave and its sparks free themselves")


func test_sword_wave_on_game_time() -> void:
	_aim(Vector3.LEFT)
	_cast(&"sword_wave", _commander.global_position, 0.0)
	await _frames(1)
	var mesh := _fx.get_effect_mesh(&"sword_wave")
	if mesh == null:
		assert_true(false, "the wave exists")
		return
	var t0: float = mesh.get_instance_shader_parameter(&"game_time")
	await TimeManager.wait_game(0.05)
	var t1: float = mesh.get_instance_shader_parameter(&"game_time")
	assert_true(t1 > t0, "the band moves on game time")
	TimeManager.request_pause(TimeManager.REASON_USER)
	await TimeManager.wait_real(0.1)
	assert_true(is_equal_approx(mesh.get_instance_shader_parameter(&"game_time"), t1), "while paused the band holds")
	TimeManager.release_pause(TimeManager.REASON_USER)
	await _clear()


func test_sword_wave_flicker() -> void:
	EventBus.settings_changed.emit(&"reduce_flash", true)
	_aim(Vector3.LEFT)
	_cast(&"sword_wave", _commander.global_position, 0.0)
	await _frames(2)
	var mesh := _fx.get_effect_mesh(&"sword_wave")
	assert_true(mesh != null and mesh.get_instance_shader_parameter(&"flicker") == 0.0,
		"reduced flashing turns the band pulse off")
	EventBus.settings_changed.emit(&"reduce_flash", false)
	await _frames(2)
	assert_true(mesh != null and mesh.get_instance_shader_parameter(&"flicker") == 1.0,
		"turning it back off brings the pulse back")
	assert_true(_fx.wave_material.shader.code.contains("min(pulse_hz, 3.0)"), "the pulse never goes over 3 per second")
	assert_true(float(_fx.wave_material.get_shader_parameter(&"pulse_hz")) <= 3.0, "the tuned pulse is under 3 per second")
	await _clear()


func test_firebomb_lands_and_burns() -> void:
	var target := Vector3(-2, 0, 3)
	_cast(&"firebomb", target, FIRE_RADIUS)
	await _frames(1)
	var zone := _fx.get_effect_mesh(&"firebomb")
	assert_true(zone != null and not zone.visible, "while the bomb flies the burn area is hidden")
	await TimeManager.wait_game(_fx.throw_time + 0.2)
	assert_true(zone != null and zone.visible, "the burn area shows once the bomb lands")
	assert_true(zone != null and zone.global_position.distance_to(target + Vector3.UP * _fx.ground_lift) < 0.001,
		"the burn area sits on the cast point")
	assert_true(zone != null and is_equal_approx(zone.get_instance_shader_parameter(&"radius"), FIRE_RADIUS),
		"the burn area uses the skill radius")
	var t0: float = zone.get_instance_shader_parameter(&"game_time")
	await TimeManager.wait_game(0.3)
	assert_true(zone.get_instance_shader_parameter(&"game_time") > t0, "the flames move on game time")
	assert_true(_fx.get_active_count(&"firebomb") == 1, "the burn area is still there during the burn time")
	await TimeManager.wait_game(_fx.fallback_burn_time + _fx.fade_time + 1.0)
	await _frames(2)
	assert_true(_fx.get_active_count(&"firebomb") == 0, "the burn area frees itself after the burn time")


func test_firebomb_flicker() -> void:
	EventBus.settings_changed.emit(&"reduce_flash", true)
	_cast(&"firebomb", Vector3.ZERO, FIRE_RADIUS)
	await TimeManager.wait_game(_fx.throw_time + 0.1)
	var zone := _fx.get_effect_mesh(&"firebomb")
	assert_true(zone != null and zone.get_instance_shader_parameter(&"flicker") == 0.0,
		"reduced flashing turns the flame flicker off")
	EventBus.settings_changed.emit(&"reduce_flash", false)
	await _frames(2)
	assert_true(zone != null and zone.get_instance_shader_parameter(&"flicker") == 1.0,
		"turning it back off brings the flicker back")
	var code := _fx.fire_material.shader.code
	assert_true(code.contains("min(flicker_hz, 3.0)"), "the flicker never goes over 3 per second")
	assert_true(float(_fx.fire_material.get_shader_parameter(&"flicker_hz")) <= 3.0, "the tuned flicker is under 3 per second")
	_fx.clear()
	await _frames(1)


func test_depth_test_kept() -> void:
	for mat in [_fx.whirlwind_material, _fx.wave_material, _fx.fire_material]:
		var shader := (mat as ShaderMaterial).shader
		assert_true(not shader.code.contains("depth_test_disabled"),
			"%s keeps the depth test, so walls hide it" % shader.resource_path.get_file())


func test_whirlwind_shader_rules() -> void:
	var code := _fx.whirlwind_material.shader.code
	assert_true(code.contains("blend_premul_alpha"), "the whirlwind blends with premultiplied alpha")
	assert_true(not code.contains("TIME"), "the whirlwind runs on the age it is given, not on engine time")


func test_particle_budget() -> void:
	var budget := _fx.particle_budget
	_fx.particle_budget = 0
	_cast(&"whirlwind", Vector3.ZERO, WHIRLWIND_RADIUS)
	_cast(&"firebomb", Vector3(3, 0, 0), FIRE_RADIUS)
	_cast(&"sword_wave", Vector3(0, 0, 5), 0.0)
	# Before the wave has flown and faded out (0.175 s flight plus the fade).
	await TimeManager.wait_game(0.15)
	assert_true(_fx.get_active_count() == 3, "over the budget all effects still play")
	assert_true(_fx.active_particles() == 0, "over the budget there are no embers and no sparks")
	assert_true(_fx.get_effect_particles(&"whirlwind") == null, "over the budget the whirlwind has no sparks")
	assert_true(_fx.get_effect_particles(&"sword_wave") == null, "over the budget the wave has no sparks")
	_fx.clear()
	_fx.particle_budget = budget
	_cast(&"whirlwind", Vector3.ZERO, WHIRLWIND_RADIUS)
	await _frames(1)
	assert_true(_fx.active_particles() > 0, "under the budget the whirlwind throws sparks")
	_fx.clear()
	await _frames(1)


func test_run_started_clears() -> void:
	_cast(&"whirlwind", Vector3.ZERO, WHIRLWIND_RADIUS)
	_cast(&"firebomb", Vector3.ZERO, FIRE_RADIUS)
	_cast(&"sword_wave", Vector3.ZERO, 0.0)
	await _frames(1)
	EventBus.run_started.emit()
	await _frames(2)
	assert_true(_fx.get_active_count() == 0, "run_started clears every effect")
	var left := _fx.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	assert_true(left.is_empty(), "no mesh or particle node is left behind")
#endregion


#region Helpers
func _cast(skill_id: StringName, origin: Vector3, radius: float) -> void:
	EventBus.skill_cast.emit(skill_id, 0, 1, origin, radius)


## Turns the stand-in commander so its forward (-Z) is dir; the manager falls back to it
## when the commander has no aim_dir.
func _aim(dir: Vector3) -> void:
	_commander.global_basis = Basis.looking_at(dir, Vector3.UP)


func _age_ms() -> float:
	var mesh := _fx.get_effect_mesh(&"whirlwind")
	return mesh.get_instance_shader_parameter(&"age_ms") if mesh != null else -1.0


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _clear() -> void:
	await TimeManager.wait_game(1.2)
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


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
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	ground.material_override = preload("res://art/materials/env_grass.tres")
	add_child(ground)

	# A wall on the world layer, across the +X side of the commander.
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 2.0, 6.0)
	shape.shape = box
	wall.add_child(shape)
	var wall_mesh := MeshInstance3D.new()
	var wall_box := BoxMesh.new()
	wall_box.size = box.size
	wall_mesh.mesh = wall_box
	wall_mesh.material_override = preload("res://art/materials/struct_stone.tres")
	wall.add_child(wall_mesh)
	wall.position = Vector3(WALL_X + 0.3, 1.0, 0.0)
	add_child(wall)

	_commander = Node3D.new()
	_commander.name = "Commander"
	_commander.add_to_group(&"commander")
	add_child(_commander)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 14.0
	cam.position = Vector3(20, 20, 20)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	cam.current = true
#endregion


func _run_demo() -> void:
	_build_demo_ui()
	# All three at once, each in its own spot: the whirlwind on the left, the wave flying right
	# past the end of the wall, the bomb thrown from the commander to the open ground in front.
	_aim(Vector3.RIGHT)
	while is_inside_tree():
		_cast(&"whirlwind", Vector3(-5, 0, 1), WHIRLWIND_RADIUS)
		_cast(&"sword_wave", Vector3(-1, 0, -4.5), 0.0)
		_cast(&"firebomb", Vector3(0, 0, 6), FIRE_RADIUS)
		await TimeManager.wait_game(2.0)


func _build_demo_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bar := HBoxContainer.new()
	bar.position = Vector2(16, 16)
	layer.add_child(bar)
	for level in [1, 2, 3]:
		_button(bar, "x%d" % level, func() -> void: TimeManager.set_time_scale(level))
	_button(bar, "Dừng / chạy", func() -> void:
		if TimeManager.has_pause_reason(TimeManager.REASON_USER):
			TimeManager.release_pause(TimeManager.REASON_USER)
		else:
			TimeManager.request_pause(TimeManager.REASON_USER))
	_button(bar, "Giảm nhấp nháy", func() -> void:
		var on: bool = GameState.get_setting(&"reduce_flash", false) != true
		EventBus.settings_changed.emit(&"reduce_flash", on))


func _button(parent: Control, text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(on_pressed)
	parent.add_child(button)
