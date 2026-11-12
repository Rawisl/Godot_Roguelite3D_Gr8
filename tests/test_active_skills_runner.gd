extends Node
## Runner for the active skills: Whirlwind, Sword Wave, Firebomb, the BOSS_INTRO lock and the
## slot signal of the reward service. Prints PASS/FAIL then quits.

const FORTRESS_SCENE: PackedScene = preload("res://entities/fortress/fortress.tscn")
const GRUNT := "res://entities/enemy/grunt.tscn"
const BULWARK := "res://entities/enemy/bulwark.tscn"

var passes: int = 0
var fails: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("          ACTIVE SKILLS VERIFICATION                    ")
	print("=======================================================")

	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 10, 10)
	camera.rotation_degrees = Vector3(-45, 0, 0)
	camera.make_current()

	test_data_tables()
	await test_whirlwind()
	await test_sword_wave()
	await test_sword_wave_blocked()
	await test_sword_wave_spawn_zone()
	await test_sword_wave_levels_and_bulwark()
	await test_firebomb()
	await test_firebomb_levels()
	await test_firebomb_landing()
	await test_boss_intro_lock()
	await test_reward_slots()

	print("=======================================================")
	print("ACTIVE SKILLS TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
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
	commander.set_physics_process(false)
	return commander


func _new_enemy(scene: String, pos: Vector3) -> Enemy:
	var enemy: Enemy = (load(scene) as PackedScene).instantiate()
	add_child(enemy)
	enemy.global_position = pos
	enemy.spawn_grace = false
	enemy.is_in_spawn_zone = false
	enemy.set_physics_process(false)
	return enemy


func _press_and_step(commander: CharacterBody3D, action: StringName) -> void:
	commander._cmd_input.register_press(action)
	commander.set_physics_process(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	commander.set_physics_process(false)


func _wall(pos: Vector3, groups: Array[StringName]) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 2, 8)
	shape.shape = box
	body.add_child(shape)
	for group in groups:
		body.add_to_group(group)
	add_child(body)
	body.global_position = pos
	return body


func _zones() -> Array[FirebombZone]:
	var zones: Array[FirebombZone] = []
	for child in get_children():
		if child is FirebombZone and not child.is_queued_for_deletion():
			zones.append(child)
	return zones


func test_data_tables() -> void:
	print("\n[GROUP 1] Skill numbers")
	var wave: SkillData = load("res://data/skills/sword_wave.tres")
	var bomb: SkillData = load("res://data/skills/firebomb.tres")
	assert_true(wave.validate().is_empty() and bomb.validate().is_empty(), "sword_wave and firebomb pass validate()")
	assert_true(wave.damage_type == Enums.DamageType.SLASH, "Sword Wave is SLASH")
	assert_true(bomb.damage_type == Enums.DamageType.BLAST, "Firebomb is BLAST")
	for i in 3:
		assert_true(is_equal_approx(wave.get_value(&"damage", i + 1), [18.0, 21.0, 24.0][i]), "Sword Wave level %d damage" % [i + 1])
		assert_true(is_equal_approx(wave.get_value(&"width", i + 1), [3.0, 3.5, 4.0][i]), "Sword Wave level %d width" % [i + 1])
		assert_true(is_equal_approx(bomb.get_value(&"dps", i + 1), [6.0, 8.0, 10.0][i]), "Firebomb level %d damage per second" % [i + 1])
		assert_true(is_equal_approx(bomb.get_value(&"radius", i + 1), [2.5, 3.0, 3.5][i]), "Firebomb level %d radius" % [i + 1])
	assert_true(is_equal_approx(wave.get_value(&"cooldown", 1), 5.0) and is_equal_approx(bomb.get_value(&"cooldown", 1), 8.0), "cooldowns 5 s and 8 s")
	assert_true(SkillRunner.SKILLS.has(wave) and SkillRunner.SKILLS.has(bomb), "SkillRunner knows both skills")
	var pool: RewardPool = load("res://data/config/reward_pool.tres")
	assert_true(pool.skills.has(wave) and pool.skills.has(bomb), "reward pool offers both skills")


func test_whirlwind() -> void:
	print("\n[GROUP 2] Whirlwind: 15 inside 3 m, nothing outside")
	var commander := _new_commander()
	var inside := _new_enemy(GRUNT, Vector3(2.5, 0, 0))
	var outside := _new_enemy(GRUNT, Vector3(3.5, 0, 0))
	var boss := _new_enemy(BULWARK, Vector3(0, 0, 2.5)) as Bulwark
	EventBus.reward_picked.emit(&"whirlwind", &"ACTIVE", 1)
	var before := inside.health.hp
	var armor_before := boss.current_armor_hp
	assert_true(not boss.hit_by_commander, "Bulwark has no commander hit before Whirlwind")
	commander.skill_runner.activate(0)
	assert_true(before - inside.health.hp == 15, "enemy at 2.5 m takes 15")
	assert_true(outside.health.hp == outside.health.max_hp, "enemy at 3.5 m is untouched")
	assert_true(armor_before - boss.current_armor_hp == 9, "armored Bulwark takes 60% from Whirlwind")
	assert_true(boss.hit_by_commander, "Whirlwind counts as a commander hit on Bulwark")
	inside.free()
	outside.free()
	boss.free()
	commander.free()
	await get_tree().process_frame


func test_sword_wave() -> void:
	print("\n[GROUP 3] Sword Wave: rectangle along the aim")
	var commander := _new_commander()
	commander.aim_dir = Vector3.RIGHT
	var hit_near := _new_enemy(GRUNT, Vector3(1.0, 0, 0))
	var hit_far := _new_enemy(GRUNT, Vector3(3.8, 0, 1.4))
	var too_wide := _new_enemy(GRUNT, Vector3(2.0, 0, 1.6))
	var too_far := _new_enemy(GRUNT, Vector3(4.3, 0, 0))
	var behind := _new_enemy(GRUNT, Vector3(-1.0, 0, 0))
	EventBus.reward_picked.emit(&"sword_wave", &"ACTIVE", 1)
	var casts: Array = []
	var on_cast := func(skill_id: StringName, slot: int, _level: int, _origin: Vector3, size: float) -> void:
		casts.append([skill_id, slot, size])
	EventBus.skill_cast.connect(on_cast)
	var near_before := hit_near.health.hp
	var far_before := hit_far.health.hp
	var data: SkillData = commander.skill_runner.activate(0)
	EventBus.skill_cast.disconnect(on_cast)
	assert_true(data != null and data.id == &"sword_wave", "slot 1 casts Sword Wave")
	assert_true(near_before - hit_near.health.hp == 18, "enemy 1 m ahead takes 18")
	assert_true(far_before - hit_far.health.hp == 18, "enemy 3.8 m ahead, 1.4 m aside takes 18")
	assert_true(too_wide.health.hp == too_wide.health.max_hp, "enemy 1.6 m aside is outside the 3 m width")
	assert_true(too_far.health.hp == too_far.health.max_hp, "enemy 4.3 m ahead is outside the 4 m range")
	assert_true(behind.health.hp == behind.health.max_hp, "enemy behind the caster is untouched")
	assert_true(hit_near.hit_by_commander, "the hit counts as a commander hit")
	assert_true(casts == [[&"sword_wave", 0, 3.0]], "skill_cast carries the width")
	for node in [hit_near, hit_far, too_wide, too_far, behind, commander]:
		node.free()
	await get_tree().process_frame


func test_sword_wave_blocked() -> void:
	print("\n[GROUP 4] Sword Wave stops at a barricade, not at other towers")
	var commander := _new_commander()
	commander.aim_dir = Vector3.RIGHT
	var before_wall := _new_enemy(GRUNT, Vector3(1.0, 0, 0))
	var behind_wall := _new_enemy(GRUNT, Vector3(3.0, 0, 0))
	var wall := _wall(Vector3(2.0, 0, 0), [&"tower", &"barricade"])
	await get_tree().physics_frame
	await get_tree().physics_frame
	EventBus.reward_picked.emit(&"sword_wave", &"ACTIVE", 1)
	commander.skill_runner.activate(0)
	assert_true(before_wall.health.hp < before_wall.health.max_hp, "enemy in front of the barricade is hit")
	assert_true(behind_wall.health.hp == behind_wall.health.max_hp, "enemy behind the barricade is not")
	wall.remove_from_group(&"barricade")
	commander.skill_runner.tick(10.0)
	commander.skill_runner.activate(0)
	assert_true(behind_wall.health.hp < behind_wall.health.max_hp, "a tower that is not a barricade lets the wave through")
	for node in [before_wall, behind_wall, wall, commander]:
		node.free()
	await get_tree().process_frame


func _spawn_zone(center: Vector3, shape_name: String) -> Area3D:
	var spawn := Area3D.new()
	spawn.add_to_group(&"spawn_zone")
	var shape := CollisionShape3D.new()
	shape.name = shape_name
	var box := BoxShape3D.new()
	box.size = Vector3(6, 2, 20)
	shape.shape = box
	spawn.add_child(shape)
	add_child(spawn)
	spawn.global_position = center
	return spawn


func test_sword_wave_spawn_zone() -> void:
	print("
[GROUP 4b] Sword Wave stops at the spawn zone edge")
	var commander := _new_commander()
	commander.aim_dir = Vector3.RIGHT
	var spawn := _spawn_zone(Vector3(5, 0, 0), "SpawnShape")
	var before_edge := _new_enemy(GRUNT, Vector3(1.5, 0, 0))
	var inside_zone := _new_enemy(GRUNT, Vector3(3.0, 0, 0))
	EventBus.reward_picked.emit(&"sword_wave", &"ACTIVE", 1)
	commander.skill_runner.activate(0)
	assert_true(before_edge.health.hp < before_edge.health.max_hp, "enemy before the zone edge (x = 2) is hit")
	assert_true(inside_zone.health.hp == inside_zone.health.max_hp, "enemy inside the zone is not")
	var clear := SwordWaveSkill.spawn_zone_distance(commander, Vector3.LEFT, 4.0)
	assert_true(is_equal_approx(clear, 4.0), "aiming away from the zone leaves the range alone")
	for node in [before_edge, inside_zone, spawn, commander]:
		node.free()
	await get_tree().process_frame


func test_sword_wave_levels_and_bulwark() -> void:
	print("
[GROUP 4c] Sword Wave width by level, armored Bulwark takes 60%")
	var commander := _new_commander()
	commander.aim_dir = Vector3.RIGHT
	var runner: SkillRunner = commander.skill_runner
	var edge_15 := _new_enemy(GRUNT, Vector3(2.0, 0, 1.7))
	var edge_19 := _new_enemy(GRUNT, Vector3(2.0, 0, -1.9))
	for level in [1, 2, 3]:
		edge_15.health.hp = edge_15.health.max_hp
		edge_19.health.hp = edge_19.health.max_hp
		EventBus.reward_picked.emit(&"sword_wave", &"ACTIVE", level)
		runner.tick(10.0)
		runner.activate(0)
		var hit_15 := edge_15.health.hp < edge_15.health.max_hp
		var hit_19 := edge_19.health.hp < edge_19.health.max_hp
		assert_true(hit_15 == (level >= 2), "level %d: enemy 1.7 m aside is %s" % [level, "hit" if level >= 2 else "outside"])
		assert_true(hit_19 == (level == 3), "level %d: enemy 1.9 m aside is %s" % [level, "hit" if level == 3 else "outside"])
	edge_15.free()
	edge_19.free()
	var boss := _new_enemy(BULWARK, Vector3(2.0, 0, 0)) as Bulwark
	boss.current_phase = Enums.BossPhase.ARMORED
	EventBus.reward_picked.emit(&"sword_wave", &"ACTIVE", 1)
	runner.tick(10.0)
	var armor_before := boss.current_armor_hp
	var core_before := boss.current_core_hp
	assert_true(not boss.hit_by_commander, "Bulwark has no commander hit before Sword Wave")
	runner.activate(0)
	assert_true(armor_before - boss.current_armor_hp == 11, "18 x 0.6 = 10.8 rounds to 11 armor damage on Bulwark")
	assert_true(boss.current_core_hp == core_before, "Sword Wave leaves the core intact while armor remains")
	assert_true(boss.hit_by_commander, "Sword Wave counts as a commander hit on Bulwark")
	boss.free()
	commander.free()
	await get_tree().process_frame


func test_firebomb_levels() -> void:
	print("
[GROUP 5d] Firebomb radius by level")
	var commander := _new_commander()
	var runner: SkillRunner = commander.skill_runner
	commander.aim_point = Vector3(5, 0, 0)
	var near := _new_enemy(GRUNT, Vector3(7.8, 0, 0))
	var far := _new_enemy(GRUNT, Vector3(8.3, 0, 0))
	for level in [1, 2, 3]:
		near.health.hp = near.health.max_hp
		far.health.hp = far.health.max_hp
		EventBus.reward_picked.emit(&"firebomb", &"ACTIVE", level)
		runner.tick(10.0)
		runner.activate(0)
		var zone := _zones()[-1]
		zone.tick(1.0)
		assert_true((near.health.hp < near.health.max_hp) == (level >= 2), "level %d: enemy 2.8 m from the centre is %s" % [level, "burnt" if level >= 2 else "outside"])
		assert_true((far.health.hp < far.health.max_hp) == (level == 3), "level %d: enemy 3.3 m from the centre is %s" % [level, "burnt" if level == 3 else "outside"])
		zone.free()
	near.free()
	far.free()
	commander.free()
	await get_tree().process_frame


func test_firebomb() -> void:
	print("\n[GROUP 5] Firebomb: 4 ticks of 6, XP flag, skill damage bonus, Bulwark")
	var commander := _new_commander()
	var runner: SkillRunner = commander.skill_runner
	var grunt := _new_enemy(GRUNT, Vector3(5, 0, 0))
	var outside := _new_enemy(GRUNT, Vector3(9, 0, 0))
	commander.aim_point = Vector3(5, 0, 0)
	EventBus.reward_picked.emit(&"firebomb", &"ACTIVE", 1)
	var casts: Array = []
	var on_cast := func(skill_id: StringName, _slot: int, _level: int, origin: Vector3, radius: float) -> void:
		casts.append([skill_id, origin, radius])
	EventBus.skill_cast.connect(on_cast)
	runner.activate(0)
	EventBus.skill_cast.disconnect(on_cast)
	var zones := _zones()
	assert_true(zones.size() == 1, "one zone is added beside the commander")
	assert_true(casts.size() == 1 and casts[0][0] == &"firebomb" and (casts[0][1] as Vector3).is_equal_approx(Vector3(5, 0, 0)) and is_equal_approx(casts[0][2], 2.5), "skill_cast carries the landing point and the radius")
	assert_true(is_equal_approx(runner.get_cooldown_left(0), 8.0), "cooldown 8 s")
	var zone: FirebombZone = zones[0]
	assert_true(zone.global_position.is_equal_approx(Vector3(5, 0, 0)), "zone sits at the landing point")
	var start := grunt.health.hp
	zone.tick(0.5)
	assert_true(grunt.health.hp == start, "no damage before the first second")
	zone.tick(0.5)
	assert_true(start - grunt.health.hp == 6, "tick 1 deals 6")
	assert_true(grunt.hit_by_commander, "the burn counts as a commander hit")
	zone.tick(1.0)
	zone.tick(1.0)
	assert_true(not zone.is_queued_for_deletion(), "zone lives until the 4th tick")
	zone.tick(1.0)
	assert_true(start - grunt.health.hp == 24, "4 ticks deal 24")
	assert_true(zone.is_queued_for_deletion(), "zone frees itself after the 4th tick")
	assert_true(outside.health.hp == outside.health.max_hp, "enemy outside 2.5 m takes nothing")

	print("[GROUP 5b] +5% skill damage")
	await get_tree().process_frame
	commander.stat_block.set_mul(&"skill_damage", &"test", 0.05)
	runner.tick(10.0)
	grunt.health.hp = grunt.health.max_hp
	grunt.health.dot_remainder = 0.0
	start = grunt.health.hp
	runner.activate(0)
	zone = _zones()[0]
	for i in 4:
		zone.tick(1.0)
	assert_true(start - grunt.health.hp == 25, "4 ticks of 6.3 total 25 with the remainder carried")
	commander.stat_block.clear_source(&"test")

	print("[GROUP 5c] Bulwark phase 1 takes 100%")
	await get_tree().process_frame
	var boss := _new_enemy(BULWARK, Vector3(5, 0, 1)) as Bulwark
	var immune_boss := _new_enemy(BULWARK, Vector3(5, 0, -1)) as Bulwark
	var immune_data := immune_boss.data.duplicate(true) as BossData
	immune_data.resist_table_phase1[Enums.DamageType.BLAST] = 0.0
	immune_boss.data = immune_data
	var immune_events: Array[Node3D] = []
	var on_immune := func(target: Node3D, _info: DamageInfo) -> void: immune_events.append(target)
	EventBus.damage_immune.connect(on_immune)
	runner.tick(10.0)
	var armor_before := boss.current_armor_hp
	var core_before := boss.current_core_hp
	var immune_hp_before := immune_boss.health.hp
	assert_true(not boss.hit_by_commander, "Bulwark has no commander hit before Firebomb")
	runner.activate(0)
	zone = _zones()[0]
	zone.tick(1.0)
	EventBus.damage_immune.disconnect(on_immune)
	assert_true(armor_before - boss.current_armor_hp == 6, "armored Bulwark takes the full 6 per tick")
	assert_true(boss.current_core_hp == core_before, "Firebomb leaves the core intact while armor remains")
	assert_true(boss.hit_by_commander, "Firebomb tick counts as a commander hit on Bulwark")
	assert_true(immune_boss.health.hp == immune_hp_before, "a BLAST-immune boss takes no Firebomb damage")
	assert_true(not immune_boss.hit_by_commander, "an immune Firebomb tick gives no commander credit")
	assert_true(immune_events == [immune_boss], "only the immune boss emits damage_immune")
	zone.free()
	for node in [grunt, outside, boss, immune_boss, commander]:
		node.free()
	await get_tree().process_frame


func test_firebomb_landing() -> void:
	print("\n[GROUP 6] Firebomb landing point")
	var commander := _new_commander()
	var range_limit: float = GameConfig.skill_firebomb_cast_range
	var near := FirebombSkill.landing_point(commander, Vector3(3, 0, 0))
	assert_true(near.is_equal_approx(Vector3(3, 0, 0)), "a point in range is kept")
	var far := FirebombSkill.landing_point(commander, Vector3(0, 0, 30))
	assert_true(far.is_equal_approx(Vector3(0, 0, range_limit)), "a far point is held to the cast range")
	var unseen := FirebombSkill.landing_point(commander, Vector3.INF, Vector3.RIGHT)
	assert_true(unseen.is_equal_approx(Vector3(range_limit, 0, 0)), "no mouse point lands at full range along the aim")

	var spawn := _spawn_zone(Vector3(8, 0, 0), "SpawnShape")
	var pulled := FirebombSkill.landing_point(commander, Vector3(7, 0, 1))
	assert_true(is_equal_approx(pulled.x, 5.0) and is_equal_approx(pulled.z, 1.0), "a point inside the spawn zone moves to its edge")
	var outside := FirebombSkill.landing_point(commander, Vector3(4, 0, 1))
	assert_true(outside.is_equal_approx(Vector3(4, 0, 1)), "a point outside the spawn zone stays")
	spawn.free()
	commander.free()
	await get_tree().process_frame


func test_boss_intro_lock() -> void:
	print("\n[GROUP 7] BOSS_INTRO locks skills, attacks, damage and Emergency Repair")
	var fortress: Fortress = FORTRESS_SCENE.instantiate()
	add_child(fortress)
	var commander := _new_commander()
	var enemy := _new_enemy(GRUNT, Vector3(1.5, 0, 0))
	EventBus.reward_picked.emit(&"whirlwind", &"ACTIVE", 1)
	await get_tree().process_frame
	EventBus.state_changed.emit(&"BOSS_INTRO")
	var hp := enemy.health.hp
	await _press_and_step(commander, &"skill_1")
	assert_true(enemy.health.hp == hp and commander.skill_runner.get_cooldown_left(0) == 0.0, "skill key is refused")
	await _press_and_step(commander, &"attack")
	assert_true(enemy.health.hp == hp and not commander.is_attacking, "attack is refused")
	var commander_hp: int = commander.health.hp
	commander.take_damage(DamageInfo.new(40, Enums.DamageType.SLASH))
	assert_true(commander.health.hp == commander_hp, "the commander loses no HP")

	var repair: EmergencyRepair = commander.get_node("EmergencyRepair")
	var charges_before := repair.charges
	var denied: Array[StringName] = []
	var on_denied := func(reason: StringName) -> void: denied.append(reason)
	EventBus.emergency_repair_denied.connect(on_denied)
	fortress.health.hp = 500
	EventBus.mode_changed.emit(&"COMMANDER")
	var key := InputEventAction.new()
	key.action = &"emergency_repair"
	key.pressed = true
	repair._unhandled_input(key)
	EventBus.emergency_repair_denied.disconnect(on_denied)
	assert_true(denied == [EmergencyRepair.REASON_BOSS_INTRO], "R is denied with BOSS_INTRO")
	assert_true(fortress.get_hp() == 500 and repair.charges == charges_before, "the Fortress is not repaired and no charge is spent")

	EventBus.mode_changed.emit(&"FRONTLINE")
	EventBus.state_changed.emit(&"COMBAT")
	await _press_and_step(commander, &"skill_1")
	assert_true(enemy.health.hp < hp, "after BOSS_INTRO the skill works again")
	enemy.free()
	commander.free()
	fortress.free()
	await get_tree().process_frame


func test_reward_slots() -> void:
	print("\n[GROUP 8] RewardService fills the slots and announces them")
	var pool := RewardPool.new()
	var skills: Array[SkillData] = [load("res://data/skills/whirlwind.tres"), load("res://data/skills/sword_wave.tres")]
	pool.skills = skills
	pool.cards_per_pick = 3
	var service := RewardService.new()
	service.pool = pool
	add_child(service)
	var emitted: Array = []
	var on_slots := func(active: Array, passive: Array, levels: Dictionary) -> void:
		emitted.append({"active": active, "passive": passive, "levels": levels})
	EventBus.skill_slots_changed.connect(on_slots)

	assert_true(_pick(service, &"sword_wave"), "Sword Wave is picked")
	var last: Dictionary = emitted[-1]
	assert_true(last.active == [&"sword_wave", &"", &""], "the first card takes slot 1")
	assert_true(last.levels == {&"sword_wave": 1}, "levels hold only ids that sit in a slot")
	assert_true(_pick(service, &"whirlwind"), "Whirlwind is picked")
	assert_true(service.state.active == [&"sword_wave", &"whirlwind", &""], "the next card takes the lowest empty slot")
	assert_true(_pick(service, &"whirlwind"), "Whirlwind is picked again")
	last = emitted[-1]
	assert_true(last.levels == {&"sword_wave": 1, &"whirlwind": 2}, "picking an owned card raises it from 1 to 2")
	assert_true(last.active == [&"sword_wave", &"whirlwind", &""], "the slots do not move on a level-up")

	service.offer_next()
	emitted.clear()
	service.skip()
	assert_true(emitted.size() == 1 and emitted[0].levels == {&"sword_wave": 1, &"whirlwind": 2}, "a skip announces the slots")
	emitted.clear()
	EventBus.run_started.emit()
	assert_true(emitted.size() == 1 and emitted[0].active == [&"", &"", &""] and emitted[0].levels.is_empty(), "a new run announces empty slots")
	EventBus.skill_slots_changed.disconnect(on_slots)
	service.free()
	await get_tree().process_frame


## Offers until the card shows up (skipping the offers without it), then picks it.
func _pick(service: RewardService, card_id: StringName) -> bool:
	for i in 40:
		for card in service.offer_next():
			if card.get("id") == card_id:
				return service.pick(card_id, &"", 0)
		service.skip()
	return false
