extends Node

## Automated test runner: tests BuildService.repair_fortress against the Fortress quote,
## and the Fortress click area:
## - step prices, partial repairs when gold is short, the minimum repair
## - refusals: full HP, outside PREP, destroyed Fortress, nested calls
## - the gold taken always equals what Fortress.quote_repair promises

const FORTRESS_SCENE: PackedScene = preload("res://entities/fortress/fortress.tscn")

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []

var _root: Node3D
var _gold: GoldManager
var _service: BuildService
var _fortress: Fortress
var _repaired: Array = []
var _denied: Array = []
var _gold_changes: int = 0
var _nested_results: Array = []

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED FORTRESS REPAIR RUNNER TEST           ")
	print("=======================================================")

	await _run()

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")

	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)

func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		failed_names.append(test_name)
		printerr("  [FAIL] %s" % test_name)

func _run() -> void:
	_setup()
	# GoldManager resets itself on a deferred call; let it land before gold is set by hand.
	await get_tree().process_frame
	test_small_step()
	test_large_step_capped()
	test_srs_example()
	test_short_gold()
	test_below_minimum()
	test_gap_under_one_percent()
	test_full_hp()
	test_not_prep()
	test_fortress_refuses()
	test_destroyed()
	test_transaction_lock()
	test_quote_matches_spend()
	await test_click_area()

func _setup() -> void:
	_root = Node3D.new()
	add_child(_root)
	_gold = GoldManager.new()
	add_child(_gold)
	_service = BuildService.new()
	add_child(_service)
	EventBus.fortress_repaired.connect(func(heal, source): _repaired.append([heal, source]))
	EventBus.build_denied.connect(func(reason, shortfall): _denied.append([reason, shortfall]))
	EventBus.gold_changed.connect(func(_g): _gold_changes += 1)
	_spawn_fortress()

## Frees the old Fortress at once so the "fortress" group never holds two.
func _spawn_fortress(level: int = 0) -> void:
	if _fortress != null and is_instance_valid(_fortress):
		_root.remove_child(_fortress)
		_fortress.free()
	_fortress = FORTRESS_SCENE.instantiate() as Fortress
	_fortress.fort_hp_level = level
	_root.add_child(_fortress)

func _set_hp(target: int) -> void:
	EventBus.state_changed.emit(&"COMBAT")
	var hp := _fortress.get_hp()
	if hp > target:
		_fortress.take_damage(hp - target, Enums.DamageType.TRUE)
	elif hp < target:
		_fortress.health.heal(target - hp)
	EventBus.state_changed.emit(&"PREP")

## PREP, Frontline, no recorded events.
func _reset() -> void:
	EventBus.run_started.emit()
	EventBus.state_changed.emit(&"PREP")
	EventBus.mode_changed.emit(&"FRONTLINE")
	_clear_records()

func _clear_records() -> void:
	_repaired.clear()
	_denied.clear()
	_gold_changes = 0
	_nested_results.clear()

## Fresh PREP with the given HP and gold, nothing recorded.
func _prepare(hp: int, gold: int) -> void:
	_reset()
	_set_hp(hp)
	_gold.gold = gold
	_clear_records()

func _max_hp() -> int:
	return _fortress.get_max_hp()

func _price() -> int:
	return _fortress.stats.repair_gold_per_pct

func _small() -> float:
	return _fortress.stats.repair_step_small_pct

func _large() -> float:
	return _fortress.stats.repair_step_large_pct

func test_small_step() -> void:
	print("\n[GROUP 1] Small step")
	var m := _max_hp()
	var hp := m - floori(m * 0.2)
	_prepare(hp, 5000)
	assert_true(_service.repair_fortress(_small()), "repair_fortress returns true")
	assert_true(_fortress.get_hp() == hp + floori(_small() * m), "HP rose by the small step")
	var cost := ceili(_small() * 100.0 * _price())
	assert_true(5000 - _gold.gold == cost, "gold dropped by the step price")
	var quoted: Dictionary = Fortress.quote_repair(_small() * 100.0, hp, m, 1 << 30, _price())
	assert_true(5000 - _gold.gold == int(quoted.cost), "gold equals the price the panel quotes")
	assert_true(_repaired.size() == 1 and _repaired[0] == [floori(_small() * m), &"GOLD"], "fortress_repaired emitted once with GOLD")

func test_large_step_capped() -> void:
	print("\n[GROUP 2] Large step bigger than the gap")
	var m := _max_hp()
	_prepare(m - floori(m * 0.2), 5000)
	var missing_pct := _fortress.get_missing_pct()
	assert_true(_service.repair_fortress(_large()), "repair_fortress returns true")
	assert_true(_fortress.is_full(), "HP is full")
	assert_true(5000 - _gold.gold == ceili(missing_pct * _price() - Fortress.PCT_EPSILON), "price follows the gap, not the step")

func test_srs_example() -> void:
	print("\n[GROUP 3] Worked example with FORT_HP level 1")
	_spawn_fortress(1)
	var m := _max_hp()
	if _fortress.stats.max_hp != 1000 or _price() != 4:
		print("  [SKIP] needs max_hp 1000 and 4 gold per percent")
		_spawn_fortress()
		return
	assert_true(m == 1050, "max HP is 1050")
	_prepare(1033, 5000)
	assert_true(_service.repair_fortress(0.0), "repair to full returns true")
	assert_true(_fortress.get_hp() == 1050, "HP back to 1050")
	assert_true(5000 - _gold.gold == 7, "cost 7 gold (expected SRS example)")
	_prepare(1033, 5000)
	assert_true(_service.repair_fortress(_small()), "small step returns true")
	assert_true(_fortress.get_hp() == 1050, "small step also reaches 1050")
	assert_true(5000 - _gold.gold == 7, "small step also costs 7 gold")
	_spawn_fortress()

func test_short_gold() -> void:
	print("\n[GROUP 4] Short on gold, repaired 1% at a time")
	var m := _max_hp()
	var hp := m - floori(m * 0.2)
	for step in [_small(), 0.0]:
		_prepare(hp, _price() + 2)
		assert_true(_service.repair_fortress(step), "step %s returns true" % step)
		assert_true(_fortress.get_hp() == hp + floori(m / 100.0), "HP rose by 1%%, step %s" % step)
		assert_true(_gold.gold == 2, "two gold left, step %s" % step)

func test_below_minimum() -> void:
	print("\n[GROUP 5] Gold below the smallest repair")
	var m := _max_hp()
	var hp := m - floori(m * 0.2)
	_prepare(hp, _price() - 1)
	assert_true(not _service.repair_fortress(_small()), "returns false")
	assert_true(_gold.gold == _price() - 1, "gold unchanged")
	assert_true(_fortress.get_hp() == hp, "HP unchanged")
	assert_true(_denied == [[&"NOT_ENOUGH_GOLD", 1]], "build_denied NOT_ENOUGH_GOLD with shortfall 1")
	assert_true(_repaired.is_empty(), "no fortress_repaired")

func test_gap_under_one_percent() -> void:
	print("\n[GROUP 6] Gap smaller than 1%")
	var m := _max_hp()
	var hp := m - floori(m * 0.005)
	var cost: int = Fortress.quote_repair(_small() * 100.0, hp, m, 1 << 30, _price()).cost
	_prepare(hp, cost)
	assert_true(_service.repair_fortress(_small()), "returns true")
	assert_true(_fortress.is_full(), "HP is full")
	assert_true(_gold.gold == 0, "all the gold was needed")

func test_full_hp() -> void:
	print("\n[GROUP 7] Full HP")
	_prepare(_max_hp(), 5000)
	for step in [_small(), _large(), 0.0]:
		assert_true(not _service.repair_fortress(step), "step %s refused" % step)
	assert_true(_gold.gold == 5000, "gold unchanged")
	assert_true(_gold_changes == 0 and _repaired.is_empty() and _denied.is_empty(), "no signals emitted")

func test_not_prep() -> void:
	print("\n[GROUP 8] Outside PREP, and both modes in PREP")
	var m := _max_hp()
	var hp := m - floori(m * 0.2)
	_prepare(hp, 5000)
	for state in [&"COMBAT", &"BOSS_COMBAT"]:
		EventBus.state_changed.emit(state)
		assert_true(not _service.repair_fortress(_small()), "refused in %s" % state)
	assert_true(_gold.gold == 5000 and _fortress.get_hp() == hp, "gold and HP unchanged")
	EventBus.state_changed.emit(&"PREP")
	EventBus.mode_changed.emit(&"COMMANDER")
	assert_true(_service.repair_fortress(_small()), "allowed in Commander mode during PREP")
	EventBus.mode_changed.emit(&"FRONTLINE")
	assert_true(_service.repair_fortress(_small()), "allowed in Frontline mode during PREP")

func test_fortress_refuses() -> void:
	print("\n[GROUP 9] Fortress refuses after the gold was taken")
	var m := _max_hp()
	var hp := m - floori(m * 0.2)
	_prepare(hp, 5000)
	_fortress.set(&"_wave_state", &"COMBAT")
	assert_true(not _service.repair_fortress(_small()), "returns false")
	assert_true(_gold.gold == 5000, "gold refunded")
	assert_true(_fortress.get_hp() == hp, "HP unchanged")
	_reset()

func test_destroyed() -> void:
	print("\n[GROUP 10] Destroyed Fortress")
	_prepare(_max_hp(), 5000)
	_set_hp(0)
	assert_true(_fortress.is_destroyed(), "Fortress is destroyed")
	assert_true(not _service.repair_fortress(_small()), "repair refused")
	assert_true(_gold.gold == 5000, "gold unchanged")
	_spawn_fortress()

func test_transaction_lock() -> void:
	print("\n[GROUP 11] Nested calls from signal handlers")
	var m := _max_hp()
	var hp := m - floori(m * 0.2)
	var quoted: Dictionary = Fortress.quote_repair(_small() * 100.0, hp, m, 5000, _price())
	var nest := func(): _nested_results.append(_service.repair_fortress(_small()))
	var on_repaired := func(_heal, _source): nest.call()
	var on_gold := func(_g): nest.call()
	EventBus.fortress_repaired.connect(on_repaired)
	EventBus.gold_changed.connect(on_gold)
	_prepare(hp, 5000)
	var ok := _service.repair_fortress(_small())
	EventBus.fortress_repaired.disconnect(on_repaired)
	EventBus.gold_changed.disconnect(on_gold)
	assert_true(ok, "outer call succeeds")
	assert_true(_nested_results.size() >= 2 and not _nested_results.has(true), "every nested call returned false")
	assert_true(5000 - _gold.gold == int(quoted.cost), "gold dropped by one step only")
	_prepare(hp, 5000)
	assert_true(_service.repair_fortress(_small()), "lock released after the transaction")

func test_quote_matches_spend() -> void:
	print("\n[GROUP 12] Gold spent always equals the Fortress quote")
	var m := _max_hp()
	var hps: Array[int] = [m - 1, m - 5, m - floori(m * 0.1) - 3, floori(m * 0.5), 1]
	var golds: Array[int] = [5000, 7, _price(), _price() - 1]
	var first_bad := ""
	var count := 0
	for hp in hps:
		for step in [_small(), _large(), 0.0]:
			for gold in golds:
				_prepare(hp, gold)
				var start_hp := _fortress.get_hp()
				var q: Dictionary = Fortress.quote_repair(step * 100.0, start_hp, m, gold, _price())
				var ok := _service.repair_fortress(step)
				var expected_cost: int = q.cost if q.heal > 0 else 0
				var good: bool = ok == (q.heal > 0) and gold - _gold.gold == expected_cost \
					and _fortress.get_hp() - start_hp == int(q.heal)
				count += 1
				if not good and first_bad == "":
					first_bad = "hp %d step %s gold %d: ok %s, spent %d, healed %d, quote %s" % [
						start_hp, step, gold, ok, gold - _gold.gold, _fortress.get_hp() - start_hp, q]
	if first_bad != "":
		printerr("  first mismatch: %s" % first_bad)
	assert_true(first_bad == "", "all %d combinations match the quote" % count)

func test_click_area() -> void:
	print("\n[GROUP 13] Click area")
	_spawn_fortress()
	var area := _fortress.get_node_or_null("ClickArea") as Area3D
	assert_true(area != null, "ClickArea is a direct Area3D child")
	if area == null:
		return
	assert_true(area.collision_layer == SelectionController.CLICK_LAYER, "on the click layer")
	assert_true(area.collision_mask == 0, "detects nothing")
	var shape_node := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert_true(shape_node != null and shape_node.shape != null, "has a collision shape")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var from := _fortress.global_position + Vector3(0, 20, 0)
	var to := _fortress.global_position - Vector3(0, 1, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, SelectionController.CLICK_LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := _root.get_world_3d().direct_space_state.intersect_ray(query)
	assert_true(not hit.is_empty() and (hit.collider as Node).get_parent() == _fortress, "ray hits the area whose parent is the Fortress")
