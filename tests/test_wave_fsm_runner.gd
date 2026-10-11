extends Node

## Automated test runner verifying:
## - Grunt State Machine (SPAWN, ADVANCE, CHASE, ATTACK, STAGGER, DEAD)
## - AI-01: Melee attack active frame strike, miss on target out of reach
## - AI-04: Knockback interrupts windup, causes STAGGER, grants immunity
## - SPN-01, SPN-02, EN-04: Spawn queue, spawn_zone, spawn_grace, cannot be targeted in spawn_zone
## - Wave FSM: PREP -> COMBAT -> SUMMARY transitions
## - Acceptance Criteria: 1 wave 8 Grunts spawned from queue, ends when queue is empty and enemies_alive == 0

const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const FORTRESS_SCENE: PackedScene = preload("res://entities/fortress/fortress.tscn")

var passes: int = 0
var fails: int = 0

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED GRUNT FSM & WAVE RUNNER TEST          ")
	print("=======================================================")

	test_grunt_initial_spawn_state()
	test_grunt_spawn_grace_and_invulnerability()
	test_grunt_advance_and_targeting()
	test_grunt_attack_and_ai01_active_frame()
	test_grunt_stagger_and_ai04()
	test_wave_fsm_and_8_grunts_flow()

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
		printerr("  [FAIL] %s" % test_name)

func test_grunt_initial_spawn_state() -> void:
	print("\n[GROUP 1] Testing Grunt Initial State & Spawn Grace")
	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt.position = Vector3(15.0, 0.0, 0.0) # Inside spawn_zone (x >= 8.0)
	add_child(grunt)

	assert_true(grunt.current_state == Enums.EnemyState.SPAWN, "Grunt starts in SPAWN state")
	assert_true(grunt.spawn_grace == true, "Grunt has spawn_grace = true on spawn (EN-04)")
	assert_true(grunt.is_in_spawn_zone == true, "Grunt is marked is_in_spawn_zone = true")
	assert_true(grunt.can_be_targeted() == false, "Grunt CANNOT be targeted while in spawn_zone (SPN-02, EN-04)")

	grunt.queue_free()

func test_grunt_spawn_grace_and_invulnerability() -> void:
	print("\n[GROUP 2] Testing Grunt Invulnerability in Spawn Grace")
	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt.position = Vector3(15.0, 0.0, 0.0)
	add_child(grunt)

	var initial_hp := grunt.health.hp
	grunt.take_damage(DamageInfo.new(20, Enums.DamageType.SLASH))
	assert_true(grunt.health.hp == initial_hp, "Grunt does NOT take damage during spawn_grace (invulnerable, EN-04)")

	# Move Grunt outside spawn_zone
	grunt.global_position.x = 7.0
	grunt._physics_process(0.1) # Trigger state update

	assert_true(grunt.spawn_grace == false, "Grunt loses spawn_grace when exiting spawn_zone")
	assert_true(grunt.can_be_targeted() == true, "Grunt CAN be targeted after exiting spawn_zone")
	assert_true(grunt.current_state == Enums.EnemyState.ADVANCE, "Grunt transitions to ADVANCE state upon exiting spawn_zone")

	# Now take damage outside spawn zone
	grunt.take_damage(DamageInfo.new(10, Enums.DamageType.SLASH))
	assert_true(grunt.health.hp == initial_hp - 10, "Grunt takes damage normally after leaving spawn_zone")

	grunt.queue_free()

func test_grunt_advance_and_targeting() -> void:
	print("\n[GROUP 3] Testing Grunt Advance and Target Acquisition")
	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt.position = Vector3(5.0, 0.0, 0.0) # Outside spawn zone
	add_child(grunt)
	grunt.spawn_grace = false
	grunt.is_in_spawn_zone = false
	grunt.change_state(Enums.EnemyState.ADVANCE)

	var fortress := FORTRESS_SCENE.instantiate() as Node3D
	fortress.position = Vector3(0.0, 0.0, 0.0)
	add_child(fortress)

	grunt._find_best_target()
	assert_true(grunt.current_target == fortress, "Grunt acquires Fortress target")

	grunt._physics_process(0.1)
	assert_true(grunt.current_state == Enums.EnemyState.CHASE, "Grunt transitions to CHASE when target is acquired")

	fortress.free()
	grunt.free()

func test_grunt_attack_and_ai01_active_frame() -> void:
	print("\n[GROUP 4] Testing Grunt Melee Attack & AI-01 Active Frame")
	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt.position = Vector3(1.0, 0.0, 0.0)
	add_child(grunt)
	grunt.spawn_grace = false
	grunt.is_in_spawn_zone = false

	var dummy := CharacterBody3D.new()
	dummy.name = "DummyTarget"
	dummy.position = Vector3(0.0, 0.0, 0.0)
	dummy.add_to_group(&"fortress") # Grunt can target it as fortress
	dummy.set_script(preload("res://tests/dummy_target.gd"))
	add_child(dummy)

	var dummy_initial_hp: int = dummy.get("hp")

	grunt.set_target(dummy)
	grunt.velocity = Vector3.ZERO
	grunt.change_state(Enums.EnemyState.ATTACK)

	# During windup (before 0.4s), no damage is dealt yet
	grunt._physics_process(0.2)
	assert_true(dummy.get("hp") == dummy_initial_hp, "No damage dealt during wind-up (AI-01)")

	# Complete windup (total >= 0.4s) -> triggers active frame
	grunt._physics_process(0.25)
	assert_true(dummy.get("hp") < dummy_initial_hp, "Damage dealt at active frame (AI-01)")

	# Test miss when target out of reach at active frame
	dummy.set("hp", dummy_initial_hp)
	grunt.is_attacking_active = false
	grunt.attack_windup_timer = 0.0
	dummy.global_position = Vector3(50.0, 0.0, 0.0) # Move far away

	grunt._physics_process(0.45) # Triggers active strike
	assert_true(dummy.get("hp") == dummy_initial_hp, "Attack misses if target moves out of range before active frame (AI-01)")

	dummy.queue_free()
	grunt.queue_free()

func test_grunt_stagger_and_ai04() -> void:
	print("\n[GROUP 5] Testing Knockback Stagger & AI-04 Interruption")
	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt.position = Vector3(0.0, 0.0, 0.0)
	add_child(grunt)
	grunt.spawn_grace = false
	grunt.is_in_spawn_zone = false

	# Start attack windup
	grunt.change_state(Enums.EnemyState.ATTACK)
	grunt.attack_windup_timer = 0.2

	# Hit with knockback
	var kb_info := DamageInfo.new(5, Enums.DamageType.SLASH, null, 1.5, Vector3.FORWARD)
	grunt.take_damage(kb_info)

	assert_true(grunt.current_state == Enums.EnemyState.STAGGER, "Knockback forces STAGGER state (AI-04)")
	assert_true(grunt.attack_windup_timer == 0.0, "Knockback interrupts wind-up (AI-04)")

	# Wait stagger duration (0.4s)
	grunt._physics_process(0.45)
	assert_true(grunt.knockback_immunity_timer > 0.0, "Gains knockback immunity after stagger (AI-04)")
	assert_true(grunt.current_state != Enums.EnemyState.STAGGER, "Exits STAGGER after stagger timer expires")

	grunt.queue_free()

func test_wave_fsm_and_8_grunts_flow() -> void:
	print("\n[GROUP 6] Testing Wave FSM: 1 Wave 8 Grunts from Queue to Summary")
	var wave_manager := WaveManager.new()
	wave_manager.spawn_interval = 0.05
	wave_manager.default_wave_1_count = 8
	wave_manager.auto_advance_summary = false
	add_child(wave_manager)

	var states_received: Array[StringName] = []
	var on_state_changed := func(new_st: StringName):
		states_received.append(new_st)
	EventBus.state_changed.connect(on_state_changed)

	var waves_started: Array[int] = []
	var on_wave_started := func(w: int):
		waves_started.append(w)
	EventBus.wave_started.connect(on_wave_started)

	var waves_cleared: Array[int] = []
	var on_wave_cleared := func(w: int):
		waves_cleared.append(w)
	EventBus.wave_cleared.connect(on_wave_cleared)

	# 1. Start PREP
	wave_manager.start_prep()
	assert_true(wave_manager.wave_state == Enums.WaveState.PREP, "WaveManager enters PREP state")
	assert_true(states_received.has(&"PREP"), "EventBus emitted state_changed(&'PREP')")

	# 2. Call Early -> Enters COMBAT
	wave_manager.call_early()
	assert_true(wave_manager.wave_state == Enums.WaveState.COMBAT, "WaveManager enters COMBAT on early call")
	assert_true(states_received.has(&"COMBAT"), "EventBus emitted state_changed(&'COMBAT')")
	assert_true(waves_started.has(1), "EventBus emitted wave_started(1)")
	assert_true(wave_manager.spawn_queue.size() == 8, "spawn_queue has exactly 8 Grunts queued")

	# 3. Simulate process frames to spawn all 8 Grunts from queue
	var enemies_spawned: Array[Enemy] = []
	var on_enemy_spawned := func(e: Node):
		if e is Enemy:
			enemies_spawned.append(e)
	EventBus.enemy_spawned.connect(on_enemy_spawned)

	for _step in range(30):
		wave_manager._physics_process(0.1)
		if wave_manager.spawn_queue.is_empty():
			break

	assert_true(wave_manager.spawn_queue.is_empty(), "spawn_queue is now empty after spawning 8 Grunts")
	assert_true(wave_manager.enemies_alive == 8, "enemies_alive == 8 after all spawned")
	assert_true(enemies_spawned.size() == 8, "Exactly 8 Grunts spawned into world")

	# Verify all Grunts in spawn_zone cannot be targeted
	var all_un_targetable := true
	for enemy in enemies_spawned:
		if enemy.can_be_targeted() != false:
			all_un_targetable = false
	assert_true(all_un_targetable, "Enemies in spawn_zone cannot be targeted (can_be_targeted() == false, SPN-02)")

	# 4. Kill all 8 Grunts one by one
	for enemy in enemies_spawned:
		enemy.spawn_grace = false
		enemy.health.take_damage(DamageInfo.new(999, Enums.DamageType.TRUE))

	assert_true(wave_manager.enemies_alive == 0, "enemies_alive is 0 after all 8 Grunts killed")
	assert_true(wave_manager.wave_state == Enums.WaveState.SUMMARY, "Wave transitions to SUMMARY when queue is empty and enemies_alive == 0")
	assert_true(states_received.has(&"SUMMARY"), "EventBus emitted state_changed(&'SUMMARY')")
	assert_true(waves_cleared.has(1), "EventBus emitted wave_cleared(1)")

	# Clean up connections
	EventBus.state_changed.disconnect(on_state_changed)
	EventBus.wave_started.disconnect(on_wave_started)
	EventBus.wave_cleared.disconnect(on_wave_cleared)
	EventBus.enemy_spawned.disconnect(on_enemy_spawned)
	wave_manager.queue_free()
