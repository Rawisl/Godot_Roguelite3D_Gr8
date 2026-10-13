extends Node

var passes: int = 0
var fails: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("    AUTOMATED STUN, KNOCKBACK & UI VERIFICATION RUNNER ")
	print("=======================================================")

	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()

	await test_initial_hp_emit()
	test_brute_knockback_data()
	await test_commander_knockback()
	test_knockback_immunities()

	print("=======================================================")
	print("VERIFICATION SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================")

	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


func test_initial_hp_emit() -> void:
	print("\n[GROUP 1] Testing Initial Commander HP Deferred Emit")
	var scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander: CharacterBody3D = scene.instantiate()
	var result := {
		"emitted": false,
		"hp": -1,
		"max_hp": -1
	}

	var cb := func(hp: int, max_hp: int) -> void:
		result.emitted = true
		result.hp = hp
		result.max_hp = max_hp

	EventBus.commander_hp_changed.connect(cb)
	add_child(commander)

	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(result.emitted, "commander_hp_changed signal emitted deferredly on setup")
	assert_true(result.hp == 100, "Initial received HP is 100")
	assert_true(result.max_hp == 100, "Initial received max HP is 100")

	EventBus.commander_hp_changed.disconnect(cb)
	commander.free()


func test_brute_knockback_data() -> void:
	print("\n[GROUP 2] Testing Brute Knockback Data & Melee Strike")
	var brute_data: EnemyData = load("res://data/enemies/brute.tres")
	assert_true(brute_data != null, "brute.tres loaded successfully")
	if brute_data != null:
		assert_true(is_equal_approx(brute_data.knockback_force, 2.0), "Brute knockback_force == 2.0 m")

	var brute_scene: PackedScene = load("res://entities/enemy/brute.tscn")
	var brute: Enemy = brute_scene.instantiate()
	add_child(brute)
	brute.spawn_grace = false
	brute.is_in_spawn_zone = false

	var cmd_scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander: CharacterBody3D = cmd_scene.instantiate()
	add_child(commander)
	commander.global_position = Vector3(0.0, 0.0, 1.5)

	brute.set_target(commander)

	var damage_res := {"info": null}
	commander.health.damaged.connect(func(_amount: int, info: DamageInfo):
		damage_res.info = info
	)

	# Execute direct strike from brute
	var strike_dir := (commander.global_position - brute.global_position).normalized()
	var strike_info := DamageInfo.new(brute.data.base_damage, brute.data.damage_type, brute, brute.data.knockback_force, strike_dir)
	commander.take_damage(strike_info)

	assert_true(damage_res.info != null, "Commander received damage from Brute strike")
	if damage_res.info != null:
		assert_true(is_equal_approx(damage_res.info.knockback_force, 2.0), "DamageInfo carried knockback_force == 2.0")

	brute.free()
	commander.free()


func test_commander_knockback() -> void:
	print("\n[GROUP 3] Testing Commander Knockback Movement")
	var cmd_scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander: CharacterBody3D = cmd_scene.instantiate()
	add_child(commander)
	commander.global_position = Vector3.ZERO

	var start_pos := commander.global_position
	var hit_dir := Vector3(0.0, 0.0, 1.0)
	var dmg := DamageInfo.new(10, Enums.DamageType.SLASH, null, 2.0, hit_dir)

	commander.take_damage(dmg)

	assert_true(commander._knockback_velocity.length() > 0.0, "Knockback velocity initialized on hit")

	# Wait for physics loop to complete knockback decay
	while not commander._knockback_velocity.is_zero_approx():
		await get_tree().physics_frame

	var displacement := Vector2(commander.global_position.x - start_pos.x, commander.global_position.z - start_pos.z).length()
	assert_true(is_equal_approx(displacement, 2.0) or absf(displacement - 2.0) < 0.2, "Commander displaced horizontally by ~2.0 m (got %.2f m)" % displacement)
	assert_true(commander._knockback_velocity.is_zero_approx(), "Knockback velocity decayed to zero")

	commander.free()


func test_knockback_immunities() -> void:
	print("\n[GROUP 4] Testing Knockback Immunities (Dodge, Deploying, Commander Mode)")
	var cmd_scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander: CharacterBody3D = cmd_scene.instantiate()
	add_child(commander)

	# 1. Dodge immunity
	commander.is_dodging = true
	var dmg := DamageInfo.new(10, Enums.DamageType.SLASH, null, 2.0, Vector3.FORWARD)
	commander.take_damage(dmg)
	assert_true(commander._knockback_velocity.is_zero_approx(), "Knockback ignored during Dodge")
	commander.is_dodging = false

	# 2. Deploying immunity
	commander.is_deploying = true
	commander.take_damage(dmg)
	assert_true(commander._knockback_velocity.is_zero_approx(), "Knockback ignored during Deploying")
	commander.is_deploying = false

	# 3. Commander mode immunity
	commander.is_commander_mode = true
	commander.take_damage(dmg)
	assert_true(commander._knockback_velocity.is_zero_approx(), "Knockback ignored in Commander Mode")
	commander.is_commander_mode = false

	# 4. Normal state accepts knockback
	commander.take_damage(dmg)
	assert_true(commander._knockback_velocity.length() > 0.0, "Knockback applied when not immune")

	commander.free()
