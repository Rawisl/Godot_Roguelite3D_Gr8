extends Node
## F6 acceptance scene for SkillRunner and Whirlwind. Prints PASS/FAIL then quits.

var passes: int = 0
var fails: int = 0
var _commander: CharacterBody3D


func _ready() -> void:
	print("\n=======================================================")
	print("          SKILL RUNNER + WHIRLWIND VERIFICATION          ")
	print("=======================================================")

	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 10, 10)
	camera.rotation_degrees = Vector3(-45, 0, 0)
	camera.make_current()

	test_slots_and_levels()
	test_whirlwind_table()
	await test_whirlwind_hits()
	await test_cooldown_clamp_and_damage_mult()
	await test_keys_and_modes()
	await test_cooldown_time_scale()

	print("=======================================================")
	print("SKILL RUNNER TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================")
	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


func _new_commander() -> CharacterBody3D:
	var commander: CharacterBody3D = (load("res://entities/commander/commander.tscn") as PackedScene).instantiate()
	add_child(commander)
	commander.global_position = Vector3.ZERO
	commander.set_physics_process(false)  # tests step by hand where they need to
	return commander


func _new_enemy(scene: String, pos: Vector3) -> Enemy:
	var enemy: Enemy = (load(scene) as PackedScene).instantiate()
	add_child(enemy)
	enemy.global_position = pos
	enemy.spawn_grace = false
	enemy.is_in_spawn_zone = false
	enemy.set_physics_process(false)
	return enemy


func _dummy_active(id: StringName) -> SkillData:
	var data := SkillData.new()
	data.id = id
	data.kind = SkillData.Kind.ACTIVE
	data.values = {&"cooldown": PackedFloat32Array([1, 1, 1])}
	return data


func test_slots_and_levels() -> void:
	print("\n[GROUP 1] Slots fill from the smallest empty one, levels follow reward_picked")
	var runner := SkillRunner.new()
	add_child(runner)
	var whirlwind: SkillData = load("res://data/skills/whirlwind.tres")
	runner.catalog = [whirlwind, _dummy_active(&"b"), _dummy_active(&"c"), _dummy_active(&"d")]

	assert_true(runner.get_skill_id(0) == &"", "slots start empty")
	EventBus.reward_picked.emit(&"whirlwind", &"ACTIVE", 1)
	assert_true(runner.get_skill_id(0) == &"whirlwind" and runner.get_level(0) == 1, "first skill takes slot 1 at level 1")
	EventBus.reward_picked.emit(&"whirlwind", &"ACTIVE", 2)
	assert_true(runner.get_skill_id(0) == &"whirlwind" and runner.get_level(0) == 2, "same card levels up in place")
	EventBus.reward_picked.emit(&"b", &"active", 1)
	assert_true(runner.get_skill_id(1) == &"b", "second skill takes slot 2 (slot_kind is case-insensitive)")
	EventBus.reward_picked.emit(&"c", &"ACTIVE", 1)
	assert_true(runner.get_skill_id(2) == &"c", "third skill takes slot 3")
	EventBus.reward_picked.emit(&"d", &"ACTIVE", 1)
	assert_true(runner.state.active.find(&"d") == -1, "a fourth skill finds no slot")
	EventBus.reward_picked.emit(&"whirlwind", &"ACTIVE", 3)
	assert_true(runner.get_level(0) == 3, "level 3 reached")
	EventBus.reward_picked.emit(&"whirlwind", &"ACTIVE", 9)
	assert_true(runner.get_level(0) == 3, "level is capped at skill_max_level")
	EventBus.reward_picked.emit(&"sharpness", &"PASSIVE", 1)
	assert_true(runner.state.active.find(&"sharpness") == -1, "passive cards are ignored")
	runner.free()


func test_whirlwind_table() -> void:
	print("\n[GROUP 2] Whirlwind numbers from SkillData")
	var data: SkillData = load("res://data/skills/whirlwind.tres")
	var damage := [15.0, 20.0, 25.0]
	var cooldown := [6.0, 5.5, 5.0]
	for i in 3:
		assert_true(is_equal_approx(data.get_value(&"damage", i + 1), damage[i]), "level %d damage %d" % [i + 1, damage[i]])
		assert_true(is_equal_approx(data.get_value(&"cooldown", i + 1), cooldown[i]), "level %d cooldown %.1f s" % [i + 1, cooldown[i]])
		assert_true(is_equal_approx(data.get_value(&"radius", i + 1), 3.0), "level %d radius 3 m" % [i + 1])
	assert_true(data.damage_type == Enums.DamageType.SLASH, "damage type is SLASH")


func test_whirlwind_hits() -> void:
	print("\n[GROUP 3] Whirlwind hits every enemy inside 3 m, no target cap")
	var commander := _new_commander()
	var runner: SkillRunner = commander.skill_runner
	var ring: Array[Enemy] = []
	for i in 12:
		var angle := TAU * float(i) / 12.0
		ring.append(_new_enemy("res://entities/enemy/grunt.tscn", Vector3(cos(angle), 0, sin(angle)) * 2.9))
	var outside := _new_enemy("res://entities/enemy/grunt.tscn", Vector3(3.2, 0, 0))
	var brute := _new_enemy("res://entities/enemy/brute.tscn", Vector3(0, 0, -1.5))
	var before: Array[int] = []
	for e in ring:
		before.append(e.health.hp)
	var outside_before := outside.health.hp

	EventBus.reward_picked.emit(&"whirlwind", &"ACTIVE", 1)
	var casts: Array = []
	var on_cast := func(skill_id: StringName, slot: int, level: int, _origin: Vector3, radius: float) -> void:
		casts.append([skill_id, slot, level, radius])
	EventBus.skill_cast.connect(on_cast)
	assert_true(runner.activate(0) != null, "level 1 cast accepted")
	EventBus.skill_cast.disconnect(on_cast)

	var all_hit := true
	for i in ring.size():
		if before[i] - ring[i].health.hp != 15:
			all_hit = false
	assert_true(all_hit, "all 12 enemies at 2.9 m take 15 SLASH at level 1")
	assert_true(outside.health.hp == outside_before, "enemy at 3.2 m is untouched")
	assert_true(brute.health.hp < brute.health.max_hp, "a Brute in range is hit too")
	assert_true(casts == [[&"whirlwind", 0, 1, 3.0]], "skill_cast signalled once with slot, level, radius")
	assert_true(is_equal_approx(runner.get_cooldown_left(0), 6.0), "level 1 cooldown 6.0 s")
	assert_true(runner.activate(0) == null, "cannot recast during cooldown")

	for level in [2, 3]:
		runner.tick(10.0)
		EventBus.reward_picked.emit(&"whirlwind", &"ACTIVE", level)
		ring[0].health.hp = ring[0].health.max_hp
		var hp_before := ring[0].health.hp
		runner.activate(0)
		assert_true(hp_before - ring[0].health.hp == 15 + 5 * (level - 1), "level %d deals %d" % [level, 15 + 5 * (level - 1)])
		assert_true(is_equal_approx(runner.get_cooldown_left(0), 6.5 - 0.5 * level), "level %d cooldown %.1f s" % [level, 6.5 - 0.5 * level])

	print("[GROUP 3b] Bulwark armored phase takes 60% from SLASH")
	var boss := _new_enemy("res://entities/enemy/bulwark.tscn", Vector3(2.0, 0, 2.0))
	boss.current_phase = Enums.BossPhase.ARMORED
	runner.tick(10.0)
	var boss_before := boss.health.hp
	runner.activate(0)
	assert_true(boss_before - boss.health.hp == 15, "level 3 Whirlwind 25 x 0.6 = 15 on the armored Bulwark")

	for e in ring:
		e.free()
	outside.free()
	brute.free()
	boss.free()
	commander.free()
	await get_tree().process_frame


func test_cooldown_clamp_and_damage_mult() -> void:
	print("\n[GROUP 3c] Cooldown clamp on level-up, StatBlock skill damage multiplier")
	var commander := _new_commander()
	var runner: SkillRunner = commander.skill_runner
	var grunt := _new_enemy("res://entities/enemy/grunt.tscn", Vector3(2, 0, 0))
	var boss := _new_enemy("res://entities/enemy/bulwark.tscn", Vector3(0, 0, 2))
	boss.current_phase = Enums.BossPhase.ARMORED
	EventBus.reward_picked.emit(&"whirlwind", &"ACTIVE", 1)
	runner.activate(0)
	runner.tick(0.2)
	EventBus.reward_picked.emit(&"whirlwind", &"ACTIVE", 2)
	assert_true(is_equal_approx(runner.get_cooldown_left(0), 5.5), "5.8 s left at L1 is clamped to the L2 total 5.5 s")
	runner.tick(1.5)
	EventBus.reward_picked.emit(&"whirlwind", &"ACTIVE", 3)
	assert_true(is_equal_approx(runner.get_cooldown_left(0), 4.0), "4.0 s left is below the L3 total and stays")

	runner.tick(10.0)
	EventBus.reward_picked.emit(&"whirlwind", &"ACTIVE", 1)
	EventBus.reward_picked.emit(&"sharpness", &"PASSIVE", 1)
	grunt.health.hp = grunt.health.max_hp
	var before := grunt.health.hp
	runner.activate(0)
	assert_true(before - grunt.health.hp == 16, "Sharpness L1 (+8%%): 15 x 1.08 = 16")
	runner.tick(10.0)
	EventBus.reward_picked.emit(&"sharpness", &"PASSIVE", 3)
	EventBus.reward_picked.emit(&"mastery", &"STAT", 1)
	grunt.health.hp = grunt.health.max_hp
	before = grunt.health.hp
	var boss_before := boss.health.hp
	runner.activate(0)
	assert_true(before - grunt.health.hp == 19, "Sharpness L3 + Mastery (+29%%): 15 x 1.29 = 19")
	assert_true(boss_before - boss.health.hp == 12, "same multiplier on the armored Bulwark: 15 x 1.29 x 0.6 = 12, rounded once")

	grunt.free()
	boss.free()
	commander.free()
	await get_tree().process_frame


func _press_and_step(commander: CharacterBody3D, action: StringName) -> void:
	commander._cmd_input.register_press(action)
	commander.set_physics_process(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	commander.set_physics_process(false)


func test_keys_and_modes() -> void:
	print("\n[GROUP 4] Keys 1-3 follow the mode, Stun and Recall rules")
	for action in [&"skill_1", &"skill_2", &"skill_3"]:
		assert_true(InputMap.has_action(action), "InputMap has %s" % action)
	var key := (InputMap.action_get_events(&"skill_1")[0] as InputEventKey).physical_keycode
	assert_true(key == KEY_1, "skill_1 is the physical key 1")

	var commander := _new_commander()
	var runner: SkillRunner = commander.skill_runner
	var enemy := _new_enemy("res://entities/enemy/grunt.tscn", Vector3(1.5, 0, 0))
	EventBus.reward_picked.emit(&"whirlwind", &"ACTIVE", 1)

	commander.is_commander_mode = true
	var hp := enemy.health.hp
	await _press_and_step(commander, &"skill_1")
	assert_true(enemy.health.hp == hp and runner.get_cooldown_left(0) == 0.0 and not commander.is_using_skill, "Commander mode: key 1 does nothing")
	assert_true(commander._cmd_input.get_buffered() == &"", "Commander mode: nothing is buffered")

	commander.is_commander_mode = false
	commander.is_stunned = true
	commander._stun_timer = 5.0
	await _press_and_step(commander, &"skill_1")
	assert_true(enemy.health.hp == hp, "Stunned: key 1 does nothing")
	commander.is_stunned = false

	await _press_and_step(commander, &"skill_2")
	assert_true(enemy.health.hp == hp and runner.get_cooldown_left(0) == 0.0, "Empty slot 2: key 2 does nothing")

	await _press_and_step(commander, &"skill_1")
	assert_true(enemy.health.hp == hp - 15, "Frontline: key 1 casts Whirlwind")
	assert_true(commander.is_using_skill, "the cast locks the commander for the skill animation")
	assert_true(runner.get_cooldown_left(0) > 5.9, "cooldown started")
	assert_true(not commander._skill_locks_movement, "an active slot skill does not lock movement")

	print("[GROUP 4b] Skill key cancels Recall")
	commander.is_using_skill = false
	commander._skill_timer = 0.0
	runner.tick(10.0)
	commander._mode_switch.interrupt_recall()
	commander._mode_switch.request()
	var recalling: bool = commander.is_recalling()
	await _press_and_step(commander, &"skill_1")
	assert_true(not recalling or not commander.is_recalling(), "pressing a skill while recalling cancels the recall")

	enemy.free()
	commander.free()
	await get_tree().process_frame


func test_cooldown_time_scale() -> void:
	print("\n[GROUP 5] Cooldown follows game time: x1, x2, x3 and Pause")
	var runner := SkillRunner.new()
	add_child(runner)
	EventBus.reward_picked.emit(&"whirlwind", &"ACTIVE", 1)
	var commander := _new_commander()
	runner.caster = commander
	commander.get_node("SkillRunner").reset()
	runner.set_skill_level(&"whirlwind", 1)

	await TimeManager.wait_real(0.3)  # let the physics loop settle after the previous groups
	for scale in [1, 2, 3]:
		TimeManager.set_time_scale(scale)
		runner._cooldowns[0] = 6.0
		var start: float = TimeManager.game_time
		await TimeManager.wait_real(0.8)
		var game_elapsed: float = TimeManager.game_time - start
		var used: float = 6.0 - runner.get_cooldown_left(0)
		assert_true(absf(used - game_elapsed) < 0.2 and used > 0.7 * scale, "x%d: cooldown used %.2f s of game time %.2f s" % [scale, used, game_elapsed])

	TimeManager.set_time_scale(1)
	runner._cooldowns[0] = 6.0
	TimeManager.request_pause(TimeManager.REASON_USER)
	await TimeManager.wait_real(0.5)
	assert_true(is_equal_approx(runner.get_cooldown_left(0), 6.0), "Pause freezes the cooldown")
	TimeManager.release_pause(TimeManager.REASON_USER)
	TimeManager.reset()

	commander.free()
	runner.free()
