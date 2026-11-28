extends Node
## Acceptance scene for BladeTempestSkill and the strike helpers it shares with Whirlwind and Sword Wave.

const BLADE_TEMPEST: SkillData = preload("res://data/skills/blade_tempest.tres")
const WHIRL_DAMAGE := 25
const WAVE_DAMAGE := 24
const STEP := 1.0 / 60.0

var passes: int = 0
var fails: int = 0
var _waves_seen: int = 0
var _ended_seen: int = 0


class DummyCaster extends Node3D:
	var aim_dir: Vector3 = Vector3.FORWARD
	var is_commander_mode: bool = false
	var is_dead: bool = false


class DummyEnemy extends Node3D:
	var is_dead: bool = false
	var hits: Array[DamageInfo] = []

	func take_damage(info: DamageInfo) -> void:
		hits.append(info)

	func count(amount: int) -> int:
		var total := 0
		for info in hits:
			if info.amount == amount:
				total += 1
		return total


func _ready() -> void:
	print("\n=======================================================")
	print("              BLADE TEMPEST VERIFICATION                ")
	print("=======================================================")

	test_wave_dir_clockwise()
	test_wave_count_per_level()
	test_wave_order_is_world_locked()
	test_whirl_hits_per_level()
	test_whirl_interval_survives_leaving()
	test_wave_starts_at_ring_edge()
	await test_wave_stops_at_wall()
	test_data_and_strings()
	test_channel_emits_waves()
	test_stops_on_commander_mode()
	test_stops_on_death()
	test_stops_on_other_skill()
	test_stops_on_run_started()
	test_paused_and_x3()
	test_cooldown_full_after_cut()
	test_commander_hooks()
	test_spin_loops_while_channelling()
	test_spin_not_replayed_after_dodge()
	test_spin_not_replayed_after_channel_end()
	test_spin_resumes_in_loop_after_hit()
	test_whirl_schedule_ignores_tick_size()
	test_import_state_stops_channel()
	test_stops_on_run_ended()
	test_exit_tree_ends_channel()

	print("=======================================================")
	print("BLADE TEMPEST TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================")
	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


func _new_caster() -> DummyCaster:
	var caster := DummyCaster.new()
	add_child(caster)
	caster.global_position = Vector3.ZERO
	return caster


func _new_enemy(pos: Vector3) -> DummyEnemy:
	var enemy := DummyEnemy.new()
	enemy.add_to_group(&"enemy")
	add_child(enemy)
	enemy.global_position = pos
	return enemy


func _near(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < 0.0001


## Ticks until the channel ends; returns the elapsed time at which each wave fired.
## Does not hook on_wave: a lambda capturing the skill would make a reference cycle.
func _run_channel(skill: BladeTempestSkill) -> Array[float]:
	var fired: Array[float] = []
	var guard := 0
	while guard < 1000:
		var before := skill.waves_fired
		var running := skill.tick(STEP)
		for i in skill.waves_fired - before:
			fired.append(skill.elapsed)
		if not running:
			break
		guard += 1
	return fired


func test_wave_dir_clockwise() -> void:
	print("\n[GROUP 1] wave_dir_clockwise")
	assert_true(_near(BladeTempestSkill.wave_dir(0, 0.0), Vector3(1, 0, 0)), "index 0 points along +X")
	var second := BladeTempestSkill.wave_dir(1, 0.0)
	assert_true(_near(second, Vector3(cos(deg_to_rad(72.0)), 0, sin(deg_to_rad(72.0)))) and second.z > 0.0, "index 1 is 72 degrees on, towards +Z")
	assert_true(_near(BladeTempestSkill.wave_dir(5, 0.0), BladeTempestSkill.wave_dir(0, 0.0)), "index 5 wraps to index 0")
	assert_true(_near(BladeTempestSkill.wave_dir(0, 90.0), Vector3(0, 0, 1)), "start angle 90 begins along +Z")


func test_wave_count_per_level() -> void:
	print("\n[GROUP 2] wave_count_per_level")
	var caster := _new_caster()
	var expected := [15, 20, 26]
	for level in [1, 2, 3]:
		var skill := BladeTempestSkill.new(caster, BLADE_TEMPEST, level, 1.0)
		var fired := _run_channel(skill)
		assert_true(skill.waves_fired == expected[level - 1], "level %d fires %d waves (got %d)" % [level, expected[level - 1], skill.waves_fired])
		if level == 1:
			assert_true(not fired.is_empty() and absf(fired[0] - 0.3) <= STEP + 0.0001, "first wave at about 0.3 s")
		assert_true(fired.is_empty() or fired.back() < 2.7,"level %d: no wave from 2.7 s on" % level)
	caster.free()


func test_wave_order_is_world_locked() -> void:
	print("\n[GROUP 3] wave_order_is_world_locked")
	var caster := _new_caster()
	var skill := BladeTempestSkill.new(caster, BLADE_TEMPEST, 1, 1.0)
	var dirs: Array[Vector3] = []
	skill.on_wave = func(_origin: Vector3, dir: Vector3) -> void: dirs.append(dir)
	var step := 0
	while skill.tick(STEP):
		step += 1
		caster.rotation.y += 0.2
		caster.aim_dir = Vector3(cos(step), 0, sin(step))
	var matches := dirs.size() == 15
	for i in dirs.size():
		if not _near(dirs[i], BladeTempestSkill.wave_dir(i % 5, 0.0)):
			matches = false
	assert_true(matches, "15 waves keep the n %% 5 order while the caster turns and re-aims")
	caster.free()


func test_whirl_hits_per_level() -> void:
	print("\n[GROUP 4] whirl_hits_per_level")
	var caster := _new_caster()
	var expected := [3, 5, 6]
	for level in [1, 2, 3]:
		var enemy := _new_enemy(Vector3(0, 0, -1))
		_run_channel(BladeTempestSkill.new(caster, BLADE_TEMPEST, level, 1.0))
		assert_true(enemy.count(WHIRL_DAMAGE) == expected[level - 1], "level %d: %d whirl hits of 25 (got %d)" % [level, expected[level - 1], enemy.count(WHIRL_DAMAGE)])
		enemy.free()
	caster.free()


func test_whirl_interval_survives_leaving() -> void:
	print("\n[GROUP 5] whirl_interval_survives_leaving (RF4)")
	var caster := _new_caster()
	var enemy := _new_enemy(Vector3(0, 0, -1))
	var skill := BladeTempestSkill.new(caster, BLADE_TEMPEST, 1, 1.0)
	var first_contact := false
	var hits_before_one_second := 0
	while skill.elapsed < 0.99:
		var away := skill.elapsed >= 0.2 and skill.elapsed < 0.5
		enemy.global_position = Vector3(0, 0, -6) if away else Vector3(0, 0, -1)
		skill.tick(STEP)
		if skill.elapsed < STEP * 1.5:
			first_contact = enemy.count(WHIRL_DAMAGE) == 1
		hits_before_one_second = enemy.count(WHIRL_DAMAGE)
	assert_true(first_contact, "first contact hits at once")
	assert_true(hits_before_one_second == 1, "no second hit inside the interval after leaving and returning (got %d)" % hits_before_one_second)
	enemy.free()
	caster.free()


func test_wave_starts_at_ring_edge() -> void:
	print("\n[GROUP 6] wave_starts_at_ring_edge")
	var caster := _new_caster()
	var inside := _new_enemy(Vector3(2.0, 0, 0))
	var outside := _new_enemy(Vector3(3.5, 0, 0))
	_run_channel(BladeTempestSkill.new(caster, BLADE_TEMPEST, 1, 1.0))
	assert_true(inside.count(WAVE_DAMAGE) == 0, "enemy 2 m out takes no wave damage")
	assert_true(inside.count(WHIRL_DAMAGE) > 0, "enemy 2 m out is still in the ring")
	assert_true(outside.count(WAVE_DAMAGE) > 0, "enemy 3.5 m out takes wave damage")
	inside.free()
	outside.free()
	caster.free()


func test_wave_stops_at_wall() -> void:
	print("\n[GROUP 7] wave_stops_at_wall (RF2)")
	# Whirl hits are 25, wave hits 24, so a 5 m enemy outside the ring can only take wave damage.
	var caster := _new_caster()
	# Control: with no wall the same enemy 5 m out is hit by the waves.
	var open := _new_enemy(Vector3(5.0, 0, 0))
	_run_channel(BladeTempestSkill.new(caster, BLADE_TEMPEST, 1, 1.0))
	assert_true(open.count(WAVE_DAMAGE) > 0, "control: enemy 5 m out takes wave damage without a wall")
	open.free()
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 3.0, 8.0)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = Vector3(4.0, 1.0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var behind := _new_enemy(Vector3(5.0, 0, 0))
	_run_channel(BladeTempestSkill.new(caster, BLADE_TEMPEST, 1, 1.0))
	assert_true(behind.count(WAVE_DAMAGE) == 0, "enemy behind a wall at 4 m takes no wave damage")
	behind.free()
	wall.free()
	caster.free()


func test_data_and_strings() -> void:
	print("\n[GROUP 8] data validates, strings exist")
	assert_true(BLADE_TEMPEST.validate().is_empty(), "blade_tempest.tres has three values per key")
	assert_true(BLADE_TEMPEST.id == &"blade_tempest" and BLADE_TEMPEST.kind == SkillData.Kind.ACTIVE, "id and kind")
	assert_true(BLADE_TEMPEST.damage_type == Enums.DamageType.SLASH, "damage type is SLASH")
	var csv := FileAccess.get_file_as_string("res://data/locale/strings.csv")
	assert_true(csv.contains("skill.blade_tempest.name,") and csv.contains("skill.blade_tempest.desc,"), "locale keys present")


func _on_wave_fired(_id: StringName, _origin: Vector3, _dir: Vector3, _level: int) -> void:
	_waves_seen += 1


func _on_channel_ended(_id: StringName) -> void:
	_ended_seen += 1


## Runner with Blade Tempest in slot 0, counting the two channel signals.
func _new_runner(caster: Node3D) -> SkillRunner:
	var runner := SkillRunner.new()
	runner.caster = caster
	add_child(runner)
	EventBus.reward_picked.emit(&"blade_tempest", &"ACTIVE", 1)
	_waves_seen = 0
	_ended_seen = 0
	EventBus.skill_wave_fired.connect(_on_wave_fired)
	EventBus.skill_channel_ended.connect(_on_channel_ended)
	return runner


func _free_runner(runner: SkillRunner, caster: Node3D) -> void:
	EventBus.skill_wave_fired.disconnect(_on_wave_fired)
	EventBus.skill_channel_ended.disconnect(_on_channel_ended)
	runner.free()
	caster.free()


func _tick_for(runner: SkillRunner, seconds: float, step: float = STEP) -> void:
	var done := 0.0
	while done < seconds - 0.0001:
		runner.tick(step)
		done += step


func test_channel_emits_waves() -> void:
	print("\n[GROUP 9] channel_emits_waves")
	var caster := _new_caster()
	var runner := _new_runner(caster)
	var data := runner.activate(0)
	assert_true(data != null and runner.is_channeling(), "activate starts the channel")
	_tick_for(runner, 3.2)
	assert_true(_waves_seen == 15, "15 skill_wave_fired at level 1 (got %d)" % _waves_seen)
	assert_true(_ended_seen == 1, "one skill_channel_ended (got %d)" % _ended_seen)
	assert_true(not runner.is_channeling(), "not channelling afterwards")
	assert_true(absf(runner.get_cooldown_left(0) - 4.8) < 0.1, "cooldown about 8 - 3.2 left (got %.2f)" % runner.get_cooldown_left(0))
	_free_runner(runner, caster)


func test_stops_on_commander_mode() -> void:
	print("\n[GROUP 10] stops_on_commander_mode (RF1)")
	var caster := _new_caster()
	var runner := _new_runner(caster)
	runner.activate(0)
	_tick_for(runner, 1.0)
	caster.is_commander_mode = true
	runner.tick(STEP)
	var waves := _waves_seen
	_tick_for(runner, 1.0)
	assert_true(not runner.is_channeling() and _ended_seen == 1, "channel ends once on Commander mode")
	assert_true(_waves_seen == waves, "no wave after the cut")
	_free_runner(runner, caster)


func test_stops_on_death() -> void:
	print("\n[GROUP 11] stops_on_death (RF1)")
	var caster := _new_caster()
	var runner := _new_runner(caster)
	runner.activate(0)
	_tick_for(runner, 1.0)
	caster.is_dead = true
	runner.tick(STEP)
	var waves := _waves_seen
	_tick_for(runner, 1.0)
	assert_true(not runner.is_channeling() and _ended_seen == 1, "channel ends once on death")
	assert_true(_waves_seen == waves, "no wave after death")
	_free_runner(runner, caster)


func test_stops_on_other_skill() -> void:
	print("\n[GROUP 12] stops_on_other_skill")
	var caster := _new_caster()
	var runner := _new_runner(caster)
	EventBus.reward_picked.emit(&"whirlwind", &"ACTIVE", 1)
	runner.activate(0)
	_tick_for(runner, 1.0)
	var casts: Array[StringName] = []
	var on_cast := func(id: StringName, _s: int, _l: int, _o: Vector3, _r: float) -> void: casts.append(id)
	EventBus.skill_cast.connect(on_cast)
	var other := runner.activate(1)
	EventBus.skill_cast.disconnect(on_cast)
	assert_true(other != null and other.id == &"whirlwind", "whirlwind casts")
	assert_true(not runner.is_channeling() and _ended_seen == 1, "channel ended by the other cast")
	assert_true(casts == [&"whirlwind"], "only the whirlwind cast was announced")
	_free_runner(runner, caster)


func test_stops_on_run_started() -> void:
	print("\n[GROUP 13] stops_on_run_started (RF5)")
	var caster := _new_caster()
	var runner := _new_runner(caster)
	runner.activate(0)
	_tick_for(runner, 1.0)
	EventBus.run_started.emit()
	assert_true(not runner.is_channeling() and _ended_seen == 1, "channel gone and announced as ended")
	assert_true(runner.get_skill_id(0) == &"", "slots are empty")
	var waves := _waves_seen
	_tick_for(runner, 1.0)
	assert_true(_waves_seen == waves, "no wave after the restart")
	_free_runner(runner, caster)


func test_paused_and_x3() -> void:
	print("\n[GROUP 14] paused_and_x3 (RF3)")
	var caster := _new_caster()
	var runner := _new_runner(caster)
	runner.activate(0)
	_tick_for(runner, 1.0)
	var waves := _waves_seen
	for i in 100:
		runner.tick(0.0)
	assert_true(_waves_seen == waves and runner.is_channeling(), "100 frames of delta 0 change nothing")
	_free_runner(runner, caster)

	caster = _new_caster()
	runner = _new_runner(caster)
	runner.activate(0)
	_tick_for(runner, 3.2, 3.0 * STEP)
	assert_true(_waves_seen == 15 and _ended_seen == 1, "x3 deltas give 15 waves and one end (got %d, %d)" % [_waves_seen, _ended_seen])
	_free_runner(runner, caster)


func test_cooldown_full_after_cut() -> void:
	print("\n[GROUP 15] cooldown_full_after_cut")
	var caster := _new_caster()
	var runner := _new_runner(caster)
	runner.activate(0)
	_tick_for(runner, 0.5)
	runner.stop_channel()
	runner.stop_channel()
	assert_true(_ended_seen == 1, "stop_channel announces once")
	assert_true(absf(runner.get_cooldown_left(0) - 7.5) < 0.1, "cooldown keeps counting from the 8 s at the cast (got %.2f)" % runner.get_cooldown_left(0))
	_free_runner(runner, caster)


## Whirl hits taken by an enemy that is in the ring from t = 0, or only from enter_at on, at the given tick size.
func _whirl_hits(level: int, step: float, enter_at: float) -> int:
	var caster := _new_caster()
	var enemy := _new_enemy(Vector3(0, 0, -1) if enter_at <= 0.0 else Vector3(0, 0, -8))
	var skill := BladeTempestSkill.new(caster, BLADE_TEMPEST, level, 1.0)
	var running := true
	while running:
		if enter_at > 0.0 and skill.elapsed >= enter_at - 0.0001:
			enemy.global_position = Vector3(0, 0, -1)
		running = skill.tick(step)
	var hits := enemy.count(WHIRL_DAMAGE)
	enemy.free()
	caster.free()
	return hits


func test_whirl_schedule_ignores_tick_size() -> void:
	print("\n[GROUP 17] whirl_schedule_ignores_tick_size")
	var expected := [3, 5, 6]
	for level in [1, 2, 3]:
		for step in [STEP, 3.0 * STEP]:
			var hits := _whirl_hits(level, step, 0.0)
			assert_true(hits == expected[level - 1], "level %d, step %.4f: %d hits from t=0 (got %d)" % [level, step, expected[level - 1], hits])
	var fine := _whirl_hits(3, STEP, 0.05)
	var coarse := _whirl_hits(3, 3.0 * STEP, 0.05)
	assert_true(fine == coarse, "level 3 enemy entering at 0.05 s: same hits at both tick sizes (%d vs %d)" % [fine, coarse])


func test_import_state_stops_channel() -> void:
	print("\n[GROUP 18] import_state_stops_channel")
	var caster := _new_caster()
	var runner := _new_runner(caster)
	runner.activate(0)
	_tick_for(runner, 1.0)
	var saved := runner.export_state()
	runner.import_state(saved)
	assert_true(not runner.is_channeling() and _ended_seen == 1, "import_state ends the channel once (ended %d)" % _ended_seen)
	var waves := _waves_seen
	_tick_for(runner, 1.0)
	assert_true(_waves_seen == waves, "no wave after the import")
	_free_runner(runner, caster)


func test_stops_on_run_ended() -> void:
	print("\n[GROUP 19] stops_on_run_ended")
	var caster := _new_caster()
	var runner := _new_runner(caster)
	runner.activate(0)
	_tick_for(runner, 1.0)
	# Emitting the real signal would also drive GameState and SaveManager, so call the connected handler.
	assert_true(EventBus.run_ended.is_connected(runner._on_run_ended), "runner listens to run_ended")
	runner._on_run_ended(&"ABANDONED", {})
	assert_true(not runner.is_channeling() and _ended_seen == 1, "run_ended stops the channel once (ended %d)" % _ended_seen)
	var waves := _waves_seen
	_tick_for(runner, 1.0)
	assert_true(_waves_seen == waves, "no wave after run_ended")
	_free_runner(runner, caster)


func test_exit_tree_ends_channel() -> void:
	print("\n[GROUP 20] exit_tree_ends_channel")
	var caster := _new_caster()
	var runner := _new_runner(caster)
	runner.activate(0)
	_tick_for(runner, 0.5)
	runner.free()
	assert_true(_ended_seen == 1, "freeing the runner mid-channel announces the end once (got %d)" % _ended_seen)
	EventBus.skill_wave_fired.disconnect(_on_wave_fired)
	EventBus.skill_channel_ended.disconnect(_on_channel_ended)
	caster.free()


func _new_commander() -> CharacterBody3D:
	var commander: CharacterBody3D = (load("res://entities/commander/commander.tscn") as PackedScene).instantiate()
	add_child(commander)
	commander.set_physics_process(false)
	EventBus.reward_picked.emit(&"blade_tempest", &"ACTIVE", 1)
	return commander


## Commander that has just cast Blade Tempest; the cast animation lock is cleared so other actions can start.
func _channelling_commander() -> CharacterBody3D:
	var commander := _new_commander()
	commander._try_skill(0)
	commander._end_skill()
	return commander


func test_commander_hooks() -> void:
	print("\n[GROUP 16] commander hooks")
	var camera := Camera3D.new()
	add_child(camera)

	var commander := _channelling_commander()
	assert_true(commander.skill_runner.is_channeling(), "commander is channelling")
	commander._try_attack()
	assert_true(not commander.is_attacking, "attack does nothing while channelling")
	commander.skill_runner.stop_channel()
	commander._try_attack()
	assert_true(commander.is_attacking, "attack works once the channel is over")
	commander.free()

	commander = _channelling_commander()
	commander._try_dodge(camera)
	assert_true(commander.is_dodging and not commander.skill_runner.is_channeling(), "dodge ends the channel")
	commander.free()

	commander = _channelling_commander()
	commander._try_battle_cry()
	assert_true(commander.is_using_skill and not commander.skill_runner.is_channeling(), "battle cry ends the channel")
	commander.free()

	commander = _channelling_commander()
	commander._dodge_cooldown_timer = 5.0
	commander._try_dodge(camera)
	assert_true(commander.skill_runner.is_channeling(), "a refused dodge keeps the channel")
	commander.free()
	camera.free()


## Advances game time by seconds the way the physics loop would: runner tick, animation, loop check.
func _step_commander(commander: CharacterBody3D, seconds: float) -> void:
	var done := 0.0
	while done < seconds - 0.0001:
		commander.skill_runner.tick(STEP)
		commander._anim_player.advance(STEP)
		commander._keep_channel_spin_playing()
		done += STEP


func _spin_playing(commander: CharacterBody3D) -> bool:
	var anim: AnimationPlayer = commander._anim_player
	return anim.is_playing() and anim.current_animation == commander.COMBO_ANIM_CLIPS[2]


func _spin_pos(commander: CharacterBody3D) -> float:
	return commander._anim_player.current_animation_position


func test_spin_loops_while_channelling() -> void:
	print("
[GROUP 17] spin segment loops during the channel")
	var commander := _channelling_commander()
	var anim: AnimationPlayer = commander._anim_player
	assert_true(anim != null and anim.has_animation(commander.COMBO_ANIM_CLIPS[2]), "commander has the spin clip")
	assert_true(is_equal_approx(anim.get_playing_speed(), commander.channel_spin_anim_speed), "cast plays the spin at the channel speed")
	var loop_start: float = commander.channel_spin_loop_start
	var loop_end: float = commander.channel_spin_loop_end
	var max_pos := 0.0
	var inside_at_1_5 := false
	var inside_at_2_8 := false
	var loops_seen := 0
	var last_pos := 0.0
	var t := 0.0
	while t < 2.8 - 0.0001:
		_step_commander(commander, STEP)
		t += STEP
		var pos := _spin_pos(commander)
		max_pos = maxf(max_pos, pos)
		if pos < last_pos - 0.1:
			loops_seen += 1
		last_pos = pos
		if absf(t - 1.5) < STEP * 0.5:
			inside_at_1_5 = _spin_playing(commander) and pos >= loop_start and pos <= loop_end
	inside_at_2_8 = _spin_playing(commander) and _spin_pos(commander) >= loop_start and _spin_pos(commander) <= loop_end
	assert_true(inside_at_1_5, "spin is playing inside the loop at 1.5 s")
	assert_true(inside_at_2_8, "spin is playing inside the loop at 2.8 s")
	assert_true(max_pos <= loop_end, "position never passes the loop end while channelling")
	assert_true(loops_seen >= 2, "the segment wrapped at least twice")
	commander.free()


func test_spin_not_replayed_after_dodge() -> void:
	print("
[GROUP 18] spin clip not replayed after a dodge")
	var camera := Camera3D.new()
	add_child(camera)
	var commander := _channelling_commander()
	_step_commander(commander, 1.0)
	commander._try_dodge(camera)
	var current: String = commander._anim_player.current_animation
	assert_true(current.begins_with("advance/Dodge"), "dodge clip replaces the spin")
	_step_commander(commander, 0.2)
	assert_true(commander._anim_player.current_animation == current, "dodge clip is still the current animation")
	commander.free()
	camera.free()


func test_spin_not_replayed_after_channel_end() -> void:
	print("
[GROUP 19] recovery plays after the channel ends")
	var commander := _channelling_commander()
	_step_commander(commander, 1.0)
	commander.skill_runner.stop_channel()
	var loop_end: float = commander.channel_spin_loop_end
	var passed_end := false
	var replayed := false
	var t := 0.0
	while t < 1.0:
		_step_commander(commander, STEP)
		t += STEP
		if _spin_playing(commander) and _spin_pos(commander) > loop_end:
			passed_end = true
		if passed_end and _spin_playing(commander) and _spin_pos(commander) < loop_end:
			replayed = true
	assert_true(passed_end, "position goes past the loop end once the channel is over")
	assert_true(not replayed, "spin is not looped again after the channel")
	assert_true(not _spin_playing(commander), "the clip has finished after its recovery")
	commander.free()


func test_spin_resumes_in_loop_after_hit() -> void:
	print("
[GROUP 20] spin resumes in the loop after a hit clip")
	var commander := _channelling_commander()
	_step_commander(commander, 1.0)
	commander._anim_player.play(commander.ANIM_HIT)
	assert_true(commander._anim_player.current_animation == commander.ANIM_HIT, "hit clip cuts the spin")
	commander._keep_channel_spin_playing()
	assert_true(_spin_playing(commander), "spin plays again")
	assert_true(absf(_spin_pos(commander) - commander.channel_spin_loop_start) < 0.001, "resumes at the loop start, no second wind-up")
	commander.free()
