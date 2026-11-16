extends Node3D

## Automated test for the cost of six top level towers:
## - three WALL and three GROUND towers (Arrow and Cannon alternating) upgraded to the top level
## - max_alive Grunts standing along the lane
## - the scan of all six towers in one physics frame stays under the budget (median of many batches)
## - at x3 the towers still fire; the physics time per frame is printed, not asserted

const SLOT_SCENE: PackedScene = preload("res://systems/build/slot.tscn")
const ARROW: TowerData = preload("res://data/towers/arrow.tres")
const CANNON: TowerData = preload("res://data/towers/cannon.tres")
const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
const CANNON_SCENE: PackedScene = preload("res://entities/tower/cannon.tscn")
const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const POOL_SCENE: PackedScene = preload("res://entities/projectile/projectile_pool.tscn")

## Target for the scan of all six towers landing in one physics frame.
const SCAN_BUDGET_MS := 1.0
const BATCHES := 30
const FRAMES_PER_BATCH := 10
const X3_FRAMES := 180
const LANE_X_MIN := -9.0
const LANE_X_MAX := 18.0
const LANE_Z := 6.0
const SEED := 8

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes := 0
var fails := 0
var _gold: GoldManager
var _service: BuildService
var _towers: Array[Tower] = []
var _shots := 0


func _ready() -> void:
	print("\n[tower perf] start")
	_setup()
	# GoldManager resets itself on a deferred call; let it land before gold is set by hand.
	await get_tree().process_frame
	_build_towers()
	_spawn_enemies()
	for i in 5:
		await get_tree().physics_frame
	test_scan_cost()
	await test_x3_run()
	print("[tower perf] done: %d passed, %d failed" % [passes, fails])
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, label: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % label)
	else:
		fails += 1
		printerr("  [FAIL] %s" % label)


#region Setup
func _setup() -> void:
	add_child(POOL_SCENE.instantiate())
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child(floor_body)
	_gold = GoldManager.new()
	add_child(_gold)
	_service = BuildService.new()
	_service.towers = [ARROW, CANNON]
	_service.tower_scenes = {&"arrow": ARROW_SCENE, &"cannon": CANNON_SCENE}
	add_child(_service)
	_make_slot(&"W1", Enums.SlotZone.WALL, Vector3(-16, 0, -6))
	_make_slot(&"W2", Enums.SlotZone.WALL, Vector3(-16, 0, 0))
	_make_slot(&"W3", Enums.SlotZone.WALL, Vector3(-16, 0, 6))
	_make_slot(&"G1", Enums.SlotZone.GROUND, Vector3(-13, 0, -10))
	_make_slot(&"G2", Enums.SlotZone.GROUND, Vector3(-13, 0, -7.5))
	_make_slot(&"G3", Enums.SlotZone.GROUND, Vector3(-13, 0, 7.5))
	EventBus.run_started.emit()
	EventBus.state_changed.emit(&"PREP")
	EventBus.level_up.emit(GameConfig.tower_gate_tier3, 0)


func _make_slot(id: StringName, zone: Enums.SlotZone, pos: Vector3) -> void:
	var slot := SLOT_SCENE.instantiate() as Slot
	slot.name = String(id)
	slot.slot_id = id
	slot.zone = zone
	add_child(slot)
	slot.global_position = pos


## Arrow and Cannon alternate, so all six towers scan and shoot.
func _build_towers() -> void:
	_gold.gold = 10000000
	var plan := [[&"W1", &"arrow"], [&"W2", &"cannon"], [&"W3", &"arrow"], [&"G1", &"cannon"], [&"G2", &"arrow"], [&"G3", &"cannon"]]
	var all_top := true
	for p in plan:
		var slot_id: StringName = p[0]
		if not _service.build(slot_id, p[1]):
			all_top = false
			continue
		var t := _service.find_slot(slot_id).tower
		while t.level < GameConfig.tower_max_level and _service.upgrade(slot_id):
			pass
		all_top = all_top and t.level == GameConfig.tower_max_level
		_towers.append(t)
	assert_true(_towers.size() == 6 and all_top, "six towers at the top level")


## Grunts that stay where they are put (no AI, no grace), spread along the lane.
func _spawn_enemies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in GameConfig.max_alive:
		var g := GRUNT_SCENE.instantiate() as Enemy
		g.position = Vector3(rng.randf_range(LANE_X_MIN, LANE_X_MAX), 0, rng.randf_range(-LANE_Z, LANE_Z))
		add_child(g)
		g.set_physics_process(false)
		g.spawn_grace = false
		g.is_in_spawn_zone = false
#endregion


func test_scan_cost() -> void:
	print("\n[GROUP 1] Scan of six top level towers in one frame")
	var in_range := []
	var every_tower_sees := true
	for t in _towers:
		var n := t.range_area.get_overlapping_bodies().size()
		in_range.append(n)
		every_tower_sees = every_tower_sees and n > 0
	print("  enemies in range per tower: %s of %d" % [in_range, GameConfig.max_alive])
	assert_true(every_tower_sees, "every tower has at least one enemy in range")
	var samples: Array[float] = []
	for b in BATCHES:
		var start := Time.get_ticks_usec()
		for f in FRAMES_PER_BATCH:
			for t in _towers:
				t._scan()
		samples.append(float(Time.get_ticks_usec() - start) / 1000.0 / FRAMES_PER_BATCH)
	samples.sort()
	var median := samples[samples.size() / 2]
	print("  scan cost per frame: median %.3f ms, worst batch %.3f ms" % [median, samples[-1]])
	assert_true(median < SCAN_BUDGET_MS, "median scan cost %.3f ms is under %.1f ms per frame" % [median, SCAN_BUDGET_MS])


func test_x3_run() -> void:
	print("\n[GROUP 2] Towers at x3")
	for t in _towers:
		t.shot_released.connect(func(_pos, _target): _shots += 1)
	TimeManager.set_time_scale(3)
	var total := 0.0
	var worst := 0.0
	for i in X3_FRAMES:
		await get_tree().physics_frame
		var ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		total += ms
		worst = maxf(worst, ms)
	TimeManager.reset_time_scale()
	print("  physics time per frame at x3: mean %.2f ms, max %.2f ms (shots: %d)" % [total / X3_FRAMES, worst, _shots])
	assert_true(_shots > 0, "towers at the top level fire at x3")
