extends Node
## Runner for the Sniper and the Rider:
## - Sniper: ranged, with a range beyond the level 1 Arrow tower, so it shoots from where that
##   tower cannot reach; it stops and shoots like the Archer
## - Rider: melee like the Grunt, with the Grunt's targets, and faster
## - both come from the balance table, wear their own models and the wave manager knows their scenes
## Units run with physics off; the state step is called by hand.

const SNIPER_SCENE: PackedScene = preload("res://entities/enemy/sniper.tscn")
const RIDER_SCENE: PackedScene = preload("res://entities/enemy/rider.tscn")
const GRUNT_DATA: EnemyData = preload("res://data/enemies/grunt.tres")
const ARCHER_DATA: EnemyData = preload("res://data/enemies/archer.tres")
const ARROW_L1: Resource = preload("res://data/towers/arrow_l1.tres")

var passes: int = 0
var fails: int = 0


class Target extends Node3D:
	var health := HealthComponent.new()

	func _init() -> void:
		health.max_hp = 1000
		add_child(health)
		add_to_group(&"commander")


func _ready() -> void:
	print("\n=======================================================")
	print("              SNIPER AND RIDER RUNNER TEST             ")
	print("=======================================================")
	test_data()
	await test_sniper_holds_and_shoots()
	await test_rider_melee()
	await test_wave_manager_scenes()
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
		print("  [FAIL] %s" % test_name)


func test_data() -> void:
	print("\n[GROUP 1] Data")
	var sniper := load("res://data/enemies/sniper.tres") as EnemyData
	var rider := load("res://data/enemies/rider.tres") as EnemyData
	assert_true(sniper != null and sniper.id == &"sniper" and rider != null and rider.id == &"rider", "Both have data")
	var arrow_range := float(ARROW_L1.get(&"attack_range"))
	assert_true(sniper.is_ranged and sniper.attack_range > arrow_range, "Sniper outranges the level 1 Arrow (%.1f > %.1f)" % [sniper.attack_range, arrow_range])
	assert_true(sniper.target_rules == ARCHER_DATA.target_rules, "Sniper picks targets like the Archer")
	assert_true(sniper.damage_type == Enums.DamageType.PIERCE, "Sniper shoots PIERCE")
	assert_true(not rider.is_ranged and is_equal_approx(rider.attack_range, GRUNT_DATA.attack_range), "Rider fights in melee like the Grunt")
	assert_true(rider.target_rules == GRUNT_DATA.target_rules, "Rider picks targets like the Grunt")
	assert_true(rider.move_speed > GRUNT_DATA.move_speed and rider.damage_type == Enums.DamageType.SLASH, "Rider is faster, SLASH")
	assert_true(sniper.traits.is_empty() and rider.traits.is_empty(), "No special trait")


func _unit(scene: PackedScene) -> Enemy:
	var unit := scene.instantiate() as Enemy
	add_child(unit)
	unit.set_physics_process(false)
	unit.spawn_grace = false
	unit.is_in_spawn_zone = false
	return unit


func test_sniper_holds_and_shoots() -> void:
	print("\n[GROUP 2] Sniper stops and shoots")
	var target := Target.new()
	add_child(target)
	var sniper := _unit(SNIPER_SCENE)
	assert_true(sniper is Archer, "Sniper uses the Archer's ranged attack")
	assert_true(sniper.find_child("Bow", true, false) != null, "Sniper wears its own model with the bow")
	assert_true(sniper.anim_player != null and sniper.anim_player.has_animation(sniper.data.anim_attack)
			and sniper.anim_player.has_animation(sniper.data.anim_shoot), "Its model has the aim and shoot clips")
	var arrow_range := float(ARROW_L1.get(&"attack_range"))
	var stand := (arrow_range + sniper.data.attack_range) * 0.5
	sniper.global_position = Vector3(stand, 0.0, 0.0)
	sniper.set_target(target)
	sniper.change_state(Enums.EnemyState.CHASE)
	sniper._update_state(0.016)
	assert_true(sniper.current_state == Enums.EnemyState.ATTACK, "At %.1f m, out of the Arrow's reach, it stops to shoot" % stand)
	var before := _projectiles()
	sniper._execute_attack_action()
	await get_tree().process_frame
	assert_true(_projectiles() > before, "It fires a projectile")
	sniper.global_position = Vector3(sniper.data.attack_range + 2.0, 0.0, 0.0)
	sniper.change_state(Enums.EnemyState.CHASE)
	sniper._update_state(0.016)
	assert_true(sniper.current_state == Enums.EnemyState.CHASE, "Beyond its own range it keeps walking")
	sniper.queue_free()
	target.queue_free()
	await get_tree().process_frame


func _projectiles() -> int:
	var count := 0
	for node in get_tree().root.find_children("*", "Projectile", true, false):
		if node.is_inside_tree():
			count += 1
	return count


func test_rider_melee() -> void:
	print("\n[GROUP 3] Rider fights in melee")
	var target := Target.new()
	add_child(target)
	var rider := _unit(RIDER_SCENE)
	assert_true(rider.find_child("Horse", true, false) != null, "Rider wears its own model on a horse")
	assert_true(rider.anim_player != null and rider.anim_player.has_animation(rider.data.anim_walk)
			and rider.anim_player.has_animation(rider.data.anim_attack), "Its walk clip is the seated one and it has a melee clip")
	rider.global_position = Vector3(5.0, 0.0, 0.0)
	rider.set_target(target)
	rider.change_state(Enums.EnemyState.CHASE)
	rider._update_state(0.016)
	assert_true(rider.current_state == Enums.EnemyState.CHASE, "At 5 m it still closes in")
	rider.global_position = Vector3(1.0, 0.0, 0.0)
	rider._update_state(0.016)
	assert_true(rider.current_state == Enums.EnemyState.ATTACK, "In melee reach it attacks")
	rider.queue_free()
	target.queue_free()
	await get_tree().process_frame


func test_wave_manager_scenes() -> void:
	print("\n[GROUP 4] Spawner")
	var wm := WaveManager.new()
	add_child(wm)
	assert_true(wm.get_enemy_scene(&"sniper") != null and wm.get_enemy_scene(&"sniper").resource_path.ends_with("sniper.tscn"), "The spawner knows the Sniper")
	assert_true(wm.get_enemy_scene(&"rider") != null and wm.get_enemy_scene(&"rider").resource_path.ends_with("rider.tscn"), "The spawner knows the Rider")
	wm.queue_free()
	await get_tree().process_frame
