extends Node

## Automated test runner for W6-KT5:
## - Heal Station as TOWER_GROUND (HLT-10, EN-01)
## - ETG targeting priority: Grunt (Barricade > Heal Station > Fortress), Archer (Tower), Brute (Heal Station > Fortress)
## - Melee slot capacity: exactly 3 melee units can claim slots simultaneously (GameConfig.max_attackers_per_tower)
## - 4th melee unit is throttled into WAIT state
## - Slot release on unit death and handoff to waiting unit

const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const ARCHER_SCENE: PackedScene = preload("res://entities/enemy/archer.tscn")
const BRUTE_SCENE: PackedScene = preload("res://entities/enemy/brute.tscn")
const DUMMY_TARGET_SCRIPT: Script = preload("res://tests/dummy_target.gd")
const DUMMY_STATION_SCRIPT: Script = preload("res://tests/dummy_heal_station.gd")

var passes: int = 0
var fails: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED W6-KT5 HEAL STATION ETG TEST RUNNER   ")
	print("=======================================================")

	test_hlt10_dummy_station_attributes()
	test_etg_targeting_priority_grunt()
	test_etg_targeting_archer_and_brute()
	test_melee_slot_limit_max_3_attackers()
	test_melee_slot_release_and_handoff()

	print("=======================================================")
	print("W6-KT5 TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")

	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


func _create_dummy_station(pos: Vector3 = Vector3.ZERO) -> Node3D:
	var station: Node3D = DUMMY_STATION_SCRIPT.new()
	station.name = "DummyHealStation"
	station.position = pos
	add_child(station)
	return station


func _create_fortress(pos: Vector3 = Vector3(-15.0, 0.0, 0.0)) -> CharacterBody3D:
	var fort := CharacterBody3D.new()
	fort.name = "FortressTarget"
	fort.position = pos
	fort.add_to_group(&"fortress")
	fort.set_script(DUMMY_TARGET_SCRIPT)
	add_child(fort)
	return fort


func _create_barricade(pos: Vector3 = Vector3(2.0, 0.0, 0.0)) -> CharacterBody3D:
	var bar := CharacterBody3D.new()
	bar.name = "BarricadeTarget"
	bar.position = pos
	bar.add_to_group(&"barricade")
	bar.set_script(DUMMY_TARGET_SCRIPT)
	add_child(bar)
	return bar


func test_hlt10_dummy_station_attributes() -> void:
	print("\n[GROUP 1] Testing HLT-10 DummyHealStation Attributes & Groups")
	var station := _create_dummy_station()

	assert_true(station.is_in_group(&"tower"), "Station is in group &'tower'")
	assert_true(station.is_in_group(&"tower_ground"), "Station is in group &'tower_ground' (HLT-10)")
	assert_true(station.is_in_group(&"heal_station"), "Station is in group &'heal_station'")
	assert_true(station.health != null, "Station has HealthComponent")
	assert_true(station.health.max_hp == 300, "Station base HP == 300 (HLT-07)")
	assert_true(station.health.hp == 300, "Station initial HP == 300")
	assert_true(station.get_free_melee_slots() == GameConfig.max_attackers_per_tower, "Station has 3 free melee slots (GameConfig.max_attackers_per_tower)")

	station.queue_free()


func test_etg_targeting_priority_grunt() -> void:
	print("\n[GROUP 2] Testing Grunt ETG Priority (Barricade > Heal Station > Fortress)")
	var fort := _create_fortress(Vector3(-15.0, 0.0, 0.0))
	var station := _create_dummy_station(Vector3(-2.0, 0.0, 0.0))
	var bar := _create_barricade(Vector3(3.0, 0.0, 0.0))

	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt.position = Vector3(8.0, 0.0, 0.0)
	grunt.spawn_grace = false
	grunt.is_in_spawn_zone = false
	add_child(grunt)

	# 1. With Barricade present ahead: Grunt targets Barricade first (priority 2)
	grunt._find_best_target()
	assert_true(grunt.current_target == bar, "Grunt prioritizes Barricade ahead over Heal Station and Fortress (ETG-01)")

	# 2. When Barricade is destroyed/removed: Grunt targets Heal Station (priority 3 TOWER_GROUND over Fortress)
	bar.free()
	grunt.set_target(null)
	grunt._find_best_target()
	assert_true(grunt.current_target == station, "Grunt prioritizes Heal Station (TOWER_GROUND) over Fortress (HLT-10)")

	# 3. When Heal Station is destroyed/removed: Grunt defaults to Fortress (priority 4)
	station.free()
	grunt.set_target(null)
	grunt._find_best_target()
	assert_true(grunt.current_target == fort, "Grunt defaults to Fortress when no Barricade or Ground Tower exists")

	fort.free()
	grunt.queue_free()


func test_etg_targeting_archer_and_brute() -> void:
	print("\n[GROUP 3] Testing Archer & Brute Targeting of Heal Station")
	Enemy.invalidate_node_cache()
	var fort := _create_fortress(Vector3(-15.0, 0.0, 0.0))
	var station := _create_dummy_station(Vector3(0.0, 0.0, 0.0))

	# Archer targeting
	var archer: Enemy = ARCHER_SCENE.instantiate() as Enemy
	archer.position = Vector3(6.0, 0.0, 0.0)
	archer.spawn_grace = false
	archer.is_in_spawn_zone = false
	add_child(archer)

	archer._find_best_target()
	assert_true(archer.current_target == station, "Archer targets Heal Station as TOWER / TOWER_GROUND")
	assert_true(not archer._uses_melee_slot(station), "Archer does NOT consume melee attack slot (CRD-06)")

	# Brute targeting
	var brute: Enemy = BRUTE_SCENE.instantiate() as Enemy
	brute.position = Vector3(8.0, 0.0, 0.0)
	brute.spawn_grace = false
	brute.is_in_spawn_zone = false
	add_child(brute)

	brute._find_best_target()
	assert_true(brute.current_target == station, "Brute targets Heal Station according to ETG target_rules")
	assert_true(brute._uses_melee_slot(station), "Brute uses melee attack slot")

	fort.queue_free()
	station.queue_free()
	archer.queue_free()
	brute.queue_free()


func test_melee_slot_limit_max_3_attackers() -> void:
	print("\n[GROUP 4] Testing Melee Slot Limit (Max 3 Attackers per Tower, 4th waits)")
	var station := _create_dummy_station(Vector3(0.0, 0.0, 0.0))

	# Create 3 melee units
	var m1: Enemy = GRUNT_SCENE.instantiate() as Enemy
	var m2: Enemy = GRUNT_SCENE.instantiate() as Enemy
	var m3: Enemy = BRUTE_SCENE.instantiate() as Enemy
	for u in [m1, m2, m3]:
		u.spawn_grace = false
		u.is_in_spawn_zone = false
		u.position = Vector3(2.0, 0.0, 0.0)
		add_child(u)

	# All 3 claim slots
	assert_true(station.claim_melee_slot(m1), "Unit 1 successfully claimed melee slot 1")
	assert_true(station.claim_melee_slot(m2), "Unit 2 successfully claimed melee slot 2")
	assert_true(station.claim_melee_slot(m3), "Unit 3 (Brute) successfully claimed melee slot 3")
	assert_true(station.get_free_melee_slots() == 0, "All 3 melee slots on Heal Station are now full")

	# Create 4th melee unit
	var m4: Enemy = GRUNT_SCENE.instantiate() as Enemy
	m4.spawn_grace = false
	m4.is_in_spawn_zone = false
	m4.position = Vector3(2.0, 0.0, 0.0)
	add_child(m4)
	m4.set_target(station)
	m4.change_state(Enums.EnemyState.CHASE)

	# 4th unit tries to claim slot
	assert_true(not station.claim_melee_slot(m4), "Unit 4 CANNOT claim slot because station is full (max 3, HLT-10)")
	assert_true(not m4._try_hold_melee_slot(station), "m4._try_hold_melee_slot() returns false when slots are full")

	# Process physics tick to let CHASE state handle full slots
	m4._physics_process(0.016)
	assert_true(m4.current_state == Enums.EnemyState.WAIT, "Unit 4 transitions to WAIT state when all 3 slots are occupied")

	# Cleanup
	m1.queue_free()
	m2.queue_free()
	m3.queue_free()
	m4.queue_free()
	station.queue_free()


func test_melee_slot_release_and_handoff() -> void:
	print("\n[GROUP 5] Testing Melee Slot Release on Death & Handoff to Waiting Unit")
	var station := _create_dummy_station(Vector3(0.0, 0.0, 0.0))

	var m1: Enemy = GRUNT_SCENE.instantiate() as Enemy
	var m2: Enemy = GRUNT_SCENE.instantiate() as Enemy
	var m3: Enemy = GRUNT_SCENE.instantiate() as Enemy
	var m4: Enemy = GRUNT_SCENE.instantiate() as Enemy

	for u in [m1, m2, m3, m4]:
		u.spawn_grace = false
		u.is_in_spawn_zone = false
		u.position = Vector3(2.0, 0.0, 0.0)
		add_child(u)
		u.set_target(station)

	station.claim_melee_slot(m1)
	station.claim_melee_slot(m2)
	station.claim_melee_slot(m3)

	m4.change_state(Enums.EnemyState.WAIT)
	assert_true(station.get_free_melee_slots() == 0, "Slots are initially full (0 free)")

	# Kill unit 1
	m1._on_died()
	assert_true(station.get_free_melee_slots() == 1, "Slot released upon unit 1 death (1 free slot)")

	# Now unit 4 can claim the freed slot
	assert_true(station.claim_melee_slot(m4), "Waiting unit 4 successfully claims newly freed slot")
	assert_true(station.has_melee_slot(m4), "station.has_melee_slot(unit 4) is true")
	assert_true(station.get_free_melee_slots() == 0, "Slots are full again (0 free)")

	m1.queue_free()
	m2.queue_free()
	m3.queue_free()
	m4.queue_free()
	station.queue_free()
