extends Node

## Automated test runner verifying BuildService:
## - build / upgrade / sell prices and invested_gold on the Tower
## - commander level limits on upgrades, and rebuild level checks
## - slot lock during a transaction, HP refill at the start of PREP
## - one gold_changed per finished transaction, none when refused
## - a missing GoldManager refuses everything, and the wallet has no interest or cap
## - rubble clearing and the ground building cap
## - upgrade gates only at the first level of tiers 2 and 3, and the level cap
## - commander level from the real XpTracker (level_up and xp_changed)

const SLOT_SCENE: PackedScene = preload("res://systems/build/slot.tscn")
const ARROW: TowerData = preload("res://data/towers/arrow.tres")
const CANNON: TowerData = preload("res://data/towers/cannon.tres")
const BARRICADE: TowerData = preload("res://data/towers/barricade.tres")
const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
const CANNON_SCENE: PackedScene = preload("res://entities/tower/cannon.tscn")
const BARRICADE_SCENE: PackedScene = preload("res://entities/tower/barricade.tscn")
const HEAL_STATION_SCENE: PackedScene = preload("res://entities/tower/heal_station.tscn")
const LONG_ID := &"arrow_long"
const OVER_ID := &"arrow_over"

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
var _nested_results: Array = []
var _slot_changes: Array = []

## Arrow copies with many levels, since the real data has only three. Built from scenes
## packed with this data, so build, rebuild and apply_level all read the same levels.
var _long: TowerData
var _over: TowerData

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED BUILD SERVICE RUNNER TEST             ")
	print("=======================================================")

	_setup()
	test_build_level_one()
	test_upgrade_to_max()
	test_sell_refund()
	test_sell_refused()
	test_sell_not_earned()
	test_not_prep()
	test_not_enough_gold()
	test_commander_level()
	test_rebuild()
	test_level_range()
	test_tier_gate_table()
	test_level_cap()
	test_transaction_lock()
	test_heal_on_prep()
	test_clear_rubble()
	test_ground_cap()
	test_ground_cap_ruined()
	test_ground_cap_clear()
	test_ground_cap_sell()
	test_clear_rubble_lock()
	test_real_xp_tracker()
	test_gold_changed_once()
	test_missing_gold_manager()
	test_wallet()
	test_scene_data()

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
	_long = _long_arrow(LONG_ID, GameConfig.tower_max_level)
	_over = _long_arrow(OVER_ID, GameConfig.tower_max_level + 4)
	_service.towers = [ARROW, CANNON, BARRICADE, _long, _over]
	_service.tower_scenes = {
		&"arrow": ARROW_SCENE,
		&"cannon": CANNON_SCENE,
		&"barricade": BARRICADE_SCENE,
		LONG_ID: _scene_with(_long),
		OVER_ID: _scene_with(_over),
	}
	add_child(_service)
	for id in [&"W1", &"W2", &"W3", &"W4"]:
		_make_slot(id, Enums.SlotZone.WALL)
	# One more GROUND slot than the cap allows.
	for i in GameConfig.max_ground_buildings + 1:
		_make_slot(_ground_id(i), Enums.SlotZone.GROUND)
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

## Empty slots, PREP, commander level 0, lots of gold, no recorded events.
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

func _long_arrow(id: StringName, count: int) -> TowerData:
	var data := ARROW.duplicate() as TowerData
	data.id = id
	var levels: Array[TowerLevelData] = []
	for i in count:
		var lv := ARROW.levels[0].duplicate() as TowerLevelData
		lv.build_cost = 1
		levels.append(lv)
	data.levels = levels
	return data

func _scene_with(data: TowerData) -> PackedScene:
	var proto := ARROW_SCENE.instantiate() as Tower
	proto.data = data
	var ps := PackedScene.new()
	ps.pack(proto)
	proto.free()
	return ps

## Upgrades until the tower on the slot reaches `level`; false as soon as one upgrade fails.
func _upgrade_to(slot_id: StringName, level: int) -> bool:
	if _slot(slot_id) == null or _slot(slot_id).tower == null:
		return false
	while _slot(slot_id).tower.level < level:
		if not _service.upgrade(slot_id):
			return false
	return true

func test_build_level_one() -> void:
	print("\n[GROUP 1] Build Arrow at level 1")
	_reset()
	var cost := ARROW.levels[0].build_cost
	assert_true(_service.build(&"W1", &"arrow"), "build returns true")
	assert_true(_gold.gold == 5000 - cost, "gold dropped by the level 1 cost")
	assert_true(_slot(&"W1").tower.invested_gold == cost, "invested_gold equals the price")
	assert_true(_built.size() == 1, "tower_built emitted once")

func test_upgrade_to_max() -> void:
	print("\n[GROUP 2] Upgrade Arrow to its last level")
	_reset()
	EventBus.level_up.emit(GameConfig.tower_gate_tier3, 0)
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
	EventBus.level_up.emit(GameConfig.tower_gate_tier3, 0)
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

func test_sell_not_earned() -> void:
	print("\n[GROUP 4b] Sell refunds are not counted as earned gold")
	_reset()
	var rs := RunState.new()
	add_child(rs)
	_gold.gold = 5000
	_service.build(&"W1", &"arrow")
	var expected: int = _service.get_tower_info(&"W1").sell_value
	var g := _gold.gold
	var earned := rs.run_gold_earned
	assert_true(_service.sell(&"W1"), "sell works with a RunState in the tree")
	assert_true(_gold.gold - g == expected and expected > 0, "gold rises by the shown sell value")
	assert_true(rs.run_gold_earned == earned, "run_gold_earned unchanged after the sell")
	_gold.add(40)
	assert_true(rs.run_gold_earned == earned + 40, "other gold still counts as earned")

	# Heal station, refunded by its remaining HP.
	var saved_towers := _service.towers.duplicate()
	var saved_scenes := _service.tower_scenes.duplicate()
	_service.towers.append(_service.heal_station_data)
	_service.tower_scenes[&"heal_station"] = HEAL_STATION_SCENE
	var gid := _ground_id(0)
	assert_true(_service.build(gid, &"heal_station"), "heal station built")
	var station = _slot(gid).tower
	station.drain(float(station.health.max_hp) / 2.0)
	var heal_value: int = _service.get_tower_info(gid).sell_value
	g = _gold.gold
	earned = rs.run_gold_earned
	assert_true(_service.sell(gid), "heal station sold")
	assert_true(_gold.gold - g == heal_value and heal_value > 0, "gold rises by the HP-based refund")
	assert_true(rs.run_gold_earned == earned, "run_gold_earned unchanged after selling the heal station")
	_service.towers.assign(saved_towers)
	_service.tower_scenes = saved_scenes
	remove_child(rs)
	rs.free()

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
	EventBus.level_up.emit(GameConfig.tower_gate_tier3, 0)
	_service.build(&"W1", &"arrow")
	_gold.gold = ARROW.levels[1].build_cost - 3
	_denied.clear()
	assert_true(not _service.upgrade(&"W1"), "upgrade refused")
	assert_true(_denied.size() == 1 and _denied[0] == [&"NOT_ENOUGH_GOLD", 3], "upgrade denied with the exact shortfall")
	assert_true(_service.get_upgrade_block_reason(&"W1") == &"NOT_ENOUGH_GOLD", "reason is NOT_ENOUGH_GOLD")

func test_commander_level() -> void:
	print("\n[GROUP 7] Commander level limits")
	var t2 := GameConfig.tower_tier2_level
	var t3 := GameConfig.tower_tier3_level
	var g2 := GameConfig.tower_gate_tier2
	var g3 := GameConfig.tower_gate_tier3
	_reset()
	assert_true(_service.get_commander_level() == 0, "TC1: a new run starts at commander level 0")
	_service.build(&"W1", LONG_ID)
	assert_true(_upgrade_to(&"W1", t2 - 1), "TC1: upgrades below the tier 2 level need no commander level")
	var g := _gold.gold
	assert_true(not _service.can_upgrade(&"W1"), "TC1: can_upgrade false below the tier 2 gate")
	_denied.clear()
	assert_true(not _service.upgrade(&"W1"), "TC1: upgrade onto the tier 2 level blocked")
	assert_true(_denied == [[&"COMMANDER_LEVEL", 0]], "TC1: build_denied COMMANDER_LEVEL, 0")
	assert_true(_gold.gold == g, "TC1: gold unchanged when blocked")
	var info := _service.get_tower_info(&"W1")
	assert_true(info.get("upgrade_required_level") == g2, "TC1: info has the tier 2 requirement")
	assert_true(info.get("upgrade_locked") == true, "TC1: info says locked")
	EventBus.level_up.emit(g2, 0)
	assert_true(_service.upgrade(&"W1") and _slot(&"W1").tower.level == t2, "upgrade onto the tier 2 level allowed at the gate")
	info = _service.get_tower_info(&"W1")
	assert_true(info.get("upgrade_required_level") == 0 and info.get("upgrade_locked") == false, "levels inside a tier have no requirement")
	assert_true(_upgrade_to(&"W1", t3 - 1), "upgrades up to the tier 3 level go through")
	assert_true(not _service.upgrade(&"W1") and _service.get_upgrade_block_reason(&"W1") == &"COMMANDER_LEVEL", "upgrade onto the tier 3 level blocked")
	info = _service.get_tower_info(&"W1")
	assert_true(info.get("upgrade_required_level") == g3, "info has the tier 3 requirement")
	EventBus.level_up.emit(g3, 0)
	assert_true(_upgrade_to(&"W1", GameConfig.tower_max_level), "upgrades reach the level cap once the tier 3 gate is open")
	info = _service.get_tower_info(&"W1")
	assert_true(_service.get_upgrade_block_reason(&"W1") == &"MAX_LEVEL" and info.get("is_max") == true, "reason is MAX_LEVEL at the level cap")
	EventBus.level_up.emit(g2, 0)
	assert_true(_service.get_commander_level() == g3, "a lower level_up does not lower the level")
	EventBus.run_started.emit()
	assert_true(_service.get_commander_level() == 0, "TC2: run_started resets the level")
	# A tower below the tier 2 level is gated again after the reset.
	_gold.gold = 5000
	_service.build(&"W2", LONG_ID)
	assert_true(_upgrade_to(&"W2", t2 - 1), "TC2: tower reaches the level below the tier 2 level")
	assert_true(not _service.upgrade(&"W2"), "TC2: upgrade blocked again after run_started")
	assert_true(_service.get_upgrade_block_reason(&"W2") == &"COMMANDER_LEVEL", "TC2: reason is COMMANDER_LEVEL after run_started")

func test_rebuild() -> void:
	print("\n[GROUP 8] Rebuild")
	_reset()
	EventBus.level_up.emit(GameConfig.tower_gate_tier3, 0)
	_service.build(&"G1", &"arrow")
	_service.upgrade(&"G1")
	_service.upgrade(&"G1")
	_slot(&"G1").ruin()
	# Back to commander level 0: rebuilding must not need the level again.
	EventBus.run_started.emit()
	_gold.gold = 5000
	assert_true(not _service.build(&"G1", &"arrow", 2), "wrong level refused")
	assert_true(_gold.gold == 5000, "gold unchanged after the wrong level")
	assert_true(_service.build(&"G1", &"arrow", 3), "rebuild at the lost level works at commander level 0")
	var t := _slot(&"G1").tower
	assert_true(_gold.gold == 5000 - ARROW.get_total_cost(3), "rebuild costs the total up to the level")
	assert_true(t.invested_gold == ARROW.get_total_cost(3), "invested_gold equals the rebuild price")
	assert_true(t.level == 3, "rebuilt at level 3")
	assert_true(t.priority == Enums.TargetPriority.FIRST, "priority is back to the default")

	# A tower above the tier 2 level is rebuilt without any commander level.
	var t2 := GameConfig.tower_tier2_level
	_reset()
	EventBus.level_up.emit(GameConfig.tower_gate_tier2, 0)
	_service.build(&"W2", LONG_ID)
	_upgrade_to(&"W2", t2 + 1)
	_slot(&"W2").ruin()
	EventBus.run_started.emit()
	_gold.gold = 5000
	assert_true(_service.build(&"W2", LONG_ID, t2 + 1), "rebuild above the tier 2 level works at commander level 0")
	assert_true(_slot(&"W2").tower.level == t2 + 1, "rebuilt long tower keeps its level")
	assert_true(5000 - _gold.gold == _long.get_total_cost(t2 + 1), "long rebuild costs the total up to the level")

func test_tier_gate_table() -> void:
	print("\n[GROUP 9a] Upgrade gate table")
	var t2 := GameConfig.tower_tier2_level
	var t3 := GameConfig.tower_tier3_level
	assert_true(1 < t2 and t2 < t3 and t3 <= GameConfig.tower_max_level, "tier levels sit inside the level range")
	assert_true(_service.get_upgrade_required_level(t2) == GameConfig.tower_gate_tier2, "the tier 2 level needs the tier 2 gate")
	assert_true(_service.get_upgrade_required_level(t3) == GameConfig.tower_gate_tier3, "the tier 3 level needs the tier 3 gate")
	var next_to_tiers := [t2 - 1, t2 + 1, t3 - 1, t3 + 1]
	assert_true(next_to_tiers.all(func(n): return _service.get_upgrade_required_level(n) == 0), "levels next to the tier levels need nothing")
	var gated := 0
	for n in range(2, GameConfig.tower_max_level + 1):
		if _service.get_upgrade_required_level(n) > 0:
			gated += 1
	assert_true(gated == 2, "exactly two levels have a gate")

func test_level_cap() -> void:
	print("\n[GROUP 9b] Level cap")
	var cap := GameConfig.tower_max_level
	assert_true(_service.get_max_level(_over) == cap, "get_max_level caps long data at tower_max_level")
	assert_true(_service.get_max_level(ARROW) == ARROW.levels.size(), "get_max_level keeps short data as is")
	_reset()
	EventBus.level_up.emit(GameConfig.tower_gate_tier3, 0)
	_service.build(&"W1", OVER_ID)
	assert_true(_upgrade_to(&"W1", cap), "upgrades stop at tower_max_level")
	assert_true(_service.get_upgrade_block_reason(&"W1") == &"MAX_LEVEL", "reason is MAX_LEVEL at the cap even with levels left in the data")
	var info := _service.get_tower_info(&"W1")
	assert_true(info.get("is_max") == true and not info.has("upgrade_cost"), "info is_max at the cap, no upgrade price")
	assert_true(not _service.upgrade(&"W1") and _slot(&"W1").tower.level == cap, "upgrade past the cap refused")
	var g := _gold.gold
	assert_true(not _service.build(&"W2", OVER_ID, cap + 1), "build above the cap refused")
	assert_true(_gold.gold == g, "gold unchanged after the refused build")

func test_scene_data() -> void:
	print("\n[GROUP 22] Tower scenes carry the data BuildService uses")
	for type in [&"arrow", &"cannon", &"barricade", LONG_ID, OVER_ID]:
		var inst = _service.tower_scenes[type].instantiate()
		assert_true(inst.data == _service.get_data(type), "%s scene carries the data BuildService uses" % type)
		inst.free()
	var heal = HEAL_STATION_SCENE.instantiate()
	assert_true(heal.data == _service.heal_station_data, "heal station scene carries heal_station_data")
	heal.free()

func test_level_range() -> void:
	print("\n[GROUP 9] Level out of range")
	_reset()
	assert_true(not _service.build(&"W1", &"arrow", 0), "level 0 refused")
	assert_true(not _service.build(&"W1", &"arrow", ARROW.levels.size() + 1), "level above max refused")
	assert_true(_gold.gold == 5000, "gold unchanged")

## Runs `action` from inside `signal_ref`, so it only succeeds when the slot is not locked.
## The result of each nested call lands in _nested_results.
func _connect_nested(signal_ref: Signal, action: Callable) -> Callable:
	var handler := func(slot_id: StringName, _a = null, _b = null) -> void:
		_nested_results.append(action.call(slot_id))
	signal_ref.connect(handler)
	return handler

func test_transaction_lock() -> void:
	print("\n[GROUP 10] Slot lock during a transaction")
	var cost1 := ARROW.levels[0].build_cost

	# build -> nested sell on the same slot.
	_reset()
	_nested_results.clear()
	var handler := _connect_nested(EventBus.tower_built, func(id): return _service.sell(id))
	var ok := _service.build(&"W1", &"arrow")
	EventBus.tower_built.disconnect(handler)
	assert_true(ok, "outer build works")
	assert_true(_nested_results == [false], "nested sell during build refused")
	assert_true(_slot(&"W1").state == Enums.SlotState.OCCUPIED, "tower still stands after the nested sell")
	assert_true(_gold.gold == 5000 - cost1, "gold spent once, nothing refunded")

	# build -> nested upgrade on the same slot (would succeed with every gate open).
	_reset()
	EventBus.level_up.emit(GameConfig.tower_gate_tier3, 0)
	_nested_results.clear()
	handler = _connect_nested(EventBus.tower_built, func(id): return _service.upgrade(id))
	ok = _service.build(&"W1", &"arrow")
	EventBus.tower_built.disconnect(handler)
	assert_true(ok, "outer build works with the upgrade handler")
	assert_true(_nested_results == [false], "nested upgrade during build refused")
	assert_true(_slot(&"W1").tower.level == 1, "tower stays at level 1")
	assert_true(_gold.gold == 5000 - cost1, "gold spent once for the build")

	# upgrade -> nested sell on the same slot.
	_reset()
	EventBus.level_up.emit(GameConfig.tower_gate_tier3, 0)
	_service.build(&"W1", &"arrow")
	_nested_results.clear()
	handler = _connect_nested(EventBus.tower_upgraded, func(id): return _service.sell(id))
	ok = _service.upgrade(&"W1")
	EventBus.tower_upgraded.disconnect(handler)
	assert_true(ok, "outer upgrade works")
	assert_true(_nested_results == [false], "nested sell during upgrade refused")
	assert_true(_slot(&"W1").state == Enums.SlotState.OCCUPIED and _slot(&"W1").tower.level == 2, "level 2 tower still stands")

	# sell -> nested build on the same slot (the slot is already EMPTY, so it would succeed).
	_reset()
	_service.build(&"W1", &"arrow")
	var before := _gold.gold
	var refund := floori(float(_slot(&"W1").tower.invested_gold) * GameConfig.sell_refund_pct)
	_nested_results.clear()
	handler = _connect_nested(EventBus.tower_sold, func(id): return _service.build(id, &"arrow"))
	ok = _service.sell(&"W1")
	EventBus.tower_sold.disconnect(handler)
	assert_true(ok, "outer sell works")
	assert_true(_nested_results == [false], "nested build during sell refused")
	assert_true(_slot(&"W1").state == Enums.SlotState.EMPTY, "slot is EMPTY after the sell")
	assert_true(_gold.gold == before + refund, "gold rose by the refund only")

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

func _ground_id(i: int) -> StringName:
	return StringName("G%d" % (i + 1))

## Fills the first max_ground_buildings GROUND slots with Arrow towers.
func _fill_ground() -> void:
	for i in GameConfig.max_ground_buildings:
		_service.build(_ground_id(i), &"arrow")

func _on_slot_changed(slot_id: StringName, new_state: StringName) -> void:
	_slot_changes.append([slot_id, new_state])

func test_clear_rubble() -> void:
	print("\n[GROUP 12] Clear rubble")
	_reset()
	_service.build(&"G1", &"arrow")
	_slot(&"G1").ruin()
	var g := _gold.gold
	_slot_changes.clear()
	EventBus.slot_state_changed.connect(_on_slot_changed)
	var ok := _service.clear_rubble(&"G1")
	EventBus.slot_state_changed.disconnect(_on_slot_changed)
	var slot := _slot(&"G1")
	assert_true(ok, "clear_rubble returns true")
	assert_true(slot.state == Enums.SlotState.EMPTY, "slot is EMPTY")
	assert_true(slot.last_data == null and slot.last_level == 0, "lost tower forgotten")
	assert_true(_gold.gold == g, "gold unchanged")
	assert_true(_slot_changes == [[&"G1", &"EMPTY"]], "slot_state_changed(EMPTY) emitted once")
	var has_rebuild := false
	for option in _service.get_build_options(&"G1"):
		has_rebuild = has_rebuild or option.rebuild
	assert_true(not has_rebuild, "no rebuild entry left")
	assert_true(not slot.rubble.visible, "rubble hidden")
	assert_true(not _service.clear_rubble(&"G1"), "EMPTY slot refused")
	_service.build(&"G1", &"arrow")
	assert_true(not _service.clear_rubble(&"G1"), "OCCUPIED slot refused")
	_slot(&"G1").ruin()
	EventBus.state_changed.emit(&"COMBAT")
	assert_true(not _service.clear_rubble(&"G1"), "refused outside PREP")
	assert_true(_slot(&"G1").state == Enums.SlotState.RUINED, "still RUINED after the refusal")
	EventBus.state_changed.emit(&"PREP")
	assert_true(not _service.clear_rubble(&"missing"), "unknown slot refused")

func test_ground_cap() -> void:
	print("\n[GROUP 13] Ground building cap")
	_reset()
	_fill_ground()
	assert_true(_service.get_ground_used() == GameConfig.max_ground_buildings, "ground used reaches the cap")
	assert_true(_service.is_ground_full(), "ground is full")
	var extra := _ground_id(GameConfig.max_ground_buildings)
	var g := _gold.gold
	_denied.clear()
	assert_true(not _service.build(extra, &"arrow"), "build on an EMPTY ground slot refused")
	assert_true(_denied.size() == 1 and _denied[0] == [&"GROUND_FULL", 0], "build_denied GROUND_FULL")
	assert_true(_gold.gold == g, "gold unchanged")
	var options := _service.get_build_options(extra)
	assert_true(not options.is_empty() and options.all(func(o): return o.locked_reason == &"GROUND_FULL"), "options carry locked_reason GROUND_FULL")
	assert_true(_service.build(&"W1", &"arrow"), "WALL slot still builds")
	assert_true(_service.get_ground_used() == GameConfig.max_ground_buildings, "WALL does not count")
	_reset()
	options = _service.get_build_options(&"G1")
	assert_true(not options.is_empty() and options.all(func(o): return o.locked_reason == &""), "no locked_reason when not full")

func test_ground_cap_ruined() -> void:
	print("\n[GROUP 14] Ruined slots keep their place")
	_reset()
	_fill_ground()
	var extra := _ground_id(GameConfig.max_ground_buildings)
	_slot(&"G1").ruin()
	assert_true(_service.get_ground_used() == GameConfig.max_ground_buildings, "ground used unchanged by ruin")
	assert_true(not _service.build(extra, &"arrow"), "extra slot still refused")
	assert_true(_service.build(&"G1", &"arrow"), "build on a RUINED ground slot works when full")

func test_ground_cap_clear() -> void:
	print("\n[GROUP 15] Clearing frees a place")
	_reset()
	_fill_ground()
	var extra := _ground_id(GameConfig.max_ground_buildings)
	var cap := GameConfig.max_ground_buildings
	_slot(&"G1").ruin()
	assert_true(_service.clear_rubble(&"G1"), "rubble cleared")
	assert_true(_service.get_ground_used() == cap - 1, "ground used dropped by 1")
	assert_true(_service.build(extra, &"arrow"), "extra slot builds now")
	assert_true(GameConfig.max_ground_buildings == cap, "cap setting unchanged")

func test_ground_cap_sell() -> void:
	print("\n[GROUP 16] Selling frees a place")
	_reset()
	_fill_ground()
	assert_true(_service.sell(&"G2"), "sold a ground tower")
	assert_true(_service.get_ground_used() == GameConfig.max_ground_buildings - 1, "ground used dropped by 1")

func _nested_clear(_slot_id: StringName, _new_state: StringName) -> void:
	_nested_result = _service.build(&"G1", &"arrow")
	_nested_ran = true

func test_clear_rubble_lock() -> void:
	print("\n[GROUP 17] Slot lock while clearing")
	_reset()
	_service.build(&"G1", &"arrow")
	_slot(&"G1").ruin()
	_nested_ran = false
	var gold_before := _gold.gold
	EventBus.slot_state_changed.connect(_nested_clear)
	var ok := _service.clear_rubble(&"G1")
	EventBus.slot_state_changed.disconnect(_nested_clear)
	assert_true(ok, "outer clear works")
	assert_true(_nested_ran, "nested handler ran")
	assert_true(not _nested_result, "nested build on the slot being cleared refused")
	assert_true(_slot(&"G1").state == Enums.SlotState.EMPTY, "slot is EMPTY after the outer clear")
	assert_true(_gold.gold == gold_before, "gold unchanged")

## Total XP a fresh tracker needs to reach the given commander level.
func _xp_to_reach(level: int) -> float:
	var total := 0.0
	for n in range(1, level + 1):
		total += float(GameConfig.get_xp_to_level(n))
	return total

func test_real_xp_tracker() -> void:
	print("\n[GROUP 18] Commander level from the real XpTracker")
	var g2 := GameConfig.tower_gate_tier2
	var g3 := GameConfig.tower_gate_tier3
	var t2 := GameConfig.tower_tier2_level
	var t3 := GameConfig.tower_tier3_level
	# Stays in the tree until the runner quits, so its deferred first emit has a live node.
	var tracker := XpTracker.new()
	add_child(tracker)

	# Just below the tier 2 gate.
	_reset()
	_service.build(&"W1", LONG_ID)
	assert_true(_upgrade_to(&"W1", t2 - 1), "TC3: tower reaches the level below the tier 2 level")
	_denied.clear()
	var g := _gold.gold
	tracker.add_xp(_xp_to_reach(g2 - 1))
	assert_true(tracker.commander_level == g2 - 1, "TC3: tracker reaches the level below the tier 2 gate")
	assert_true(_service.get_commander_level() == g2 - 1, "TC3: service level matches the tracker")
	assert_true(_service.get_upgrade_block_reason(&"W1") == &"COMMANDER_LEVEL", "TC3: reason is COMMANDER_LEVEL")
	assert_true(_service.get_tower_info(&"W1").get("upgrade_locked") == true, "TC3: info says locked")
	assert_true(not _service.upgrade(&"W1"), "TC3: upgrade onto the tier 2 level refused")
	assert_true(_denied == [[&"COMMANDER_LEVEL", 0]], "TC3: build_denied COMMANDER_LEVEL, 0")
	assert_true(_slot(&"W1").tower.level == t2 - 1, "TC3: tower stays below the tier 2 level")
	assert_true(_gold.gold == g, "TC3: gold unchanged")

	# Exactly on the tier 2 gate.
	if GameConfig.xp_base == 5 and GameConfig.xp_step == 4:
		assert_true(_xp_to_reach(g2) == 44.0, "TC4: total XP to the tier 2 gate is 44")
	else:
		print("  [SKIP] TC4: XP milestone check needs xp_base 5 and xp_step 4")
	tracker.add_xp(_xp_to_reach(g2) - _xp_to_reach(g2 - 1))
	assert_true(_service.get_commander_level() == g2, "TC4: service reaches the tier 2 gate")
	assert_true(_service.get_tower_info(&"W1").get("upgrade_locked") == false, "TC4: info says unlocked")
	assert_true(_service.upgrade(&"W1"), "TC4: upgrade onto the tier 2 level allowed")
	assert_true(_slot(&"W1").tower.level == t2, "TC4: tower is at the tier 2 level")
	assert_true(_upgrade_to(&"W1", t3 - 1), "TC4: tower reaches the level below the tier 3 level")
	var info := _service.get_tower_info(&"W1")
	assert_true(info.get("upgrade_required_level") == g3, "TC4: next requirement is the tier 3 gate")
	assert_true(info.get("upgrade_locked") == true, "TC4: tier 3 upgrade is locked")

	# Exactly on the tier 3 gate.
	tracker.add_xp(_xp_to_reach(g3) - _xp_to_reach(g2))
	assert_true(_service.get_commander_level() == g3, "TC5: service reaches the tier 3 gate")
	assert_true(_service.upgrade(&"W1"), "TC5: upgrade onto the tier 3 level allowed")
	assert_true(_slot(&"W1").tower.level == t3, "TC5: tower reaches the tier 3 level")

	# xp_changed alone, as after restoring a run.
	_reset()
	var level_ups: Array = []
	var count_level_up := func(level: int, _picks: int) -> void: level_ups.append(level)
	EventBus.level_up.connect(count_level_up)
	EventBus.xp_changed.emit(0.0, g2, 17.0, 0)
	EventBus.level_up.disconnect(count_level_up)
	assert_true(_service.get_commander_level() == g2, "TC6: xp_changed alone sets the level")
	assert_true(level_ups.is_empty(), "TC6: no level_up was emitted")
	_service.build(&"W2", LONG_ID)
	assert_true(_upgrade_to(&"W2", t2), "TC6: upgrade onto the tier 2 level allowed after xp_changed alone")

	# One add_xp call crossing several levels.
	_reset()
	level_ups.clear()
	EventBus.level_up.connect(count_level_up)
	tracker.add_xp(_xp_to_reach(g3))
	EventBus.level_up.disconnect(count_level_up)
	assert_true(level_ups.size() == g3, "TC8: level_up emitted once per level gained")
	assert_true(tracker.commander_level == g3, "TC8: tracker reaches the tier 3 gate")
	assert_true(_service.get_commander_level() == g3, "TC8: service level matches the tracker")
	assert_true(tracker.pending_picks == g3, "TC8: one pending pick per level gained")

	# run_started resets both the tracker and the service.
	_reset()
	tracker.add_xp(_xp_to_reach(g3))
	_service.build(&"W3", LONG_ID)
	_upgrade_to(&"W3", t2 - 1)
	EventBus.run_started.emit()
	_gold.gold = 5000
	assert_true(tracker.commander_level == 0 and tracker.xp == 0.0, "TC9: tracker is reset by run_started")
	assert_true(_service.get_commander_level() == 0, "TC9: service level is reset by run_started")
	assert_true(_service.get_tower_info(&"W3").get("upgrade_locked") == true, "TC9: tower below the tier 2 level is locked again")
	assert_true(not _service.upgrade(&"W3"), "TC9: upgrade blocked again")
	assert_true(_service.get_upgrade_block_reason(&"W3") == &"COMMANDER_LEVEL", "TC9: reason is COMMANDER_LEVEL")

## Counts gold_changed while `action` runs. The counter is an Array so the lambda can fill it.
func _count_gold_changes(action: Callable) -> int:
	var changes: Array = []
	var counter := func(_g: int) -> void: changes.append(_g)
	EventBus.gold_changed.connect(counter)
	action.call()
	EventBus.gold_changed.disconnect(counter)
	return changes.size()

func test_gold_changed_once() -> void:
	print("\n[GROUP 19] One gold_changed per finished transaction")
	_reset()
	EventBus.level_up.emit(GameConfig.tower_gate_tier3, 0)
	assert_true(_count_gold_changes(func(): _service.build(&"W1", &"arrow")) == 1, "build emits gold_changed once")
	assert_true(_count_gold_changes(func(): _service.upgrade(&"W1")) == 1, "upgrade emits gold_changed once")
	assert_true(_count_gold_changes(func(): _service.sell(&"W1")) == 1, "sell emits gold_changed once")

	_reset()
	_gold.gold = ARROW.levels[0].build_cost - 1
	assert_true(_count_gold_changes(func(): _service.build(&"W1", &"arrow")) == 0, "refused build (not enough gold) emits none")

	_reset()
	_service.build(&"W1", LONG_ID)
	_upgrade_to(&"W1", GameConfig.tower_tier2_level - 1)
	assert_true(_count_gold_changes(func(): _service.upgrade(&"W1")) == 0, "upgrade blocked by commander level emits none")

	_reset()
	_service.build(&"W1", &"arrow")
	_slot(&"W1").ruin()
	assert_true(_count_gold_changes(func(): _service.sell(&"W1")) == 0, "sell on a RUINED slot emits none")

	_reset()
	EventBus.state_changed.emit(&"COMBAT")
	assert_true(_count_gold_changes(func(): _service.build(&"W1", &"arrow")) == 0, "build outside PREP emits none")
	EventBus.state_changed.emit(&"PREP")

func test_missing_gold_manager() -> void:
	print("\n[GROUP 20] Missing GoldManager")
	_reset()
	_service.build(&"W1", &"arrow")
	remove_child(_gold)
	assert_true(_service.get_upgrade_block_reason(&"W1") == &"NO_GOLD_MANAGER", "reason is NO_GOLD_MANAGER")
	assert_true(not _service.build(&"W2", &"arrow"), "build refused")
	assert_true(not _service.sell(&"W1"), "sell refused")
	assert_true(not _service.upgrade(&"W1"), "upgrade refused")
	assert_true(_slot(&"W1").state == Enums.SlotState.OCCUPIED and _slot(&"W2").state == Enums.SlotState.EMPTY, "slots unchanged")
	add_child(_gold)
	assert_true(_service.get_upgrade_block_reason(&"W1") != &"NO_GOLD_MANAGER", "reason clears when the GoldManager is back")
	assert_true(_service.sell(&"W1"), "sell works again")

func test_wallet() -> void:
	print("\n[GROUP 21] Wallet: no interest, no cap, never negative")
	_reset()
	_gold.gold = 1000
	for state in [&"COMBAT", &"SUMMARY", &"PREP"]:
		EventBus.state_changed.emit(state)
	assert_true(_gold.gold == 1000, "BuildService adds no gold across a wave")
	_gold.add(1_000_000)
	assert_true(_gold.gold == 1_001_000, "no cap on the wallet")
	EventBus.run_started.emit()
	assert_true(_gold.gold == GameConfig.starting_gold, "run_started resets to the starting gold")
	var g := _gold.gold
	assert_true(not _gold.try_spend(g + 1), "cannot spend more than the wallet holds")
	assert_true(_gold.gold == g, "gold unchanged after the refused spend")
