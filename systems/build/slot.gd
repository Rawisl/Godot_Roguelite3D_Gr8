class_name Slot
extends Node3D

signal clicked(slot: Slot)

@export var slot_id: StringName
@export var zone: SlotZone.Zone = SlotZone.Zone.NEAR
@export var allowed_types: Array[StringName] = []

var state: SlotZone.State = SlotZone.State.EMPTY
var tower: Tower = null

@onready var marker: MeshInstance3D = %Marker
@onready var click_area: Area3D = %ClickArea
@onready var anchor: Marker3D = %TowerAnchor

func _ready() -> void:
	add_to_group("slot")
	click_area.input_event.connect(_on_input_event)
	set_buildable_visible(false)
	
	if slot_id == &"":
		slot_id = StringName(name)

func _on_input_event(_cam, event: InputEvent, _pos, _normal, _idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)

func set_buildable_visible(v: bool) -> void:
	marker.visible = v and state == SlotZone.State.EMPTY

func can_build(data: TowerData) -> bool:
	return state == SlotZone.State.EMPTY and zone in data.allowed_zones
