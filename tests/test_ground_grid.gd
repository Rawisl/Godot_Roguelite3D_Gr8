extends Node

## Automated test runner verifying GroundGrid in the corridor level:
## - one GROUND slot per valid GridData cell, named and slot_id'd G_c_r, at the cell centre
## - spawned before SlotManager collects, so SlotManager lists every cell and finds no problem
## - the 4 reference cells exist; the pick collider is 1.9 m for a 2 m cell
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
	var valid := grid.grid_data.get_valid_cells(grid.lane, grid.spawn_zone, grid.return_zone, grid.command_post)

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
	for ref in [&"G_0_1", &"G_0_2", &"G_1_1", &"G_1_2"]:
		assert_true(mgr.get_slot(ref) != null, "reference cell %s exists" % ref)

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
