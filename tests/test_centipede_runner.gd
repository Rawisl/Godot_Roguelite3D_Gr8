extends Node3D

## Skeletal Centipede: AI scoring, every move's hit times and shapes, the armor phases, death,
## the HUD hookup and the model scale. The boss's own clocks are stepped by hand (process and
## physics off), so results do not depend on frame timing. Distances are written at model scale 1
## and multiplied by the scale of the data under test.

const BOSS_SCENE: PackedScene = preload("res://entities/enemy/skeletal_centipede.tscn")
const BOSS_DATA: CentipedeBossData = preload("res://data/bosses/skeletal_centipede_boss.tres")
const POOL_SCENE: PackedScene = preload("res://entities/enemy/poison_pool.tscn")
const BOSS_BAR_SCENE: PackedScene = preload("res://ui/hud/parts/boss_bar.tscn")
const FX_LIBRARY: AnimationLibrary = preload("res://art/vfx/centipede_fx_library.tres")
const STEP: float = 1.0 / 60.0
const SLASH: StringName = SkeletalCentipede.MOVE_SLASH
const COMBO: StringName = SkeletalCentipede.MOVE_COMBO
const SPIT: StringName = SkeletalCentipede.MOVE_SPIT
const ROLL: StringName = SkeletalCentipede.MOVE_ROLL

var passes: int = 0
var fails: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("            SKELETAL CENTIPEDE VERIFICATION            ")
	print("=======================================================")

	test_tc1_brain_scores()
	test_tc2_brain_deterministic()
	test_tc3_setup()
	test_tc4_slash()
	test_tc5_combo()
	test_tc6_spit_stream()
	test_tc7_spit_pool()
	test_tc8_roll()
	test_tc9_turn()
	test_tc10_armor_phase()
	test_tc11_enrage()
	test_tc12_immunities()
	test_tc13_death()
	test_tc14_hud_and_fx_anchors()
	test_tc15_chains_stay_survivable()
	test_tc16_default_scale()
	test_tc17_scale_is_proportional()
	test_tc18_particles_follow_scale()

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
	# Keep the roll's start distance clear of the spit's reach at any scale under test.
	scaled.roll_min_distance = 12.0 * model_scale
	return scaled


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
	assert_true(_pick(_situation({"in_slash": true})) == CentipedeBrain.SLASH, "In front inside the slash: SLASH")
	assert_true(_pick(_situation({"in_spit_reach": true, "distance": 3.0})) == CentipedeBrain.SPIT, "In the spit's band, spit ready: SPIT")
	assert_true(_pick(_situation({"in_spit_reach": true, "distance": 3.0, "spit_ready": false})) == CentipedeBrain.CHASE, "Spit cooling down: CHASE")
	assert_true(_pick(_situation({"distance": 11.0})) == CentipedeBrain.ROLL, "Far away, roll unlocked: ROLL")
	assert_true(_pick(_situation({"distance": 11.0, "roll_unlocked": false})) == CentipedeBrain.CHASE, "Far away, roll locked: CHASE")
	assert_true(_pick(_situation({"in_front": false})) == CentipedeBrain.FACE, "Commander at the flank or behind: FACE")
	assert_true(_pick(_situation({"in_front": false, "has_objective": true, "t_away": 4.0})) == CentipedeBrain.PUSH, "Out of reach for 4 s with a structure: PUSH")
	var low_hp := CentipedeBrain.score_all(_situation({"in_slash": true, "hp_fraction": 0.4}), BOSS_DATA)
	assert_true(float(low_hp[CentipedeBrain.COMBO]) > 0.0, "Below half HP the combo scores")
	var full_hp := CentipedeBrain.score_all(_situation({"in_slash": true, "hp_fraction": 0.9}), BOSS_DATA)
	assert_true(is_zero_approx(float(full_hp[CentipedeBrain.COMBO])), "At half HP or more the combo scores nothing")
	var locked := CentipedeBrain.score_all(_situation({"in_slash": true, "hp_fraction": 0.4, "combo_unlocked": false}), BOSS_DATA)
	assert_true(is_zero_approx(float(locked[CentipedeBrain.COMBO])), "Combo locked: no score")

	# The same picks through a real boss, at the model's own scale.
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(0.0, 0.0, BOSS_DATA.body(3.0)))
	boss.current_target = cmd
	boss.provoked_by_player = true
	assert_true(boss.choose_attack() == CentipedeBrain.SPIT, "Boss with the commander 3 body-metres ahead: SPIT")
	cmd.global_position = Vector3(0.0, 0.0, BOSS_DATA.body(1.2))
	assert_true(boss.choose_attack() == CentipedeBrain.SLASH, "Commander inside the slash: SLASH")
	cmd.global_position = Vector3(0.0, 0.0, 9.0)
	assert_true(boss.choose_attack() == CentipedeBrain.ROLL, "Commander 9 m ahead: ROLL")
	assert_true(is_equal_approx(float(boss.last_scores[CentipedeBrain.ROLL]), BOSS_DATA.weight_roll * BOSS_DATA.stickiness),
			"At 9 m, inside the engaged range, the roll scores its full weight")
	boss.spawn_wave = 5
	assert_true(boss.choose_attack() == CentipedeBrain.CHASE, "First appearance has no roll: CHASE")
	cmd.global_position = Vector3(0.0, 0.0, -2.0)
	assert_true(boss.choose_attack() == CentipedeBrain.FACE, "Commander behind: FACE")
	_free_all([cmd, boss])


func test_tc2_brain_deterministic() -> void:
	print("\n[TC2] Brain is deterministic")
	var tie := _situation({"in_slash": true, "hp_fraction": 0.4})
	var picks: Array = []
	for run in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var sequence: Array[StringName] = []
		for i in 50:
			sequence.append(CentipedeBrain.decide(tie, BOSS_DATA, rng.randf))
		picks.append(sequence)
	assert_true(picks[0] == picks[1], "Same seed gives the same 50 picks")
	assert_true(picks[0].has(CentipedeBrain.SLASH) and picks[0].has(CentipedeBrain.COMBO), "A tie rolls both moves")

	var calls := [0]
	var count_roll := func() -> float:
		calls[0] += 1
		return 0.5
	CentipedeBrain.decide(_situation({"in_slash": true}), BOSS_DATA, count_roll)
	assert_true(calls[0] == 0, "A clear choice never calls the roll")
	CentipedeBrain.decide(tie, BOSS_DATA, count_roll)
	assert_true(calls[0] == 1, "A tie calls the roll once")


func test_tc3_setup() -> void:
	print("\n[TC3] Setup")
	var boss := _make_boss()
	assert_true(boss.is_in_group(&"boss"), "Boss is in the boss group")
	assert_true(boss.current_phase == Enums.BossPhase.ARMORED, "Starts armored")
	assert_true(boss.max_armor_hp == BOSS_DATA.armor_hp and boss.max_core_hp == BOSS_DATA.core_hp, "Armor and core come from the data")
	boss.apply_wave_scale(1.5, 1.0, 1.0, 5)
	assert_true(boss.max_armor_hp == int(round(BOSS_DATA.armor_hp * 1.5)), "Armor follows the wave HP multiplier")
	var player := boss.anim_player
	assert_true(player != null and player.has_animation(SkeletalCentipede.CLIP_ROAR), "The roar clip is loaded")
	assert_true(player.has_animation(SkeletalCentipede.CLIP_IDLE), "The resting pose clip is built")
	var turn := player.get_animation(SkeletalCentipede.CLIP_TURN_LEFT)
	assert_true(turn != null and turn.find_track(SkeletalCentipede.RIG_ROOT_TRACK, Animation.TYPE_ROTATION_3D) == -1,
			"The runtime turn clip has no root rotation")
	var source := player.get_animation(&"turn_left_90")
	assert_true(source.find_track(SkeletalCentipede.RIG_ROOT_TRACK, Animation.TYPE_ROTATION_3D) >= 0, "The model's own turn clip keeps its root rotation")
	var table: PackedFloat32Array = boss._turn_tables[&"turn_left_90"]
	assert_true(absf(rad_to_deg(table[table.size() - 1]) - 90.0) < 1.0, "Left turn samples to +90 degrees of yaw")
	table = boss._turn_tables[&"turn_180"]
	assert_true(absf(rad_to_deg(table[table.size() - 1]) - 180.0) < 1.0, "Half turn samples to 180 degrees of yaw")
	_free_all([boss])


func test_tc4_slash() -> void:
	print("\n[TC4] Slash")
	var d := BOSS_DATA
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(0.0, 0.0, d.body(1.2)))
	var clips: Array[StringName] = []
	boss.move_started.connect(func(_move: StringName, clip: StringName, _dur: float) -> void: clips.append(clip))
	boss.current_target = cmd
	boss.change_state(Enums.EnemyState.ATTACK)
	assert_true(boss.last_chosen_move == SLASH, "AI picks the slash for a commander 1.2 ahead")
	_step(boss, 0.57)
	assert_true(cmd.hits.is_empty(), "No damage before the swing's window opens at 0.6 s")
	_step(boss, 0.4)
	assert_true(cmd.hits.size() == 1, "One hit once the window has opened")
	_step(boss, 0.25)
	assert_true(cmd.hits.size() == 1, "No second hit after the window")
	assert_true(clips == [SkeletalCentipede.CLIP_SLASH_3], "Dead ahead plays the heavy third swing")
	assert_true(cmd.hits[0].amount == d.la3_damage and cmd.hits[0].damage_type == Enums.DamageType.SLASH, "Heavy swing deals la3_damage SLASH")
	assert_true(is_equal_approx(cmd.hits[0].knockback_force, d.la3_knockback), "Heavy swing knocks the commander back")
	_free_all([cmd, boss])

	for case in [["right", -d.body(0.8), SkeletalCentipede.CLIP_SLASH_1], ["left", d.body(0.8), SkeletalCentipede.CLIP_SLASH_2]]:
		var side_boss := _make_boss()
		var side_cmd := _make_commander(Vector3(case[1], 0.0, d.body(1.2)))
		var side_clips: Array[StringName] = []
		side_boss.move_started.connect(func(_move: StringName, clip: StringName, _dur: float) -> void: side_clips.append(clip))
		_start(side_boss, side_cmd, SLASH)
		_step(side_boss, 1.0)
		assert_true(side_clips == [case[2]], "Commander on the %s plays %s" % [case[0], case[2]])
		assert_true(side_cmd.hits.size() == 1 and side_cmd.hits[0].amount == d.la_damage, "Light swing deals la_damage")
		assert_true(is_zero_approx(side_cmd.hits[0].knockback_force), "Light swing has no knockback")
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
	_step(boss, 5.3)
	var total := 0
	for info in cmd.hits:
		total += info.amount
	var expected := 10 * d.combo_hit_damage + d.combo_finisher_damage
	assert_true(windows_hit[0] == 11 and cmd.hits.size() == 11, "All eleven windows hit the commander once")
	assert_true(total == expected, "Hits add up to ten light hits and the finisher (%d)" % expected)
	assert_true(cmd.hits[10].amount == d.combo_finisher_damage and cmd.hits[10].knockback_force > 0.0, "The last hit is the finisher with knockback")
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
	while boss._move == SPIT and t < 6.0:
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
	assert_true(t > 4.0 and t < 4.5, "The move lasts the clip plus the held stream (%.2f s)" % t)
	assert_true(boss.spit_cooldown_left > 0.0, "Spit went on cooldown")
	for pool in _pools():
		pool.free()
	cmd.free()

	var outside := _make_commander(Vector3(5.0, 0.0, 1.0))
	_start(boss, outside, SPIT)
	outside.global_position = boss.get_spit_apex() + Vector3(d.body(3.0), 0.0, d.body(1.0))
	_step(boss, 4.5)
	assert_true(outside.hits.is_empty(), "A commander outside the cone takes nothing")
	_free_all([outside, boss])


func test_tc7_spit_pool() -> void:
	print("\n[TC7] Spit pool")
	var d := BOSS_DATA
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(40.0, 0.0, 40.0))
	_start(boss, cmd, SPIT)
	_step(boss, d.pool_spawn_time - 0.1)
	assert_true(_pools().is_empty(), "No pool before its spawn time")
	_step(boss, 0.2)
	var origin := boss.to_global(d.body_v3(d.pool_offset))
	var spit_yaw := boss.rotation.y
	var pools := _pools()
	assert_true(pools.size() == 1, "One pool is spawned at its spawn time")
	_step(boss, 4.0)
	assert_true(_pools().size() == 1, "Still only one pool after the spit")
	var pool := pools[0]
	pool.set_physics_process(false)
	assert_true(pool.global_position.distance_to(origin) < 0.01, "The pool starts at the boss's pool offset")
	assert_true(absf(pool.rotation.y - spit_yaw) < 0.001, "The pool faces where the boss faced")

	var inside := _make_commander(origin + Vector3(0.0, 0.0, d.body(2.5)))
	for i in 63:
		pool._physics_process(STEP)
	assert_true(inside.hits.size() == 2, "A commander in the pool takes a tick every 0.5 s (%d in 1.05 s)" % inside.hits.size())
	assert_true(inside.hits[0].is_dot and inside.hits[0].damage_type == Enums.DamageType.MAGIC, "Pool ticks are MAGIC damage over time")
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
	assert_true(absf(speed - d.body(d.roll_speed)) < d.body(d.roll_speed) * 0.1, "Loop speed is roll_speed (%.2f m/s)" % speed)
	var guard := 0
	while boss._move == ROLL and guard < 1200:
		_step(boss, STEP)
		guard += 1
	assert_true(cmd.hits.size() == 1, "The roll hits the commander once")
	assert_true(cmd.hits[0].amount == d.roll_damage and cmd.hits[0].damage_type == Enums.DamageType.BLAST, "Roll damage is roll_damage BLAST")
	assert_true(cmd.hits[0].knockback_force > 0.0, "The roll throws the commander back")
	assert_true(boss.global_position.length() <= d.roll_max_distance + 0.5, "The roll stops within its maximum distance (%.2f m)" % boss.global_position.length())
	assert_true(boss.roll_cooldown_left > 0.0, "Roll went on cooldown")
	_free_all([cmd, boss])

	var tower_boss := _make_boss()
	var far := _make_commander(Vector3(0.0, 0.0, 40.0))
	var tower := _make_structure(Vector3(0.0, 0.0, 6.0))
	_start(tower_boss, far, ROLL)
	guard = 0
	while tower.hits.is_empty() and guard < 1200:
		_step(tower_boss, STEP)
		guard += 1
	assert_true(tower.hits.size() == 1 and tower.hits[0].amount == d.roll_damage, "A tower in the way takes roll_damage")
	assert_true(tower_boss._roll_phase == SkeletalCentipede.RollPhase.END, "The roll goes into its end clip the moment it hits a tower")
	_step(tower_boss, 2.0)
	assert_true(tower.hits.size() == 1, "The tower is hit only once")
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
	_step(boss, 2.0)
	assert_true(particles.emitting, "The stream's particles run while it spits")
	var mesh := boss.find_child("SkeletalCentipede_Mesh", true, false) as MeshInstance3D
	mesh.set_blend_shape_value(0, 0.7)
	assert_true(is_zero_approx(boss.get_resist(Enums.DamageType.PIERCE)) and is_zero_approx(boss.get_resist(Enums.DamageType.TRAP)),
			"Armored: PIERCE and TRAP do nothing")
	assert_true(boss.take_damage(DamageInfo.new(100, Enums.DamageType.PIERCE)) == 0, "A PIERCE hit deals nothing to armor")
	boss.take_damage(DamageInfo.new(boss.current_armor_hp, Enums.DamageType.TRUE))
	assert_true(boss.current_phase == Enums.BossPhase.TRANSITION, "Breaking the armor starts the transition")
	assert_true(boss._move == &"" and not particles.emitting, "The running move stops and the stream goes out")
	assert_true(is_zero_approx(mesh.get_blend_shape_value(0)), "The ribs are closed again")
	assert_true(is_equal_approx(boss.get_resist(Enums.DamageType.SLASH), 1.5), "Transition resist is 1.5")
	var t := 0.0
	while boss.current_phase == Enums.BossPhase.TRANSITION and t < d.transition_duration + 1.0:
		boss._physics_process(STEP)
		t += STEP
	assert_true(boss.current_phase == Enums.BossPhase.EXPOSED, "The transition ends in the exposed phase")
	assert_true(is_equal_approx(boss.speed_multiplier, d.phase2_speed_mult), "Exposed speeds the boss up")
	assert_true(is_equal_approx(boss.get_resist(Enums.DamageType.SLASH), 1.25), "Exposed resist is 1.25")
	_free_all([cmd, boss])

	var combo_boss := _make_boss()
	var front := _make_commander(Vector3(0.0, 0.0, d.body(1.2)))
	_start(combo_boss, front, COMBO)
	_step(combo_boss, 0.5)
	var hits_before := front.hits.size()
	assert_true(hits_before > 0, "The combo has started hitting")
	combo_boss.take_damage(DamageInfo.new(combo_boss.current_armor_hp, Enums.DamageType.TRUE))
	_step(combo_boss, 2.0)
	assert_true(front.hits.size() == hits_before, "No more hits come out of the stopped combo")
	_free_all([front, combo_boss])


func test_tc11_enrage() -> void:
	print("\n[TC11] Enrage")
	var boss := _make_boss()
	var interval := boss._get_attack_interval()
	EventBus.boss_enraged.emit()
	assert_true(boss.is_enraged, "boss_enraged enrages the boss")
	assert_true(is_equal_approx(boss.speed_multiplier, GameConfig.enrage_speed_mult), "Enrage speeds the boss up")
	assert_true(boss._scale_attack_damage(BOSS_DATA.la_damage) == int(round(BOSS_DATA.la_damage * GameConfig.enrage_damage_mult)), "Slash damage is 1.5x")
	assert_true(boss._get_attack_interval() < interval, "The attack interval shortens")
	_free_all([boss])


func test_tc12_immunities() -> void:
	print("\n[TC12] Immunities")
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(2.0, 0.0, 0.0))
	boss.change_state(Enums.EnemyState.ADVANCE)
	boss.apply_knockback(Vector3(1.0, 0.0, 0.0))
	assert_true(boss.current_state == Enums.EnemyState.ADVANCE, "Knockback does not move the boss")
	boss.apply_commander_taunt(cmd, 5.0)
	assert_true(not boss.taunted_by_player and boss.current_target != cmd, "A taunt does not lock the boss's target")
	assert_true(not boss.can_be_recycled() and not boss.can_be_culled(), "The stuck ladder never sends the boss back or removes it")
	_free_all([cmd, boss])


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
	assert_true(boss.is_dead and defeated[0] == 1, "The boss dies and announces its defeat once")
	assert_true(seen["hp"] == [0, 0], "The boss bar is sent zero HP")
	boss._process(0.0)
	var t := 0.0
	while t < BOSS_DATA.death_duration + 0.1:
		boss._process(STEP)
		t += STEP
	assert_true(boss.is_queued_for_deletion(), "The boss is removed after the death time")
	assert_true(model.position.y <= -BOSS_DATA.body(BOSS_DATA.death_sink_depth) + 0.01, "The model has sunk into the floor")
	assert_true(defeated[0] == 1, "Defeat is announced only once")
	boss.free()

	var room_boss := _make_boss()
	room_boss.in_hazard_trial = true
	room_boss.current_phase = Enums.BossPhase.EXPOSED
	room_boss.take_damage(DamageInfo.new(room_boss.current_core_hp, Enums.DamageType.TRUE))
	assert_true(room_boss.is_dead and defeated[0] == 1, "The Hazard Trial copy does not announce a boss defeat")
	EventBus.boss_defeated.disconnect(on_defeated)
	EventBus.boss_hp_changed.disconnect(on_hp)
	room_boss.free()


func test_tc14_hud_and_fx_anchors() -> void:
	print("\n[TC14] HUD and effect anchors")
	var bar := BOSS_BAR_SCENE.instantiate()
	var found := BossInfo.find(bar.bosses, &"skeletal_centipede")
	assert_true(found != null and found.id == &"skeletal_centipede" and found.resource_path == BOSS_DATA.resource_path,
			"The boss bar lists the centipede")
	var text := BossInfo.immune_text(found, Enums.BossPhase.ARMORED)
	assert_true(text.contains(TranslationServer.translate(&"damage.pierce")) and text.contains(TranslationServer.translate(&"damage.trap")),
			"The armored phase names PIERCE and TRAP as immune (%s)" % text)
	assert_true(not text.contains(TranslationServer.translate(&"damage.magic")), "MAGIC is not listed as immune")
	bar.free()

	var boss := _make_boss()
	var anchors := boss.get_fx_anchors()
	var skeleton := boss.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_true(skeleton.find_bone(anchors["core_bone"]) >= 0, "The core bone exists in the skeleton")
	var vents_ok := true
	for bone: StringName in anchors["vent_bones"]:
		vents_ok = vents_ok and skeleton.find_bone(bone) >= 0
	assert_true(vents_ok and not (anchors["vent_bones"] as Array).is_empty(), "Every vent bone exists in the skeleton")
	assert_true((anchors["core_fallback"] as Vector3).is_equal_approx(BOSS_DATA.body_v3(BOSS_DATA.fx_core_fallback)), "Fallback anchors follow the model scale")
	_free_all([boss])


func test_tc15_chains_stay_survivable() -> void:
	print("\n[TC15] Chains stay survivable at wave 5")
	var boss := _make_boss()
	boss.apply_wave_scale(1.0, Enemy.DEFAULT_SCALE_CONFIG.get_dmg_mult(5), 1.0, 5)
	var d := BOSS_DATA
	var cmd := _make_commander(Vector3(0.0, 0.0, d.body(1.2)))
	_start(boss, cmd, COMBO)
	_step(boss, 5.3)
	var combo_total := _damage_sum(cmd)
	print("  combo total: %d" % combo_total)
	assert_true(combo_total > 0 and combo_total < 100, "The whole combo stays under 100")

	cmd.hits.clear()
	_start(boss, cmd, SPIT)
	cmd.global_position = boss.get_spit_apex() + Vector3(0.0, 0.0, d.body(2.5))
	_step(boss, 4.5)
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
	_free_all([cmd, boss])


func _damage_sum(cmd: MockCommander) -> int:
	var total := 0
	for info in cmd.hits:
		total += info.amount
	return total


func test_tc16_default_scale() -> void:
	print("\n[TC16] Default scale")
	var d := BOSS_DATA
	assert_true(is_equal_approx(d.model_scale, 1.6), "The data's model scale is 1.6")
	var a := _make_boss()
	var b := _make_boss()
	var model := a.get_node("Model") as Node3D
	assert_true(model.scale.is_equal_approx(Vector3.ONE * 1.6), "The model is scaled 1.6")
	var body_shape := a.get_node("CollisionShape3D") as CollisionShape3D
	assert_true((body_shape.shape as BoxShape3D).size.is_equal_approx(d.body_box_size * 1.6), "The body box is the data's box times the scale")
	var hurt_shape := a.get_node("HurtBox/CollisionShape3D") as CollisionShape3D
	assert_true((hurt_shape.shape as BoxShape3D).size.is_equal_approx(d.body_box_size * 1.6), "The hurt box is scaled too")
	var other_shape := b.get_node("CollisionShape3D") as CollisionShape3D
	assert_true(body_shape.shape != other_shape.shape, "Two bosses do not share a shape")
	assert_true(a.nav.radius >= 1.6, "The agent radius stays at least 1.6")
	assert_true(is_equal_approx(a.get_attack_range(), 1.4 * 1.6) and is_equal_approx(a.nav.target_desired_distance, 1.4 * 1.6),
			"The attack range is scaled")
	_free_all([a, b])


func test_tc17_scale_is_proportional() -> void:
	print("\n[TC17] Scale is proportional")
	var roll_speeds: Array[float] = []
	var combo_steps: Array[float] = []
	var walk_speeds: Array[float] = []
	for model_scale: float in [1.0, 2.0]:
		var d := _scaled_data(model_scale)
		var tag := "scale %.0f" % model_scale
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
		_free_all([far, roller])

		var stepper := _make_boss(d)
		var behind := _make_commander(Vector3(0.0, 0.0, -50.0))
		_start(stepper, behind, COMBO)
		_step(stepper, 5.3)
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
	assert_true(absf(roll_speeds[1] / roll_speeds[0] - 2.0) < 0.1, "Roll speed doubles with the scale (%.2f to %.2f)" % [roll_speeds[0], roll_speeds[1]])
	assert_true(absf(combo_steps[1] / combo_steps[0] - 2.0) < 0.1, "The combo's advance doubles with the scale (%.2f to %.2f)" % [combo_steps[0], combo_steps[1]])
	assert_true(absf(walk_speeds[1] / walk_speeds[0] - 0.5) < 0.025, "At the same ground speed the walk clip plays half as fast at double scale")


func test_tc18_particles_follow_scale() -> void:
	print("\n[TC18] Particles follow scale")
	var one := _make_boss(_scaled_data(1.0))
	var two := _make_boss(_scaled_data(2.0))
	var core_one := one.get_node("Model/CentipedeFx/Head/SpitEmitter/Core") as CPUParticles3D
	var core_two := two.get_node("Model/CentipedeFx/Head/SpitEmitter/Core") as CPUParticles3D
	assert_true(core_two.gravity.is_equal_approx(core_one.gravity * 2.0), "Spit gravity doubles with the scale")
	var fx_two := two.get_node("Model/CentipedeFx") as CentipedeFx
	fx_two.apply_scale(2.0)
	assert_true(core_two.gravity.is_equal_approx(core_one.gravity * 2.0), "Applying the scale again does not compound")
	# The cloud's size cannot be captured headless; the effect runner covers the particle physics.
	_free_all([one, two])


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
