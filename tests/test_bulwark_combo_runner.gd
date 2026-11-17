extends Node3D

## Bulwark slash -> stab -> slam combo: hitboxes, full timeline, speed-up, and the AI that picks
## the combo inside the ATTACK state. The boss's own clocks are stepped by hand so the results
## do not depend on frame timing.

const BULWARK_SCENE: PackedScene = preload("res://entities/enemy/bulwark.tscn")
const STEP: float = 1.0 / 60.0

var passes: int = 0
var fails: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("          BULWARK COMBO HITBOX & AI VERIFICATION        ")
	print("=======================================================")

	test_slash_hitbox()
	test_stab_hitbox()
	test_dodge_and_deploy()
	test_full_combo_timeline()
	test_combo_speeds_up()
	test_ai_picks_combo()
	test_turn_rate_limit()
	test_ai_hands_back_to_attack_state()
	test_ai_combo_stops_when_target_lost()
	test_armor_break_cancels_combo()
	test_triple_stomp_clip_cut()
	test_triple_stomp_hits()
	test_moves_unlock_by_appearance()
	test_stomp_punishes_kiting()
	test_chains_never_kill_full_commander()
	test_stomp_lands_in_front()
	test_brain_scores()
	test_t_away()
	test_push_on_when_circled()
	test_hazard_turns_faster()
	test_structure_turn_first()
	test_no_structures_keeps_fighting()

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


# Boss at the origin facing +Z, with its own process loops off so the test drives them.
func _make_bulwark() -> Bulwark:
	var bulwark := BULWARK_SCENE.instantiate() as Bulwark
	add_child(bulwark)
	bulwark.set_physics_process(false)
	bulwark.set_process(false)
	bulwark.global_position = Vector3.ZERO
	bulwark.rotation.y = 0.0
	bulwark.spawn_grace = false
	bulwark.spawn_wave = 15  # third appearance: every move unlocked
	bulwark.is_in_spawn_zone = false
	return bulwark


func _make_commander(pos: Vector3) -> MockCommander:
	var cmd := MockCommander.new()
	add_child(cmd)
	cmd.global_position = pos
	return cmd


func _run_process(bulwark: Bulwark, seconds: float, advance_anim: bool = false) -> void:
	var t := 0.0
	while t < seconds:
		bulwark._process(STEP)
		if advance_anim and bulwark.anim_player != null:
			bulwark.anim_player.advance(STEP)
		t += STEP


func test_slash_hitbox() -> void:
	print("\n[GROUP 1] Slash hitbox (sector in front)")
	var bulwark := _make_bulwark()
	var reach := (bulwark.data as BossData).combo_slash_range
	var arc := (bulwark.data as BossData).combo_slash_arc_deg
	var front := _make_commander(Vector3(0.0, 0.0, 2.5))
	assert_true(bulwark._in_slash_hitbox(front, reach, arc), "Target 2.5 m in front is inside the slash")
	front.global_position = Vector3(1.2, 0.0, 2.0)
	assert_true(bulwark._in_slash_hitbox(front, reach, arc), "Target 31 degrees off-center is inside the 120 degree arc")
	front.global_position = Vector3(2.5, 0.0, 0.0)
	assert_true(not bulwark._in_slash_hitbox(front, reach, arc), "Target at 90 degrees is outside the arc")
	front.global_position = Vector3(0.0, 0.0, -2.5)
	assert_true(not bulwark._in_slash_hitbox(front, reach, arc), "Target behind the boss is not hit")
	front.global_position = Vector3(0.0, 0.0, reach + 0.5)
	assert_true(not bulwark._in_slash_hitbox(front, reach, arc), "Target past the slash reach is not hit")

	front.global_position = Vector3(0.0, 0.0, 2.0)
	bulwark.combo_step = Bulwark.ComboStep.SLASH
	bulwark._strike_combo_step(Bulwark.ComboStep.SLASH)
	assert_true(front.damage_taken == 15, "Combo slash deals 15 SLASH at wave 1")
	assert_true(front.last_type == Enums.DamageType.SLASH, "Slash damage type is SLASH")
	assert_true(front.knockback_taken == 0.0, "Slash has no knockback")
	front.free()
	bulwark.free()


func test_stab_hitbox() -> void:
	print("\n[GROUP 2] Stab hitbox (narrow box ahead)")
	var bulwark := _make_bulwark()
	var boss_data := bulwark.data as BossData
	var cmd := _make_commander(Vector3(0.0, 0.0, 3.5))
	assert_true(bulwark._in_stab_hitbox(cmd, boss_data.combo_stab_range, boss_data.combo_stab_width), "Target 3.5 m straight ahead is inside the stab")
	cmd.global_position = Vector3(1.5, 0.0, 2.0)
	assert_true(not bulwark._in_stab_hitbox(cmd, boss_data.combo_stab_range, boss_data.combo_stab_width), "Target 1.5 m to the side is outside the stab")
	cmd.global_position = Vector3(0.0, 0.0, -1.0)
	assert_true(not bulwark._in_stab_hitbox(cmd, boss_data.combo_stab_range, boss_data.combo_stab_width), "Target behind is outside the stab")

	cmd.global_position = Vector3(0.0, 0.0, 3.0)
	bulwark._strike_combo_step(Bulwark.ComboStep.STAB)
	assert_true(cmd.damage_taken == 20, "Stab deals 20 SLASH at wave 1")
	assert_true(is_equal_approx(cmd.knockback_taken, 1.5), "Stab knocks the commander back 1.5")

	bulwark.wave_dmg_mult = 2.0
	cmd.damage_taken = 0
	bulwark._strike_combo_step(Bulwark.ComboStep.STAB)
	assert_true(cmd.damage_taken == 40, "Stab damage scales with the wave damage multiplier")
	cmd.free()
	bulwark.free()


func test_dodge_and_deploy() -> void:
	print("\n[GROUP 3] Dodge and Deploy")
	var bulwark := _make_bulwark()
	var cmd := _make_commander(Vector3(0.0, 0.0, 2.0))
	cmd.is_dodging = true
	bulwark._strike_combo_step(Bulwark.ComboStep.SLASH)
	bulwark._strike_combo_step(Bulwark.ComboStep.STAB)
	assert_true(cmd.damage_taken == 0, "Dodging commander takes no slash or stab damage")
	cmd.is_dodging = false
	cmd.is_deploying = true
	bulwark._strike_combo_step(Bulwark.ComboStep.STAB)
	assert_true(cmd.damage_taken == 20 and cmd.knockback_taken == 0.0, "Deploying commander takes the stab but no knockback")
	cmd.free()
	bulwark.free()


func test_full_combo_timeline() -> void:
	print("\n[GROUP 4] Full combo timeline")
	var bulwark := _make_bulwark()
	var cmd := _make_commander(Vector3(0.0, 0.0, 2.0))
	var steps: Array[StringName] = []
	var hit_steps: Array[StringName] = []
	var finished := [false]
	bulwark.attack_step_started.connect(func(atk_id: int, step_name: StringName, _c: StringName, _d: float) -> void:
		if atk_id == Bulwark.COMBO_SLAM_ID:
			steps.append(step_name))
	bulwark.attack_hit.connect(func(_atk_id: int, step_name: StringName, targets: Array) -> void:
		if targets.has(cmd):
			hit_steps.append(step_name))
	bulwark.attack_sequence_finished.connect(func(atk_id: int) -> void:
		finished[0] = atk_id == Bulwark.COMBO_SLAM_ID)

	bulwark.play_attack_combo_slam()
	assert_true(bulwark.is_in_attack_sequence and bulwark.current_attack_id == Bulwark.COMBO_SLAM_ID, "Combo starts as attack 6")
	_run_process(bulwark, 0.4)
	assert_true(cmd.damage_taken == 0, "No damage before the slash lands")
	_run_process(bulwark, 0.25)
	assert_true(cmd.damage_taken == 15, "Slash lands at its hit time")
	_run_process(bulwark, 1.57 - 0.65 + 0.85)
	assert_true(cmd.damage_taken == 35, "Stab lands during the second step")
	_run_process(bulwark, 3.0)
	assert_true(cmd.damage_taken == 69, "Slam lands for 75% of the stomp (34)")
	_run_process(bulwark, 1.0)
	assert_true(steps == [&"SLASH_1H", &"STAB_1H", &"2H_GROUND_SLAM"], "Steps run in order: slash, stab, slam")
	assert_true(hit_steps == [&"SLASH_1H", &"STAB_1H", &"2H_GROUND_SLAM"], "Each step hits the commander exactly once")
	assert_true(finished[0], "Combo emits attack_sequence_finished")
	assert_true(not bulwark.is_in_attack_sequence and bulwark.combo_step == Bulwark.ComboStep.NONE, "Combo state is cleared at the end")
	cmd.free()
	bulwark.free()


func test_combo_speeds_up() -> void:
	print("\n[GROUP 5] Phase 2 and Enrage speed the combo up")
	var bulwark := _make_bulwark()
	assert_true(is_equal_approx(bulwark._combo_speed(), 1.0), "Phase 1 combo plays at clip speed")
	bulwark.current_phase = Enums.BossPhase.EXPOSED
	assert_true(is_equal_approx(bulwark._combo_speed(), 1.3), "Exposed phase plays the combo 1.3x faster")
	bulwark.is_enraged = true
	assert_true(is_equal_approx(bulwark._combo_speed(), 1.3 * GameConfig.enrage_attack_rate_mult), "Enrage stacks on top of phase 2")

	var done := [false]
	bulwark.attack_sequence_finished.connect(func(_id: int) -> void: done[0] = true)
	bulwark.play_attack_combo_slam()
	var total := 1.57 + 1.40 + 2.83
	_run_process(bulwark, total / bulwark._combo_speed() + 0.05)
	assert_true(done[0], "Sped-up combo finishes in the shortened time")
	bulwark.free()


func test_ai_picks_combo() -> void:
	print("
[GROUP 6] Commander move table")
	var bulwark := _make_bulwark()
	var cmd := _make_commander(Vector3(0.0, 0.0, 2.0))
	bulwark.current_target = cmd
	bulwark.set_ai_seed(1234)

	assert_true(bulwark.is_in_front(cmd), "Commander straight ahead counts as in front")
	assert_true(bulwark.choose_attack() == Bulwark.MOVE_NORMAL, "Front, full HP: normal attack")
	bulwark.change_state(Enums.EnemyState.ATTACK)
	assert_true(bulwark.current_attack_id == Bulwark.NORMAL_ATTACK_ID and bulwark.combo_step == Bulwark.ComboStep.SLASH, "Entering ATTACK starts the normal attack")
	bulwark.stop_attack_sequence()

	cmd.global_position = Vector3(2.0, 0.0, 0.5)
	assert_true(not bulwark.is_in_front(cmd), "Commander at the flank is not in front")
	assert_true(bulwark.choose_attack() == Bulwark.MOVE_TRIPLE, "Flank: triple stomp")
	cmd.global_position = Vector3(0.0, 0.0, -2.0)
	assert_true(bulwark.choose_attack() == Bulwark.MOVE_TRIPLE, "Behind: triple stomp")
	bulwark._play_attack_anim()
	assert_true(bulwark.current_attack_id == Bulwark.TRIPLE_STOMP_ID, "The pick plays the triple stomp")
	assert_true(bulwark.triple_stomp_cooldown_left > 0.0, "Triple stomp goes on cooldown")
	bulwark.stop_attack_sequence()
	assert_true(bulwark.choose_attack() == Bulwark.MOVE_FACE, "Behind while the stomp cools down: turn to face, no swing at air")
	bulwark._process(bulwark.triple_stomp_cooldown_left + 0.01)
	bulwark.t_away = 0.0
	assert_true(bulwark.choose_attack() == Bulwark.MOVE_TRIPLE, "Cooldown runs out on game time")

	cmd.global_position = Vector3(0.0, 0.0, 2.0)
	var counts := {Bulwark.MOVE_NORMAL: 0, Bulwark.MOVE_COMBO: 0}
	for i in range(400):
		counts[bulwark.choose_attack()] += 1
	assert_true(counts[Bulwark.MOVE_COMBO] == 0, "Front, above half HP: never the combo")

	bulwark.current_armor_hp = 50  # (50 + 900) / 2100 = 45%
	assert_true(bulwark.get_hp_fraction() < 0.5, "Boss is below half HP")
	counts = {Bulwark.MOVE_NORMAL: 0, Bulwark.MOVE_COMBO: 0}
	for i in range(400):
		counts[bulwark.choose_attack()] += 1
	print("  below half HP over 400 picks: normal %d, combo %d" % [counts[Bulwark.MOVE_NORMAL], counts[Bulwark.MOVE_COMBO]])
	assert_true(counts[Bulwark.MOVE_COMBO] > 150 and counts[Bulwark.MOVE_NORMAL] > 150, "Front, below half HP: roughly 50/50 normal and combo")

	var picks_a: Array[StringName] = []
	var picks_b: Array[StringName] = []
	bulwark.set_ai_seed(99)
	for i in range(20):
		picks_a.append(bulwark.choose_attack())
	bulwark.set_ai_seed(99)
	for i in range(20):
		picks_b.append(bulwark.choose_attack())
	assert_true(picks_a == picks_b, "Same seed, same choices")

	cmd.global_position = Vector3(0.0, 0.0, -20.0)
	var fortress := MockFortress.new()
	add_child(fortress)
	fortress.global_position = Vector3(0.0, 0.0, 4.0)
	bulwark.current_target = fortress
	assert_true(bulwark.choose_attack() == Bulwark.MOVE_PUSH, "Commander far away: the boss keeps on at the structures")
	bulwark.change_state(Enums.EnemyState.ADVANCE)
	bulwark.current_target = fortress
	bulwark.change_state(Enums.EnemyState.ATTACK)
	assert_true(bulwark.current_target == fortress and bulwark.last_chosen_move == Bulwark.MOVE_STOMP, "Fortress gets the stomp")
	bulwark._locked_stomp_center = Vector3.INF
	fortress.free()
	cmd.free()
	bulwark.free()


func test_turn_rate_limit() -> void:
	print("
[GROUP 6b] Boss locks facing during a swing and turns at ai_turn_rate_deg between moves")
	var bulwark := _make_bulwark()
	var boss_data := bulwark.data as BossData
	var cmd := _make_commander(Vector3(0.0, 0.0, 2.0))
	bulwark.current_target = cmd
	bulwark.change_state(Enums.EnemyState.ATTACK)
	assert_true(bulwark.combo_step != Bulwark.ComboStep.NONE, "Commander in front: the boss swings")
	cmd.global_position = Vector3(0.0, 0.0, -2.0)
	for i in range(30):  # half a second of the swing
		bulwark._update_state(STEP)
	var turned := rad_to_deg(absf(angle_difference(0.0, bulwark.rotation.y)))
	assert_true(turned < 0.001, "Boss does not turn during a swing (turned %.1f deg)" % turned)
	assert_true(bulwark.velocity.x == 0.0 and bulwark.velocity.z == 0.0, "Boss does not move during a swing")

	# Pause after the swing: the boss turns, no faster than ai_turn_rate_deg.
	bulwark.stop_attack_sequence()
	bulwark.is_attacking_active = true
	bulwark.attack_recovery_timer = 5.0
	for i in range(30):
		bulwark._update_state(STEP)
	turned = rad_to_deg(absf(angle_difference(0.0, bulwark.rotation.y)))
	var max_turn := boss_data.ai_turn_rate_deg * 0.5
	assert_true(turned > max_turn * 0.9 and turned <= max_turn + 0.01,
			"Boss turns toward the commander between moves at the turn rate (%.1f of max %.1f deg)" % [turned, max_turn])
	var walk_speed := Vector2(bulwark.velocity.x, bulwark.velocity.z).length()
	var max_walk := boss_data.move_speed * bulwark.speed_multiplier * Bulwark.TURN_WALK_SPEED_MULT
	assert_true(walk_speed > 0.0 and walk_speed <= max_walk + 0.001,
			"Boss walks slowly while it turns between moves (%.2f m/s, max %.2f)" % [walk_speed, max_walk])
	var fwd := bulwark._combo_forward()
	assert_true(Vector3(bulwark.velocity.x, 0.0, bulwark.velocity.z).normalized().dot(fwd) > 0.99,
			"The turning walk goes along the boss's facing")
	assert_true(bulwark.anim_player.current_animation == bulwark._walk_clip(), "The turning walk plays the walk clip")
	cmd.global_position = Vector3(3.0 * sin(bulwark.rotation.y), 0.0, 3.0 * cos(bulwark.rotation.y))
	bulwark._update_state(STEP)
	assert_true(bulwark.velocity.x == 0.0 and bulwark.velocity.z == 0.0, "Facing the target: the boss stops walking")
	cmd.free()
	bulwark.free()

	print("
[GROUP 6e] After a stomp the boss turns only once the mace is back up")
	bulwark = _make_bulwark()
	bulwark.spawn_wave = 5
	cmd = _make_commander(Vector3(0.0, 0.0, 5.0))
	bulwark.current_target = cmd
	bulwark.provoked_by_player = true  # the commander just hit it, so the boss minds it at 5 m
	bulwark.change_state(Enums.EnemyState.ATTACK)
	assert_true(bulwark.last_chosen_move == Bulwark.MOVE_STOMP, "Commander 5 m ahead: the stomp")
	var steps := 0
	while not bulwark.is_attacking_active and steps < 120:  # wind-up until the impact
		bulwark._update_state(STEP)
		steps += 1
	assert_true(bulwark._stomp_recovering, "After the impact the stomp clip is still pulling the mace back")
	cmd.global_position = Vector3(0.0, 0.0, -3.0)
	for i in range(30):
		bulwark._update_state(STEP)
	turned = rad_to_deg(absf(angle_difference(0.0, bulwark.rotation.y)))
	assert_true(turned < 0.001, "No turning while bent over the mace (turned %.1f deg)" % turned)
	bulwark.anim_player.seek(Bulwark.STOMP_CLIP_RECOVERED + 0.01, true)
	bulwark._process(STEP)
	assert_true(not bulwark._stomp_recovering, "Mace back up: the stomp is over")
	for i in range(30):
		bulwark._update_state(STEP)
	turned = rad_to_deg(absf(angle_difference(0.0, bulwark.rotation.y)))
	assert_true(turned > 10.0, "Then the boss turns toward the commander (turned %.1f deg)" % turned)
	cmd.free()
	bulwark.free()

	print("
[GROUP 6d] Phase 2 and Enrage turn faster by the attack speed-up")
	for case in [["phase 2", true, false], ["phase 2 + Enrage", true, true], ["Enrage", false, true]]:
		bulwark = _make_bulwark()
		cmd = _make_commander(Vector3(0.0, 0.0, -2.0))
		bulwark.current_target = cmd
		if case[1]:
			bulwark.current_phase = Enums.BossPhase.EXPOSED
		if case[2]:
			bulwark.enter_enrage()
		bulwark.change_state(Enums.EnemyState.ATTACK)
		bulwark.stop_attack_sequence()
		bulwark.is_attacking_active = true
		bulwark.attack_recovery_timer = 5.0
		for i in range(30):
			bulwark._update_state(STEP)
		turned = rad_to_deg(absf(angle_difference(0.0, bulwark.rotation.y)))
		var speed_up := boss_data.attack_interval / bulwark._get_attack_interval()
		var expected := boss_data.ai_turn_rate_deg * speed_up * 0.5
		assert_true(speed_up > 1.01 and absf(turned - expected) < 0.5,
				"%s: turns %.1f deg in 0.5 s (%.0f deg/s, x%.2f)" % [case[0], turned, turned * 2.0, speed_up])
		cmd.free()
		bulwark.free()

	print("
[GROUP 6c] Commander behind with no triple stomp ready: turn first, never swing at air")
	bulwark = _make_bulwark()
	cmd = _make_commander(Vector3(0.0, 0.0, -2.0))
	bulwark.current_target = cmd
	bulwark.triple_stomp_cooldown_left = 99.0
	bulwark.change_state(Enums.EnemyState.ATTACK)
	assert_true(bulwark.combo_step == Bulwark.ComboStep.NONE and not bulwark.is_in_attack_sequence,
			"No normal attack is swung at a commander behind the boss")
	var swung := false
	for i in range(240):  # 4 s: enough to turn 180 degrees at 90 deg/s
		bulwark._update_state(STEP)
		if bulwark.combo_step != Bulwark.ComboStep.NONE:
			swung = true
			break
	assert_true(swung and bulwark.is_in_front(cmd), "Boss turns to face the commander, then attacks")
	cmd.free()
	bulwark.free()


func test_ai_hands_back_to_attack_state() -> void:
	print("
[GROUP 7] AI sequences hand back to the ATTACK state")
	var bulwark := _make_bulwark()
	var cmd := _make_commander(Vector3(0.0, 0.0, 2.0))
	bulwark.current_target = cmd
	bulwark.change_state(Enums.EnemyState.ATTACK)
	bulwark._update_state(STEP)
	assert_true(bulwark.combo_step != Bulwark.ComboStep.NONE, "ATTACK state keeps the normal attack running")
	assert_true(bulwark.velocity.x == 0.0 and bulwark.velocity.z == 0.0, "Boss stands still during the attack")
	_run_process(bulwark, 0.6)
	assert_true(cmd.damage_taken == 18, "Normal attack deals 18")
	_run_process(bulwark, 1.57 - 0.6 + 0.05)
	assert_true(bulwark.combo_step == Bulwark.ComboStep.NONE, "Normal attack is a single slash")
	assert_true(bulwark.current_state == Enums.EnemyState.ATTACK, "Boss is still in ATTACK")
	assert_true(bulwark.is_attacking_active and is_equal_approx(bulwark.attack_recovery_timer, 0.6), "ATTACK waits out the recovery before the next move")

	cmd.global_position = Vector3(0.0, 0.0, -2.0)
	bulwark._play_attack_anim()
	assert_true(bulwark.current_attack_id == Bulwark.TRIPLE_STOMP_ID, "Triple stomp from the AI")
	_run_process(bulwark, bulwark.get_triple_stomp_step_length() * 3.0 + 0.05)
	assert_true(not bulwark.is_in_attack_sequence and bulwark.is_attacking_active, "Triple stomp also hands back with a recovery")
	assert_true(is_equal_approx(bulwark.attack_recovery_timer, 1.75), "Triple stomp leaves the long 1.75 s opening")
	cmd.free()
	bulwark.free()


func test_ai_combo_stops_when_target_lost() -> void:
	print("
[GROUP 8] AI sequences stop when the target is gone")
	var bulwark := _make_bulwark()
	var cmd := _make_commander(Vector3(0.0, 0.0, 2.0))
	bulwark.current_target = cmd
	bulwark.change_state(Enums.EnemyState.ATTACK)
	assert_true(bulwark.combo_step == Bulwark.ComboStep.SLASH, "Attack running")
	cmd.free()
	bulwark._update_state(STEP)
	assert_true(bulwark.combo_step == Bulwark.ComboStep.NONE and not bulwark.is_in_attack_sequence, "Lost target cancels the attack")

	var cmd2 := _make_commander(Vector3(0.0, 0.0, -2.0))
	bulwark.current_target = cmd2
	bulwark.change_state(Enums.EnemyState.ADVANCE)
	bulwark.triple_stomp_cooldown_left = 0.0
	bulwark.change_state(Enums.EnemyState.ATTACK)
	assert_true(bulwark.current_attack_id == Bulwark.TRIPLE_STOMP_ID, "Triple stomp running")
	bulwark.change_state(Enums.EnemyState.ADVANCE)
	bulwark._process(STEP)
	assert_true(not bulwark.is_in_attack_sequence, "Leaving ATTACK cancels an AI triple stomp")
	cmd2.free()
	bulwark.free()


func test_armor_break_cancels_combo() -> void:
	print("\n[GROUP 9] Armor break cancels the combo")
	var bulwark := _make_bulwark()
	bulwark.play_attack_combo_slam()
	bulwark.take_damage(DamageInfo.new(bulwark.current_armor_hp + 10, Enums.DamageType.BLAST))
	assert_true(bulwark.current_phase == Enums.BossPhase.TRANSITION, "Boss is in TRANSITION")
	assert_true(bulwark.combo_step == Bulwark.ComboStep.NONE and not bulwark.is_in_attack_sequence, "Combo is cancelled by the armor break")
	bulwark.free()


func test_triple_stomp_clip_cut() -> void:
	print("\n[GROUP 10] Triple stomp cuts the slam clip and restarts it each stomp")
	var bulwark := _make_bulwark()
	var ap := bulwark.anim_player
	assert_true(ap != null and ap.has_animation(Bulwark.CLIP_SLAM_2H), "Bulwark model has the slam clip")
	var clip_len := ap.get_animation(Bulwark.CLIP_SLAM_2H).length
	print("  slam clip length: %.3fs, each stomp plays %.3fs" % [clip_len, bulwark.get_triple_stomp_step_length()])
	assert_true(is_equal_approx(bulwark.get_triple_stomp_step_length(), clip_len * 0.75), "Each stomp plays 75% of the slam clip")

	var starts: Array[float] = []
	var durations: Array[float] = []
	var finished := [false]
	bulwark.attack_step_started.connect(func(atk_id: int, _s: StringName, _c: StringName, d: float) -> void:
		if atk_id == Bulwark.TRIPLE_STOMP_ID:
			starts.append(ap.current_animation_position)
			durations.append(d))
	bulwark.attack_sequence_finished.connect(func(atk_id: int) -> void:
		finished[0] = atk_id == Bulwark.TRIPLE_STOMP_ID)

	bulwark.play_triple_stomp()
	var positions: Array[float] = [ap.current_animation_position]
	_run_process(bulwark, bulwark.get_triple_stomp_step_length() - 0.1, true)
	var end_of_first := ap.current_animation_position
	_run_process(bulwark, 0.15, true)
	positions.append(ap.current_animation_position)
	_run_process(bulwark, bulwark.get_triple_stomp_step_length(), true)
	positions.append(ap.current_animation_position)

	assert_true(end_of_first > clip_len * 0.6, "First stomp reaches late in the clip before the cut")
	assert_true(positions[1] < 0.2, "Second stomp restarts the clip from its wind-up")
	assert_true(positions[2] < 0.2, "Third stomp restarts the clip from its wind-up")
	assert_true(durations.size() == 3 and is_equal_approx(durations[0], clip_len * 0.75), "Step duration reported as the cut length")
	_run_process(bulwark, bulwark.get_triple_stomp_step_length(), true)
	assert_true(finished[0] and not bulwark.is_in_attack_sequence, "Chain ends after the third cut stomp")
	assert_true(ap.current_animation == Bulwark.CLIP_IDLE, "Boss goes back to idle")
	bulwark.free()


func test_triple_stomp_hits() -> void:
	print("\n[GROUP 11] Triple stomp hit timing and growing radius")
	var bulwark := _make_bulwark()
	var cmd := _make_commander(bulwark.get_stomp_center() + Vector3(0.0, 0.0, 4.0))
	var hits: Array[StringName] = []
	var hit_times: Array[float] = []
	var clock := [0.0]
	bulwark.attack_hit.connect(func(atk_id: int, step_name: StringName, targets: Array) -> void:
		if atk_id == Bulwark.TRIPLE_STOMP_ID:
			hit_times.append(clock[0])
			if targets.has(cmd):
				hits.append(step_name))
	assert_true(is_equal_approx(bulwark.get_triple_stomp_radius(0), 3.0)
			and is_equal_approx(bulwark.get_triple_stomp_radius(1), 4.5)
			and is_equal_approx(bulwark.get_triple_stomp_radius(2), 6.6), "Radii are 3.0, 4.5 and 6.6 m")

	bulwark.play_triple_stomp()
	var total := bulwark.get_triple_stomp_step_length() * 3.0 + 0.1
	while clock[0] < total:
		bulwark._process(STEP)
		clock[0] += STEP
	var step_len := bulwark.get_triple_stomp_step_length()
	assert_true(hit_times.size() == 3, "Three stomp hits")
	assert_true(hit_times.size() == 3 and absf(hit_times[0] - 0.97) < 0.03
			and absf(hit_times[1] - (step_len + 0.97)) < 0.03, "Each stomp hits 0.97 s into its own clip")
	assert_true(hits == [&"TRIPLE_STOMP_2", &"TRIPLE_STOMP_3"], "Commander 4 m from the impact point dodges the first ring, eats the bigger two")
	assert_true(cmd.damage_taken == 57, "Second and third stomp deal 50% and 75% of 45 (23 + 34)")
	cmd.free()
	bulwark.free()


func test_stomp_punishes_kiting() -> void:
	print("
[GROUP 12b] Commander kept out of slash reach in front gets the stomp")
	var bulwark := _make_bulwark()
	var boss_data := bulwark.data as BossData
	var cmd := _make_commander(Vector3(0.0, 0.0, 2.0))
	bulwark.current_target = cmd
	bulwark.spawn_wave = 5  # first appearance: the stomp is there from the start
	assert_true(bulwark.choose_attack() == Bulwark.MOVE_NORMAL, "Front, 2 m: the slash")

	cmd.global_position = Vector3(0.0, 0.0, 5.0)
	assert_true(not BulwarkBrain.is_commander_action(bulwark.choose_attack()), "Front, 5 m, has not hit the boss: the boss does not mind it")
	bulwark.provoked_by_player = true  # the commander hit the boss, then backed off
	assert_true(bulwark.choose_attack() == Bulwark.MOVE_STOMP, "Front, 5 m (in the ring, out of slash reach): the stomp")
	cmd.global_position = Vector3(0.0, 0.0, 7.5)
	assert_true(bulwark.choose_attack() == Bulwark.MOVE_CHASE, "Front, 7.5 m (past the ring): chase, no stomp")
	cmd.global_position = Vector3(0.0, 0.0, -5.0)
	assert_true(bulwark.choose_attack() == Bulwark.MOVE_FACE, "Behind, 5 m: turn, no stomp (its ring lands in front)")

	# Chasing: walking into the ring starts the stomp from range.
	cmd.global_position = Vector3(0.0, 0.0, 5.0)
	bulwark.change_state(Enums.EnemyState.CHASE)
	bulwark._update_state(STEP)
	assert_true(bulwark.current_state == Enums.EnemyState.ATTACK and bulwark.last_chosen_move == Bulwark.MOVE_STOMP,
			"Chasing a commander 5 m ahead: the boss stops and stomps")
	assert_true(is_equal_approx(bulwark.commander_stomp_cooldown_left, boss_data.commander_stomp_cooldown),
			"Stomping the commander starts its cooldown")
	assert_true(bulwark.choose_attack() == Bulwark.MOVE_CHASE, "On cooldown: no second stomp from range, the boss chases")
	bulwark.commander_stomp_cooldown_left = 0.0
	bulwark.t_away = 0.0
	assert_true(bulwark.choose_attack() == Bulwark.MOVE_STOMP, "Cooldown over: the stomp from range is back")
	cmd.free()
	bulwark.free()


func test_moves_unlock_by_appearance() -> void:
	print("
[GROUP 12] Moves unlock as the boss comes back")
	var bulwark := _make_bulwark()
	var cmd := _make_commander(Vector3.ZERO)
	bulwark.current_target = cmd
	bulwark.set_ai_seed(7)
	bulwark.current_armor_hp = 50  # below half HP so the combo is allowed when unlocked
	var behind := Vector3(0.0, 0.0, -2.0)
	var ahead := Vector3(0.0, 0.0, 2.0)

	var saw_combo := func() -> bool:
		cmd.global_position = ahead
		for i in range(60):
			if bulwark.choose_attack() == Bulwark.MOVE_COMBO:
				return true
		return false

	bulwark.spawn_wave = 5
	assert_true(bulwark.get_appearance() == 1, "Wave 5 is the first appearance")
	cmd.global_position = behind
	assert_true(bulwark.choose_attack() == Bulwark.MOVE_FACE, "Appearance 1, behind: no triple stomp yet, so it turns")
	assert_true(not saw_combo.call(), "Appearance 1, front at low HP: never the combo")

	bulwark.spawn_wave = 10
	cmd.global_position = behind
	assert_true(bulwark.choose_attack() == Bulwark.MOVE_TRIPLE, "Appearance 2, behind: triple stomp")
	assert_true(not saw_combo.call(), "Appearance 2, front at low HP: still no combo")

	bulwark.spawn_wave = 15
	assert_true(saw_combo.call(), "Appearance 3, front at low HP: the combo shows up")

	bulwark.in_hazard_trial = true
	assert_true(bulwark.get_moveset_appearance() == 2, "Hazard Trial boss on wave 15 fights like appearance 2")
	assert_true(not saw_combo.call(), "Hazard Trial boss on wave 15 has no combo")
	bulwark.spawn_wave = 5
	assert_true(bulwark.get_moveset_appearance() == 1, "Hazard Trial never drops below appearance 1")
	cmd.free()
	bulwark.free()


func test_chains_never_kill_full_commander() -> void:
	print("
[GROUP 13] A full chain leaves a full-health commander alive")
	var bulwark := _make_bulwark()
	var cmd := _make_commander(bulwark.get_stomp_center())
	bulwark.play_triple_stomp()
	_run_process(bulwark, bulwark.get_triple_stomp_step_length() * 3.0 + 0.1)
	print("  triple stomp, all three hits: %d" % cmd.damage_taken)
	assert_true(cmd.damage_taken < 100, "Triple stomp total is under 100 HP")
	cmd.damage_taken = 0
	bulwark.play_attack_combo_slam()
	_run_process(bulwark, 6.0)
	print("  combo, all three hits: %d" % cmd.damage_taken)
	assert_true(cmd.damage_taken < 100, "Combo total is under 100 HP")
	cmd.free()
	bulwark.free()


func test_stomp_lands_in_front() -> void:
	print("
[GROUP 14] Stomps land where the mace hits, 1.25 boss heights ahead")
	var bulwark := _make_bulwark()
	var height := bulwark.get_model_height()
	print("  model height %.2f m, stomp center %.2f m ahead" % [height, bulwark.get_stomp_forward_offset()])
	assert_true(height > 2.5 and height < 4.0, "Model height is measured from the meshes (3.17 m)")
	assert_true(is_equal_approx(bulwark.get_stomp_forward_offset(), height * 1.25), "Offset is 1.25 x height")
	var center := bulwark.get_stomp_center()
	assert_true(absf(center.x) < 0.01 and is_equal_approx(center.z, height * 1.25), "Center sits straight ahead of the boss")

	var telegraph_pos := [Vector3.INF]
	var on_tele := func(_k: StringName, pos: Vector3, _r: float, _d: float) -> void: telegraph_pos[0] = pos
	EventBus.telegraph_started.connect(on_tele)
	# One commander at a time: the stomp looks up the first node in the commander group.
	var at_boss := _make_commander(Vector3(0.0, 0.0, -0.5))
	bulwark.execute_stomp()
	assert_true(at_boss.damage_taken == 0, "Standing just behind the boss is outside the stomp")
	at_boss.free()
	var at_mace := _make_commander(center + Vector3(2.0, 0.0, 0.0))
	bulwark.execute_stomp()
	assert_true(at_mace.damage_taken == 45, "Standing 2 m from the impact point is hit")

	# The ring is fixed when it appears: turning the boss mid wind-up does not move the hit.
	at_mace.damage_taken = 0
	bulwark.play_triple_stomp()
	assert_true(telegraph_pos[0].distance_to(center) < 0.01, "Telegraph ring is drawn at the impact point")
	bulwark.rotation.y = PI
	_run_process(bulwark, 1.0)
	assert_true(at_mace.damage_taken > 0, "Hit lands on the ring even though the boss turned away")
	bulwark.stop_attack_sequence()
	EventBus.telegraph_started.disconnect(on_tele)
	at_mace.free()
	bulwark.free()

	print("\n[GROUP 15] Triple stomp locks facing and does not turn towards the commander during attack")
	bulwark = _make_bulwark()
	var behind := _make_commander(Vector3(0.0, 0.0, -2.5))
	bulwark.current_target = behind
	bulwark.play_triple_stomp()
	var rings: Array[Vector3] = []
	bulwark.attack_hit.connect(func(_id: int, _s: StringName, _t: Array) -> void: rings.append(bulwark.get_stomp_center()))
	_run_process(bulwark, bulwark.get_triple_stomp_step_length() * 3.0 + 0.1)
	var yaw := rad_to_deg(absf(angle_difference(0.0, bulwark.rotation.y)))
	print("  boss facing delta: %.1f degrees over the chain, commander damage: %d" % [yaw, behind.damage_taken])
	assert_true(yaw < 1.0, "Boss remains locked in facing and does not turn toward target during attack")
	behind.free()
	bulwark.free()


func _situation() -> BulwarkBrain.Situation:
	var s := BulwarkBrain.Situation.new()
	s.engaged = true
	s.in_front = true
	s.in_slash = true
	s.in_ring = false
	s.in_triple_reach = true
	s.has_objective = true
	s.combo_unlocked = true
	s.triple_unlocked = true
	s.triple_ready = true
	s.commander_stomp_ready = true
	return s


func _behind(s: BulwarkBrain.Situation) -> BulwarkBrain.Situation:
	s.in_front = false
	s.in_slash = false
	return s


func test_brain_scores() -> void:
	print("\n[GROUP 16] Utility scores pick the expected action")
	var d := BossData.new()
	var low := func() -> float: return 0.0
	var high := func() -> float: return 0.99
	var s := _situation()
	assert_true(BulwarkBrain.decide(s, d, low) == BulwarkBrain.NORMAL, "Front, in reach, full HP: normal attack")
	s.hp_fraction = 0.4
	assert_true(BulwarkBrain.decide(s, d, low) == BulwarkBrain.NORMAL and BulwarkBrain.decide(s, d, high) == BulwarkBrain.COMBO,
			"Below half HP the normal attack and the combo tie, the roll picks")
	s.combo_unlocked = false
	assert_true(BulwarkBrain.decide(s, d, high) == BulwarkBrain.NORMAL, "Combo locked: always the normal attack")

	s = _behind(_situation())
	assert_true(BulwarkBrain.decide(s, d, low) == BulwarkBrain.TRIPLE, "Behind, triple stomp ready: triple stomp")
	s.triple_ready = false
	s.t_away = 1.0
	assert_true(BulwarkBrain.decide(s, d, low) == BulwarkBrain.FACE, "Behind, triple stomp cooling down, 1 s away: turn")
	s.t_away = 5.0
	assert_true(BulwarkBrain.decide(s, d, low) == BulwarkBrain.PUSH, "Behind for 5 s: push on to the structures")
	s.triple_ready = true
	assert_true(BulwarkBrain.decide(s, d, low) == BulwarkBrain.PUSH, "Behind for 5 s: pushing on beats the triple stomp")
	s.has_objective = false
	s.t_away = 30.0
	assert_true(BulwarkBrain.decide(s, d, low) == BulwarkBrain.TRIPLE, "Hazard Trial (nothing to push on to): never pushes")

	s = _situation()
	s.engaged = false
	assert_true(BulwarkBrain.decide(s, d, low) == BulwarkBrain.PUSH, "Commander not minded: keep on at the structures")
	s.has_objective = false
	assert_true(BulwarkBrain.decide(s, d, low) == &"", "Nothing to fight and nothing to push on to: no action")

	s = _situation()
	s.push_committed = true
	s.pushing = true
	assert_true(BulwarkBrain.decide(s, d, low) == BulwarkBrain.PUSH, "Committed to pushing on: ignores a commander in reach")
	s.push_committed = false
	assert_true(BulwarkBrain.decide(s, d, low) == BulwarkBrain.NORMAL, "After the commitment, a commander in front and in reach pulls it back")

	s = _situation()
	s.in_slash = false
	s.in_ring = true
	assert_true(BulwarkBrain.decide(s, d, low) == BulwarkBrain.STOMP, "Front, out of slash reach, in the ring: the stomp")
	s.commander_stomp_ready = false
	assert_true(BulwarkBrain.decide(s, d, low) == BulwarkBrain.CHASE, "Stomp cooling down: chase")

	var scores := BulwarkBrain.score_all(_behind(_situation()), d)
	assert_true(is_equal_approx(float(scores[BulwarkBrain.PUSH]), d.weight_push * d.push_base),
			"Push starts at its base score while the commander has just left reach")


func test_t_away() -> void:
	print("\n[GROUP 17] Time out of reach")
	var bulwark := _make_bulwark()
	var cmd := _make_commander(Vector3(0.0, 0.0, -2.0))
	_run_process(bulwark, 1.0)
	assert_true(absf(bulwark.t_away - 1.0) < 0.05, "Commander behind: t_away counts up (%.2f s)" % bulwark.t_away)
	cmd.global_position = Vector3(0.0, 0.0, 2.0)
	_run_process(bulwark, 0.5)
	assert_true(bulwark.t_away > 0.9, "Commander passes through the front for 0.5 s: t_away only pauses (%.2f s)" % bulwark.t_away)
	_run_process(bulwark, 0.6)
	assert_true(bulwark.t_away == 0.0, "Commander stays in reach for 1 s: t_away resets")
	cmd.global_position = Vector3(0.0, 0.0, -2.0)
	_run_process(bulwark, 1.0)
	bulwark._on_commander_hit()
	assert_true(bulwark.t_away == 0.0, "Landing a hit on the commander resets t_away")
	cmd.global_position = Vector3(0.0, 0.0, -20.0)
	_run_process(bulwark, 1.0)
	assert_true(bulwark.t_away == 0.0, "Commander far away and not minded: t_away stays at 0")
	bulwark._pushing = true  # marching on to the structures as usual
	_run_process(bulwark, 3.0)
	cmd.global_position = Vector3(0.0, 0.0, -2.0)
	bulwark._process(STEP)
	assert_true(bulwark.t_away < 0.05, "Marching on, then the commander walks up behind: t_away starts from 0")
	bulwark._pushing = false
	cmd.global_position = Vector3(0.0, 0.0, -20.0)

	# Chasing the commander off the lane makes no lane progress; that is not being stuck.
	cmd.global_position = Vector3(0.0, 0.0, 3.0)
	bulwark.current_target = cmd
	bulwark.change_state(Enums.EnemyState.CHASE)
	for i in range(int(8.0 / STEP)):
		bulwark._update_stuck_detection(STEP)
	assert_true(bulwark._stuck_timer == 0.0 and bulwark._current_stuck_tier == 0, "Chasing the commander never counts as stuck")
	cmd.free()
	bulwark.free()


## A commander circling the boss at full run speed, stopping now and then to swing at it.
func _circle_commander(bulwark: Bulwark, cmd: MockCommander, seconds: float, on_step: Callable) -> void:
	var radius := 2.5
	var angle := 0.0
	var t := 0.0
	while t < seconds:
		var cycle := fmod(t, 1.6)
		if cycle < 1.0:
			angle += 6.0 / radius * STEP
		else:
			bulwark.provoked_by_player = true
			bulwark.provoked_timer = GameConfig.aggro_duration
		cmd.global_position = Vector3(radius * sin(angle), 0.0, radius * cos(angle))
		bulwark._update_state(STEP)
		bulwark._process(STEP)
		t += STEP
		if not on_step.call(t):
			return


func test_push_on_when_circled() -> void:
	print("\n[GROUP 18] A commander circling the boss gets it to push on to the structures")
	var bulwark := _make_bulwark()
	var boss_data := bulwark.data as BossData
	bulwark.spawn_wave = 5
	var fortress := MockFortress.new()
	add_child(fortress)
	fortress.global_position = Vector3(-30.0, 0.0, 0.0)
	var cmd := _make_commander(Vector3(0.0, 0.0, 2.5))
	bulwark.current_target = cmd
	bulwark.change_state(Enums.EnemyState.CHASE)
	var pushed_at := [-1.0]
	_circle_commander(bulwark, cmd, 20.0, func(t: float) -> bool:
		if bulwark.current_target == fortress:
			pushed_at[0] = t
			return false
		return true)
	print("  pushed on after %.1f s, commander took %d damage" % [pushed_at[0], cmd.damage_taken])
	assert_true(pushed_at[0] > 0.0 and pushed_at[0] < 12.0, "Boss leaves the circling commander for the Fortress")
	assert_true(bulwark.provoked_by_player == false, "Pushing on drops the commander's aggro")

	var held := [true]
	_circle_commander(bulwark, cmd, boss_data.push_commit_time - 0.2, func(_t: float) -> bool:
		if bulwark.current_target != fortress:
			held[0] = false
		return true)
	assert_true(held[0], "Hits from the commander do not pull the boss back during the commitment")
	cmd.free()
	fortress.free()
	bulwark.free()


func test_hazard_turns_faster() -> void:
	print("\n[GROUP 19] Hazard Trial: no structures, a faster turn instead")
	var bulwark := _make_bulwark()
	var boss_data := bulwark.data as BossData
	var base_rate := bulwark.get_turn_rate_rad()
	bulwark.in_hazard_trial = true
	assert_true(is_equal_approx(bulwark.get_turn_rate_rad(), base_rate * boss_data.hazard_turn_rate_mult),
			"Hazard Trial boss turns %.0fx faster (%.0f deg/s)" % [boss_data.hazard_turn_rate_mult, rad_to_deg(bulwark.get_turn_rate_rad())])
	bulwark.free()

	for hazard in [false, true]:
		bulwark = _make_bulwark()
		bulwark.spawn_wave = 5
		bulwark.in_hazard_trial = hazard
		var cmd := _make_commander(Vector3(0.0, 0.0, 2.5))
		bulwark.current_target = cmd
		bulwark.change_state(Enums.EnemyState.CHASE)
		var left := [false]
		_circle_commander(bulwark, cmd, 20.0, func(_t: float) -> bool:
			if bulwark.current_target != cmd:
				left[0] = true
			return true)
		var label := "Hazard Trial" if hazard else "No structures on the map"
		print("  %s: commander circling for 20 s took %d damage" % [label, cmd.damage_taken])
		assert_true(not left[0], "%s: the boss stays on the commander" % label)
		if hazard:
			assert_true(cmd.damage_taken > 0, "Hazard Trial: the faster turn catches a circling commander")
		cmd.free()
		bulwark.free()


func test_structure_turn_first() -> void:
	print("\n[GROUP 20] A structure beside the boss: turn on the spot, then stomp it")
	var bulwark := _make_bulwark()
	var tower := MockTower.new()
	add_child(tower)
	tower.global_position = Vector3(3.0, 0.0, 0.0)  # 90 degrees off the boss's facing
	bulwark.current_target = tower
	bulwark.change_state(Enums.EnemyState.ATTACK)
	assert_true(bulwark.last_chosen_move != Bulwark.MOVE_STOMP, "Ring would miss the tower: no stomp yet")
	var moved := false
	var t := 0.0
	while t < 4.0 and tower.damage_taken == 0:
		bulwark._update_state(STEP)
		bulwark._process(STEP)
		if bulwark.velocity.x != 0.0 or bulwark.velocity.z != 0.0:
			moved = true
		t += STEP
	var facing := rad_to_deg(absf(angle_difference(bulwark.rotation.y, atan2(3.0, 0.0))))
	print("  first stomp hit the tower after %.2f s, facing %.1f deg off" % [t, facing])
	assert_true(tower.damage_taken > 0, "The first stomp lands on the tower")
	assert_true(not moved, "The boss turns on the spot (it does not walk off its point)")
	tower.free()
	bulwark.free()

	# At the Fortress the attack point is the melee point under the boss; it still turns to the wall.
	bulwark = _make_bulwark()
	var melee_point := Marker3D.new()
	melee_point.add_to_group(&"boss_melee_point")
	add_child(melee_point)
	melee_point.global_position = Vector3.ZERO
	var fortress := MockFortress.new()
	add_child(fortress)
	fortress.global_position = Vector3(-3.0, 0.0, 0.0)
	var fortress_hit := [false]
	bulwark.attack_hit.connect(func(_id: int, _s: StringName, targets: Array) -> void:
		if targets.has(fortress):
			fortress_hit[0] = true)
	bulwark.current_target = fortress
	bulwark.change_state(Enums.EnemyState.ATTACK)
	t = 0.0
	while t < 4.0 and not fortress_hit[0]:
		bulwark._update_state(STEP)
		bulwark._process(STEP)
		t += STEP
	print("  Fortress 90 deg off: first stomp hit it after %.2f s" % t)
	assert_true(fortress_hit[0], "Fortress beside the boss at its melee point: turns, then the stomp hits the Fortress")
	assert_true(bulwark.global_position.distance_to(melee_point.global_position) < 0.01, "The boss stays on its melee point")
	fortress.free()
	melee_point.free()
	bulwark.free()


func test_no_structures_keeps_fighting() -> void:
	print("
[GROUP 21] Nothing to push on to: the boss never gives up on the commander")
	var bulwark := _make_bulwark()
	var cmd := _make_commander(Vector3(0.0, 0.0, 6.0))
	bulwark.current_target = cmd
	assert_true(bulwark.choose_attack() == &"", "Commander 6 m away, not minded, no structures: no action")
	bulwark.taunted_by_player = true  # the AI test arena keeps the boss on the commander this way
	assert_true(BulwarkBrain.is_commander_action(bulwark.choose_attack()), "A taunt makes the boss mind the commander")
	bulwark.taunted_by_player = false
	bulwark.change_state(Enums.EnemyState.CHASE)
	for i in range(30):
		bulwark._update_state(STEP)
		bulwark._process(STEP)
	assert_true(bulwark.push_commit_left == 0.0, "No action does not count as leaving the commander")
	bulwark.rotation.y = 0.0  # it turned while walking; face the commander again
	cmd.global_position = Vector3(0.0, 0.0, 2.0)
	bulwark.change_state(Enums.EnemyState.ADVANCE)
	bulwark.current_target = cmd
	bulwark.change_state(Enums.EnemyState.ATTACK)
	assert_true(bulwark.last_chosen_move == Bulwark.MOVE_NORMAL, "Commander walks up in front: the boss swings")
	cmd.free()
	bulwark.free()


class MockCommander extends Node3D:
	var is_dodging: bool = false
	var is_deploying: bool = false
	var damage_taken: int = 0
	var knockback_taken: float = 0.0
	var last_type: Enums.DamageType = Enums.DamageType.TRUE

	func _init() -> void:
		add_to_group(&"commander")

	func take_damage(info: DamageInfo) -> void:
		damage_taken += info.amount
		knockback_taken = info.knockback_force
		last_type = info.damage_type


class MockTower extends Node3D:
	var damage_taken: int = 0

	func _init() -> void:
		add_to_group(&"tower")

	func take_damage(info: DamageInfo) -> void:
		damage_taken += info.amount


class MockFortress extends Node3D:
	func _init() -> void:
		add_to_group(&"fortress")

	func take_damage(_info: DamageInfo) -> void:
		pass
