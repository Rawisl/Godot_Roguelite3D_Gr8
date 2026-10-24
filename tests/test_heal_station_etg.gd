extends Node

## Automated test runner for Heal Station ETG integration:
## - Heal Station as a ground tower
## - Targeting priority: Grunt (Barricade > Heal Station > Fortress), Archer (Tower), Bulwark (Heal Station), Brute (Fortress)
## - Melee slot capacity: exactly 3 melee units can claim slots simultaneously
## - 4th melee unit is throttled into WAIT state
## - Slot release on unit death and automatic handoff to waiting unit
## - DummyHealStation includes temporary 3D mesh and collision shape

const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const ARCHER_SCENE: PackedScene = preload("res://entities/enemy/archer.tscn")
const BRUTE_SCENE: PackedScene = preload("res://entities/enemy/brute.tscn")
const BULWARK_SCENE: PackedScene = preload("res://entities/enemy/bulwark.tscn")
const DUMMY_STATION_SCRIPT: Script = preload("res://tests/dummy_heal_station.gd")

var passes: int = 0
var fails: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED HEAL STATION ETG TEST RUNNER          ")
	print("=======================================================")

	test_dummy_station_attributes()
	test_targeting_priority_grunt()
	test_targeting_archer_brute_and_bulwark()
	test_melee_slot_limit_max_3_attackers()
	test_melee_slot_release_and_handoff()

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


func _create_dummy_station(pos: Vector3 = Vector3.ZERO) -> Node3D:
	var station: Node3D = DUMMY_STATION_SCRIPT.new()
	station.name = "DummyHealStation"
	station.position = pos
	add_child(station)
	return station


func _create_fortress(pos: Vector3 = Vector3.ZERO) -> Node3D:
	var fort := Node3D.new()
	fort.name = "Fortress"
	fort.add_to_group(&"fortress")
	fort.position = pos
	var health := HealthComponent.new()
	health.name = "Health"
	health.max_hp = 1000
	health.hp = 1000
	fort.add_child(health)
	add_child(fort)
	return fort


func _create_barricade(pos: Vector3 = Vector3.ZERO) -> Node3D:
	var bar := Node3D.new()
	bar.name = "Barricade"
	bar.add_to_group(&"barricade")
	bar.position = pos
	var health := HealthComponent.new()
	health.name = "Health"
	health.max_hp = 300
	health.hp = 300
	bar.add_child(health)
	add_child(bar)
	return bar


func test_dummy_station_attributes() -> void:
	print("\n[GROUP 1] Testing DummyHealStation Attributes & Groups")
	var station := _create_dummy_station(Vector3.ZERO)

	assert_true(station.is_in_group(&"tower"), "Station is in group &'tower'")
	assert_true(station.is_in_group(&"heal_station"), "Station is in group &'heal_station'")
	assert_true(station.health != null, "Station has HealthComponent")
	assert_true(station.health.max_hp == 300, "Station base HP == 300")
	assert_true(station.health.hp == 300, "Station initial HP == 300")
	assert_true(station.get_free_melee_slots() == GameConfig.max_attackers_per_tower, "Station has 3 free melee slots")
	assert_true(station.get_node_or_null("CollisionShape3D") != null, "Station has CollisionShape3D")
	assert_true(station.get_node_or_null("TempMesh") != null, "Station has TempMesh")

	station.free()


func test_targeting_priority_grunt() -> void:
	print("\n[GROUP 2] Testing Grunt Targeting Priority (Barricade > Heal Station > Fortress)")
	Enemy.invalidate_node_cache()
	var fort := _create_fortress(Vector3(-15.0, 0.0, 0.0))
	var station := _create_dummy_station(Vector3(0.0, 0.0, 0.0))
	var bar := _create_barricade(Vector3(5.0, 0.0, 0.0))

	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt.position = Vector3(10.0, 0.0, 0.0)
	grunt.spawn_grace = false
	grunt.is_in_spawn_zone = false
	add_child(grunt)

	# 1. Barricade exists ahead -> Grunt prioritizes Barricade
	grunt._find_best_target()
	assert_true(grunt.current_target == bar, "Grunt prioritizes Barricade ahead over ground tower and Fortress")

	# 2. Barricade destroyed -> Grunt prioritizes Heal Station (ground tower)
	bar.free()
	Enemy.invalidate_node_cache()
	grunt._find_best_target()
	assert_true(grunt.current_target == station, "Grunt prioritizes ground tower over Fortress")

	# 3. Heal Station destroyed -> Grunt defaults to Fortress
	station.free()
	Enemy.invalidate_node_cache()
	grunt._find_best_target()
	assert_true(grunt.current_target == fort, "Grunt defaults to Fortress when no Barricade or ground tower exists")

	fort.free()
	grunt.free()


func test_targeting_archer_brute_and_bulwark() -> void:
	print("\n[GROUP 3] Testing Archer, Brute, and Bulwark Targeting of Heal Station")
	Enemy.invalidate_node_cache()
	var fort := _create_fortress(Vector3(-15.0, 0.0, 0.0))
	var station := _create_dummy_station(Vector3(0.0, 0.0, 0.0))

	# Archer targeting: Archer targets Tower
	var archer: Enemy = ARCHER_SCENE.instantiate() as Enemy
	archer.position = Vector3(6.0, 0.0, 0.0)
	archer.spawn_grace = false
	archer.is_in_spawn_zone = false
	add_child(archer)

	archer._find_best_target()
	assert_true(archer.current_target == station, "Archer targets Heal Station as a tower")
	assert_true(not archer._uses_melee_slot(station), "Archer does not consume melee attack slot")

	# Brute targeting: Brute marches to Fortress, does NOT target towers
	var brute: Enemy = BRUTE_SCENE.instantiate() as Enemy
	brute.position = Vector3(8.0, 0.0, 0.0)
	brute.spawn_grace = false
	brute.is_in_spawn_zone = false
	add_child(brute)

	brute._find_best_target()
	assert_true(brute.current_target == fort, "Brute prioritizes Fortress and ignores Heal Station")

	# Bulwark targeting: Bulwark targets ground tower in front
	var bulwark: Bulwark = BULWARK_SCENE.instantiate() as Bulwark
	bulwark.position = Vector3(4.0, 0.0, 0.0)
	bulwark.spawn_grace = false
	bulwark.is_in_spawn_zone = false
	add_child(bulwark)

	bulwark._find_best_target()
	assert_true(bulwark.current_target == station, "Bulwark targets Heal Station as ground tower in front")

	fort.free()
	station.free()
	archer.free()
	brute.free()
	bulwark.free()


func test_melee_slot_limit_max_3_attackers() -> void:
	print("\n[GROUP 4] Testing Melee Slot Limit (Max 3 Attackers per Tower, 4th waits)")
	var station := _create_dummy_station(Vector3(0.0, 0.0, 0.0))

	# Create 3 melee units
	var m1: Enemy = GRUNT_SCENE.instantiate() as Enemy
	var m2: Enemy = GRUNT_SCENE.instantiate() as Enemy
	var m3: Enemy = GRUNT_SCENE.instantiate() as Enemy
	for u in [m1, m2, m3]:
		u.spawn_grace = false
		u.is_in_spawn_zone = false
		u.position = Vector3(2.0, 0.0, 0.0)
		add_child(u)

	# All 3 claim slots
	assert_true(station.claim_melee_slot(m1), "Unit 1 successfully claimed melee slot 1")
	assert_true(station.claim_melee_slot(m2), "Unit 2 successfully claimed melee slot 2")
	assert_true(station.claim_melee_slot(m3), "Unit 3 successfully claimed melee slot 3")
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
	assert_true(not station.claim_melee_slot(m4), "Unit 4 cannot claim slot because station is full")
	assert_true(not m4._try_hold_melee_slot(station), "m4._try_hold_melee_slot() returns false when slots are full")

	# Process physics tick to let CHASE state handle full slots
	m4._physics_process(0.016)
	assert_true(m4.current_state == Enums.EnemyState.WAIT, "Unit 4 transitions to WAIT state when all 3 slots are occupied")

	# Cleanup
	m1.free()
	m2.free()
	m3.free()
	m4.free()
	station.free()


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

	# Waiting unit 4 automatically detects freed slot and claims it
	m4._physics_process(0.016)
	assert_true(station.has_melee_slot(m4), "Waiting unit 4 automatically claims newly freed slot")
	assert_true(m4.current_state == Enums.EnemyState.CHASE, "Unit 4 transitions from WAIT back to CHASE")
	assert_true(station.get_free_melee_slots() == 0, "Slots are full again (0 free)")

	m1.free()
	m2.free()
	m3.free()
	m4.free()
	station.free()
