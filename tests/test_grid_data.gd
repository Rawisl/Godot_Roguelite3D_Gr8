extends Node

## Automated test runner verifying the corridor GridData:
## - cell_id is G_c_r, unique, and the 4 reference cells exist
## - no cell lies in no_build_lane, spawn_zone or return_zone, or near command_post
## - no_build_lane is wide enough for the corridor
## - cells sit inside the walls and do not overlap
## - a bad cell is dropped on load

const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")
const GRID: GridData = preload("res://levels/corridor/grid_data.tres")

@export var quit_when_done := true

var passes: int = 0
var fails: int = 0

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED GRID DATA TEST                        ")
	print("=======================================================")

	var level: Node3D = LEVEL_SCENE.instantiate()
	add_child(level)
	var lane: Path3D = level.get_node("LaneCurve")
	var spawn: Area3D = level.get_node("SpawnZone")
	var ret: Area3D = level.get_node("Markers/ReturnZone")
	var post: Node3D = level.get_node("Markers/CommandPost")

	var cells := GRID.get_cells()
	var valid := GRID.get_valid_cells(lane, spawn, ret, post)
	assert_true(cells.size() > 0, "GridData declares cells (%d)" % cells.size())
	assert_true(valid.size() == cells.size(), "every declared cell is valid (%d/%d)" % [valid.size(), cells.size()])

	var ids := {}
	for c in cells:
		ids[GridData.cell_id(c.x, c.y)] = true
	assert_true(ids.size() == cells.size(), "cell_ids are unique")
	for ref in [&"G_0_1", &"G_0_2", &"G_1_1", &"G_1_2"]:
		assert_true(ids.has(ref), "reference cell %s exists" % ref)

	var min_lane := maxf(GameConfig.no_build_lane_min_width, GameConfig.no_build_lane_min_ratio * GRID.corridor_width)
	assert_true(GRID.no_build_lane_width >= min_lane, "no_build_lane %.1f m >= %.1f m" % [GRID.no_build_lane_width, min_lane])

	var lane_side_ok := true
	for r in [1, 2]:
		var edge := absf(GRID.row_offsets[r]) - GameConfig.grid_cell_size * 0.5
		lane_side_ok = lane_side_ok and is_equal_approx(edge, GRID.no_build_lane_width * 0.5)
	assert_true(lane_side_ok, "rows 1 and 2 border no_build_lane")

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

	var bad := GRID.duplicate() as GridData
	bad.row_offsets = PackedFloat32Array([-6, -1, 4, 6])
	var bad_valid := bad.get_valid_cells(lane, spawn, ret, post)
	assert_true(bad_valid.size() == cells.size() - GRID.columns, "cells in no_build_lane are dropped")

	var far := GRID.duplicate() as GridData
	far.columns = 10
	assert_true(far.get_valid_cells(lane, spawn, ret, post).size() == cells.size(), "cells in spawn_zone are dropped")

	var near := GRID.duplicate() as GridData
	near.origin = Vector3(-11, 0, 0)
	var near_valid := near.get_valid_cells(lane, spawn, ret, post)
	assert_true(not near_valid.has(Vector2i(0, 1)), "cells in return_zone are dropped")

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
