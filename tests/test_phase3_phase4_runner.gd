extends Node3D

## Automated Verification Suite for Phase 3 (Archer Ranged & AI-02) & Phase 4 (STAGGER AI-04, AI-03, AI-05)

var passed_count: int = 0
var failed_count: int = 0

func _ready() -> void:
	print("\n=======================================================")
	print("       PHASE 3 & PHASE 4 VERIFICATION RUNNER           ")
	print("=======================================================\n")

	test_group_1_archer_hold_distance_and_no_kiting()
	test_group_2_archer_projectile_parabolic_specs()
	test_group_3_barricade_bypass_for_parabolic_arrows()
	test_group_4_dodge_evades_arrow()
	test_group_5_stagger_interrupts_windup_and_grants_immunity()
	test_group_6_brute_knockback_immune()
	test_group_7_no_friendly_fire()
	test_group_8_no_stun_on_enemies()
	test_group_9_projectile_deals_damage_when_source_freed_mid_flight()

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
# GROUP 1: Archer Hold Distance & No Kiting (AI-02, SRS 3.7.3, EN-11)
# ==============================================================================
func test_group_1_archer_hold_distance_and_no_kiting() -> void:
	print("[GROUP 1] Testing Archer Hold Distance (11m) & No Kiting (EN-11)")

	var target_dummy := StaticBody3D.new()
	target_dummy.name = "TargetDummy"
	target_dummy.add_to_group(&"tower")
	var hc := HealthComponent.new()
	hc.name = "Health"
	hc.max_hp = 100
	hc.hp = 100
	target_dummy.add_child(hc)
	add_child(target_dummy)
	target_dummy.global_position = Vector3(0.0, 0.0, 0.0)

	var archer_scene: PackedScene = load("res://entities/enemy/archer.tscn")
	var archer := archer_scene.instantiate() as Archer
	add_child(archer)
	archer.spawn_grace = false
	archer.is_in_spawn_zone = false
	archer.change_state(Enums.EnemyState.CHASE)

	# Position archer at 10.5m (within 11.0m attack range)
	archer.global_position = Vector3(10.5, 0.0, 0.0)
	archer.set_target(target_dummy)

	# 1. When in range <= 11m, Archer enters ATTACK and stops velocity
	archer._update_state(0.016)
	assert_eq(archer.current_state, Enums.EnemyState.ATTACK, "Archer enters ATTACK when target is within 11.0m")
	assert_eq(archer.velocity.x, 0.0, "Archer stops horizontal velocity in ATTACK (holds distance)")

	# 2. EN-11: Target moves very close (< 2m), Archer continues ATTACK without kiting
	target_dummy.global_position = Vector3(9.0, 0.0, 0.0) # 1.5m away
	archer._update_state(0.016)
	assert_eq(archer.current_state, Enums.EnemyState.ATTACK, "Archer stays in ATTACK when target is < 2m (no kiting)")

	# 3. Target moves beyond attack_range + 0.3m (12m away)
	target_dummy.global_position = Vector3(-2.0, 0.0, 0.0) # 12.5m away
	archer.is_attacking_active = true
	archer.attack_recovery_timer = 0.0
	archer._update_state(0.016)
	assert_eq(archer.current_state, Enums.EnemyState.CHASE, "Archer returns to CHASE when target moves beyond 11.3m")

	target_dummy.free()
	archer.free()

# ==============================================================================
# GROUP 2: Archer Projectile Specifications (AI-02)
# ==============================================================================
func test_group_2_archer_projectile_parabolic_specs() -> void:
	print("\n[GROUP 2] Testing Archer Projectile Specs (AI-02: 20 m/s, Parabolic, PIERCE)")

	var proj_scene: PackedScene = load("res://entities/projectile/enemy_projectile.tscn")
	var proj := proj_scene.instantiate() as Projectile
	add_child(proj)

	var start_pt := Vector3(10.0, 1.2, 0.0)
	var end_pt := Vector3(0.0, 0.9, 0.0)
	proj.launch(start_pt, end_pt, 8, null, Enums.DamageType.PIERCE, true, 2.5)

	assert_eq(proj.speed, 20.0, "Projectile speed == 20 m/s")
	assert_eq(proj.damage_type, Enums.DamageType.PIERCE, "Projectile damage_type == PIERCE")
	assert_true(proj.is_parabolic, "Projectile is_parabolic == true")
	assert_eq(proj.arc_height, 2.5, "Projectile arc_height == 2.5m")

	# Check mid-air parabolic trajectory height: at t = 0.5, height should exceed linear height
	proj._physics_process(proj.duration * 0.5)
	var linear_mid_y := lerpf(start_pt.y, end_pt.y, 0.5)
	assert_true(proj.global_position.y > linear_mid_y + 2.0, "Projectile arcs overhead above linear path at midpoint")

	proj.free()

# ==============================================================================
# GROUP 3: Barricade Bypass for Parabolic Arrows (AI-02)
# ==============================================================================
func test_group_3_barricade_bypass_for_parabolic_arrows() -> void:
	print("\n[GROUP 3] Testing Arrow Bypasses Intervening Barricade (AI-02: không bị Barricade chắn)")

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

	var barricade_scene: PackedScene = load("res://entities/tower/barricade.tscn")
	var barricade := barricade_scene.instantiate() as Tower
	add_child(barricade)
	barricade.global_position = Vector3(5.0, 0.0, 0.0)

	var proj_scene: PackedScene = load("res://entities/projectile/enemy_projectile.tscn")
	var proj := proj_scene.instantiate() as Projectile
	add_child(proj)
	# Launch from 10m towards Fortress at 0m, passing through Barricade at 5m
	proj.launch(Vector3(10.0, 1.2, 0.0), fortress.global_position, 8, null, Enums.DamageType.PIERCE, true, 2.5, fortress)

	# Simulate collision with Barricade
	proj._apply_hit(barricade)
	assert_eq(barricade.health.hp, 300, "Intervening Barricade takes 0 damage when arrow is aimed at Fortress behind it")
	assert_true(is_instance_valid(proj) and not proj.is_queued_for_deletion(), "Arrow is NOT destroyed by intervening Barricade")

	# Now test arrow directly targeting Barricade
	var direct_proj := proj_scene.instantiate() as Projectile
	add_child(direct_proj)
	direct_proj.launch(Vector3(10.0, 1.2, 0.0), barricade.global_position, 8, null, Enums.DamageType.PIERCE, true, 2.5, barricade)
	direct_proj._apply_hit(barricade)
	assert_eq(barricade.health.hp, 292, "Barricade takes 8 damage when arrow is explicitly aimed at it")

	proj.free()
	fortress.free()
	barricade.free()

# ==============================================================================
# GROUP 4: Dodge Evades Arrow (AI-02, CMB-06)
# ==============================================================================
func test_group_4_dodge_evades_arrow() -> void:
	print("\n[GROUP 4] Testing Dodge Evades Arrow (AI-02 & CMB-06: Dodge i-frame)")

	var commander_scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander := commander_scene.instantiate() as CharacterBody3D
	add_child(commander)
	commander.global_position = Vector3(0.0, 0.0, 0.0)
	var initial_hp: int = int(commander.health.hp)

	var proj_scene: PackedScene = load("res://entities/projectile/enemy_projectile.tscn")

	# Case A: Commander not dodging -> takes damage
	var proj_hit := proj_scene.instantiate() as Projectile
	add_child(proj_hit)
	proj_hit.launch(Vector3(5.0, 1.2, 0.0), commander.global_position, 8, null, Enums.DamageType.PIERCE, true, 2.5, commander)
	proj_hit._apply_hit(commander)
	assert_true(int(commander.health.hp) < initial_hp, "Commander takes damage when NOT dodging: %d < %d" % [commander.health.hp, initial_hp])

	# Case B: Commander is dodging -> 0 damage (i-frame)
	commander.is_dodging = true
	var hp_before_dodge_shot: int = int(commander.health.hp)
	var proj_dodge := proj_scene.instantiate() as Projectile
	add_child(proj_dodge)
	proj_dodge.launch(Vector3(5.0, 1.2, 0.0), commander.global_position, 8, null, Enums.DamageType.PIERCE, true, 2.5, commander)
	proj_dodge._apply_hit(commander)
	assert_eq(int(commander.health.hp), hp_before_dodge_shot, "Commander takes 0 damage when DODGING (AI-02 Dodge né được)")

	# Case C: Commander walks 2m sideways before impact -> arrow lands and does not damage Commander (AI-02 no homing)
	commander.is_dodging = false
	var hp_before_move_shot: int = int(commander.health.hp)
	var proj_move := proj_scene.instantiate() as Projectile
	add_child(proj_move)
	proj_move.launch(Vector3(5.0, 1.2, 0.0), Vector3(0.0, 0.0, 0.0), 8, null, Enums.DamageType.PIERCE, true, 2.5, commander)
	commander.global_position = Vector3(0.0, 0.0, 2.0)
	proj_move.global_position = Vector3(0.0, 0.0, 0.0)
	proj_move._on_impact_at_target()
	assert_eq(int(commander.health.hp), hp_before_move_shot, "Commander takes 0 damage when walking 2m sideways away from landing spot (AI-02)")

	commander.free()

# ==============================================================================
# GROUP 5: STAGGER Interrupts Wind-up & Applies 2s Immunity (AI-04)
# ==============================================================================
func test_group_5_stagger_interrupts_windup_and_grants_immunity() -> void:
	print("\n[GROUP 5] Testing STAGGER (AI-04: Ngắt wind-up, miễn knockback 2s)")

	var grunt_scene: PackedScene = load("res://entities/enemy/grunt.tscn")
	var grunt := grunt_scene.instantiate() as Enemy
	add_child(grunt)
	grunt.spawn_grace = false
	grunt.is_in_spawn_zone = false

	# Put Grunt in ATTACK with active windup
	grunt.change_state(Enums.EnemyState.ATTACK)
	grunt.attack_windup_timer = 0.2
	assert_eq(grunt.current_state, Enums.EnemyState.ATTACK, "Grunt begins in ATTACK state")

	# 1. Knockback hit interrupts wind-up and triggers STAGGER
	var kb_info := DamageInfo.new(10, Enums.DamageType.SLASH, null, 1.5, Vector3.BACK)
	grunt.take_damage(kb_info)
	assert_eq(grunt.current_state, Enums.EnemyState.STAGGER, "Grunt enters STAGGER on knockback hit")
	assert_eq(grunt.attack_windup_timer, 0.0, "Wind-up timer reset on stagger")
	assert_eq(grunt.stagger_timer, GameConfig.enemy_stagger_time, "stagger_timer initialized to 0.4s")

	# 2. Complete stagger duration (0.4s) -> sets knockback_immunity_timer to 2.0s
	grunt._update_state(GameConfig.enemy_stagger_time)
	assert_eq(grunt.knockback_immunity_timer, GameConfig.enemy_knockback_immunity_time, "knockback_immunity_timer set to 2.0s upon exiting STAGGER")
	assert_true(grunt.current_state != Enums.EnemyState.STAGGER, "Grunt exits STAGGER")

	# 3. Second knockback hit during 2s immunity does NOT stagger
	var state_before := grunt.current_state
	grunt.take_damage(kb_info)
	assert_eq(grunt.current_state, state_before, "Grunt ignores knockback during 2.0s immunity window")

	grunt.free()

# ==============================================================================
# GROUP 6: Brute is Knockback Immune (AI-04, AI-05, SRS 3.7.1)
# ==============================================================================
func test_group_6_brute_knockback_immune() -> void:
	print("\n[GROUP 6] Testing Brute Knockback & Stun Immunity (SRS 3.7.1)")

	var brute_scene: PackedScene = load("res://entities/enemy/brute.tscn")
	var brute := brute_scene.instantiate() as Enemy
	add_child(brute)
	brute.spawn_grace = false
	brute.is_in_spawn_zone = false

	brute.change_state(Enums.EnemyState.ATTACK)
	brute.attack_windup_timer = 0.3

	# Apply heavy knockback hit to Brute
	var heavy_kb := DamageInfo.new(30, Enums.DamageType.SLASH, null, 2.5, Vector3.BACK)
	brute.take_damage(heavy_kb)

	assert_eq(brute.current_state, Enums.EnemyState.ATTACK, "Brute remains in ATTACK state (immune to knockback/stagger)")
	assert_eq(brute.attack_windup_timer, 0.3, "Brute wind-up is NOT interrupted by knockback")

	brute.free()

# ==============================================================================
# GROUP 7: No Friendly Fire (AI-03)
# ==============================================================================
func test_group_7_no_friendly_fire() -> void:
	print("\n[GROUP 7] Testing No Friendly Fire Between Enemies (AI-03)")

	var archer_scene: PackedScene = load("res://entities/enemy/archer.tscn")
	var archer := archer_scene.instantiate() as Archer
	add_child(archer)

	var grunt_scene: PackedScene = load("res://entities/enemy/grunt.tscn")
	var grunt := grunt_scene.instantiate() as Enemy
	add_child(grunt)
	var grunt_initial_hp: int = int(grunt.health.hp)

	var proj_scene: PackedScene = load("res://entities/projectile/enemy_projectile.tscn")
	var proj := proj_scene.instantiate() as Projectile
	add_child(proj)
	proj.launch(archer.global_position, Vector3(-10, 0, 0), 8, archer, Enums.DamageType.PIERCE, true, 2.5)

	# Simulate collision with friendly grunt
	proj._apply_hit(grunt)
	assert_eq(int(grunt.health.hp), grunt_initial_hp, "Grunt takes 0 damage from friendly Archer arrow")

	archer.free()
	grunt.free()
	if is_instance_valid(proj) and not proj.is_queued_for_deletion():
		proj.free()

# ==============================================================================
# GROUP 8: No Stun On Enemies (AI-05)
# ==============================================================================
func test_group_8_no_stun_on_enemies() -> void:
	print("\n[GROUP 8] Testing No Stun State On Enemies (AI-05)")

	var grunt_scene: PackedScene = load("res://entities/enemy/grunt.tscn")
	var grunt := grunt_scene.instantiate() as Enemy
	add_child(grunt)

	# Verify EnemyState enum has no STUN state
	assert_true(not Enums.EnemyState.has("STUN"), "Enums.EnemyState has no STUN state (AI-05: không có khống chế lên kẻ địch ở MVP)")
	assert_true(Enums.EnemyState.has("STAGGER"), "Enums.EnemyState contains STAGGER for interruption")

	grunt.free()

# ==============================================================================
# GROUP 9: Projectile Deals Damage When Source Is Freed Mid-Flight
# ==============================================================================
func test_group_9_projectile_deals_damage_when_source_freed_mid_flight() -> void:
	print("\n[GROUP 9] Testing Projectile Hit When Source Freed Mid-Flight")

	# Case A: Tower shoots arrow, then tower is destroyed mid-flight -> arrow deals full damage to enemy
	var grunt_scene: PackedScene = load("res://entities/enemy/grunt.tscn")
	var grunt := grunt_scene.instantiate() as Enemy
	add_child(grunt)
	grunt.spawn_grace = false
	grunt.is_in_spawn_zone = false
	var grunt_initial_hp := int(grunt.health.hp)

	var tower_scene: PackedScene = load("res://entities/tower/arrow.tscn")
	var tower := tower_scene.instantiate() as Node3D
	add_child(tower)

	var arrow_scene: PackedScene = load("res://entities/projectile/arrow_projectile.tscn")
	var arrow := arrow_scene.instantiate() as ArrowProjectile
	add_child(arrow)
	arrow.in_use = true
	arrow.fire(tower.global_position, grunt, 10, Enums.DamageType.PIERCE, 30.0, tower)

	# Destroy the tower while arrow is mid-flight
	tower.free()

	# Arrow hits grunt
	arrow._hit(grunt)
	assert_eq(int(grunt.health.hp), grunt_initial_hp - 10, "Grunt takes 10 damage from arrow even after tower is freed mid-flight")
	assert_true(is_instance_valid(grunt) and not grunt.is_dead, "Grunt is valid and alive after taking damage")

	grunt.free()
	if is_instance_valid(arrow) and not arrow.is_queued_for_deletion():
		arrow.free()

	# Case B: Archer shoots arrow at Commander, then Archer dies mid-flight -> arrow deals full damage to Commander
	var commander_scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander := commander_scene.instantiate() as CharacterBody3D
	add_child(commander)
	var cmd_hp_before := int(commander.health.hp)

	var archer_scene: PackedScene = load("res://entities/enemy/archer.tscn")
	var archer := archer_scene.instantiate() as Archer
	add_child(archer)
	archer.global_position = Vector3(10.0, 0.0, 0.0)

	var enemy_proj_scene: PackedScene = load("res://entities/projectile/enemy_projectile.tscn")
	var enemy_proj := enemy_proj_scene.instantiate() as Projectile
	add_child(enemy_proj)
	enemy_proj.launch(archer.global_position, commander.global_position, 8, archer, Enums.DamageType.PIERCE, true, 2.5, commander)

	# Destroy archer mid-flight
	archer.free()

	# Arrow hits commander
	enemy_proj._apply_hit(commander)
	assert_eq(int(commander.health.hp), cmd_hp_before - 8, "Commander takes 8 damage from arrow even after Archer is freed mid-flight")

	commander.free()
	if is_instance_valid(enemy_proj) and not enemy_proj.is_queued_for_deletion():
		enemy_proj.free()
