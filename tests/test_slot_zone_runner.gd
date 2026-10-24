extends Node

## Automated test runner verifying:
## - SlotZone is only WALL and GROUND; corridor has 6 WALL slots + one GROUND slot per GridData cell
## - BLD-06: WALL menu has Arrow and Cannon only, GROUND menu has Arrow, Cannon, Barricade
## - Slot.allowed_types narrows the zone, never widens it
## - SLOT-05: missing W slot, wrong prefix and duplicate slot_id are logged on load

const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")
const SLOT_SCENE: PackedScene = preload("res://systems/build/slot.tscn")
const ARROW: TowerData = preload("res://data/towers/arrow.tres")
const CANNON: TowerData = preload("res://data/towers/cannon.tres")
const BARRICADE: TowerData = preload("res://data/towers/barricade.tres")

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED SLOT ZONE RUNNER TEST                 ")
	print("=======================================================")

	test_zone_enum()
	test_corridor_layout()
	test_buildable_types_by_zone()
	test_allowed_types_narrow_zone()
	test_layout_validation_logs()

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

func _ids(list: Array[TowerData]) -> String:
	var out: PackedStringArray = []
	for d in list:
		out.append(String(d.id))
	return ",".join(out)

func _make_slot(parent: Node, id: StringName, zone: Enums.SlotZone) -> Slot:
	var slot := SLOT_SCENE.instantiate() as Slot
	slot.name = String(id)
	slot.slot_id = id
	slot.zone = zone
	parent.add_child(slot)
	return slot

## require_walls = false skips the W1-W6 check for small hand-made layouts.
func _make_manager(root: Node, require_walls := true) -> SlotManager:
	var mgr := SlotManager.new()
	mgr.slot_root = root
	if not require_walls:
		mgr.required_wall_ids = []
	add_child(mgr)
	return mgr

func test_zone_enum() -> void:
	print("\n[GROUP 1] SlotZone has only WALL and GROUND (SRS 1.8)")
	assert_true(",".join(Enums.SlotZone.keys()) == "WALL,GROUND", "SlotZone keys are WALL, GROUND")
	var slot := SLOT_SCENE.instantiate() as Slot
	assert_true(slot.zone == Enums.SlotZone.GROUND, "a new slot defaults to GROUND")
	slot.free()

func test_corridor_layout() -> void:
	print("\n[GROUP 2] Corridor layout: 6 WALL + GridData GROUND cells (SLOT-05)")
	var level := LEVEL_SCENE.instantiate()
	add_child(level)
	var mgr := _make_manager(level)
	var cells: int = (level.get_node("Slots/GroundGrid") as GroundGrid).cells.size()
	assert_true(mgr.get_all_slots().size() == 6 + cells, "corridor has %d slots (got %d)" % [6 + cells, mgr.get_all_slots().size()])
	assert_true(mgr.get_slots_in_zone(Enums.SlotZone.WALL).size() == 6, "6 WALL slots")
	assert_true(mgr.get_slots_in_zone(Enums.SlotZone.GROUND).size() == cells, "%d GROUND slots, one per grid cell" % cells)
	assert_true(mgr.get_layout_problems().is_empty(), "no layout problems: %s" % ", ".join(mgr.get_layout_problems()))
	var order: PackedStringArray = []
	for s in mgr.get_all_slots():
		order.append(String(s.slot_id))
	assert_true(",".join(order.slice(0, 6)) == "W1,W2,W3,W4,W5,W6", "WALL slots listed first, W1..W6")
	mgr.free()
	level.free()

func test_buildable_types_by_zone() -> void:
	print("\n[GROUP 3] Build menu by zone (BLD-06)")
	var root := Node3D.new()
	add_child(root)
	_make_slot(root, &"W1", Enums.SlotZone.WALL)
	_make_slot(root, &"G_0_0", Enums.SlotZone.GROUND)
	var mgr := _make_manager(root, false)
	var all: Array[TowerData] = [ARROW, CANNON, BARRICADE]
	assert_true(_ids(mgr.get_buildable_types(&"W1", all)) == "arrow,cannon", "WALL: Arrow, Cannon, no Barricade")
	assert_true(_ids(mgr.get_buildable_types(&"G_0_0", all)) == "arrow,cannon,barricade", "GROUND: Arrow, Cannon, Barricade")
	assert_true(not mgr.get_slot(&"W1").can_build(BARRICADE), "Barricade cannot be built on W1")
	mgr.get_slot(&"G_0_0").set_state(Enums.SlotState.OCCUPIED)
	assert_true(mgr.get_buildable_types(&"G_0_0", all).is_empty(), "OCCUPIED slot offers nothing")
	mgr.free()
	root.free()

func test_allowed_types_narrow_zone() -> void:
	print("\n[GROUP 4] allowed_types narrows the zone")
	var root := Node3D.new()
	add_child(root)
	var g := _make_slot(root, &"G_1_0", Enums.SlotZone.GROUND)
	g.allowed_types = [&"arrow"]
	var w := _make_slot(root, &"W1", Enums.SlotZone.WALL)
	w.allowed_types = [&"barricade", &"cannon"]
	var mgr := _make_manager(root, false)
	var all: Array[TowerData] = [ARROW, CANNON, BARRICADE]
	assert_true(_ids(mgr.get_buildable_types(&"G_1_0", all)) == "arrow", "GROUND slot limited to Arrow")
	assert_true(_ids(mgr.get_buildable_types(&"W1", all)) == "cannon", "WALL slot listing Barricade still refuses it")
	mgr.free()
	root.free()

func test_layout_validation_logs() -> void:
	print("\n[GROUP 5] Load-time checks (SLOT-05 [LOG])")
	var root := Node3D.new()
	add_child(root)
	for i in range(1, 6):  # W6 left out on purpose
		_make_slot(root, StringName("W%d" % i), Enums.SlotZone.WALL)
	_make_slot(root, &"G_0_0", Enums.SlotZone.WALL)   # G prefix on a WALL slot
	_make_slot(root, &"W3", Enums.SlotZone.WALL).name = "W3_copy"  # duplicate id
	_make_slot(root, &"X1", Enums.SlotZone.GROUND)    # unknown prefix
	_make_slot(root, &"G_2_0", 2 as Enums.SlotZone)   # old FAR value left in a scene
	var mgr := _make_manager(root)
	var problems := "\n".join(mgr.get_layout_problems())
	assert_true("missing slot 'W6'" in problems, "missing W6 is logged")
	assert_true("duplicate slot_id 'W3'" in problems, "duplicate W3 is logged")
	assert_true("slot 'G_0_0' has zone WALL, expected GROUND" in problems, "G prefix on WALL is logged")
	assert_true("slot 'X1' has unknown prefix" in problems, "unknown prefix is logged")
	assert_true("slot 'G_2_0' has invalid zone value 2" in problems, "old NEAR/FAR value is logged")
	assert_true(mgr.get_all_slots().size() == 8, "duplicate is skipped, 8 slots kept")
	mgr.free()
	root.free()
