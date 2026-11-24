extends Node

var passes := 0
var fails := 0
var _deaths := 0
var _run_ends := 0
var _zero_hp_reports := 0
var _denied: StringName = &""
var _run_state: RunState
var _commander: CharacterBody3D


func _ready() -> void:
	EventBus.commander_died.connect(func() -> void: _deaths += 1)
	EventBus.commander_hp_changed.connect(func(hp: int, _max_hp: int) -> void:
		if hp == 0:
			_zero_hp_reports += 1)
	EventBus.run_ended.connect(func(_type: StringName, _summary: Dictionary) -> void: _run_ends += 1)
	EventBus.mode_switch_denied.connect(func(reason: StringName, _left: float) -> void: _denied = reason)
	_run_state = RunState.new()
	add_child(_run_state)
	_commander = preload("res://entities/commander/commander.tscn").instantiate()
	add_child(_commander)
	_commander.set_physics_process(false)
	for child in _commander.get_children():
		child.set_physics_process(false)
	await get_tree().process_frame
	test_snapshot_and_locks()
	await test_room_death()
	test_cap_retries_without_valid_enemies()
	test_lazy_cap_and_boss()
	await test_damage_sources()
	test_weapon_effects_outside_hazard()
	await test_cooldowns_at_each_speed()
	test_cleanup()
	_commander.free()
	_run_state.free()
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	get_tree().quit(0 if fails == 0 else 1)


func assert_true(condition: bool, label: String) -> void:
	if condition:
		passes += 1
		print("[PASS] %s" % label)
	else:
		fails += 1
		printerr("[FAIL] %s" % label)


func _enter() -> void:
	EventBus.state_changed.emit(&"PREP")
	EventBus.hazard_trial_entered.emit(1, [&"grunt"])
	EventBus.state_changed.emit(&"HAZARD_TRIAL")


func _leave() -> void:
	EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
	EventBus.state_changed.emit(&"PREP")


func _enemy(boss: bool = false) -> Enemy:
	var scene := "res://entities/enemy/bulwark.tscn" if boss else "res://entities/enemy/grunt.tscn"
	var enemy := (load(scene) as PackedScene).instantiate() as Enemy
	add_child(enemy)
	enemy.position = Vector3(1.2, 0.0, 0.0)
	enemy.set_physics_process(false)
	enemy.spawn_grace = false
	enemy.is_in_spawn_zone = false
	enemy.health.max_hp = 500
	enemy.health.hp = 500
	return enemy


func test_snapshot_and_locks() -> void:
	var health: HealthComponent = _commander.health
	EventBus.state_changed.emit(&"PREP")
	health.restore_state(70.0, 100, 0.25)
	_commander.stat_block.set_add(&"sword_damage", &"snapshot_test", 3.0)
	_commander.skill_runner.set_skill_level(&"whirlwind", 1)
	var skills: Dictionary = _commander.skill_runner.export_state()
	skills["cooldowns"][&"whirlwind"] = 4.5
	_commander.skill_runner.import_state(skills)
	_commander._dodge_cooldown_timer = 1.25
	_commander._battle_cry_cd_timer = 7.5
	_commander._mode_switch.cooldown_left = 2.5
	_run_state.chain_cd = 3.0
	var stats: Dictionary = _commander.stat_block.export_state()
	EventBus.hazard_trial_entered.emit(1, [&"grunt"])
	EventBus.state_changed.emit(&"HAZARD_TRIAL")
	assert_true(_commander.hazard_trial_state.is_in_room() and not _run_state.hazard_session.is_empty(), "entry stores the snapshot in RunState")
	EventBus.hazard_trial_entered.emit(1, [&"grunt"])
	assert_true(_run_state.hazard_session["hp"] == 70.0, "duplicate entry preserves the original snapshot")
	_commander.take_damage(DamageInfo.new(50, Enums.DamageType.TRUE))
	assert_true(health.hp == 20, "room damage is applied")
	assert_true(_commander._ground_actions_allowed(), "room allows movement and combat commands")
	_commander._mode_switch.request()
	assert_true(_denied == ModeSwitch.DENIED_HAZARD and not _commander.is_recalling(), "Tab refuses Recall with HAZARD reason")
	var repair := _commander.get_node("EmergencyRepair") as EmergencyRepair
	assert_true(repair.get_denial_reason() == EmergencyRepair.REASON_NOT_COMMANDER, "Frontline room refuses Emergency Repair")
	var heal := _commander.get_node("HealChannel") as HealChannel
	for state in Enums.WaveState.keys():
		if state in ["COMBAT", "BOSS_COMBAT"]:
			continue
		EventBus.state_changed.emit(StringName(state))
		assert_true(heal.get_block_reason() == &"WAVE_STATE", "%s refuses station healing" % state)
	EventBus.state_changed.emit(&"HAZARD_TRIAL")
	_commander.stat_block.set_add(&"sword_damage", &"snapshot_test", 99.0)
	_commander.stat_block.set_mul(&"sword_range", &"room_only", 2.0)
	_commander.skill_runner.set_skill_level(&"whirlwind", 3)
	_commander.skill_runner.set_skill_level(&"firebomb", 1)
	_commander.skill_runner.tick(2.0)
	_commander._dodge_cooldown_timer = 0.0
	_commander._battle_cry_cd_timer = 0.0
	_commander._mode_switch.cooldown_left = 0.0
	_commander.is_stunned = true
	_run_state.equipped_weapon = &"swift"
	_commander._apply_weapon(&"swift")
	_run_state.chain_cd = 0.0
	var restored_chain: Array[Vector2] = []
	var capture := func(id: StringName, remaining: float, total: float) -> void:
		if id == &"chain_lightning":
			restored_chain.append(Vector2(remaining, total))
	EventBus.skill_cooldown_changed.connect(capture)
	_leave()
	EventBus.skill_cooldown_changed.disconnect(capture)
	assert_true(restored_chain == [Vector2(3.0, 5.0)], "room exit refreshes the shared cooldown with another weapon equipped")
	assert_true(health.hp == 70 and health.max_hp == 100 and health.dot_remainder == 0.25, "70/100 HP and DoT remainder restored without PREP heal")
	assert_true(_commander.stat_block.export_state() == stats, "deep StatBlock snapshot survives room mutations")
	assert_true(_commander.skill_runner.export_state() == skills, "skill slots, levels and cooldowns restored")
	assert_true(_commander._dodge_cooldown_timer == 1.25 and _commander._battle_cry_cd_timer == 7.5 and _commander._mode_switch.cooldown_left == 2.5, "commander and mode cooldowns restored")
	assert_true(not _commander.is_stunned and _run_state.equipped_weapon == &"sword_base" and _run_state.chain_cd == 3.0, "status, weapon and chain cooldown restored")
	assert_true(not DamageCalc.has_cap_hook() and _run_state.hazard_session.is_empty(), "room exit clears cap and session")
	health.restore_state(69.5, 100, 0.125)
	_enter_without_prep()
	health.take_damage(10)
	_leave()
	assert_true(health.get_precise_hp() == 69.5, "fractional HP survives the round trip exactly")
	_commander.stat_block.clear_source(&"snapshot_test")
	_commander.skill_runner.reset()


func _enter_without_prep() -> void:
	EventBus.hazard_trial_entered.emit(1, [&"grunt"])
	EventBus.state_changed.emit(&"HAZARD_TRIAL")


func test_room_death() -> void:
	_commander.health.restore_state(70.0, 100, 0.0)
	_enter_without_prep()
	_commander.take_damage(DamageInfo.new(1000, Enums.DamageType.TRUE))
	await get_tree().process_frame
	assert_true(_commander.health.hp == 0 and not _commander.is_dead, "room death keeps is_dead false")
	assert_true(_deaths == 0 and _run_ends == 0, "room death emits no commander_died and does not end the run")
	assert_true(_zero_hp_reports == 1, "room death reports zero HP through the existing commander_hp_changed signal")
	var animator: AnimationPlayer = _commander._anim_player
	assert_true(animator.current_animation != String(_commander.ANIM_DEATH), "room death does not play the death animation")
	_leave()
	assert_true(_commander.health.hp == 70, "room death restores 70 HP")


func test_cap_retries_without_valid_enemies() -> void:
	for scenario in ["empty", "queued", "zero_hp"]:
		_enter()
		var invalid_enemy: Enemy = null
		if scenario != "empty":
			invalid_enemy = _enemy()
			if scenario == "queued":
				invalid_enemy.queue_free()
			else:
				invalid_enemy.health.max_hp = 0
		assert_true(_commander.hazard_trial_state._cap() == 0, "%s scan temporarily caps damage at zero" % scenario)
		if invalid_enemy != null:
			invalid_enemy.free()
		var enemy := _enemy()
		var damage := enemy.take_damage(DamageInfo.new(80, Enums.DamageType.SLASH, _commander))
		assert_true(damage == 50, "%s scan retries when a valid 500 HP enemy appears" % scenario)
		_leave()
		enemy.free()


func test_lazy_cap_and_boss() -> void:
	_enter()
	var enemy := _enemy()
	var hit := DamageInfo.outgoing(80.0, 1.0, Enums.DamageType.SLASH, _commander)
	assert_true(enemy.take_damage(hit) == 50, "late-spawned 500 HP dummy caps 80 to 50")
	enemy.health.max_hp = 2000
	assert_true(enemy.take_damage(hit) == 50, "HP reference is cached after the first hit")
	assert_true(enemy.take_damage(DamageInfo.new(80)) == 80, "non-commander damage is not capped")
	assert_true(enemy.take_damage(DamageInfo.new(80, Enums.DamageType.TRUE, _commander)) == 50, "TRUE commander damage is capped")
	_leave()
	enemy.free()
	_enter()
	var boss := _enemy(true) as Bulwark
	boss.max_core_hp = 900
	boss.current_core_hp = 900
	boss.max_armor_hp = 1200
	boss.current_armor_hp = 1200
	boss.health.max_hp = 2100
	boss.health.hp = 2100
	_commander._apply_weapon(&"frost")
	assert_true(boss.take_damage(DamageInfo.new(500, Enums.DamageType.TRUE, _commander)) == 90, "boss cap uses 900 core HP, excluding 1200 armor")
	assert_true(is_equal_approx(boss.get_slow_factor(), 0.8), "Frost slows the armored boss")
	_leave()
	boss.free()


func test_damage_sources() -> void:
	var enemy := _enemy()
	_commander.stat_block.set_add(&"sword_damage", &"cap_test", 1000.0)
	_commander.stat_block.set_mul(&"skill_damage", &"cap_test", 100.0)
	_enter()
	_commander.aim_dir = Vector3.RIGHT
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before := enemy.health.hp
	_commander._start_attack(1)
	_commander._execute_sword_strike(1)
	_commander._end_attack()
	assert_true(before - enemy.health.hp == 50, "normal sword strike is capped")
	var runner: SkillRunner = _commander.skill_runner
	for id in [&"whirlwind", &"sword_wave"]:
		var slot := runner.set_skill_level(id, 1)
		before = enemy.health.hp
		runner.activate(slot)
		assert_true(before - enemy.health.hp == 50, "%s is capped" % id)
	var firebomb := runner.set_skill_level(&"firebomb", 1)
	_commander.aim_point = enemy.global_position
	runner.activate(firebomb)
	var zone := get_node_or_null("FirebombZone") as FirebombZone
	assert_true(zone != null, "Firebomb creates a zone")
	if zone != null:
		zone.set_physics_process(false)
		_commander._apply_weapon(&"frost")
		before = enemy.health.hp
		zone.tick(1.0)
		assert_true(before - enemy.health.hp == 50, "Firebomb tick is capped")
		assert_true(is_equal_approx(enemy.get_slow_factor(), 0.8), "Firebomb ticks proc Frost")
		zone.free()
	before = enemy.health.hp
	_commander._apply_weapon(&"burn")
	enemy.take_damage(DamageInfo.new(1, Enums.DamageType.BLAST, _commander))
	enemy._tick_status(1.0)
	assert_true(before - enemy.health.hp == 51 and enemy.burn_damage_type == Enums.DamageType.BLAST,
		"Burn inherits the triggering type and its tick is capped")
	_commander._apply_weapon(&"chain_lightning")
	_run_state.chain_cd = 0.0
	var second := _enemy()
	second.position = Vector3(2.2, 0.0, 0.5)
	var third := _enemy()
	third.position = Vector3(2.2, 0.0, -0.5)
	var fourth := _enemy()
	fourth.position = Vector3(3.2, 0.0, 0.0)
	enemy.in_hazard_room = true
	second.in_hazard_room = true
	third.in_hazard_room = true
	fourth.in_hazard_room = true
	var outsider := _enemy()
	outsider.position = Vector3(1.3, 0.0, 0.0)
	before = enemy.health.hp
	enemy.take_damage(DamageInfo.new(1, Enums.DamageType.SLASH, _commander))
	assert_true(before - enemy.health.hp == 51 and _run_state.chain_cd > 0.0, "triggered Chain Lightning bolt is capped separately from its initiating hit")
	assert_true(second.health.hp == 450 and third.health.hp == 450 and fourth.health.hp == 500, "chain visits three distinct targets with deterministic ties and caps each bolt")
	assert_true(outsider.health.hp == 500, "chain cannot jump across the room boundary")
	outsider.free()
	before = second.health.hp
	second.take_damage(DamageInfo.new(1, Enums.DamageType.SLASH, _commander))
	assert_true(before - second.health.hp == 1, "chain shares its cooldown across targets and does not recurse")
	_commander._update_cooldowns_and_timers(1.0)
	assert_true(is_equal_approx(_run_state.chain_cd, 4.0), "chain cooldown advances in game time")
	second.free()
	third.free()
	fourth.free()
	var projectile := Projectile.new()
	add_child(projectile)
	projectile.damage = 80
	projectile.source = _commander
	before = enemy.health.hp
	projectile._apply_hit(enemy)
	assert_true(before - enemy.health.hp == 50, "commander projectile reaches receiver resolution and cap")
	_leave()
	assert_true(enemy.take_damage(DamageInfo.new(80, Enums.DamageType.TRUE, _commander)) == 80, "damage is uncapped after leaving")
	_commander.stat_block.clear_source(&"cap_test")
	enemy.free()


func test_weapon_effects_outside_hazard() -> void:
	_commander.global_position = Vector3.ZERO
	_commander.aim_dir = Vector3.RIGHT
	var slash := DamageInfo.new(20, Enums.DamageType.SLASH, _commander)
	var boss := _enemy(true) as Bulwark
	_commander._apply_weapon(&"frost")
	boss.take_damage(slash)
	boss._tick_status(2.0)
	boss.take_damage(slash)
	assert_true(is_equal_approx(boss.get_slow_factor(), 0.8) and is_equal_approx(boss.slow_timer, 3.0),
		"an armored boss receives and refreshes Frost from SLASH hits")
	boss._tick_status(3.0)
	boss.take_damage(DamageInfo.new(20, Enums.DamageType.PIERCE, _commander))
	assert_true(boss.slow_timer == 0.0, "an immune hit does not start Frost")
	boss.free()

	_commander._apply_weapon(&"burn")
	var burning := _enemy()
	var burn_hits: Array[DamageInfo] = []
	burning.health.damaged.connect(func(_amount: int, info: DamageInfo) -> void:
		if info.is_weapon_effect:
			burn_hits.append(info))
	burning.take_damage(DamageInfo.new(1, Enums.DamageType.BLAST, _commander))
	var starting_hp := burning.health.hp
	burning._tick_status(5.0)
	var base: float = _commander.stat_block.get_base(&"sword_damage") + _commander.stat_block.get_add_total(&"sword_damage")
	assert_true(starting_hp - burning.health.hp == floori(base * 0.5 * _commander.get_sword_dealt_mult()),
		"Burn deals half the base sword damage over five seconds")
	assert_true(not burn_hits.is_empty() and burn_hits.all(func(info: DamageInfo) -> bool:
		return info.damage_type == Enums.DamageType.BLAST and info.hit_by_commander) and burning.burn_timer == 0.0,
		"Burn preserves the triggering type and credit without refreshing itself")
	burning.take_damage(slash)
	burning._tick_status(3.0)
	var per_tick := burning.burn_per_tick
	burning.take_damage(slash)
	assert_true(burning.burn_timer == 5.0 and burning.burn_per_tick == per_tick, "Burn refreshes without stacking")
	burning.free()

	_commander._apply_weapon(&"chain_lightning")
	var farther := _enemy()
	farther.position = Vector3(2.0, 0.0, 0.0)
	var nearer := _enemy()
	nearer.position = Vector3(1.0, 0.0, 0.0)
	var targets: Array[Enemy] = [farther, nearer]
	var chain_hits: Array[Enemy] = []
	for target in targets:
		target.health.damaged.connect(func(_amount: int, info: DamageInfo) -> void:
			if info.is_weapon_effect:
				chain_hits.append(target))
	_run_state.chain_cd = 0.0
	WhirlwindSkill.cast(_commander, preload("res://data/skills/whirlwind.tres"), 1)
	assert_true(chain_hits == [nearer, farther], "Whirlwind starts the chain at the nearer enemy regardless of tree order")
	chain_hits.clear()
	_run_state.chain_cd = 0.0
	SwordWaveSkill.cast(_commander, preload("res://data/skills/sword_wave.tres"), 1, 1.0, Vector3.RIGHT)
	assert_true(chain_hits == [nearer, farther], "Sword Wave starts the chain at the nearer enemy")
	chain_hits.clear()
	_run_state.chain_cd = 0.0
	var zone := FirebombZone.new()
	zone.setup(_commander, preload("res://data/skills/firebomb.tres"), 1, 1.0)
	add_child(zone)
	zone.position = farther.position
	zone.tick(1.0)
	assert_true(chain_hits == [nearer, farther], "Firebomb ranks chain targets from the caster")
	chain_hits.clear()
	zone.tick(1.0)
	assert_true(chain_hits.is_empty(), "another Firebomb tick cannot start a chain during cooldown")
	zone.free()
	for target in targets:
		target.free()

	var line: Array[Enemy] = []
	for index in 4:
		var target := _enemy()
		target.position = Vector3(index * 1.5, 0.0, 0.0)
		line.append(target)
	_run_state.chain_cd = 0.0
	line[0].take_damage(DamageInfo.new(1, Enums.DamageType.BLAST, _commander))
	var bolt := maxi(1, roundi(base * 0.2 * _commander.get_sword_dealt_mult()))
	assert_true(line[0].health.hp == 499 - bolt and line[1].health.hp == 500 - bolt
		and line[2].health.hp == 500 - bolt and line[3].health.hp == 500,
		"Chain hits exactly three distinct enemies for one fifth of base sword damage")
	assert_true(line[1].health.hit_by_commander and line[2].health.hit_by_commander,
		"Chain jumps grant commander credit")
	for target in line:
		target.free()


func test_cooldowns_at_each_speed() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	_enter()
	_commander._apply_weapon(&"chain_lightning")
	var runner := _commander.get_node("SkillRunner") as SkillRunner
	var slot := runner.set_skill_level(&"whirlwind", 1)
	assert_true(runner.activate(slot) != null, "Whirlwind starts a cooldown in Hazard")
	runner.set_physics_process(true)
	_commander.set_physics_process(true)
	await get_tree().physics_frame
	const PHYSICS_STEPS := 8
	for speed in [1, 2, 3]:
		TimeManager.set_time_scale(speed)
		await get_tree().process_frame
		await get_tree().physics_frame
		_run_state.chain_cd = 2.0
		var skill_cooldown := runner.get_cooldown_left(slot)
		for step in range(PHYSICS_STEPS):
			await get_tree().physics_frame
		var expected := float(PHYSICS_STEPS * speed) / Engine.physics_ticks_per_second
		var elapsed := 2.0 - _run_state.chain_cd
		assert_true(is_equal_approx(elapsed, expected),
			"Chain cooldown in Hazard at x%d advances %.3f game seconds (expected %.3f)" % [speed, elapsed, expected])
		assert_true(is_equal_approx(skill_cooldown - runner.get_cooldown_left(slot), expected),
			"Whirlwind cooldown uses scaled gameplay time in Hazard at x%d" % speed)
	_commander.set_physics_process(false)
	runner.set_physics_process(false)
	TimeManager.reset_time_scale()
	_leave()
	camera.free()


func test_cleanup() -> void:
	_enter()
	EventBus.run_ended.emit(&"ABANDONED", {})
	assert_true(not DamageCalc.has_cap_hook() and not _commander.hazard_trial_state.is_in_room() and _run_state.hazard_session.is_empty(), "abandon clears the hook and session")
	_enter()
	_commander.remove_child(_commander.hazard_trial_state)
	assert_true(not DamageCalc.has_cap_hook() and _run_state.hazard_session.is_empty(), "scene exit clears the hook and session")
	_commander.hazard_trial_state.free()
