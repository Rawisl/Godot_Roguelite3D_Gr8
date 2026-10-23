class_name GroundGrid
extends Node3D
## Spawns one GROUND slot per valid GridData cell when the level loads, before SlotManager
## collects its slots, and keeps them for the whole run. Cells that break the placement rules
## are dropped and logged by GridData. Slots are plain slot.tscn instances named by cell_id,
## kept outside the navmesh source group so the baked navmesh never changes.

@export var grid_data: GridData = preload("res://levels/corridor/grid_data.tres")
@export var slot_scene: PackedScene = preload("res://systems/build/slot.tscn")
## Level markers the cells are checked against.
@export var lane: Path3D
@export var spawn_zone: Area3D
@export var return_zone: Area3D
@export var command_post: Node3D

## cell_id -> Slot, filled once.
var cells: Dictionary = {}


## Runs before the parent SlotManager's _ready, which is when slots are collected.
func _ready() -> void:
	if grid_data == null or slot_scene == null:
		push_error("GroundGrid: grid_data or slot_scene is missing")
		return
	for cell in grid_data.get_valid_cells(lane, spawn_zone, return_zone, command_post):
		var id := GridData.cell_id(cell.x, cell.y)
		var slot := slot_scene.instantiate() as Slot
		slot.name = id
		slot.slot_id = id
		slot.zone = Enums.SlotZone.GROUND
		add_child(slot)
		# Identity basis: facing (basis x) points along the columns, toward spawn.
		slot.global_position = grid_data.cell_position(cell)
		cells[id] = slot
