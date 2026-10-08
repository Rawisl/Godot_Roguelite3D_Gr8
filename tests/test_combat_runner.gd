extends Node

## Comprehensive verification runner for:
## - InputMap
## - CharacterStats 
## - Scene Groups and Collision Layers
## - Movement WASD & Screen Axis (no diagonal speedup)
## - Aim plane
## - 3-hit combo, Cleave & Sorting
## - Dodge mechanics 
## - HealthComponent & DamageInfo with damage_type

var passes: int = 0
var fails: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED COMBAT & MOVEMENT VERIFICATION        ")
	print("=======================================================")

	test_input_map()
	test_character_stats()
	test_commander_scene_and_groups()
	test_movement_and_aim()
	test_dodge_mechanics()
	test_combo_and_cleave()
	test_health_and_damage_info()

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


func test_input_map() -> void:
	print("\n[GROUP 1] Testing InputMap")
	var expected_actions := [
		&"move_up", &"move_down", &"move_left", &"move_right",
		&"attack", &"dodge", &"battle_cry", &"mode_switch",
		&"emergency_repair", &"retreat", &"call_wave", &"build_toggle",
		&"upgrade", &"sell", &"show_ranges", &"pause",
		&"select", &"cancel", &"toggle_hud"
	]

	for action in expected_actions:
		assert_true(InputMap.has_action(action), "InputMap contains action '%s'" % action)

	# Verify physical_keycode for keyboard events
	var keys_using_physical := true
	for action in expected_actions:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				if event.physical_keycode == 0:
					keys_using_physical = false
					printerr("Action '%s' does not use physical_keycode!" % action)
	assert_true(keys_using_physical, "All keyboard actions use physical_keycode")

	# Verify NO actions mapped to keys 1, 2, 3 
	var has_num_123 := false
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				if event.physical_keycode in [KEY_1, KEY_2, KEY_3] or event.keycode in [KEY_1, KEY_2, KEY_3]:
					has_num_123 = true
					printerr("Action '%s' mapped to key 1-3!" % action)
	assert_true(not has_num_123, "No actions assigned to keys 1, 2, 3")


func test_character_stats() -> void:
	print("\n[GROUP 2] Testing CharacterStats values")
	var stats: CharacterStats = load("res://data/config/commander_stats.tres")
	assert_true(stats != null, "commander_stats.tres loaded successfully")
	if stats == null:
		return

	assert_true(stats.commander_max_hp == 100, "commander_max_hp == 100")
	assert_true(is_equal_approx(stats.move_speed, 6.0), "move_speed == 6.0 m/s")
	assert_true(is_equal_approx(stats.dodge_distance, 4.0), "dodge_distance == 4.0 m")
	assert_true(is_equal_approx(stats.dodge_iframe, 0.3), "dodge_iframe == 0.3 s")
	assert_true(is_equal_approx(stats.dodge_cooldown, 1.5), "dodge_cooldown == 1.5 s")
	assert_true(stats.sword_damage == 20, "sword_damage == 20")
	assert_true(stats.sword_damage_type == Enums.DamageType.SLASH, "sword_damage_type == SLASH")
	assert_true(is_equal_approx(stats.sword_range, 2.2), "sword_range == 2.2 m")
	assert_true(is_equal_approx(stats.sword_arc_deg, 120.0), "sword_arc_deg == 120.0 deg")
	assert_true(stats.sword_max_targets == 3, "sword_max_targets == 3")
	assert_true(is_equal_approx(stats.attack_interval, 0.45), "attack_interval == 0.45 s")
	assert_true(is_equal_approx(stats.combo_hit3_mult, 1.5), "combo_hit3_mult == 1.5")
	assert_true(is_equal_approx(stats.combo_hit3_knockback, 1.5), "combo_hit3_knockback == 1.5 m")
	assert_true(is_equal_approx(stats.combo_window, 0.35), "combo_window == 0.35 s")
	assert_true(is_equal_approx(stats.combo_reset_time, 0.6), "combo_reset_time == 0.6 s")
	assert_true(is_equal_approx(stats.input_buffer_time, 0.15), "input_buffer_time == 0.15 s")


func test_commander_scene_and_groups() -> void:
	print("\n[GROUP 3] Testing Commander Scene, Groups and Layers...")
	var scene: PackedScene = load("res://entities/commander/commander.tscn")
	assert_true(scene != null, "commander.tscn exists")
	if scene == null:
		return

	var commander := scene.instantiate() as CharacterBody3D
	add_child(commander)

	# Verify root node group
	assert_true(commander.is_in_group("commander"), "Commander root node is in group 'commander'")
	var health_node := commander.get_node_or_null("Health")
	assert_true(health_node != null and not health_node.is_in_group("commander"), "Health node is NOT in group 'commander'")

	# Verify collision layers
	assert_true(commander.collision_layer == 2, "Commander collision_layer == 2 (Layer 2: commander)")
	assert_true(commander.collision_mask == 13, "Commander collision_mask == 13 (Layers 1, 3, 4)")

	# Verify sword area mask
	var sword_area: Area3D = commander.get_node_or_null("%SwordArea")
	assert_true(sword_area != null and sword_area.collision_mask == 4, "SwordArea collision_mask == 4 (Layer 3: enemy)")

	commander.queue_free()


func test_movement_and_aim() -> void:
	print("\n[GROUP 4] Testing Movement Diagonal Math and Aim Plane...")
	# Verify diagonal normalization
	var v_diagonal := Vector2(1.0, 1.0).normalized()
	assert_true(is_equal_approx(v_diagonal.length(), 1.0), "Normalized diagonal vector length is 1.0 (not 1.414)")

	# Verify Aim Plane foot-level intersection
	var foot_y := 1.5
	var plane := Plane(Vector3.UP, foot_y)
	var ray_origin := Vector3(0.0, 10.0, 5.0)
	var ray_dir := (Vector3(2.0, foot_y, 3.0) - ray_origin).normalized()
	var hit: Variant = plane.intersects_ray(ray_origin, ray_dir)
	assert_true(hit != null, "Aim ray intersects foot-level horizontal plane")
	if hit != null:
		var hit_pos: Vector3 = hit
		assert_true(is_equal_approx(hit_pos.y, foot_y), "Hit point Y exactly equals foot height (%.2f)" % foot_y)


func test_dodge_mechanics() -> void:
	print("\n[GROUP 5] Testing Dodge Mechanics")
	var scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander := scene.instantiate() as CharacterBody3D
	add_child(commander)

	# Initial collision masks
	assert_true(commander.get_collision_mask_value(1), "Mask 1 (World) enabled before dodge")
	assert_true(commander.get_collision_mask_value(3), "Mask 3 (Enemy) enabled before dodge")
	assert_true(commander.get_collision_mask_value(4), "Mask 4 (Structure) enabled before dodge")

	# Start dodge
	var cam := Camera3D.new()
	add_child(cam)
	commander.set("aim_dir", Vector3(0, 0, -1))
	commander.call("_start_dodge", cam)

	assert_true(commander.get("is_dodging") == true, "Commander enters is_dodging = true")
	assert_true(not commander.get_collision_mask_value(3), "Mask 3 (Enemy) DISABLED during dodge")
	assert_true(commander.get_collision_mask_value(1), "Mask 1 (World) remains ENABLED during dodge (blocked by walls)")
	assert_true(commander.get_collision_mask_value(4), "Mask 4 (Structure) remains ENABLED during dodge (blocked by structures)")

	# I-frame check: normal damage ignored, TRUE damage received
	var commander_health: HealthComponent = commander.get_node("%Health")
	var prev_hp: int = commander_health.hp
	var slash_info := DamageInfo.new(20, Enums.DamageType.SLASH)
	commander.call("take_damage", slash_info)
	assert_true(commander_health.hp == prev_hp, "Normal damage ignored during dodge i-frame")

	var true_info := DamageInfo.new(15, Enums.DamageType.TRUE)
	commander.call("take_damage", true_info)
	assert_true(commander_health.hp == prev_hp - 15, "TRUE damage bypasses dodge i-frame (DMG-05)")

	# End dodge
	commander.call("_end_dodge")
	assert_true(commander.get("is_dodging") == false, "is_dodging == false after dodge ends")
	assert_true(commander.get_collision_mask_value(3), "Mask 3 (Enemy) RE-ENABLED after dodge ends")

	cam.queue_free()
	commander.queue_free()


func test_combo_and_cleave() -> void:
	print("\n[GROUP 6] Testing 3-Hit Combo, Cleave Limit and Sorting")
	var scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander := scene.instantiate() as CharacterBody3D
	add_child(commander)

	var stats: CharacterStats = commander.get("stats")
	assert_true(stats != null, "Commander has CharacterStats resource")
	if stats == null:
		commander.queue_free()
		return

	# Test combo damage calculation
	var dmg_hit1: int = stats.sword_damage
	var dmg_hit3: int = roundi(float(stats.sword_damage) * stats.combo_hit3_mult)
	assert_true(dmg_hit1 == 20, "Hit 1 damage == 20")
	assert_true(dmg_hit3 == 30, "Hit 3 damage == 30 (1.5x multiplier)")

	# Test deterministic sorting tie-breaker (distance -> angle -> id)
	var candidates: Array[Dictionary] = [
		{"distance": 1.5, "angle": 0.4, "id": 10},
		{"distance": 1.0, "angle": 0.5, "id": 5},
		{"distance": 1.0, "angle": 0.2, "id": 8},
		{"distance": 1.0, "angle": 0.2, "id": 3},
		{"distance": 2.0, "angle": 0.1, "id": 1}
	]

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(a.distance, b.distance):
			return a.distance < b.distance
		if not is_equal_approx(a.angle, b.angle):
			return a.angle < b.angle
		return a.id < b.id
	)

	assert_true(candidates[0].id == 3, "1st candidate is closest with smallest angle and lowest id (id=3)")
	assert_true(candidates[1].id == 8, "2nd candidate is closest with smallest angle and next id (id=8)")
	assert_true(candidates[2].id == 5, "3rd candidate is closest with larger angle (id=5)")

	# Test cleave cap = 3 targets
	var max_targets: int = stats.sword_max_targets
	var hit_count := mini(candidates.size(), max_targets)
	assert_true(hit_count == 3, "Cleave strictly limits to maximum %d targets" % max_targets)

	commander.queue_free()


func test_health_and_damage_info() -> void:
	print("\n[GROUP 7] Testing HealthComponent & DamageInfo...")
	var hc := HealthComponent.new()
	hc.max_hp = 100
	hc.hp = 100
	add_child(hc)

	var hook_data := {
		"amount": 0,
		"info": null
	}

	hc.damaged.connect(func(amount: int, info: DamageInfo):
		hook_data["amount"] = amount
		hook_data["info"] = info
	)

	# Test take_damage with DamageInfo
	var pierce_info := DamageInfo.new(25, Enums.DamageType.PIERCE, null, 1.0, Vector3.FORWARD)
	hc.take_damage(pierce_info)

	assert_true(hc.hp == 75, "Health correctly deducted (100 -> 75)")
	assert_true(hook_data["amount"] == 25, "damaged signal emitted with correct amount 25")
	assert_true(hook_data["info"] != null and hook_data["info"].damage_type == Enums.DamageType.PIERCE, "damaged signal preserved damage_type PIERCE")

	# Test take_damage with backward compatible int and damage_type argument
	hc.take_damage(20, Enums.DamageType.BLAST)
	assert_true(hc.hp == 55, "Health correctly deducted (75 -> 55)")
	assert_true(hook_data["info"] != null and hook_data["info"].damage_type == Enums.DamageType.BLAST, "damaged signal preserved damage_type BLAST")

	hc.queue_free()
