extends Node

## Automated test runner for W6-KT4:
## - EnemyData.xp_value per archetype (XP-01: Grunt 1, Archer 2, Brute 5, Boss 30)
## - DamageInfo hit_by_commander flag and source detection
## - HealthComponent hit_by_commander: flips on first damage >= 1 from commander
## - Immutability of hit_by_commander flag (never reverts on non-commander hit or heal)
## - Battle Cry does NOT flip hit_by_commander (XP-03)
## - Enemy entity exposure and death signal forwarding

const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const ARCHER_SCENE: PackedScene = preload("res://entities/enemy/archer.tscn")
const BRUTE_SCENE: PackedScene = preload("res://entities/enemy/brute.tscn")

const GRUNT_DATA: EnemyData = preload("res://data/enemies/grunt.tres")
const ARCHER_DATA: EnemyData = preload("res://data/enemies/archer.tres")
const BRUTE_DATA: EnemyData = preload("res://data/enemies/brute.tres")
const BULWARK_DATA: EnemyData = preload("res://data/enemies/bulwark.tres")

var passes: int = 0
var fails: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED W6-KT4 XP & HIT FLAG TEST RUNNER      ")
	print("=======================================================")

	test_xp01_enemy_data_xp_values()
	test_damage_info_commander_detection()
	test_health_component_flag_transitions()
	test_battle_cry_does_not_flip_flag()
	test_enemy_entity_flag_and_death_event()

	print("=======================================================")
	print("W6-KT4 TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")

	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


func test_xp01_enemy_data_xp_values() -> void:
	print("\n[GROUP 1] Testing XP-01 EnemyData xp_value Configuration")
	assert_true(GRUNT_DATA != null, "Grunt EnemyData resource loaded successfully")
	assert_true(GRUNT_DATA.xp_value == 1, "Grunt xp_value == 1 (XP-01)")

	assert_true(ARCHER_DATA != null, "Archer EnemyData resource loaded successfully")
	assert_true(ARCHER_DATA.xp_value == 2, "Archer xp_value == 2 (XP-01)")

	assert_true(BRUTE_DATA != null, "Brute EnemyData resource loaded successfully")
	assert_true(BRUTE_DATA.xp_value == 5, "Brute xp_value == 5 (XP-01)")

	assert_true(BULWARK_DATA != null, "Bulwark EnemyData resource loaded successfully")
	assert_true(BULWARK_DATA.xp_value == 30, "Bulwark boss xp_value == 30 (XP-01)")

	var boss_data := BossData.new()
	assert_true(boss_data.xp_value == 30, "BossData default instance xp_value == 30 (XP-01)")


func test_damage_info_commander_detection() -> void:
	print("\n[GROUP 2] Testing DamageInfo hit_by_commander & Source Detection")
	var default_info := DamageInfo.new(10)
	assert_true(not default_info.hit_by_commander, "Default DamageInfo has hit_by_commander == false")
	assert_true(not default_info.is_from_commander(), "Default DamageInfo is_from_commander() == false")

	var explicit_info := DamageInfo.new(10, Enums.DamageType.SLASH, null, 0.0, Vector3.ZERO, true)
	assert_true(explicit_info.hit_by_commander, "Explicit p_hit_by_commander = true sets flag")
	assert_true(explicit_info.is_from_commander(), "Explicit p_hit_by_commander is_from_commander() == true")

	var str_source_info := DamageInfo.new(10, Enums.DamageType.SLASH, "commander")
	assert_true(str_source_info.hit_by_commander, "source='commander' string auto-detects hit_by_commander")

	var sym_source_info := DamageInfo.new(10, Enums.DamageType.SLASH, &"commander")
	assert_true(sym_source_info.hit_by_commander, "source=&'commander' StringName auto-detects hit_by_commander")

	var cmd_node := Node.new()
	cmd_node.add_to_group(&"commander")
	var node_source_info := DamageInfo.new(15, Enums.DamageType.SLASH, cmd_node)
	assert_true(node_source_info.hit_by_commander, "Node in group &'commander' auto-detects hit_by_commander")
	assert_true(node_source_info.is_from_commander(), "node_source_info is_from_commander() == true")
	cmd_node.free()

	var tower_node := Node.new()
	tower_node.add_to_group(&"tower")
	var tower_info := DamageInfo.new(20, Enums.DamageType.PIERCE, tower_node)
	assert_true(not tower_info.hit_by_commander, "Node in group &'tower' does NOT set hit_by_commander")
	assert_true(not tower_info.is_from_commander(), "tower_info is_from_commander() == false")
	tower_node.free()


func test_health_component_flag_transitions() -> void:
	print("\n[GROUP 3] Testing HealthComponent hit_by_commander Activation & Persistence")
	var hc := HealthComponent.new()
	hc.max_hp = 100
	hc._ready()

	assert_true(not hc.hit_by_commander, "HealthComponent initial hit_by_commander == false")

	# Damage from non-commander source
	var tower_info := DamageInfo.new(10, Enums.DamageType.PIERCE, "tower")
	hc.take_damage(tower_info)
	assert_true(hc.hp == 90, "HealthComponent took 10 damage from tower")
	assert_true(not hc.hit_by_commander, "hit_by_commander remains false after tower damage")

	# 0 damage from commander
	var zero_cmd_info := DamageInfo.new(0, Enums.DamageType.SLASH, "commander")
	hc.take_damage(zero_cmd_info)
	assert_true(hc.hp == 90, "HealthComponent HP unchanged on 0 damage")
	assert_true(not hc.hit_by_commander, "0 damage from commander does NOT activate hit_by_commander")

	# First damage >= 1 from commander
	var cmd_info := DamageInfo.new(12, Enums.DamageType.SLASH, "commander")
	hc.take_damage(cmd_info)
	assert_true(hc.hp == 78, "HealthComponent took 12 damage from commander")
	assert_true(hc.hit_by_commander, "hit_by_commander flips to true on first damage >= 1 from commander (XP-03)")

	# Subsequent non-commander damage should NOT revert the flag
	var tower_info_2 := DamageInfo.new(15, Enums.DamageType.MAGIC, "tower")
	hc.take_damage(tower_info_2)
	assert_true(hc.hp == 63, "HealthComponent took subsequent 15 damage from tower")
	assert_true(hc.hit_by_commander, "hit_by_commander remains true after subsequent non-commander damage")

	# Heal should NOT revert the flag
	hc.heal(20)
	assert_true(hc.hp == 83, "HealthComponent healed 20 HP")
	assert_true(hc.hit_by_commander, "hit_by_commander remains true after heal")

	hc.free()


func test_battle_cry_does_not_flip_flag() -> void:
	print("\n[GROUP 4] Testing Battle Cry Interaction (Taunt Must NOT Flip Flag)")
	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt.spawn_grace = false
	grunt.is_in_spawn_zone = false
	add_child(grunt)

	var cmd_dummy := Node3D.new()
	cmd_dummy.add_to_group(&"commander")
	add_child(cmd_dummy)

	assert_true(not grunt.hit_by_commander, "Grunt initially has hit_by_commander == false")
	assert_true(not grunt.health.hit_by_commander, "Grunt health has hit_by_commander == false")

	# Execute Battle Cry taunt
	grunt.apply_commander_taunt(cmd_dummy, 4.0)

	assert_true(grunt.taunted_by_player, "Grunt taunted_by_player is true after Battle Cry")
	assert_true(grunt.provoked_by_player, "Grunt provoked_by_player is true after Battle Cry")
	assert_true(grunt.health.hp == grunt.health.max_hp, "Grunt HP remains at full (no damage taken)")
	assert_true(not grunt.hit_by_commander, "Battle Cry does NOT flip hit_by_commander on Enemy (Acceptance Criteria)")
	assert_true(not grunt.health.hit_by_commander, "Battle Cry does NOT flip hit_by_commander on HealthComponent")

	cmd_dummy.queue_free()
	grunt.queue_free()


func test_enemy_entity_flag_and_death_event() -> void:
	print("\n[GROUP 5] Testing Enemy Strike and Death Event with hit_by_commander")
	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt.spawn_grace = false
	grunt.is_in_spawn_zone = false
	add_child(grunt)

	var cmd_dummy := Node3D.new()
	cmd_dummy.add_to_group(&"commander")
	add_child(cmd_dummy)

	# Strike grunt with commander sword strike damage
	var sword_dmg := DamageInfo.new(15, Enums.DamageType.SLASH, cmd_dummy)
	grunt.take_damage(sword_dmg)

	assert_true(grunt.hit_by_commander, "Enemy.hit_by_commander is true after commander sword damage")
	assert_true(grunt.health.hit_by_commander, "Enemy.health.hit_by_commander is true after commander sword damage")

	# Listen to EventBus.enemy_died to verify hit_by_commander parameter
	var death_record := {"emitted": false, "hit_by_cmd": false, "gold": 0}
	var on_died := func(_type: StringName, _pos: Vector3, gold: int, _prestige: int, _cull: bool, hit_by_cmd: bool = false):
		death_record.emitted = true
		death_record.hit_by_cmd = hit_by_cmd
		death_record.gold = gold

	EventBus.enemy_died.connect(on_died)

	# Trigger death
	grunt._on_died()

	assert_true(death_record.emitted, "EventBus.enemy_died emitted on enemy death")
	assert_true(death_record.hit_by_cmd == true, "EventBus.enemy_died received hit_by_commander == true")

	EventBus.enemy_died.disconnect(on_died)
	cmd_dummy.queue_free()
	grunt.queue_free()
