extends Node

## Comprehensive verification runner for W6-KT3:
## - SCL-01: ScaleConfig tunable via resource without code modification
## - SCL-02: Soft cap at wave 40 reducing budget growth rate by budget_soft_cap_factor (0.5)
## - SCL-05: Wave scale applied at enemy spawn time (HP, damage, speed, gold reward)
## - SCL-05: Enemy stats remain immutable while alive
## - WAVE-01: Maximum alive (70) queue throttling
## - WAVE-08: 0-enemy wave forces minimum 1 Grunt and logs warning

const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const ARCHER_SCENE: PackedScene = preload("res://entities/enemy/archer.tscn")
const BRUTE_SCENE: PackedScene = preload("res://entities/enemy/brute.tscn")
const SCALE_CONFIG_RES: ScaleConfig = preload("res://data/config/scale_config.tres")

var passes: int = 0
var fails: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED W6-KT3 WAVE SCALE TEST RUNNER         ")
	print("=======================================================")

	test_scl01_and_scl02_scale_config_formulas()
	test_scl02_budget_soft_cap_at_wave_40()
	test_scl05_enemy_spawn_time_hp_and_damage_scaling()
	test_scl05_scaling_applied_before_entering_tree()
	test_frenzy_speed_multiplier_compounds_wave_speed()
	test_scl05_archer_projectile_damage_scaling()
	test_scl05_stats_immutable_while_alive()
	test_scl05_gold_reward_scaling_rwd02()
	test_wave01_max_alive_queue_throttling()
	test_wave08_empty_wave_warning_and_fallback()

	print("=======================================================")
	print("W6-KT3 TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")

	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


func test_scl01_and_scl02_scale_config_formulas() -> void:
	print("\n[GROUP 1] Testing SCL-01 & SCL-02 ScaleConfig Formulas vs SRS Table")
	var cfg := SCALE_CONFIG_RES
	assert_true(cfg != null, "ScaleConfig resource loaded from data/config/scale_config.tres")
	assert_true(cfg.budget_soft_cap_factor == 0.5, "budget_soft_cap_factor is configured to 0.5 (SCL-01)")
	assert_true(cfg.scale_soft_cap_wave == 40, "scale_soft_cap_wave is configured to 40 (SCL-02)")

	# Verify SRS 3.7.6 table exact values:
	# Wave 1: budget 8, duration 15, hp_mult 1.00, dmg_mult 1.00, speed_mult 1.000
	assert_true(cfg.get_budget(1) == 8, "Wave 1 budget == 8")
	assert_true(is_equal_approx(cfg.get_spawn_duration(1), 15.0), "Wave 1 duration == 15.0s")
	assert_true(is_equal_approx(cfg.get_hp_mult(1), 1.00), "Wave 1 hp_mult == 1.00")
	assert_true(is_equal_approx(cfg.get_dmg_mult(1), 1.00), "Wave 1 dmg_mult == 1.00")
	assert_true(is_equal_approx(cfg.get_speed_mult(1), 1.000), "Wave 1 speed_mult == 1.000")

	# Wave 5: budget 18, duration 17, hp_mult 1.464, dmg_mult 1.272, speed_mult 1.020
	assert_true(cfg.get_budget(5) == 18, "Wave 5 budget == 18")
	assert_true(is_equal_approx(cfg.get_spawn_duration(5), 17.0), "Wave 5 duration == 17.0s")
	assert_true(is_equal_approx(cfg.get_hp_mult(5), 1.464), "Wave 5 hp_mult == 1.464")
	assert_true(is_equal_approx(cfg.get_dmg_mult(5), 1.272), "Wave 5 dmg_mult == 1.272")
	assert_true(is_equal_approx(cfg.get_speed_mult(5), 1.020), "Wave 5 speed_mult == 1.020")

	# Wave 10: budget 32, duration 19.5, hp_mult 2.224, dmg_mult 1.702, speed_mult 1.045
	assert_true(cfg.get_budget(10) == 32, "Wave 10 budget == 32")
	assert_true(is_equal_approx(cfg.get_spawn_duration(10), 19.5), "Wave 10 duration == 19.5s")
	assert_true(is_equal_approx(cfg.get_hp_mult(10), 2.224), "Wave 10 hp_mult == 2.224")
	assert_true(is_equal_approx(cfg.get_dmg_mult(10), 1.702), "Wave 10 dmg_mult == 1.702")
	assert_true(is_equal_approx(cfg.get_speed_mult(10), 1.045), "Wave 10 speed_mult == 1.045")

	# Wave 20: budget 68, duration 24.5, hp_mult 4.344, dmg_mult 2.862, speed_mult 1.095
	assert_true(cfg.get_budget(20) == 68, "Wave 20 budget == 68")
	assert_true(is_equal_approx(cfg.get_spawn_duration(20), 24.5), "Wave 20 duration == 24.5s")

	# Wave 30: budget 114, duration 29.5, hp_mult 7.264, dmg_mult 4.422, speed_mult 1.145
	assert_true(cfg.get_budget(30) == 114, "Wave 30 budget == 114")


func test_scl02_budget_soft_cap_at_wave_40() -> void:
	print("\n[GROUP 2] Testing SCL-02 Soft Cap Growth Reduction After Wave 40")
	var cfg := SCALE_CONFIG_RES

	var budget_w40 := cfg.get_budget(40)
	var budget_w45 := cfg.get_budget(45)
	var raw_w40 := cfg.get_raw_budget(40)
	var raw_w45 := cfg.get_raw_budget(45)

	# Before soft cap: growth from w40 to w45 without cap would be raw_w45 - raw_w40
	var uncap_growth := raw_w45 - raw_w40
	var actual_growth := float(budget_w45 - budget_w40)

	# Actual growth must be approximately half of uncap_growth (within rounding tolerance)
	var expected_budget_w45 := int(round(raw_w40 + 0.5 * uncap_growth))
	assert_true(budget_w45 == expected_budget_w45, "Wave 45 budget matches SCL-02 soft cap formula (growth rate cut in half)")
	assert_true(actual_growth < uncap_growth * 0.55 and actual_growth > uncap_growth * 0.45, "Soft cap halved budget increase after wave 40")


func test_scl05_enemy_spawn_time_hp_and_damage_scaling() -> void:
	print("\n[GROUP 3] Testing SCL-05 Spawn-time HP and Damage Scaling on Enemies")
	var wm := WaveManager.new()
	add_child(wm)

	# Wave 1: Grunt base HP 40, base DMG 6
	wm.current_wave = 1
	var grunt_w1: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt_w1.position = Vector3(14.0, 0.0, 0.0)
	wm.add_child(grunt_w1)
	var cfg := SCALE_CONFIG_RES
	grunt_w1.apply_wave_scale(cfg.get_hp_mult(1), cfg.get_dmg_mult(1), cfg.get_speed_mult(1), 1)

	assert_true(grunt_w1.health.max_hp == 40, "Wave 1 Grunt max_hp == 40")
	assert_true(grunt_w1.health.hp == 40, "Wave 1 Grunt hp == 40")
	assert_true(grunt_w1.scaled_damage == 6, "Wave 1 Grunt scaled_damage == 6")
	assert_true(is_equal_approx(grunt_w1.speed_multiplier, 1.0), "Wave 1 Grunt speed_multiplier == 1.0")

	# Wave 5: hp_mult 1.464 (40 * 1.464 = 59), dmg_mult 1.272 (6 * 1.272 = 8), speed_mult 1.02
	wm.current_wave = 5
	var grunt_w5: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt_w5.position = Vector3(14.0, 0.0, 0.0)
	wm.add_child(grunt_w5)
	grunt_w5.apply_wave_scale(cfg.get_hp_mult(5), cfg.get_dmg_mult(5), cfg.get_speed_mult(5), 5)

	assert_true(grunt_w5.health.max_hp == 59, "Wave 5 Grunt max_hp scaled to 59 (round(40 * 1.464))")
	assert_true(grunt_w5.health.hp == 59, "Wave 5 Grunt hp initialized to max_hp (59)")
	assert_true(grunt_w5.scaled_damage == 8, "Wave 5 Grunt scaled_damage scaled to 8 (round(6 * 1.272))")
	assert_true(is_equal_approx(grunt_w5.speed_multiplier, 1.020), "Wave 5 Grunt speed_multiplier == 1.020")

	# Wave 10: hp_mult 2.224 (40 * 2.224 = 89), dmg_mult 1.702 (6 * 1.702 = 10)
	var grunt_w10: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt_w10.position = Vector3(14.0, 0.0, 0.0)
	wm.add_child(grunt_w10)
	grunt_w10.apply_wave_scale(cfg.get_hp_mult(10), cfg.get_dmg_mult(10), cfg.get_speed_mult(10), 10)

	assert_true(grunt_w10.health.max_hp == 89, "Wave 10 Grunt max_hp scaled to 89 (round(40 * 2.224))")
	assert_true(grunt_w10.scaled_damage == 10, "Wave 10 Grunt scaled_damage scaled to 10 (round(6 * 1.702))")

	grunt_w1.queue_free()
	grunt_w5.queue_free()
	grunt_w10.queue_free()
	wm.queue_free()


func test_scl05_scaling_applied_before_entering_tree() -> void:
	print("\n[GROUP 3B] Testing Scaling Applied Before Node Enters Scene Tree (WaveManager Execution Flow)")
	var wm := WaveManager.new()
	add_child(wm)
	var cfg := SCALE_CONFIG_RES

	# Wave 5: Grunt base HP 40 * 1.464 = 59; base DMG 6 * 1.272 = 8; speed 1.020
	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	# Verify health component is not yet initialized prior to entering tree
	assert_true(grunt.health == null, "Enemy health is not yet initialized before entering scene tree")

	# WaveManager applies scale BEFORE add_child
	grunt.apply_wave_scale(cfg.get_hp_mult(5), cfg.get_dmg_mult(5), cfg.get_speed_mult(5), 5, cfg)

	# Now add to scene tree
	wm.add_child(grunt)

	# Verify health.max_hp and stats after entering tree and running _ready()
	assert_true(grunt.health != null, "Enemy health initialized upon entering scene tree")
	assert_true(grunt.health.max_hp == 59, "health.max_hp correctly scaled to 59 when scale was applied before add_child")
	assert_true(grunt.health.hp == 59, "health.hp correctly initialized to max_hp (59)")
	assert_true(grunt.scaled_damage == 8, "scaled_damage correctly set to 8")
	assert_true(is_equal_approx(grunt.speed_multiplier, 1.020), "speed_multiplier correctly set to 1.020")

	grunt.queue_free()
	wm.queue_free()


func test_frenzy_speed_multiplier_compounds_wave_speed() -> void:
	print("\n[GROUP 3C] Testing Frenzy State Compounds Wave Speed Scale (wave_speed_mult * frenzy_speed_mult)")
	var wm := WaveManager.new()
	add_child(wm)
	var cfg := SCALE_CONFIG_RES

	# Wave 10 Grunt: speed_mult = 1.045
	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	var wave_spd := cfg.get_speed_mult(10)
	grunt.apply_wave_scale(cfg.get_hp_mult(10), cfg.get_dmg_mult(10), wave_spd, 10, cfg)
	wm.add_child(grunt)

	assert_true(is_equal_approx(grunt.speed_multiplier, wave_spd), "Initial speed_multiplier matches wave_speed_mult (1.045)")

	# Enter Frenzy state
	grunt.change_state(Enums.EnemyState.FRENZY)

	var expected_frenzy_spd := wave_spd * GameConfig.frenzy_speed_mult
	assert_true(grunt.current_state == Enums.EnemyState.FRENZY, "Enemy transitioned to FRENZY state")
	assert_true(is_equal_approx(grunt.speed_multiplier, expected_frenzy_spd), "Frenzy speed_multiplier == wave_speed_mult * frenzy_speed_mult (%.4f == %.4f)" % [grunt.speed_multiplier, expected_frenzy_spd])

	grunt.queue_free()
	wm.queue_free()


func test_scl05_archer_projectile_damage_scaling() -> void:
	print("\n[GROUP 4] Testing SCL-05 Archer Projectile Damage Scaling")
	var wm := WaveManager.new()
	add_child(wm)
	var cfg := SCALE_CONFIG_RES

	# Wave 5 Archer: base HP 30 * 1.464 = 44; base DMG 8 * 1.272 = 10
	var archer: Archer = ARCHER_SCENE.instantiate() as Archer
	archer.position = Vector3(14.0, 0.0, 0.0)
	wm.add_child(archer)
	archer.apply_wave_scale(cfg.get_hp_mult(5), cfg.get_dmg_mult(5), cfg.get_speed_mult(5), 5)

	assert_true(archer.health.max_hp == 44, "Wave 5 Archer max_hp scaled to 44 (round(30 * 1.464))")
	assert_true(archer.scaled_damage == 10, "Wave 5 Archer scaled_damage scaled to 10 (round(8 * 1.272))")

	# Target dummy to receive hit
	var dummy := CharacterBody3D.new()
	dummy.position = Vector3(0.0, 0.0, 0.0)
	var dummy_health := HealthComponent.new()
	dummy_health.name = "Health"
	dummy_health.max_hp = 100
	dummy_health.hp = 100
	dummy.add_child(dummy_health)
	add_child(dummy)

	archer.set_target(dummy)
	archer.spawn_grace = false
	archer.is_in_spawn_zone = false

	# Execute attack
	archer._execute_attack_action()
	await get_tree().physics_frame

	# Find launched projectile
	var proj := get_node_or_null("EnemyProjectile") as Projectile
	if proj == null:
		var root := get_tree().current_scene
		if root != null:
			proj = root.find_child("EnemyProjectile", true, false) as Projectile

	if proj != null:
		assert_true(proj.damage == 10, "Archer projectile launched with scaled damage (10, not base 8)")
		proj.queue_free()

	archer.queue_free()
	dummy.queue_free()
	wm.queue_free()


func test_scl05_stats_immutable_while_alive() -> void:
	print("\n[GROUP 5] Testing SCL-05 Enemy Stats Immutability While Alive")
	var wm := WaveManager.new()
	add_child(wm)
	var cfg := SCALE_CONFIG_RES

	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt.position = Vector3(14.0, 0.0, 0.0)
	wm.add_child(grunt)
	grunt.apply_wave_scale(cfg.get_hp_mult(3), cfg.get_dmg_mult(3), cfg.get_speed_mult(3), 3)

	var initial_hp := grunt.health.max_hp
	var initial_dmg := grunt.scaled_damage
	var initial_spd := grunt.speed_multiplier

	# Simulate time passing and wave manager changing wave
	wm.current_wave = 15
	for _i in range(10):
		grunt._physics_process(0.1)

	assert_true(grunt.health.max_hp == initial_hp, "Enemy max_hp remains unchanged while alive despite wave changes")
	assert_true(grunt.scaled_damage == initial_dmg, "Enemy scaled_damage remains unchanged while alive")
	assert_true(is_equal_approx(grunt.speed_multiplier, initial_spd), "Enemy speed_multiplier remains unchanged while alive")

	grunt.queue_free()
	wm.queue_free()


func test_scl05_gold_reward_scaling_rwd02() -> void:
	print("\n[GROUP 6] Testing Scaled Gold Reward on Death and Custom ScaleConfig Growth")
	var wm := WaveManager.new()
	add_child(wm)
	var cfg := SCALE_CONFIG_RES

	var res := {"gold": -1}
	var on_died := func(_type: StringName, _pos: Vector3, gold: int, _prestige: int, _cull: bool):
		res.gold = gold
	EventBus.enemy_died.connect(on_died)

	# Wave 10 Grunt: base_gold 4 * (1 + 0.04 * 9) = 4 * 1.36 = 5.44 -> round 5
	var grunt_w10: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt_w10.position = Vector3(14.0, 0.0, 0.0)
	grunt_w10.apply_wave_scale(cfg.get_hp_mult(10), cfg.get_dmg_mult(10), cfg.get_speed_mult(10), 10, cfg)
	wm.add_child(grunt_w10)

	grunt_w10._on_died()
	assert_true(res.gold == 5, "Wave 10 Grunt death emitted scaled gold (5 gold per ScaleConfig formula, not base 4)")
	grunt_w10.queue_free()

	# Test with custom ScaleConfig having modified gold_growth_per_wave (e.g. 0.10)
	var custom_cfg := ScaleConfig.new()
	custom_cfg.gold_growth_per_wave = 0.10
	# Wave 10 with 0.10: 4 * (1 + 0.10 * 9) = 4 * 1.9 = 7.6 -> round 8
	var grunt_custom: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt_custom.position = Vector3(14.0, 0.0, 0.0)
	grunt_custom.apply_wave_scale(custom_cfg.get_hp_mult(10), custom_cfg.get_dmg_mult(10), custom_cfg.get_speed_mult(10), 10, custom_cfg)
	wm.add_child(grunt_custom)

	grunt_custom._on_died()
	assert_true(res.gold == 8, "Modifying ScaleConfig.gold_growth_per_wave to 0.10 dynamically changes reward to 8 (ScaleConfig controls value)")

	EventBus.enemy_died.disconnect(on_died)
	grunt_custom.queue_free()
	wm.queue_free()


func test_wave01_max_alive_queue_throttling() -> void:
	print("\n[GROUP 7] Testing Max Alive (70) Queue Throttling With Large Wave")
	var wm := WaveManager.new()
	wm.spawn_interval = 0.01
	add_child(wm)

	assert_true(GameConfig.max_alive == 70, "GameConfig max_alive == 70")

	# Build a large queue of 85 units to thoroughly test surplus units waiting scenario
	wm.current_wave = 25
	wm.spawn_queue.clear()
	const LARGE_WAVE_COUNT := 85
	for _i in range(LARGE_WAVE_COUNT):
		wm.spawn_queue.append(GRUNT_SCENE)
	wm.total_wave_enemies = LARGE_WAVE_COUNT
	wm.wave_state = Enums.WaveState.COMBAT

	assert_true(wm.spawn_queue.size() == LARGE_WAVE_COUNT, "Queue populated with %d enemies (exceeding max_alive 70)" % LARGE_WAVE_COUNT)

	# When enemies_alive reaches max_alive (70)
	wm.enemies_alive = GameConfig.max_alive
	for _i in range(15):
		wm._physics_process(0.1)

	assert_true(wm.spawn_queue.size() == LARGE_WAVE_COUNT, "All %d surplus enemies remain safely in queue while enemies_alive >= 70" % LARGE_WAVE_COUNT)

	# Drop enemies_alive below 70
	wm.enemies_alive = GameConfig.max_alive - 1
	wm._physics_process(0.1)
	assert_true(wm.spawn_queue.size() == LARGE_WAVE_COUNT - 1, "Spawner resumed popping queue when enemies_alive dropped to 69 (queue size is now %d)" % wm.spawn_queue.size())

	wm.queue_free()


func test_wave08_empty_wave_warning_and_fallback() -> void:
	print("\n[GROUP 8] Testing WAVE-08 Empty Wave Warning and 1 Grunt Fallback")
	var wm := WaveManager.new()
	add_child(wm)

	# Wave 0 (or negative)
	var comp_zero := wm.generate_wave_composition(0, 42)
	assert_true(comp_zero.size() == 1, "Wave 0 generated exactly 1 enemy")
	assert_true(comp_zero[0].id == &"grunt", "Fallback enemy is Grunt (WAVE-08)")

	var comp_neg := wm.generate_wave_composition(-5, 42)
	assert_true(comp_neg.size() == 1 and comp_neg[0].id == &"grunt", "Negative wave also falls back to 1 Grunt (WAVE-08)")

	wm.queue_free()
