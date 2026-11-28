extends Node3D

## Test for the active skill visuals (SkillFxManager):
## - Whirlwind: the blades sit on the cast point at the skill radius and spin on game time (faster
##   at x2, held while paused), then free themselves with their sparks; the sparks fly in towards
##   the commander, and reduced flashing turns the flicker off
## - Sword Wave: flies along the commander's aim for its distance, stops early at a wall; its
##   plane leaves room for the glow, sparks follow the wave and stop with it, the wisps run on
##   game time (held while paused), reduced flashing stops the wisp gaps drifting, and the
##   colours are the ones Whirlwind uses
## - Firebomb: the bomb flies first, then the burn area shows at the cast point for the burn
##   time; reduced flashing turns the flicker off, and the flicker is capped at 3 per second
## - every skill shader keeps the depth test, so walls hide the effects
## - over the particle budget the effects still play without sparks or embers
## - run_started clears everything
## - Whirlwind and Sword Wave stay flat under a high or top-down camera and tilt towards a low one,
##   never past their own max tilt, and stay flat when min_view_angle is 0; the wave reaches
##   min_view_angle and stays clear of the floor, Whirlwind turns about its centre at the middle of
##   the commander and its edge never reaches the floor
## - the colours follow the equipped sword: six palettes, base sword by default and for unknown swords, never
##   changed under an effect already flying
## - Blade Tempest: the age maps to growing, a looping full-size spin and the unravel; the ring
##   lasts the whole channel, follows the commander, ends in a moment when the channel is cut, and
##   run_started clears it; its waves start at the ring edge and stop at a wall; Sword Wave itself
##   still starts at wave_start_offset
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
	await test_whirlwind_rings()
	await test_whirlwind_rings_on_game_time()
	await test_whirlwind_rings_free()
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
	test_sword_wave_shader_rules()
	await test_particle_budget()
	await test_run_started_clears()
	test_palettes_complete()
	await test_default_palette_is_base()
	await test_burn_palette_on_both_skills()
	await test_sword_change_keeps_flying_effect()
	await test_unknown_sword_uses_base()
	await test_sword_change_after_readd()
	await test_tilt_toward_low_camera()
	test_tempest_age_mapping()
	await test_tempest_lives_whole_channel()
	await test_tempest_follows_commander()
	await test_tempest_cut_ends_ring()
	await test_tempest_end_signal_at_normal_end()
	await test_edge_wave_start()
	await test_edge_wave_stops_at_wall()
	await test_sword_wave_unchanged()
	await test_sword_wave_wall_inside_offset_unchanged()
	await test_tempest_cleared_on_run_started()

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
	assert_true(mesh != null and mesh.global_position.distance_to(Vector3(1, _fx.whirlwind_height, -2)) < 0.001,
		"the blades sit over the cast point, at the middle of the commander")
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


func test_whirlwind_rings() -> void:
	_cast(&"whirlwind", Vector3.ZERO, WHIRLWIND_RADIUS)
	await _frames(1)
	var rings := _fx.get_whirlwind_rings()
	var wanted := _fx.whirlwind_ring_count()
	assert_true(wanted >= 1 and rings.size() == wanted, "the whirlwind has one extra mesh per extra ring")
	assert_true(_whirlwind_mesh_count() == 1 + wanted, "the whirlwind is the main mesh plus the extra rings")
	var main := _fx.get_effect_mesh(&"whirlwind")
	# Values never set read back as null: the shader defaults (1 and 0) apply.
	assert_true(main != null and main.get_instance_shader_parameter(&"ring_scale") in [null, 1.0]
		and main.get_instance_shader_parameter(&"ring_delay_ms") in [null, 0.0], "the main ring keeps the default ring values")
	var wisp: float = _fx.whirlwind_material.get_shader_parameter(&"wisp_offset")
	var ok := rings.size() == wanted
	var plane_ok := ok
	for i in rings.size():
		var ring_scale: float = rings[i].get_instance_shader_parameter(&"ring_scale")
		ok = ok and is_equal_approx(ring_scale, _fx.whirlwind_ring_scales[i]) \
			and is_equal_approx(rings[i].get_instance_shader_parameter(&"ring_delay_ms"), _fx.whirlwind_ring_delays_ms[i]) \
			and is_equal_approx(rings[i].get_instance_shader_parameter(&"ring_weight"), _fx.whirlwind_ring_weights[i]) \
			and is_equal_approx(rings[i].get_instance_shader_parameter(&"radius"), WHIRLWIND_RADIUS)
		var plane := rings[i].mesh as PlaneMesh
		plane_ok = plane_ok and plane != null and plane.size.x >= 2.0 * WHIRLWIND_RADIUS * ring_scale * wisp
	assert_true(ok, "each extra ring carries its own radius factor, delay and strength")
	assert_true(plane_ok, "each ring plane fits the outer wisps of its own radius")
	await _clear()


func test_whirlwind_rings_on_game_time() -> void:
	_cast(&"whirlwind", Vector3.ZERO, WHIRLWIND_RADIUS)
	await TimeManager.wait_game(0.2)
	var rings := _fx.get_whirlwind_rings()
	var ok := not rings.is_empty()
	for ring in rings:
		ok = ok and absf(ring.get_instance_shader_parameter(&"age_ms") - 200.0) < 60.0
	assert_true(ok, "after 0.2 s of game time the extra rings are 200 ms old")
	TimeManager.request_pause(TimeManager.REASON_USER)
	var held := _age_ms()
	await TimeManager.wait_real(0.2)
	assert_true(not rings.is_empty() and is_equal_approx(rings[0].get_instance_shader_parameter(&"age_ms"), held),
		"while paused the extra rings hold too")
	TimeManager.release_pause(TimeManager.REASON_USER)
	await _clear()


func test_whirlwind_rings_free() -> void:
	_cast(&"whirlwind", Vector3.ZERO, WHIRLWIND_RADIUS)
	await _frames(1)
	var rings := _fx.get_whirlwind_rings().duplicate()
	var end_s: float = float(_fx.whirlwind_material.get_shader_parameter(&"end_ms")) * 0.001
	var max_delay_s := 0.0
	for delay in _fx.whirlwind_ring_delays_ms:
		max_delay_s = maxf(max_delay_s, delay * 0.001)
	assert_true(is_equal_approx(_fx.whirlwind_time(), end_s + max_delay_s),
		"the effect lives until the latest ring has faded")
	await TimeManager.wait_game(_fx.whirlwind_time() + 0.3)
	await _frames(2)
	var freed := not rings.is_empty()
	for ring in rings:
		freed = freed and (not is_instance_valid(ring) or ring.is_queued_for_deletion())
	assert_true(freed, "the extra rings are freed with the blades")
	assert_true(_whirlwind_mesh_count() == 0, "no whirlwind mesh is left behind")
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
	var arc_half: float = _fx.wave_material.get_shader_parameter(&"arc_half")
	var scale_m: float = _fx.fallback_wave_width * 0.5 / arc_half
	var front_margin: float = _fx.wave_material.get_shader_parameter(&"front_margin")
	var tail_extent: float = _fx.wave_material.get_shader_parameter(&"tail_extent")
	assert_true(plane != null and plane.size.x > _fx.fallback_wave_width,
		"the wave plane is wider than the arc, so the glow and the fanned shards fit")
	assert_true(plane != null and plane.size.y >= (front_margin + tail_extent) * scale_m - 0.001,
		"the wave plane reaches in front of the front edge and back over the shards and wisps")
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
	assert_true(sparks.particle_flag_align_y, "the wave sparks are streaks turned along their flight")
	assert_true(sparks.lifetime <= _fx.wave_spark_lifetime, "the wave sparks are short lived")
	# The front edge sits at local z = 0 and the wave flies towards -Z.
	var behind_front := true
	for point in sparks.emission_points:
		behind_front = behind_front and point.z > 0.0
	assert_true(behind_front, "the wave sparks start behind the front edge")
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
	assert_true(t1 > t0, "the wisps move on game time")
	TimeManager.request_pause(TimeManager.REASON_USER)
	await TimeManager.wait_real(0.1)
	assert_true(is_equal_approx(mesh.get_instance_shader_parameter(&"game_time"), t1), "while paused the wisps hold")
	TimeManager.release_pause(TimeManager.REASON_USER)
	await _clear()


func test_sword_wave_flicker() -> void:
	EventBus.settings_changed.emit(&"reduce_flash", true)
	_aim(Vector3.LEFT)
	_cast(&"sword_wave", _commander.global_position, 0.0)
	await _frames(2)
	var mesh := _fx.get_effect_mesh(&"sword_wave")
	assert_true(mesh != null and mesh.get_instance_shader_parameter(&"flicker") == 0.0,
		"reduced flashing stops the wisp gaps drifting")
	EventBus.settings_changed.emit(&"reduce_flash", false)
	await _frames(2)
	assert_true(mesh != null and mesh.get_instance_shader_parameter(&"flicker") == 1.0,
		"turning it back off brings the wisp drift back")
	assert_true(_fx.wave_material.shader.code.contains("wisp_scroll * flicker"), "the wisp drift follows the flicker setting")
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


func test_sword_wave_shader_rules() -> void:
	var code := _fx.wave_material.shader.code
	assert_true(code.contains("blend_premul_alpha"), "the wave blends with premultiplied alpha")
	assert_true(not code.contains("TIME"), "the wave runs on the game time it is given, not on engine time")
	assert_true(not code.contains("slash_common"), "the wave shader includes nothing")
	# The growth scaling must run before the offset to the disc centre, or the front edge drifts off the node.
	var scale_at := code.find("q /= mix(start_scale")
	var offset_at := code.find("q.y += arc_origin + arc_radius;")
	assert_true(scale_at >= 0 and offset_at > scale_at, "the wave grows around its front edge, which stays on the node")
	# The glow must be gone before the plane edge, or the plane shows as a faint rectangle.
	var margin: float = _fx.wave_material.get_shader_parameter(&"front_margin")
	var glow_w: float = _fx.wave_material.get_shader_parameter(&"glow_width")
	var glow_a: float = _fx.wave_material.get_shader_parameter(&"glow_alpha")
	assert_true(glow_a * exp(-margin / glow_w) < 0.005, "the glow is invisible at the front edge of the plane")
	var same_colours := true
	for color_name in [&"core_color", &"rim_color", &"band_color", &"shard_color", &"mid_color", &"tail_color"]:
		same_colours = same_colours and _fx.wave_material.get_shader_parameter(color_name) == _fx.whirlwind_material.get_shader_parameter(color_name)
	assert_true(same_colours, "Sword Wave and Whirlwind share the same base colours")


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


func test_palettes_complete() -> void:
	var ids: Array[StringName] = [&"sword_base", &"frost", &"chain_lightning", &"burn", &"rampage", &"swift"]
	var whole := true
	var seen: Array[String] = []
	for id in ids:
		var palette := _fx.palettes.get(id) as SkillPalette
		if palette == null:
			whole = false
			continue
		var colours: Array[Color] = [palette.core, palette.rim, palette.band, palette.shard, palette.mid, palette.tail, palette.spark]
		var key := ""
		for colour in colours:
			whole = whole and colour.a == 1.0
			key += colour.to_html(false)
		for other in colours.size() - 1:
			whole = whole and colours[other] != colours[other + 1]
		seen.append(key)
	assert_true(whole and _fx.palettes.size() == ids.size(), "every sword has a palette of seven colours")
	var unique := {}
	for key in seen:
		unique[key] = true
	assert_true(seen.size() == ids.size() and unique.size() == ids.size(), "the six palettes differ from each other")


func test_default_palette_is_base() -> void:
	_cast(&"whirlwind", Vector3.ZERO, WHIRLWIND_RADIUS)
	await _frames(1)
	var base := _fx.palettes[&"sword_base"] as SkillPalette
	assert_true(_mesh_colours_match(_fx.get_effect_mesh(&"whirlwind"), base), "before any sword is announced the base sword colours are used")
	await _clear()


func test_burn_palette_on_both_skills() -> void:
	var burn := _fx.palettes[&"burn"] as SkillPalette
	EventBus.weapon_equipped.emit(&"burn")
	_cast(&"whirlwind", Vector3.ZERO, WHIRLWIND_RADIUS)
	_aim(Vector3.LEFT)
	_cast(&"sword_wave", _commander.global_position, 0.0)
	await _frames(1)
	var ring_ok := _mesh_colours_match(_fx.get_effect_mesh(&"whirlwind"), burn)
	var extra := _fx.get_whirlwind_rings()
	for ring in extra:
		ring_ok = ring_ok and _mesh_colours_match(ring, burn)
	assert_true(ring_ok and not extra.is_empty(), "after equipping burn every Whirlwind ring uses the burn colours")
	assert_true(_mesh_colours_match(_fx.get_effect_mesh(&"sword_wave"), burn), "after equipping burn the Sword Wave uses the burn colours")
	var whirl_sparks := _fx.get_effect_particles(&"whirlwind")
	var wave_sparks := _fx.get_effect_particles(&"sword_wave")
	assert_true(whirl_sparks != null and whirl_sparks.color_ramp.get_color(0).is_equal_approx(burn.spark), "the Whirlwind sparks have the burn spark colour")
	assert_true(wave_sparks != null and wave_sparks.color_ramp.get_color(0).is_equal_approx(burn.spark), "the Sword Wave sparks have the burn spark colour")
	assert_true(_fx.whirlwind_material.get_shader_parameter(&"core_color") != burn.core, "the shared source material is not recoloured")
	EventBus.weapon_equipped.emit(&"sword_base")
	await _clear()


func test_sword_change_keeps_flying_effect() -> void:
	var base := _fx.palettes[&"sword_base"] as SkillPalette
	_aim(Vector3.LEFT)
	_cast(&"sword_wave", _commander.global_position, 0.0)
	_cast(&"whirlwind", Vector3.ZERO, WHIRLWIND_RADIUS)
	await _frames(1)
	var wave := _fx.get_effect_mesh(&"sword_wave")
	var whirl := _fx.get_effect_mesh(&"whirlwind")
	EventBus.weapon_equipped.emit(&"swift")
	await _frames(2)
	assert_true(_mesh_colours_match(wave, base) and _mesh_colours_match(whirl, base), "changing sword does not recolour an effect already flying")
	_cast(&"sword_wave", _commander.global_position, 0.0)
	await _frames(1)
	assert_true(_mesh_colours_match(_fx.get_effect_mesh(&"sword_wave"), _fx.palettes[&"swift"]), "the next cast uses the new sword colours")
	EventBus.weapon_equipped.emit(&"sword_base")
	await _clear()


func test_unknown_sword_uses_base() -> void:
	var base := _fx.palettes[&"sword_base"] as SkillPalette
	EventBus.weapon_equipped.emit(&"no_such_sword")
	_cast(&"whirlwind", Vector3.ZERO, WHIRLWIND_RADIUS)
	await _frames(1)
	assert_true(_mesh_colours_match(_fx.get_effect_mesh(&"whirlwind"), base), "a sword with no palette falls back to the base sword colours")
	var sparks := _fx.get_effect_particles(&"whirlwind")
	assert_true(sparks != null and sparks.color_ramp.get_color(0).is_equal_approx(base.spark), "its sparks use the base spark colour")
	EventBus.weapon_equipped.emit(&"sword_base")
	await _clear()


func test_sword_change_after_readd() -> void:
	var parent := _fx.get_parent()
	parent.remove_child(_fx)
	parent.add_child(_fx)
	EventBus.weapon_equipped.emit(&"swift")
	_cast(&"whirlwind", Vector3.ZERO, WHIRLWIND_RADIUS)
	await _frames(1)
	var swift := _fx.palettes[&"swift"] as SkillPalette
	assert_true(_mesh_colours_match(_fx.get_effect_mesh(&"whirlwind"), swift),
		"a manager taken out of the tree and added back still follows the sword change")
	EventBus.weapon_equipped.emit(&"sword_base")
	await _clear()
#endregion


#region Blade Tempest
const TEMPEST_ID := &"blade_tempest"
const TEMPEST_DURATION := 3.0
const TEMPEST_RAMP := 0.3


func test_tempest_age_mapping() -> void:
	var f := func(t: float) -> float: return SkillFxManager.tempest_age_ms(t, 3.0, 0.3, 83.0, 250.0, 400.0, 123.0, 200.0)
	assert_true(is_equal_approx(f.call(0.0), 0.0), "tempest age is 0 at the cast")
	assert_true(is_equal_approx(f.call(0.15), 41.5), "tempest age grows linearly over the ramp")
	assert_true(is_equal_approx(f.call(0.3), 83.0), "tempest age is form_ms at the end of the ramp")
	assert_true(is_equal_approx(f.call(0.3 + 0.1), 183.0), "tempest age runs on past form_ms on the first pass")
	assert_true(absf(f.call(0.3 + 0.12) - 203.0 + 77.0) < 0.5, "tempest age wraps back to the loop start after the loop end")
	var in_loop := true
	for i in range(400, 2700):
		var a: float = f.call(float(i) * 0.001)
		if a > 200.0 + 0.001 or (i > 520 and a < 123.0 - 0.001):
			in_loop = false
	assert_true(in_loop, "tempest age stays inside the loop window while looping")
	assert_true(is_equal_approx(f.call(2.85), 325.0), "tempest age is halfway through the unravel in the last ramp")
	assert_true(is_equal_approx(f.call(3.0), 400.0), "tempest age is end_ms at the end")
	assert_true(is_equal_approx(f.call(3.5), 400.0), "tempest age stays clamped at end_ms")
	# The blade angle (age + lost spin) never goes back, also across the jump into the unravel.
	var last := -1.0
	var smooth := true
	for i in 3001:
		var t := float(i) * 0.001
		var v: float = f.call(t) + SkillFxManager.tempest_spin_lost_ms(t, 3.0, 0.3, 83.0, 250.0, 400.0, 123.0, 200.0)
		if v < last - 0.001:
			smooth = false
		last = v
	assert_true(smooth, "age plus lost spin only ever goes forward")


func _tempest_cast() -> void:
	EventBus.skill_cast.emit(TEMPEST_ID, 0, 1, _commander.global_position, WHIRLWIND_RADIUS)


func test_tempest_lives_whole_channel() -> void:
	_tempest_cast()
	await _frames(1)
	assert_true(_fx.get_active_count(&"blade_tempest") == 1, "skill_cast blade_tempest adds one ring effect")
	assert_true(_fx.get_active_count(&"whirlwind") == 0, "the tempest ring is not a plain whirlwind")
	await TimeManager.wait_game(2.9)
	assert_true(_fx.get_active_count(&"blade_tempest") == 1, "the ring is still there at 2.9 s")
	await TimeManager.wait_game(0.1 + _fx.fade_time + 0.1)
	assert_true(_fx.get_active_count() == 0, "the ring frees itself after the channel")


func test_tempest_follows_commander() -> void:
	_commander.global_position = Vector3.ZERO
	_tempest_cast()
	await _frames(2)
	var mesh := _fx.get_effect_mesh(&"blade_tempest")
	var before := mesh.global_position if mesh != null else Vector3.ZERO
	_commander.global_position = Vector3(0, 0, 2)
	await _frames(2)
	assert_true(mesh != null and is_equal_approx(mesh.global_position.z - before.z, 2.0), "the ring moves with the commander")
	assert_true(mesh != null and is_equal_approx(mesh.global_position.y, _fx.whirlwind_height), "the ring stays at the middle of the commander")
	_commander.global_position = Vector3.ZERO
	await _clear()
	await TimeManager.wait_game(TEMPEST_DURATION)
	await _frames(2)


func test_tempest_cut_ends_ring() -> void:
	_tempest_cast()
	await TimeManager.wait_game(1.0)
	EventBus.skill_channel_ended.emit(TEMPEST_ID)
	await TimeManager.wait_game(_fx.channel_cut_time * 0.5)
	assert_true(_fx.get_active_count(&"blade_tempest") == 1, "the ring is still fading halfway through the cut")
	await TimeManager.wait_game(_fx.channel_cut_time + 0.1)
	await _frames(2)
	assert_true(_fx.get_active_count(&"blade_tempest") == 0, "a cut channel leaves no ring")
	assert_true(_tempest_nodes_left() == 0, "a cut channel leaves no mesh or particle node")


func test_tempest_end_signal_at_normal_end() -> void:
	_tempest_cast()
	await TimeManager.wait_game(2.8)
	var mesh := _fx.get_effect_mesh(&"blade_tempest")
	var before: float = mesh.get_instance_shader_parameter(&"age_ms") if mesh != null else -1.0
	EventBus.skill_channel_ended.emit(TEMPEST_ID)
	await _frames(2)
	var after: float = mesh.get_instance_shader_parameter(&"age_ms") if mesh != null else -1.0
	assert_true(after >= before, "an end signal in the last phase does not restart the unravel")
	await TimeManager.wait_game(0.5)
	await _frames(2)
	assert_true(_fx.get_active_count(&"blade_tempest") == 0, "the ring is gone after the normal end")


func test_edge_wave_start() -> void:
	# Checked in the same frame as the signal, before the wave has flown.
	_fire_wave(Vector3(-8, 0, 0), Vector3.RIGHT)
	var mesh := _fx.get_effect_mesh(&"sword_wave")
	assert_true(mesh != null and absf(mesh.global_position.x - (-8.0 + WHIRLWIND_RADIUS)) < 0.05,
		"a tempest wave starts at the ring edge")
	await _clear()


func test_edge_wave_stops_at_wall() -> void:
	# The wall face is at WALL_X, nearer than the ring edge: the wave must not appear behind it.
	_fire_wave(Vector3.ZERO, Vector3.RIGHT)
	var mesh := _fx.get_effect_mesh(&"sword_wave")
	assert_true(mesh != null and mesh.global_position.x <= WALL_X + 0.01, "a tempest wave never passes the wall")
	await TimeManager.wait_game(0.5)
	assert_true(_fx.get_effect_mesh(&"sword_wave") == null, "a wave blocked at once is gone after its fade")
	await _clear()


func test_sword_wave_unchanged() -> void:
	_commander.global_position = Vector3(-8, 0, 0)
	_aim(Vector3.RIGHT)
	_cast(&"sword_wave", _commander.global_position, 0.0)
	var mesh := _fx.get_effect_mesh(&"sword_wave")
	assert_true(mesh != null and absf(mesh.global_position.x - (-8.0 + _fx.wave_start_offset)) < 0.05,
		"a plain sword wave still starts at wave_start_offset")
	_commander.global_position = Vector3.ZERO
	await _clear()


func test_sword_wave_wall_inside_offset_unchanged() -> void:
	# A wall 0.1 m ahead (0.2 m thick) lies wholly inside wave_start_offset: a plain wave starts
	# beyond it and flies its full distance, as before.
	var wall := _make_wall_at(Vector3(-8.0 + 0.1 + 0.1, 1.0, 0.0))
	_commander.global_position = Vector3(-8, 0, 0)
	_aim(Vector3.RIGHT)
	_cast(&"sword_wave", _commander.global_position, 0.0)
	var mesh := _fx.get_effect_mesh(&"sword_wave")
	assert_true(mesh != null and absf(mesh.global_position.x - (-8.0 + _fx.wave_start_offset)) < 0.05,
		"a plain sword wave with a wall 0.1 m ahead starts at wave_start_offset like before")
	var flight := (_fx.fallback_wave_distance - _fx.wave_start_offset) / _fx.fallback_wave_speed
	await TimeManager.wait_game(flight + _fx.fade_time * 0.5)
	var travelled := _flat_distance(mesh.global_position, _commander.global_position) if is_instance_valid(mesh) else INF
	assert_true(absf(travelled - _fx.fallback_wave_distance) < 0.05, "that plain wave still flies its full distance (got %.2f)" % travelled)
	await _clear()
	_fire_wave(Vector3(-8, 0, 0), Vector3.RIGHT)
	var tempest := _fx.get_effect_mesh(&"sword_wave")
	assert_true(tempest != null and absf(tempest.global_position.x - (-8.0 + 0.1)) < 0.05,
		"a tempest wave with a wall inside its start offset starts at the wall")
	wall.queue_free()
	_commander.global_position = Vector3.ZERO
	await _clear()


func _make_wall_at(pos: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 2.0, 6.0)
	shape.shape = box
	wall.add_child(shape)
	wall.position = pos
	add_child(wall)
	return wall


func test_tempest_cleared_on_run_started() -> void:
	_tempest_cast()
	await _frames(2)
	EventBus.run_started.emit()
	await _frames(2)
	assert_true(_fx.get_active_count() == 0, "run_started clears the tempest ring")
	assert_true(_tempest_nodes_left() == 0, "no tempest node is left behind")


func _fire_wave(origin: Vector3, dir: Vector3) -> void:
	EventBus.skill_wave_fired.emit(TEMPEST_ID, origin, dir, 1)


## Mesh and particle nodes under the manager that are not already queued for deletion.
func _tempest_nodes_left() -> int:
	return _fx.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()
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


## Meshes still alive under the manager: the main ring and the extra ones.
func _whirlwind_mesh_count() -> int:
	return _fx.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D and not n.is_queued_for_deletion()).size()


## Whether the six shader colours on the mesh's material are the palette's.
func _mesh_colours_match(mesh: MeshInstance3D, palette: SkillPalette) -> bool:
	var material := mesh.material_override as ShaderMaterial if mesh != null else null
	if material == null or palette == null:
		return false
	var want := {&"core_color": palette.core, &"rim_color": palette.rim, &"band_color": palette.band,
		&"shard_color": palette.shard, &"mid_color": palette.mid, &"tail_color": palette.tail}
	for key in want:
		if not (material.get_shader_parameter(key) as Color).is_equal_approx(want[key]):
			return false
	return true


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _clear() -> void:
	await TimeManager.wait_game(1.2)
	await _frames(2)


func _whirlwind_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = [_fx.get_effect_mesh(&"whirlwind")]
	meshes.append_array(_fx.get_whirlwind_rings())
	return meshes


func _wave_mesh() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = [_fx.get_effect_mesh(&"sword_wave")]
	return meshes


func _tilt_deg(mesh: MeshInstance3D) -> float:
	return rad_to_deg(mesh.global_basis.y.angle_to(Vector3.UP)) if mesh != null else INF


func _all_flat(meshes: Array[MeshInstance3D]) -> bool:
	for mesh in meshes:
		if mesh == null or not mesh.global_basis.y.normalized().is_equal_approx(Vector3.UP):
			return false
	return true


## Degrees between the camera's view of the mesh centre and the mesh plane.
func _view_angle(mesh: MeshInstance3D, cam: Camera3D) -> float:
	var to_cam := (cam.global_position - mesh.global_position).normalized()
	return rad_to_deg(asin(absf(to_cam.dot(mesh.global_basis.y.normalized()))))


func _lowest_corner(mesh: MeshInstance3D) -> float:
	var box := mesh.get_aabb()
	var low := INF
	for i in 8:
		low = minf(low, (mesh.global_transform * box.get_endpoint(i)).y)
	return low


func _cast_tilt_pair(origin: Vector3) -> void:
	_fx.clear()
	_aim(Vector3.FORWARD)
	_cast(&"whirlwind", origin, WHIRLWIND_RADIUS)
	_cast(&"sword_wave", origin, 0.0)
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


## Placed after the other tests: it swaps the camera and puts the old one back at the end.
func test_tilt_toward_low_camera() -> void:
	var old_cam := get_viewport().get_camera_3d()
	var origin := Vector3(-6, 0, 0)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true

	cam.global_position = origin + Vector3(0, 10, 6)
	cam.look_at(origin)
	await _cast_tilt_pair(origin)
	assert_true(_all_flat(_wave_mesh()) and _all_flat(_whirlwind_meshes()), "a high camera leaves both effects flat")

	cam.global_position = origin + Vector3(0, 1.2, 9)
	cam.look_at(origin + Vector3.UP * 0.6)
	await _cast_tilt_pair(origin)
	var wave: MeshInstance3D = _wave_mesh()[0]
	assert_true(wave != null and not _all_flat(_wave_mesh())
		and _view_angle(wave, cam) >= _fx.min_view_angle - 1.0,
		"a low camera sees Sword Wave at least at min_view_angle")
	assert_true(wave != null and _lowest_corner(wave) >= origin.y + _fx.ground_lift - 0.001,
		"the tilted wave rises so no corner dips into the floor")
	var rings := _whirlwind_meshes()
	var one_disc := true
	for ring in rings:
		one_disc = one_disc and ring != null and ring.global_transform.is_equal_approx(rings[0].global_transform)
	assert_true(not _all_flat(rings) and _tilt_deg(rings[0]) <= _fx.whirlwind_max_tilt + 0.5,
		"a low camera tilts Whirlwind, at most whirlwind_max_tilt")
	var whirl_clear := true
	for ring in rings:
		whirl_clear = whirl_clear and ring != null and _lowest_corner(ring) >= origin.y
	assert_true(one_disc and rings[0].global_position.is_equal_approx(origin + Vector3.UP * _fx.whirlwind_height),
		"the Whirlwind rings tilt together about their centre, without moving")
	assert_true(whirl_clear, "the tilted Whirlwind never cuts into the floor")

	# Looking up from near the floor, as the chase camera does at its highest pitch.
	cam.global_position = origin + Vector3(0, 0.3, 3)
	cam.look_at(origin + Vector3.UP * 1.6)
	await _cast_tilt_pair(origin)
	wave = _wave_mesh()[0]
	assert_true(_tilt_deg(wave) <= _fx.wave_max_tilt + 0.5, "a camera below the wave never tilts it past wave_max_tilt")
	var whirl: MeshInstance3D = _whirlwind_meshes()[0]
	assert_true(_tilt_deg(whirl) <= _fx.whirlwind_max_tilt + 0.5
		and whirl.global_position.is_equal_approx(origin + Vector3.UP * _fx.whirlwind_height),
		"a camera looking up never tilts Whirlwind past whirlwind_max_tilt nor lifts it")

	var angle := _fx.min_view_angle
	_fx.min_view_angle = 0.0
	cam.global_position = origin + Vector3(0, 1.2, 9)
	cam.look_at(origin + Vector3.UP * 0.6)
	await _cast_tilt_pair(origin)
	assert_true(_all_flat(_wave_mesh()) and _all_flat(_whirlwind_meshes()),
		"min_view_angle 0 keeps both effects flat under a low camera")
	_fx.min_view_angle = angle

	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.global_position = origin + Vector3.UP * 10.0
	cam.rotation_degrees = Vector3(-90, 0, 0)
	await _cast_tilt_pair(origin)
	assert_true(_all_flat(_wave_mesh()) and _all_flat(_whirlwind_meshes()), "a top-down overview camera leaves both effects flat")

	_fx.clear()
	cam.queue_free()
	if old_cam != null:
		old_cam.current = true


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
