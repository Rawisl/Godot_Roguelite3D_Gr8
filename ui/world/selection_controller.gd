class_name SelectionController
extends Node
## Picks towers and slots with a ray on the click layer only, so walls and faded
## meshes never block a click. GUI controls get the mouse first because picking
## runs in _unhandled_input. Also reports what is under the mouse for hover feedback.

signal selection_cleared
signal fortress_selected
signal hovered_changed(node: Node)

const CLICK_LAYER := 1 << 6
const ENEMY_LAYER := 1 << 2
const RAY_LENGTH := 300.0
const MAX_HITS := 4
const FORTRESS_ID := &"FORTRESS"

var selected_slot: StringName = &""
var hovered: Node = null

var _mode: StringName = &"FRONTLINE"
var _rings_visible := false
var _hovered_slot: Slot = null
var _selected_ring: Slot = null

func _ready() -> void:
	# Building is allowed while paused in PREP.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hovered_changed.connect(_on_hovered_changed)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.mode_changed.connect(_on_mode_changed)
	# The first PREP is sent before the HUD is ready, so read it once here.
	_sync_rings.call_deferred()

## Hover follows the same order as clicks: tower, then slot, then enemy.
func _process(_delta: float) -> void:
	var node: Node = null
	if not _is_mouse_over_ui():
		node = pick_under_mouse()
		if node == null:
			node = _pick_enemy()
	if node != hovered:
		hovered = node
		hovered_changed.emit(node)

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
	_set_selected_ring(null)
	if selected_slot == &"":
		return
	selected_slot = &""
	selection_cleared.emit()

func _pick_enemy() -> Enemy:
	var viewport := get_viewport()
	var cam := viewport.get_camera_3d()
	if cam == null:
		return null
	var mouse := viewport.get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(
		from, from + cam.project_ray_normal(mouse) * RAY_LENGTH, ENEMY_LAYER)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var enemy := hit.collider as Enemy
	return enemy if enemy != null and not enemy.is_dead else null

func _is_mouse_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null

func _select(node: Node) -> void:
	if node is Tower:
		_select_tower(_slot_of(node))
	elif node is Slot:
		var slot := node as Slot
		if slot.state == Enums.SlotState.OCCUPIED:
			_select_tower(slot)
		elif _is_prep() and _rings_visible:
			selected_slot = slot.slot_id
			_set_selected_ring(slot)
			EventBus.slot_selected.emit(slot.slot_id)
	elif node is Fortress and _is_prep():
		selected_slot = FORTRESS_ID
		_set_selected_ring(null)
		fortress_selected.emit()
	else:
		clear_selection()

func _select_tower(slot: Slot) -> void:
	if slot == null:
		return
	selected_slot = slot.slot_id
	_set_selected_ring(null)
	EventBus.tower_selected.emit(slot.slot_id)

## One golden ring at a time: the empty slot picked for building.
func _set_selected_ring(slot: Slot) -> void:
	if is_instance_valid(_selected_ring):
		_selected_ring.set_selected(false)
	_selected_ring = slot
	if slot != null:
		slot.set_selected(true)

## Slot rings glow white under the mouse; uses the hover pick above, only while rings show.
func _on_hovered_changed(_node: Node) -> void:
	_update_slot_hover()

func _update_slot_hover() -> void:
	var slot := hovered as Slot if is_instance_valid(hovered) else null
	if not _rings_visible or (slot != null and not slot.is_free()):
		slot = null
	if slot == _hovered_slot:
		return
	if is_instance_valid(_hovered_slot):
		_hovered_slot.set_hovered(false)
	_hovered_slot = slot
	if slot != null:
		slot.set_hovered(true)

func _rank(node: Node) -> int:
	if node is Tower:
		return 0
	# An empty slot only counts while the rings show, so the Fortress roof under it stays clickable.
	if node is Slot:
		return 2 if _rings_visible or not (node as Slot).is_free() else 99
	# Wall slots sit on the Fortress roof, so the Fortress loses to any slot that counts.
	if node is Fortress:
		return 3
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
	_update_slot_hover()

func _sync_rings() -> void:
	_set_rings_visible(_is_prep())

func _on_state_changed(new_state: StringName) -> void:
	_set_rings_visible(new_state == &"PREP")

func _on_mode_changed(mode: StringName) -> void:
	_mode = mode
