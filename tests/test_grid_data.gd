extends Node

## Automated test runner verifying the corridor GridData:
## - 9 rows, cell centres 0, +-2.5, +-5, +-7.5, +-10 m across a 23.5 m corridor, middle row on the lane
## - cell_id is G_c_r and unique; cells sit inside the walls and do not overlap
## - columns run from just in front of the gate to just before spawn_zone
## - no valid cell lies in spawn_zone, return_zone, near command_post or in the Bulwark clear zone
## - a cell breaking any rule is dropped on load
## - starter_arrow_slot is a valid cell in the middle row, nearest the gate (when GameConfig has it)
## - neighbouring columns are one cell plus the gap apart

const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")
const GRID: GridData = preload("res://levels/corridor/grid_data.tres")
const ROW_CENTRES := [-10.0, -7.5, -5.0, -2.5, 0.0, 2.5, 5.0, 7.5, 10.0]

@export var quit_when_done := true

var passes: int = 0
var fails: int = 0

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED GRID DATA TEST                        ")
	print("=======================================================")

	var level: Node3D = LEVEL_SCENE.instantiate()
	add_child(level)
	var spawn: Area3D = level.get_node("SpawnZone")
	var ret: Area3D = level.get_node("Markers/ReturnZone")
	var post: Node3D = level.get_node("Markers/CommandPost")
	var boss: Vector3 = (level.get_node("Markers/BossMeleePoint") as Node3D).global_position

	var cells := GRID.get_cells()
	var valid := GRID.get_valid_cells(spawn, ret, post, boss)
	assert_true(cells.size() > 0, "GridData declares cells (%d)" % cells.size())
	# Every check below indexes rows and cells, so an empty layout would stop the runner with a script error.
	if cells.is_empty() or valid.is_empty():
		_finish(level)
		return
	assert_true(valid.size() == cells.size(), "every declared cell is valid, so loading logs nothing (%d/%d)" % [valid.size(), cells.size()])

	# Layout
	assert_true(is_equal_approx(GRID.corridor_width, 23.5), "corridor is 23.5 m wide")
	var rows_ok := GRID.row_offsets.size() == ROW_CENTRES.size()
	for r in mini(GRID.row_offsets.size(), ROW_CENTRES.size()):
		rows_ok = rows_ok and is_equal_approx(GRID.row_offsets[r], ROW_CENTRES[r])
	assert_true(rows_ok, "9 rows at 0, +-2.5, +-5, +-7.5, +-10 m (%s)" % GRID.row_offsets)
	assert_true(GRID.middle_row() == 4 and is_zero_approx(GRID.row_offsets[GRID.middle_row()]), "row 4 is the middle row, on the lane")
	assert_true(is_equal_approx(GRID.row_offsets[1] - GRID.row_offsets[0], GameConfig.grid_cell_size + GameConfig.grid_cell_gap),
		"neighbouring rows are one cell plus the gap apart")
	assert_true(is_equal_approx(GRID.cell_position(Vector2i(1, 0)).distance_to(GRID.cell_position(Vector2i(0, 0))), GameConfig.grid_cell_size + GameConfig.grid_cell_gap),
		"neighbouring columns are one cell plus the gap apart")

	var ids := {}
	for c in cells:
		ids[GridData.cell_id(c.x, c.y)] = true
	assert_true(ids.size() == cells.size(), "cell_ids are unique")

	var inside := true
	var half_w := GRID.corridor_width * 0.5
	for c in cells:
		var p := GRID.cell_position(c)
		inside = inside and absf(p.z) + GameConfig.grid_cell_size * 0.5 <= half_w + 0.001
	assert_true(inside, "every cell is inside the walls")

	var overlap := false
	for i in cells.size():
		for j in range(i + 1, cells.size()):
			var d := GRID.cell_position(cells[i]) - GRID.cell_position(cells[j])
			if absf(d.x) < GameConfig.grid_cell_size - 0.001 and absf(d.z) < GameConfig.grid_cell_size - 0.001:
				overlap = true
	assert_true(not overlap, "cells do not overlap")

	# Length: from just in front of the gate to just before spawn_zone.
	var half := GameConfig.grid_cell_size * 0.5
	var gate_face := boss.x - 1.8
	var first_edge := GRID.cell_position(Vector2i(0, 0)).x - half
	var last_edge := GRID.cell_position(Vector2i(GRID.columns - 1, 0)).x + half
	var spawn_edge := spawn.global_position.x - ((spawn.get_child(0) as CollisionShape3D).shape as BoxShape3D).size.x * 0.5
	assert_true(first_edge > gate_face and first_edge - gate_face < GameConfig.grid_cell_size,
		"column 0 starts %.1f m in front of the gate" % (first_edge - gate_face))
	assert_true(last_edge <= spawn_edge + 0.001 and spawn_edge - last_edge < GameConfig.grid_cell_size,
		"the last column ends %.1f m before spawn_zone" % (spawn_edge - last_edge))

	# Rules on the real level
	var bad_spawn := 0
	var bad_return := 0
	var bad_post := 0
	var bad_boss := 0
	var ret_r := ((ret.get_child(0) as CollisionShape3D).shape as CylinderShape3D).radius
	for c in valid:
		var p := GRID.cell_position(c)
		if p.x + half > spawn_edge + 0.001:
			bad_spawn += 1
		if _square_distance(p, ret.global_position) < ret_r - 0.001:
			bad_return += 1
		if _square_distance(p, post.global_position) < GameConfig.grid_min_gap_to_command_post - 0.001:
			bad_post += 1
		if _square_distance(p, boss) < GameConfig.boss_point_clear_radius - 0.001:
			bad_boss += 1
	assert_true(bad_spawn == 0, "no valid cell inside spawn_zone")
	assert_true(bad_return == 0, "no valid cell inside return_zone")
	assert_true(bad_post == 0, "no valid cell within %.0f m of command_post" % GameConfig.grid_min_gap_to_command_post)
	assert_true(bad_boss == 0, "no valid cell within %.1f m of boss_melee_point" % GameConfig.boss_point_clear_radius)
	# The holes are exactly the cells the rules would drop: none could be built, none is missing.
	var full := GRID.duplicate() as GridData
	full.holes = []
	var full_valid := full.get_valid_cells(spawn, ret, post, boss)
	var holes_ok := full_valid.size() == valid.size()
	for h in GRID.holes:
		holes_ok = holes_ok and full.check_cell(h, spawn, ret, post, boss) != ""
	assert_true(holes_ok, "the %d holes are exactly the cells in return_zone or the boss clear zone" % GRID.holes.size())
	assert_true(valid.has(Vector2i(0, 0)) and valid.has(Vector2i(0, 8)), "the wing cells next to the gate are buildable")

	# Each rule drops a cell that breaks it.
	var far := GRID.duplicate() as GridData
	far.columns = GRID.columns + 2
	assert_true(far.get_valid_cells(spawn, ret, post, boss).size() == valid.size(), "cells in spawn_zone are dropped")

	var wide := GRID.duplicate() as GridData
	wide.row_offsets = PackedFloat32Array([-11.0, 0.0, 11.0])
	var wide_valid := wide.get_valid_cells(spawn, ret, post, Vector3(100, 0, 0))
	assert_true(not wide_valid.has(Vector2i(4, 0)) and not wide_valid.has(Vector2i(4, 2)) and wide_valid.has(Vector2i(4, 1)),
		"cells crossing the corridor walls are dropped")

	var c4 := Vector2i(4, 4)
	assert_true(valid.has(c4), "%s is valid with the real markers" % GridData.cell_id(c4.x, c4.y))
	var c4_pos := GRID.cell_position(c4)
	assert_true(GRID.check_cell(c4, spawn, ret, post, c4_pos + Vector3(0, 0, 4.3)) == "", "a cell 3.3 m from the boss point is kept")
	assert_true(GRID.check_cell(c4, spawn, ret, post, c4_pos + Vector3(0, 0, 4.1)).ends_with("from boss_melee_point"),
		"a cell 3.1 m from the boss point is dropped")
	assert_true(GRID.check_cell(c4, spawn, ret, post, c4_pos + Vector3(4.1, 0, 0)) != "",
		"the boss clear zone is measured to the cell edge, not its centre")

	var moved_post := Node3D.new()
	add_child(moved_post)
	moved_post.global_position = c4_pos + Vector3(0, 0, 3.5)
	assert_true(GRID.check_cell(c4, spawn, ret, moved_post, boss).ends_with("from command_post"), "cells too close to command_post are dropped")
	moved_post.queue_free()

	var near := GRID.duplicate() as GridData
	near.origin = Vector3(-11, 0, 0)
	assert_true(not near.get_valid_cells(spawn, ret, post, boss).has(Vector2i(0, 4)), "cells in return_zone are dropped")

	# starter_arrow_slot: middle row, the column nearest the gate that is valid.
	var starter_col := -1
	for col in GRID.columns:
		if valid.has(Vector2i(col, GRID.middle_row())):
			starter_col = col
			break
	var expected := GridData.cell_id(starter_col, GRID.middle_row())
	assert_true(starter_col >= 0, "the middle row has a valid cell for starter_arrow_slot (%s)" % expected)
	var configured: Variant = GameConfig.get(&"starter_arrow_slot")
	if configured == null:
		print("  [SKIP] GameConfig has no starter_arrow_slot yet; it should be %s" % expected)
	else:
		assert_true(StringName(configured) == expected, "starter_arrow_slot is %s (GameConfig has %s)" % [expected, configured])

	# Robustness
	assert_true(GRID.cell_position(Vector2i(0, 99)) == GRID.origin, "out-of-range row falls back to origin")
	var empty_zone := Area3D.new()
	empty_zone.add_child(CollisionShape3D.new())
	add_child(empty_zone)
	assert_true(GRID.get_valid_cells(empty_zone, ret, post, boss).size() >= valid.size(), "zone without a shape is skipped, not a crash")
	empty_zone.queue_free()
	_finish(level)

func _square_distance(centre: Vector3, p: Vector3) -> float:
	var h := GameConfig.grid_cell_size * 0.5
	return Vector2(maxf(absf(p.x - centre.x) - h, 0.0), maxf(absf(p.z - centre.z) - h, 0.0)).length()

func _finish(level: Node) -> void:
	level.queue_free()
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
		printerr("  [FAIL] %s" % test_name)
