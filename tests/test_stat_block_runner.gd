extends Node

const CARDS_PATH := "res://data/skills/stat_cards.tres"
const STATS_PATH := "res://data/config/commander_stats.tres"
const EPS := 0.0001

var passes: int = 0
var fails: int = 0
var _stats: CharacterStats
var _table: StatCardTable


func _ready() -> void:
	print("\n=======================================================")
	print("          STAT BLOCK VERIFICATION RUNNER               ")
	print("=======================================================")
	_stats = load(STATS_PATH)
	_table = load(CARDS_PATH)

	test_base_values()
	test_add_and_mul()
	test_sources_replace_and_clear()
	test_armor_cap()
	test_card_table_levels()
	await test_reward_picked_signal()
	test_resource_untouched()
	await test_commander_integration()
	await test_lifesteal_kill_credit()

	print("=======================================================")
	print("STAT BLOCK TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================")
	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


func assert_near(actual: float, expected: float, test_name: String) -> void:
	assert_true(absf(actual - expected) < EPS, "%s (got %s, want %s)" % [test_name, actual, expected])


func _new_applier(block: StatBlock) -> StatCardApplier:
	var applier := StatCardApplier.new()
	applier.stat_block = block
	applier.table = _table
	add_child(applier)
	return applier


func test_base_values() -> void:
	print("\n[GROUP 1] Base values")
	var block := StatBlock.new(_stats)
	assert_near(block.get_value(&"sword_damage"), float(_stats.sword_damage), "sword_damage base")
	assert_near(block.get_value(&"move_speed"), _stats.move_speed, "move_speed base")
	assert_true(block.get_max_hp() == _stats.commander_max_hp, "max hp base")
	assert_near(block.get_value(&"unknown_key"), 0.0, "unknown key starts at 0")
	assert_near(StatBlock.new().get_value(&"sword_damage"), 0.0, "no stats resource gives 0")


func test_add_and_mul() -> void:
	print("\n[GROUP 2] Add and mul")
	var block := StatBlock.new(_stats)
	var base := float(_stats.sword_damage)

	block.set_add(&"sword_damage", &"a", 5.0)
	assert_near(block.get_value(&"sword_damage"), base + 5.0, "add only")
	block.set_add(&"sword_damage", &"b", 3.0)
	assert_near(block.get_value(&"sword_damage"), base + 8.0, "adds from two sources stack")

	block.clear_all()
	block.set_mul(&"sword_damage", &"a", 0.08)
	block.set_mul(&"sword_damage", &"b", 0.16)
	assert_near(block.get_value(&"sword_damage"), base * 1.24, "mul only, sums before applying")

	block.set_add(&"sword_damage", &"c", 10.0)
	assert_near(block.get_value(&"sword_damage"), (base + 10.0) * 1.24, "add applies before mul")

	var counter := [0]
	block.changed.connect(func() -> void: counter[0] += 1)
	block.set_add(&"move_speed", &"x", 1.0)
	assert_true(counter[0] == 1, "changed emitted on modifier")


func test_sources_replace_and_clear() -> void:
	print("\n[GROUP 3] Source replace and clear")
	var block := StatBlock.new(_stats)
	block.set_add(&"move_speed", &"boots", 1.0)
	block.set_add(&"move_speed", &"boots", 2.0)
	assert_near(block.get_value(&"move_speed"), _stats.move_speed + 2.0, "same source replaces")
	block.set_add(&"move_speed", &"boots", 0.0)
	assert_near(block.get_value(&"move_speed"), _stats.move_speed, "zero removes modifier")
	block.set_mul(&"move_speed", &"boots", 0.5)
	block.set_add(&"sword_damage", &"boots", 4.0)
	block.clear_source(&"boots")
	assert_near(block.get_value(&"move_speed"), _stats.move_speed, "clear_source drops mul")
	assert_near(block.get_value(&"sword_damage"), float(_stats.sword_damage), "clear_source drops add on every key")


func test_armor_cap() -> void:
	print("\n[GROUP 4] Armor cap")
	var block := StatBlock.new(_stats)
	var cap: float = GameConfig.commander_armor_cap
	assert_near(cap, 0.75, "cap comes from GameConfig")
	block.set_add(&"armor_pct", &"debug", 0.90)
	assert_near(block.get_value(&"armor_pct"), 0.90, "raw value is not clamped")
	assert_near(block.get_capped(&"armor_pct", cap), 0.75, "90% is clamped to the cap")
	block.set_add(&"armor_pct", &"debug", 0.15)
	assert_near(block.get_capped(&"armor_pct", cap), 0.15, "below the cap is unchanged")
	block.set_add(&"armor_pct", &"debug", -0.5)
	assert_near(block.get_capped(&"armor_pct", cap), 0.0, "never below zero")


func test_card_table_levels() -> void:
	print("\n[GROUP 5] Card levels")
	var block := StatBlock.new(_stats)
	var applier := _new_applier(block)

	applier.apply_pick(&"sharpness", 3)
	assert_near(block.get_mul_total(&"sword_damage"), 0.24, "sharpness L3 is +24%")
	assert_near(block.get_value(&"sword_damage"), float(_stats.sword_damage) * 1.24, "sharpness L3 damage")

	applier.apply_pick(&"armored", 3)
	assert_near(block.get_capped(&"armor_pct", GameConfig.commander_armor_cap), 0.15, "armored L3 is 15%")

	assert_near(block.get_mul_total(&"skill_damage"), 0.24, "sharpness L3 also raises skill damage")
	applier.apply_pick(&"mastery", 3)
	assert_near(block.get_mul_total(&"skill_damage"), 0.39, "mastery stacks with sharpness on skill damage")
	assert_near(block.get_mul_total(&"sword_damage"), 0.24, "mastery leaves sword damage alone")

	applier.apply_pick(&"lifesteal", 3)
	assert_near(block.get_value(&"lifesteal_pct"), 0.015, "lifesteal L3 is 1.5%")

	applier.apply_pick(&"heal_station", 0)
	assert_near(block.get_value(&"heal_rate_add"), 0.0, "heal station L0 adds nothing")
	for level in [1, 2, 3]:
		applier.apply_pick(&"heal_station", level)
		assert_near(block.get_value(&"heal_rate_add"), 5.0 * level, "heal bonus L%d" % level)
	assert_near(block.get_value(&"heal_rate_base"), _stats.heal_rate_base, "heal station leaves the base rate intact")

	applier.apply_pick(&"sharpness", 3)
	assert_near(block.get_mul_total(&"sword_damage"), 0.24, "picking the same level again does not stack")

	var changes := [0]
	block.changed.connect(func() -> void: changes[0] += 1)
	applier.apply_pick(&"unknown_card", 1)
	assert_true(changes[0] == 0, "unknown card changes nothing")

	applier.queue_free()


func test_reward_picked_signal() -> void:
	print("\n[GROUP 6] reward_picked signal")
	var block := StatBlock.new(_stats)
	var applier := _new_applier(block)
	var before := block.get_value(&"sword_damage")
	EventBus.reward_picked.emit(&"sharpness", &"PASSIVE", 1)
	assert_near(block.get_value(&"sword_damage"), before * 1.08, "recalculated right after the signal")
	EventBus.reward_picked.emit(&"sharpness", &"PASSIVE", 2)
	assert_near(block.get_value(&"sword_damage"), before * 1.16, "level up replaces the previous level")
	applier.queue_free()
	await get_tree().process_frame
	EventBus.reward_picked.emit(&"sharpness", &"PASSIVE", 3)
	assert_near(block.get_value(&"sword_damage"), before * 1.16, "freed applier no longer listens")


func test_resource_untouched() -> void:
	print("\n[GROUP 7] CharacterStats stays read-only")
	var snapshot := {}
	for prop in _stats.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			snapshot[prop.name] = _stats.get(prop.name)
	var block := StatBlock.new(_stats)
	var applier := _new_applier(block)
	for card in [&"sharpness", &"armored", &"lifesteal", &"heal_station", &"vitality", &"mastery"]:
		applier.apply_pick(card, 3)
	var same := true
	for key in snapshot:
		if _stats.get(key) != snapshot[key]:
			same = false
	assert_true(same, "no CharacterStats field changed")
	var reloaded: CharacterStats = ResourceLoader.load(STATS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_true(reloaded.commander_max_hp == _stats.commander_max_hp, "resource on disk matches")
	applier.queue_free()


func test_commander_integration() -> void:
	print("\n[GROUP 8] Commander integration")
	var commander: Node = (load("res://entities/commander/commander.tscn") as PackedScene).instantiate()
	add_child(commander)
	await get_tree().process_frame
	var base_max: int = _stats.commander_max_hp
	assert_true(commander.health.max_hp == base_max, "starts at base max hp")

	commander.health.hp = 50
	EventBus.reward_picked.emit(&"vitality", &"STAT", 1)
	assert_true(commander.health.max_hp == base_max + 10, "vitality 1 adds 10 max hp")
	assert_true(commander.health.hp == 60, "heals exactly the amount gained")

	EventBus.reward_picked.emit(&"vitality", &"STAT", 1)
	assert_true(commander.health.hp == 60, "repeated event heals nothing")

	EventBus.reward_picked.emit(&"vitality", &"STAT", 3)
	assert_true(commander.health.max_hp == base_max + 30, "vitality 3 is flat, not compounding")
	assert_true(commander.health.hp == 80, "second and third pick heal 20 in total")

	commander.health.hp = commander.health.max_hp
	EventBus.reward_picked.emit(&"armored", &"PASSIVE", 3)
	var before_hp: int = commander.health.hp
	commander.take_damage(DamageInfo.new(100, Enums.DamageType.SLASH))
	# Damage is rounded up, so float noise in 1 - 0.15 may land on 85 or 86.
	assert_true(absf(float(before_hp - commander.health.hp) - 85.0) <= 1.0, "armor 15% reduces 100 damage to about 85")

	EventBus.reward_picked.emit(&"heal_station", &"PASSIVE", 2)
	var channel: HealChannel = commander.get_node("HealChannel")
	assert_near(channel.get_heal_rate(), _stats.heal_rate_base + 10.0, "heal channel reads rate from stat block")

	commander.queue_free()
	await get_tree().process_frame


func test_lifesteal_kill_credit() -> void:
	print("\n[GROUP 9] Lifesteal kill credit")
	var run_state := RunState.new()
	add_child(run_state)
	var commander: Node = preload("res://entities/commander/commander.tscn").instantiate()
	add_child(commander)
	commander.set_physics_process(false)
	await get_tree().process_frame
	commander.health.hp = 50
	var shown_hp := [50]
	var track_hp := func(hp: int, _max_hp: int) -> void: shown_hp[0] = hp
	EventBus.commander_hp_changed.connect(track_hp)
	var rewards := RewardService.new()
	rewards.pool = preload("res://data/config/reward_pool.tres")
	add_child(rewards)
	for _attempt in 30:
		rewards.offer_next()
		if rewards.pick(&"lifesteal", &"PASSIVE", 1):
			break
		rewards.skip()
	assert_true(rewards.state.get_level(&"lifesteal") == 1, "lifesteal is picked from the run reward pool")

	var marked := _new_kill_target()
	marked.take_damage(DamageInfo.new(1, Enums.DamageType.SLASH, commander))
	marked.take_damage(100)
	assert_near(commander.health.get_precise_hp(), 50.0, "prior commander hit gives no lifesteal on a different killing blow")
	marked.free()

	var sword_target := _new_kill_target()
	sword_target.take_damage(DamageInfo.new(100, Enums.DamageType.SLASH, commander))
	sword_target.take_damage(DamageInfo.new(100, Enums.DamageType.SLASH, commander))
	assert_near(commander.health.get_precise_hp(), 50.5, "one sword kill heals exactly half an HP")
	assert_near(run_state.commander_hp, 50.5, "run state keeps fractional HP")
	assert_true(shown_hp[0] == 50, "HUD gets floored HP")
	sword_target.free()

	var burn_target := _new_kill_target()
	burn_target.health.hp = 6
	var zone := FirebombZone.new()
	zone.setup(commander, preload("res://data/skills/firebomb.tres"), 1, 1.0)
	add_child(zone)
	zone.tick(1.0)
	assert_true(burn_target.is_dead, "firebomb tick kills its target")
	assert_near(commander.health.get_precise_hp(), 51.0, "a second kill from a Firebomb tick completes one HP")
	assert_true(shown_hp[0] == 51, "HUD shows the completed HP")
	zone.free()
	burn_target.free()

	var boss := preload("res://entities/enemy/bulwark.tscn").instantiate() as Bulwark
	add_child(boss)
	boss.set_physics_process(false)
	boss.spawn_grace = false
	boss.current_armor_hp = 1
	var blast := DamageInfo.new(10, Enums.DamageType.BLAST, commander)
	boss.take_damage(blast)
	assert_true(not boss.is_dead, "breaking Bulwark's armor leaves its core alive")
	assert_near(commander.health.get_precise_hp(), 51.0, "breaking armor grants no lifesteal")
	boss.current_core_hp = 1
	boss.take_damage(blast)
	assert_true(boss.is_dead, "the lethal hit destroys Bulwark's core")
	assert_near(commander.health.get_precise_hp(), 51.5, "the final core hit grants lifesteal once")
	boss.free()

	EventBus.commander_hp_changed.disconnect(track_hp)
	rewards.free()
	commander.free()
	run_state.free()


func _new_kill_target() -> Enemy:
	var enemy := preload("res://entities/enemy/grunt.tscn").instantiate() as Enemy
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.spawn_grace = false
	return enemy
