extends Node

## Automated test runner: tests BuildService.repair_fortress_mithril, Fortress.repair_with_mithril,
## RunState's Mithril API and the Fortress click area:
## - one Mithril heals mithril_repair_pct of the effective max HP, clamped at max
## - refusals: full HP, no Mithril, outside PREP, destroyed Fortress, no RunState
## - the Mithril is taken only when HP was restored, and both signals are out before the call returns
## - RunState add_mithril / spend_mithril and the reset on run_started

const FORTRESS_SCENE: PackedScene = preload("res://entities/fortress/fortress.tscn")

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []

var _root: Node3D
var _run_state: RunState
var _service: BuildService
var _fortress: Fortress
var _repaired: Array = []
var _denied: Array = []
var _mithril_events: Array = []
var _hp_events: Array = []

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
	await get_tree().process_frame
	test_heals_share_and_spends_one()
	test_clamped_at_max()
	test_full_hp()
	test_no_mithril()
	test_not_prep()
	test_destroyed()
	test_no_run_state()
	test_signals_before_return()
	test_repaired_source()
	test_second_call_without_mithril()
	test_effective_max_hp()
	test_run_state_api()
	await test_click_area()

func _setup() -> void:
	_root = Node3D.new()
	add_child(_root)
	_run_state = RunState.new()
	add_child(_run_state)
	_service = BuildService.new()
	add_child(_service)
	EventBus.fortress_repaired.connect(func(heal, source): _repaired.append([heal, source]))
	EventBus.build_denied.connect(func(reason, shortfall): _denied.append([reason, shortfall]))
	EventBus.mithril_changed.connect(func(n, delta): _mithril_events.append([n, delta]))
	EventBus.fortress_hp_changed.connect(func(hp, max_hp, delta): _hp_events.append([hp, max_hp, delta]))
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

func _clear_records() -> void:
	_repaired.clear()
	_denied.clear()
	_mithril_events.clear()
	_hp_events.clear()

## Fresh PREP with the given HP and Mithril, nothing recorded.
func _prepare(hp: int, mithril: int) -> void:
	EventBus.run_started.emit()
	EventBus.state_changed.emit(&"PREP")
	_set_hp(hp)
	_run_state.mithril = mithril
	_clear_records()

func _max_hp() -> int:
	return _fortress.get_max_hp()

## What one Mithril heals at the Fortress' effective max HP.
func _share() -> int:
	return floori(_max_hp() * _fortress.stats.mithril_repair_pct + Fortress.PCT_EPSILON)

func test_heals_share_and_spends_one() -> void:
	print("\n[GROUP 1] One Mithril heals the configured share")
	var hp := _max_hp() - _share() * 2
	_prepare(hp, 3)
	assert_true(_service.repair_fortress_mithril(), "repair_fortress_mithril returns true")
	assert_true(_fortress.get_hp() == hp + _share(), "HP rose by floor(max × mithril_repair_pct)")
	assert_true(_run_state.mithril == 2, "exactly 1 Mithril was spent")

func test_clamped_at_max() -> void:
	print("\n[GROUP 2] Gap smaller than the share")
	_prepare(_max_hp() - 1, 2)
	assert_true(_service.repair_fortress_mithril(), "still allowed")
	assert_true(_fortress.get_hp() == _max_hp(), "HP clamped at max")
	assert_true(_run_state.mithril == 1, "still costs 1 Mithril")
	assert_true(_repaired.size() == 1 and _repaired[0][0] == 1, "fortress_repaired reports the HP really healed")

func test_full_hp() -> void:
	print("\n[GROUP 3] Full HP")
	_prepare(_max_hp(), 2)
	assert_true(not _service.repair_fortress_mithril(), "refused")
	assert_true(_run_state.mithril == 2, "Mithril unchanged")
	assert_true(_repaired.is_empty(), "no fortress_repaired")
	assert_true(_mithril_events.is_empty(), "no mithril_changed")

func test_no_mithril() -> void:
	print("\n[GROUP 4] No Mithril")
	var hp := _max_hp() - _share()
	_prepare(hp, 0)
	assert_true(not _service.repair_fortress_mithril(), "refused")
	assert_true(_denied.size() == 1 and _denied[0] == [&"NOT_ENOUGH_MITHRIL", 1], "build_denied NOT_ENOUGH_MITHRIL with shortfall 1")
	assert_true(_fortress.get_hp() == hp, "HP unchanged")

func test_not_prep() -> void:
	print("\n[GROUP 5] Outside PREP")
	var hp := _max_hp() - _share()
	for state in [&"COMBAT", &"HAZARD_TRIAL", &"BOSS_COMBAT"]:
		_prepare(hp, 2)
		EventBus.state_changed.emit(state)
		assert_true(not _service.repair_fortress_mithril(), "%s: refused" % state)
		assert_true(_run_state.mithril == 2 and _fortress.get_hp() == hp, "%s: nothing spent, HP unchanged" % state)
		assert_true(_fortress.repair_with_mithril() == 0, "%s: Fortress itself refuses" % state)
	EventBus.state_changed.emit(&"PREP")

func test_destroyed() -> void:
	print("\n[GROUP 6] Destroyed Fortress")
	_spawn_fortress()
	_prepare(_max_hp(), 2)
	EventBus.state_changed.emit(&"COMBAT")
	_fortress.take_damage(_max_hp(), Enums.DamageType.TRUE)
	EventBus.state_changed.emit(&"PREP")
	assert_true(_fortress.is_destroyed(), "Fortress is destroyed")
	assert_true(not _service.repair_fortress_mithril(), "refused")
	assert_true(_run_state.mithril == 2, "Mithril unchanged")
	_spawn_fortress()

func test_no_run_state() -> void:
	print("\n[GROUP 7] No RunState")
	var hp := _max_hp() - _share()
	_prepare(hp, 2)
	_run_state.remove_from_group(&"run_state")
	assert_true(not _service.repair_fortress_mithril(), "refused")
	assert_true(_fortress.get_hp() == hp, "HP unchanged")
	_run_state.add_to_group(&"run_state")

func test_signals_before_return() -> void:
	print("\n[GROUP 8] Signals are out when the call returns")
	var hp := _max_hp() - _share()
	_prepare(hp, 3)
	_service.repair_fortress_mithril()
	assert_true(_mithril_events == [[2, -1]], "mithril_changed(n - 1, -1)")
	assert_true(_hp_events.size() == 1 and _hp_events[0] == [hp + _share(), _max_hp(), _share()], "fortress_hp_changed with the new HP and delta")

func test_repaired_source() -> void:
	print("\n[GROUP 9] fortress_repaired source")
	_prepare(_max_hp() - _share(), 1)
	_service.repair_fortress_mithril()
	assert_true(_repaired.size() == 1 and _repaired[0] == [_share(), &"MITHRIL"], "source MITHRIL and amount equal to the HP healed")

func test_second_call_without_mithril() -> void:
	print("\n[GROUP 10] Two calls, one Mithril")
	_prepare(_max_hp() - _share() * 2, 1)
	var first := _service.repair_fortress_mithril()
	var second := _service.repair_fortress_mithril()
	assert_true(first and not second, "second call refused")
	assert_true(_run_state.mithril == 0, "only 1 Mithril spent in total")
	assert_true(_fortress.get_hp() == _max_hp() - _share(), "only one share healed")

func test_effective_max_hp() -> void:
	print("\n[GROUP 11] FORT_HP level raises the share")
	_spawn_fortress(5)
	var m := _max_hp()
	assert_true(m == Fortress.compute_max_hp(_fortress.stats.max_hp, 5), "max HP includes the level")
	var hp := m - _share() * 2
	_prepare(hp, 1)
	assert_true(_service.repair_fortress_mithril(), "repair works")
	assert_true(_fortress.get_hp() == hp + floori(m * _fortress.stats.mithril_repair_pct + Fortress.PCT_EPSILON), "share follows the effective max HP")
	_spawn_fortress()

func test_run_state_api() -> void:
	print("\n[GROUP 12] RunState Mithril API")
	EventBus.run_started.emit()
	_clear_records()
	_run_state.add_mithril(3)
	assert_true(_run_state.mithril == 3 and _mithril_events == [[3, 3]], "add_mithril emits (n, +amount)")
	_run_state.add_mithril(0)
	_run_state.add_mithril(-2)
	assert_true(_run_state.mithril == 3 and _mithril_events.size() == 1, "amount <= 0 is ignored")
	_clear_records()
	assert_true(not _run_state.spend_mithril(4), "spending more than owned returns false")
	assert_true(_run_state.mithril == 3 and _mithril_events.is_empty(), "nothing changed or emitted")
	assert_true(not _run_state.spend_mithril(0) and not _run_state.spend_mithril(-1), "amount <= 0 returns false")
	assert_true(_run_state.spend_mithril(2) and _run_state.mithril == 1 and _mithril_events == [[1, -2]], "spend_mithril emits (n, -amount)")
	_run_state.add_mithril(1)
	_clear_records()
	EventBus.run_started.emit()
	assert_true(_run_state.mithril == 0 and _mithril_events == [[0, -2]], "run_started resets Mithril to 0 and emits the drop")
	_clear_records()
	EventBus.run_started.emit()
	assert_true(_mithril_events.is_empty(), "run_started with no Mithril emits nothing")

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
