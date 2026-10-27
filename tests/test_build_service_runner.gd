extends Node

## Automated test runner verifying BuildService:
## - build / upgrade / sell prices and invested_gold on the Tower
## - commander level limits on upgrades, and rebuild level checks
## - slot lock during a transaction, HP refill at the start of PREP

const SLOT_SCENE: PackedScene = preload("res://systems/build/slot.tscn")
const ARROW: TowerData = preload("res://data/towers/arrow.tres")
const CANNON: TowerData = preload("res://data/towers/cannon.tres")
const BARRICADE: TowerData = preload("res://data/towers/barricade.tres")
const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
const CANNON_SCENE: PackedScene = preload("res://entities/tower/cannon.tscn")
const BARRICADE_SCENE: PackedScene = preload("res://entities/tower/barricade.tscn")

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []

var _root: Node3D
var _gold: GoldManager
var _service: BuildService
var _built: Array[StringName] = []
var _sold: Array[StringName] = []
var _denied: Array = []
var _nested_result := true
var _nested_ran := false

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED BUILD SERVICE RUNNER TEST             ")
	print("=======================================================")

	_setup()
	test_build_level_one()
	test_upgrade_to_max()
	test_sell_refund()
	test_sell_refused()
	test_not_prep()
	test_not_enough_gold()
	test_commander_level()
	test_rebuild()
	test_level_range()
	test_transaction_lock()
	test_heal_on_prep()

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

func _setup() -> void:
	_root = Node3D.new()
	add_child(_root)
	_gold = GoldManager.new()
	add_child(_gold)
	_service = BuildService.new()
	_service.towers = [ARROW, CANNON, BARRICADE]
	_service.tower_scenes = {&"arrow": ARROW_SCENE, &"cannon": CANNON_SCENE, &"barricade": BARRICADE_SCENE}
	add_child(_service)
	for id in [&"W1", &"W2", &"W3", &"W4"]:
		_make_slot(id, Enums.SlotZone.WALL)
	for id in [&"G1", &"G2", &"G3"]:
		_make_slot(id, Enums.SlotZone.GROUND)
	EventBus.tower_built.connect(func(slot_id, _type): _built.append(slot_id))
	EventBus.tower_sold.connect(func(slot_id): _sold.append(slot_id))
	EventBus.build_denied.connect(func(reason, shortfall): _denied.append([reason, shortfall]))
	_reset()

func _make_slot(id: StringName, zone: Enums.SlotZone) -> Slot:
	var slot := SLOT_SCENE.instantiate() as Slot
	slot.name = String(id)
	slot.slot_id = id
	slot.zone = zone
	_root.add_child(slot)
	return slot

## Empty slots, PREP, commander level 1, lots of gold, no recorded events.
func _reset() -> void:
	for node in get_tree().get_nodes_in_group(&"slot"):
		(node as Slot).set_state(Enums.SlotState.EMPTY)
	EventBus.run_started.emit()
	EventBus.state_changed.emit(&"PREP")
	_gold.gold = 5000
	_built.clear()
	_sold.clear()
	_denied.clear()

func _slot(id: StringName) -> Slot:
	return _service.find_slot(id)

func test_build_level_one() -> void:
	print("\n[GROUP 1] Build Arrow at level 1")
	_reset()
	var cost := ARROW.levels[0].build_cost
	assert_true(_service.build(&"W1", &"arrow"), "build returns true")
	assert_true(_gold.gold == 5000 - cost, "gold dropped by the level 1 cost")
	assert_true(_slot(&"W1").tower.invested_gold == cost, "invested_gold equals the price")
	assert_true(_built.size() == 1, "tower_built emitted once")

func test_upgrade_to_max() -> void:
	print("\n[GROUP 2] Upgrade twice with commander level 8")
	_reset()
	EventBus.level_up.emit(GameConfig.tower_gate_lv3, 0)
	_service.build(&"W1", &"arrow")
	var before := _gold.gold
	assert_true(_service.upgrade(&"W1"), "first upgrade")
	assert_true(_service.upgrade(&"W1"), "second upgrade")
	var t := _slot(&"W1").tower
	assert_true(t.level == 3, "tower is level 3")
	assert_true(t.invested_gold == ARROW.get_total_cost(3), "invested_gold equals total cost to level 3")
	# Expected totals come from the price table, not from the data files.
	assert_true(ARROW.get_total_cost(3) == 230, "Arrow level 3 total is 230 (price table)")
	assert_true(CANNON.get_total_cost(3) == 390, "Cannon level 3 total is 390 (price table)")
	assert_true(BARRICADE.get_total_cost(3) == 190, "Barricade level 3 total is 190 (price table)")
	assert_true(before - _gold.gold == ARROW.levels[1].build_cost + ARROW.levels[2].build_cost, "gold dropped by both upgrade prices")
	assert_true(_service.get_upgrade_block_reason(&"W1") == &"MAX_LEVEL", "reason is MAX_LEVEL at the top")
	var g := _gold.gold
	assert_true(not _service.upgrade(&"W1"), "third upgrade refused")
	assert_true(_gold.gold == g, "gold unchanged after the refused upgrade")

func test_sell_refund() -> void:
	print("\n[GROUP 3] Sell at level 1, 2 and 3")
	_reset()
	EventBus.level_up.emit(GameConfig.tower_gate_lv3, 0)
	var ids: Array[StringName] = [&"W1", &"W2", &"W3"]
	for i in 3:
		_service.build(ids[i], &"arrow")
		for n in i:
			_service.upgrade(ids[i])
	_sold.clear()
	for i in 3:
		var invested := _slot(ids[i]).tower.invested_gold
		var g := _gold.gold
		assert_true(_service.sell(ids[i]), "sell level %d" % (i + 1))
		assert_true(_gold.gold - g == floori(float(invested) * GameConfig.sell_refund_pct), "refund at level %d is the set share of invested" % (i + 1))
		assert_true(_slot(ids[i]).state == Enums.SlotState.EMPTY, "slot empty after selling level %d" % (i + 1))
	assert_true(_sold.size() == 3, "tower_sold emitted three times")

func test_sell_refused() -> void:
	print("\n[GROUP 4] Sell refused on RUINED and EMPTY slots")
	_reset()
	_service.build(&"W1", &"arrow")
	_slot(&"W1").ruin()
	var g := _gold.gold
	assert_true(not _service.sell(&"W1"), "RUINED slot cannot be sold")
	assert_true(not _service.sell(&"W2"), "EMPTY slot cannot be sold")
	assert_true(_gold.gold == g, "gold unchanged")

func test_not_prep() -> void:
	print("\n[GROUP 5] Nothing works outside PREP")
	_reset()
	_service.build(&"W1", &"arrow")
	EventBus.state_changed.emit(&"COMBAT")
	var g := _gold.gold
	assert_true(not _service.build(&"W2", &"arrow"), "build refused")
	assert_true(not _service.upgrade(&"W1"), "upgrade refused")
	assert_true(not _service.sell(&"W1"), "sell refused")
	assert_true(_gold.gold == g, "gold unchanged")
	assert_true(_service.get_upgrade_block_reason(&"W1") == &"NOT_PREP", "reason is NOT_PREP")
	EventBus.state_changed.emit(&"PREP")

func test_not_enough_gold() -> void:
	print("\n[GROUP 6] Not enough gold")
	_reset()
	_gold.gold = ARROW.levels[0].build_cost - 1
	assert_true(not _service.build(&"W1", &"arrow"), "build refused")
	assert_true(_denied.size() == 1 and _denied[0] == [&"NOT_ENOUGH_GOLD", 1], "build_denied has the exact shortfall")
	_reset()
	EventBus.level_up.emit(GameConfig.tower_gate_lv3, 0)
	_service.build(&"W1", &"arrow")
	_gold.gold = ARROW.levels[1].build_cost - 3
	_denied.clear()
	assert_true(not _service.upgrade(&"W1"), "upgrade refused")
	assert_true(_denied.size() == 1 and _denied[0] == [&"NOT_ENOUGH_GOLD", 3], "upgrade denied with the exact shortfall")
	assert_true(_service.get_upgrade_block_reason(&"W1") == &"NOT_ENOUGH_GOLD", "reason is NOT_ENOUGH_GOLD")

func test_commander_level() -> void:
	print("\n[GROUP 7] Commander level limits")
	_reset()
	_service.build(&"W1", &"arrow")
	var g := _gold.gold
	assert_true(not _service.can_upgrade(&"W1"), "can_upgrade false at commander level 1")
	assert_true(not _service.upgrade(&"W1"), "upgrade to 2 blocked")
	assert_true(_denied.size() == 1 and _denied[0] == [&"COMMANDER_LEVEL", 0], "build_denied COMMANDER_LEVEL, 0")
	assert_true(_gold.gold == g, "gold unchanged when blocked")
	var info := _service.get_tower_info(&"W1")
	assert_true(info.get("upgrade_required_level") == GameConfig.tower_gate_lv2, "info has the level 2 requirement")
	assert_true(info.get("upgrade_locked") == true, "info says locked")
	EventBus.level_up.emit(GameConfig.tower_gate_lv2, 0)
	assert_true(_service.upgrade(&"W1"), "upgrade to 2 allowed")
	assert_true(not _service.upgrade(&"W1"), "upgrade to 3 blocked")
	info = _service.get_tower_info(&"W1")
	assert_true(info.get("upgrade_required_level") == GameConfig.tower_gate_lv3, "info has the level 3 requirement")
	EventBus.level_up.emit(GameConfig.tower_gate_lv3, 0)
	assert_true(_service.upgrade(&"W1"), "upgrade to 3 allowed")
	EventBus.level_up.emit(3, 0)
	assert_true(_service.get_commander_level() == GameConfig.tower_gate_lv3, "a lower level_up does not lower the level")
	EventBus.run_started.emit()
	assert_true(_service.get_commander_level() == 1, "run_started resets the level")

func test_rebuild() -> void:
	print("\n[GROUP 8] Rebuild")
	_reset()
	EventBus.level_up.emit(GameConfig.tower_gate_lv3, 0)
	_service.build(&"G1", &"arrow")
	_service.upgrade(&"G1")
	_service.upgrade(&"G1")
	_slot(&"G1").ruin()
	# Back to commander level 1: rebuilding must not need the level again.
	EventBus.run_started.emit()
	_gold.gold = 5000
	assert_true(not _service.build(&"G1", &"arrow", 2), "wrong level refused")
	assert_true(_gold.gold == 5000, "gold unchanged after the wrong level")
	assert_true(_service.build(&"G1", &"arrow", 3), "rebuild at the lost level works at commander level 1")
	var t := _slot(&"G1").tower
	assert_true(_gold.gold == 5000 - ARROW.get_total_cost(3), "rebuild costs the total up to the level")
	assert_true(t.invested_gold == ARROW.get_total_cost(3), "invested_gold equals the rebuild price")
	assert_true(t.level == 3, "rebuilt at level 3")
	assert_true(t.priority == Enums.TargetPriority.FIRST, "priority is back to the default")

func test_level_range() -> void:
	print("\n[GROUP 9] Level out of range")
	_reset()
	assert_true(not _service.build(&"W1", &"arrow", 0), "level 0 refused")
	assert_true(not _service.build(&"W1", &"arrow", ARROW.levels.size() + 1), "level above max refused")
	assert_true(_gold.gold == 5000, "gold unchanged")

func _nested_build(slot_id: StringName, _type: StringName) -> void:
	_nested_result = _service.build(slot_id, &"arrow")
	_nested_ran = true

func test_transaction_lock() -> void:
	print("\n[GROUP 10] Slot lock during a transaction")
	_reset()
	_nested_ran = false
	EventBus.tower_built.connect(_nested_build)
	_service.build(&"W1", &"arrow")
	EventBus.tower_built.disconnect(_nested_build)
	assert_true(_nested_ran, "nested handler ran")
	assert_true(not _nested_result, "nested build on the same slot refused")
	assert_true(_gold.gold == 5000 - ARROW.levels[0].build_cost, "gold spent once")

func test_heal_on_prep() -> void:
	print("\n[GROUP 11] HP refill at the start of PREP")
	_reset()
	_service.build(&"W1", &"arrow")
	var t := _slot(&"W1").tower
	t.take_damage(10)
	assert_true(t.health.hp < t.health.max_hp, "tower is damaged")
	EventBus.state_changed.emit(&"COMBAT")
	EventBus.state_changed.emit(&"PREP")
	assert_true(t.health.hp == t.health.max_hp, "full HP in PREP")
	var saved := GameConfig.tower_full_heal_on_prep
	GameConfig.tower_full_heal_on_prep = false
	t.take_damage(10)
	EventBus.state_changed.emit(&"COMBAT")
	EventBus.state_changed.emit(&"PREP")
	GameConfig.tower_full_heal_on_prep = saved
	assert_true(t.health.hp < t.health.max_hp, "no refill when the option is off")
