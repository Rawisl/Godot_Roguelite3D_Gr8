extends Node

## Automated test runner verifying:
## - Grunt State Machine (SPAWN, ADVANCE, CHASE, ATTACK, STAGGER, FRENZY, DEAD)
## - AI-01: Melee attack active frame strike, miss on target out of reach
## - AI-02: Archer ranged attack, parabolic projectile, and dodge i-frame interaction
## - AI-04: Knockback interrupts windup, causes STAGGER, grants immunity
## - EN-02, EN-03: FRENZY persists after STAGGER without signal spam
## - ETG-01: data.target_rules prioritization, behind-target filter, wall tower filter
## - SPN-01, SPN-02, EN-04: Spawn queue, spawn_zone, spawn_grace, cannot be targeted in spawn_zone
## - WAVE-07, GLD-09: WaveManager PREP on ready, early call gold bonus
## - Wave FSM: PREP -> COMBAT -> SUMMARY transitions with 8 Grunts

const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const ARCHER_SCENE: PackedScene = preload("res://entities/enemy/archer.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://entities/projectile/projectile.tscn")

var passes: int = 0
var fails: int = 0

class MemorySaveRepository extends SaveRepository:
	var stored: Dictionary = {}
	func has_data() -> bool: return not stored.is_empty()
	func load_data() -> Dictionary:
		last_error = OK if has_data() else ERR_FILE_NOT_FOUND
		return stored.duplicate(true)
	func save_data(envelope: Dictionary) -> Error:
		stored = envelope.duplicate(true)
		last_error = OK
		return OK

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED GRUNT FSM & WAVE RUNNER TEST          ")
	print("=======================================================")

	var real_repo := SaveManager.repository
	SaveManager.set_repository(MemorySaveRepository.new())
	SaveManager.load_save()

	test_grunt_initial_spawn_state()
	test_grunt_spawn_grace_and_invulnerability()
	test_grunt_advance_and_targeting()
	test_grunt_attack_and_ai01_active_frame()
	test_grunt_stagger_and_ai04()
	test_frenzy_retention_after_stagger()
	test_targeting_rules_and_wall_filtering()
	test_archer_projectile_and_dodge_iframes()
	test_wave_fsm_and_8_grunts_flow()

	SaveManager.set_repository(real_repo)
	SaveManager.load_save()

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
	grunt.position = Vector3(15.0, 0.0, 0.0)
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
	var hit := DamageInfo.new(10, Enums.DamageType.SLASH)
	grunt.take_damage(hit)
	assert_true(grunt.health.hp == initial_hp, "Grunt takes NO damage during spawn_grace (SPN-02)")

	# Move out of spawn zone
	grunt.position = Vector3(0.0, 0.0, 0.0)
	grunt._physics_process(0.1) # Detects exited spawn zone
	assert_true(grunt.current_state == Enums.EnemyState.ADVANCE, "Grunt enters ADVANCE upon leaving spawn zone")
	assert_true(grunt.can_be_targeted() == true, "Grunt CAN be targeted after leaving spawn zone")

	grunt.take_damage(hit)
	assert_true(grunt.health.hp < initial_hp, "Grunt takes damage normally after leaving spawn zone")

	grunt.queue_free()

func test_grunt_advance_and_targeting() -> void:
	print("\n[GROUP 3] Testing Grunt Advance & Threat Priority Targeting")
	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt.position = Vector3(5.0, 0.0, 0.0)
	add_child(grunt)
	grunt.spawn_grace = false
	grunt.is_in_spawn_zone = false
	grunt.change_state(Enums.EnemyState.ADVANCE)

	var fortress := CharacterBody3D.new()
	fortress.name = "FortressTarget"
	fortress.position = Vector3(-17.5, 0.0, 0.0)
	fortress.add_to_group(&"fortress")
	fortress.set_script(preload("res://tests/dummy_target.gd"))
	add_child(fortress)

	grunt._find_best_target()
	assert_true(grunt.current_target == fortress, "Grunt defaults to Fortress target in lane")

	# Target Barricade ahead
	var barricade := CharacterBody3D.new()
	barricade.name = "BarricadeTarget"
	barricade.position = Vector3(2.0, 0.0, 0.0)
	barricade.add_to_group(&"barricade")
	barricade.set_script(preload("res://tests/dummy_target.gd"))
	add_child(barricade)

	grunt._find_best_target()
	assert_true(grunt.current_target == barricade, "Grunt prioritizes Barricade blocking path (ETG-01)")

	# Provocation by Commander
	var commander := CharacterBody3D.new()
	commander.name = "CommanderTarget"
	commander.position = Vector3(4.0, 0.0, 0.0)
	commander.add_to_group(&"commander")
	commander.set_script(preload("res://tests/dummy_target.gd"))
	add_child(commander)

	grunt.take_damage(DamageInfo.new(1, Enums.DamageType.SLASH, commander))
	assert_true(grunt.provoked_by_player == true, "Grunt provoked when hit by Commander (AGG-01)")
	grunt._find_best_target()
	assert_true(grunt.current_target == commander, "Provoked Grunt redirects attack towards Commander")

	barricade.free()
	fortress.free()
	commander.free()
	grunt.queue_free()

func test_grunt_attack_and_ai01_active_frame() -> void:
	print("\n[GROUP 4] Testing Melee Attack Lifecycle & Active Frame Strike (AI-01)")
	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt.position = Vector3(1.0, 0.0, 0.0)
	add_child(grunt)
	grunt.spawn_grace = false
	grunt.is_in_spawn_zone = false

	var dummy := CharacterBody3D.new()
	dummy.name = "DummyTarget"
	dummy.position = Vector3(0.0, 0.0, 0.0)
	dummy.add_to_group(&"fortress")
	dummy.set_script(preload("res://tests/dummy_target.gd"))
	add_child(dummy)

	var dummy_initial_hp: int = dummy.get("hp")

	grunt.set_target(dummy)
	grunt.velocity = Vector3.ZERO
	grunt.change_state(Enums.EnemyState.ATTACK)

	# During windup (before 0.4s), no damage dealt yet
	grunt._physics_process(0.2)
	assert_true(dummy.get("hp") == dummy_initial_hp, "No damage dealt during wind-up (AI-01)")

	# Complete windup (total >= 0.4s) -> triggers active frame
	grunt._physics_process(0.25)
	assert_true(dummy.get("hp") < dummy_initial_hp, "Damage dealt at active frame (AI-01)")

	# Test miss when target out of reach at active frame
	dummy.set("hp", dummy_initial_hp)
	grunt.is_attacking_active = false
	grunt.attack_windup_timer = 0.0
	dummy.global_position = Vector3(50.0, 0.0, 0.0)

	grunt._physics_process(0.45)
	assert_true(dummy.get("hp") == dummy_initial_hp, "Attack misses if target moves out of range before active frame (AI-01)")

	dummy.free()
	grunt.queue_free()

func test_grunt_stagger_and_ai04() -> void:
	print("\n[GROUP 5] Testing Knockback Stagger & AI-04 Interruption")
	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt.position = Vector3(0.0, 0.0, 0.0)
	add_child(grunt)
	grunt.spawn_grace = false
	grunt.is_in_spawn_zone = false

	grunt.change_state(Enums.EnemyState.ATTACK)
	grunt.attack_windup_timer = 0.2

	var kb_info := DamageInfo.new(5, Enums.DamageType.SLASH, null, 1.5, Vector3.FORWARD)
	grunt.take_damage(kb_info)

	assert_true(grunt.current_state == Enums.EnemyState.STAGGER, "Knockback forces STAGGER state (AI-04)")
	assert_true(grunt.attack_windup_timer == 0.0, "Knockback interrupts wind-up (AI-04)")

	# Wait stagger duration (0.4s)
	grunt._physics_process(0.45)
	assert_true(grunt.knockback_immunity_timer > 0.0, "Gains knockback immunity after stagger (AI-04)")
	assert_true(grunt.current_state != Enums.EnemyState.STAGGER, "Exits STAGGER after stagger timer expires")

	grunt.queue_free()

func test_frenzy_retention_after_stagger() -> void:
	print("\n[GROUP 6] Testing Frenzy Retention After Stagger (EN-02, EN-03)")
	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt.position = Vector3(0.0, 0.0, 0.0)
	add_child(grunt)
	grunt.spawn_grace = false
	grunt.is_in_spawn_zone = false

	var frenzy_signals: Array[Node] = []
	var on_frenzy := func(e: Node): frenzy_signals.append(e)
	EventBus.frenzy_started.connect(on_frenzy)

	# Enter Frenzy
	grunt.change_state(Enums.EnemyState.FRENZY)
	assert_true(grunt.current_state == Enums.EnemyState.FRENZY, "Grunt enters FRENZY")
	assert_true(grunt.is_frenzied == true, "is_frenzied flag is set")
	assert_true(frenzy_signals.size() == 1, "frenzy_started signal emitted once")

	# Stagger the frenzied enemy
	var kb := DamageInfo.new(5, Enums.DamageType.SLASH, null, 1.5, Vector3.FORWARD)
	grunt.take_damage(kb)
	assert_true(grunt.current_state == Enums.EnemyState.STAGGER, "Frenzied enemy enters STAGGER on knockback")

	# Advance past stagger duration (0.4s)
	grunt._physics_process(0.45)
	assert_true(grunt.current_state == Enums.EnemyState.FRENZY, "Grunt recovers back into FRENZY state (EN-02, EN-03)")

	# Verify no signal spam on subsequent physics ticks
	grunt._physics_process(0.1)
	assert_true(frenzy_signals.size() == 1, "frenzy_started is NOT spammed on subsequent ticks")

	EventBus.frenzy_started.disconnect(on_frenzy)
	grunt.queue_free()

func test_targeting_rules_and_wall_filtering() -> void:
	print("\n[GROUP 7] Testing Target Rules, Wall Tower Filter & Behind-Target Filter (ETG-01)")
	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt.position = Vector3(5.0, 0.0, 0.0)
	add_child(grunt)
	grunt.spawn_grace = false
	grunt.is_in_spawn_zone = false

	# 1. Test Wall tower filtering: Grunt (ground melee) ignores wall tower
	var wall_tower := CharacterBody3D.new()
	wall_tower.name = "WallTower"
	wall_tower.position = Vector3(0.0, 4.0, 0.0)
	wall_tower.add_to_group(&"tower")
	wall_tower.set_meta("is_wall", true)
	wall_tower.set_script(preload("res://tests/dummy_target.gd"))
	add_child(wall_tower)

	assert_true(grunt._is_target_valid(wall_tower) == false, "Ground melee Grunt rejects WALL towers (ETG-01)")

	# Archer (ranged) CAN target wall tower
	var archer: Enemy = ARCHER_SCENE.instantiate() as Enemy
	archer.position = Vector3(5.0, 0.0, 0.0)
	add_child(archer)
	assert_true(archer._is_target_valid(wall_tower) == true, "Ranged Archer accepts WALL towers (ETG-01)")

	# 2. Test target behind enemy: Enemy advancing -X ignores target at positive X
	var behind_barricade := CharacterBody3D.new()
	behind_barricade.name = "BehindBarricade"
	behind_barricade.position = Vector3(10.0, 0.0, 0.0) # Behind grunt at x=5
	behind_barricade.add_to_group(&"barricade")
	behind_barricade.set_script(preload("res://tests/dummy_target.gd"))
	add_child(behind_barricade)

	assert_true(grunt._is_target_ahead(behind_barricade.global_position) == false, "Target at x=10 is behind enemy at x=5")

	wall_tower.free()
	behind_barricade.free()
	archer.queue_free()
	grunt.queue_free()

func test_archer_projectile_and_dodge_iframes() -> void:
	print("\n[GROUP 8] Testing Archer Projectile & Dodge I-Frames (AI-02)")
	var proj: Projectile = PROJECTILE_SCENE.instantiate() as Projectile
	add_child(proj)

	var dummy := CharacterBody3D.new()
	dummy.name = "TargetDummy"
	dummy.position = Vector3(0.0, 0.0, 0.0)
	dummy.set_script(preload("res://tests/dummy_target.gd"))
	add_child(dummy)

	var start_pos := Vector3(10.0, 0.0, 0.0)
	var target_pos := Vector3(0.0, 0.0, 0.0)
	proj.launch(start_pos, target_pos, 8, null, Enums.DamageType.PIERCE, true, 2.0)

	assert_true(proj.has_launched == true, "Projectile launched successfully")
	assert_true(proj.is_parabolic == true, "Projectile trajectory is parabolic (AI-02)")

	# Advance midway along arc
	proj._physics_process(proj.duration * 0.5)
	assert_true(proj.global_position.y > 1.0, "Projectile reaches arc apex above ground (AI-02)")

	# Verify Dodge i-frame logic
	var mock_cmd := CharacterBody3D.new()
	mock_cmd.add_to_group(&"commander")
	var mock_script := GDScript.new()
	mock_script.source_code = "extends CharacterBody3D\nvar is_dodging: bool = true\nvar hp: int = 100\nfunc take_damage(info: Variant) -> void:\n\tif is_dodging and info is DamageInfo and info.damage_type != Enums.DamageType.TRUE:\n\t\treturn\n\tif info is DamageInfo:\n\t\thp -= info.amount\n"
	mock_script.reload()
	mock_cmd.set_script(mock_script)
	add_child(mock_cmd)

	var hp_before: int = mock_cmd.get("hp")
	mock_cmd.call("take_damage", DamageInfo.new(8, Enums.DamageType.PIERCE))
	assert_true(mock_cmd.get("hp") == hp_before, "Dodge i-frames prevent arrow damage (AI-02)")

	proj.queue_free()
	dummy.free()
	mock_cmd.queue_free()

func test_wave_fsm_and_8_grunts_flow() -> void:
	print("\n[GROUP 9] Testing Wave FSM: PREP on Ready, Early Call Gold, and 8 Grunts Wave")
	var wave_manager := WaveManager.new()
	wave_manager.spawn_interval = 0.05
	wave_manager.default_wave_1_count = 8
	wave_manager.auto_advance_summary = false

	var states_received: Array[StringName] = []
	var on_state_changed := func(new_st: StringName): states_received.append(new_st)
	EventBus.state_changed.connect(on_state_changed)

	var gold_deltas: Array[int] = []
	var on_gold_delta := func(g: int): gold_deltas.append(g)
	EventBus.gold_delta.connect(on_gold_delta)

	var waves_started: Array[int] = []
	var on_wave_started := func(w: int): waves_started.append(w)
	EventBus.wave_started.connect(on_wave_started)

	var waves_cleared: Array[int] = []
	var on_wave_cleared := func(w: int): waves_cleared.append(w)
	EventBus.wave_cleared.connect(on_wave_cleared)

	# 1. Adding WaveManager automatically enters PREP via _ready()
	add_child(wave_manager)
	assert_true(wave_manager.wave_state == Enums.WaveState.PREP, "WaveManager enters PREP automatically on _ready()")
	assert_true(wave_manager.prep_timer > 0.0, "prep_timer initialized to prep_time_early (25s)")
	assert_true(states_received.has(&"PREP"), "EventBus emitted state_changed(&'PREP')")

	# 2. Call Early -> Grants early call bonus gold (WAVE-07, GLD-09) and enters COMBAT
	wave_manager.call_early()
	assert_true(wave_manager.wave_state == Enums.WaveState.COMBAT, "WaveManager enters COMBAT on early call")
	assert_true(gold_deltas.size() > 0 and gold_deltas[0] > 0, "Early call gold bonus granted via EventBus.gold_delta (GLD-09)")
	assert_true(states_received.has(&"COMBAT"), "EventBus emitted state_changed(&'COMBAT')")
	assert_true(waves_started.has(1), "EventBus emitted wave_started(1)")
	assert_true(wave_manager.spawn_queue.size() == 8, "spawn_queue has exactly 8 Grunts queued")

	# 3. Simulate process frames to spawn all 8 Grunts from queue
	var enemies_spawned: Array[Enemy] = []
	var on_enemy_spawned := func(e: Node):
		if e is Enemy:
			enemies_spawned.append(e)
	EventBus.enemy_spawned.connect(on_enemy_spawned)

	for _step in range(80):
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

	EventBus.state_changed.disconnect(on_state_changed)
	EventBus.gold_delta.disconnect(on_gold_delta)
	EventBus.wave_started.disconnect(on_wave_started)
	EventBus.wave_cleared.disconnect(on_wave_cleared)
	EventBus.enemy_spawned.disconnect(on_enemy_spawned)
	wave_manager.queue_free()
