class_name GroundGrid
extends Node3D
## Spawns one GROUND slot per valid GridData cell when the level loads, before SlotManager
## collects its slots, and keeps them for the whole run. Cells that break the placement rules
## are dropped and logged by GridData. Slots are plain slot.tscn instances named by cell_id,
## kept outside the navmesh source group so the baked navmesh never changes.

## Distance from the gate end of the lane to the Bulwark's fallback standing point.
const BOSS_POINT_FALLBACK_GAP := 1.8

@export var grid_data: GridData = preload("res://levels/corridor/grid_data.tres")
@export var slot_scene: PackedScene = preload("res://systems/build/slot.tscn")
## Level markers the cells are checked against.
@export var spawn_zone: Area3D
@export var return_zone: Area3D
@export var command_post: Node3D
## Where the Bulwark stands at the Fortress. Empty = the node in group "boss_melee_point".
@export var boss_melee_point: Node3D
## Only used when the level has no boss_melee_point: the fallback point is taken from the
## lane's gate end.
@export var lane: Path3D

## cell_id -> Slot, filled once.
var cells: Dictionary = {}


## Runs before the parent SlotManager's _ready, which is when slots are collected.
func _ready() -> void:
	if grid_data == null or slot_scene == null:
		push_error("GroundGrid: grid_data or slot_scene is missing")
		return
	for cell in get_valid_cells():
		var id := GridData.cell_id(cell.x, cell.y)
		var slot := slot_scene.instantiate() as Slot
		slot.name = id
		slot.slot_id = id
		slot.zone = Enums.SlotZone.GROUND
		add_child(slot)
		# Facing (basis x) points along the columns, toward spawn, on any map.
		slot.global_basis = Basis(grid_data.column_dir.normalized(), Vector3.UP, grid_data.row_dir())
		slot.global_position = grid_data.cell_position(cell)
		cells[id] = slot


## The cells of grid_data that pass the placement rules against this level's markers.
func get_valid_cells() -> Array[Vector2i]:
	return grid_data.get_valid_cells(spawn_zone, return_zone, command_post, get_boss_point())


## The Bulwark's standing point. Without a marker: on the lane, BOSS_POINT_FALLBACK_GAP from
## its gate end, and logged.
func get_boss_point() -> Vector3:
	var marker := boss_melee_point
	if marker == null and is_inside_tree():
		marker = get_tree().get_first_node_in_group(&"boss_melee_point") as Node3D
	if marker != null:
		return marker.global_position
	if lane == null or lane.curve == null or lane.curve.point_count == 0:
		push_error("GroundGrid: no boss_melee_point and no lane, the Bulwark clear zone sits at the grid origin")
		return grid_data.origin
	var gate_end := lane.global_transform * lane.curve.get_point_position(lane.curve.point_count - 1)
	var fallback := gate_end + grid_data.column_dir.normalized() * BOSS_POINT_FALLBACK_GAP
	push_error("GroundGrid: no boss_melee_point, using the fallback at %s" % fallback)
	return fallback
