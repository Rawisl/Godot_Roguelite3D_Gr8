extends Node3D
## The Bulwark on the real corridor reaches the Fortress past three ground buildings:
## - no grid cell has its nearest point closer than boss_point_clear_radius to boss_melee_point
## - the tightest legal layout of three cells within 10 m of boss_melee_point (the one refused
##   first when the path check asks for more width) gets a Barricade on each cell
## - a wave 5 Bulwark, with nothing that can hurt it, walks on the large-agent navmesh, stops
##   within 0.3 m of boss_melee_point without reaching stuck tier 2 or 3, faces the Fortress and
##   its first Stomp there lowers the Fortress HP; it never takes a Fortress melee slot
## Run at x1 and at x3. Not shipped. Headless: prints a summary and quits.

const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")
const BULWARK_SCENE: PackedScene = preload("res://entities/enemy/bulwark.tscn")
const BARRICADE: TowerData = preload("res://data/towers/barricade.tres")
const BARRICADE_SCENE: PackedScene = preload("res://entities/tower/barricade.tscn")
const SCALE_CONFIG: ScaleConfig = preload("res://data/config/scale_config.tres")
const NEAR_POINT := 10.0
const TIGHT_MARGINS: Array[float] = [0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0]
const STOP_TOLERANCE := 0.3
const WAVE := 5
## Game seconds the boss gets to land its first Stomp on the Fortress.
const TIME_LIMIT := 240.0
const WAIT_FRAMES := 300
const MAP_SYNC_FRAMES := 10

var _pass := 0
var _fail := 0
var _level: Node3D
var _service: BuildService
var _rebaker: NavRebaker
var _grid: GroundGrid


func _ready() -> void:
	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	var gold := GoldManager.new()
	add_child(gold)
	_service = BuildService.new()
	_service.towers = [BARRICADE]
	_service.tower_scenes = {&"barricade": BARRICADE_SCENE}
	add_child(_service)
	_rebaker = _level.get_node("Slots/NavRebaker") as NavRebaker
	_grid = _level.get_node("Slots/GroundGrid") as GroundGrid
	for i in 5:
		await get_tree().physics_frame
	gold.gold = 1000000
	EventBus.state_changed.emit(&"PREP")

	_check_clear_zone()
	var layout: Array = _tightest_near_layout()
	_check("found a legal three-cell layout near boss_melee_point", layout.size() == 3)
	if layout.size() == 3:
		for speed in [1, 3]:
			await _build_layout(layout)
			EventBus.state_changed.emit(&"COMBAT")
			await _run_boss(speed)

	TimeManager.reset_time_scale()
	print("BULWARK TO FORTRESS: %d PASSED, %d FAILED" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("  [PASS] ", label)
	else:
		_fail += 1
		print("  [FAIL] ", label)


func _check_clear_zone() -> void:
	var point := _grid.get_boss_point()
	var radius := GameConfig.boss_point_clear_radius
	var closest := INF
	for c in _grid.get_valid_cells():
		var node := _grid.cells.get(GridData.cell_id(c.x, c.y)) as Node3D
		if node == null:
			continue
		var center := node.global_position
		var half := GameConfig.grid_cell_size * 0.5
		var dx := maxf(absf(point.x - center.x) - half, 0.0)
		var dz := maxf(absf(point.z - center.z) - half, 0.0)
		closest = minf(closest, Vector2(dx, dz).length())
	_check("no grid cell within %.1f m of boss_melee_point (closest %.2f m)" % [radius, closest], closest >= radius - 0.001)


## Legal layouts of three cells near the point; the first refused when the check asks for more width.
func _tightest_near_layout() -> Array:
	var data := _grid.grid_data
	var point := _grid.get_boss_point()
	var spawn := _grid.spawn_zone.global_position
	var gate := _gate()
	var width := GameConfig.path_check_min_width
	var near: Array[Vector2i] = []
	for c in _grid.get_valid_cells():
		var node := _grid.cells.get(GridData.cell_id(c.x, c.y)) as Node3D
		if node != null and Vector2(node.global_position.x - point.x, node.global_position.z - point.z).length() <= NEAR_POINT:
			near.append(c)
	var goals: Array[Vector3] = [data.gate_goal(gate, width), point]
	var legal: Array = []
	for i in near.size():
		for j in range(i + 1, near.size()):
			for k in range(j + 1, near.size()):
				var obstacles: Array[Vector2i] = [near[i], near[j], near[k]]
				if data.is_path_open(obstacles, spawn, gate, goals, width):
					legal.append(obstacles)
	print("[layout] %d cells near the point, %d legal layouts" % [near.size(), legal.size()])
	if legal.is_empty():
		return []
	for margin in TIGHT_MARGINS:
		var w := width + margin
		var wide_goals: Array[Vector3] = [data.gate_goal(gate, w), point]
		for obstacles: Array[Vector2i] in legal:
			if not data.is_path_open(obstacles, spawn, gate, wide_goals, w):
				print("[layout] tightest: %s (refused with %.1f m more width)" % [obstacles, margin])
				return obstacles
	return legal[0]


func _run_boss(speed: int) -> void:
	print("\n[x%d]" % speed)
	TimeManager.set_time_scale(speed)
	var fortress := get_tree().get_first_node_in_group(&"fortress") as Node3D
	var fortress_health := fortress.get(&"health") as HealthComponent
	var point := _grid.get_boss_point()
	var boss := BULWARK_SCENE.instantiate() as Enemy
	var start := _grid.spawn_zone.global_position
	start.y = 0.0
	boss.position = start
	boss.spawn_grace = true
	boss.is_in_spawn_zone = true
	boss.apply_wave_scale(SCALE_CONFIG.get_hp_mult(WAVE), SCALE_CONFIG.get_dmg_mult(WAVE), SCALE_CONFIG.get_speed_mult(WAVE), WAVE, SCALE_CONFIG)
	add_child(boss)
	for i in 3:
		await get_tree().physics_frame
	_check("x%d: the Bulwark walks on the large-agent navmesh (layers %d)" % [speed, boss.nav.navigation_layers], boss.nav.navigation_layers == (boss.data as BossData).nav_layers)

	var hp_before := fortress_health.hp
	var max_tier := 0
	var took_slot := false
	var elapsed := 0.0
	var hit_at := Vector3.INF
	var facing := -1.0
	var last_tier := -1
	var last_target := ""
	while elapsed < TIME_LIMIT and is_instance_valid(boss) and not boss.is_dead:
		await get_tree().physics_frame
		# Already scaled by the time scale: game seconds.
		elapsed += get_physics_process_delta_time()
		var tier := int(boss.get(&"_current_stuck_tier"))
		if tier != last_tier:
			print("    %.1f s tier %d at %s" % [elapsed, tier, boss.global_position])
			last_tier = tier
		max_tier = maxi(max_tier, tier)
		var tname := String(boss.current_target.name) if is_instance_valid(boss.current_target) else "-"
		if tname != last_target:
			print("    %.1f s target %s at %s" % [elapsed, tname, boss.global_position])
			last_target = tname
		if fortress.has_method(&"has_melee_slot") and fortress.has_melee_slot(boss):
			took_slot = true
		# Damage that splashes onto the wall while the boss fights something else is not its Fortress attack.
		var on_fortress := is_instance_valid(boss.current_target) and boss.current_target.is_in_group(&"fortress")
		if on_fortress and OS.has_environment("BULWARK_TRACE") and int(elapsed * 2.0) != int((elapsed - get_physics_process_delta_time()) * 2.0):
			var p := boss.global_position
			print("      t=%.1f pos=(%.2f, %.2f) gap=%.2f state=%s vel=%.2f finished=%s next=%s desired=%.2f hit=%s" % [elapsed, p.x, p.z, Vector2(p.x - point.x, p.z - point.z).length(), Enums.EnemyState.keys()[boss.current_state], Vector2(boss.velocity.x, boss.velocity.z).length(), boss.nav.is_navigation_finished(), boss.nav.get_next_path_position(), boss.nav.target_desired_distance, (str(boss.get_last_slide_collision().get_collider().get_path()) + " n=" + str(boss.get_last_slide_collision().get_normal())) if boss.get_last_slide_collision() != null else "-"])
		if not on_fortress:
			hp_before = fortress_health.hp
		elif fortress_health.hp < hp_before:
			hit_at = boss.global_position
			var fwd := -boss.global_transform.basis.z
			fwd.y = 0.0
			var to_fort := fortress.global_position - boss.global_position
			to_fort.y = 0.0
			# The model faces +Z or -Z depending on the rig; either way it must point at the Fortress.
			var fwd_z := boss.global_transform.basis.z
			fwd_z.y = 0.0
			facing = maxf(fwd.normalized().dot(to_fort.normalized()), fwd_z.normalized().dot(to_fort.normalized()))
			break
	var gap := Vector2(hit_at.x - point.x, hit_at.z - point.z).length() if hit_at.is_finite() else INF
	_check("x%d: the first Stomp on the Fortress lowers its HP (after %.1f game s)" % [speed, elapsed], hit_at.is_finite())
	_check("x%d: it stands within %.1f m of boss_melee_point (%.2f m)" % [speed, STOP_TOLERANCE, gap], gap <= STOP_TOLERANCE)
	_check("x%d: it faces the Fortress (%.2f)" % [speed, facing], facing >= 0.7)
	_check("x%d: never reached stuck tier 2 or 3 (max %d)" % [speed, max_tier], max_tier < 2)
	_check("x%d: never took a Fortress melee slot" % speed, not took_slot)
	if is_instance_valid(boss):
		boss.queue_free()
	fortress_health.hp = fortress_health.max_hp
	await get_tree().physics_frame


## Fresh Barricades on the layout (the last boss may have broken them).
func _build_layout(layout: Array) -> void:
	EventBus.state_changed.emit(&"PREP")
	for node in _grid.cells.values():
		var slot := node as Slot
		if slot.state == Enums.SlotState.OCCUPIED:
			_service.sell(slot.slot_id)
		elif slot.state == Enums.SlotState.RUINED:
			_service.clear_rubble(slot.slot_id)
	await _wait_rebake()
	var built := 0
	for c: Vector2i in layout:
		if _service.build(StringName(GridData.cell_id(c.x, c.y)), &"barricade", 1):
			built += 1
	_check("three Barricades built on %s" % [layout], built == 3)
	_check("navmesh rebaked", await _wait_rebake())


func _gate() -> Vector3:
	var lane := _grid.lane
	return lane.global_transform * lane.curve.get_point_position(lane.curve.point_count - 1)


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
