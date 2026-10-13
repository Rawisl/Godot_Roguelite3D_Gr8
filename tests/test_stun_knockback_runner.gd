extends Node3D

var passes: int = 0
var fails: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("    AUTOMATED STUN, KNOCKBACK & UI VERIFICATION RUNNER ")
	print("=======================================================")

	var cam := get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		cam = Camera3D.new()
		add_child(cam)
	cam.make_current()

	await test_initial_hp_emit()
	test_brute_knockback_data()
	await test_commander_knockback()
	test_knockback_immunities()
	await test_stun_state_and_immunities()
	await test_bulwark_stomp_mechanics()

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
	var hp_before_deploy: int = int(commander.health.hp)
	commander.take_damage(dmg)
	assert_true(commander._knockback_velocity.is_zero_approx(), "Knockback ignored during Deploying")
	assert_true(commander.health.hp == hp_before_deploy, "Normal damage ignored during Deploying")

	var true_dmg := DamageInfo.new(10, Enums.DamageType.TRUE)
	commander.take_damage(true_dmg)
	assert_true(commander.health.hp == hp_before_deploy - 10, "TRUE damage bypasses Deploying invulnerability")
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


class DummyStructure extends Node3D:
	var received_damage: int = 0
	var received_type: int = -1
	var hit_count: int = 0

	func take_damage(info: Variant, _type: int = 0) -> void:
		hit_count += 1
		if info is DamageInfo:
			received_damage = info.amount
			received_type = info.damage_type
		elif info is int:
			received_damage = info


func test_stun_state_and_immunities() -> void:
	print("\n[GROUP 5] Testing Stun State, Interrupts, Timers & Immunities")
	var cmd_scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander: CharacterBody3D = cmd_scene.instantiate()
	add_child(commander)

	# 1. Stun clamping & application
	assert_true(not commander.is_stunned, "Commander initially not stunned")
	assert_true(commander.can_retreat(), "Commander can retreat initially")

	assert_true(bool(commander.apply_stun(2.5)), "apply_stun returns true on valid target")
	assert_true(commander.is_stunned, "Commander is now stunned")
	assert_true(is_equal_approx(commander._stun_timer, 1.5), "Stun duration capped at 1.5 s")
	assert_true(not commander.can_retreat(), "can_retreat returns false while stunned")

	# 2. Cannot re-stun while already stunned
	assert_true(not bool(commander.apply_stun(1.0)), "Cannot re-stun while already stunned")

	# 3. Interrupt attack
	commander.is_stunned = false
	commander._stun_timer = 0.0
	commander.is_attacking = true
	commander.apply_stun(1.0)
	assert_true(not commander.is_attacking, "Active attack interrupted on stun")

	# 4. Interrupt skill
	commander.is_stunned = false
	commander._stun_timer = 0.0
	commander.is_using_skill = true
	commander._battle_cry_cd_timer = 12.0
	commander.apply_stun(1.0)
	assert_true(not commander.is_using_skill, "Active skill interrupted on stun")
	assert_true(commander._battle_cry_cd_timer > 0.0, "Skill cooldown retained on stun interrupt")

	# 5. Stun timer expiration & 3s immunity transition
	commander.is_stunned = true
	commander._stun_timer = 0.05
	commander._stun_immunity_timer = 0.0
	commander._update_cooldowns_and_timers(0.06)
	assert_true(not commander.is_stunned, "Stun expires when timer drops to 0")
	assert_true(is_equal_approx(commander._stun_immunity_timer, 3.0), "Commander gains 3.0 s stun immunity after stun expires")
	assert_true(commander.can_retreat(), "can_retreat returns true after stun expires")

	# 6. Immune during 3s immunity period
	assert_true(not bool(commander.apply_stun(1.0)), "Cannot stun during 3.0 s immunity")
	assert_true(not commander.is_stunned, "is_stunned remains false during immunity")

	# 7. Immunity timer expiration
	commander._update_cooldowns_and_timers(3.1)
	assert_true(commander._stun_immunity_timer == 0.0, "Stun immunity timer decays to 0")
	assert_true(bool(commander.apply_stun(1.0)), "Can be stunned again after immunity decays")
	commander.is_stunned = false
	commander._stun_timer = 0.0

	# 8. Dodge, Deploying, and Commander Mode immunities
	commander.is_dodging = true
	assert_true(not bool(commander.apply_stun(1.0)), "Cannot stun during Dodge")
	commander.is_dodging = false

	commander.is_deploying = true
	assert_true(not bool(commander.apply_stun(1.0)), "Cannot stun during Deploying")
	commander.is_deploying = false

	commander.is_commander_mode = true
	assert_true(not bool(commander.apply_stun(1.0)), "Cannot stun in Commander Mode")
	commander.is_commander_mode = false

	# 9. Mode switch to COMMANDER clears active stun
	commander.apply_stun(1.5)
	assert_true(commander.is_stunned, "Commander stunned before mode switch")
	commander._on_mode_changed(&"COMMANDER")
	assert_true(not commander.is_stunned, "Active stun cleared on switching to COMMANDER mode")
	commander.is_commander_mode = false

	# 10. Death resets stun & immunity
	commander.apply_stun(1.5)
	commander.health.hp = 0
	commander._on_died()
	assert_true(not commander.is_stunned, "Death resets is_stunned")
	assert_true(commander._stun_timer == 0.0, "Death resets _stun_timer")
	assert_true(commander._stun_immunity_timer == 0.0, "Death resets _stun_immunity_timer")
	assert_true(not commander.can_retreat(), "Dead commander cannot retreat")

	commander.free()


func test_bulwark_stomp_mechanics() -> void:
	print("\n[GROUP 6] Testing Bulwark Boss Stomp AoE, Knockback & Stun Integration")
	var bulwark_scene: PackedScene = load("res://entities/enemy/bulwark.tscn")
	var bulwark: Bulwark = bulwark_scene.instantiate()
	add_child(bulwark)
	bulwark.global_position = Vector3.ZERO
	bulwark.spawn_grace = false
	bulwark.is_in_spawn_zone = false

	var cmd_scene: PackedScene = load("res://entities/commander/commander.tscn")
	var commander: CharacterBody3D = cmd_scene.instantiate()
	add_child(commander)
	commander.global_position = Vector3(0.0, 0.0, 1.5)

	# Allied structures inside and outside stomp radius
	var tower := DummyStructure.new()
	tower.add_to_group(&"tower")
	add_child(tower)
	tower.global_position = Vector3(1.5, 0.0, 0.0)

	var fortress := DummyStructure.new()
	fortress.add_to_group(&"fortress")
	add_child(fortress)
	fortress.global_position = Vector3(0.0, 0.0, -2.0)

	var far_tower := DummyStructure.new()
	far_tower.add_to_group(&"tower")
	add_child(far_tower)
	far_tower.global_position = Vector3(5.0, 0.0, 0.0)

	var dual_structure := DummyStructure.new()
	dual_structure.add_to_group(&"tower")
	dual_structure.add_to_group(&"barricade")
	add_child(dual_structure)
	dual_structure.global_position = Vector3(1.0, 0.0, 0.0)

	# 1. Execute stomp
	var initial_cmd_hp: int = int(commander.health.hp)
	var start_cmd_pos := commander.global_position

	bulwark.execute_stomp()

	assert_true(commander.health.hp == initial_cmd_hp - Bulwark.STOMP_DAMAGE, "Commander took Stomp damage (%d HP)" % Bulwark.STOMP_DAMAGE)
	assert_true(commander.is_stunned, "Commander stunned by Stomp")
	assert_true(is_equal_approx(commander._stun_timer, Bulwark.STOMP_STUN_DURATION), "Commander stun duration == %.1f s" % Bulwark.STOMP_STUN_DURATION)
	assert_true(commander._knockback_velocity.length() > 0.0, "Commander received knockback impulse from Stomp")

	# Wait for knockback physics loop to finish
	while not commander._knockback_velocity.is_zero_approx():
		await get_tree().physics_frame

	var displacement := (commander.global_position - start_cmd_pos).length()
	assert_true(is_equal_approx(displacement, Bulwark.STOMP_KNOCKBACK) or absf(displacement - Bulwark.STOMP_KNOCKBACK) < 0.25, "Commander displaced ~3.0 m by Boss knockback (got %.2f m)" % displacement)
	assert_true(commander.is_stunned, "Commander remains stunned during/after knockback decay")

	# Check structures in radius
	assert_true(tower.received_damage == Bulwark.STOMP_DAMAGE, "Tower in AoE took Stomp damage")
	assert_true(tower.received_type == Enums.DamageType.BLAST, "Damage type applied to Tower is BLAST")
	assert_true(fortress.received_damage == Bulwark.STOMP_DAMAGE, "Fortress in AoE took Stomp damage")
	assert_true(far_tower.received_damage == 0, "Out of range structure unaffected by Stomp")
	assert_true(dual_structure.hit_count == 1, "Multi-group structure receives Stomp damage only once")

	# 2. Dodge i-frame immunity against Stomp
	commander.global_position = Vector3(0.0, 0.0, 1.5)
	commander.is_stunned = false
	commander._stun_timer = 0.0
	commander._stun_immunity_timer = 0.0
	commander._knockback_velocity = Vector3.ZERO
	var hp_before_dodge: int = int(commander.health.hp)

	commander.is_dodging = true
	bulwark.execute_stomp()

	assert_true(commander.health.hp == hp_before_dodge, "Dodge completely avoids Stomp damage")
	assert_true(not commander.is_stunned, "Dodge avoids Stomp stun")
	assert_true(commander._knockback_velocity.is_zero_approx(), "Dodge avoids Stomp knockback")

	# 3. Boss knockback immunity
	var boss_kb_dmg := DamageInfo.new(20, Enums.DamageType.SLASH, null, 2.0, Vector3.FORWARD)
	bulwark.velocity = Vector3.ZERO
	bulwark.take_damage(boss_kb_dmg)
	var boss_horiz_vel := Vector2(bulwark.velocity.x, bulwark.velocity.z)
	assert_true(boss_horiz_vel.is_zero_approx(), "Boss ignores knockback velocity")
	assert_true(bulwark.current_state != Enums.EnemyState.STAGGER, "Boss does not enter STAGGER on knockback")

	# 4. Verify towers have no friendly fire towards Commander or structures
	var tower_scene: PackedScene = load("res://entities/tower/tower.tscn")
	if tower_scene != null:
		var active_tower: Tower = tower_scene.instantiate() as Tower
		assert_true(not active_tower._is_valid_target(commander), "Tower target validation rejects Commander (no friendly fire)")
		assert_true(not active_tower._is_valid_target(fortress), "Tower target validation rejects Fortress (no friendly fire)")
		assert_true(not active_tower._is_valid_target(tower), "Tower target validation rejects other Towers (no friendly fire)")
		active_tower.free()

	dual_structure.free()
	tower.free()
	fortress.free()
	far_tower.free()
	bulwark.free()
	commander.free()
