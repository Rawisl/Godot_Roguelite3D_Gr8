extends Node3D

## Automated test runner for NavRebaker on the real corridor level:
## - both regions are found and bake from the shared source group
## - a ground build, sell, ruin and rubble clear each change the navigation mesh and restore it
## - a wall slot does not bake; several changes in one frame bake once per region
## - a change during a bake still ends on the right mesh
## - a sell or ruin made at the start of a frame is baked only after the tower is freed and the
##   rubble collider is on
## - the boss navigation mesh still reaches the Bulwark standing point past the bottleneck layout
## - NavRebaker outside a level does nothing
## Expected log noise: one WARNING per boss mesh bake (agent_radius is ceiled to cell_size).

const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")
const SLOTS_SCENE: PackedScene = preload("res://levels/corridor/slots_layout.tscn")
const ARROW: TowerData = preload("res://data/towers/arrow.tres")
const CANNON: TowerData = preload("res://data/towers/cannon.tres")
const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
const CANNON_SCENE: PackedScene = preload("res://entities/tower/cannon.tscn")

## Two adjacent cells of one column whose gap is narrower than a unit.
const GAP_A := &"G_4_1"
const GAP_B := &"G_4_2"
## The legal layout that leaves the narrowest lane for the boss.
const BOTTLENECK: Array[StringName] = [&"G_2_1", &"G_2_7", &"G_3_4"]
## The navigation mesh must be at least this far from the gap centre once the gap is built.
const GAP_CLEARANCE := 0.5
## The boss path must end this close to the standing point.
const BOSS_POINT_TOLERANCE := 0.3
const WAIT_FRAMES := 300
## Physics frames after a finished bake until the navigation map answers with the new mesh.
const MAP_SYNC_FRAMES := 10
const NORMAL_LAYER := 1

@export var quit_when_done := true

var passes := 0
var fails := 0

var _level: Node3D
var _rebaker: NavRebaker
var _service: BuildService
var _gold: GoldManager
var _normal: NavigationRegion3D
var _large: NavigationRegion3D
var _prebaked_normal := PackedVector3Array()
var _prebaked_large := PackedVector3Array()
var _rebaked_count := 0


func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED NAV REBAKE TEST                       ")
	print("=======================================================")

	await _setup()
	await test_regions_found()
	await test_empty_ground_matches_prebaked()
	await test_build_changes_navmesh()
	await test_sell_restores_navmesh()
	await test_ruin_and_clear_rubble()
	await test_wall_slot_does_not_bake()
	await test_changes_in_one_frame_bake_once()
	await test_change_during_bake()
	await test_sell_right_after_process_frame()
	await test_ruin_right_after_process_frame()
	await test_boss_reaches_standing_point()
	await test_without_level()

	print("\n=======================================================")
	print("  TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================")
	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("[PASS] ", test_name)
	else:
		fails += 1
		print("[FAIL] ", test_name)


# --- setup and helpers ---

func _setup() -> void:
	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	_gold = GoldManager.new()
	add_child(_gold)
	_service = BuildService.new()
	_service.towers = [ARROW, CANNON]
	_service.tower_scenes = {&"arrow": ARROW_SCENE, &"cannon": CANNON_SCENE}
	add_child(_service)
	_rebaker = _level.get_node("Slots/NavRebaker") as NavRebaker
	_rebaker.rebaked.connect(func(): _rebaked_count += 1)
	_normal = _level.get_node("NavigationRegion3D") as NavigationRegion3D
	_large = _level.get_node("NavigationRegionLarge") as NavigationRegion3D
	_prebaked_normal = _normal.navigation_mesh.get_vertices()
	_prebaked_large = _large.navigation_mesh.get_vertices()
	for i in 5:
		await get_tree().physics_frame
	_gold.gold = 1000000
	EventBus.state_changed.emit(&"PREP")


## Waits for the rebake to finish, then until the navigation map has the new mesh.
func _wait_rebake() -> bool:
	var waited := 0
	while not _rebaker.is_idle():
		if waited >= WAIT_FRAMES:
			return false
		await get_tree().physics_frame
		waited += 1
	for i in MAP_SYNC_FRAMES:
		await get_tree().physics_frame
	return true


func _slot(id: StringName) -> Slot:
	return _service.find_slot(id)


## Sells every ground tower and clears every rubble through the service, then waits for the bake.
func _clear_ground() -> void:
	for node in _level.get_node("Slots/GroundGrid").cells.values():
		var slot := node as Slot
		if slot.state == Enums.SlotState.OCCUPIED:
			_service.sell(slot.slot_id)
		elif slot.state == Enums.SlotState.RUINED:
			_service.clear_rubble(slot.slot_id)
	await _wait_rebake()


func _build(id: StringName) -> bool:
	return _service.build(id, &"arrow", 1)


func _normal_vertices() -> PackedVector3Array:
	return _normal.navigation_mesh.get_vertices()


func _large_vertices() -> PackedVector3Array:
	return _large.navigation_mesh.get_vertices()


func _gap_center() -> Vector3:
	return (_slot(GAP_A).global_position + _slot(GAP_B).global_position) * 0.5


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _map() -> RID:
	return _level.get_world_3d().navigation_map


# --- tests ---

func test_regions_found() -> void:
	print("\n--- Regions ---")
	assert_true(_rebaker._regions.size() == 2, "NavRebaker finds both navigation regions")
	var all_group := true
	for region in _rebaker._regions:
		if region.navigation_mesh.geometry_source_group_name != NavRebaker.SOURCE_GROUP:
			all_group = false
	assert_true(all_group, "both regions bake from the nav_source group")


func test_empty_ground_matches_prebaked() -> void:
	print("\n--- Empty ground bake matches the baked mesh ---")
	assert_true(_build(GAP_A), "build on a cell")
	assert_true(await _wait_rebake(), "rebake finished after the build")
	assert_true(_service.sell(GAP_A), "sell it again")
	assert_true(await _wait_rebake(), "rebake finished after the sell")
	assert_true(_normal_vertices() == _prebaked_normal, "normal mesh equals the baked one on empty ground")
	assert_true(_large_vertices() == _prebaked_large, "boss mesh equals the baked one on empty ground")
	assert_true(_rebaked_count > 0, "rebaked was emitted")


func test_build_changes_navmesh() -> void:
	print("\n--- Build closes the gap ---")
	assert_true(_build(GAP_A) and _build(GAP_B), "build both gap cells")
	assert_true(await _wait_rebake(), "rebake finished after the builds")
	assert_true(_normal_vertices() != _prebaked_normal, "normal mesh changed")
	assert_true(_large_vertices() != _prebaked_large, "boss mesh changed")
	assert_true(_slot(GAP_A).tower.is_in_group(NavRebaker.SOURCE_GROUP), "ground tower is a bake source")
	var center := _gap_center()
	var closest := NavigationServer3D.map_get_closest_point(_map(), center)
	assert_true(_flat_distance(closest, center) > GAP_CLEARANCE, "no navigable point near the gap centre (%.2f m)" % _flat_distance(closest, center))
	var path := NavigationServer3D.map_get_path(_map(), center + Vector3(6, 0, 0), center - Vector3(6, 0, 0), true, NORMAL_LAYER)
	var nearest := INF
	for point in path:
		nearest = minf(nearest, _flat_distance(point, center))
	assert_true(path.size() > 1 and nearest > GAP_CLEARANCE, "path across the gap goes around it (%.2f m)" % nearest)
	await _clear_ground()


func test_sell_restores_navmesh() -> void:
	print("\n--- Sell restores the mesh ---")
	assert_true(_build(GAP_A) and _build(GAP_B), "build both gap cells")
	await _wait_rebake()
	assert_true(_service.sell(GAP_A) and _service.sell(GAP_B), "sell both")
	assert_true(await _wait_rebake(), "rebake finished after the sells")
	assert_true(_normal_vertices() == _prebaked_normal, "normal mesh is back to the baked one")
	assert_true(_large_vertices() == _prebaked_large, "boss mesh is back to the baked one")


func test_ruin_and_clear_rubble() -> void:
	print("\n--- Rubble ---")
	assert_true(_build(GAP_A), "build a cell")
	await _wait_rebake()
	var slot := _slot(GAP_A)
	slot.ruin()
	assert_true(slot.state == Enums.SlotState.RUINED, "slot is RUINED")
	assert_true(await _wait_rebake(), "rebake finished after the ruin")
	assert_true(slot.rubble.is_in_group(NavRebaker.SOURCE_GROUP), "rubble is a bake source")
	assert_true(_normal_vertices() != _prebaked_normal, "normal mesh keeps a hole for the rubble")
	assert_true(_service.clear_rubble(GAP_A), "clear the rubble")
	assert_true(await _wait_rebake(), "rebake finished after the clear")
	assert_true(not slot.rubble.is_in_group(NavRebaker.SOURCE_GROUP), "rubble left the bake source group")
	assert_true(_normal_vertices() == _prebaked_normal, "normal mesh is back to the baked one")


func test_wall_slot_does_not_bake() -> void:
	print("\n--- Wall slot ---")
	var before := _rebaker.bake_count
	assert_true(_build(&"W1"), "build on a wall slot")
	for i in 10:
		await get_tree().physics_frame
	assert_true(_rebaker.bake_count == before, "no bake after a wall build")
	assert_true(_rebaker.is_idle(), "rebaker is idle")
	assert_true(not _slot(&"W1").tower.is_in_group(NavRebaker.SOURCE_GROUP), "wall tower is not a bake source")
	_service.sell(&"W1")
	await _wait_rebake()


func test_changes_in_one_frame_bake_once() -> void:
	print("\n--- Merged changes ---")
	await _clear_ground()
	var before := _rebaker.bake_count
	var built := 0
	for id in BOTTLENECK:
		if _build(id):
			built += 1
	assert_true(built == BOTTLENECK.size(), "three cells built in one frame")
	assert_true(await _wait_rebake(), "rebake finished")
	assert_true(_rebaker.bake_count - before == 2, "one bake per region (%d calls)" % (_rebaker.bake_count - before))


func test_change_during_bake() -> void:
	print("\n--- Change during a bake ---")
	await _clear_ground()
	assert_true(_build(GAP_A), "build a cell")
	for i in 2:
		await get_tree().process_frame
	assert_true(_service.sell(GAP_A), "sell it while the bake may still run")
	assert_true(await _wait_rebake(), "rebake finished")
	assert_true(_normal_vertices() == _prebaked_normal, "normal mesh ends on the empty-ground bake")
	assert_true(_large_vertices() == _prebaked_large, "boss mesh ends on the empty-ground bake")


func test_sell_right_after_process_frame() -> void:
	print("\n--- Sell at the start of a frame ---")
	await _clear_ground()
	assert_true(_build(GAP_A) and _build(GAP_B), "build both gap cells")
	assert_true(await _wait_rebake(), "rebake finished after the builds")
	await get_tree().process_frame
	assert_true(_service.sell(GAP_A) and _service.sell(GAP_B), "sell both right after a process frame")
	assert_true(await _wait_rebake(), "rebake finished after the sells")
	assert_true(_normal_vertices() == _prebaked_normal, "sold towers left no hole in the normal mesh")
	assert_true(_large_vertices() == _prebaked_large, "sold towers left no hole in the boss mesh")


func test_ruin_right_after_process_frame() -> void:
	print("\n--- Ruin at the start of a frame ---")
	await _clear_ground()
	assert_true(_build(GAP_A), "build a cell")
	assert_true(await _wait_rebake(), "rebake finished after the build")
	var slot := _slot(GAP_A)
	await get_tree().process_frame
	slot.ruin()
	assert_true(slot.state == Enums.SlotState.RUINED, "slot is RUINED")
	assert_true(await _wait_rebake(), "rebake finished after the ruin")
	assert_true(_normal_vertices() != _prebaked_normal, "rubble is carved out of the normal mesh")
	assert_true(_service.clear_rubble(GAP_A), "clear the rubble")
	assert_true(await _wait_rebake(), "rebake finished after the clear")
	assert_true(_normal_vertices() == _prebaked_normal, "normal mesh is back to the baked one")


func test_boss_reaches_standing_point() -> void:
	print("\n--- Boss path ---")
	await _clear_ground()
	var built := 0
	for id in BOTTLENECK:
		if _build(id):
			built += 1
	assert_true(built == BOTTLENECK.size(), "bottleneck layout built")
	assert_true(await _wait_rebake(), "rebake finished")
	var spawn := (_level.get_node("SpawnZone") as Node3D).global_position
	var goal := (get_tree().get_first_node_in_group(&"boss_melee_point") as Node3D).global_position
	var path := NavigationServer3D.map_get_path(_map(), spawn, goal, true, _large.navigation_layers)
	var gap := INF
	if not path.is_empty():
		gap = _flat_distance(path[path.size() - 1], goal)
	assert_true(gap <= BOSS_POINT_TOLERANCE, "boss path ends %.2f m from the standing point" % gap)
	await _clear_ground()


func test_without_level() -> void:
	print("\n--- Outside a level ---")
	# The level's slots share the slot group, so remove the level first.
	_level.free()
	var slots := SLOTS_SCENE.instantiate()
	add_child(slots)
	var lone := slots.get_node("NavRebaker") as NavRebaker
	await get_tree().process_frame
	assert_true(lone._regions.is_empty(), "no regions found")
	EventBus.slot_state_changed.emit(&"W1", &"OCCUPIED")
	EventBus.slot_state_changed.emit(GAP_A, &"OCCUPIED")
	for i in 3:
		await get_tree().physics_frame
	assert_true(lone.bake_count == 0, "no bake without a level")
	assert_true(lone.is_idle(), "idle without a level")
	slots.queue_free()
