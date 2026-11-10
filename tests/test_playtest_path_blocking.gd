class_name TestPlaytestPathBlocking
extends Node3D
## Scene playtest for ground buildings that narrow the lane. Finds the legal ground layout with the
## narrowest bottleneck on the real corridor, builds it through BuildService, then releases each
## enemy group from the spawn zone and checks that every unit still walks to the Fortress. The
## towers are made silent and unbreakable, so only the path is measured. Archers arrive once the
## Fortress is in bow range, which can be before the layout, so they only show the spawn side is clear.
## Headless (or auto_run): runs every group, prints one line per group and quits.
## F6 starts with an empty ground, so towers are placed by hand through BuildService (its cap and
## path check apply). Each free cell is tinted: buildable, ground cap reached, or would seal the lane.
## F6 mouse: left click a cell builds an Arrow, right click removes the tower on it.
## F6 keys: L build the worst layout found, C clear the ground, 1-5 run one group, R repeat it,
## A run all, +/- speed, T enemies attack towers on/off.

const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const ARCHER_SCENE: PackedScene = preload("res://entities/enemy/archer.tscn")
const BRUTE_SCENE: PackedScene = preload("res://entities/enemy/brute.tscn")
const BULWARK_SCENE: PackedScene = preload("res://entities/enemy/bulwark.tscn")
const ARROW: TowerData = preload("res://data/towers/arrow.tres")
const CANNON: TowerData = preload("res://data/towers/cannon.tres")
const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
const CANNON_SCENE: PackedScene = preload("res://entities/tower/cannon.tscn")

const GROUP_NAMES: Array[String] = ["Grunt", "Archer", "Brute", "Bulwark", "Mixed wave"]
const GROUP_BULWARK := 3
const GROUP_MIXED := 4
## Used when the spawn zone has no box shape.
const DEFAULT_ZONE_SIZE := Vector3(12.0, 4.0, 23.5)
const CAMERA_HEIGHT := 40.0
const CAMERA_SIZE := 28.0

signal group_finished

## Runs every group and quits even with a window. Headless always does.
@export var auto_run := false
## Engine.time_scale while a group runs.
@export var time_scale := 4.0
## Off: enemies only aim at the Fortress (the Bulwark at its standing point), so the result is the
## path alone. On: the data's own target rules apply, to watch the real behaviour.
@export var enemies_attack_towers := false

@export_group("Cell hints")
## Free cell where a build would be allowed.
@export var hint_color_ok := Color(0.2, 0.9, 0.3, 0.4)
## Free cell refused because the ground cap is reached.
@export var hint_color_full := Color(0.6, 0.6, 0.6, 0.35)
## Free cell refused because it would seal the lane.
@export var hint_color_blocks := Color(0.95, 0.2, 0.2, 0.45)
## Hint quad edge as a share of GameConfig.grid_pick_size.
@export var hint_size_fraction := 0.85
## Height of the hint quads above the cell.
@export var hint_height := 0.05

@export_group("Layout search")
## Ground cells up to this column are candidates.
@export var search_max_column := 2
## Middle-row cells this many columns further out are candidates too.
@export var middle_row_extra_columns := 2
## Cell ids to build instead of searching, for example [&"G_2_1", &"G_2_7", &"G_1_0"].
@export var layout_override: Array[StringName] = []
## HP given to each tower so nothing can destroy it.
@export var tower_hp := 1000000

@export_group("Groups")
@export var grunt_count := 6
@export var archer_count := 4
@export var brute_count := 2
@export var bulwark_count := 1
## Wave whose composition the mixed group uses.
@export var mixed_wave := 10

@export_group("Scoring")
## A unit has arrived this far beyond its attack range from its goal.
@export var arrival_margin := 1.0
## Time limit = lane length / speed * factor + extra, in game seconds.
@export var time_limit_factor := 2.5
@export var time_limit_extra := 10.0
## A window with less movement than this share of the walking speed counts as stalled.
@export var stall_speed_fraction := 0.25
@export var stall_window := 0.5
## A jump longer than this in one physics frame counts as a hop.
@export var hop_distance := 2.0
## Gap between spawned units, along the rows and columns of the spawn zone.
@export var spawn_spacing := 2.0
## Real seconds after which an automatic run gives up.
@export var real_time_budget := 140.0

class Track:
	var enemy: Enemy
	var speed := 1.0
	var limit := 0.0
	var arrived := false
	var arrive_time := 0.0
	var lost := false
	var timed_out := false
	var hops := 0
	var retargets := 0
	var stall_max := 0.0
	var stall_run := 0.0
	var last_pos := Vector3.ZERO
	var window_pos := Vector3.ZERO
	var window_time := 0.0

	func is_done() -> bool:
		return arrived or lost or timed_out

@onready var level: Node3D = %Level
@onready var wave_manager: WaveManager = %WaveManager
@onready var enemy_container: Node3D = %Enemy
@onready var camera: Camera3D = %TopCamera
@onready var status_label: Label = %StatusLabel
@onready var log_text: RichTextLabel = %LogText

var passes := 0
var fails := 0

var _grid: GroundGrid
var _fortress: Fortress
var _gold: GoldManager
var _service: BuildService
var _tracks: Array[Track] = []
var _layout_ids: Array[StringName] = []
var _layout_text := "searching..."
var _results: Array[String] = []
var _last_denied: StringName = &""
var _notice := ""
var _worst_ids: Array[StringName] = []
var _hints: Dictionary[StringName, MeshInstance3D] = {}
var _hint_root: Node3D
var _current_group := -1
var _elapsed := 0.0
var _watching := false
var _running := false
var _budget_blown := false
var _start_msec := 0


func _ready() -> void:
	_start_msec = Time.get_ticks_msec()
	_grid = level.get_node("Slots/GroundGrid") as GroundGrid
	_fortress = get_tree().get_first_node_in_group(&"fortress") as Fortress
	wave_manager.set_physics_process(false)
	wave_manager.auto_advance_summary = false
	wave_manager.spawn_queue.clear()
	_setup_economy()
	camera.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(1.0, CAMERA_HEIGHT, 0.0))
	camera.size = CAMERA_SIZE
	camera.make_current()
	EventBus.build_denied.connect(func(reason: StringName, _shortfall: int): _last_denied = reason)
	EventBus.stuck_event_logged.connect(_on_stuck_event)
	_start.call_deferred()


func _setup_economy() -> void:
	_gold = GoldManager.new()
	add_child(_gold)
	_service = BuildService.new()
	_service.towers = [ARROW, CANNON]
	_service.tower_scenes = {&"arrow": ARROW_SCENE, &"cannon": CANNON_SCENE}
	add_child(_service)


func _is_auto() -> bool:
	return auto_run or DisplayServer.get_name() == "headless"


func _start() -> void:
	# Let the navigation map sync and the economy nodes finish their deferred setup.
	for i in 5:
		await get_tree().physics_frame
	if not _is_auto():
		_start_manual()
		return
	_prepare_layout()
	await _run_all()
	_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================")
	if _is_auto():
		get_tree().quit(0 if fails == 0 else 1)


#region Layout
func _prepare_layout() -> void:
	_return_to_prep()
	var ids := _choose_layout()
	_check(ids.size() == GameConfig.max_ground_buildings, "layout has %d cells" % GameConfig.max_ground_buildings)
	for id in ids:
		var ok := _build_inert(id)
		_check(ok, "BuildService builds Arrow on %s" % id)
		if ok:
			_layout_ids.append(id)
	_try_extra_build()


## The override when set, else the narrowest legal layout; sets _layout_text.
func _choose_layout() -> Array[StringName]:
	var ids: Array[StringName] = []
	if layout_override.is_empty():
		var found := _find_layout()
		ids = found.get("ids", [] as Array[StringName])
		_layout_text = found.get("text", "no layout")
	else:
		ids = layout_override.duplicate()
		_layout_text = "override %s" % [ids]
	_log("Layout: %s" % _layout_text)
	return ids


## Arrow through the real service, then silent and unbreakable. False when the service refuses.
func _build_inert(id: StringName) -> bool:
	var ok := _service.build(id, &"arrow", 1)
	var slot := _service.find_slot(id)
	if ok and slot != null and slot.tower != null:
		_make_tower_inert(slot.tower)
	return ok


## Plenty of gold and the PREP state, which BuildService needs to build or sell.
func _return_to_prep() -> void:
	_gold.gold = 1000000
	EventBus.state_changed.emit(&"PREP")


## Silent (no shots) and unbreakable, so towers neither kill enemies nor die to them.
func _make_tower_inert(tower: Tower) -> void:
	tower.set_physics_process(false)
	tower.health.set_max_hp(tower_hp, true)


## One more ground building must be refused by the cap.
func _try_extra_build() -> void:
	for id in _grid.cells.keys():
		var slot := _grid.cells[id] as Slot
		if slot == null or not slot.is_free():
			continue
		_last_denied = &""
		var ok := _service.build(id, &"arrow", 1)
		_log("Extra build on %s: %s, denied reason %s" % [id, ok, _last_denied])
		_check(not ok and _last_denied == &"GROUND_FULL", "a ground build past the cap is refused as GROUND_FULL")
		if ok:
			_make_tower_inert(slot.tower)
			_layout_ids.append(id)
		return


## The legal combination of GameConfig.max_ground_buildings cells with the smallest bottleneck:
## the widest agent that still reaches every goal. Widths grow in path_sample_step() steps.
@warning_ignore("integer_division")
func _find_layout() -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var data := _grid.grid_data
	var min_w := GameConfig.path_check_min_width
	var step := GridData.path_sample_step()
	var gate := _lane_end()
	var goals: Array[Vector3] = [data.gate_goal(gate, min_w), _grid.get_boss_point()]
	var spawn := _grid.spawn_zone.global_position
	var max_steps := ceili((data.corridor_width - min_w) / step) + 1
	var combos := _combinations(_candidate_cells(), GameConfig.max_ground_buildings)
	var best: Array[Vector2i] = []
	var best_steps := max_steps
	for combo in combos:
		var obstacles: Array[Vector2i] = combo
		# Still open at the best width: cannot be narrower than the best so far.
		if not best.is_empty() and _is_open(obstacles, spawn, gate, goals, min_w + best_steps * step):
			continue
		# Sealed at the minimum width: BuildService would refuse it.
		if not _is_open(obstacles, spawn, gate, goals, min_w):
			continue
		var lo := 0
		var hi := best_steps
		while hi - lo > 1:
			var mid := (lo + hi) / 2
			if _is_open(obstacles, spawn, gate, goals, min_w + mid * step):
				lo = mid
			else:
				hi = mid
		best = combo
		best_steps = lo
	var ms := Time.get_ticks_msec() - t0
	if best.is_empty():
		return {"text": "no legal layout (%d combinations, %d ms)" % [combos.size(), ms]}
	var ids: Array[StringName] = []
	for cell in best:
		ids.append(GridData.cell_id(cell.x, cell.y))
	var width := min_w + best_steps * step
	return {"ids": ids, "width": width,
		"text": "%s, bottleneck %.3f m (agent minimum %.2f m), %d combinations, %d ms" % [ids, width, min_w, combos.size(), ms]}


func _is_open(obstacles: Array[Vector2i], spawn: Vector3, gate: Vector3, goals: Array[Vector3], width: float) -> bool:
	return _grid.grid_data.unreachable_goals(obstacles, spawn, gate, goals, width).is_empty()


func _lane_end() -> Vector3:
	return _grid.lane.global_transform * _grid.lane.curve.get_point_position(_grid.lane.curve.point_count - 1)


func _candidate_cells() -> Array[Vector2i]:
	var middle := _grid.grid_data.middle_row()
	var out: Array[Vector2i] = []
	for id in _grid.cells.keys():
		var cell := GridData.cell_of(id)
		if cell.x < 0:
			continue
		var near := cell.x <= search_max_column
		var middle_extra := cell.y == middle and cell.x <= search_max_column + middle_row_extra_columns
		if near or middle_extra:
			out.append(cell)
	return out


func _combinations(items: Array[Vector2i], size: int) -> Array:
	var out: Array = []
	var current: Array[Vector2i] = []
	_collect_combinations(items, size, 0, current, out)
	return out


func _collect_combinations(items: Array[Vector2i], size: int, start: int, current: Array[Vector2i], out: Array) -> void:
	if current.size() == size:
		out.append(current.duplicate())
		return
	for i in range(start, items.size()):
		current.append(items[i])
		_collect_combinations(items, size, i + 1, current, out)
		current.pop_back()
#endregion


#region Groups
func _run_all() -> void:
	for i in GROUP_NAMES.size():
		await _run_group(i)


func _run_group(index: int) -> void:
	_running = true
	_current_group = index
	_clear_enemies()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _fortress != null:
		_fortress.health.heal(_fortress.health.max_hp)
	if _budget_blown:
		_report_skipped(index)
		_running = false
		return
	Engine.time_scale = time_scale
	_spawn_group(index)
	_elapsed = 0.0
	if _tracks.is_empty():
		_log("%s: nothing to spawn" % GROUP_NAMES[index])
	else:
		_watching = true
		await group_finished
	Engine.time_scale = 1.0
	_report_group(index)
	_clear_enemies()
	_running = false
	if not _is_auto():
		_return_to_prep()
		_refresh_hints()


func _clear_enemies() -> void:
	_watching = false
	for node in get_tree().get_nodes_in_group(&"enemy"):
		if is_instance_valid(node):
			node.queue_free()
	_tracks.clear()


func _spawn_group(index: int) -> void:
	var scenes := _group_scenes(index)
	var positions := _spawn_positions(scenes.size())
	if index == GROUP_BULWARK and scenes.size() == 1:
		positions = [_boss_spawn_position()]
	var wave := mixed_wave if index == GROUP_MIXED else 0
	for i in scenes.size():
		_spawn_one(scenes[i], positions[i], wave)
	_log("%s: spawned %d" % [GROUP_NAMES[index], _tracks.size()])


func _group_scenes(index: int) -> Array[PackedScene]:
	var out: Array[PackedScene] = []
	match index:
		0:
			_fill(out, GRUNT_SCENE, grunt_count)
		1:
			_fill(out, ARCHER_SCENE, archer_count)
		2:
			_fill(out, BRUTE_SCENE, brute_count)
		3:
			_fill(out, BULWARK_SCENE, bulwark_count)
		GROUP_MIXED:
			for item in wave_manager.generate_wave_composition(mixed_wave, 0):
				var scene := item.get("scene") as PackedScene
				if scene != null:
					out.append(scene)
	return out


func _fill(out: Array[PackedScene], scene: PackedScene, count: int) -> void:
	for i in count:
		out.append(scene)


func _spawn_one(scene: PackedScene, pos: Vector3, wave: int) -> void:
	var enemy := scene.instantiate() as Enemy
	enemy.position = pos
	enemy.spawn_grace = false
	enemy.is_in_spawn_zone = false
	if not enemies_attack_towers:
		enemy.data = _fortress_only(enemy.data)
	if wave > 0:
		var cfg: ScaleConfig = wave_manager.scale_config
		enemy.apply_wave_scale(cfg.get_hp_mult(wave), cfg.get_dmg_mult(wave), cfg.get_speed_mult(wave), wave, cfg)
	enemy_container.add_child(enemy)
	var track := Track.new()
	track.enemy = enemy
	track.speed = maxf(0.1, enemy.data.move_speed * enemy.speed_multiplier)
	track.limit = _lane_length() / track.speed * time_limit_factor + time_limit_extra
	track.last_pos = pos
	track.window_pos = pos
	_tracks.append(track)


## A copy of data that only targets the Fortress; the shared resource stays untouched.
func _fortress_only(data: EnemyData) -> EnemyData:
	var copy := data.duplicate() as EnemyData
	var rules: Array[StringName] = [&"FORTRESS"]
	copy.target_rules = rules
	return copy


func _lane_length() -> float:
	return _grid.lane.curve.get_baked_length()


func _zone_size() -> Vector3:
	var shape := _grid.spawn_zone.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null and shape.shape is BoxShape3D:
		return (shape.shape as BoxShape3D).size
	return DEFAULT_ZONE_SIZE


## Rows across the zone, columns going back from the gate side; fewer units are spread evenly.
@warning_ignore("integer_division")
func _spawn_positions(count: int) -> Array[Vector3]:
	var centre := _grid.spawn_zone.global_position
	var size := _zone_size()
	var rows := maxi(1, floori((size.z - 2.0) / spawn_spacing) + 1)
	var out: Array[Vector3] = []
	for i in count:
		var col := i / rows
		var in_col := mini(rows, count - col * rows)
		var idx := i % rows
		var row := rows / 2 if in_col == 1 else roundi(float(idx) * float(rows - 1) / float(in_col - 1))
		var z := (float(row) - float(rows - 1) * 0.5) * spawn_spacing
		var x := centre.x + size.x * 0.5 - 1.0 - float(col) * spawn_spacing
		out.append(Vector3(x, 0.0, centre.z + z))
	return out


func _boss_spawn_position() -> Vector3:
	var marker := get_tree().get_first_node_in_group(&"boss_spawn_point") as Node3D
	if marker == null:
		return Vector3(_grid.spawn_zone.global_position.x, 0.0, 0.0)
	return Vector3(marker.global_position.x, 0.0, marker.global_position.z)
#endregion


#region Scoring
func _physics_process(delta: float) -> void:
	if not _watching:
		return
	_elapsed += delta
	if _is_auto() and (Time.get_ticks_msec() - _start_msec) / 1000.0 > real_time_budget:
		_budget_blown = true
	for track in _tracks:
		_update_track(track)
	for track in _tracks:
		if not track.is_done():
			return
	_watching = false
	group_finished.emit()


func _update_track(track: Track) -> void:
	if track.is_done():
		return
	var enemy := track.enemy
	if not is_instance_valid(enemy) or enemy.is_dead:
		track.lost = true
		return
	var pos := enemy.global_position
	var jump := pos - track.last_pos
	jump.y = 0.0
	if jump.length() > hop_distance:
		track.hops += 1
		_log("%s jumped %.1f m at %.1f s" % [enemy.data.id, jump.length(), _elapsed])
	track.last_pos = pos
	_keep_fortress_target(track)
	if _has_arrived(enemy):
		track.arrived = true
		track.arrive_time = _elapsed
		# Gone before it can hurt the Fortress or crowd the units still walking.
		enemy.queue_free()
		return
	_update_stall(track, pos)
	if _elapsed > track.limit or _budget_blown:
		track.timed_out = true


## The Bulwark's stuck ladder can aim it at the nearest tower, which would never break here. With
## the attack switch off the Fortress is put back, and the switch is counted and logged.
func _keep_fortress_target(track: Track) -> void:
	if enemies_attack_towers or _fortress == null:
		return
	var enemy := track.enemy
	var target := enemy.current_target
	if target == null or not is_instance_valid(target) or target.is_in_group(&"fortress"):
		return
	track.retargets += 1
	_log("%s retargeted to %s at %.1f s, Fortress put back" % [enemy.data.id, target.name, _elapsed])
	enemy.set_target(_fortress)


func _update_stall(track: Track, pos: Vector3) -> void:
	var span := _elapsed - track.window_time
	if span < stall_window:
		return
	var moved := pos - track.window_pos
	moved.y = 0.0
	if moved.length() < stall_speed_fraction * track.speed * span:
		track.stall_run += span
	else:
		track.stall_run = 0.0
	track.stall_max = maxf(track.stall_max, track.stall_run)
	track.window_pos = pos
	track.window_time = _elapsed


## In reach of the Fortress (the Bulwark: of its standing point), or already swinging at the Fortress.
func _has_arrived(enemy: Enemy) -> bool:
	var diff := _goal_for(enemy) - enemy.global_position
	diff.y = 0.0
	if diff.length() <= enemy.data.attack_range + arrival_margin:
		return true
	var target := enemy.current_target
	return enemy.current_state == Enums.EnemyState.ATTACK and target != null and is_instance_valid(target) and target.is_in_group(&"fortress")


func _goal_for(enemy: Enemy) -> Vector3:
	if enemy is Bulwark:
		var marker := get_tree().get_first_node_in_group(&"boss_melee_point") as Node3D
		if marker != null:
			return marker.global_position
	return _fortress.get_melee_slot_position(enemy)


func _report_group(index: int) -> void:
	var reached := 0
	var hops := 0
	var retargets := 0
	var max_time := 0.0
	var stall := 0.0
	var lost := 0
	for track in _tracks:
		if track.arrived:
			reached += 1
			max_time = maxf(max_time, track.arrive_time)
		elif track.timed_out:
			max_time = maxf(max_time, track.limit)
		if track.lost:
			lost += 1
		elif not track.arrived:
			_log("  not arrived: %s at (%.1f, %.1f), stalled %.1f s, state %s" % [
				track.enemy.data.id, track.last_pos.x, track.last_pos.z, track.stall_run,
				Enums.EnemyState.keys()[track.enemy.current_state]])
		hops += track.hops
		retargets += track.retargets
		stall = maxf(stall, track.stall_max)
	var ok := reached == _tracks.size() and hops == 0
	var line := "%s: reached %d/%d, max time %.1f s, longest stall %.1f s, hops %d, retargets %d" % [
		GROUP_NAMES[index], reached, _tracks.size(), max_time, stall, hops, retargets]
	if lost > 0:
		line += ", lost %d" % lost
	_record(ok, line)


func _report_skipped(index: int) -> void:
	_record(false, "%s: skipped, real-time budget of %.0f s used up" % [GROUP_NAMES[index], real_time_budget])
#endregion


#region Manual placement
func _start_manual() -> void:
	_return_to_prep()
	_worst_ids = _choose_layout()
	_layout_text = "worst layout (key L): %s" % _layout_text
	_hint_root = Node3D.new()
	_hint_root.name = "CellHints"
	add_child(_hint_root)
	_refresh_hints()
	_log("Ground is empty. Left click builds, right click removes, L worst layout, C clear, 1-5 group, R repeat, A all, +/- speed, T enemies attack towers.")


func _handle_click(click: InputEventMouseButton) -> void:
	if not click.pressed or _running or _is_auto() or _hint_root == null:
		return
	if click.button_index != MOUSE_BUTTON_LEFT and click.button_index != MOUSE_BUTTON_RIGHT:
		return
	var slot := _pick_cell(click.position)
	if slot == null:
		return
	if click.button_index == MOUSE_BUTTON_LEFT:
		_place_at(slot)
	else:
		_remove_at(slot)


## The ground cell under the screen point: the ray meets the ground plane, the nearest cell centre
## within half the pick size wins.
func _pick_cell(screen_pos: Vector2) -> Slot:
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var hit: Variant = Plane(Vector3.UP, _grid.global_position.y).intersects_ray(origin, dir)
	if hit == null:
		return null
	var point := hit as Vector3
	var best: Slot = null
	var best_dist := GameConfig.grid_pick_size * 0.5
	for node in _grid.cells.values():
		var slot := node as Slot
		if slot == null or not is_instance_valid(slot):
			continue
		var diff := slot.global_position - point
		diff.y = 0.0
		var dist := maxf(absf(diff.x), absf(diff.z))
		if dist <= best_dist:
			best = slot
			best_dist = dist
	return best


func _place_at(slot: Slot) -> void:
	if not slot.is_free():
		_notice = "%s is occupied" % slot.slot_id
		return
	_last_denied = &""
	if _build_inert(slot.slot_id):
		_notice = "Built Arrow on %s" % slot.slot_id
	elif _last_denied != &"":
		_notice = "%s: %s" % [slot.slot_id, _last_denied]
	else:
		_notice = "%s: refused" % slot.slot_id
	_log(_notice)
	_refresh_hints()


func _remove_at(slot: Slot) -> void:
	if not slot.uses_ground_space():
		_notice = "%s is empty" % slot.slot_id
		return
	_clear_slot(slot)
	_notice = "Removed %s" % slot.slot_id
	_log(_notice)
	_refresh_hints()


## Back to EMPTY through the service: sell a tower, then clear any rubble.
func _clear_slot(slot: Slot) -> void:
	if slot.state == Enums.SlotState.OCCUPIED:
		_service.sell(slot.slot_id)
	if slot.state == Enums.SlotState.RUINED:
		_service.clear_rubble(slot.slot_id)


func _clear_ground() -> void:
	if _running or _is_auto() or _hint_root == null:
		return
	_return_to_prep()
	for node in _grid.cells.values():
		var slot := node as Slot
		if slot != null and slot.uses_ground_space():
			_clear_slot(slot)
	_notice = "Ground cleared"
	_log(_notice)
	_refresh_hints()


func _load_worst_layout() -> void:
	if _running or _is_auto() or _hint_root == null:
		return
	_clear_ground()
	var built := 0
	for id in _worst_ids:
		_last_denied = &""
		if _build_inert(id):
			built += 1
		else:
			_log("Worst layout: %s refused (%s)" % [id, _last_denied])
	_notice = "Worst layout built: %d/%d cells" % [built, _worst_ids.size()]
	_log(_notice)
	_refresh_hints()


## One tinted quad per free ground cell; occupied cells have none.
func _refresh_hints() -> void:
	if _hint_root == null:
		return
	var full := _service.is_ground_full()
	for id in _grid.cells.keys():
		var slot := _grid.cells[id] as Slot
		if slot == null or not is_instance_valid(slot):
			continue
		var quad := _hint_for(id, slot)
		quad.visible = not slot.uses_ground_space()
		if not quad.visible:
			continue
		var material := quad.material_override as StandardMaterial3D
		if full:
			material.albedo_color = hint_color_full
		elif _service.would_block_path(slot, ARROW):
			material.albedo_color = hint_color_blocks
		else:
			material.albedo_color = hint_color_ok


func _hint_for(id: StringName, slot: Slot) -> MeshInstance3D:
	if _hints.has(id):
		return _hints[id]
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * GameConfig.grid_pick_size * hint_size_fraction
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := MeshInstance3D.new()
	quad.mesh = mesh
	quad.material_override = material
	_hint_root.add_child(quad)
	quad.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), slot.global_position + Vector3.UP * hint_height)
	_hints[id] = quad
	return quad
#endregion


#region Input and display
func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null:
		_handle_click(click)
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_change_speed(1.0)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_change_speed(-1.0)
		KEY_T:
			enemies_attack_towers = not enemies_attack_towers
			_log("Enemies attack towers: %s" % enemies_attack_towers)
		KEY_L:
			_load_worst_layout()
		KEY_C:
			_clear_ground()
		KEY_A:
			_start_manual_all()
		KEY_R:
			_repeat_manual_group()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			_start_manual_group(key.keycode - KEY_1)


func _start_manual_all() -> void:
	if _running:
		return
	await _run_all()


func _start_manual_group(index: int) -> void:
	if _running:
		return
	await _run_group(index)


## Nothing to repeat until a group has run.
func _repeat_manual_group() -> void:
	if _current_group < 0:
		return
	await _start_manual_group(_current_group)


func _change_speed(direction: float) -> void:
	time_scale = clampf(time_scale + direction, 1.0, 8.0)
	if _running:
		Engine.time_scale = time_scale
	_log("Speed: %.0fx" % time_scale)


func _process(_delta: float) -> void:
	var group_name := GROUP_NAMES[_current_group] if _current_group >= 0 else "none"
	var arrived := 0
	for track in _tracks:
		if track.arrived:
			arrived += 1
	status_label.text = "Group: %s | %.1f s | arrived %d/%d | speed %.0fx | enemies attack towers: %s\nLayout: %s\n%s%s" % [
		group_name, _elapsed, arrived, _tracks.size(), time_scale, enemies_attack_towers, _layout_text,
		_notice + "\n" if not _notice.is_empty() else "", "\n".join(_results)]


func _on_stuck_event(tier: int, kind: StringName, pos: Vector3, _wave: int) -> void:
	_log("Stuck tier %d (%s) at (%.1f, %.1f)" % [tier, kind, pos.x, pos.z])


func _check(cond: bool, test_name: String) -> void:
	_record(cond, test_name)


func _record(ok: bool, text: String) -> void:
	var tag := "[PASS]" if ok else "[FAIL]"
	if ok:
		passes += 1
	else:
		fails += 1
	var line := "%s %s" % [tag, text]
	_results.append(line)
	_log(line)


func _log(msg: String) -> void:
	var line := "[%.1f s] %s" % [Time.get_ticks_msec() / 1000.0, msg]
	print(line)
	log_text.append_text(line + "\n")
#endregion
