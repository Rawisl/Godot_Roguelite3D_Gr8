extends Node
## Runner for weapon data, the weapon state in RunState and the sword range of the commander.
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
	run_state.free()


func test_equip_in_prep() -> void:
	print("\n[GROUP 3] Equip in PREP changes the sword range")
	var run_state := _new_run_state()
	var commander := _new_commander()
	await get_tree().process_frame
	var area_shape := (commander.get("_sword_area") as Area3D).get_node("CollisionShape3D") as CollisionShape3D
	var base_radius := (area_shape.shape as CylinderShape3D).radius
	assert_true(is_equal_approx(commander.get_stat(&"sword_range", 2.2), 2.2), "base sword range 2.2 m")
	run_state.grant_weapon(&"swift")
	_equipped.clear()
	EventBus.state_changed.emit(&"PREP")
	assert_true(run_state.equip_weapon(&"swift"), "swift equips in PREP")
	assert_true(run_state.equipped_weapon == &"swift" and _equipped == [&"swift"], "equipped_weapon changed and weapon_equipped sent once")
	assert_true(is_equal_approx(commander.get_stat(&"sword_range", 2.2), 2.2 * 0.7), "sword range is 2.2 x 0.7")
	assert_true((area_shape.shape as CylinderShape3D).radius >= 2.2 * 0.7 + commander.TARGET_COLLIDER_PADDING, "sword area still covers the new range")
	assert_true(is_equal_approx((commander.get("stats") as CharacterStats).sword_range, 2.2), "CharacterStats is not written to")

	assert_true(run_state.equip_weapon(&"sword_base"), "the base sword can always be picked again")
	assert_true(is_equal_approx(commander.get_stat(&"sword_range", 2.2), 2.2), "range is back to 2.2 m")
	assert_true((area_shape.shape as CylinderShape3D).radius == base_radius, "sword area is back to its scene radius")
	assert_true(_equipped == [&"swift", &"sword_base"], "each equip sent weapon_equipped")
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
	commander.free()
	run_state.free()
