extends Node3D

## Automated Verification Suite for Phase 1 (Data & Assets) & Phase 2 (AI Targeting ETG-01..07)

var passed_count: int = 0
var failed_count: int = 0

func _ready() -> void:
	print("\n=======================================================")
	print("       PHASE 1 & PHASE 2 VERIFICATION RUNNER           ")
	print("=======================================================\n")

	test_group_1_resource_validation()
	test_group_2_scene_and_assets()
	test_group_3_kaykit_facing_direction()
	test_group_4_melee_wall_tower_exclusion()
	test_group_5_grunt_barricade_before_tower()
	test_group_6_archer_priority()
	test_group_7_brute_straight_to_fortress()
	test_group_8_tie_break_rule()

	print("\n=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passed_count, failed_count])
	print("=======================================================\n")

	if failed_count == 0:
		get_tree().quit(0)
	else:
		get_tree().quit(1)

func assert_true(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1
		print("  [PASS] %s" % message)
	else:
		failed_count += 1
		print("  [FAIL] %s" % message)

func assert_eq(val1: Variant, val2: Variant, message: String) -> void:
	if val1 == val2:
		passed_count += 1
		print("  [PASS] %s: %s == %s" % [message, str(val1), str(val2)])
	else:
		failed_count += 1
		print("  [FAIL] %s: expected %s, got %s" % [message, str(val2), str(val1)])

# ==============================================================================
# GROUP 1: Resource Validation
# ==============================================================================
func test_group_1_resource_validation() -> void:
	print("[GROUP 1] Testing EnemyData Resources (SRS 3.7.1, 3.7.3)")

	var grunt_data: EnemyData = load("res://data/enemies/grunt.tres")
	assert_true(grunt_data != null, "grunt.tres loaded")
	if grunt_data:
		assert_eq(grunt_data.base_hp, 40, "Grunt base_hp == 40")
		assert_eq(grunt_data.base_damage, 6, "Grunt base_damage == 6")
		assert_eq(grunt_data.attack_interval, 1.0, "Grunt attack_interval == 1.0")
		assert_eq(grunt_data.attack_range, 1.5, "Grunt attack_range == 1.5")
		assert_eq(grunt_data.move_speed, 3.5, "Grunt move_speed == 3.5")
		assert_eq(grunt_data.damage_type, Enums.DamageType.SLASH, "Grunt damage_type == SLASH")
		assert_eq(grunt_data.is_ranged, false, "Grunt is_ranged == false")
		assert_eq(grunt_data.knockback_immune, false, "Grunt knockback_immune == false")
		assert_eq(grunt_data.aggro_range, 10.0, "Grunt aggro_range == 10.0")

	var archer_data: EnemyData = load("res://data/enemies/archer.tres")
	assert_true(archer_data != null, "archer.tres loaded")
	if archer_data:
		assert_eq(archer_data.base_hp, 30, "Archer base_hp == 30")
		assert_eq(archer_data.base_damage, 8, "Archer base_damage == 8")
		assert_eq(archer_data.attack_interval, 1.5, "Archer attack_interval == 1.5")
		assert_eq(archer_data.attack_range, 11.0, "Archer attack_range == 11.0")
		assert_eq(archer_data.move_speed, 3.0, "Archer move_speed == 3.0")
		assert_eq(archer_data.damage_type, Enums.DamageType.PIERCE, "Archer damage_type == PIERCE")
		assert_eq(archer_data.is_ranged, true, "Archer is_ranged == true")
		assert_eq(archer_data.knockback_immune, false, "Archer knockback_immune == false")
		assert_eq(archer_data.aggro_range, 11.0, "Archer aggro_range == 11.0")
		assert_true(archer_data.target_rules[0] == &"TOWER" or archer_data.target_rules[0] == &"TOWER_GROUND", "Archer prioritizes Tower first")

	var brute_data: EnemyData = load("res://data/enemies/brute.tres")
	assert_true(brute_data != null, "brute.tres loaded")
	if brute_data:
		assert_eq(brute_data.base_hp, 250, "Brute base_hp == 250")
		assert_eq(brute_data.base_damage, 25, "Brute base_damage == 25")
		assert_eq(brute_data.attack_interval, 2.0, "Brute attack_interval == 2.0")
		assert_eq(brute_data.attack_range, 2.0, "Brute attack_range == 2.0")
		assert_eq(brute_data.move_speed, 2.0, "Brute move_speed == 2.0")
		assert_eq(brute_data.damage_type, Enums.DamageType.SLASH, "Brute damage_type == SLASH")
		assert_eq(brute_data.is_ranged, false, "Brute is_ranged == false")
		assert_eq(brute_data.knockback_immune, true, "Brute knockback_immune == true")
		assert_eq(brute_data.aggro_range, 4.0, "Brute aggro_range == 4.0")
		assert_eq(brute_data.avoid_radius, 0.9, "Brute avoid_radius == 0.9")
		assert_eq(brute_data.avoid_priority, 3, "Brute avoid_priority == 3")
		assert_true(brute_data.target_rules.has(&"FORTRESS"), "Brute target_rules contains FORTRESS")
		assert_true(not brute_data.target_rules.has(&"BARRICADE"), "Brute target_rules excludes BARRICADE")

# ==============================================================================
# GROUP 2: Scene & 3D Model Verification
# ==============================================================================
func test_group_2_scene_and_assets() -> void:
	print("\n[GROUP 2] Testing Scene Hierarchies & AnimationPlayers (models_animations.md)")

	var grunt_scene: PackedScene = load("res://entities/enemy/grunt.tscn")
	var grunt := grunt_scene.instantiate() as Enemy
	add_child(grunt)
	var grunt_model := grunt.get_node_or_null("Model/GruntModel")
	assert_true(grunt_model != null, "grunt.tscn contains Model/GruntModel instance")
	var grunt_anim: AnimationPlayer = grunt.find_child("AnimationPlayer", true, false)
	assert_true(grunt_anim != null, "grunt.tscn contains AnimationPlayer")
	if grunt_anim:
		assert_true(grunt_anim.has_animation("move/Running_A"), "Grunt has move/Running_A")
		assert_true(grunt_anim.has_animation("melee/Melee_1H_Attack_Slice_Diagonal"), "Grunt has melee attack clip")
		assert_true(grunt_anim.has_animation("general/Hit_B"), "Grunt has Hit_B clip")
		assert_true(grunt_anim.has_animation("general/Death_B"), "Grunt has Death_B clip")
	grunt.free()

	var archer_scene: PackedScene = load("res://entities/enemy/archer.tscn")
	var archer := archer_scene.instantiate() as Enemy
	add_child(archer)
	var archer_model := archer.get_node_or_null("Model/ArcherModel")
	assert_true(archer_model != null, "archer.tscn contains Model/ArcherModel instance")
	var archer_anim: AnimationPlayer = archer.find_child("AnimationPlayer", true, false)
	assert_true(archer_anim != null, "archer.tscn contains AnimationPlayer")
	if archer_anim:
		assert_true(archer_anim.has_animation("move/Running_A"), "Archer has move/Running_A")
		assert_true(archer_anim.has_animation("ranged/Ranged_2H_Aiming"), "Archer has Ranged_2H_Aiming")
		assert_true(archer_anim.has_animation("ranged/Ranged_2H_Shoot"), "Archer has Ranged_2H_Shoot")
	var muzzle := archer.get_node_or_null("Muzzle")
	assert_true(muzzle != null, "archer.tscn contains Muzzle node for projectile origin")
	archer.free()

	var brute_scene: PackedScene = load("res://entities/enemy/brute.tscn")
	var brute := brute_scene.instantiate() as Enemy
	add_child(brute)
	var brute_model := brute.get_node_or_null("Model/BruteModel")
	assert_true(brute_model != null, "brute.tscn contains Model/BruteModel instance")
	var brute_anim: AnimationPlayer = brute.find_child("AnimationPlayer", true, false)
	assert_true(brute_anim != null, "brute.tscn contains AnimationPlayer")
	if brute_anim:
		assert_true(brute_anim.has_animation("move/Walking_B"), "Brute has move/Walking_B")
		assert_true(brute_anim.has_animation("melee/Melee_1H_Attack_Slice_Horizontal"), "Brute has Melee_1H_Attack_Slice_Horizontal")
	var col_shape := brute.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape and col_shape.shape is CapsuleShape3D:
		var cap := col_shape.shape as CapsuleShape3D
		assert_true(is_equal_approx(cap.radius, 0.6), "Brute capsule radius == 0.6m")
		assert_true(is_equal_approx(cap.height, 2.3), "Brute capsule height == 2.3m")
	brute.free()

# ==============================================================================
# GROUP 3: KayKit Facing Direction (+Z forward)
# ==============================================================================
func test_group_3_kaykit_facing_direction() -> void:
	print("\n[GROUP 3] Testing Model Facing Direction (+Z Convention)")

	var grunt_scene: PackedScene = load("res://entities/enemy/grunt.tscn")
	var grunt := grunt_scene.instantiate() as Enemy
	add_child(grunt)

	# When moving in -X (leftward towards Fortress), yaw converges to atan2(-1, 0) = -PI/2
	for i in 60:
		grunt._move_towards_direction(Vector3(-1.0, 0.0, 0.0))
	var expected_yaw_left := atan2(-1.0, 0.0) # -PI/2
	assert_true(absf(grunt.rotation.y - expected_yaw_left) < 0.05, "Grunt faces -X when moving left: got %f, expected %f" % [grunt.rotation.y, expected_yaw_left])

	# When moving in +X (rightward), yaw converges to atan2(1, 0) = PI/2
	for i in 60:
		grunt._move_towards_direction(Vector3(1.0, 0.0, 0.0))
	var expected_yaw_right := atan2(1.0, 0.0) # PI/2
	assert_true(absf(grunt.rotation.y - expected_yaw_right) < 0.05, "Grunt faces +X when moving right: got %f, expected %f" % [grunt.rotation.y, expected_yaw_right])

	grunt.free()

# ==============================================================================
# GROUP 4: ETG-01 Wall Tower Exclusion for Melee
# ==============================================================================
func test_group_4_melee_wall_tower_exclusion() -> void:
	print("\n[GROUP 4] Testing Melee Cannot Target Wall Tower (ETG-01)")

	var wall_tower := StaticBody3D.new()
	wall_tower.name = "WallTower"
	wall_tower.add_to_group(&"tower")
	wall_tower.add_to_group(&"tower_wall")
	var hc := HealthComponent.new()
	hc.name = "Health"
	hc.max_hp = 100
	hc.hp = 100
	wall_tower.add_child(hc)
	add_child(wall_tower)

	var grunt_scene: PackedScene = load("res://entities/enemy/grunt.tscn")
	var grunt := grunt_scene.instantiate() as Enemy
	add_child(grunt)
	assert_true(not grunt._is_target_valid(wall_tower), "Grunt cannot target wall tower")

	var brute_scene: PackedScene = load("res://entities/enemy/brute.tscn")
	var brute := brute_scene.instantiate() as Enemy
	add_child(brute)
	assert_true(not brute._is_target_valid(wall_tower), "Brute cannot target wall tower")

	var archer_scene: PackedScene = load("res://entities/enemy/archer.tscn")
	var archer := archer_scene.instantiate() as Enemy
	add_child(archer)
	assert_true(archer._is_target_valid(wall_tower), "Archer CAN target wall tower")

	wall_tower.free()
	grunt.free()
	brute.free()
	archer.free()

# ==============================================================================
# GROUP 5: Grunt Priority (Barricade before Tower)
# ==============================================================================
func test_group_5_grunt_barricade_before_tower() -> void:
	print("\n[GROUP 5] Testing Grunt Chooses Barricade Before Ground Tower (SRS 3.7.3)")

	var ground_tower := StaticBody3D.new()
	ground_tower.name = "GroundTower"
	ground_tower.add_to_group(&"tower")
	var hc1 := HealthComponent.new()
	hc1.name = "Health"
	hc1.max_hp = 100
	hc1.hp = 100
	ground_tower.add_child(hc1)
	add_child(ground_tower)
	ground_tower.global_position = Vector3(5.0, 0.0, 0.0)

	var barricade := StaticBody3D.new()
	barricade.name = "Barricade"
	barricade.add_to_group(&"tower")
	barricade.add_to_group(&"barricade")
	var hc2 := HealthComponent.new()
	hc2.name = "Health"
	hc2.max_hp = 300
	hc2.hp = 300
	barricade.add_child(hc2)
	add_child(barricade)
	barricade.global_position = Vector3(8.0, 0.0, 0.0)

	var grunt_scene: PackedScene = load("res://entities/enemy/grunt.tscn")
	var grunt := grunt_scene.instantiate() as Enemy
	add_child(grunt)
	grunt.global_position = Vector3(12.0, 0.0, 0.0)

	# Force node cache update
	Enemy._last_cache_frame = -1
	grunt._find_best_target()
	assert_eq(grunt.current_target, barricade, "Grunt prioritizes Barricade even if Tower is closer")

	ground_tower.free()
	barricade.free()
	grunt.free()

# ==============================================================================
# GROUP 6: Archer Priority (Tower -> Player -> Barricade -> Fortress)
# ==============================================================================
func test_group_6_archer_priority() -> void:
	print("\n[GROUP 6] Testing Archer Targeting Hierarchy (Tower > Player > Barricade > Fortress)")

	var fortress := StaticBody3D.new()
	fortress.name = "Fortress"
	fortress.add_to_group(&"fortress")
	var hcf := HealthComponent.new()
	hcf.name = "Health"
	hcf.max_hp = 1000
	hcf.hp = 1000
	fortress.add_child(hcf)
	add_child(fortress)
	fortress.global_position = Vector3(0.0, 0.0, 0.0)

	var barricade := StaticBody3D.new()
	barricade.name = "Barricade"
	barricade.add_to_group(&"barricade")
	var hcb := HealthComponent.new()
	hcb.name = "Health"
	hcb.max_hp = 300
	hcb.hp = 300
	barricade.add_child(hcb)
	add_child(barricade)
	barricade.global_position = Vector3(5.0, 0.0, 0.0)

	var player := CharacterBody3D.new()
	player.name = "Commander"
	player.add_to_group(&"commander")
	var hcp := HealthComponent.new()
	hcp.name = "Health"
	hcp.max_hp = 100
	hcp.hp = 100
	player.add_child(hcp)
	add_child(player)
	player.global_position = Vector3(7.0, 0.0, 0.0)

	var ground_tower := StaticBody3D.new()
	ground_tower.name = "GroundTower"
	ground_tower.add_to_group(&"tower")
	var hct := HealthComponent.new()
	hct.name = "Health"
	hct.max_hp = 150
	hct.hp = 150
	ground_tower.add_child(hct)
	add_child(ground_tower)
	ground_tower.global_position = Vector3(8.0, 0.0, 0.0)

	var archer_scene: PackedScene = load("res://entities/enemy/archer.tscn")
	var archer := archer_scene.instantiate() as Enemy
	add_child(archer)
	archer.global_position = Vector3(12.0, 0.0, 0.0)

	# 1. With all present, Archer selects Tower
	Enemy._last_cache_frame = -1
	archer._find_best_target()
	assert_eq(archer.current_target, ground_tower, "Archer selects Tower over Player, Barricade, and Fortress")

	# 2. When Tower removed, Archer selects Player
	ground_tower.free()
	Enemy._last_cache_frame = -1
	archer._find_best_target()
	assert_eq(archer.current_target, player, "Archer selects Player when Tower is absent")

	# 3. When Player removed, Archer selects Barricade
	player.free()
	Enemy._last_cache_frame = -1
	archer._find_best_target()
	assert_eq(archer.current_target, barricade, "Archer selects Barricade when Tower and Player are absent")

	# 4. When Barricade removed, Archer selects Fortress
	barricade.free()
	Enemy._last_cache_frame = -1
	archer._find_best_target()
	assert_eq(archer.current_target, fortress, "Archer selects Fortress when only Fortress remains")

	fortress.free()
	archer.free()

# ==============================================================================
# GROUP 7: Brute Straight to Fortress
# ==============================================================================
func test_group_7_brute_straight_to_fortress() -> void:
	print("\n[GROUP 7] Testing Brute Ignores Barricade and Walks Straight to Fortress")

	var fortress := StaticBody3D.new()
	fortress.name = "Fortress"
	fortress.add_to_group(&"fortress")
	var hcf := HealthComponent.new()
	hcf.name = "Health"
	hcf.max_hp = 1000
	hcf.hp = 1000
	fortress.add_child(hcf)
	add_child(fortress)
	fortress.global_position = Vector3(0.0, 0.0, 0.0)

	var barricade := StaticBody3D.new()
	barricade.name = "Barricade"
	barricade.add_to_group(&"barricade")
	var hcb := HealthComponent.new()
	hcb.name = "Health"
	hcb.max_hp = 300
	hcb.hp = 300
	barricade.add_child(hcb)
	add_child(barricade)
	barricade.global_position = Vector3(5.0, 0.0, 0.0)

	var player := CharacterBody3D.new()
	player.name = "Commander"
	player.add_to_group(&"commander")
	var hcp := HealthComponent.new()
	hcp.name = "Health"
	hcp.max_hp = 100
	hcp.hp = 100
	player.add_child(hcp)
	add_child(player)
	player.global_position = Vector3(10.0, 0.0, 0.0) # 6m away from Brute at 16m

	var brute_scene: PackedScene = load("res://entities/enemy/brute.tscn")
	var brute := brute_scene.instantiate() as Enemy
	add_child(brute)
	brute.global_position = Vector3(16.0, 0.0, 0.0)

	# 1. Default state: Brute ignores Barricade and targets Fortress
	Enemy._last_cache_frame = -1
	brute._find_best_target()
	assert_eq(brute.current_target, fortress, "Brute defaults to Fortress, ignoring Barricade")

	# 2. Provocation beyond 4m aggro range is ignored by Brute (dist = 6m)
	brute.provoked_by_player = true
	brute.provoked_timer = 4.0
	Enemy._last_cache_frame = -1
	brute._find_best_target()
	assert_eq(brute.current_target, fortress, "Brute ignores provocation from Player beyond 4m (6m > 4m)")

	# 3. Provocation within 4m aggro range forces Brute to target Player (move Player to 14m, dist = 2m)
	player.global_position = Vector3(14.0, 0.0, 0.0)
	Enemy._last_cache_frame = -1
	brute._find_best_target()
	assert_eq(brute.current_target, player, "Brute targets Player when provoked within 4m (2m <= 4m)")

	fortress.free()
	barricade.free()
	player.free()
	brute.free()

# ==============================================================================
# GROUP 8: Tie-Break Rule (ETG-07)
# ==============================================================================
func test_group_8_tie_break_rule() -> void:
	print("\n[GROUP 8] Testing Deterministic Tie-Break (ETG-07)")

	var tower_a := StaticBody3D.new()
	tower_a.name = "TowerA"
	tower_a.add_to_group(&"tower")
	var hca := HealthComponent.new()
	hca.name = "Health"
	hca.max_hp = 100
	hca.hp = 100
	tower_a.add_child(hca)
	add_child(tower_a)
	tower_a.global_position = Vector3(5.0, 0.0, 0.0)

	var tower_b := StaticBody3D.new()
	tower_b.name = "TowerB"
	tower_b.add_to_group(&"tower")
	var hcb := HealthComponent.new()
	hcb.name = "Health"
	hcb.max_hp = 100
	hcb.hp = 100
	tower_b.add_child(hcb)
	add_child(tower_b)
	tower_b.global_position = Vector3(5.0, 0.0, 0.0) # Exactly same distance

	var expected_winner: Node3D = tower_a if tower_a.get_instance_id() < tower_b.get_instance_id() else tower_b

	var archer_scene: PackedScene = load("res://entities/enemy/archer.tscn")
	var archer := archer_scene.instantiate() as Enemy
	add_child(archer)
	archer.global_position = Vector3(10.0, 0.0, 0.0)

	Enemy._last_cache_frame = -1
	archer._find_best_target()
	assert_eq(archer.current_target, expected_winner, "Equal distance tie-break deterministically selects smaller instance_id")

	tower_a.free()
	tower_b.free()
	archer.free()
