extends Node3D
## Heal station regression with the real station scene and all ten unit types:
## - every unit that targets ground towers picks the station like any ground tower (the Barricade
##   still first for the Grunt family), ranged units do not take a melee slot, the Brute keeps the
##   Fortress, the stealth Assassin is not hidden from it (stealth only hides from towers)
## - at most max_attackers_per_tower melee units hold a slot on the station at once; a fourth waits
## The run numbers (how many runs use a station, how often the store runs dry) come from the wave
## bot, see tests/wave_bot.gd.

const STATION_SCENE: PackedScene = preload("res://entities/tower/heal_station.tscn")
const POOL_SCENE: PackedScene = preload("res://entities/projectile/projectile_pool.tscn")
const IDS: Array[StringName] = [&"grunt", &"archer", &"brute", &"sniper", &"rider", &"assassin",
	&"suicide_squad", &"captain", &"knight", &"undead"]

var passes: int = 0
var fails: int = 0
var _wm: WaveManager


func _ready() -> void:
	print("\n=======================================================")
	print("          HEAL STATION REGRESSION RUNNER TEST          ")
	print("=======================================================")
	add_child(POOL_SCENE.instantiate())
	_wm = WaveManager.new()
	_wm.set_process(false)
	_wm.set_physics_process(false)

	await test_every_type_targets_station()
	await test_slot_cap()

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")
	_wm.free()
	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		print("  [FAIL] %s" % test_name)


func _fortress(pos: Vector3) -> Node3D:
	var fort := Node3D.new()
	fort.name = "Fortress"
	fort.add_to_group(&"fortress")
	fort.position = pos
	var health := HealthComponent.new()
	health.name = "Health"
	health.max_hp = 1000
	fort.add_child(health)
	add_child(fort)
	return fort


func _station(pos: Vector3) -> Tower:
	var s := STATION_SCENE.instantiate() as Tower
	s.position = pos
	add_child(s)
	return s


func _unit(id: StringName, pos: Vector3) -> Enemy:
	var e := _wm.get_enemy_scene(id).instantiate() as Enemy
	e.position = pos
	add_child(e)
	e.set_physics_process(false)
	e.spawn_grace = false
	e.is_in_spawn_zone = false
	return e


func _physics_frames(n := 2) -> void:
	for i in n:
		await get_tree().physics_frame


func test_every_type_targets_station() -> void:
	print("\n[GROUP 1] Every unit type against a real Heal station")
	Enemy.invalidate_node_cache()
	var fort := _fortress(Vector3(-15, 0, 0))
	var station := _station(Vector3(0, 0, 0))
	await _physics_frames()
	assert_true(station.is_in_group(&"tower") and not station.is_in_group(&"tower_wall"), "The station is a ground tower")
	for id in IDS:
		Enemy.invalidate_node_cache()
		var e := _unit(id, Vector3(6, 0, 0))
		await _physics_frames(1)
		e._find_best_target()
		var data := e.data
		if data.is_charger or data.target_rules == [&"FORTRESS"]:
			assert_true(e.current_target == fort, "%s keeps the Fortress" % id)
		else:
			assert_true(e.current_target == station, "%s picks the Heal station" % id)
			if data.is_ranged:
				assert_true(not e._uses_melee_slot(station), "%s does not take a melee slot" % id)
			else:
				assert_true(e._uses_melee_slot(station), "%s fights for a melee slot" % id)
		e.free()
	station.free()
	fort.free()
	await _physics_frames()


func test_slot_cap() -> void:
	print("\n[GROUP 2] At most %d melee units on the station" % GameConfig.max_attackers_per_tower)
	Enemy.invalidate_node_cache()
	var station := _station(Vector3(0, 0, 0))
	await _physics_frames()
	var units: Array[Enemy] = []
	var melee: Array[StringName] = [&"knight", &"undead", &"rider", &"assassin"]
	var claimed := 0
	for i in melee.size():
		var e := _unit(melee[i], Vector3(1.5, 0, -1.5 + i))
		units.append(e)
		if station.claim_melee_slot(e):
			claimed += 1
	assert_true(claimed == GameConfig.max_attackers_per_tower, "%d of %d new melee units get a slot" % [claimed, melee.size()])
	var waiting := units[melee.size() - 1]
	assert_true(not station.has_melee_slot(waiting), "The fourth unit has no slot and must wait")
	station.release_melee_slot(units[0])
	assert_true(station.claim_melee_slot(waiting), "A freed slot goes to the waiting unit")
	for e in units:
		e.free()
	station.free()
	await _physics_frames()
