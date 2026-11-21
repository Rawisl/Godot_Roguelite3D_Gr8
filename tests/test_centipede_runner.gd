extends Node3D

## Skeletal Centipede: AI scoring, every move's hit times and shapes, the armor phases, death,
## chain survivability and the model scale. The boss's own clocks are stepped by hand (process and
## physics off), so results do not depend on frame timing. Distances are written at model scale 1
## and multiplied by the scale of the data under test. The structure case runs the boss's physics
## by hand against real colliders. Spit and Combo open with the roar, so their times add its length.

const BOSS_SCENE: PackedScene = preload("res://entities/enemy/skeletal_centipede.tscn")
const BOSS_DATA: CentipedeBossData = preload("res://data/bosses/skeletal_centipede_boss.tres")
const POOL_SCENE: PackedScene = preload("res://entities/enemy/poison_pool.tscn")
const COMMANDER_SCENE: PackedScene = preload("res://entities/commander/commander.tscn")
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

	# The cases that wait for physics frames run first: a boss freed before its own navigation
	# setup has run makes the engine log an error, and the cases below free hundreds of them.
	test_chase_fortress_share()
	await test_tc22_dash()
	await test_dash_air_turn()
	await test_tc23_structures()
	await test_tc7_spit_pool()
	await test_tc24_commander_sword()
	test_tc1_brain_scores()
	test_tc4_slash()
	test_la3_cooldown()
	test_tc5_combo()
	test_combo_steps()
	test_combo_step_turn()
	test_combo_step_side_target()
	test_combo_cancel()
	test_tc6_spit_stream()
	test_tc8_roll()
	test_roll_speed_lines_intensity()
	test_tc9_turn()
	test_turn_in_place_plays_walk()
	test_tc10_armor_phase()
	test_tc13_death()
	test_tc15_chains_stay_survivable()
	test_tc16_default_scale()
	test_tc17_scale_is_proportional()
	test_tc19_brain_v2()
	test_tc19b_dash_scores()
	test_tc20_roar_lead_in()
	test_tc21_charge_roll()
	test_tc26_shared_roll_cooldown()
	test_tc25_turn_pressure()
	test_eye_glow_in_roar()

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
	assert_true(is_equal_approx(float(close[CentipedeBrain.CHARGE_ROLL]), d.weight_charge_roll * d.stickiness), "Inside the slash the charge roll still scores its full weight")
	var near_roll := CentipedeBrain.score_all(_situation({"in_slash": true, "in_front": false, "distance": d.body(1.0), "roll_ready": true}), d)
	assert_true(is_equal_approx(float(near_roll[CentipedeBrain.ROLL]), d.weight_roll * d.stickiness), "The roll scores its full weight for a commander near, behind and inside the slash")
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
	boss.roll_cooldown_left = 99.0
	assert_true(boss.choose_attack() == CentipedeBrain.SPIT, "Boss with the commander 3 body-metres ahead: SPIT")
	# The combo and the dash are put on cooldown so the pick is a clear one.
	boss.combo_cooldown_left = 99.0
	boss.dash_cooldown_left = 99.0
	cmd.global_position = Vector3(0.0, 0.0, BOSS_DATA.body(1.2))
	assert_true(boss.choose_attack() == CentipedeBrain.SLASH, "Commander inside the slash: SLASH")
	boss.roll_cooldown_left = 0.0
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
	_run_combo(boss)
	var total := 0
	for info in cmd.hits:
		total += info.amount
	var expected := 10 * d.combo_hit_damage + d.combo_finisher_damage
	assert_true(windows_hit[0] == 11 and cmd.hits.size() == 11, "All eleven windows hit the commander once")
	assert_true(total == expected and cmd.hits[10].amount == d.combo_finisher_damage and cmd.hits[10].knockback_force > 0.0,
			"Hits add up to ten light hits and the finisher (%d), the last one with knockback" % expected)
	var advanced := boss.global_position.z
	var final_gap := boss._flat_gap(cmd, boss.global_position)
	assert_true(advanced > 0.0 and final_gap >= d.body(d.combo_step_stop_gap) - STEP * d.body(d.combo_move_speed),
			"Boss steps toward the commander and stops at the step gap (moved %.2f m, gap %.2f m)" % [advanced, final_gap])
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


# --- Combo steps and cancel --------------------------------------------------------------------

## Data copy with the combo cancel switched off, so a far commander does not end the combo.
func _no_cancel_data() -> CentipedeBossData:
	var no_cancel := BOSS_DATA.duplicate() as CentipedeBossData
	no_cancel.combo_cancel_distance = 1000.0
	return no_cancel


func _vfx_player(boss: SkeletalCentipede) -> AnimationPlayer:
	return boss._fx.get_node("VfxPlayer") as AnimationPlayer


## Runs the boss until its move is over (the combo's length depends on how far it has to step).
func _run_combo(boss: SkeletalCentipede) -> void:
	for frame in 2400:
		if boss._move == &"":
			return
		_step(boss, STEP)


## Runs the boss frame by frame until a combo step is under way. Returns false when none began.
func _run_to_step(boss: SkeletalCentipede) -> bool:
	for frame in 1200:
		if boss._combo_step_index >= 0:
			return true
		_step(boss, STEP)
	return false


func test_combo_steps() -> void:
	print("\n[Combo steps] The clip stops for a longer walk")
	var d := _no_cancel_data()
	var spans := d.combo_move_windows
	var overlap := false
	for span in spans:
		for window in d.combo_hit_windows:
			if span.x < window.y and window.x < span.y:
				overlap = true
	assert_true(not overlap, "No step span overlaps a hit window")

	var boss := _make_boss(d)
	var cmd := _make_commander(Vector3(0.0, 0.0, d.body(50.0)))
	var vfx := _vfx_player(boss)
	var speed := boss._combo_speed()
	var announced := [0.0]
	boss.move_started.connect(func(move: StringName, _clip: StringName, duration: float) -> void:
		if move == COMBO:
			announced[0] = duration)
	_start(boss, cmd, COMBO)
	var planned := boss._combo_planned_length()
	assert_true(is_equal_approx(announced[0], (_roar(boss) + planned) / speed),
			"The combo is announced as the roar plus the clip with its steps (%.2f s)" % announced[0])
	assert_true(is_equal_approx(planned, boss._clip_length(SkeletalCentipede.CLIP_COMBO) - 1.0 + spans.size() * d.combo_step_time),
			"The planned length swaps each skipped span for a step (%.2f clip s)" % planned)

	var frames: Array[int] = [0, 0, 0]
	var clock_held := true
	var walking := true
	var trail_held := true
	var trail_pos: Array[float] = [0.0, 0.0, 0.0]
	var resumed_ok := 0
	var last_index := -1
	for frame in 2400:
		_step(boss, STEP)
		var index := boss._combo_step_index
		if index >= 0:
			frames[index] += 1
			clock_held = clock_held and boss._move_time == spans[index].x
			walking = walking and boss.anim_player.current_animation == SkeletalCentipede.CLIP_WALK
			if frames[index] == 1:
				trail_pos[index] = vfx.current_animation_position
			else:
				trail_held = trail_held and is_equal_approx(vfx.current_animation_position, trail_pos[index])
		elif last_index >= 0:
			var resume_at := spans[last_index].y
			if boss.anim_player.current_animation == SkeletalCentipede.CLIP_COMBO \
					and absf(boss.anim_player.current_animation_position - resume_at) <= 2.0 * STEP * speed \
					and vfx.is_playing() and absf(vfx.current_animation_position - resume_at) <= 2.0 * STEP * speed:
				resumed_ok += 1
		last_index = index
		if boss._move == &"":
			break
	var long_enough := true
	for count in frames:
		long_enough = long_enough and absf(float(count) * STEP - d.combo_step_time / speed) <= 2.0 * STEP
	assert_true(clock_held and walking, "The move clock stands still and the walk plays during every step")
	assert_true(long_enough, "Each step lasts combo_step_time (%s frames)" % [frames])
	assert_true(trail_held, "The trail clip stands still during a step")
	assert_true(resumed_ok == spans.size(), "The combo clip and the trail go on from the span's end after each step (%d of %d)" % [resumed_ok, spans.size()])
	var travelled := boss.global_position.z
	var wanted := spans.size() * d.body(d.combo_move_speed) * d.combo_step_time
	assert_true(absf(travelled - wanted) <= wanted * 0.05 and travelled > d.body(0.6),
			"The steps add up to %.2f m, longer than the old advance (%.2f m)" % [travelled, d.body(0.6)])
	_free_all([cmd, boss])

	# A commander close ahead ends the first step early, at the step gap.
	var near_boss := _make_boss()
	var near := _make_commander(Vector3(0.0, 0.0, d.body(1.3)))
	var offset := near_boss._flat_gap(near, near_boss.global_position) - d.body(1.3)
	near.global_position.z = d.body(1.3) - offset
	var moves: Array[StringName] = []
	near_boss.move_started.connect(func(move: StringName, _clip: StringName, _duration: float) -> void: moves.append(move))
	_start(near_boss, near, COMBO)
	assert_true(_run_to_step(near_boss), "A combo with the commander near still takes its first step")
	var near_frames := 0
	while near_boss._combo_step_index == 0 and near_frames < 600:
		_step(near_boss, STEP)
		near_frames += 1
	var near_gap := near_boss._flat_gap(near, near_boss.global_position)
	assert_true(float(near_frames) * STEP < d.combo_step_time / near_boss._combo_speed() - 2.0 * STEP
			and near_gap >= d.body(d.combo_step_stop_gap) - STEP * d.body(d.combo_move_speed),
			"The step ends early at the step gap (%d frames, gap %.2f m)" % [near_frames, near_gap])
	_run_combo(near_boss)
	assert_true(not moves.has(SkeletalCentipede.MOVE_COMBO_CANCEL) and near_boss._move == &"",
			"A commander inside the cancel distance never cancels the combo")
	_free_all([near, near_boss])

	# Stopping the sequence in the middle of a step clears it.
	var stopped := _make_boss(d)
	var far := _make_commander(Vector3(0.0, 0.0, d.body(50.0)))
	_start(stopped, far, COMBO)
	assert_true(_run_to_step(stopped), "The combo reaches a step")
	stopped.stop_attack_sequence()
	assert_true(stopped._combo_step_left == 0.0 and stopped._combo_step_index == -1 and stopped._move == &""
			and stopped.anim_player.current_animation == SkeletalCentipede.CLIP_IDLE,
			"stop_attack_sequence in a step clears it and shows the resting pose")
	_free_all([far, stopped])


func test_combo_step_turn() -> void:
	print("\n[Combo steps] Turning while stepping")
	var d := _no_cancel_data()
	var boss := _make_boss(d)
	var cmd := _make_commander(Vector3(d.body(2.4), 0.0, 0.0))
	var speed := boss._combo_speed()
	var max_turn := deg_to_rad(d.combo_step_turn_rate_deg) * STEP * speed + 0.0001
	_start(boss, cmd, COMBO)
	var turn_ok := true
	var heading_ok := true
	var still_ok := true
	var turned := 0.0
	var was_stepping := false
	for frame in 2400:
		var yaw_before := boss.rotation.y
		var position_before := boss.global_position
		var stepping_before := boss._combo_step_index >= 0
		_step(boss, STEP)
		if stepping_before:
			var yaw_change := angle_difference(yaw_before, boss.rotation.y)
			turn_ok = turn_ok and absf(yaw_change) <= max_turn
			turned += yaw_change
			var motion := boss.global_position - position_before
			if motion.length() > 0.0001:
				heading_ok = heading_ok and motion.normalized().dot(boss._combo_forward()) > 0.99
		elif not was_stepping and boss._move == COMBO:
			still_ok = still_ok and is_equal_approx(boss.rotation.y, yaw_before)
		was_stepping = stepping_before
		if boss._move == &"":
			break
	assert_true(turned > deg_to_rad(20.0), "A commander at the side pulls the face round during the steps (%.0f degrees)" % rad_to_deg(turned))
	assert_true(turn_ok, "Each tick turns no more than the step turn rate")
	assert_true(heading_ok, "Each tick walks the way the body faces after the turn")
	assert_true(still_ok, "The body does not turn between steps")
	_free_all([cmd, boss])


func test_combo_step_side_target() -> void:
	print("\n[Combo steps] A commander right beside the boss")
	var d := _no_cancel_data()
	for side in [1.0, -1.0]:
		var boss := _make_boss(d)
		var cmd := _make_commander(Vector3(side * d.body(0.4), 0.0, 0.0))
		_start(boss, cmd, COMBO)
		assert_true(_run_to_step(boss), "A combo with the commander beside it reaches a step")
		var close := boss._flat_gap(cmd, boss.global_position) <= d.body(d.combo_step_stop_gap)
		var start_pos := boss.global_position
		var frames := 0
		while boss._combo_step_index == 0 and frames < 600:
			_step(boss, STEP)
			frames += 1
		var yaw_left := absf(boss._yaw_to_point(boss._aim_point(cmd)))
		var moved := boss.global_position.distance_to(start_pos)
		assert_true(close, "The commander starts inside the step gap")
		assert_true(yaw_left <= deg_to_rad(d.combo_step_face_tolerance_deg) + 0.0001,
				"The step turns the face to a commander beside it (%.0f degrees left)" % rad_to_deg(yaw_left))
		assert_true(moved <= d.body(0.05), "The boss turns in place without walking on (%.3f m)" % moved)
		_free_all([cmd, boss])


func test_combo_cancel() -> void:
	print("\n[Combo cancel] A far commander cancels the combo outside the hit windows")
	var d := BOSS_DATA
	var far_z := d.body(d.combo_cancel_distance + 8.0)

	# In the middle of a step.
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(0.0, 0.0, d.body(1.3)))
	var moves: Array[StringName] = []
	var reported := [0]
	boss.move_started.connect(func(move: StringName, _clip: StringName, _duration: float) -> void: moves.append(move))
	boss.move_hit.connect(func(_move: StringName, _window: int, _targets: Array) -> void: reported[0] += 1)
	var elapsed := 0
	_start(boss, cmd, COMBO)
	var guard := 0
	while boss._combo_step_index < 0 and guard < 1200:
		_step(boss, STEP)
		elapsed += 1
		guard += 1
	var hits_before := cmd.hits.size()
	var reported_before: int = reported[0]
	cmd.global_position.z = far_z
	_step(boss, STEP)
	elapsed += 1
	assert_true(boss._move == SkeletalCentipede.MOVE_COMBO_CANCEL and moves.has(SkeletalCentipede.MOVE_COMBO_CANCEL),
			"A commander past the cancel distance cancels the combo during a step")
	var vfx := _vfx_player(boss)
	var trail := boss._fx.get_node("SlashCombo/VFX_SlashCombo_01") as GeometryInstance3D
	assert_true(boss._windows.is_empty() and reported[0] == reported_before and not vfx.is_playing()
			and is_zero_approx(trail.get_instance_shader_parameter(&"progress") as float)
			and is_zero_approx(trail.get_instance_shader_parameter(&"opacity") as float),
			"The cancel drops the unfinished windows without a report and clears the trails")
	assert_true(boss._combo_step_left == 0.0 and boss._combo_step_index == -1, "The cancel ends the step")
	cmd.global_position.z = d.body(1.3)
	var finished_frames := 0
	while boss._move == SkeletalCentipede.MOVE_COMBO_CANCEL and finished_frames < 600:
		_step(boss, STEP)
		elapsed += 1
		finished_frames += 1
	var speed := boss._combo_speed()
	assert_true(absf(float(finished_frames) * STEP - d.combo_cancel_time / speed) <= 2.0 * STEP,
			"The pull-back lasts combo_cancel_time (%d frames)" % finished_frames)
	assert_true(boss._move == &"" and absf(boss._recovery_left - d.combo_cancel_recovery / speed) <= STEP + 0.0001,
			"The rest after a cancel is the short one (%.3f s)" % boss._recovery_left)
	assert_true(absf(boss.combo_cooldown_left - (d.combo_cooldown - float(elapsed) * STEP)) <= 2.0 * STEP and boss.last_chosen_move == COMBO,
			"The combo's cooldown keeps counting from its start (%.2f s left)" % boss.combo_cooldown_left)
	_step(boss, 0.5)
	assert_true(boss._move != &"" or boss.current_state != Enums.EnemyState.ATTACK, "The boss picks its next action after the rest")
	assert_true(cmd.hits.size() == hits_before, "No hit comes out after the cancel, even with the commander back in reach")
	_free_all([cmd, boss])

	# Never in the middle of a swing: the cancel waits for the open window to end.
	var swing_boss := _make_boss()
	var target := _make_commander(Vector3(0.0, 0.0, d.body(1.3)))
	var window := d.combo_hit_windows[0]
	var closed := [0]
	swing_boss.move_hit.connect(func(_move: StringName, _window: int, _targets: Array) -> void: closed[0] += 1)
	_start(swing_boss, target, COMBO)
	guard = 0
	while swing_boss._move_time < (window.x + window.y) * 0.5 and guard < 1200:
		_step(swing_boss, STEP)
		guard += 1
	target.global_position.z = far_z
	_step(swing_boss, STEP)
	assert_true(swing_boss._move == COMBO, "The cancel waits while a hit window is open")
	guard = 0
	var time_at_cancel := 0.0
	while swing_boss._move == COMBO and guard < 600:
		time_at_cancel = swing_boss._move_time
		_step(swing_boss, STEP)
		guard += 1
	assert_true(swing_boss._move == SkeletalCentipede.MOVE_COMBO_CANCEL and time_at_cancel > window.y
			and time_at_cancel - window.y <= 2.0 * STEP * swing_boss._combo_speed() and closed[0] == 1,
			"The cancel comes right after the window ends, which still reported once (clock %.3f, window end %.3f)" % [time_at_cancel, window.y])
	_free_all([target, swing_boss])

	# During the roar, before the clip has begun.
	var roar_boss := _make_boss()
	var roar_target := _make_commander(Vector3(0.0, 0.0, d.body(1.3)))
	_start(roar_boss, roar_target, COMBO)
	roar_target.global_position.z = far_z
	_step(roar_boss, STEP)
	_step(roar_boss, roar_boss._combo_planned_length())
	assert_true(roar_target.hits.is_empty() and roar_boss._move_time == 0.0 and roar_boss._move != COMBO,
			"A commander far away at the start cancels in the roar, with no hit")
	_free_all([roar_target, roar_boss])


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

	# The stream reaches the far edge of the pool and not beyond.
	var reach_boss := _make_boss()
	var reach_target := _make_commander(Vector3(0.0, 0.0, 60.0))
	_start(reach_boss, reach_target, SPIT)
	var reach_apex := reach_boss.get_spit_apex()
	var to_pool := reach_boss.to_global(d.body_v3(d.pool_center)) - reach_apex
	to_pool.y = 0.0
	var reach := to_pool.length() + d.pool_radius
	reach_target.global_position = reach_apex + Vector3(0.0, 0.0, reach - 0.3)
	reach_boss._hurt_in_stream()
	assert_true(reach_target.hits.size() == 1, "A commander just inside the pool's far edge is in the stream (reach %.2f m)" % reach)
	reach_target.hits.clear()
	reach_target.global_position = reach_apex + Vector3(0.0, 0.0, reach + 0.3)
	reach_boss._hurt_in_stream()
	assert_true(reach_target.hits.is_empty(), "A commander just past the far edge is not")
	_free_all([reach_target, reach_boss])


func test_tc7_spit_pool() -> void:
	print("\n[TC7] Spit pool")
	for model_scale: float in [3.0, 4.5]:
		await _spit_pool_case(model_scale)


## One boss spits: the warning, the pool's place and shape, its ticks and its life, and where the
## stream's core comes down.
func _spit_pool_case(model_scale: float) -> void:
	var d := _scaled_data(model_scale)
	var tag := "scale %.1f" % model_scale
	var boss := _make_boss(d)
	var cmd := _make_commander(Vector3(40.0, 0.0, 40.0))
	var warnings: Array[Dictionary] = []
	var on_telegraph := func(_kind: StringName, position: Vector3, radius: float, _duration: float) -> void:
		warnings.append({"position": position, "radius": radius})
	EventBus.telegraph_started.connect(on_telegraph)
	_start(boss, cmd, SPIT)
	EventBus.telegraph_started.disconnect(on_telegraph)
	var origin := boss.to_global(d.body_v3(d.pool_center))
	assert_true(warnings.size() == 1 and absf(float(warnings[0]["radius"]) - d.pool_radius) < 0.001
			and (warnings[0]["position"] as Vector3).distance_to(origin) < 0.01,
			"%s: the warning is a ring of pool_radius at the pool's centre" % tag)
	_step(boss, _roar(boss) + d.pool_spawn_time - 0.1)
	assert_true(_pools().is_empty(), "%s: no pool before its spawn time" % tag)
	_step(boss, 0.2)
	var spit_yaw := boss.rotation.y
	var pools := _pools()
	assert_true(pools.size() == 1, "%s: one pool is spawned at its spawn time" % tag)
	_step(boss, 4.0)
	var pool := pools[0]
	pool.set_physics_process(false)
	assert_true(pool.global_position.distance_to(origin) < 0.01 and absf(pool.rotation.y - spit_yaw) < 0.001,
			"%s: the pool is centred where the data says, facing where the boss faced" % tag)
	assert_true(pool.scale.is_equal_approx(Vector3.ONE), "%s: the pool is not scaled with the model" % tag)
	assert_true(pool.contains_point(origin + Vector3(2.9, 0.0, 0.0)) and not pool.contains_point(origin + Vector3(3.1, 0.0, 0.0))
			and pool.contains_point(origin + Vector3(0.0, 0.0, -2.9)) and not pool.contains_point(origin + Vector3(0.0, 0.0, -3.1)),
			"%s: the pool is a disc 3 m in radius, the same at every scale" % tag)

	var inside := _make_commander(origin + Vector3(0.0, 0.0, 1.5))
	for i in 63:
		pool._physics_process(STEP)
	assert_true(inside.hits.size() == 2 and inside.hits[0].is_dot and inside.hits[0].damage_type == Enums.DamageType.MAGIC,
			"%s: a commander in the pool takes a MAGIC tick every 0.5 s (%d in 1.05 s)" % [tag, inside.hits.size()])
	inside.hits.clear()
	inside.global_position = origin + Vector3(0.0, 0.0, d.pool_radius + 1.0)
	for i in 63:
		pool._physics_process(STEP)
	assert_true(inside.hits.is_empty(), "%s: a commander just outside the disc takes nothing" % tag)
	inside.global_position = Vector3(30.0, 0.0, 0.0)
	var steps := 126
	while not pool.is_queued_for_deletion() and steps < 600:
		pool._physics_process(STEP)
		steps += 1
	assert_true(absf(steps * STEP - d.pool_lifetime) < 0.1, "%s: the pool is gone when its lifetime runs out (%.2f s)" % [tag, steps * STEP])
	pool.free()

	# The stream's core, flown by hand from the mouth in the held spit pose, comes down in the pool.
	boss.rotation.y = 0.0
	boss.anim_player.play(SkeletalCentipede.CLIP_SPIT)
	boss.anim_player.seek(d.spit_freeze_time, true)
	await get_tree().process_frame
	var landing := _core_landing(boss)
	var miss := Vector2(landing.x - origin.x, landing.z - origin.z).length()
	assert_true(miss <= 1.0, "%s: the core lands within 1 m of the pool's centre (%.2f m off, at z %.2f)" % [tag, miss, landing.z])
	_free_all([inside, boss])

	# A boss that dies makes its pool fade out quickly.
	var fresh := _make_boss(d)
	fresh.current_target = cmd
	fresh._spawn_pool()
	var fading := _pools()[0]
	fading.set_physics_process(false)
	fresh._on_died()
	steps = 0
	while not fading.is_queued_for_deletion() and steps < 600:
		fading._physics_process(STEP)
		steps += 1
	assert_true(steps * STEP <= d.pool_fade_time + 0.1, "%s: a pool whose boss died fades within the fade time (%.2f s)" % [tag, steps * STEP])
	_free_all([fresh, cmd])


## Where an average particle of the stream's core is when it reaches the floor or its lifetime ends:
## it leaves the emitter at the mean start speed along the emitter's direction (the emitter's basis
## carries the model scale) and falls under the particles' gravity.
func _core_landing(boss: SkeletalCentipede) -> Vector3:
	var core := boss.get_node("Model/CentipedeFx/Head/SpitEmitter/Core") as CPUParticles3D
	var speed := (core.initial_velocity_min + core.initial_velocity_max) * 0.5
	var position := core.global_position
	var velocity := core.global_transform.basis * (core.direction.normalized() * speed)
	var floor_y := boss.global_position.y
	var t := 0.0
	while t < core.lifetime and position.y > floor_y:
		velocity += core.gravity * STEP
		position += velocity * STEP
		t += STEP
	return position


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
	boss.roll_cooldown_left = 99.0
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


func test_turn_in_place_plays_walk() -> void:
	print("\n[Turn in place] Walk clip while turning without a move")
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(1.5, 0.0, 2.598))
	boss.current_target = cmd
	boss.change_state(Enums.EnemyState.ATTACK)
	boss._move = &""
	boss._recovery_left = 5.0
	var start_off := absf(rad_to_deg(boss._yaw_to_point(cmd.global_position)))
	_step(boss, STEP * 3.0)
	assert_true(boss.anim_player.current_animation == String(SkeletalCentipede.CLIP_WALK) and boss.anim_player.speed_scale > 0.0,
			"A turn under the clip threshold plays the walk clip in place (speed %.2f)" % boss.anim_player.speed_scale)
	var mid_off := absf(rad_to_deg(boss._yaw_to_point(cmd.global_position)))
	assert_true(mid_off < start_off, "The yaw approaches the target (%.1f to %.1f degrees)" % [start_off, mid_off])
	_step(boss, 1.0)
	assert_true(absf(rad_to_deg(boss._yaw_to_point(cmd.global_position))) < 1.0, "The boss ends up facing the target")
	assert_true(boss.anim_player.current_animation == String(SkeletalCentipede.CLIP_IDLE), "Once aligned it returns to the idle clip")
	_free_all([cmd, boss])
	var wide := _make_boss()
	var behind := _make_commander(Vector3(0.0, 0.0, -3.0))
	var clips: Array[StringName] = []
	wide.move_started.connect(func(_move: StringName, clip: StringName, _dur: float) -> void: clips.append(clip))
	wide.dash_cooldown_left = 99.0
	wide.roll_cooldown_left = 99.0
	wide.current_target = behind
	wide.change_state(Enums.EnemyState.ATTACK)
	assert_true(not clips.is_empty() and clips[0] == SkeletalCentipede.CLIP_TURN_180, "A gap of 45 degrees or more still plays the turn clip")
	_free_all([behind, wide])


func test_tc10_armor_phase() -> void:
	print("\n[TC10] Armor phase")
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
	assert_true(boss.get_fx_anchors().get("show_core", true) == false, "The centipede asks the effects manager to keep its core dark")
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
	_run_combo(boss)
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
	cmd.global_position = pool.global_position + Vector3(0.0, 0.0, 1.5)
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
	assert_true((body_shape.shape as BoxShape3D).size.is_equal_approx(d.body_box_size * 3.0) and (hurt_shape.shape as BoxShape3D).size.is_equal_approx(d.hurt_box_size * 3.0),
			"The body box and the hurt box are the data's boxes times the scale")
	assert_true(hurt_shape.position.is_equal_approx(d.hurt_box_center * 3.0) and body_shape.position.is_equal_approx(d.body_box_center * 3.0),
			"The hurt box and the body box sit where the data puts them")
	assert_true(absf(a.get_hit_point(Vector3(0.0, 0.0, 20.0)).z - d.body(1.1)) < 0.01,
			"The hit point seen from far ahead is the hurt box's front face, 1.1 body ahead of the centre")
	var wrapper := a.get_node_or_null("Model/SkeletalCentipedeModel")
	assert_true(wrapper != null and String(wrapper.scene_file_path).ends_with("skeletal_centipede_model.tscn"), "The model is the wrapper scene")
	assert_true(a.anim_player != null and a.anim_player.has_animation(SkeletalCentipede.CLIP_SLASH_1) and a.anim_player.has_animation(SkeletalCentipede.CLIP_ROAR)
			and a.anim_player.has_animation(SkeletalCentipede.CLIP_DASH_FRONT), "The wrapper's animation player has the model's clips and the code's libraries")
	var other_shape := b.get_node("CollisionShape3D") as CollisionShape3D
	assert_true(body_shape.shape != other_shape.shape, "Two bosses do not share a shape")
	assert_true(is_equal_approx(a.nav.radius, 2.7), "The agent radius follows the body (2.7)")
	assert_true(is_equal_approx(a.get_attack_range(), 1.4 * 3.0) and is_equal_approx(a.nav.target_desired_distance, 1.4 * 3.0),
			"The attack range is scaled")
	assert_true(is_equal_approx(a.dash_travel(CentipedeBrain.DASH_LEFT).length(), d.body(2.0) * d.dash_travel_scale), "The dash covers the clip's 2.0 body times the travel scale")
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
		assert_true(sized_box.size.is_equal_approx(d.body_box_size * model_scale) and sized_hurt.size.is_equal_approx(d.hurt_box_size * model_scale),
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
		assert_true(pool.contains_point(pool.global_position + Vector3(0.0, 0.0, 2.9)) and not pool.contains_point(pool.global_position + Vector3(0.0, 0.0, 3.1)),
				"%s: the pool is 3 m in radius whatever the scale" % tag)
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

		var no_cancel := d.duplicate() as CentipedeBossData
		no_cancel.combo_cancel_distance = 1000.0
		var stepper := _make_boss(no_cancel)
		var ahead := _make_commander(Vector3(0.0, 0.0, 50.0))
		_start(stepper, ahead, COMBO)
		_step(stepper, _roar(stepper) + stepper._combo_planned_length() + 0.2)
		combo_steps.append(stepper.global_position.z)
		_free_all([ahead, stepper])

		for case in [[0.9, true], [1.1, false]]:
			var spitter := _make_boss(d)
			var target := _make_commander(Vector3(0.0, 0.0, 60.0))
			_start(spitter, target, SPIT)
			target.global_position = spitter.get_spit_apex() + Vector3(0.0, 0.0, _stream_reach(spitter, d) * case[0])
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


## Distance from the spit's mouth to the far edge of the pool, in metres.
func _stream_reach(boss: SkeletalCentipede, d: CentipedeBossData) -> float:
	var to_pool := boss.to_global(d.body_v3(d.pool_center)) - boss.get_spit_apex()
	to_pool.y = 0.0
	return to_pool.length() + d.pool_radius


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
			"charge_roll_unlocked": true, "charge_roll_ready": true, "roll_ready": true, "off_angle_deg": 25.0}), d)
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


func test_tc19b_dash_scores() -> void:
	print("\n[TC19b] Dash scores by where the commander stands")
	var d := BOSS_DATA
	var stick := d.stickiness
	assert_true(is_equal_approx(d.spit_cooldown, 30.0) and is_equal_approx(d.dash_cooldown, 20.0) and is_equal_approx(d.dash_front_cooldown, 20.0),
			"The spit cools down 30 s, the side dashes share 20 s and the forward dash has 20 s of its own")
	var dash := {"dash_unlocked": true, "dash_ready": true}
	# Commander on the boss's left, 3 m off the body; the Fortress is on the left too.
	var left_side := CentipedeBrain.score_all(_situation(dash.merged({"in_front": false, "commander_lateral": 1.0, "distance": 3.0,
			"dash_left_share": 1.0, "dash_right_share": 0.2, "dash_front_ready": true})), d)
	assert_true(absf(float(left_side[CentipedeBrain.DASH_LEFT]) - 0.9 * stick) < 0.01 and absf(float(left_side[CentipedeBrain.DASH_RIGHT]) - 0.36 * stick) < 0.01,
			"Commander on the left, Fortress on the left: left 0.90, right 0.36 (%.2f, %.2f)" % [left_side[CentipedeBrain.DASH_LEFT], left_side[CentipedeBrain.DASH_RIGHT]])
	var to_fortress := CentipedeBrain.score_all(_situation(dash.merged({"in_front": false, "commander_lateral": 1.0, "distance": 3.0,
			"dash_left_share": 0.2, "dash_right_share": 1.0, "dash_front_ready": true})), d)
	assert_true(absf(float(to_fortress[CentipedeBrain.DASH_LEFT]) - 0.18 * stick) < 0.01 and absf(float(to_fortress[CentipedeBrain.DASH_RIGHT]) - 1.8 * stick) < 0.01,
			"Fortress on the right: left 0.18, right 1.80 (%.2f, %.2f)" % [to_fortress[CentipedeBrain.DASH_LEFT], to_fortress[CentipedeBrain.DASH_RIGHT]])
	var behind := CentipedeBrain.score_all(_situation(dash.merged({"in_front": false, "commander_lateral": 0.0, "distance": 5.0,
			"dash_left_share": 1.0, "dash_right_share": 0.2, "dash_front_ready": true})), d)
	assert_true(absf(float(behind[CentipedeBrain.DASH_LEFT]) - 1.35 * stick) < 0.01 and absf(float(behind[CentipedeBrain.DASH_RIGHT]) - 0.27 * stick) < 0.01,
			"Commander right behind: left 1.35, right 0.27 (%.2f, %.2f)" % [behind[CentipedeBrain.DASH_LEFT], behind[CentipedeBrain.DASH_RIGHT]])
	var ahead := CentipedeBrain.score_all(_situation(dash.merged({"in_front": true, "commander_lateral": 0.0, "distance": 3.0,
			"dash_left_share": 1.0, "dash_right_share": 1.0, "dash_front_ready": true})), d)
	assert_true(float(ahead[CentipedeBrain.DASH_LEFT]) < float(behind[CentipedeBrain.DASH_LEFT]), "A side dash is worth less with the commander in front than behind")

	# The forward dash in its band.
	var front := {"dash_unlocked": true, "dash_front_ready": true, "dash_front_share": 1.0, "in_spit_reach": true,
			"dash_ready": true, "dash_left_share": 1.0, "dash_right_share": 0.2}
	assert_true(_pick(_situation(front.merged({"distance": d.body(2.5)}))) == CentipedeBrain.DASH_FRONT, "Commander 2.5 body-metres ahead: DASH_FRONT")
	for gap: float in [2.0, 3.0]:
		var outside := CentipedeBrain.score_all(_situation(front.merged({"distance": d.body(gap)})), d)
		assert_true(is_zero_approx(float(outside[CentipedeBrain.DASH_FRONT])), "Commander %.1f body-metres ahead: no DASH_FRONT" % gap)
	var cooling := _situation(front.merged({"distance": d.body(2.5), "dash_front_ready": false}, true))
	assert_true(_pick(cooling) == CentipedeBrain.SPIT, "Forward dash cooling down: SPIT")

	# While the forward dash cools down the combo is worth a little more.
	var melee := {"in_slash": true, "hp_fraction": 0.4, "dash_unlocked": true}
	var combo_ready := CentipedeBrain.score_all(_situation(melee.merged({"dash_front_ready": true})), d)
	var combo_cooling := CentipedeBrain.score_all(_situation(melee.merged({"dash_front_ready": false})), d)
	assert_true(absf(float(combo_cooling[CentipedeBrain.COMBO]) - float(combo_ready[CentipedeBrain.COMBO]) * d.combo_dash_front_cooldown_mult) < 0.001
			and float(combo_ready[CentipedeBrain.COMBO]) > 0.0, "The combo scores combo_dash_front_cooldown_mult more while the forward dash cools down")

	# Turn pressure on the roll.
	var roll_open := {"distance": d.body(2.5), "roll_ready": true}
	var calm := CentipedeBrain.score_all(_situation(roll_open), d)
	assert_true(is_equal_approx(float(calm[CentipedeBrain.ROLL]), d.weight_roll * stick), "With no turns the roll scores its plain weight even this close")
	var once := CentipedeBrain.score_all(_situation(roll_open.merged({"recent_turns": 1})), d)
	assert_true(is_equal_approx(float(once[CentipedeBrain.ROLL]), d.weight_roll * stick), "One turn is no pressure yet")
	var twice := CentipedeBrain.score_all(_situation(roll_open.merged({"recent_turns": 2})), d)
	var thrice := CentipedeBrain.score_all(_situation(roll_open.merged({"recent_turns": 3})), d)
	assert_true(float(twice[CentipedeBrain.ROLL]) > 0.0 and absf(float(thrice[CentipedeBrain.ROLL]) - d.weight_roll * d.turn_roll_max_mult * stick) < 0.01,
			"Three turns score the roll at weight_roll times turn_roll_max_mult even this close (%.2f)" % float(thrice[CentipedeBrain.ROLL]))


## The roll and the charge roll share one cooldown.
func test_tc26_shared_roll_cooldown() -> void:
	print("\n[TC26] Shared roll cooldown")
	var d := BOSS_DATA
	assert_true(is_equal_approx(d.roll_cooldown, 30.0), "The shared roll cooldown is 30 s")
	for first: StringName in [ROLL, CHARGE_ROLL]:
		var boss := _make_boss()
		var cmd := _make_commander(Vector3(0.0, 0.0, 3.0))
		boss.current_target = cmd
		boss.provoked_by_player = true
		boss._start_move(first)
		var scores := CentipedeBrain.score_all(boss.build_situation(), d)
		assert_true(is_zero_approx(float(scores[CentipedeBrain.ROLL])) and is_zero_approx(float(scores[CentipedeBrain.CHARGE_ROLL])),
				"After %s starts, neither roll scores until the shared cooldown ends" % first)
		boss.roll_cooldown_left = 0.0
		var ready := CentipedeBrain.score_all(boss.build_situation(), d)
		assert_true(float(ready[CentipedeBrain.ROLL]) > 0.0 and float(ready[CentipedeBrain.CHARGE_ROLL]) > 0.0, "Both rolls score again once it has passed (after %s)" % first)
		_free_all([cmd, boss])


## Turn clips in a short time make the roll worth more; the count clears when a roll starts or the
## window passes.
func test_tc25_turn_pressure() -> void:
	print("\n[TC25] Turn pressure on the roll")
	var d := BOSS_DATA
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(0.0, 0.0, 8.0))
	boss.current_target = cmd
	boss.current_state = Enums.EnemyState.ATTACK
	boss.provoked_by_player = true
	assert_true(boss.recent_turn_count() == 0, "A boss that has not turned has no turn count")
	var plain := d.weight_roll * d.stickiness
	assert_true(absf(_roll_score(boss) - plain) < 0.01, "With no turns the roll scores its plain weight (%.2f)" % _roll_score(boss))
	_turn_times_in_place(boss, 3)
	assert_true(boss.recent_turn_count() == 3, "Three turn clips count three (%d)" % boss.recent_turn_count())
	var expected := d.weight_roll * d.turn_roll_max_mult * d.stickiness
	assert_true(absf(_roll_score(boss) - expected) < 0.01, "Three turns score the roll at weight_roll times turn_roll_max_mult (%.2f of %.2f)" % [_roll_score(boss), expected])
	for i in int((d.turn_roll_window + 0.1) / STEP):
		boss._process(STEP)
	assert_true(boss.recent_turn_count() == 0 and absf(_roll_score(boss) - plain) < 0.01, "The count empties once the window has passed")
	_turn_times_in_place(boss, 3)
	boss._start_move(ROLL)
	assert_true(boss.recent_turn_count() == 0, "Starting a roll clears the count")
	_free_all([cmd, boss])


## Roll's score for the boss's situation right now.
func _roll_score(boss: SkeletalCentipede) -> float:
	boss.choose_attack()
	return float(boss.last_scores[CentipedeBrain.ROLL])


## Plays count turn clips that do not rotate the boss, each to its end.
func _turn_times_in_place(boss: SkeletalCentipede, count: int) -> void:
	for i in count:
		boss._begin_turn(0.0)
		var guard := 0
		while boss._move == SkeletalCentipede.MOVE_TURN and guard < 400:
			_step(boss, STEP)
			guard += 1


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
	_run_combo(combo_boss)
	assert_true(front.hits.size() == 11, "All eleven hits still land after the roar (%d)" % front.hits.size())
	_free_all([front, combo_boss])


func _eye_glows(boss: SkeletalCentipede) -> Array[float]:
	var fx := boss._fx
	var nodes: Array[Node] = [fx.get_node("Head/EyeL"), fx.get_node("Head/EyeR"), fx.get_node("Head/EyeL/Halo"), fx.get_node("Head/EyeR/Halo")]
	var glows: Array[float] = []
	for node in nodes:
		glows.append((node as GeometryInstance3D).get_instance_shader_parameter(&"glow") as float)
	return glows


func test_eye_glow_in_roar() -> void:
	print("
[TC27] Eye glow in the roar")
	for move: StringName in [ROLL, SPIT, COMBO]:
		var boss := _make_boss()
		var cmd := _make_commander(Vector3(0.0, 0.0, 6.0))
		_start(boss, cmd, move)
		var rise := boss._fx.eye_glow_rise_time
		_step(boss, rise + 0.05)
		var glows := _eye_glows(boss)
		assert_true(glows.all(func(g: float) -> bool: return g >= 0.9), "%s: mid roar both eyes and both halos glow (%s)" % [move, glows])
		var head := boss._skeleton.global_transform * boss._skeleton.get_bone_global_pose(boss._skeleton.find_bone("Head"))
		var eye := (boss._fx.get_node("Head/EyeL") as Node3D).global_position
		var limit := 0.3 * boss.cdata.model_scale
		assert_true(eye.distance_to(head.origin) < limit, "%s: the eye sits on the Head bone (%.2f m, limit %.2f)" % [move, eye.distance_to(head.origin), limit])
		if move == ROLL:
			var guard := 0
			while boss._roll_phase == SkeletalCentipede.RollPhase.ROAR and guard < 400:
				_step(boss, STEP)
				guard += 1
			assert_true(boss._roll_phase == SkeletalCentipede.RollPhase.START, "Roll: the roar hands over to the start phase")
		else:
			_step(boss, _roar(boss))
		glows = _eye_glows(boss)
		assert_true(glows.all(func(g: float) -> bool: return is_zero_approx(g)), "%s: once the roar is over the eyes and halos are dark (%s)" % [move, glows])
		_free_all([cmd, boss])


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
	assert_true(cmd.hits.is_empty() and boss.roll_cooldown_left > 0.0, "A dodging commander is not hit and the roll went on cooldown")
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


func test_chase_fortress_share() -> void:
	print("\n[Chase] Chase score by direction to the Fortress")
	var d := BOSS_DATA
	var toward := CentipedeBrain.score_all(_situation({"engaged": true, "in_front": true, "chase_fortress_share": 1.0}), d)
	var away := CentipedeBrain.score_all(_situation({"engaged": true, "in_front": true, "chase_fortress_share": d.chase_off_fortress_share}), d)
	assert_true(absf(float(away[CentipedeBrain.CHASE]) - float(toward[CentipedeBrain.CHASE]) * d.chase_off_fortress_share) < 0.001,
			"Chase share 0.3 scores 0.3 times the chase share 1.0 (%.2f vs %.2f)" % [away[CentipedeBrain.CHASE], toward[CentipedeBrain.CHASE]])
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(d.body(4.0), 0.0, 0.0))
	boss.current_target = cmd
	assert_true(is_equal_approx(boss.build_situation().chase_fortress_share, 1.0), "No Fortress: chase share 1.0")
	var fortress := _make_structure(Vector3(30.0, 0.0, 0.0), &"fortress")
	assert_true(is_equal_approx(boss.build_situation().chase_fortress_share, 1.0), "Commander between the boss and the Fortress: chase share 1.0")
	cmd.global_position = Vector3(-d.body(4.0), 0.0, 0.0)
	assert_true(absf(boss.build_situation().chase_fortress_share - d.chase_off_fortress_share) < 0.001, "Commander on the far side from the Fortress: chase share 0.3")
	_free_all([cmd, fortress, boss])


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

	var lc := boss._clip_length(SkeletalCentipede.CLIP_DASH_CHARGE_LEFT)
	var ld := boss._clip_length(SkeletalCentipede.CLIP_DASH_LEFT)
	var left_end := boss._dash_travel_end(CentipedeBrain.DASH_LEFT)
	var left_length := lc + minf(ld, left_end + d.dash_land_time)
	var travel := boss.dash_travel(CentipedeBrain.DASH_LEFT).x
	assert_true(absf(travel - 2.0 * d.model_scale * d.dash_travel_scale) < 0.01, "The dash covers 2.0 body times the travel scale (%.2f m)" % travel)

	# The leap clip keeps the root bone's height but not its sideways travel.
	var source := boss.anim_player.get_animation(&"dash_left")
	var in_place := boss.anim_player.get_animation(SkeletalCentipede.CLIP_DASH_LEFT)
	var source_track := source.find_track(SkeletalCentipede.RIG_ROOT_TRACK, Animation.TYPE_POSITION_3D)
	var copy_track := in_place.find_track(SkeletalCentipede.RIG_ROOT_TRACK, Animation.TYPE_POSITION_3D)
	var in_place_ok := source_track >= 0 and copy_track >= 0 and source.track_get_key_count(source_track) == in_place.track_get_key_count(copy_track)
	for key in in_place.track_get_key_count(copy_track):
		var kept := in_place.track_get_key_value(copy_track, key) as Vector3
		var original := source.track_get_key_value(source_track, key) as Vector3
		in_place_ok = in_place_ok and is_zero_approx(kept.x) and is_zero_approx(kept.z) and is_equal_approx(kept.y, original.y)
	assert_true(in_place_ok, "The runtime leap clip has no sideways root travel and keeps the jump height")
	boss.anim_player.play(SkeletalCentipede.CLIP_DASH_LEFT)
	boss.anim_player.seek(0.25, true)
	var root_pose := boss._skeleton.get_bone_pose_position(boss._skeleton.find_bone("Root"))
	assert_true(absf(root_pose.x) < 0.001 and absf(root_pose.z) < 0.001 and root_pose.y > 0.0, "Mid-leap the root bone is lifted but has not moved sideways")
	boss.anim_player.stop()

	var clips: Array[StringName] = []
	var lengths: Array[float] = []
	boss.move_started.connect(func(_move: StringName, clip: StringName, duration: float) -> void:
		clips.append(clip)
		lengths.append(duration))
	_start(boss, cmd, CentipedeBrain.DASH_LEFT)
	assert_true(clips == [SkeletalCentipede.CLIP_DASH_CHARGE_LEFT] and absf(lengths[0] - left_length) < 0.001,
			"The dash is announced once with the wind-up clip and its length, cut a landing after the root stops (%s)" % clips)
	var frames := 0
	while boss._move_time < lc - STEP and frames < 400:
		boss._update_state(STEP)
		frames += 1
	assert_true(boss.global_position.is_zero_approx() and boss.anim_player.current_animation == "dash_charging_left",
			"During the wind-up the boss stands still and plays the wind-up clip")
	while boss._move_time < lc + 0.2167 and frames < 400:
		boss._update_state(STEP)
		frames += 1
	var expected := boss.dash_offset(CentipedeBrain.DASH_LEFT, boss._move_time - lc, Basis.IDENTITY)
	assert_true(boss.anim_player.current_animation == "runtime/dash_left" and absf(boss.global_position.x - expected.x) < 0.01,
			"Mid-leap the body is where the clip says (%.2f of %.2f m)" % [boss.global_position.x, expected.x])
	while boss._move == DASH and frames < 400:
		boss._update_state(STEP)
		frames += 1
	assert_true(absf(boss.global_position.x - travel) < 0.02, "A dash to the left ends dash_travel along +X (%.2f of %.2f m)" % [boss.global_position.x, travel])
	assert_true(absf(boss.global_position.z) < 0.001, "The dash does not move forward")
	assert_true(absi(frames - int(round(left_length / STEP))) <= 1, "The dash takes the wind-up plus the leap up to its landing (%d frames)" % frames)
	assert_true(absf(left_end - 0.4167) < 0.05 and left_end < ld, "The root stops travelling about 0.42 s into the leap (%.3f s of %.3f s)" % [left_end, ld])
	for action: StringName in [CentipedeBrain.DASH_LEFT, CentipedeBrain.DASH_RIGHT, CentipedeBrain.DASH_FRONT]:
		var end := boss._dash_travel_end(action)
		var whole := boss._clip_length(boss._dash_leap_clip(action))
		assert_true(end > 0.3 and end < 0.5 and end < whole, "%s: the root stops travelling between 0.3 and 0.5 s (%.3f of %.3f s)" % [action, end, whole])
	assert_true(is_equal_approx(d.dash_recovery, 0.05) and is_equal_approx(d.dash_land_time, 0.1), "The dash rests 0.05 s and keeps 0.1 s of landing")
	assert_true(absf(boss._recovery_left - d.dash_recovery / boss._combo_speed()) < STEP + 0.0001, "The dash recovery is the short one (%.3f s)" % boss._recovery_left)
	assert_true(is_equal_approx(boss.dash_buff_left, d.dash_buff_time) and boss.last_chosen_move == DASH,
			"The dash starts the buff")
	assert_true(is_equal_approx(boss.dash_cooldown_left, d.dash_cooldown) and is_zero_approx(boss.dash_front_cooldown_left),
			"A side dash sets the shared cooldown and leaves the forward dash's alone")

	boss.last_decision = &""
	for tick in int(ceil(d.dash_recovery / STEP)) + 1:
		boss._update_state(STEP)
	assert_true(boss.last_decision != &"", "The AI decides again right after the short recovery (%s)" % boss.last_decision)
	boss.stop_attack_sequence()

	# A far wall only takes away the side it blocks over the whole leap.
	boss.global_position = Vector3.ZERO
	boss.rotation.y = 0.0
	boss.dash_cooldown_left = 0.0
	var half_box := d.body(d.body_box_size.x * 0.5)
	var far_wall := _make_solid(Vector3(half_box + 2.0, 2.0, 0.0), Vector3(0.5, 4.0, 10.0), &"")
	await _settle()
	var walled := boss.build_situation()
	assert_true(is_zero_approx(walled.dash_left_share), "A wall in the dash's path leaves that side no score")
	assert_true(walled.dash_right_share > 0.0, "The other side keeps its score")
	far_wall.free()

	# A wall closer than the leap stops the body for good; the clip still plays out.
	boss.rotation.y = 0.0
	var near_wall := _make_solid(Vector3(half_box + 1.0 + 0.25, 2.0, 0.0), Vector3(0.5, 4.0, 10.0), &"")
	await _settle()
	var wall_run := _run_dash(boss, cmd)
	assert_true(boss.global_position.x + half_box <= half_box + 1.0 + 0.05 and boss.global_position.x > 0.5,
			"A wall stops the dash short of it after some travel (x = %.2f)" % boss.global_position.x)
	assert_true(absi(int(wall_run["frames"]) - int(round(left_length / STEP))) <= 1, "A blocked dash still plays its whole clip (%d frames)" % int(wall_run["frames"]))
	assert_true(wall_run["stopped"] and is_equal_approx(float(wall_run["stop_x"]), boss.global_position.x), "Once stopped the body does not drift")
	near_wall.free()

	# A tower (structure layer) stops it the same way.
	boss.global_position = Vector3.ZERO
	boss.rotation.y = 0.0
	boss.dash_cooldown_left = 0.0
	var tower := _make_solid(Vector3(half_box + 1.0 + 0.25, 2.0, 0.0), Vector3(0.5, 4.0, 10.0), &"tower")
	tower.collision_layer = 8
	await _settle()
	_run_dash(boss, cmd)
	assert_true(boss.global_position.x + half_box <= half_box + 1.0 + 0.05 and boss.global_position.x > 0.5,
			"A tower stops the dash short of it (x = %.2f)" % boss.global_position.x)
	tower.free()

	# The forward dash: straight ahead, a cooldown of its own, no buff.
	boss.global_position = Vector3.ZERO
	boss.rotation.y = 0.0
	boss.dash_buff_left = 0.0
	boss.dash_cooldown_left = 5.0
	boss.dash_front_cooldown_left = 0.0
	cmd.global_position = Vector3(0.0, 0.0, d.body(2.5))
	boss.current_target = cmd
	var front_situation := boss.build_situation()
	assert_true(front_situation.dash_front_ready and is_equal_approx(front_situation.dash_front_share, 1.0), "A commander in the forward dash's band: the forward dash is worth 1.0")
	cmd.global_position = Vector3(0.0, 0.0, d.body(2.0))
	assert_true(is_zero_approx(boss.build_situation().dash_front_share), "Closer than the band: no share")
	cmd.global_position = Vector3(0.0, 0.0, 40.0)
	var front_clips: Array[StringName] = []
	boss.move_started.connect(func(_move: StringName, clip: StringName, _duration: float) -> void: front_clips.append(clip))
	var front_run := _run_dash(boss, cmd, CentipedeBrain.DASH_FRONT)
	var front_travel := 2.0 * d.model_scale * d.dash_travel_scale
	assert_true(front_clips.back() == SkeletalCentipede.CLIP_DASH_CHARGE_FRONT, "The forward dash opens with its own wind-up clip")
	assert_true(absf(boss.global_position.z - front_travel) < 0.02 and absf(boss.global_position.x) < 0.02,
			"The forward dash moves the body straight ahead by 2.0 body times the travel scale (z = %.2f of %.2f m)" % [boss.global_position.z, front_travel])
	assert_true(is_equal_approx(boss.dash_front_cooldown_left, d.dash_front_cooldown) and is_equal_approx(boss.dash_cooldown_left, 5.0),
			"The forward dash sets its own cooldown and leaves the side dashes' alone")
	assert_true(is_zero_approx(boss.dash_buff_left) and absi(int(front_run["frames"]) - int(round((boss._clip_length(SkeletalCentipede.CLIP_DASH_CHARGE_FRONT) + minf(boss._clip_length(SkeletalCentipede.CLIP_DASH_FRONT), boss._dash_travel_end(CentipedeBrain.DASH_FRONT) + d.dash_land_time)) / STEP))) <= 1,
			"The forward dash gives no buff and takes the wind-up plus the leap up to its landing")

	# A commander standing ahead stops the leap short of its torso.
	boss.global_position = Vector3.ZERO
	cmd.global_position = Vector3(0.0, 0.0, d.body(d.body_box_size.z * 0.5) + 2.0)
	var stop_run := _run_dash(boss, cmd, CentipedeBrain.DASH_FRONT)
	var gap := cmd.global_position.z - boss.global_position.z
	assert_true(stop_run["stopped"] and gap >= d.body(d.body_box_size.z * 0.5) - 0.05 and boss.global_position.z > 0.5,
			"The forward dash stops with the commander still clear of the torso (gap %.2f m)" % gap)
	_free_all([cmd, boss, fortress, spawn])

	var big_data := _scaled_data(4.5)
	var big := _make_boss(big_data)
	var big_cmd := _make_commander(Vector3(0.0, 0.0, big_data.body(2.0)))
	await _settle()
	_run_dash(big, big_cmd)
	assert_true(absf(big.global_position.x - 2.0 * 4.5 * big_data.dash_travel_scale) < 0.03, "At scale 4.5 the dash covers 5.4 m (%.2f)" % big.global_position.x)
	_free_all([big_cmd, big])


## Starts a dash against target and runs it to its end. Reports the frame count and whether
## and where the body was held ("stopped", "stop_x").
func _run_dash(boss: SkeletalCentipede, target: Node3D, action: StringName = CentipedeBrain.DASH_LEFT) -> Dictionary:
	_start(boss, target, action)
	var report := {"frames": 0, "stopped": false, "stop_x": 0.0}
	while boss._move == DASH and int(report["frames"]) < 400:
		boss._update_state(STEP)
		report["frames"] += 1
		if boss._dash_stopped and not report["stopped"]:
			report["stopped"] = true
			report["stop_x"] = boss.global_position.x
	return report


func test_la3_cooldown() -> void:
	print("\n[LA3] Heavy swing cooldown")
	var d := BOSS_DATA
	assert_true(is_equal_approx(d.la3_cooldown, 4.0), "The heavy swing waits 4 s")
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(0.0, 0.0, d.body(1.2)))
	var clips: Array[StringName] = []
	boss.move_started.connect(func(_move: StringName, clip: StringName, _dur: float) -> void: clips.append(clip))
	boss.combo_cooldown_left = 99.0
	_start(boss, cmd, SLASH)
	assert_true(clips == [SkeletalCentipede.CLIP_SLASH_3] and is_equal_approx(boss.la3_cooldown_left, d.la3_cooldown),
			"Dead ahead plays the heavy swing and starts its cooldown (%s)" % clips)
	_step(boss, 1.2)
	cmd.hits.clear()
	clips.clear()
	_start(boss, cmd, SLASH)
	_step(boss, 1.0)
	assert_true(clips.front() == SkeletalCentipede.CLIP_SLASH_2 and cmd.hits.size() == 1 and cmd.hits[0].amount == d.la_damage and is_zero_approx(cmd.hits[0].knockback_force),
			"On cooldown a commander dead ahead gets the left swing: la_damage, no knockback (%s)" % clips)
	cmd.global_position = Vector3(-d.body(0.1), 0.0, d.body(1.2))
	clips.clear()
	_start(boss, cmd, SLASH)
	assert_true(clips.front() == SkeletalCentipede.CLIP_SLASH_1, "Slightly to the right, still inside the centre cone: the right swing (%s)" % clips)
	cmd.global_position = Vector3(0.0, 0.0, d.body(1.2))
	boss.la3_cooldown_left = 0.05
	clips.clear()
	_start(boss, cmd, SLASH)
	assert_true(clips.front() != SkeletalCentipede.CLIP_SLASH_3, "A cooldown with 0.05 s left still blocks the heavy swing")
	_step(boss, 0.1)
	clips.clear()
	_start(boss, cmd, SLASH)
	assert_true(clips.front() == SkeletalCentipede.CLIP_SLASH_3, "The heavy swing comes back when the cooldown is over")
	_free_all([cmd, boss])

	var tower_boss := _make_boss()
	var tower := _make_structure(Vector3(0.0, 0.0, d.body(1.2)), &"tower")
	var tower_clips: Array[StringName] = []
	tower_boss.move_started.connect(func(_move: StringName, clip: StringName, _dur: float) -> void: tower_clips.append(clip))
	tower_boss.la3_cooldown_left = 3.0
	tower_boss.current_target = tower
	tower_boss.current_state = Enums.EnemyState.ATTACK
	tower_boss._attack_structure()
	assert_true(tower_clips == [SkeletalCentipede.CLIP_SLASH_3], "A structure still gets the heavy swing during the cooldown (%s)" % tower_clips)
	_free_all([tower, tower_boss])

	var timer_boss := _make_boss()
	timer_boss.la3_cooldown_left = d.la3_cooldown
	for frame in int(round(d.la3_cooldown / STEP)):
		timer_boss._process(STEP)
	assert_true(absf(timer_boss.la3_cooldown_left) < 0.001, "The cooldown runs out after 4 s (%.4f)" % timer_boss.la3_cooldown_left)
	_free_all([timer_boss])


## While airborne the boss turns toward the commander, at a capped rate; the leap's path stays the
## one set at take-off.
func test_dash_air_turn() -> void:
	print("\n[Dash] Turn in the air")
	var d := BOSS_DATA
	var boss := _make_boss()
	var cmd := _make_commander(Vector3(0.0, 0.0, -d.body(2.0)))
	await _settle()
	boss.dash_cooldown_left = 0.0
	var travel := boss.dash_travel(CentipedeBrain.DASH_LEFT)
	var lc := boss._clip_length(SkeletalCentipede.CLIP_DASH_CHARGE_LEFT)
	var start_angle := absf(boss._yaw_to_point(cmd.global_position))
	_start(boss, cmd, CentipedeBrain.DASH_LEFT)
	var max_step := deg_to_rad(d.dash_air_turn_rate_deg) * STEP + 0.0001
	var charge_still := true
	var worst := 0.0
	var turned := 0.0
	var landing_still := true
	var guard := 0
	while boss._move == DASH and guard < 400:
		var yaw := boss.rotation.y
		var time_before := boss._move_time
		boss._update_state(STEP)
		var change := absf(angle_difference(yaw, boss.rotation.y))
		var leap_before := time_before - lc
		if boss._move_time < lc:
			charge_still = charge_still and is_zero_approx(change)
		elif leap_before < boss._dash_travel_end_time:
			worst = maxf(worst, change)
			turned += change
		else:
			landing_still = landing_still and is_zero_approx(change)
		guard += 1
	assert_true(charge_still, "The wind-up does not turn the boss")
	assert_true(worst <= max_step and turned > 0.5, "In the air it turns at most dash_air_turn_rate_deg and does turn (%.3f of %.3f rad per step, %.2f rad)" % [worst, max_step, turned])
	assert_true(landing_still, "Once the root stops the boss stops turning")
	assert_true(absf(boss._yaw_to_point(cmd.global_position)) < start_angle, "The boss ends up facing the commander more than at take-off")
	assert_true(absf(boss.global_position.x - travel.x) < 0.02 and absf(boss.global_position.z) < 0.001,
			"Turning does not bend the path (%.2f, %.3f of %.2f m)" % [boss.global_position.x, boss.global_position.z, travel.x])
	_free_all([cmd, boss])

	var front_boss := _make_boss()
	var front_cmd := _make_commander(Vector3(d.body(1.5), 0.0, d.body(2.5)))
	await _settle()
	var front_travel := front_boss.dash_travel(CentipedeBrain.DASH_FRONT)
	_run_dash(front_boss, front_cmd, CentipedeBrain.DASH_FRONT)
	assert_true(absf(front_boss.global_position.x) < 0.02 and absf(front_boss.global_position.z - front_travel.z) < 0.02,
			"The forward leap still goes straight ahead (%.2f, %.2f of %.2f m)" % [front_boss.global_position.x, front_boss.global_position.z, front_travel.z])
	assert_true(front_boss.rotation.y > 0.1, "The face turned toward the commander on the +X side (%.2f rad)" % front_boss.rotation.y)
	_free_all([front_cmd, front_boss])


## The roll's speed lines are full at the roll's top speed, whatever the boss's scale or cap.
func test_roll_speed_lines_intensity() -> void:
	print("\n[Roll] Speed lines")
	for case in [[3.0, ROLL], [4.5, ROLL], [3.0, SkeletalCentipede.MOVE_CHARGE_ROLL]]:
		var d := _scaled_data(case[0])
		var boss := _make_boss(d)
		var cmd := _make_commander(Vector3(0.0, 0.0, 40.0))
		var lines := boss.get_node_or_null("Model/CentipedeFx/RollSpeedLines") as GeometryInstance3D
		var tag := "scale %.1f %s" % [case[0], case[1]]
		assert_true(lines != null, "%s: the speed lines node exists" % tag)
		if lines == null:
			_free_all([cmd, boss])
			continue
		_start(boss, cmd, case[1])
		var roar_peak := 0.0
		var loop_peak := 0.0
		var guard := 0
		while boss._move == case[1] and guard < 2400:
			_step(boss, STEP)
			var intensity := float(lines.get_instance_shader_parameter(&"intensity"))
			if boss._roll_phase == SkeletalCentipede.RollPhase.ROAR:
				roar_peak = maxf(roar_peak, intensity)
			elif boss._roll_phase == SkeletalCentipede.RollPhase.LOOP:
				loop_peak = maxf(loop_peak, intensity)
			guard += 1
		assert_true(roar_peak == 0.0, "%s: no lines during the roar" % tag)
		assert_true(loop_peak > 0.95, "%s: the lines are full in the loop (%.2f)" % [tag, loop_peak])
		_step(boss, 3.0)
		assert_true(is_zero_approx(float(lines.get_instance_shader_parameter(&"intensity"))), "%s: no lines once the roll is over" % tag)
		_free_all([cmd, boss])


## The commander's sword measures to the boss's hurt box, so a swing lands from the front, the back
## and the side at both scales. The commander (the real scene) is pushed into the torso, faces it,
## and swings once.
func test_tc24_commander_sword() -> void:
	print("\n[TC24] The commander's sword hits the boss from every side")
	var approaches := {"front": Vector3(0.0, 0.0, 1.0), "back": Vector3(0.0, 0.0, -1.0), "left": Vector3(1.0, 0.0, 0.0)}
	for model_scale: float in [3.0, 4.5]:
		for approach: String in approaches:
			await _sword_case(model_scale, approach, approaches[approach])


func _sword_case(model_scale: float, approach: String, direction: Vector3) -> void:
	var d := _scaled_data(model_scale)
	var boss := _make_boss(d)
	var fox := COMMANDER_SCENE.instantiate() as CharacterBody3D
	add_child(fox)
	fox.set_physics_process(false)
	fox.set_process(false)
	fox.global_position = direction * 30.0
	await _settle()
	fox.move_and_collide(-direction * 30.0)
	fox._attack_strike_dir = -direction
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before := boss.current_armor_hp + boss.current_core_hp
	fox._execute_sword_strike(1)
	var after := boss.current_armor_hp + boss.current_core_hp
	assert_true(after < before, "scale %.1f: a swing from the %s lands (%d to %d, commander %.2f m from the centre)" % [model_scale, approach, before, after, fox.global_position.length()])
	_free_all([fox, boss])


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
