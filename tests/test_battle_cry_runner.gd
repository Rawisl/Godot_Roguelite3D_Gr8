extends Node

var passes: int = 0
var fails: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED BATTLE CRY VERIFICATION RUNNER        ")
	print("=======================================================")

	test_stats_parameters()
	test_skill_activation_and_timers()
	test_damage_reduction()
	test_aoe_taunt()
	test_boss_immunity()
	test_leash_distance()
	test_event_bus_cooldown_signal()
	test_mode_switch_and_death_cleanup()
	test_max_aggro_melee_limit()

	print("=======================================================")
	print("BATTLE CRY TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================")

	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


func test_stats_parameters() -> void:
	print("\n[GROUP 1] Testing CharacterStats Battle Cry parameters")
	var stats: CharacterStats = load("res://data/config/commander_stats.tres")
	assert_true(stats != null, "commander_stats.tres loaded successfully")
	if stats == null:
		return

	assert_true(is_equal_approx(stats.skill_cooldown, 12.0), "skill_cooldown == 12.0 s")
	assert_true(is_equal_approx(stats.skill_animation_time, 0.5), "skill_animation_time == 0.5 s")
	assert_true(is_equal_approx(stats.battle_cry_radius, 6.0), "battle_cry_radius == 6.0 m")
	assert_true(is_equal_approx(stats.battle_cry_duration, 4.0), "battle_cry_duration == 4.0 s")
	assert_true(is_equal_approx(stats.battle_cry_damage_mult, 0.7), "battle_cry_damage_mult == 0.7")


func test_skill_activation_and_timers() -> void:
	print("\n[GROUP 2] Testing Skill Activation and Timers")
	var scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander: CharacterBody3D = scene.instantiate()
	add_child(commander)

	assert_true(not commander.is_using_skill, "Initial is_using_skill is false")
	assert_true(is_equal_approx(commander._battle_cry_cd_timer, 0.0), "Initial cooldown timer is 0.0")

	commander._start_battle_cry()

	assert_true(commander.is_using_skill, "is_using_skill becomes true on activation")
	assert_true(is_equal_approx(commander._skill_timer, 0.5), "Skill lock timer set to 0.5s")
	assert_true(is_equal_approx(commander._battle_cry_cd_timer, 12.0), "Cooldown initialized to 12.0s")
	assert_true(is_equal_approx(commander._battle_cry_active_timer, 4.0), "Buff duration initialized to 4.0s")
	assert_true(commander.velocity.is_zero_approx(), "Velocity reset on activation")

	# Simulate 0.5s passing
	commander._update_cooldowns_and_timers(0.5)

	assert_true(not commander.is_using_skill, "Skill lock ends after 0.5s")
	assert_true(is_equal_approx(commander._battle_cry_cd_timer, 11.5), "Cooldown timer decreased by 0.5s")
	# Verify skill cannot be triggered when dead
	commander.health.hp = 0
	commander._battle_cry_cd_timer = 0.0
	commander._check_skill_input()
	assert_true(not commander.is_using_skill, "Skill cannot be activated when dead")

	commander.free()


func test_damage_reduction() -> void:
	print("\n[GROUP 3] Testing Damage Reduction and True Damage")
	var scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander: CharacterBody3D = scene.instantiate()
	add_child(commander)

	commander.health.hp = 100
	commander.stats.armor_pct = 0.0

	# Activate buff
	commander._battle_cry_active_timer = 4.0

	# 0 damage remains 0 damage
	var zero_dmg := DamageInfo.new(0, Enums.DamageType.SLASH)
	commander.take_damage(zero_dmg)
	assert_true(commander.health.hp == 100, "Zero damage does not deal 1 damage: remains 100")

	# 20 Slash damage with 30% reduction: ceil(20 * 0.7) = 14
	var slash_dmg := DamageInfo.new(20, Enums.DamageType.SLASH)
	commander.take_damage(slash_dmg)
	assert_true(commander.health.hp == 86, "Slash damage reduced by 30%: 100 -> 86 (took 14)")

	# 10 True damage: ignores reduction
	var true_dmg := DamageInfo.new(10, Enums.DamageType.TRUE)
	commander.take_damage(true_dmg)
	assert_true(commander.health.hp == 76, "True damage ignores reduction: 86 -> 76 (took 10)")

	# Buff expires
	commander._battle_cry_active_timer = 0.0

	# 20 Slash damage without buff: takes full 20
	commander.take_damage(slash_dmg)
	assert_true(commander.health.hp == 56, "Normal damage after buff expired: 76 -> 56 (took 20)")

	commander.free()


func test_aoe_taunt() -> void:
	print("\n[GROUP 4] Testing AoE Taunt Targeting")
	var cmd_scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander: CharacterBody3D = cmd_scene.instantiate()
	add_child(commander)
	commander.global_position = Vector3.ZERO

	var grunt_scene: PackedScene = load("res://entities/enemy/grunt.tscn")
	var archer_scene: PackedScene = load("res://entities/enemy/archer.tscn")
	var brute_scene: PackedScene = load("res://entities/enemy/brute.tscn")

	# Target within 6.0m
	var close_grunt: Enemy = grunt_scene.instantiate()
	add_child(close_grunt)
	close_grunt.global_position = Vector3(3.0, 0.0, 0.0)
	close_grunt.spawn_grace = false
	close_grunt.is_in_spawn_zone = false

	# Target within 6.0m
	var close_archer: Enemy = archer_scene.instantiate()
	add_child(close_archer)
	close_archer.global_position = Vector3(-4.0, 0.0, 0.0)
	close_archer.spawn_grace = false
	close_archer.is_in_spawn_zone = false

	# Target within 6.0m (Brute at 5.5m)
	var close_brute: Enemy = brute_scene.instantiate()
	add_child(close_brute)
	close_brute.global_position = Vector3(0.0, 0.0, 5.5)
	close_brute.spawn_grace = false
	close_brute.is_in_spawn_zone = false

	# Target outside 6.0m (at 8.0m)
	var far_grunt: Enemy = grunt_scene.instantiate()
	add_child(far_grunt)
	far_grunt.global_position = Vector3(8.0, 0.0, 0.0)
	far_grunt.spawn_grace = false
	far_grunt.is_in_spawn_zone = false

	# Target inside spawn zone
	var spawn_grunt: Enemy = grunt_scene.instantiate()
	add_child(spawn_grunt)
	spawn_grunt.global_position = Vector3(2.0, 0.0, 0.0)
	spawn_grunt.spawn_grace = true
	spawn_grunt.is_in_spawn_zone = true

	# Trigger Battle Cry
	commander._start_battle_cry()

	assert_true(close_grunt.provoked_by_player, "Close Grunt (3m) is provoked")
	assert_true(close_grunt.current_target == commander, "Close Grunt targets Commander")
	assert_true(is_equal_approx(close_grunt.provoked_timer, 4.0), "Close Grunt taunt timer is 4.0s")

	assert_true(close_archer.provoked_by_player, "Close Archer (4m) is provoked")
	assert_true(close_archer.current_target == commander, "Close Archer targets Commander")

	assert_true(close_brute.provoked_by_player, "Close Brute (5.5m) is provoked despite aggro_range 4m")
	assert_true(close_brute.current_target == commander, "Close Brute targets Commander")

	assert_true(not far_grunt.provoked_by_player, "Far Grunt (8m) is NOT provoked")
	assert_true(far_grunt.current_target != commander, "Far Grunt does NOT target Commander")

	assert_true(not spawn_grunt.provoked_by_player, "Spawn zone Grunt is NOT provoked")

	commander.free()
	close_grunt.free()
	close_archer.free()
	close_brute.free()
	far_grunt.free()
	spawn_grunt.free()


func test_boss_immunity() -> void:
	print("\n[GROUP 5] Testing Boss Taunt Immunity")
	var cmd_scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander: CharacterBody3D = cmd_scene.instantiate()
	add_child(commander)
	commander.global_position = Vector3.ZERO

	var grunt_scene: PackedScene = load("res://entities/enemy/grunt.tscn")
	var boss_dummy: Enemy = grunt_scene.instantiate()
	add_child(boss_dummy)
	boss_dummy.global_position = Vector3(2.0, 0.0, 0.0)
	boss_dummy.spawn_grace = false
	boss_dummy.is_in_spawn_zone = false
	boss_dummy.add_to_group(&"boss")

	commander._start_battle_cry()

	assert_true(not boss_dummy.provoked_by_player, "Boss node in 6m is immune to taunt")
	assert_true(boss_dummy.current_target != commander, "Boss node does not retarget Commander")

	# Verify null commander does not crash or set target
	boss_dummy.apply_commander_taunt(null, 4.0)
	assert_true(not boss_dummy.provoked_by_player, "Null commander node safely ignored")

	commander.free()
	boss_dummy.free()


func test_leash_distance() -> void:
	print("\n[GROUP 6] Testing Leash Distance")
	var cmd_scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander: CharacterBody3D = cmd_scene.instantiate()
	add_child(commander)
	commander.global_position = Vector3.ZERO

	var grunt_scene: PackedScene = load("res://entities/enemy/grunt.tscn")
	var grunt: Enemy = grunt_scene.instantiate()
	add_child(grunt)
	grunt.global_position = Vector3(2.0, 0.0, 0.0)
	grunt.spawn_grace = false
	grunt.is_in_spawn_zone = false

	grunt.apply_commander_taunt(commander, 4.0)
	assert_true(grunt.provoked_by_player, "Grunt initially provoked")

	# Move commander past 25m leash distance
	commander.global_position = Vector3(30.0, 0.0, 0.0)
	grunt._update_timers(0.1)

	assert_true(not grunt.provoked_by_player, "Grunt provocation cancelled beyond leash distance")

	commander.free()
	grunt.free()


func test_event_bus_cooldown_signal() -> void:
	print("\n[GROUP 7] Testing EventBus Cooldown Signal")
	var cmd_scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander: CharacterBody3D = cmd_scene.instantiate()
	add_child(commander)

	var signal_data := {
		"received": false,
		"skill": &"",
		"remaining": -1.0,
		"total": -1.0
	}

	var cb := func(skill_id: StringName, remaining: float, total: float) -> void:
		if skill_id == &"battle_cry":
			signal_data.received = true
			signal_data.skill = skill_id
			signal_data.remaining = remaining
			signal_data.total = total

	EventBus.skill_cooldown_changed.connect(cb)

	commander._start_battle_cry()

	assert_true(signal_data.received, "skill_cooldown_changed signal emitted for battle_cry")
	assert_true(signal_data.skill == &"battle_cry", "Signal skill_id is battle_cry")
	assert_true(is_equal_approx(signal_data.remaining, 12.0), "Signal remaining cooldown is 12.0")
	assert_true(is_equal_approx(signal_data.total, 12.0), "Signal total cooldown is 12.0")

	EventBus.skill_cooldown_changed.disconnect(cb)
	commander.free()


func test_mode_switch_and_death_cleanup() -> void:
	print("\n[GROUP 8] Testing Mode Switch and Death Cleanup")
	var cmd_scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander: CharacterBody3D = cmd_scene.instantiate()
	add_child(commander)

	commander._start_battle_cry()
	assert_true(commander.is_using_skill, "Skill active before mode switch")
	assert_true(commander._battle_cry_active_timer > 0.0, "Buff active before mode switch")

	# Switch to Commander mode
	commander._on_mode_changed(&"COMMANDER")
	assert_true(not commander.is_using_skill, "Skill state cleanly ended on mode switch")
	assert_true(is_equal_approx(commander._battle_cry_active_timer, 0.0), "Buff reset on mode switch")

	# Switch back to Frontline
	commander._on_mode_changed(&"FRONTLINE")
	commander._start_battle_cry()
	assert_true(commander.is_using_skill, "Skill active before death")

	# Death triggers cleanup
	commander._on_died()
	assert_true(not commander.is_using_skill, "Skill state cleanly ended on death")

	commander.free()


func test_max_aggro_melee_limit() -> void:
	print("\n[GROUP 9] Testing Melee Aggro Capacity (max_aggro_melee = 8)")
	var cmd_scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander: CharacterBody3D = cmd_scene.instantiate()
	add_child(commander)
	commander.global_position = Vector3.ZERO

	var grunt_scene: PackedScene = load("res://entities/enemy/grunt.tscn")
	var archer_scene: PackedScene = load("res://entities/enemy/archer.tscn")

	var melee_enemies: Array[Enemy] = []
	# Spawn 9 melee grunts within 5m
	for i in range(9):
		var angle := (float(i) / 9.0) * TAU
		var grunt: Enemy = grunt_scene.instantiate()
		add_child(grunt)
		grunt.global_position = Vector3(cos(angle) * 3.5, 0.0, sin(angle) * 3.5)
		grunt.spawn_grace = false
		grunt.is_in_spawn_zone = false
		melee_enemies.append(grunt)

	# Spawn 1 ranged archer within 4m
	var archer: Enemy = archer_scene.instantiate()
	add_child(archer)
	archer.global_position = Vector3(2.0, 0.0, 2.0)
	archer.spawn_grace = false
	archer.is_in_spawn_zone = false

	# Execute Battle Cry
	commander._start_battle_cry()

	var chasing_melee_count: int = 0
	var waiting_melee_count: int = 0

	for grunt in melee_enemies:
		assert_true(grunt.provoked_by_player, "All melee grunts are provoked by Battle Cry")
		if grunt.current_state == Enums.EnemyState.CHASE or grunt.current_state == Enums.EnemyState.ATTACK:
			chasing_melee_count += 1
		elif grunt.current_state == Enums.EnemyState.WAIT:
			waiting_melee_count += 1

	assert_true(chasing_melee_count == 8, "Exactly 8 melee grunts are attacking/chasing Commander (got %d)" % chasing_melee_count)
	assert_true(waiting_melee_count == 1, "Surplus 9th melee grunt is standing on outer ring in WAIT state (got %d)" % waiting_melee_count)

	# Ranged archer is not constrained by melee slot
	assert_true(archer.provoked_by_player, "Ranged Archer is provoked")
	assert_true(archer.current_state == Enums.EnemyState.CHASE, "Ranged Archer enters CHASE without taking melee slot")

	commander.free()
	for grunt in melee_enemies:
		grunt.free()
	archer.free()

