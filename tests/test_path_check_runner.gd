extends Node

## Automated test runner verifying the GridData path check:
## - cell_of, the sample step and the gate goal helpers
## - open and sealed layouts around the min_width limit, with the gaps printed
## - wall to wall chains, a boss pocket and the build candidate layouts
## - misaligned layouts and empty goals
## - the real level: every single cell leaves the lane open; triple scan and timing are printed
## Expected log noise: one WARNING from test_alignment (misaligned rows).

const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")
const GRID: GridData = preload("res://levels/corridor/grid_data.tres")
const R9 := [-10.0, -7.5, -5.0, -2.5, 0.0, 2.5, 5.0, 7.5, 10.0]
const R3 := [-2.5, 0.0, 2.5]

@export var quit_when_done := true

var passes: int = 0
var fails: int = 0

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED PATH CHECK TEST                       ")
	print("=======================================================")

	test_cell_of()
	test_sample_step()
	test_gate_goal()
	test_empty_open()
	test_gap_table()
	test_wall_to_wall_blocks()
	test_one_cell_open()
	test_pocket_only_boss()
	test_candidate_counts()
	test_alignment()
	test_empty_goals()
	test_real_level()
	test_cost()

	print("\n=======================================================")
	print("  TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================")
	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)


# --- helpers ---

func _width() -> float:
	return GameConfig.path_check_min_width


func _corridor(width: float, rows: Array, columns: int) -> GridData:
	var g := GridData.new()
	g.origin = Vector3.ZERO
	g.column_dir = Vector3.RIGHT
	g.columns = columns
	g.row_offsets = PackedFloat32Array(rows)
	g.corridor_width = width
	return g


func _world(grid: GridData, u: float, v: float) -> Vector3:
	return grid.origin + grid.column_dir.normalized() * u + grid.row_dir() * v


func _goals(grid: GridData, gate: Vector3, boss: Vector3) -> Array[Vector3]:
	return [grid.gate_goal(gate, _width()), boss]


## Edge-to-edge distance between two cell squares.
func _cell_gap(grid: GridData, a: Vector2i, b: Vector2i) -> float:
	var h: float = GameConfig.grid_cell_size * 0.5
	var d := grid.cell_position(a) - grid.cell_position(b)
	var du := maxf(absf(d.x) - 2.0 * h, 0.0)
	var dv := maxf(absf(d.z) - 2.0 * h, 0.0)
	return Vector2(du, dv).length()


## Distance between a cell square and the nearest wall.
func _wall_gap(grid: GridData, cell: Vector2i) -> float:
	var h: float = GameConfig.grid_cell_size * 0.5
	return grid.corridor_width * 0.5 - (absf(grid.row_offsets[cell.y]) + h)


## Unreachable goal indices for a hand-built corridor: gate at u -2, boss at the lane origin
## unless given, spawn at u 27 (u 20 for narrow corridors).
func _scan(grid: GridData, obs: Array[Vector2i], boss: Vector3 = Vector3.INF) -> PackedInt32Array:
	var spawn_u := 27.0 if grid.corridor_width > 20.0 else 20.0
	var gate := _world(grid, -2.0, 0.0)
	var boss_point := _world(grid, 0.0, 0.0) if boss == Vector3.INF else boss
	return grid.unreachable_goals(obs, _world(grid, spawn_u, 0.0), gate, _goals(grid, gate, boss_point), _width())


func _is_both(res: PackedInt32Array) -> bool:
	return res.size() == 2 and res[0] == 0 and res[1] == 1


func _real_inputs(level: Node3D) -> Dictionary:
	var grid := level.get_node("Slots/GroundGrid") as GroundGrid
	var gate: Vector3 = grid.lane.global_transform * grid.lane.curve.get_point_position(grid.lane.curve.point_count - 1)
	var goals: Array[Vector3] = [GRID.gate_goal(gate, _width()), grid.get_boss_point()]
	return {"grid": grid, "gate": gate, "goals": goals, "spawn": grid.spawn_zone.global_position}


# --- cases ---

func test_cell_of() -> void:
	print("\n[GROUP 1] cell_of")
	assert_true(GridData.cell_of(&"G_3_7") == Vector2i(3, 7), "G_3_7 -> (3, 7)")
	assert_true(GridData.cell_of(GridData.cell_id(8, 0)) == Vector2i(8, 0), "cell_id round-trips")
	for bad in [&"W1", &"G1", &"G_x_1", &"G_1", &"G_-1_2"]:
		assert_true(GridData.cell_of(bad) == Vector2i(-1, -1), "%s is not a cell" % bad)


func test_sample_step() -> void:
	print("\n[GROUP 2] sample step")
	assert_true(is_equal_approx(GridData.path_sample_step(), GameConfig.grid_cell_gap / 4.0), "step is a quarter of the cell gap")


func test_gate_goal() -> void:
	print("\n[GROUP 3] gate goal")
	var g := Vector3(-15, 0, 0)
	var expected := g + GRID.column_dir.normalized() * _width() / 2.0
	assert_true(GRID.gate_goal(g, _width()).is_equal_approx(expected), "gate goal is min_width / 2 in front of the gate")


func test_empty_open() -> void:
	print("\n[GROUP 4] empty corridor")
	var grid := _corridor(23.5, R9, 9)
	var obs: Array[Vector2i] = []
	assert_true(_scan(grid, obs).is_empty(), "no obstacles leaves every goal reachable")


func test_gap_table() -> void:
	print("\n[GROUP 5] gaps around min_width (%.2f m)" % _width())
	var w := _width()

	var a := _corridor(23.5, R9, 9)
	var obs_a: Array[Vector2i] = []
	for r in range(0, 8):
		obs_a.append(Vector2i(2, r))
	var gap_a := _wall_gap(a, Vector2i(2, 7))
	print("  (a) wall gap %.3f m" % gap_a)
	assert_true(gap_a >= w, "(a) premise: wall gap %.3f >= min_width" % gap_a)
	assert_true(_scan(a, obs_a).is_empty(), "(a) column 2 rows 0..7 stays open")

	var obs_b: Array[Vector2i] = []
	for r in range(1, 9):
		obs_b.append(Vector2i(2, r))
	assert_true(_scan(a, obs_b).is_empty(), "(b) column 2 rows 1..8 stays open")

	var c := _corridor(23.25, R9, 9)
	var gap_c := _wall_gap(c, Vector2i(2, 7))
	print("  (c) wall gap %.3f m" % gap_c)
	assert_true(gap_c < w, "(c) premise: wall gap %.3f < min_width" % gap_c)
	assert_true(_is_both(_scan(c, obs_a)), "(c) the 23.25 m corridor is sealed")

	var d := _corridor(8.0, R3, 6)
	var obs_d: Array[Vector2i] = [Vector2i(2, 0), Vector2i(2, 2)]
	var gap_d := _cell_gap(d, Vector2i(2, 0), Vector2i(2, 2))
	print("  (d) gap %.3f m" % gap_d)
	assert_true(gap_d < w, "(d) premise: gap %.3f < min_width" % gap_d)
	assert_true(_is_both(_scan(d, obs_d)), "(d) two cells in one column seal the 8 m corridor")

	var obs_e: Array[Vector2i] = [Vector2i(2, 0), Vector2i(3, 2)]
	var gap_e := _cell_gap(d, Vector2i(2, 0), Vector2i(3, 2))
	print("  (e) diagonal gap %.3f m" % gap_e)
	assert_true(gap_e < w, "(e) premise: gap %.3f < min_width" % gap_e)
	assert_true(_is_both(_scan(d, obs_e)), "(e) one column apart still seals")

	var obs_f: Array[Vector2i] = [Vector2i(2, 0), Vector2i(4, 2)]
	var gap_f := _cell_gap(d, Vector2i(2, 0), Vector2i(4, 2))
	print("  (f) diagonal gap %.3f m" % gap_f)
	assert_true(gap_f >= w, "(f) premise: gap %.3f >= min_width" % gap_f)
	assert_true(_scan(d, obs_f).is_empty(), "(f) two columns apart stays open")


func test_wall_to_wall_blocks() -> void:
	print("\n[GROUP 6] wall to wall chain")
	var d := _corridor(8.0, R3, 6)
	var obs: Array[Vector2i] = [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
	var gate := _world(d, -2.0, 0.0)
	var goals := _goals(d, gate, _world(d, 0.0, 0.0))
	assert_true(_is_both(_scan(d, obs)), "three cells fill the width, both goals lost")
	assert_true(not d.is_path_open(obs, _world(d, 20.0, 0.0), gate, goals, _width()), "is_path_open is false")


func test_one_cell_open() -> void:
	print("\n[GROUP 7] one cell")
	var d := _corridor(8.0, R3, 6)
	var obs: Array[Vector2i] = [Vector2i(2, 0)]
	assert_true(_scan(d, obs).is_empty(), "a single cell in the 8 m corridor stays open")


func test_pocket_only_boss() -> void:
	print("\n[GROUP 8] boss pocket")
	var grid := _corridor(23.5, R9, 9)
	var boss := _world(grid, 2.5, 8.75)
	var obs: Array[Vector2i] = [Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 7), Vector2i(3, 8)]
	var res := _scan(grid, obs, boss)
	assert_true(res.size() == 1 and res[0] == 1, "walled-in boss point loses only the boss goal (%s)" % res)
	obs.pop_back()
	assert_true(_scan(grid, obs, boss).is_empty(), "without the last cell the pocket is open")


func test_candidate_counts() -> void:
	print("\n[GROUP 9] build candidate layouts")
	var grid := _corridor(16.0, [-5.0, 0.0, 5.0], 3)
	var gate := _world(grid, -9.0, 0.0)
	var boss := _world(grid, -7.0, 0.0)
	var goals := _goals(grid, gate, boss)
	var spawn := _world(grid, 25.0, 0.0)
	var two: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1)]
	assert_true(grid.unreachable_goals(two, spawn, gate, goals, _width()).is_empty(), "two cells in a column leave the path")
	var three: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	assert_true(_is_both(grid.unreachable_goals(three, spawn, gate, goals, _width())), "a full column seals")
	var far: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(2, 2)]
	assert_true(grid.unreachable_goals(far, spawn, gate, goals, _width()).is_empty(), "third cell two columns away leaves the path")
	var diag: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 2)]
	print("  diagonal gap %.3f m" % _cell_gap(grid, Vector2i(0, 1), Vector2i(1, 2)))
	assert_true(_is_both(grid.unreachable_goals(diag, spawn, gate, goals, _width())), "third cell one column away seals")


func test_alignment() -> void:
	print("\n[GROUP 10] alignment")
	assert_true(GRID.is_path_aligned(), "the real layout is aligned to the sample step")
	var skewed := _corridor(8.0, [-2.4, 0.0, 2.4], 6)
	assert_true(not skewed.is_path_aligned(), "rows at +-2.4 are not aligned")
	var obs: Array[Vector2i] = [Vector2i(2, 0)]
	var res := _scan(skewed, obs)
	print("  misaligned result: %s" % res)
	assert_true(res.size() <= 2, "a misaligned layout still returns a result")


func test_empty_goals() -> void:
	print("\n[GROUP 11] empty goals")
	var grid := _corridor(23.5, R9, 9)
	var obs: Array[Vector2i] = []
	var goals: Array[Vector3] = []
	var res := grid.unreachable_goals(obs, _world(grid, 27.0, 0.0), _world(grid, -2.0, 0.0), goals, _width())
	assert_true(res.is_empty(), "no goals, nothing unreachable")


func test_real_level() -> void:
	print("\n[GROUP 12] real level")
	var level: Node3D = LEVEL_SCENE.instantiate()
	add_child(level)
	var inputs := _real_inputs(level)
	var grid: GroundGrid = inputs["grid"]
	var gate: Vector3 = inputs["gate"]
	var goals: Array[Vector3] = inputs["goals"]
	var spawn: Vector3 = inputs["spawn"]
	var cells := grid.get_valid_cells()

	var none: Array[Vector2i] = []
	assert_true(GRID.unreachable_goals(none, spawn, gate, goals, _width()).is_empty(), "the empty level is open")

	var all_open := true
	for cell in cells:
		var one: Array[Vector2i] = [cell]
		if not GRID.unreachable_goals(one, spawn, gate, goals, _width()).is_empty():
			all_open = false
			print("  single cell %s seals the lane" % GridData.cell_id(cell.x, cell.y))
	assert_true(all_open, "no single cell of the %d valid cells seals the lane" % cells.size())

	var near: Array[Vector2i] = []
	for cell in cells:
		if cell.x <= 2:
			near.append(cell)
	var t0 := Time.get_ticks_usec()
	var combos := 0
	var sealing := 0
	var first := ""
	for a in near.size():
		for b in range(a + 1, near.size()):
			for c in range(b + 1, near.size()):
				combos += 1
				var obs: Array[Vector2i] = [near[a], near[b], near[c]]
				if GRID.unreachable_goals(obs, spawn, gate, goals, _width()).is_empty():
					continue
				sealing += 1
				if first == "":
					first = "%s %s %s" % [GridData.cell_id(near[a].x, near[a].y), GridData.cell_id(near[b].x, near[b].y), GridData.cell_id(near[c].x, near[c].y)]
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("  triple scan: %d cells with column <= 2, %d triples, %d sealing (first: %s), %.0f ms" % [near.size(), combos, sealing, first, ms])
	remove_child(level)
	level.free()


func test_cost() -> void:
	print("\n[GROUP 13] cost")
	var level: Node3D = LEVEL_SCENE.instantiate()
	add_child(level)
	var inputs := _real_inputs(level)
	var gate: Vector3 = inputs["gate"]
	var goals: Array[Vector3] = inputs["goals"]
	var spawn: Vector3 = inputs["spawn"]

	var open_obs: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, 4), Vector2i(5, 8)]
	var t0 := Time.get_ticks_usec()
	var open_res := GRID.unreachable_goals(open_obs, spawn, gate, goals, _width())
	print("  three scattered cells (open: %s): %.1f ms" % [open_res.is_empty(), (Time.get_ticks_usec() - t0) / 1000.0])

	var sealed_obs: Array[Vector2i] = []
	for r in GRID.row_offsets.size():
		sealed_obs.append(Vector2i(2, r))
	t0 = Time.get_ticks_usec()
	var sealed_res := GRID.unreachable_goals(sealed_obs, spawn, gate, goals, _width())
	print("  full column 2 (sealed: %s): %.1f ms" % [not sealed_res.is_empty(), (Time.get_ticks_usec() - t0) / 1000.0])
	remove_child(level)
	level.free()


func assert_true(cond: bool, name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] ", name)
	else:
		fails += 1
		printerr("  [FAIL] ", name)
