class_name Slot
extends Node3D
## A fixed build position on the map (SRS 3.6.2).

signal clicked(slot: Slot)
signal state_changed(slot: Slot, new_state: Enums.SlotState)

@export var slot_id: StringName
@export var zone: Enums.SlotZone = Enums.SlotZone.NEAR

var state: Enums.SlotState = Enums.SlotState.EMPTY
var tower: Tower = null

## Tower that was destroyed here; only set while RUINED (Rebuild, alerts, SUMMARY).
var last_data: TowerData = null
## Level of that tower; Rebuild restores the same type at this level.
var last_level: int = 0

var facing: Vector3:
	get: return global_basis.x

@onready var marker: MeshInstance3D = %Marker
@onready var click_area: Area3D = %ClickArea
@onready var anchor: Marker3D = %TowerAnchor
@onready var rubble: StaticBody3D = %Rubble
@onready var rubble_shape: CollisionShape3D = %RubbleShape
@onready var rubble_obstacle: NavigationObstacle3D = %RubbleObstacle

func _ready() -> void:
	add_to_group("slot")
	click_area.input_event.connect(_on_input_event)

	if slot_id == &"":
		slot_id = StringName(name)

	_apply_state_visuals()
	set_buildable_visible(false)

func _on_input_event(_cam, event: InputEvent, _pos, _normal, _idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)

# SLOT-01: each slot holds at most one structure; states EMPTY / OCCUPIED / RUINED
func set_state(new_state: Enums.SlotState) -> void:
	if new_state == state:
		return
	state = new_state
	if state != Enums.SlotState.OCCUPIED:
		_free_tower()
	if state != Enums.SlotState.RUINED:
		last_data = null
		last_level = 0
	_apply_state_visuals()
	state_changed.emit(self, state)
	EventBus.slot_state_changed.emit(slot_id, StringName(Enums.SlotState.keys()[state]))

func place_tower(t: Tower) -> void:
	if not is_free():
		push_warning("Slot %s: place_tower called while OCCUPIED" % slot_id)
		return
	anchor.add_child(t)
	t.transform = Transform3D.IDENTITY
	tower = t
	t.destroyed.connect(_on_tower_destroyed)
	set_state(Enums.SlotState.OCCUPIED)

# SELL-03: selling returns the slot to EMPTY
func clear_tower() -> void:
	set_state(Enums.SlotState.EMPTY)

# TWR-02, SLOT-02: a tower at 0 HP leaves rubble, the slot becomes RUINED
func _on_tower_destroyed(_t: Tower) -> void:
	ruin()

## Single entry point for destroying the tower here: HP = 0 and Overload (TWR-08) both call this.
## Remembers type and level before the tower is freed so Rebuild can restore them.
func ruin() -> void:
	if state != Enums.SlotState.OCCUPIED or tower == null:
		return
	var data := tower.data
	var level := tower.level
	set_state(Enums.SlotState.RUINED)
	last_data = data
	last_level = level
	EventBus.tower_destroyed.emit(slot_id)

## Rebuild only applies to the same tower type that was destroyed here.
## This feature may be apply after MVP
## A different type is a normal level 1 build.
func can_rebuild(data: TowerData) -> bool:
	return (state == Enums.SlotState.RUINED and last_data != null
		and data != null and data.id == last_data.id)

## Rebuild price: build + all upgrades up to last_level, from TowerData (not invested_gold, SELL-04).
func get_rebuild_cost() -> int:
	if last_data == null:
		return 0
	return last_data.get_total_cost(last_level)

func _free_tower() -> void:
	if tower != null and is_instance_valid(tower):
		if tower.destroyed.is_connected(_on_tower_destroyed):
			tower.destroyed.disconnect(_on_tower_destroyed)
		tower.queue_free()
	tower = null

# SLOT-02: RUINED behaves like an empty slot
func is_free() -> bool:
	return (state == Enums.SlotState.EMPTY 
		or state == Enums.SlotState.RUINED)

func allows(data: TowerData) -> bool:
	return data != null and zone in data.allowed_zones

func can_build(data: TowerData) -> bool:
	return is_free() and allows(data)

# SLOT-06: the ring only shows on slots that can still be built on
func set_buildable_visible(v: bool) -> void:
	marker.visible = v and is_free()

# SLOT-02: RUINED shows rubble. Rubble blocks movement and is avoided by agents (SLOT-03).
func _apply_state_visuals() -> void:
	var ruined := state == Enums.SlotState.RUINED
	rubble.visible = ruined
	# Deferred: the state can change inside a physics callback (tower killed by a hit)
	rubble_shape.set_deferred(&"disabled", not ruined)
	rubble_obstacle.avoidance_enabled = ruined
