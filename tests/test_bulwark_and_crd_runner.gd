class_name TestBulwarkAndCrdRunner
extends Node3D

const BULWARK_SCENE: PackedScene = preload("res://entities/enemy/bulwark.tscn")
const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const ARCHER_DATA: EnemyData = preload("res://data/enemies/archer.tres")
const GRUNT_DATA: EnemyData = preload("res://data/enemies/grunt.tres")
const BRUTE_DATA: EnemyData = preload("res://data/enemies/brute.tres")
const BULWARK_DATA: BossData = preload("res://data/bosses/bulwark_boss.tres")
const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")

@export var quit_when_done: bool = true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []


func assert_true(condition: bool, message: String) -> void:
	if condition:
		passes += 1
		print("  [PASS] %s" % message)
	else:
		fails += 1
		failed_names.append(message)
		print("  [FAIL] %s" % message)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("\n=======================================================")
	print("       BULWARK FRAMEWORK & CROWD DYNAMICS TESTS        ")
	print("=======================================================")

	test_avoid_radii()
	await test_slot_freed_on_knockback()
	await test_slot_freed_on_target_changed()
	await test_commander_recall_clears_aggro()
	test_bulwark_attributes_and_resistances()
	test_bulwark_fortress_targeting_point()
	await test_bulwark_stomp_telegraph_and_shake()
	test_bulwark_stomp_no_friendly_fire()
	test_bulwark_stomp_commander_interaction()
	test_bulwark_stomp_dodge_evasion()
	test_bulwark_stomp_deploy_immunity()
	await test_wave_5_boss_spawn_and_defeat()
	await test_reward_pick_flow()

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	if fails > 0:
		print("FAILURES:")
		for name in failed_names:
			print(" - %s" % name)
	print("=======================================================\n")

	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)


func test_avoid_radii() -> void:
	print("\n[GROUP 1] Avoid Radii Validation")
	assert_true(GRUNT_DATA.avoid_radius == 0.5, "Grunt avoid_radius is 0.5")
	assert_true(ARCHER_DATA.avoid_radius == 0.5, "Archer avoid_radius is 0.5")
	assert_true(BRUTE_DATA.avoid_radius == 0.9, "Brute avoid_radius is 0.9")
	assert_true(BULWARK_DATA.avoid_radius == 1.6, "Bulwark avoid_radius is 1.6")


func test_slot_freed_on_knockback() -> void:
	print("\n[GROUP 2] Slot Freed on Knockback Exceeding Distance")
	var tower := ARROW_SCENE.instantiate() as Tower
	tower.position = Vector3(0.0, 0.0, 0.0)
	add_child(tower)

	var grunt := GRUNT_SCENE.instantiate() as Enemy
	grunt.position = Vector3(2.0, 0.0, 0.0)
	add_child(grunt)

	var claimed := tower.claim_melee_slot(grunt)
	assert_true(claimed, "Enemy claimed a melee slot on tower")
	assert_true(tower.has_melee_slot(grunt), "Tower records enemy as slot holder")

	var slot_pos := tower.get_melee_slot_position(grunt)
	grunt.global_position = slot_pos + Vector3(GameConfig.crowd_claim_distance + 1.0, 0.0, 0.0)

	tower.melee_slots._audit()
	assert_true(not tower.has_melee_slot(grunt), "Slot freed after enemy knocked beyond claim distance")
	assert_true(tower.get_free_melee_slots() == GameConfig.max_attackers_per_tower, "All tower slots restored to free")

	grunt.free()
	tower.free()


func test_slot_freed_on_target_changed() -> void:
	print("\n[GROUP 3] Slot Freed on Target Changed")
	var tower_a := ARROW_SCENE.instantiate() as Tower
	var tower_b := ARROW_SCENE.instantiate() as Tower
	add_child(tower_a)
	add_child(tower_b)

	var grunt := GRUNT_SCENE.instantiate() as Enemy
	add_child(grunt)
	grunt.current_target = tower_a

	assert_true(tower_a.claim_melee_slot(grunt), "Grunt claimed slot on tower A")
	assert_true(tower_a.has_melee_slot(grunt), "Tower A has grunt slot")

	grunt.current_target = tower_b
	tower_a.melee_slots._audit()
	assert_true(not tower_a.has_melee_slot(grunt), "Slot freed when grunt switched target away from tower A")

	grunt.free()
	tower_a.free()
	tower_b.free()


func test_commander_recall_clears_aggro() -> void:
	print("\n[GROUP 4] Commander Recall Clears Aggro")
	var commander_node := Node3D.new()
	commander_node.add_to_group(&"commander")
	add_child(commander_node)

	var grunt := GRUNT_SCENE.instantiate() as Enemy
	add_child(grunt)
	grunt.provoked_by_player = true
	grunt.current_target = commander_node
	grunt.current_state = Enums.EnemyState.CHASE

	grunt.release_commander_aggro()
	await get_tree().process_frame

	assert_true(not grunt.provoked_by_player, "Provoked flag cleared on recall")
	assert_true(grunt.current_target != commander_node, "Current target cleared from commander")

	grunt.free()
	commander_node.free()


func test_bulwark_attributes_and_resistances() -> void:
	print("\n[GROUP 5] Bulwark Attributes & Resistances")
	var bulwark := BULWARK_SCENE.instantiate() as Bulwark
	add_child(bulwark)

	assert_true(bulwark.is_in_group(&"boss"), "Bulwark joins boss group")
	assert_true(bulwark.stomp_damage == 45, "Bulwark stomp damage is 45")
	assert_true(bulwark.stomp_radius == 3.0, "Bulwark stomp radius is 3.0")
	assert_true(bulwark.stomp_knockback == 3.0, "Bulwark stomp knockback is 3.0")
	assert_true(bulwark.stomp_stun_duration == 0.0, "Bulwark stomp stun duration default is 0.0")
	assert_true(bulwark.data.knockback_immune == true, "Bulwark is knockback immune")

	assert_true(bulwark.get_resist(Enums.DamageType.PIERCE) <= 0.0, "Phase 1 immune to PIERCE")
	assert_true(bulwark.get_resist(Enums.DamageType.MAGIC) <= 0.0, "Phase 1 immune to MAGIC")
	assert_true(bulwark.get_resist(Enums.DamageType.BLAST) == 1.0, "Phase 1 takes full BLAST damage")
	assert_true(bulwark.get_resist(Enums.DamageType.SLASH) == 0.6, "Phase 1 takes 60% SLASH damage")

	bulwark.current_phase = Enums.BossPhase.EXPOSED
	assert_true(bulwark.get_resist(Enums.DamageType.PIERCE) >= 1.0, "Phase 2 takes PIERCE damage")
	assert_true(bulwark.get_resist(Enums.DamageType.MAGIC) >= 1.0, "Phase 2 takes MAGIC damage")

	# Armor & Core HP and phase transition verification
	bulwark.current_phase = Enums.BossPhase.ARMORED
	bulwark.spawn_grace = false
	bulwark._init_boss_stats()
	assert_true(bulwark.current_armor_hp == 1200, "Bulwark starts with 1200 armor HP")
	assert_true(bulwark.current_core_hp == 900, "Bulwark starts with 900 core HP")
	assert_true(bulwark.health.hp == 2100, "Bulwark total HP is 2100")
	assert_true(bulwark.health.hit_by_commander == false, "Bulwark hit_by_commander initially false")

	var hp_before := bulwark.health.hp
	bulwark.take_damage(DamageInfo.new(100, Enums.DamageType.PIERCE))
	assert_true(bulwark.health.hp == hp_before, "Pierce deals zero damage in phase 1")
	assert_true(bulwark.health.hit_by_commander == false, "Bulwark hit_by_commander remains false on zero damage")

	bulwark.take_damage(DamageInfo.new(100, Enums.DamageType.BLAST))
	assert_true(bulwark.current_armor_hp == 1100, "Armor absorbs 100 BLAST damage")
	assert_true(bulwark.health.hit_by_commander == false, "Bulwark hit_by_commander false for non-commander damage")

	var cmd_damage := DamageInfo.new(100, Enums.DamageType.BLAST)
	cmd_damage.hit_by_commander = true
	bulwark.take_damage(cmd_damage)
	assert_true(bulwark.current_armor_hp == 1000, "Armor absorbs commander BLAST damage")
	assert_true(bulwark.health.hit_by_commander == true, "Bulwark hit_by_commander true after commander damage")

	var phase_data := {}
	var on_phase_changed := func(phase: StringName) -> void:
		phase_data["phase"] = phase
	EventBus.boss_phase_changed.connect(on_phase_changed)

	bulwark.take_damage(DamageInfo.new(2000, Enums.DamageType.BLAST))
	assert_true(bulwark.current_armor_hp == 0, "Armor depleted to 0")
	assert_true(bulwark.health.hp == 900, "Overkill discarded; core HP intact at 900")
	assert_true(bulwark.current_phase == Enums.BossPhase.TRANSITION, "Enters TRANSITION phase upon armor break")
	assert_true(phase_data.get("phase") == &"TRANSITION", "boss_phase_changed emitted TRANSITION")
	EventBus.boss_phase_changed.disconnect(on_phase_changed)

	bulwark.free()


func test_bulwark_fortress_targeting_point() -> void:
	print("\n[GROUP 6] Bulwark Fortress Targeting Point")
	var fortress := Node3D.new()
	fortress.add_to_group(&"fortress")
	add_child(fortress)

	var boss_point := Node3D.new()
	boss_point.name = "BossMeleePoint"
	boss_point.position = Vector3(-6.5, 0.0, 0.0)
	boss_point.add_to_group(&"boss_melee_point")
	add_child(boss_point)

	var bulwark := BULWARK_SCENE.instantiate() as Bulwark
	add_child(bulwark)

	var target_pt: Vector3 = bulwark._get_attack_point(fortress)
	assert_true(target_pt.is_equal_approx(boss_point.global_position), "Bulwark routes to dedicated boss melee point")

	bulwark.free()
	boss_point.free()
	fortress.free()


func test_bulwark_stomp_telegraph_and_shake() -> void:
	print("\n[GROUP 7] Bulwark Stomp Telegraph and Screen Shake")
	var bulwark := BULWARK_SCENE.instantiate() as Bulwark
	bulwark.position = Vector3(5.0, 0.0, 0.0)
	add_child(bulwark)

	var telegraph_data := {}
	var on_telegraph := func(shape: StringName, pos: Vector3, radius: float, duration: float):
		telegraph_data["shape"] = shape
		telegraph_data["pos"] = pos
		telegraph_data["radius"] = radius
		telegraph_data["duration"] = duration
	EventBus.telegraph_started.connect(on_telegraph)

	bulwark._play_attack_anim()
	assert_true(telegraph_data.get("shape") == &"stomp", "Telegraph started with stomp shape")
	assert_true(telegraph_data.get("radius") == 3.0, "Telegraph radius is 3.0")
	assert_true(telegraph_data.get("duration") == 1.0, "Telegraph duration matches windup (1.0)")
	EventBus.telegraph_started.disconnect(on_telegraph)

	var shake_data := {}
	var on_shake := func(intensity: float, source: StringName):
		shake_data["intensity"] = intensity
		shake_data["source"] = source
	EventBus.screen_shake_requested.connect(on_shake)

	bulwark.execute_stomp()
	assert_true(shake_data.get("intensity") == 0.6, "Screen shake requested with 0.6 intensity")
	assert_true(shake_data.get("source") == &"stomp", "Screen shake source is stomp")
	EventBus.screen_shake_requested.disconnect(on_shake)

	bulwark.free()


func test_bulwark_stomp_no_friendly_fire() -> void:
	print("\n[GROUP 8] Bulwark Stomp Friendly Fire Check")
	var bulwark := BULWARK_SCENE.instantiate() as Bulwark
	bulwark.position = Vector3(0.0, 0.0, 0.0)
	add_child(bulwark)

	var ally_grunt := GRUNT_SCENE.instantiate() as Enemy
	ally_grunt.position = Vector3(1.0, 0.0, 0.0)
	add_child(ally_grunt)

	var initial_hp: int = ally_grunt.health.hp
	bulwark.execute_stomp()

	assert_true(ally_grunt.health.hp == initial_hp, "Allied enemy takes zero damage from boss stomp")

	ally_grunt.free()
	bulwark.free()


func test_bulwark_stomp_commander_interaction() -> void:
	print("\n[GROUP 9] Bulwark Stomp Commander Hit & Stun")
	var bulwark := BULWARK_SCENE.instantiate() as Bulwark
	bulwark.position = Vector3(0.0, 0.0, 0.0)
	add_child(bulwark)

	var cmd_mock := MockCommander.new()
	cmd_mock.position = Vector3(1.5, 0.0, 0.0)
	add_child(cmd_mock)

	bulwark.execute_stomp()
	assert_true(cmd_mock.damage_taken == 45, "Commander takes 45 BLAST damage")
	assert_true(cmd_mock.knockback_taken == 3.0, "Commander receives 3.0 knockback")
	assert_true(cmd_mock.stun_duration == 0.0, "Commander receives zero stun by default")

	var boss_data := bulwark.data.duplicate() as BossData
	boss_data.stomp_stun_duration = 1.5
	bulwark.data = boss_data
	bulwark.execute_stomp()
	assert_true(cmd_mock.stun_duration == 1.5, "Commander receives 1.5s stun when configured")

	cmd_mock.free()
	bulwark.free()


func test_bulwark_stomp_dodge_evasion() -> void:
	print("\n[GROUP 10] Bulwark Stomp Dodge Evasion")
	var bulwark := BULWARK_SCENE.instantiate() as Bulwark
	bulwark.position = Vector3(0.0, 0.0, 0.0)
	add_child(bulwark)

	var boss_data := bulwark.data.duplicate() as BossData
	boss_data.stomp_stun_duration = 1.5
	bulwark.data = boss_data

	var cmd_mock := MockCommander.new()
	cmd_mock.position = Vector3(1.5, 0.0, 0.0)
	cmd_mock.is_dodging = true
	add_child(cmd_mock)

	bulwark.execute_stomp()
	assert_true(cmd_mock.damage_taken == 0, "Dodging commander takes zero damage")
	assert_true(cmd_mock.knockback_taken == 0.0, "Dodging commander takes zero knockback")
	assert_true(cmd_mock.stun_duration == 0.0, "Dodging commander receives zero stun")

	cmd_mock.free()
	bulwark.free()


func test_bulwark_stomp_deploy_immunity() -> void:
	print("\n[GROUP 11] Bulwark Stomp Deploy Knockback Immunity")
	var bulwark := BULWARK_SCENE.instantiate() as Bulwark
	bulwark.position = Vector3(0.0, 0.0, 0.0)
	add_child(bulwark)

	var cmd_mock := MockCommander.new()
	cmd_mock.position = Vector3(1.5, 0.0, 0.0)
	cmd_mock.is_deploying = true
	add_child(cmd_mock)

	bulwark.execute_stomp()
	assert_true(cmd_mock.damage_taken == 45, "Deploying commander still takes damage")
	assert_true(cmd_mock.knockback_taken == 0.0, "Deploying commander has zero knockback")
	assert_true(cmd_mock.stun_duration == 0.0, "Deploying commander receives zero stun by default")

	var boss_data := bulwark.data.duplicate() as BossData
	boss_data.stomp_stun_duration = 1.5
	bulwark.data = boss_data
	bulwark.execute_stomp()
	assert_true(cmd_mock.stun_duration == 1.5, "Deploying commander still takes stun when configured")

	cmd_mock.free()
	bulwark.free()


func test_wave_5_boss_spawn_and_defeat() -> void:
	print("\n[GROUP 12] Wave 5 Boss Spawn & Defeat")
	var wm := WaveManager.new()
	wm.auto_advance_summary = false
	wm.current_wave = 5
	add_child(wm)

	var record := {"spawned": false, "defeated": false}
	var on_boss_spawned := func(): record["spawned"] = true
	EventBus.boss_spawned.connect(on_boss_spawned)

	wm.start_combat()
	assert_true(wm.wave_state == Enums.WaveState.BOSS_COMBAT, "Wave 5 enters BOSS_COMBAT state")
	assert_true(record["spawned"], "EventBus.boss_spawned emitted on wave 5 start")

	var boss_node := get_tree().get_first_node_in_group(&"boss") as Bulwark
	assert_true(boss_node != null, "Bulwark boss instantiated into tree")

	EventBus.boss_spawned.disconnect(on_boss_spawned)

	var on_boss_defeated := func(): record["defeated"] = true
	EventBus.boss_defeated.connect(on_boss_defeated)

	boss_node.spawn_grace = false
	boss_node.take_damage(DamageInfo.new(999999, Enums.DamageType.TRUE))
	boss_node.take_damage(DamageInfo.new(999999, Enums.DamageType.TRUE))
	assert_true(record["defeated"], "Boss defeat signal emitted on Bulwark death")
	assert_true(wm.get("_boss_defeated_this_wave") == true, "WaveManager records boss defeated this wave")

	EventBus.boss_defeated.disconnect(on_boss_defeated)
	wm.free()


func test_reward_pick_flow() -> void:
	print("\n[GROUP 13] Reward Pick Flow (Contract Alignment with TV3 & TV4)")
	var wm := WaveManager.new()
	wm.enable_reward_pick = true
	wm.auto_advance_summary = false
	wm.current_wave = 1
	add_child(wm)

	var tracker: Node = wm.get("_xp_tracker")
	assert_true(tracker != null, "WaveManager has XpTracker child")

	tracker.set("pending_picks", 2)
	wm.wave_state = Enums.WaveState.SUMMARY

	wm.advance_from_summary()
	assert_true(wm.wave_state == Enums.WaveState.REWARD_PICK, "Advances from SUMMARY to REWARD_PICK when pending_picks > 0")
	assert_true(TimeManager.has_pause_reason(TimeManager.REASON_REWARD_PICK), "Simulation paused under REWARD_PICK reason")

	EventBus.reward_picked.emit(&"vitality", &"STAT", 1)
	assert_true(tracker.get("pending_picks") == 1, "First pick decrements pending_picks to 1")
	assert_true(wm.wave_state == Enums.WaveState.REWARD_PICK, "Remains in REWARD_PICK while pending_picks > 0")

	EventBus.reward_picked.emit(&"whirlwind", &"ACTIVE", 1)
	assert_true(tracker.get("pending_picks") == 0, "Second pick decrements pending_picks to 0")
	assert_true(wm.wave_state == Enums.WaveState.PREP, "Transitions to PREP once all picks consumed")
	assert_true(not TimeManager.has_pause_reason(TimeManager.REASON_REWARD_PICK), "Pause released upon exiting REWARD_PICK")
	assert_true(wm.current_wave == 2, "Wave advanced to 2")

	wm.free()


class MockCommander extends Node3D:
	var is_dodging: bool = false
	var is_deploying: bool = false
	var damage_taken: int = 0
	var knockback_taken: float = 0.0
	var stun_duration: float = 0.0

	func _init() -> void:
		add_to_group(&"commander")

	func take_damage(info: DamageInfo) -> void:
		damage_taken += info.amount
		knockback_taken = info.knockback_force

	func apply_stun(duration: float) -> void:
		stun_duration = duration
