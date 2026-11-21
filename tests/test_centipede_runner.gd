extends Node3D

## Skeletal Centipede: AI scoring, every move's hit times and shapes, the armor phases, death,
## chain survivability and the model scale. The boss's own clocks are stepped by hand (process and
## physics off), so results do not depend on frame timing. Distances are written at model scale 1
## and multiplied by the scale of the data under test. The structure case runs the boss's physics
## by hand against real colliders. Spit and Combo open with the roar, so their times add its length.

const BOSS_SCENE: PackedScene = preload("res://entities/enemy/skeletal_centipede.tscn")
const BOSS_DATA: CentipedeBossData = preload("res://data/bosses/skeletal_centipede_boss.tres")
const POOL_SCENE: PackedScene = preload("res://entities/enemy/poison_pool.tscn")
const FX_LIBRARY: AnimationLibrary = preload("res://art/vfx/centipede_fx_library.tres")
const STEP: float = 1.0 / 60.0
const SLASH: StringName = SkeletalCentipede.MOVE_SLASH
const COMBO: StringName = SkeletalCentipede.MOVE_COMBO
const SPIT: StringName = SkeletalCentipede.MOVE_SPIT
const ROLL: StringName = SkeletalCentipede.MOVE_ROLL
const CHARGE_ROLL: StringName = SkeletalCentipede.MOVE_CHARGE_ROLL
const DASH: StringName = SkeletalCentipede.MOVE_DASH

var passes: int = 0
var fails: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("            SKELETAL CENTIPEDE VERIFICATION            ")
	print("=======================================================")

	# The two cases that wait for physics frames run first: a boss freed before its own navigation
	# setup has run makes the engine log an error, and the cases below free hundreds of them.
	await test_tc22_dash()
	await test_tc23_structures()
	test_tc1_brain_scores()
	test_tc4_slash()
	test_tc5_combo()
	test_tc6_spit_stream()
	test_tc7_spit_pool()
	test_tc8_roll()
	test_tc9_turn()
	test_tc10_armor_phase()
	test_tc13_death()
	test_tc15_chains_stay_survivable()
	test_tc16_default_scale()
	test_tc17_scale_is_proportional()
	test_tc19_brain_v2()
	test_tc20_roar_lead_in()
	test_tc21_charge_roll()

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")
	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		push_error("  [FAIL] %s" % test_name)


# --- Helpers -----------------------------------------------------------------------------------

## Boss at the origin facing +Z with its own loops off, so the test drives them.
func _make_boss(boss_data: CentipedeBossData = null, wave: int = 15) -> SkeletalCentipede:
	var boss := BOSS_SCENE.instantiate() as SkeletalCentipede
	if boss_data != null:
		boss.data = boss_data
	add_child(boss)
	boss.set_physics_process(false)
	boss.set_process(false)
	boss.global_position = Vector3.ZERO
	boss.rotation.y = 0.0
	boss.spawn_grace = false
	boss.spawn_wave = wave  # third appearance: every move unlocked
	boss.is_in_spawn_zone = false
	boss.set_ai_seed(1234)
	return boss


func _make_commander(pos: Vector3) -> MockCommander:
	var cmd := MockCommander.new()
	add_child(cmd)
	cmd.global_position = pos
	return cmd


func _make_structure(pos: Vector3, group: StringName = &"tower") -> MockStructure:
	var structure := MockStructure.new(group)
	add_child(structure)
	structure.global_position = pos
	return structure


## Data copy at another model scale.
func _scaled_data(model_scale: float) -> CentipedeBossData:
	var scaled := BOSS_DATA.duplicate() as CentipedeBossData
	scaled.model_scale = model_scale
	return scaled


## Length of the roar that opens Spit and Combo, in clip seconds (speed 1).
func _roar(boss: SkeletalCentipede) -> float:
	return boss._clip_length(SkeletalCentipede.CLIP_ROAR)


## Runs the boss's process and state clocks for seconds of game time.
func _step(boss: SkeletalCentipede, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		boss._process(STEP)
		boss._update_state(STEP)
		t += STEP


## Puts the boss in the ATTACK state against target and starts move, as the AI would.
func _start(boss: SkeletalCentipede, target: Node3D, move: StringName) -> void:
	boss.current_target = target
	boss.current_state = Enums.EnemyState.ATTACK
	boss._start_move(move)


func _free_all(nodes: Array) -> void:
	for node: Node in nodes:
		if is_instance_valid(node):
			node.free()
	for child in get_children():
		if child is PoisonPool:
			child.free()


func _pools() -> Array[PoisonPool]:
	var pools: Array[PoisonPool] = []
	for child in get_children():
		if child is PoisonPool:
			pools.append(child)
	return pools


func _situation(overrides: Dictionary = {}) -> CentipedeBrain.Situation:
	var s := CentipedeBrain.Situation.new()
	s.engaged = true
	s.in_front = true
	s.combo_unlocked = true
	s.combo_ready = true
	s.spit_unlocked = true
	s.spit_ready = true
	s.roll_unlocked = true
	s.roll_ready = true
	for key in overrides:
		s.set(key, overrides[key])
	return s


func _pick(s: CentipedeBrain.Situation) -> StringName:
	return CentipedeBrain.decide(s, BOSS_DATA, func() -> float: return 0.0)


# --- Cases -------------------------------------------------------------------------------------

func test_tc1_brain_scores() -> void:
	print("\n[TC1] Brain scores")
	var d := BOSS_DATA
	assert_true(_pick(_situation({"in_spit_reach": true, "distance": d.body(3.0), "spit_ready": false})) == CentipedeBrain.CHASE, "Spit cooling down: CHASE")
	var behind := CentipedeBrain.score_all(_situation({"in_front": false, "distance": d.body(3.5), "charge_roll_unlocked": true, "charge_roll_ready": true}), d)
	assert_true(float(behind[CentipedeBrain.CHARGE_ROLL]) > 0.0, "The charge roll scores for a commander behind the boss")
	var close := CentipedeBrain.score_all(_situation({"in_slash": true, "distance": d.body(1.0), "charge_roll_unlocked": true, "charge_roll_ready": true}), d)
	assert_true(is_zero_approx(float(close[CentipedeBrain.CHARGE_ROLL])), "Inside the slash the charge roll scores nothing")
	assert_true(_pick(_situation({"in_front": false, "has_objective": true, "t_away": 4.0})) == CentipedeBrain.PUSH, "Out of reach for 4 s with a structure: PUSH")
	var low_hp := CentipedeBrain.score_all(_situation({"in_slash": true, "hp_fraction": 0.4}), BOSS_DATA)
	assert_true(float(low_hp[CentipedeBrain.COMBO]) > 0.0, "Below half HP the combo scores")
	var locked := CentipedeBrain.score_all(_situation({"in_slash": true, "hp_fraction": 0.4, "combo_unlocked": false}), BOSS_DATA)
	assert_true(is_zero_approx(float(locked[CentipedeBrain.COMBO])), "Combo locked: no score")

	# The same picks through a real boss, at the model's own scale.
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(0.0, 0.0, BOSS_DATA.body(3.0)))
	boss.current_target = cmd
	boss.provoked_by_player = true
	assert_true(boss.choose_attack() == CentipedeBrain.SPIT, "Boss with the commander 3 body-metres ahead: SPIT")
	# The combo and the dash are put on cooldown so the pick is a clear one.
	boss.combo_cooldown_left = 99.0
	boss.dash_cooldown_left = 99.0
	cmd.global_position = Vector3(0.0, 0.0, BOSS_DATA.body(1.2))
	assert_true(boss.choose_attack() == CentipedeBrain.SLASH, "Commander inside the slash: SLASH")
	boss.charge_roll_cooldown_left = 99.0
	cmd.global_position = Vector3(0.0, 0.0, BOSS_DATA.body(5.2))
	assert_true(boss.choose_attack() == CentipedeBrain.ROLL, "Commander 5.2 body-metres ahead and provoked: ROLL")
	boss.provoked_by_player = false
	assert_true(boss.build_situation().engaged, "Not hit yet, but inside the engage range: the boss still fights")
	cmd.global_position = Vector3(0.0, 0.0, BOSS_DATA.body(BOSS_DATA.engage_range + 0.3))
	assert_true(not boss.build_situation().engaged, "Past the engage range and not hit: not engaged")
	cmd.global_position = Vector3(0.0, 0.0, BOSS_DATA.body(5.2))
	boss.spawn_wave = 5
	assert_true(boss.choose_attack() == CentipedeBrain.CHASE, "First appearance has no roll: CHASE")
	cmd.global_position = Vector3(0.0, 0.0, -2.0)
	assert_true(boss.choose_attack() == CentipedeBrain.FACE, "Commander behind: FACE")
	_free_all([cmd, boss])


func test_tc4_slash() -> void:
	print("\n[TC4] Slash")
	var d := BOSS_DATA
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(0.0, 0.0, d.body(1.2)))
	var clips: Array[StringName] = []
	boss.move_started.connect(func(_move: StringName, clip: StringName, _dur: float) -> void: clips.append(clip))
	boss.combo_cooldown_left = 99.0
	boss.current_target = cmd
	boss.change_state(Enums.EnemyState.ATTACK)
	_step(boss, 0.57)
	assert_true(cmd.hits.is_empty(), "No damage before the swing's window opens at 0.6 s")
	_step(boss, 0.4)
	assert_true(cmd.hits.size() == 1, "One hit once the window has opened")
	_step(boss, 0.25)
	assert_true(cmd.hits.size() == 1, "No second hit after the window")
	assert_true(clips == [SkeletalCentipede.CLIP_SLASH_3] and cmd.hits[0].amount == d.la3_damage and cmd.hits[0].damage_type == Enums.DamageType.SLASH
			and is_equal_approx(cmd.hits[0].knockback_force, d.la3_knockback), "Dead ahead plays the heavy third swing: la3_damage SLASH with knockback")
	_free_all([cmd, boss])

	for case in [["right", -d.body(0.8), SkeletalCentipede.CLIP_SLASH_1], ["left", d.body(0.8), SkeletalCentipede.CLIP_SLASH_2]]:
		var side_boss := _make_boss()
		var side_cmd := _make_commander(Vector3(case[1], 0.0, d.body(1.2)))
		var side_clips: Array[StringName] = []
		side_boss.move_started.connect(func(_move: StringName, clip: StringName, _dur: float) -> void: side_clips.append(clip))
		_start(side_boss, side_cmd, SLASH)
		_step(side_boss, 1.0)
		assert_true(side_clips == [case[2]] and side_cmd.hits.size() == 1 and side_cmd.hits[0].amount == d.la_damage and is_zero_approx(side_cmd.hits[0].knockback_force),
				"Commander on the %s plays %s: one la_damage hit, no knockback" % [case[0], case[2]])
		_free_all([side_cmd, side_boss])

	var back_boss := _make_boss()
	var back_cmd := _make_commander(Vector3(0.0, 0.0, -d.body(1.0)))
	_start(back_boss, back_cmd, SLASH)
	_step(back_boss, 1.2)
	assert_true(back_cmd.hits.is_empty(), "Commander behind the boss is not hit")
	back_cmd.is_dodging = true
	back_cmd.global_position = Vector3(0.0, 0.0, d.body(1.2))
	_start(back_boss, back_cmd, SLASH)
	_step(back_boss, 1.2)
	assert_true(back_cmd.hits.is_empty(), "A dodging commander is not hit")
	_free_all([back_cmd, back_boss])

	var other := _make_boss()
	var target := _make_commander(Vector3(8.0, 0.0, 8.0))
	var wall := _make_structure(Vector3(0.0, 0.0, d.body(1.2)), &"tower")
	wall.add_to_group(&"tower_wall")
	var enemy := _make_structure(Vector3(0.0, 0.0, d.body(1.0)), &"enemy")
	_start(other, target, SLASH)
	_step(other, 1.2)
	assert_true(wall.hits.is_empty() and enemy.hits.is_empty(), "A wall tower and an enemy unit in the sector are not hit")
	var ground := _make_structure(Vector3(0.0, 0.0, d.body(1.2)), &"tower")
	_start(other, target, SLASH)
	_step(other, 1.2)
	assert_true(ground.hits.size() == 1, "A ground tower in the sector is hit")
	_free_all([target, wall, enemy, ground, other])


func test_tc5_combo() -> void:
	print("\n[TC5] Combo")
	var d := BOSS_DATA
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(0.0, 0.0, d.body(1.2)))
	var windows_hit := [0]
	boss.move_hit.connect(func(_move: StringName, _window: int, targets: Array) -> void:
		if targets.has(cmd):
			windows_hit[0] += 1)
	_start(boss, cmd, COMBO)
	_step(boss, _roar(boss) + 5.3)
	var total := 0
	for info in cmd.hits:
		total += info.amount
	var expected := 10 * d.combo_hit_damage + d.combo_finisher_damage
	assert_true(windows_hit[0] == 11 and cmd.hits.size() == 11, "All eleven windows hit the commander once")
	assert_true(total == expected and cmd.hits[10].amount == d.combo_finisher_damage and cmd.hits[10].knockback_force > 0.0,
			"Hits add up to ten light hits and the finisher (%d), the last one with knockback" % expected)
	var advanced := boss.global_position.z
	assert_true(absf(advanced - d.body(0.6)) < d.body(0.05), "Boss steps forward 0.6 body-metres (%.2f m)" % advanced)
	assert_true(boss._move == &"" and boss.combo_cooldown_left > 0.0, "Combo ended and went on cooldown")

	var animation := FX_LIBRARY.get_animation(&"combo_vfx")
	var frame := 1.0 / 60.0
	var matched := 0
	for i in d.combo_hit_windows.size():
		var track_name := "VFX_SlashCombo_%02d" % (i + 1) if i < 10 else "VFX_SlashCombo_11_L"
		var span := _trail_span(animation, "SlashCombo/" + track_name)
		var window := d.combo_hit_windows[i]
		if absf(window.x - span.x) <= frame and absf(window.y - span.y) <= frame:
			matched += 1
		else:
			print("    window %d is %s, trail %s" % [i, window, span])
	assert_true(matched == 11, "Every hit window matches its slash trail in the effect library (%d of 11)" % matched)
	_free_all([cmd, boss])


## Start and end of the 0 to 1 sweep of a trail's progress track.
func _trail_span(animation: Animation, node_path: String) -> Vector2:
	var track := animation.find_track(NodePath(node_path + ":instance_shader_parameters/progress"), Animation.TYPE_VALUE)
	var start := 0.0
	var end := 0.0
	for key in animation.track_get_key_count(track):
		var value := float(animation.track_get_key_value(track, key))
		var time := animation.track_get_key_time(track, key)
		if value <= 0.0:
			start = time
		elif is_zero_approx(end) and value >= 1.0:
			end = time
	return Vector2(start, end)


func test_tc6_spit_stream() -> void:
	print("\n[TC6] Spit stream")
	var d := BOSS_DATA
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(0.0, 0.0, 1.0))
	_start(boss, cmd, SPIT)
	var apex := boss.get_spit_apex()
	cmd.global_position = apex + Vector3(0.0, 0.0, d.body(2.5))
	var yaw_changed := false
	var t := 0.0
	while boss._move == SPIT and t < 9.0:
		_step(boss, STEP)
		t += STEP
		if absf(boss.rotation.y) > 0.0001:
			yaw_changed = true
	var ticks := 0
	for info in cmd.hits:
		if info.is_dot and info.damage_type == Enums.DamageType.MAGIC:
			ticks += 1
	assert_true(ticks >= 9 and ticks <= 11, "Commander in the cone takes 10 DoT ticks (%d)" % ticks)
	assert_true(not yaw_changed, "The boss does not turn during the spit")
	var roar := _roar(boss)
	assert_true(t > roar + 4.0 and t < roar + 4.5 and boss.spit_cooldown_left > 0.0,
			"The move lasts the roar, the clip and the held stream, then cools down (%.2f s)" % t)
	for pool in _pools():
		pool.free()
	cmd.free()

	var outside := _make_commander(Vector3(5.0, 0.0, 1.0))
	_start(boss, outside, SPIT)
	outside.global_position = boss.get_spit_apex() + Vector3(d.body(3.0), 0.0, d.body(1.0))
	_step(boss, _roar(boss) + 4.5)
	assert_true(outside.hits.is_empty(), "A commander outside the cone takes nothing")
	_free_all([outside, boss])


func test_tc7_spit_pool() -> void:
	print("\n[TC7] Spit pool")
	var d := BOSS_DATA
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(40.0, 0.0, 40.0))
	_start(boss, cmd, SPIT)
	_step(boss, _roar(boss) + d.pool_spawn_time - 0.1)
	assert_true(_pools().is_empty(), "No pool before its spawn time")
	_step(boss, 0.2)
	var origin := boss.to_global(d.body_v3(d.pool_offset))
	var spit_yaw := boss.rotation.y
	var pools := _pools()
	assert_true(pools.size() == 1, "One pool is spawned at its spawn time")
	_step(boss, 4.0)
	var pool := pools[0]
	pool.set_physics_process(false)
	assert_true(pool.global_position.distance_to(origin) < 0.01 and absf(pool.rotation.y - spit_yaw) < 0.001,
			"The pool starts at the boss's pool offset, facing where the boss faced")

	var inside := _make_commander(origin + Vector3(0.0, 0.0, d.body(2.5)))
	for i in 63:
		pool._physics_process(STEP)
	assert_true(inside.hits.size() == 2 and inside.hits[0].is_dot and inside.hits[0].damage_type == Enums.DamageType.MAGIC,
			"A commander in the pool takes a MAGIC tick every 0.5 s (%d in 1.05 s)" % inside.hits.size())
	inside.hits.clear()
	inside.global_position = origin + Vector3(0.0, 0.0, d.body(d.pool_length * d.pool_cut_fraction * 0.7))
	for i in 63:
		pool._physics_process(STEP)
	assert_true(inside.hits.is_empty(), "The cut-away part near the boss's mouth does not hurt")
	inside.global_position = Vector3(30.0, 0.0, 0.0)
	var steps := 126
	while not pool.is_queued_for_deletion() and steps < 600:
		pool._physics_process(STEP)
		steps += 1
	assert_true(absf(steps * STEP - d.pool_lifetime) < 0.1, "The pool is gone when its lifetime runs out (%.2f s)" % (steps * STEP))
	pool.free()

	# A boss that dies makes its pool fade out quickly.
	var fresh := _make_boss()
	fresh.current_target = cmd
	fresh._spawn_pool()
	var fading := _pools()[0]
	fading.set_physics_process(false)
	fresh._on_died()
	steps = 0
	while not fading.is_queued_for_deletion() and steps < 600:
		fading._physics_process(STEP)
		steps += 1
	assert_true(steps * STEP <= d.pool_fade_time + 0.1, "A pool whose boss died fades within the fade time (%.2f s)" % (steps * STEP))
	_free_all([inside, cmd, boss, fresh])


func test_tc8_roll() -> void:
	print("\n[TC8] Roll")
	var d := BOSS_DATA
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(0.0, 0.0, 8.0))
	_start(boss, cmd, ROLL)
	_step(boss, 1.5)
	assert_true(boss.global_position.length() < 0.001, "The roar keeps the boss still for its 1.5 s")
	var steps := 0
	while boss._roll_phase != SkeletalCentipede.RollPhase.LOOP and steps < 200:
		_step(boss, STEP)
		steps += 1
	var before := boss.global_position
	_step(boss, 20.0 * STEP)
	var speed := boss.global_position.distance_to(before) / (20.0 * STEP)
	var top_speed := minf(d.body(d.roll_speed), d.roll_speed_cap)
	assert_true(absf(speed - top_speed) < top_speed * 0.1, "Loop speed is roll_speed held down to its cap (%.2f m/s)" % speed)
	var guard := 0
	while boss._move == ROLL and guard < 1200:
		_step(boss, STEP)
		guard += 1
	assert_true(cmd.hits.size() == 1 and cmd.hits[0].amount == d.roll_damage and cmd.hits[0].damage_type == Enums.DamageType.BLAST and cmd.hits[0].knockback_force > 0.0,
			"The roll hits the commander once for roll_damage BLAST and throws it back")
	assert_true(boss.global_position.length() <= d.body(d.roll_max_distance) + 0.5 and boss.roll_cooldown_left > 0.0,
			"The roll stops within its maximum distance (%.2f m) and goes on cooldown" % boss.global_position.length())
	_free_all([cmd, boss])

	var tower_boss := _make_boss()
	var far := _make_commander(Vector3(0.0, 0.0, 40.0))
	var tower := _make_structure(Vector3(0.0, 0.0, 6.0))
	_start(tower_boss, far, ROLL)
	guard = 0
	while tower.hits.is_empty() and guard < 1200:
		_step(tower_boss, STEP)
		guard += 1
	assert_true(tower_boss._roll_phase == SkeletalCentipede.RollPhase.END, "The roll goes into its end clip the moment it hits a tower")
	_step(tower_boss, 2.0)
	assert_true(tower.hits.size() == 1 and tower.hits[0].amount == d.roll_damage, "A tower in the way takes roll_damage, once")
	_free_all([far, tower, tower_boss])

	var turn_boss := _make_boss()
	var side := _make_commander(Vector3(14.0, 0.0, 8.0))
	_start(turn_boss, side, ROLL)
	var max_turn := deg_to_rad(d.roll_turn_rate_deg) * STEP
	var worst := 0.0
	var turned := 0.0
	guard = 0
	while turn_boss._move == ROLL and guard < 1500:
		var yaw := turn_boss.rotation.y
		_step(turn_boss, STEP)
		worst = maxf(worst, absf(angle_difference(yaw, turn_boss.rotation.y)))
		guard += 1
	turned = absf(turn_boss.rotation.y)
	assert_true(worst <= max_turn + 0.0001, "The roll bends no faster than roll_turn_rate_deg (%.3f of %.3f rad per step)" % [worst, max_turn])
	assert_true(turned > 0.1, "The roll does bend toward a commander off to the side")
	_free_all([side, turn_boss])


func test_tc9_turn() -> void:
	print("\n[TC9] Turn")
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(0.0, 0.0, -3.0))
	var clips: Array[StringName] = []
	boss.move_started.connect(func(_move: StringName, clip: StringName, _dur: float) -> void: clips.append(clip))
	boss.dash_cooldown_left = 99.0
	boss.current_target = cmd
	boss.change_state(Enums.EnemyState.ATTACK)
	assert_true(clips == [SkeletalCentipede.CLIP_TURN_180], "A commander behind gets the half turn clip")
	var worst := 0.0
	var guard := 0
	while boss._move == SkeletalCentipede.MOVE_TURN and guard < 200:
		var yaw := boss.rotation.y
		_step(boss, STEP)
		worst = maxf(worst, absf(angle_difference(yaw, boss.rotation.y)))
		guard += 1
	var off := absf(rad_to_deg(angle_difference(boss.rotation.y, atan2(0.0, -3.0))))
	assert_true(off <= 2.0, "The boss ends the turn facing the commander (%.2f degrees off)" % off)
	assert_true(rad_to_deg(worst) < 15.0, "The yaw never jumps between two steps (%.1f degrees at most)" % rad_to_deg(worst))
	_free_all([cmd, boss])


func test_tc10_armor_phase() -> void:
	print("
[TC10] Armor phase")
	var d := BOSS_DATA
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(40.0, 0.0, 40.0))
	var particles := boss.get_node("Model/CentipedeFx/Head/SpitEmitter/Core") as CPUParticles3D
	_start(boss, cmd, SPIT)
	_step(boss, _roar(boss) + 1.0)
	assert_true(particles.emitting, "The stream's particles run while it spits")
	var mesh := boss.find_child("SkeletalCentipede_Mesh", true, false) as MeshInstance3D
	mesh.set_blend_shape_value(0, 0.7)
	assert_true(boss.take_damage(DamageInfo.new(100, Enums.DamageType.PIERCE)) == 0, "A PIERCE hit deals nothing to armor")
	boss.take_damage(DamageInfo.new(boss.current_armor_hp, Enums.DamageType.TRUE))
	assert_true(boss.current_phase == Enums.BossPhase.TRANSITION, "Breaking the armor starts the transition")
	assert_true(boss._move == &"" and not particles.emitting and is_zero_approx(mesh.get_blend_shape_value(0)),
			"The running move stops, the stream goes out and the ribs close again")
	assert_true(is_equal_approx(boss.get_resist(Enums.DamageType.SLASH), 1.5), "Transition resist is 1.5")
	var t := 0.0
	while boss.current_phase == Enums.BossPhase.TRANSITION and t < d.transition_duration + 1.0:
		boss._physics_process(STEP)
		t += STEP
	assert_true(boss.current_phase == Enums.BossPhase.EXPOSED, "The transition ends in the exposed phase")
	assert_true(is_equal_approx(boss.speed_multiplier, d.phase2_speed_mult) and is_equal_approx(boss.get_resist(Enums.DamageType.SLASH), 1.25),
			"Exposed speeds the boss up and its resist is 1.25")
	_free_all([cmd, boss])

	var combo_boss := _make_boss()
	var front := _make_commander(Vector3(0.0, 0.0, d.body(1.2)))
	_start(combo_boss, front, COMBO)
	_step(combo_boss, _roar(combo_boss) + 0.5)
	var hits_before := front.hits.size()
	combo_boss.take_damage(DamageInfo.new(combo_boss.current_armor_hp, Enums.DamageType.TRUE))
	_step(combo_boss, 2.0)
	assert_true(hits_before > 0 and front.hits.size() == hits_before, "The combo had started hitting and no more hits come out once it is stopped")
	_free_all([front, combo_boss])


func test_tc13_death() -> void:
	print("\n[TC13] Death")
	var boss := _make_boss()
	boss.current_phase = Enums.BossPhase.EXPOSED
	boss.current_armor_hp = 0
	var defeated := [0]
	var seen := {"hp": []}
	var on_defeated := func() -> void: defeated[0] += 1
	var on_hp := func(armor: int, core: int, _phase: StringName) -> void: seen["hp"] = [armor, core]
	EventBus.boss_defeated.connect(on_defeated)
	EventBus.boss_hp_changed.connect(on_hp)
	var model := boss.get_node("Model") as Node3D
	boss.take_damage(DamageInfo.new(boss.current_core_hp, Enums.DamageType.TRUE))
	assert_true(boss.is_dead and defeated[0] == 1 and seen["hp"] == [0, 0], "The boss dies, announces its defeat once and sends zero HP to the bar")
	boss._process(0.0)
	var t := 0.0
	while t < BOSS_DATA.death_duration + 0.1:
		boss._process(STEP)
		t += STEP
	assert_true(boss.is_queued_for_deletion(), "The boss is removed after the death time")
	assert_true(model.position.y <= -BOSS_DATA.body(BOSS_DATA.death_sink_depth) + 0.01, "The model has sunk into the floor")
	boss.free()

	var room_boss := _make_boss()
	room_boss.in_hazard_trial = true
	room_boss.current_phase = Enums.BossPhase.EXPOSED
	room_boss.take_damage(DamageInfo.new(room_boss.current_core_hp, Enums.DamageType.TRUE))
	assert_true(room_boss.is_dead and defeated[0] == 1, "The Hazard Trial copy does not announce a boss defeat")
	EventBus.boss_defeated.disconnect(on_defeated)
	EventBus.boss_hp_changed.disconnect(on_hp)
	room_boss.free()


func test_tc15_chains_stay_survivable() -> void:
	print("\n[TC15] Chains stay survivable at wave 5")
	var boss := _make_boss()
	boss.apply_wave_scale(1.0, Enemy.DEFAULT_SCALE_CONFIG.get_dmg_mult(5), 1.0, 5)
	var d := BOSS_DATA
	var cmd := _make_commander(Vector3(0.0, 0.0, d.body(1.2)))
	_start(boss, cmd, COMBO)
	_step(boss, _roar(boss) + 5.3)
	var combo_total := _damage_sum(cmd)
	print("  combo total: %d" % combo_total)
	assert_true(combo_total > 0 and combo_total < 100, "The whole combo stays under 100")

	cmd.hits.clear()
	_start(boss, cmd, SPIT)
	cmd.global_position = boss.get_spit_apex() + Vector3(0.0, 0.0, d.body(2.5))
	_step(boss, _roar(boss) + 4.5)
	var stream_total := _damage_sum(cmd)
	print("  spit stream total: %d" % stream_total)
	assert_true(stream_total > 0 and stream_total < 100, "The whole stream stays under 100")
	var pool := _pools()[0]
	pool.set_physics_process(false)
	cmd.hits.clear()
	cmd.global_position = pool.global_position + Vector3(0.0, 0.0, d.body(2.5))
	var steps := 0
	while not pool.is_queued_for_deletion() and steps < 600:
		pool._physics_process(STEP)
		steps += 1
	var pool_total := _damage_sum(cmd)
	print("  pool total: %d" % pool_total)
	assert_true(pool_total > 0 and pool_total < 100, "The whole pool stays under 100")

	cmd.hits.clear()
	cmd.global_position = Vector3(0.0, 0.0, d.body(5.0))
	_start(boss, cmd, CHARGE_ROLL)
	var guard := 0
	while boss._move == CHARGE_ROLL and guard < 1500:
		_step(boss, STEP)
		guard += 1
	var charge_total := _damage_sum(cmd)
	print("  charge roll total: %d" % charge_total)
	assert_true(charge_total > 0 and charge_total < 100, "A charge roll stays under 100")
	_free_all([cmd, boss])


func _damage_sum(cmd: MockCommander) -> int:
	var total := 0
	for info in cmd.hits:
		total += info.amount
	return total


func test_tc16_default_scale() -> void:
	print("\n[TC16] Default scale")
	var d := BOSS_DATA
	var hint := {}
	for property in d.get_property_list():
		if property["name"] == "model_scale":
			hint = property
	var range_parts := String(hint.get("hint_string", "")).split(",")
	assert_true(int(hint.get("hint", 0)) == PROPERTY_HINT_RANGE and range_parts.size() >= 2
			and is_equal_approx(float(range_parts[0]), 3.0) and is_equal_approx(float(range_parts[1]), 4.5),
			"The model scale is limited to 3.0 to 4.5 in the editor")
	var a := _make_boss()
	var b := _make_boss()
	var model := a.get_node("Model") as Node3D
	assert_true(model.scale.is_equal_approx(Vector3.ONE * 3.0), "The model is scaled 3.0")
	var body_shape := a.get_node("CollisionShape3D") as CollisionShape3D
	var hurt_shape := a.get_node("HurtBox/CollisionShape3D") as CollisionShape3D
	assert_true((body_shape.shape as BoxShape3D).size.is_equal_approx(d.body_box_size * 3.0) and (hurt_shape.shape as BoxShape3D).size.is_equal_approx(d.body_box_size * 3.0),
			"The body box and the hurt box are the data's box times the scale")
	var other_shape := b.get_node("CollisionShape3D") as CollisionShape3D
	assert_true(body_shape.shape != other_shape.shape, "Two bosses do not share a shape")
	assert_true(is_equal_approx(a.nav.radius, 2.7), "The agent radius follows the body (2.7)")
	assert_true(is_equal_approx(a.get_attack_range(), 1.4 * 3.0) and is_equal_approx(a.nav.target_desired_distance, 1.4 * 3.0),
			"The attack range is scaled")
	_free_all([a, b])


func test_tc17_scale_is_proportional() -> void:
	print("\n[TC17] Scale is proportional")
	var roll_speeds: Array[float] = []
	var roll_clip_speeds: Array[float] = []
	var combo_steps: Array[float] = []
	var walk_speeds: Array[float] = []
	for model_scale: float in [3.0, 4.5]:
		var d := _scaled_data(model_scale)
		var tag := "scale %.1f" % model_scale
		var sized := _make_boss(d)
		var sized_box := (sized.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
		var sized_hurt := (sized.get_node("HurtBox/CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
		assert_true(sized_box.size.is_equal_approx(d.body_box_size * model_scale) and sized_hurt.size.is_equal_approx(d.body_box_size * model_scale),
				"%s: body box and hurt box follow the scale" % tag)
		assert_true(is_equal_approx(sized.nav.radius, maxf(d.agent_radius, d.body(d.body_box_size.z * 0.5))), "%s: agent radius follows the body" % tag)
		assert_true(is_equal_approx(sized.get_attack_range(), d.body(d.attack_range)), "%s: walk-up range follows the scale" % tag)
		_free_all([sized])
		for case in [[0.9, 1], [1.1, 0]]:
			var boss := _make_boss(d)
			var cmd := _make_commander(Vector3(0.0, 0.0, d.body(d.slash_range) * case[0]))
			_start(boss, cmd, SLASH)
			_step(boss, 1.2)
			assert_true(cmd.hits.size() == case[1], "%s: commander at %.1fx the slash range: %d hit(s)" % [tag, case[0], case[1]])
			_free_all([cmd, boss])

		var pool := POOL_SCENE.instantiate() as PoisonPool
		pool.setup(self, 4, d)
		add_child(pool)
		pool.set_physics_process(false)
		var length: float = d.pool_length * model_scale
		assert_true(pool.contains_point(pool.global_position + Vector3(0.0, 0.0, length - 0.1)), "%s: pool reaches its length" % tag)
		assert_true(not pool.contains_point(pool.global_position + Vector3(0.0, 0.0, length + 0.2)), "%s: pool ends past its length" % tag)
		pool.free()

		var roller := _make_boss(d)
		var far := _make_commander(Vector3(0.0, 0.0, 60.0))
		_start(roller, far, ROLL)
		var guard := 0
		while roller._roll_phase != SkeletalCentipede.RollPhase.LOOP and guard < 300:
			_step(roller, STEP)
			guard += 1
		var from := roller.global_position
		_step(roller, 10.0 * STEP)
		roll_speeds.append(roller.global_position.distance_to(from) / (10.0 * STEP))
		roll_clip_speeds.append(roller.anim_player.speed_scale)
		_free_all([far, roller])

		var stepper := _make_boss(d)
		var behind := _make_commander(Vector3(0.0, 0.0, -50.0))
		_start(stepper, behind, COMBO)
		_step(stepper, _roar(stepper) + 5.3)
		combo_steps.append(stepper.global_position.z)
		_free_all([behind, stepper])

		for case in [[0.9, true], [1.1, false]]:
			var spitter := _make_boss(d)
			var target := _make_commander(Vector3(0.0, 0.0, 60.0))
			_start(spitter, target, SPIT)
			target.global_position = spitter.get_spit_apex() + Vector3(0.0, 0.0, d.body(d.spit_stream_reach) * case[0])
			spitter._hurt_in_stream()
			assert_true(target.hits.is_empty() != case[1], "%s: stream at %.1fx its reach %s" % [tag, case[0], "hits" if case[1] else "misses"])
			_free_all([target, spitter])

		var slow := d.duplicate() as CentipedeBossData
		slow.move_speed = 0.5
		var walker := _make_boss(slow)
		walker._play_locomotion_anim()
		walk_speeds.append(walker.anim_player.speed_scale)
		_free_all([walker])
	assert_true(absf(roll_speeds[1] / roll_speeds[0] - 1.0) < 0.05, "Roll speed is the same at both scales (%.2f to %.2f)" % [roll_speeds[0], roll_speeds[1]])
	assert_true(absf(roll_clip_speeds[1] / roll_clip_speeds[0] - 1.0 / 1.5) < 0.05 * (1.0 / 1.5),
			"The roll clip plays slower on the bigger boss (%.2f to %.2f)" % [roll_clip_speeds[0], roll_clip_speeds[1]])
	assert_true(absf(combo_steps[1] / combo_steps[0] - 1.5) < 0.075, "The combo's advance grows with the scale (%.2f to %.2f)" % [combo_steps[0], combo_steps[1]])
	assert_true(absf(walk_speeds[1] / walk_speeds[0] - 1.0 / 1.5) < 0.03, "At the same ground speed the walk clip plays slower at the bigger scale")


func test_tc19_brain_v2() -> void:
	print("\n[TC19] Brain v2: groups, dash and the buff")
	var d := BOSS_DATA
	var never := func() -> float: return 0.0
	var seeded: Array = []
	for run in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var sequence: Array[StringName] = []
		for i in 20:
			sequence.append(CentipedeBrain.decide(_situation({"in_slash": true, "hp_fraction": 0.4}), d, rng.randf))
		seeded.append(sequence)
	assert_true(seeded[0] == seeded[1], "The same seed gives the same picks")

	var high := _situation({"in_slash": true, "hp_fraction": 0.9})
	var scores := CentipedeBrain.score_all(high, d)
	assert_true(is_equal_approx(float(scores[CentipedeBrain.COMBO]), d.weight_centipede_combo * d.combo_high_hp_mult * d.stickiness),
			"Above half HP the combo scores its weight times combo_high_hp_mult")
	assert_true(CentipedeBrain.decide(high, d, never) == CentipedeBrain.SLASH, "A roll of 0.0 inside the melee group picks the slash")
	assert_true(CentipedeBrain.decide(high, d, func() -> float: return 0.99) == CentipedeBrain.COMBO, "A roll of 0.99 inside the melee group picks the combo")

	var dash_side := {CentipedeBrain.DASH_LEFT: 0.6, CentipedeBrain.DASH_RIGHT: 0.12}
	assert_true(CentipedeBrain.pick(dash_side, d, never) == CentipedeBrain.DASH_LEFT, "Dash shares 1.0 / 0.2, roll 0.0: DASH_LEFT")
	assert_true(CentipedeBrain.pick(dash_side, d, func() -> float: return 0.95) == CentipedeBrain.DASH_RIGHT, "Dash shares 1.0 / 0.2, roll 0.95: DASH_RIGHT")
	var dash_open := {"dash_unlocked": true, "dash_ready": true, "distance": d.body(2.0), "dash_left_share": 1.0, "dash_right_share": 0.0}
	var one_side := CentipedeBrain.score_all(_situation(dash_open), d)
	assert_true(float(one_side[CentipedeBrain.DASH_LEFT]) > 0.0 and is_zero_approx(float(one_side[CentipedeBrain.DASH_RIGHT])), "A side with no room scores nothing")
	dash_open["distance"] = d.body(d.dash_trigger_reach + 0.5)
	var far := CentipedeBrain.score_all(_situation(dash_open), d)
	assert_true(is_zero_approx(float(far[CentipedeBrain.DASH_LEFT])), "Past the dash's trigger reach it scores nothing")

	var buffed := CentipedeBrain.score_all(_situation({"dash_buff": true, "in_spit_reach": true, "distance": d.body(5.2),
			"charge_roll_unlocked": true, "charge_roll_ready": true, "off_angle_deg": 25.0}), d)
	var face := float(buffed[CentipedeBrain.FACE])
	var spit := float(buffed[CentipedeBrain.SPIT])
	var charge := float(buffed[CentipedeBrain.CHARGE_ROLL])
	var roll := float(buffed[CentipedeBrain.ROLL])
	assert_true(face > spit and spit > charge and charge > roll and roll > 0.0,
			"After a dash the weights run Face > Spit > Charge Roll > Roll (%.2f, %.2f, %.2f, %.2f)" % [face, spit, charge, roll])
	var aligned := CentipedeBrain.score_all(_situation({"dash_buff": true, "off_angle_deg": 10.0}), d)
	assert_true(is_zero_approx(float(aligned[CentipedeBrain.FACE])), "After a dash the boss does not turn for 10 degrees")
	var plain := CentipedeBrain.score_all(_situation({"in_front": false}), d)
	assert_true(float(plain[CentipedeBrain.FACE]) > 0.0, "Without the buff a commander out of the front cone still gets a FACE")


func test_tc20_roar_lead_in() -> void:
	print("\n[TC20] Roar before Spit and Combo")
	var d := BOSS_DATA
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(0.0, 0.0, 1.0))
	var clips: Array[StringName] = []
	boss.move_started.connect(func(_move: StringName, clip: StringName, _dur: float) -> void: clips.append(clip))
	var warnings: Array[float] = []
	var on_telegraph := func(_kind: StringName, _position: Vector3, _radius: float, duration: float) -> void: warnings.append(duration)
	EventBus.telegraph_started.connect(on_telegraph)
	_start(boss, cmd, SPIT)
	EventBus.telegraph_started.disconnect(on_telegraph)
	var roar := _roar(boss)
	cmd.global_position = boss.get_spit_apex() + Vector3(0.0, 0.0, d.body(2.5))
	assert_true(clips == [SkeletalCentipede.CLIP_ROAR], "The spit is announced with the roar clip")
	assert_true(warnings.size() == 1 and is_equal_approx(warnings[0], roar + d.pool_spawn_time),
			"The warning runs the roar plus the time to the pool (%s)" % [warnings])
	var start := boss.global_position
	var yaw := boss.rotation.y
	_step(boss, roar - 0.1)
	assert_true(boss.global_position == start and is_equal_approx(boss.rotation.y, yaw) and cmd.hits.is_empty() and not boss._spit_emitting,
			"The boss stands still, keeps its facing and sends no stream during the roar")
	_step(boss, 0.1 + d.spit_stream_start + d.spit_stream_tick - 0.05)
	assert_true(cmd.hits.is_empty(), "The first tick comes only after the roar and the stream's start")
	_step(boss, 0.1)
	assert_true(cmd.hits.size() == 1, "The stream ticks once its start time is past")
	_step(boss, 6.0)
	for pool in _pools():
		pool.free()
	_free_all([cmd, boss])

	var combo_boss := _make_boss()
	var front := _make_commander(Vector3(0.0, 0.0, d.body(1.2)))
	_start(combo_boss, front, COMBO)
	_step(combo_boss, _roar(combo_boss) + 0.2)
	assert_true(front.hits.is_empty(), "The combo's first hit waits for the roar")
	_step(combo_boss, 6.0)
	assert_true(front.hits.size() == 11, "All eleven hits still land after the roar (%d)" % front.hits.size())
	_free_all([front, combo_boss])


func test_tc21_charge_roll() -> void:
	print("\n[TC21] Charge roll")
	var d := BOSS_DATA
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(0.0, 0.0, -9.0))
	cmd.is_dodging = true
	_start(boss, cmd, CHARGE_ROLL)
	_step(boss, _roar(boss) - 0.1)
	assert_true(boss.global_position.length() < 0.001 and absf(boss.rotation.y) < 0.0001, "The roar keeps the boss still and facing the way it did")
	var max_turn := deg_to_rad(d.charge_roll_turn_rate_deg) * STEP + deg_to_rad(0.01)
	var worst_turn := 0.0
	var fastest := 0.0
	var loop_frames := 0
	var off_at_start := -1.0
	var off_after_2s := -1.0
	var guard := 0
	while boss._move == CHARGE_ROLL and guard < 2000:
		var yaw := boss.rotation.y
		var before := boss.global_position
		if boss._roll_phase == SkeletalCentipede.RollPhase.LOOP:
			if loop_frames == 0:
				off_at_start = absf(boss._yaw_to(cmd))
			if loop_frames == 120:
				off_after_2s = absf(boss._yaw_to(cmd))
			loop_frames += 1
		_step(boss, STEP)
		worst_turn = maxf(worst_turn, absf(angle_difference(yaw, boss.rotation.y)))
		fastest = maxf(fastest, before.distance_to(boss.global_position) / STEP)
		guard += 1
	assert_true(loop_frames * STEP >= d.charge_roll_loop_time - STEP, "The loop runs for its time even when nothing is hit (%.2f s)" % (loop_frames * STEP))
	assert_true(worst_turn <= max_turn, "The roll bends no faster than charge_roll_turn_rate_deg (%.4f of %.4f rad per step)" % [worst_turn, max_turn])
	assert_true(fastest <= d.charge_roll_speed_cap * 1.05, "The roll stays under its speed cap (%.2f m/s)" % fastest)
	assert_true(off_at_start > 0.0 and off_after_2s >= 0.0 and off_after_2s < off_at_start,
			"The roll turns toward the commander (%.0f to %.0f degrees off)" % [rad_to_deg(off_at_start), rad_to_deg(off_after_2s)])
	assert_true(cmd.hits.is_empty() and boss.charge_roll_cooldown_left > 0.0, "A dodging commander is not hit and the roll went on cooldown")
	_free_all([cmd, boss])

	var hit_boss := _make_boss()
	var target := _make_commander(Vector3(0.0, 0.0, 14.0))
	_start(hit_boss, target, CHARGE_ROLL)
	var frame := 0
	var hit_frame := -1
	var end_frame := -1
	while hit_boss._move == CHARGE_ROLL and frame < 2000:
		_step(hit_boss, STEP)
		frame += 1
		if hit_frame < 0 and not target.hits.is_empty():
			hit_frame = frame
		if end_frame < 0 and hit_boss._roll_phase == SkeletalCentipede.RollPhase.END:
			end_frame = frame
	assert_true(target.hits.size() == 1 and target.hits[0].amount == hit_boss._scale_attack_damage(d.charge_roll_damage)
			and target.hits[0].damage_type == Enums.DamageType.BLAST and target.hits[0].knockback_force > 0.0,
			"The charge roll hits the commander once for charge_roll_damage BLAST with knockback")
	assert_true(end_frame >= 0 and (end_frame - hit_frame) * STEP <= d.charge_roll_after_hit_time + 2.0 * STEP,
			"The roll ends shortly after the hit (%d frames)" % (end_frame - hit_frame))
	_free_all([target, hit_boss])

	var tower_boss := _make_boss()
	var far := _make_commander(Vector3(0.0, 0.0, 40.0))
	var tower := _make_structure(Vector3(0.0, 0.0, 6.0))
	_start(tower_boss, far, CHARGE_ROLL)
	guard = 0
	while tower.hits.is_empty() and guard < 1200:
		_step(tower_boss, STEP)
		guard += 1
	assert_true(tower_boss._roll_phase == SkeletalCentipede.RollPhase.END, "The charge roll goes into its end clip the moment it hits a tower")
	_step(tower_boss, 2.0)
	assert_true(tower.hits.size() == 1 and tower.hits[0].amount == d.charge_roll_damage, "A tower in the way takes charge_roll_damage, once")
	_free_all([far, tower, tower_boss])


func test_tc22_dash() -> void:
	print("\n[TC22] Dash")
	var d := BOSS_DATA
	var boss := _make_boss()
	var fortress := _make_structure(Vector3(30.0, 0.0, 0.0), &"fortress")
	var spawn := _make_structure(Vector3(-30.0, 0.0, 0.0), &"boss_spawn_point")
	var cmd := _make_commander(Vector3(0.0, 0.0, d.body(2.0)))
	boss.current_target = cmd
	var situation := boss.build_situation()
	assert_true(is_equal_approx(situation.dash_left_share, 1.0), "The side toward the Fortress is worth 1.0 (%.2f)" % situation.dash_left_share)
	assert_true(absf(situation.dash_right_share - d.dash_spawn_side_share) < 0.01, "The side toward the spawn is worth the spawn share (%.2f)" % situation.dash_right_share)

	var clips: Array[StringName] = []
	boss.move_started.connect(func(_move: StringName, clip: StringName, _dur: float) -> void: clips.append(clip))
	_start(boss, cmd, CentipedeBrain.DASH_LEFT)
	var frames := 0
	while boss._move == DASH and frames < 300:
		boss._update_state(STEP)
		frames += 1
	var travel := d.body(d.dash_distance)
	assert_true(absf(boss.global_position.x - travel) <= travel * 0.05, "A dash to the left moves dash_distance along +X (%.2f of %.2f m)" % [boss.global_position.x, travel])
	assert_true(absf(boss.global_position.z) < 0.001 and absf(boss.rotation.y) < 0.0001, "The dash does not move forward or turn")
	assert_true(absi(frames - int(round(d.dash_time / STEP))) <= 1, "The dash takes dash_time (%d frames)" % frames)
	assert_true(is_equal_approx(boss.dash_buff_left, d.dash_buff_time) and boss.dash_cooldown_left > 0.0 and boss.last_chosen_move == DASH,
			"The dash starts the buff and goes on cooldown")
	assert_true(clips.size() == 1 and clips[0] in [&"dash_left", &"roll_extra/dash_left", SkeletalCentipede.CLIP_WALK],
			"The dash plays its clip, or the walk clip while there is none (%s)" % clips)
	boss.global_position = Vector3.ZERO
	boss.dash_cooldown_left = 0.0
	var wall := _make_solid(Vector3(d.body(d.body_box_size.x * 0.5) + 2.0, 2.0, 0.0), Vector3(0.5, 4.0, 10.0), &"")
	await _settle()
	var walled := boss.build_situation()
	assert_true(is_zero_approx(walled.dash_left_share), "A wall in the dash's path leaves that side no score")
	assert_true(walled.dash_right_share > 0.0, "The other side keeps its score")
	_free_all([cmd, boss, fortress, spawn, wall])


func test_tc23_structures() -> void:
	print("\n[TC23] Structures are always inside the swing's reach")
	for model_scale: float in [3.0, 4.5]:
		for kind: StringName in [&"tower", &"fortress"]:
			await _structure_case(model_scale, kind)


## Three physics frames: the physics server sees the new bodies, and the boss's own navigation
## setup (a deferred call that then waits for a frame) is done before the boss is freed.
func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame


## One boss walks up to a tower or the Fortress on a floor and is stepped for seconds of game time.
func _structure_case(model_scale: float, kind: StringName) -> void:
	var tag := "scale %.1f, %s" % [model_scale, kind]
	var d := _scaled_data(model_scale)
	var nodes: Array = []
	nodes.append(_make_solid(Vector3(0.0, -0.5, 0.0), Vector3(200.0, 1.0, 200.0), &""))
	var target: MockSolid
	if kind == &"tower":
		target = _make_solid(Vector3(-9.0, 1.5, 1.5), Vector3(2.0, 3.0, 2.0), &"tower")
		target.set_meta(&"is_wall", false)
	else:
		target = _make_solid(Vector3(-20.0, 2.0, 0.0), Vector3(5.0, 4.0, 16.0), &"fortress")
		var melee_point := Marker3D.new()
		melee_point.add_to_group(&"boss_melee_point")
		add_child(melee_point)
		melee_point.global_position = Vector3(-15.5, 0.0, 0.0)
		nodes.append(melee_point)
	nodes.append(target)
	# Enemies share a per-frame cache of the towers; no frame passes between cases here.
	Enemy.invalidate_node_cache()
	var boss := _make_boss(d)
	boss.rotation.y = -PI / 2.0
	# The boss steers itself: the avoidance server does not step while this test steps by hand.
	boss.nav.avoidance_enabled = false
	nodes.append(boss)
	await _settle()
	var swings := {"total": 0, "missed": 0}
	boss.move_hit.connect(func(move: StringName, _window: int, targets: Array) -> void:
		if move != SLASH or not boss._structure_move:
			return
		swings["total"] += 1
		if not targets.has(boss.current_target):
			swings["missed"] += 1)
	boss.change_state(Enums.EnemyState.ADVANCE)
	var seconds := 12.0 if kind == &"tower" else 20.0
	var t := 0.0
	while t < seconds:
		boss._process(STEP)
		boss._physics_process(STEP)
		t += STEP
	var needed := 1 if kind == &"tower" else 2
	assert_true(target.hits.size() >= needed, "%s: the boss lands %d or more swings on it in %.0f s (%d)" % [tag, needed, seconds, target.hits.size()])
	assert_true(swings["total"] >= 1 and swings["missed"] == 0, "%s: no swing at the structure falls short (%d of %d missed)" % [tag, swings["missed"], swings["total"]])
	if kind == &"fortress":
		assert_true(boss.global_position.x > -17.4, "%s: the boss does not get into the Fortress (x = %.2f)" % [tag, boss.global_position.x])
	_free_all(nodes)


## A static box that counts the hits it takes; group "" leaves it out of every group.
func _make_solid(pos: Vector3, size: Vector3, group: StringName) -> MockSolid:
	var solid := MockSolid.new()
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	solid.add_child(shape)
	if group != &"":
		solid.add_to_group(group)
	add_child(solid)
	solid.global_position = pos
	return solid


class MockCommander extends Node3D:
	var is_dodging: bool = false
	var is_deploying: bool = false
	var hits: Array[DamageInfo] = []
	var knockback_taken: float = 0.0

	func _init() -> void:
		add_to_group(&"commander")

	func take_damage(info: DamageInfo) -> void:
		hits.append(info)
		knockback_taken = info.knockback_force


## A tower, an enemy unit or anything else that only counts the hits it takes.
class MockStructure extends Node3D:
	var hits: Array[DamageInfo] = []

	func _init(group: StringName) -> void:
		add_to_group(group)

	func take_damage(info: DamageInfo) -> void:
		hits.append(info)


## A static box (a tower, the Fortress or a wall) that counts the hits it takes.
class MockSolid extends StaticBody3D:
	var hits: Array[DamageInfo] = []

	func take_damage(info: DamageInfo) -> void:
		hits.append(info)
