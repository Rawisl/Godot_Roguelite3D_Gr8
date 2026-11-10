extends Node

## Automated test runner verifying GroundGrid in the corridor level:
## - one GROUND slot per valid GridData cell, named and slot_id'd G_c_r, at the cell centre
## - spawned before SlotManager collects, so SlotManager lists every cell and finds no problem
## - all 9 rows have slots, none in the clear zone around boss_melee_point (or its fallback)
## - the pick collider is 1.9 m for a 2 m cell
## - grid slots sit outside the navmesh source group, so the baked navmesh is unchanged
## - slots stay the same nodes across a run reset

const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")

@export var quit_when_done := true

var passes: int = 0
var fails: int = 0

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED GROUND GRID TEST                      ")
	print("=======================================================")

	var level: Node3D = LEVEL_SCENE.instantiate()
	add_child(level)
	var grid: GroundGrid = level.get_node("Slots/GroundGrid")
	var mgr: SlotManager = level.get_node("Slots")
	var valid := grid.get_valid_cells()

	assert_true(grid.cells.size() == valid.size() and valid.size() > 0, "one slot per valid cell (%d)" % valid.size())
	var ground := mgr.get_slots_in_zone(Enums.SlotZone.GROUND)
	assert_true(ground.size() == valid.size(), "SlotManager lists every grid slot (%d)" % ground.size())
	assert_true(mgr.get_layout_problems().is_empty(), "no layout problems: %s" % ", ".join(mgr.get_layout_problems()))

	var placed_ok := true
	for cell in valid:
		var id := GridData.cell_id(cell.x, cell.y)
		var slot := mgr.get_slot(id)
		placed_ok = placed_ok and slot != null and slot.name == id and slot.zone == Enums.SlotZone.GROUND \
				and slot.global_position.is_equal_approx(grid.grid_data.cell_position(cell)) \
				and slot.facing.is_equal_approx(grid.grid_data.column_dir.normalized())
	assert_true(placed_ok, "every slot is G_c_r, GROUND, at its cell centre, facing along the columns")
	var marker := level.get_node("Markers/BossMeleePoint") as Node3D
	assert_true(grid.get_boss_point().is_equal_approx(marker.global_position), "the clear zone is centred on boss_melee_point")
	var near_boss := 0
	var half := GameConfig.grid_cell_size * 0.5
	for slot in mgr.get_slots_in_zone(Enums.SlotZone.GROUND):
		var d := slot.global_position - marker.global_position
		var gap := Vector2(maxf(absf(d.x) - half, 0.0), maxf(absf(d.z) - half, 0.0)).length()
		if gap < GameConfig.boss_point_clear_radius - 0.001:
			near_boss += 1
	assert_true(near_boss == 0, "no grid slot within %.1f m of boss_melee_point" % GameConfig.boss_point_clear_radius)
	var rows := {}
	for cell in valid:
		rows[cell.y] = true
	assert_true(rows.size() == 9, "grid slots cover all 9 rows")

	# Without the marker the clear zone moves to the fallback on the lane, 1.8 m from its gate end.
	var bare := GroundGrid.new()
	bare.grid_data = grid.grid_data
	bare.lane = grid.lane
	var fallback := bare.get_boss_point()
	assert_true(fallback.distance_to(Vector3(-13.2, 0, 0)) < 0.01, "fallback point is 1.8 m in front of the lane's gate end (%s)" % fallback)
	bare.free()

	var pick := ground[0].get_node("ClickArea/CollisionShape3D") as CollisionShape3D
	var box := pick.shape as BoxShape3D
	assert_true(box != null and is_equal_approx(box.size.x, GameConfig.grid_pick_size) and is_equal_approx(box.size.z, GameConfig.grid_pick_size),
		"pick collider is %.1f m" % GameConfig.grid_pick_size)

	var in_nav := false
	for slot in ground:
		var n: Node = slot
		while n != null:
			if n.is_in_group(&"nav_source"):
				in_nav = true
			n = n.get_parent()
	assert_true(not in_nav, "no grid slot is inside the navmesh source group")

	var before := ground.duplicate()
	mgr.reset_all()
	mgr.reload_slots()
	var after := mgr.get_slots_in_zone(Enums.SlotZone.GROUND)
	var same := before.size() == after.size()
	for i in mini(before.size(), after.size()):
		same = same and before[i] == after[i]
	assert_true(same, "grid slots are the same nodes after a run reset")

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
