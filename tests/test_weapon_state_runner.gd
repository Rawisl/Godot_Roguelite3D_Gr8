extends Node
## Runner for weapon data, equipment and combat modifiers.
## Prints PASS/FAIL then quits.

const WEAPON_IDS: Array[StringName] = [&"sword_base", &"frost", &"chain_lightning", &"burn", &"rampage", &"swift"]

var passes: int = 0
var fails: int = 0
var _equipped: Array[StringName] = []


func _ready() -> void:
	print("\n=======================================================")
	print("          WEAPON STATE VERIFICATION                     ")
	print("=======================================================")

	EventBus.weapon_equipped.connect(func(id: StringName) -> void: _equipped.append(id))

	test_weapon_data()
	test_start_of_run()
	await test_equip_in_prep()
	test_equip_refused()
	await test_late_commander()
	await test_rampage_damage()

	print("=======================================================")
	print("WEAPON STATE TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================")
	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


func _new_run_state() -> RunState:
	var run_state := RunState.new()
	add_child(run_state)
	return run_state


func _new_commander() -> CharacterBody3D:
	var commander: CharacterBody3D = (load("res://entities/commander/commander.tscn") as PackedScene).instantiate()
	add_child(commander)
	commander.set_physics_process(false)
	return commander


func _weapon(id: StringName) -> WeaponData:
	return load("res://data/weapons/%s.tres" % id) as WeaponData


func test_weapon_data() -> void:
	print("\n[GROUP 1] WeaponData files")
	for id in WEAPON_IDS:
		var weapon := _weapon(id)
		assert_true(weapon != null and weapon.id == id, "%s loads with its id" % id)
		assert_true(weapon != null and weapon.name_key == StringName("weapon.%s.name" % id), "%s has a name key" % id)
		TranslationServer.set_locale("vi")
		assert_true(weapon != null and tr(weapon.name_key) != String(weapon.name_key), "%s name is translated" % id)
	assert_true(_weapon(&"sword_base").effect_id == &"none" and is_equal_approx(_weapon(&"sword_base").range_mult, 1.0), "sword_base: no effect, range x1.0")
	assert_true(is_equal_approx(_weapon(&"swift").range_mult, 0.7), "swift: range x0.7")
	for id in [&"frost", &"chain_lightning", &"burn", &"rampage"]:
		assert_true(is_equal_approx(_weapon(id).range_mult, 1.0), "%s: range x1.0" % id)
	var frost := _weapon(&"frost")
	assert_true(frost.effect_id == &"slow" and is_equal_approx(frost.get_param(&"frost_slow_pct"), 0.2) and is_equal_approx(frost.get_param(&"frost_duration"), 3.0), "frost: slow 20% for 3 s")
	var chain := _weapon(&"chain_lightning")
	assert_true(chain.effect_id == &"chain" and is_equal_approx(chain.get_param(&"chain_damage_pct"), 0.2) and chain.get_param(&"chain_max_targets") == 3.0
		and chain.get_param(&"chain_radius") == 2.0 and chain.get_param(&"chain_cooldown") == 5.0, "chain_lightning: 20%, 3 targets, 2 m, 5 s")
	var burn := _weapon(&"burn")
	assert_true(burn.effect_id == &"burn" and is_equal_approx(burn.get_param(&"burn_total_pct"), 0.5) and burn.get_param(&"burn_duration") == 5.0, "burn: 50% over 5 s")
	var rampage := _weapon(&"rampage")
	assert_true(rampage.effect_id == &"rampage" and is_equal_approx(rampage.get_param(&"rampage_hp_hi"), 0.8) and is_equal_approx(rampage.get_param(&"rampage_hp_mid"), 0.5)
		and is_equal_approx(rampage.get_param(&"rampage_hp_lo"), 0.3) and is_equal_approx(rampage.get_param(&"rampage_bonus_hi"), 0.1)
		and is_equal_approx(rampage.get_param(&"rampage_bonus_mid"), 0.25) and is_equal_approx(rampage.get_param(&"rampage_bonus_lo"), 0.5), "rampage: tiers 0.8 / 0.5 / 0.3, bonuses 0.10 / 0.25 / 0.50")
	assert_true(is_equal_approx(_weapon(&"swift").get_param(&"swift_attack_speed_mult"), 1.5), "swift: attack speed x1.5")
	assert_true(is_equal_approx(frost.get_param(&"missing", 7.0), 7.0) and frost.get_param(&"missing") == 0.0, "get_param falls back to the default")


func test_start_of_run() -> void:
	print("\n[GROUP 2] A run starts with the base sword only")
	var run_state := _new_run_state()
	assert_true(RunState.BASE_WEAPON == &"sword_base", "BASE_WEAPON is sword_base")
	assert_true(run_state.owned_weapons == [&"sword_base"], "owned_weapons = [sword_base]")
	assert_true(run_state.equipped_weapon == &"sword_base", "equipped_weapon = sword_base")
	assert_true(run_state.get_current_state() == &"PREP", "no state received yet counts as PREP")
	assert_true(not run_state.grant_weapon(&"sword_base") and not run_state.grant_weapon(&""), "an owned or empty id is not granted")
	assert_true(run_state.grant_weapon(&"swift") and run_state.owned_weapons == [&"sword_base", &"swift"], "swift is granted")
	assert_true(not run_state.grant_weapon(&"swift") and run_state.owned_weapons.size() == 2, "granting twice adds nothing")
	run_state.equipped_weapon = &"swift"
	var config := RunConfig.new()
	run_state.init_from_config(config)
	assert_true(run_state.owned_weapons == [&"sword_base"] and run_state.equipped_weapon == &"sword_base", "init_from_config puts the run back to the base sword only")
	run_state.free()


func test_equip_in_prep() -> void:
	print("\n[GROUP 3] Equip in PREP changes the sword range")
	var run_state := _new_run_state()
	var commander := _new_commander()
	await get_tree().process_frame
	var area_shape := (commander.get("_sword_area") as Area3D).get_node("CollisionShape3D") as CollisionShape3D
	var base_radius := (area_shape.shape as CylinderShape3D).radius
	var animator := commander.get("_anim_player") as AnimationPlayer
	var input_buffer: float = commander._cmd_input.buffer_time
	commander._start_attack(1)
	var base_animation_speed := animator.get_playing_speed()
	var base_strike_delay: float = commander._strike_timer
	commander._end_attack()
	assert_true(is_equal_approx(commander.get_stat(&"sword_range", 2.2), 2.2), "base sword range 2.2 m")
	run_state.grant_weapon(&"swift")
	_equipped.clear()
	EventBus.state_changed.emit(&"PREP")
	assert_true(run_state.equip_weapon(&"swift"), "swift equips in PREP")
	assert_true(run_state.equipped_weapon == &"swift" and _equipped == [&"swift"], "equipped_weapon changed and weapon_equipped sent once")
	assert_true(is_equal_approx(commander.get_stat(&"sword_range", 2.2), 2.2 * 0.7), "sword range is 2.2 x 0.7")
	assert_true((area_shape.shape as CylinderShape3D).radius >= 2.2 * 0.7 + commander.TARGET_COLLIDER_PADDING, "sword area still covers the new range")
	assert_true(is_equal_approx((commander.get("stats") as CharacterStats).sword_range, 2.2), "CharacterStats is not written to")
	commander._start_attack(1)
	assert_true(is_equal_approx(commander._attack_timer, 0.30), "Swift starts an attack with a 0.30 s interval")
	assert_true(is_equal_approx(commander._strike_timer, base_strike_delay / 1.5), "Swift moves the strike earlier in proportion to the interval")
	assert_true(base_animation_speed > 0.0 and is_equal_approx(animator.get_playing_speed(), base_animation_speed * 1.5), "Swift plays the sword animation at 1.5x speed")
	commander._end_attack()
	assert_true(is_equal_approx(commander._combo_reset_timer, 0.35), "Swift keeps the 0.35 s combo window")
	assert_true(is_equal_approx(commander._cmd_input.buffer_time, input_buffer), "Swift keeps the input buffer")

	assert_true(run_state.equip_weapon(&"sword_base"), "the base sword can always be picked again")
	assert_true(is_equal_approx(commander.get_stat(&"sword_range", 2.2), 2.2), "range is back to 2.2 m")
	assert_true((area_shape.shape as CylinderShape3D).radius == base_radius, "sword area is back to its scene radius")
	assert_true(_equipped == [&"swift", &"sword_base"], "each equip sent weapon_equipped")
	commander._start_attack(1)
	assert_true(is_equal_approx(commander._attack_timer, 0.45), "base sword restores the attack interval")
	assert_true(is_equal_approx(animator.get_playing_speed(), base_animation_speed), "base sword restores the sword animation speed")
	commander.free()
	run_state.free()


func test_equip_refused() -> void:
	print("\n[GROUP 4] Equip refused outside PREP and for weapons not owned")
	var run_state := _new_run_state()
	run_state.grant_weapon(&"swift")
	for state in [&"COMBAT", &"HAZARD_TRIAL", &"BOSS_INTRO", &"BOSS_COMBAT", &"SUMMARY", &"REWARD_PICK"]:
		EventBus.state_changed.emit(state)
		_equipped.clear()
		assert_true(not run_state.equip_weapon(&"swift"), "%s: refused" % state)
		assert_true(_equipped.is_empty() and run_state.equipped_weapon == &"sword_base", "%s: no signal, weapon unchanged" % state)
	EventBus.state_changed.emit(&"PREP")
	_equipped.clear()
	assert_true(not run_state.equip_weapon(&"frost"), "a weapon that is not owned is refused")
	assert_true(_equipped.is_empty() and run_state.equipped_weapon == &"sword_base", "no signal for it either")
	assert_true(run_state.equip_weapon(&"swift"), "back in PREP the equip works")

	run_state.end_run(&"ABANDONED")
	_equipped.clear()
	assert_true(not run_state.equip_weapon(&"sword_base"), "after the run has ended the equip is refused")
	assert_true(_equipped.is_empty() and run_state.equipped_weapon == &"swift", "no signal, weapon unchanged")
	run_state.free()


func test_late_commander() -> void:
	print("\n[GROUP 5] A commander that appears later takes the equipped weapon")
	var run_state := _new_run_state()
	run_state.grant_weapon(&"swift")
	EventBus.state_changed.emit(&"PREP")
	run_state.equip_weapon(&"swift")
	var commander := _new_commander()
	await get_tree().process_frame
	assert_true(is_equal_approx(commander.get_stat(&"sword_range", 2.2), 2.2 * 0.7), "new commander starts with the swift range")
	assert_true(is_equal_approx(commander.get_stat(&"attack_interval", 0.45), 0.30), "new commander starts with the Swift attack interval")
	commander.free()
	run_state.free()


func test_rampage_damage() -> void:
	print("\n[GROUP 6] Rampage uses the commander's HP when damage lands")
	var run_state := _new_run_state()
	var commander := _new_commander()
	EventBus.state_changed.emit(&"PREP")
	run_state.grant_weapon(&"rampage")
	assert_true(run_state.equip_weapon(&"rampage"), "Rampage equips in PREP")
	EventBus.reward_picked.emit(&"sharpness", &"PASSIVE", 3)
	EventBus.reward_picked.emit(&"mastery", &"STAT", 1)
	EventBus.state_changed.emit(&"COMBAT")
	var health: HealthComponent = commander.health
	for tier in [[90, 0.0], [81, 0.0], [80, 0.10], [70, 0.10], [51, 0.10], [50, 0.25], [40, 0.25], [31, 0.25], [30, 0.50]]:
		health.hp = tier[0]
		assert_true(is_equal_approx(commander.get_sword_dealt_mult(), 1.24 + tier[1]),
			"at %d HP Rampage adds %.2f to Sharpness" % tier)
	health.heal_fractional(0.5)
	assert_true(is_equal_approx(commander.get_sword_dealt_mult(), 1.49), "fractional healing over 30% moves Rampage to the middle tier")

	var target := preload("res://entities/enemy/grunt.tscn").instantiate() as Enemy
	target.position = Vector3(1.2, 0, 0)
	add_child(target)
	target.set_physics_process(false)
	target.spawn_grace = false
	target.health.max_hp = 500
	target.health.hp = 500
	commander.aim_dir = Vector3.RIGHT
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before := target.health.hp
	health.hp = 80
	commander._start_attack(1)
	health.hp = 40
	commander._execute_sword_strike(1)
	commander._end_attack()
	assert_true(before - target.health.hp == 30, "sword strike uses HP at impact with additive Sharpness and Rampage")

	var runner: SkillRunner = commander.skill_runner
	var whirlwind := runner.set_skill_level(&"whirlwind", 1)
	var sword_wave := runner.set_skill_level(&"sword_wave", 1)
	var firebomb := runner.set_skill_level(&"firebomb", 1)
	before = target.health.hp
	runner.activate(whirlwind)
	assert_true(before - target.health.hp == 23, "Whirlwind gets Sharpness, Mastery and Rampage additively")
	before = target.health.hp
	runner.activate(sword_wave)
	assert_true(before - target.health.hp == 28, "Sword Wave gets Sharpness, Mastery and Rampage additively")

	health.hp = 90
	commander.aim_point = target.global_position
	runner.activate(firebomb)
	var zone := get_node_or_null("FirebombZone") as FirebombZone
	assert_true(zone != null, "Firebomb creates a burning zone")
	if zone != null:
		before = target.health.hp
		health.hp = 30
		zone.tick(1.0)
		assert_true(before - target.health.hp == 10, "first Firebomb tick uses HP after casting")
		before = target.health.hp
		health.hp = 90
		zone.tick(1.0)
		assert_true(before - target.health.hp == 8, "second Firebomb tick reads the new HP and carries fractional damage")
		zone.free()

	EventBus.state_changed.emit(&"PREP")
	health.hp = 30
	assert_true(run_state.equip_weapon(&"sword_base"), "base sword can replace Rampage in PREP")
	assert_true(is_equal_approx(commander.get_sword_dealt_mult(), 1.24), "unequipping Rampage clears its bonus and keeps Sharpness")
	target.free()
	commander.free()
	run_state.free()
