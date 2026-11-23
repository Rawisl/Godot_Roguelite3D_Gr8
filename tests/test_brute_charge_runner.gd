extends Node3D

const LEVEL := preload("res://levels/corridor/level.tscn")
const BARRICADE := preload("res://entities/tower/barricade.tscn")
const ARROW := preload("res://entities/tower/arrow.tscn")
const BRUTE := preload("res://entities/enemy/brute.tscn")
const COMMANDER := preload("res://entities/commander/commander.tscn")

var _passed := 0
var _failed := 0


func _ready() -> void:
	await _test_corridor_charge()
	await _test_commander_charge()
	print("BRUTE CHARGE TEST SUMMARY: %d PASSED, %d FAILED" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _test_corridor_charge() -> void:
	var level := LEVEL.instantiate() as Node3D
	add_child(level)
	var lane := level.get_node("LaneCurve") as Path3D
	var fortress := level.get_node("NavigationRegion3D/Geometry/Fortress") as Fortress
	var barricade := _place_on_lane(BARRICADE, lane, 6.0)
	var tower := _place_on_lane(ARROW, lane, 14.0)
	var barricade_hp := barricade.health.hp
	var tower_hp := tower.health.hp
	await get_tree().physics_frame
	var region := level.get_node("NavigationRegion3D") as NavigationRegion3D
	region.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var brute := _spawn_brute(level, lane.curve.sample_baked(1.0))
	brute._find_best_target()
	var arrived := false
	for frame in 1500:
		await get_tree().physics_frame
		if brute.current_target == fortress and brute.current_state == Enums.EnemyState.ATTACK:
			arrived = true
			break
	_check(barricade_hp - barricade.health.hp == brute.data.impact_damage, "Physical charge hits the on-lane Barricade once")
	_check(tower_hp - tower.health.hp == brute.data.impact_damage, "Physical charge hits the on-lane tower once")
	_check(arrived and brute.recycle_count == 0,
		"Brute reaches Fortress after detours (position %s, state %s, slot %s, nav end %s, recycles %s)" % [
			brute.global_position, Enums.EnemyState.keys()[brute.current_state], fortress.get_melee_slot_position(brute),
			brute.nav.get_final_position(), brute.recycle_count])
	_check(fortress.has_melee_slot(brute), "Brute holds a Fortress melee slot after the detours")
	var impacted := brute._charge_impacts.duplicate()
	_check(brute.recycle() and brute._charge_detour_until == -INF and brute._charge_impacts == impacted,
		"Recycle clears the detour and remembers buildings already hit")
	brute._hit_charge_tower(barricade)
	_check(brute._charge_detour_until > 6.0 and barricade_hp - barricade.health.hp == brute.data.impact_damage,
		"Revisiting an impacted building schedules another detour without damage")
	level.queue_free()
	await get_tree().process_frame


func _test_commander_charge() -> void:
	var commander := COMMANDER.instantiate() as CharacterBody3D
	add_child(commander)
	commander.set_physics_process(false)
	var brute := _spawn_brute(self, Vector3(0.25, 0.0, 0.0))
	brute.set_physics_process(false)
	brute.in_hazard_room = true
	EventBus.state_changed.emit(&"HAZARD_TRIAL")
	brute._find_best_target()
	_check(brute.current_target == commander, "A Brute in Hazard targets the commander")

	var start_hp: int = commander.health.hp
	for flag in [&"is_dodging", &"is_deploying", &"is_commander_mode"]:
		commander.set(flag, true)
		brute._hit_charge_commander(commander)
		_check(commander.health.hp == start_hp, "%s prevents charge damage" % flag)
		commander.set(flag, false)

	var decoy := StaticBody3D.new()
	decoy.collision_layer = 2
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	decoy.add_child(shape)
	add_child(decoy)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var brute_hp := brute.health.hp
	commander._attack_strike_dir = Vector3.RIGHT
	commander._execute_sword_strike(1)
	_check(brute.health.hp < brute_hp and not brute.provoked_by_player, "A real commander sword hit cannot provoke a Brute")
	brute.scaled_damage = 0
	brute._check_charge_contacts()
	var impact_hp: int = commander.health.hp
	_check(start_hp - impact_hp == brute.data.base_damage and not commander._knockback_velocity.is_zero_approx(),
		"Shape contact finds the commander through a layer-two decoy and applies damage and knockback")
	brute._check_charge_contacts()
	_check(commander.health.hp == impact_hp, "Repeated contacts respect the shared cooldown")
	commander._knockback_velocity = Vector3.ZERO
	brute._execute_melee_strike()
	var melee_hp: int = commander.health.hp
	_check(impact_hp - melee_hp == brute.data.base_damage and commander._knockback_velocity.is_zero_approx(),
		"Ordinary Hazard melee still deals damage during contact cooldown without knockback")
	TimeManager.game_time += GameConfig.charge_commander_cooldown
	brute._check_charge_contacts()
	_check(melee_hp - commander.health.hp == brute.data.base_damage, "A contact hits again once the cooldown expires")


func _spawn_brute(parent: Node3D, at: Vector3) -> Enemy:
	var brute := BRUTE.instantiate() as Enemy
	brute.position = at
	parent.add_child(brute)
	brute.spawn_grace = false
	brute.is_in_spawn_zone = false
	brute.change_state(Enums.EnemyState.ADVANCE)
	return brute


func _place_on_lane(scene: PackedScene, lane: Path3D, offset: float) -> Tower:
	var tower := scene.instantiate() as Tower
	tower.position = lane.curve.sample_baked(offset)
	tower.add_to_group(NavRebaker.SOURCE_GROUP)
	lane.get_parent().add_child(tower)
	tower.set_process(false)
	tower.set_physics_process(false)
	return tower


func _check(passed: bool, label: String) -> void:
	if passed:
		_passed += 1
		print("[PASS] ", label)
	else:
		_failed += 1
		printerr("[FAIL] ", label)
