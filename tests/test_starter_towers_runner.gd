extends Node

## Automated test runner verifying the starter towers:
## - the two starter slots exist and take their tower
## - the preplaced pair: level 1, full HP, no invested gold, no gold change, sale lock
## - while the first run tutorial waits: free starter type on its own slot, every other slot
##   locked, only the starter slots show a ring, Skip builds what is missing
## - a rebuilt tower is a normal tower; RunState records starter and ruined slots

const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")
const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const ARROW: TowerData = preload("res://data/towers/arrow.tres")
const CANNON: TowerData = preload("res://data/towers/cannon.tres")
const BARRICADE: TowerData = preload("res://data/towers/barricade.tres")
const HEAL_STATION: TowerData = preload("res://data/towers/heal_station.tres")
const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
const CANNON_SCENE: PackedScene = preload("res://entities/tower/cannon.tscn")
const BARRICADE_SCENE: PackedScene = preload("res://entities/tower/barricade.tscn")
const HEAL_STATION_SCENE: PackedScene = preload("res://entities/tower/heal_station.tscn")

## In-memory save so the runner never touches the real profile.
class StarterMemoryRepository extends SaveRepository:
	var envelope: Dictionary = {}

	func save_data(value: Dictionary) -> Error:
		envelope = value.duplicate(true)
		return OK

	func has_data() -> bool:
		return not envelope.is_empty()

	func load_data() -> Dictionary:
		last_error = ERR_FILE_NOT_FOUND if envelope.is_empty() else OK
		return envelope.duplicate(true)

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []

var _previous_repository: SaveRepository
var _previous_data: Dictionary
var _previous_can_write: bool
var _level: Node
var _gold: GoldManager
var _rs: RunState
var _service: BuildService
var _tutorial: TutorialService
var _built: Array = []
var _denied: Array = []
var _gold_changes := 0

func _ready() -> void:
	print("\n=======================================================")
	print("          AUTOMATED STARTER TOWERS RUNNER TEST          ")
	print("=======================================================")

	_setup()
	test_starter_slots_valid()
	test_place_starters_direct_call()
	test_run_state_passes_result()
	test_first_run_no_starters()
	test_tutorial_rings_only_on_starters()
	test_tutorial_free_only_matching_type()
	test_build_starter_guards()
	test_skip_after_arrow_builds_cannon_only()
	test_skip_builds_both()
	test_tutorial_ends_mid_run()
	test_start_wave_not_one()
	test_bad_slot_places_none()
	test_second_call_places_nothing()
	test_sell_locked_until_wave3()
	test_upgraded_starter_refund()
	test_rebuilt_starter_is_normal()
	test_rebuilt_tutorial_tower_is_normal()
	test_ruined_recorded_in_run_state()
	test_locale_key()
	await test_main_scene_wiring()

	_teardown()
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
	_previous_repository = SaveManager.repository
	_previous_data = SaveManager.data
	_previous_can_write = SaveManager.can_write
	SaveManager.set_repository(StarterMemoryRepository.new())
	SaveManager.data = SaveManager.DEFAULT_DATA.duplicate(true)
	SaveManager.can_write = true
	_build_fixture()
	EventBus.tower_built.connect(func(slot_id, type): _built.append([slot_id, type]))
	EventBus.build_denied.connect(func(reason, shortfall): _denied.append([reason, shortfall]))
	EventBus.gold_changed.connect(func(_gold_value): _gold_changes += 1)

func _teardown() -> void:
	SaveManager.repository = _previous_repository
	SaveManager.data = _previous_data
	SaveManager.can_write = _previous_can_write

## Level, gold, run state, build service and tutorial in the order main.tscn adds them.
func _build_fixture() -> void:
	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	_gold = GoldManager.new()
	add_child(_gold)
	_rs = RunState.new()
	add_child(_rs)
	_service = BuildService.new()
	_service.towers = [ARROW, CANNON, BARRICADE, HEAL_STATION]
	_service.tower_scenes = {
		&"arrow": ARROW_SCENE,
		&"cannon": CANNON_SCENE,
		&"barricade": BARRICADE_SCENE,
		&"heal_station": HEAL_STATION_SCENE,
	}
	add_child(_service)
	_tutorial = TutorialService.new()
	add_child(_tutorial)

func _free_fixture() -> void:
	for node in [_tutorial, _service, _rs, _gold, _level]:
		remove_child(node)
		node.free()

## Empty slots, a new run in PREP, and no recorded events.
func _new_run(tutorial_done: bool, start_wave := 1) -> void:
	for node in get_tree().get_nodes_in_group(&"slot"):
		(node as Slot).set_state(Enums.SlotState.EMPTY)
	SaveManager.get_section(SaveManager.FLAGS)["tutorial_done"] = tutorial_done
	_rs.start_wave = start_wave
	_rs.wave_index = start_wave
	_rs.is_starter.clear()
	_rs.ruined_type.clear()
	_rs.ruined_level.clear()
	_gold.gold = GameConfig.starting_gold
	EventBus.run_started.emit()
	EventBus.state_changed.emit(&"PREP")
	_clear_events()

func _clear_events() -> void:
	_built.clear()
	_denied.clear()
	_gold_changes = 0

func _slot(id: StringName) -> Slot:
	return _service.find_slot(id)

func _arrow_slot() -> Slot:
	return _slot(GameConfig.starter_arrow_slot)

func _cannon_slot() -> Slot:
	return _slot(GameConfig.starter_cannon_slot)

## First GROUND slot (by id) that is not the Arrow starter slot.
func _other_ground_slot() -> Slot:
	return _first_slot(Enums.SlotZone.GROUND, GameConfig.starter_arrow_slot)

## First WALL slot (by id) that is not the Cannon starter slot.
func _other_wall_slot() -> Slot:
	return _first_slot(Enums.SlotZone.WALL, GameConfig.starter_cannon_slot)

func _first_slot(zone: Enums.SlotZone, except_id: StringName) -> Slot:
	var found: Array[Slot] = []
	for node in get_tree().get_nodes_in_group(&"slot"):
		var slot := node as Slot
		if slot != null and slot.zone == zone and slot.slot_id != except_id:
			found.append(slot)
	found.sort_custom(func(a: Slot, b: Slot): return String(a.slot_id) < String(b.slot_id))
	return found[0] if not found.is_empty() else null

func _occupied_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(&"slot"):
		if (node as Slot).state == Enums.SlotState.OCCUPIED:
			count += 1
	return count

func _free_options(options: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in options:
		if entry["locked_reason"] == &"":
			out.append(entry)
	return out

func _all_locked_tutorial(options: Array[Dictionary]) -> bool:
	if options.is_empty():
		return false
	for entry in options:
		if entry["locked_reason"] != BuildService.TUTORIAL_LOCKED or entry["rebuild"]:
			return false
	return true

func _unlock_commander() -> void:
	EventBus.level_up.emit(100, 0)

func _tutorial_done() -> bool:
	return bool(SaveManager.get_section(SaveManager.FLAGS).get("tutorial_done", false))

func test_starter_slots_valid() -> void:
	print("\n[GROUP 1] Starter slots exist and take their tower")
	_new_run(true)
	var arrow_slot := _arrow_slot()
	assert_true(arrow_slot != null, "the Arrow starter slot exists")
	if arrow_slot != null:
		var grid := arrow_slot.get_parent() as GroundGrid
		assert_true(arrow_slot.is_ground() and arrow_slot.allows(ARROW), "the Arrow starter slot is a ground slot that allows Arrow")
		assert_true(grid != null and GridData.cell_of(arrow_slot.slot_id).y == grid.grid_data.middle_row(), "the Arrow starter slot is on the middle row")
	var cannon_slot := _cannon_slot()
	assert_true(cannon_slot != null, "the Cannon starter slot exists")
	if cannon_slot != null:
		assert_true(cannon_slot.zone == Enums.SlotZone.WALL and cannon_slot.allows(CANNON), "the Cannon starter slot is a wall slot that allows Cannon")

func test_place_starters_direct_call() -> void:
	print("\n[GROUP 2] place_starter_towers before the first PREP")
	_new_run(true)
	EventBus.state_changed.emit(&"")
	var gold_before := _gold.gold
	_clear_events()
	assert_true(_service.place_starter_towers(), "place_starter_towers returns true")
	var arrow_tower := _arrow_slot().tower
	var cannon_tower := _cannon_slot().tower
	assert_true(arrow_tower != null and arrow_tower.data.id == &"arrow" and arrow_tower.level == 1, "a level 1 Arrow stands on its slot")
	assert_true(cannon_tower != null and cannon_tower.data.id == &"cannon" and cannon_tower.level == 1, "a level 1 Cannon stands on its slot")
	if arrow_tower == null or cannon_tower == null:
		return
	assert_true(arrow_tower.invested_gold == 0 and cannon_tower.invested_gold == 0, "both towers have no invested gold")
	assert_true(arrow_tower.is_starter and cannon_tower.is_starter, "both towers are starter towers")
	assert_true(is_equal_approx(arrow_tower.health.hp, arrow_tower.health.max_hp) and is_equal_approx(cannon_tower.health.hp, cannon_tower.health.max_hp), "both towers have full HP")
	assert_true(arrow_tower.priority == ARROW.default_priority and cannon_tower.priority == CANNON.default_priority, "both towers have their default priority")
	assert_true(_gold.gold == gold_before and _gold.gold == GameConfig.starting_gold, "no gold is spent")
	assert_true(_gold_changes == 0, "no gold_changed is sent")
	assert_true(_built == [[GameConfig.starter_arrow_slot, &"arrow"], [GameConfig.starter_cannon_slot, &"cannon"]], "tower_built is sent for the Arrow, then the Cannon")
	assert_true(_service.get_ground_used() == 1, "one ground slot is used")
	assert_true(_rs.is_starter.get(GameConfig.starter_arrow_slot, false) and _rs.is_starter.get(GameConfig.starter_cannon_slot, false), "RunState records both starter slots")

func test_run_state_passes_result() -> void:
	print("\n[GROUP 3] RunState passes the result of the placement")
	_new_run(true)
	assert_true(_rs.place_starter_towers() == true, "RunState reports true when both towers were placed")
	assert_true(_occupied_count() == 2, "two towers stand")
	print("  [EXPECTED] one push_error line from BuildService follows")
	assert_true(_rs.place_starter_towers() == false, "RunState reports false when the slots are taken")

func test_first_run_no_starters() -> void:
	print("\n[GROUP 4] First run: nothing preplaced, the menu is locked")
	_new_run(false)
	assert_true(not _service.place_starter_towers(), "nothing is placed before the tutorial is done")
	assert_true(_arrow_slot().state == Enums.SlotState.EMPTY and _cannon_slot().state == Enums.SlotState.EMPTY, "both starter slots stay empty")
	assert_true(_service.is_tutorial_pending(), "the tutorial is pending")
	var options := _service.get_build_options(GameConfig.starter_arrow_slot)
	var free := _free_options(options)
	assert_true(free.size() == 1 and free[0]["data"].id == &"arrow" and free[0]["cost"] == 0 and free[0]["shortfall"] == 0, "the Arrow slot offers a free Arrow")
	assert_true(options.size() > 1 and options.size() - 1 == options.filter(func(e): return e["locked_reason"] == BuildService.TUTORIAL_LOCKED).size(), "every other entry of the Arrow slot is locked by the tutorial")
	options = _service.get_build_options(GameConfig.starter_cannon_slot)
	free = _free_options(options)
	assert_true(free.size() == 1 and free[0]["data"].id == &"cannon" and free[0]["cost"] == 0, "the Cannon slot offers a free Cannon")
	assert_true(options.size() > 1 and options.size() - 1 == options.filter(func(e): return e["locked_reason"] == BuildService.TUTORIAL_LOCKED).size(), "every other entry of the Cannon slot is locked by the tutorial")
	assert_true(_all_locked_tutorial(_service.get_build_options(_other_ground_slot().slot_id)), "another ground slot is locked by the tutorial")
	assert_true(_all_locked_tutorial(_service.get_build_options(_other_wall_slot().slot_id)), "another wall slot is locked by the tutorial")

func test_tutorial_rings_only_on_starters() -> void:
	print("\n[GROUP 5] Only the starter slots show a ring")
	_new_run(false)
	var ok := true
	for node in get_tree().get_nodes_in_group(&"slot"):
		var slot := node as Slot
		var is_starter_slot := _service.get_starter_type(slot.slot_id) != &""
		ok = ok and slot.marker.visible == is_starter_slot
	assert_true(ok, "in PREP the ring shows on the two starter slots only")
	get_tree().call_group(&"slot", &"set_buildable_visible", true)
	ok = true
	for node in get_tree().get_nodes_in_group(&"slot"):
		var slot := node as Slot
		ok = ok and slot.marker.visible == (_service.get_starter_type(slot.slot_id) != &"")
	assert_true(ok, "turning every ring on again still leaves only the starter slots lit")
	SaveManager.mark_tutorial_done()
	ok = true
	for node in get_tree().get_nodes_in_group(&"slot"):
		var slot := node as Slot
		ok = ok and slot.marker.visible == slot.is_free()
	assert_true(ok, "when the tutorial is done every empty slot shows its ring")

func test_tutorial_free_only_matching_type() -> void:
	print("\n[GROUP 6] During the tutorial only the matching type builds, free")
	_new_run(false)
	_gold.gold = 5000
	assert_true(not _service.build(GameConfig.starter_arrow_slot, &"cannon"), "a Cannon on the Arrow slot is refused")
	assert_true(_denied.back() == [BuildService.TUTORIAL_LOCKED, 0], "the refusal carries the tutorial reason")
	_denied.clear()
	assert_true(not _service.build(_other_ground_slot().slot_id, &"arrow"), "an Arrow on another slot is refused")
	assert_true(_denied.back() == [BuildService.TUTORIAL_LOCKED, 0], "the other slot gets the tutorial reason")
	assert_true(not _service.build(GameConfig.starter_arrow_slot, &"arrow", 2), "level 2 of the starter type is refused")
	var gold_before := _gold.gold
	assert_true(_service.build(GameConfig.starter_arrow_slot, &"arrow"), "the Arrow on the Arrow slot builds")
	var tower := _arrow_slot().tower
	assert_true(_gold.gold == gold_before, "it costs nothing")
	assert_true(tower != null and tower.invested_gold == 0 and tower.is_starter, "it has no invested gold and is a starter tower")
	assert_true(_tutorial.step == TutorialService.BUILD_CANNON, "the tutorial moves on to the Cannon")

func test_build_starter_guards() -> void:
	print("\n[GROUP 7] build_starter only runs for the tutorial, in PREP, on its own slot")
	_new_run(false)
	assert_true(not _service.build_starter(_other_ground_slot().slot_id, &"arrow"), "an Arrow on another slot is refused")
	assert_true(not _service.build_starter(GameConfig.starter_arrow_slot, &"cannon"), "a Cannon on the Arrow slot is refused")
	EventBus.state_changed.emit(&"COMBAT")
	assert_true(not _service.build_starter(GameConfig.starter_arrow_slot, &"arrow"), "it is refused outside PREP")
	EventBus.state_changed.emit(&"PREP")
	_new_run(true)
	assert_true(not _service.build_starter(GameConfig.starter_arrow_slot, &"arrow"), "it is refused once the tutorial is done")
	assert_true(_occupied_count() == 0, "no tower was placed")

func test_skip_after_arrow_builds_cannon_only() -> void:
	print("\n[GROUP 8] Skip after the Arrow builds only the Cannon")
	_new_run(false)
	_gold.gold = 5000
	_service.build(GameConfig.starter_arrow_slot, &"arrow")
	var arrow_tower := _arrow_slot().tower
	var gold_before := _gold.gold
	_tutorial.skip()
	var cannon_tower := _cannon_slot().tower
	assert_true(cannon_tower != null and cannon_tower.is_starter and cannon_tower.invested_gold == 0, "a free starter Cannon is built")
	assert_true(_occupied_count() == 2, "exactly two slots are occupied")
	assert_true(_arrow_slot().tower == arrow_tower, "the Arrow is the same tower as before")
	assert_true(_tutorial_done(), "tutorial_done is saved")
	assert_true(_gold.gold == gold_before, "gold is unchanged")

func test_skip_builds_both() -> void:
	print("\n[GROUP 9] Skip at the start builds both towers")
	_new_run(false)
	_tutorial.skip()
	assert_true(_arrow_slot().tower != null and _arrow_slot().tower.is_starter and _cannon_slot().tower != null and _cannon_slot().tower.is_starter, "both starter towers stand")
	assert_true(_tutorial_done(), "tutorial_done is saved")
	assert_true(_tutorial.step == TutorialService.OFF, "the tutorial is off")

func test_tutorial_ends_mid_run() -> void:
	print("\n[GROUP 10] When both towers stand the rest unlocks")
	_new_run(false)
	_gold.gold = 5000
	_service.build(GameConfig.starter_arrow_slot, &"arrow")
	_service.build(GameConfig.starter_cannon_slot, &"cannon")
	assert_true(_tutorial_done() and not _service.is_tutorial_pending(), "the tutorial is done and no longer pending")
	var other := _other_ground_slot()
	var options := _service.get_build_options(other.slot_id)
	var locked := options.filter(func(e): return e["locked_reason"] == BuildService.TUTORIAL_LOCKED)
	assert_true(locked.is_empty(), "no entry is locked by the tutorial")
	var arrow_entry := options.filter(func(e): return e["data"].id == &"arrow")
	assert_true(arrow_entry.size() == 1 and arrow_entry[0]["cost"] == ARROW.get_total_cost(1), "the Arrow costs its normal price")
	assert_true(_service.build(other.slot_id, &"arrow"), "another slot builds an Arrow")
	assert_true(other.tower != null and not other.tower.is_starter, "that tower is not a starter tower")

func test_start_wave_not_one() -> void:
	print("\n[GROUP 11] A later start wave has no starters and no tutorial")
	_new_run(true, GameConfig.starter_sell_unlock_wave + 2)
	assert_true(not _service.place_starter_towers(), "nothing is placed")
	assert_true(_arrow_slot().state == Enums.SlotState.EMPTY and _cannon_slot().state == Enums.SlotState.EMPTY, "both starter slots stay empty")
	_new_run(false, GameConfig.starter_sell_unlock_wave + 2)
	assert_true(not _service.is_tutorial_pending(), "the tutorial is not pending after wave 1")

func test_bad_slot_places_none() -> void:
	print("\n[GROUP 12] A slot that cannot take its tower places none")
	print("  [EXPECTED] two push_error lines from BuildService follow")
	_new_run(true)
	var cannon_id := GameConfig.starter_cannon_slot
	GameConfig.starter_cannon_slot = &"W_MISSING"
	var result := _service.place_starter_towers()
	GameConfig.starter_cannon_slot = cannon_id
	assert_true(not result, "a missing Cannon slot refuses the pair")
	assert_true(_arrow_slot().state == Enums.SlotState.EMPTY, "the Arrow slot stays empty")
	_new_run(true)
	_gold.gold = 5000
	assert_true(_service.build(GameConfig.starter_arrow_slot, &"barricade"), "a normal Barricade builds on the Arrow slot")
	var barricade := _arrow_slot().tower
	assert_true(not _service.place_starter_towers(), "a taken Arrow slot refuses the pair")
	assert_true(_cannon_slot().state == Enums.SlotState.EMPTY, "the Cannon slot stays empty")
	assert_true(_arrow_slot().tower == barricade, "the Barricade is still the same tower")

func test_second_call_places_nothing() -> void:
	print("\n[GROUP 13] A second call places nothing")
	_new_run(true)
	print("  [EXPECTED] one push_error line from BuildService follows")
	var first := _service.place_starter_towers()
	var gold_before := _gold.gold
	var second := _service.place_starter_towers()
	assert_true(first and not second, "the first call works and the second returns false")
	assert_true(_occupied_count() == 2, "still exactly two slots are occupied")
	assert_true(_gold.gold == gold_before, "gold is unchanged")

func test_sell_locked_until_wave3() -> void:
	print("\n[GROUP 14] The starter towers cannot be sold before the unlock wave")
	_new_run(true)
	_service.place_starter_towers()
	var unlock := GameConfig.starter_sell_unlock_wave
	for wave in range(1, unlock):
		_rs.wave_index = wave
		EventBus.state_changed.emit(&"PREP")
		_denied.clear()
		assert_true(_service.get_sell_locked_until_wave(GameConfig.starter_arrow_slot) == unlock, "wave %d: the sale is locked until wave %d" % [wave, unlock])
		assert_true(not _service.sell(GameConfig.starter_arrow_slot), "wave %d: the sale is refused" % wave)
		assert_true(_denied.back() == [BuildService.STARTER_LOCKED, 0], "wave %d: the refusal carries the lock reason" % wave)
		assert_true(_arrow_slot().tower != null, "wave %d: the tower stays" % wave)
	_rs.wave_index = unlock
	var gold_before := _gold.gold
	assert_true(_service.get_sell_locked_until_wave(GameConfig.starter_arrow_slot) == 0, "at the unlock wave the lock is gone")
	assert_true(_service.sell(GameConfig.starter_arrow_slot), "the sale goes through")
	assert_true(_gold.gold == gold_before, "a preplaced tower refunds nothing")
	assert_true(_service.get_sell_locked_until_wave(GameConfig.starter_arrow_slot) == 0, "an empty slot has no lock")
	assert_true(not _rs.is_starter.has(GameConfig.starter_arrow_slot), "RunState forgets the sold slot")

func test_upgraded_starter_refund() -> void:
	print("\n[GROUP 15] An upgraded starter refunds only what was paid")
	_new_run(true)
	_service.place_starter_towers()
	_unlock_commander()
	_rs.wave_index = GameConfig.starter_sell_unlock_wave
	var cost: int = ARROW.levels[1].build_cost
	_gold.gold = cost
	assert_true(_service.upgrade(GameConfig.starter_arrow_slot), "the Arrow upgrades")
	var gold_before := _gold.gold
	assert_true(_service.sell(GameConfig.starter_arrow_slot), "it sells")
	assert_true(_gold.gold - gold_before == floori(cost * GameConfig.sell_refund_pct), "the refund is the sale percentage of the upgrade price")

func test_rebuilt_starter_is_normal() -> void:
	print("\n[GROUP 16] A rebuilt starter is a normal tower")
	_new_run(true)
	_service.place_starter_towers()
	_arrow_slot().ruin()
	_rs.wave_index = 2
	EventBus.state_changed.emit(&"PREP")
	var cost := ARROW.get_total_cost(1)
	_gold.gold = cost
	assert_true(_service.build(GameConfig.starter_arrow_slot, &"arrow", 1), "the Arrow is rebuilt")
	var tower := _arrow_slot().tower
	assert_true(_gold.gold == 0, "it is paid for")
	assert_true(tower != null and not tower.is_starter and tower.invested_gold == cost, "it is not a starter tower and has its price invested")
	assert_true(_service.get_sell_locked_until_wave(GameConfig.starter_arrow_slot) == 0, "it is not sale locked")
	assert_true(_service.sell(GameConfig.starter_arrow_slot), "it sells at once")
	assert_true(_gold.gold == floori(cost * GameConfig.sell_refund_pct), "it refunds the sale percentage")

func test_rebuilt_tutorial_tower_is_normal() -> void:
	print("\n[GROUP 17] A rebuilt tutorial tower is a normal tower")
	_new_run(false)
	_gold.gold = 5000
	_service.build(GameConfig.starter_arrow_slot, &"arrow")
	_service.build(GameConfig.starter_cannon_slot, &"cannon")
	assert_true(_tutorial_done(), "the tutorial is done")
	_arrow_slot().ruin()
	var cost := ARROW.get_total_cost(1)
	_gold.gold = cost
	assert_true(_service.build(GameConfig.starter_arrow_slot, &"arrow"), "the Arrow is rebuilt")
	var tower := _arrow_slot().tower
	assert_true(tower != null and not tower.is_starter and tower.invested_gold == cost, "it is not a starter tower and has its price invested")
	assert_true(_service.sell(GameConfig.starter_arrow_slot), "it sells at once")

func test_ruined_recorded_in_run_state() -> void:
	print("\n[GROUP 18] RunState records ruined slots")
	_new_run(true)
	_gold.gold = 5000
	_unlock_commander()
	var slot := _other_ground_slot()
	var id := slot.slot_id
	assert_true(_service.build(id, &"arrow") and _service.upgrade(id), "an Arrow is built and upgraded")
	slot.ruin()
	assert_true(_rs.ruined_type.get(id) == &"arrow" and _rs.ruined_level.get(id) == 2, "ruin records the type and the level")
	assert_true(_service.clear_rubble(id), "the rubble is cleared")
	assert_true(not _rs.ruined_type.has(id) and not _rs.ruined_level.has(id), "clearing removes both records")
	_gold.gold = 5000
	_service.build(id, &"arrow")
	slot.ruin()
	assert_true(_service.build(id, &"barricade"), "another type is built on the rubble")
	assert_true(not _rs.ruined_type.has(id) and not _rs.ruined_level.has(id), "building over the rubble removes both records")
	_new_run(true)
	_service.place_starter_towers()
	assert_true(_rs.is_starter.has(GameConfig.starter_arrow_slot), "the starter Arrow is recorded")
	_arrow_slot().ruin()
	assert_true(not _rs.is_starter.has(GameConfig.starter_arrow_slot), "a ruined starter is no longer recorded as one")

func test_locale_key() -> void:
	print("\n[GROUP 19] The tutorial lock text is in the locale file")
	var file := FileAccess.open("res://data/locale/strings.csv", FileAccess.READ)
	var found := false
	if file != null:
		while not file.eof_reached():
			if file.get_line().begins_with("panel.build.tutorial,"):
				found = true
				break
	assert_true(found, "panel.build.tutorial has a line in strings.csv")

func test_main_scene_wiring() -> void:
	print("\n[GROUP 20] The main scene places the starters")
	_free_fixture()
	await get_tree().process_frame
	await get_tree().process_frame
	SaveManager.get_section(SaveManager.FLAGS)["tutorial_done"] = true
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var rs := get_tree().get_first_node_in_group(&"run_state") as RunState
	assert_true(rs != null and rs.start_wave == 1, "main.tscn has a RunState starting at wave 1")
	if rs != null:
		assert_true(rs.place_starter_towers() == true, "the RunState of main places the starters")
	var arrow_slot: Slot = null
	var cannon_slot: Slot = null
	for node in get_tree().get_nodes_in_group(&"slot"):
		var slot := node as Slot
		if slot.slot_id == GameConfig.starter_arrow_slot:
			arrow_slot = slot
		elif slot.slot_id == GameConfig.starter_cannon_slot:
			cannon_slot = slot
	assert_true(arrow_slot != null and arrow_slot.state == Enums.SlotState.OCCUPIED and arrow_slot.tower.is_starter, "the Arrow stands on its slot in main")
	assert_true(cannon_slot != null and cannon_slot.state == Enums.SlotState.OCCUPIED and cannon_slot.tower.is_starter, "the Cannon stands on its slot in main")
	main.queue_free()
	await get_tree().process_frame
	_build_fixture()
