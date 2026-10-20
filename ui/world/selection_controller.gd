class_name SelectionController
extends Node
## Picks towers and slots with a ray on the click layer only, so walls and faded
## meshes never block a click. GUI controls get the mouse first because picking
## runs in _unhandled_input.

signal selection_cleared

const CLICK_LAYER := 1 << 6
const RAY_LENGTH := 300.0
const MAX_HITS := 4

var selected_slot: StringName = &""

var _mode: StringName = &"FRONTLINE"
var _rings_visible := false

func _ready() -> void:
	# Building is allowed while paused in PREP.
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.mode_changed.connect(_on_mode_changed)
	# The first PREP is sent before the HUD is ready, so read it once here.
	_sync_rings.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"select") and _can_select():
		var node := pick_under_mouse()
		_select(node)
		if node != null:
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"cancel") and selected_slot != &"":
		clear_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"build_toggle") and _is_prep():
		_set_rings_visible(not _rings_visible)
		get_viewport().set_input_as_handled()

## Tower first, then slot. Several hits are read so a slot under a tower still loses to it.
func pick_under_mouse() -> Node:
	var viewport := get_viewport()
	var cam := viewport.get_camera_3d()
	if cam == null:
		return null
	var mouse := viewport.get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(
		from, from + cam.project_ray_normal(mouse) * RAY_LENGTH, CLICK_LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var space := cam.get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	var best: Node = null
	var best_rank := 99
	for i in MAX_HITS:
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		exclude.append(hit.rid)
		var owner_node := (hit.collider as Node).get_parent()
		var rank := _rank(owner_node)
		if rank < best_rank:
			best = owner_node
			best_rank = rank
	return best

func clear_selection() -> void:
	if selected_slot == &"":
		return
	selected_slot = &""
	selection_cleared.emit()

func _select(node: Node) -> void:
	if node is Tower:
		_select_tower(_slot_of(node))
	elif node is Slot:
		var slot := node as Slot
		if slot.state == Enums.SlotState.OCCUPIED:
			_select_tower(slot)
		elif _is_prep():
			selected_slot = slot.slot_id
			EventBus.slot_selected.emit(slot.slot_id)
	else:
		clear_selection()

func _select_tower(slot: Slot) -> void:
	if slot == null:
		return
	selected_slot = slot.slot_id
	EventBus.tower_selected.emit(slot.slot_id)

func _rank(node: Node) -> int:
	if node is Tower:
		return 0
	if node is Slot:
		return 2
	return 99

func _slot_of(node: Node) -> Slot:
	var p := node.get_parent()
	while p != null and not (p is Slot):
		p = p.get_parent()
	return p as Slot

## Left click is the attack in Frontline, so selecting works in PREP or Commander mode.
func _can_select() -> bool:
	return _is_prep() or _mode == &"COMMANDER"

func _is_prep() -> bool:
	var service := get_tree().get_first_node_in_group(&"build_service") as BuildService
	return service != null and service.is_prep()

func _set_rings_visible(v: bool) -> void:
	_rings_visible = v
	get_tree().call_group(&"slot", &"set_buildable_visible", v)

func _sync_rings() -> void:
	_set_rings_visible(_is_prep())

func _on_state_changed(new_state: StringName) -> void:
	_set_rings_visible(new_state == &"PREP")

func _on_mode_changed(mode: StringName) -> void:
	_mode = mode
