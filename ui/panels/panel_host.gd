class_name PanelHost
extends Control
## Shows one panel at a time. The Build panel lives only in PREP; the Tower panel
## also stays open in combat while the commander is in Commander mode.

@onready var _build_panel: BuildPanel = %BuildPanel
@onready var _tower_panel: TowerPanel = %TowerPanel
@onready var _selection: SelectionController = %SelectionController
@onready var _ring: RangeRing = %RangeRing

var _mode: StringName = &"FRONTLINE"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_panel.visible = false
	_tower_panel.visible = false
	_build_panel.closed.connect(close_all)
	_build_panel.preview_requested.connect(_on_preview_requested)
	_build_panel.preview_cleared.connect(_ring.hide_ring)
	_tower_panel.closed.connect(close_all)
	_selection.selection_cleared.connect(close_all)
	EventBus.slot_selected.connect(_on_slot_selected)
	EventBus.tower_selected.connect(_on_tower_selected)
	EventBus.tower_built.connect(_on_tower_built)
	EventBus.tower_upgraded.connect(_on_tower_upgraded)
	EventBus.tower_sold.connect(_on_tower_sold)
	EventBus.tower_destroyed.connect(_on_tower_destroyed)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.mode_changed.connect(_on_mode_changed)
	EventBus.early_call_requested.connect(close_all)

## Runs before GameState in the tree order, so Esc closes the panel before opening Pause.
## While the pause menu is open, Esc belongs to it.
func _unhandled_input(event: InputEvent) -> void:
	if TimeManager.has_pause_reason(TimeManager.REASON_USER):
		return
	if event.is_action_pressed(&"pause") and _any_open():
		close_all()
		get_viewport().set_input_as_handled()

func close_all() -> void:
	_hide_panels()
	_selection.clear_selection()

func _hide_panels() -> void:
	_build_panel.visible = false
	_tower_panel.visible = false
	_ring.hide_ring()

func _any_open() -> bool:
	return _build_panel.visible or _tower_panel.visible

func _show_build(slot_id: StringName) -> void:
	_hide_panels()
	_build_panel.visible = true
	_build_panel.open(slot_id)

func _show_tower(slot_id: StringName) -> void:
	_hide_panels()
	_tower_panel.visible = true
	_tower_panel.open(slot_id)
	_show_tower_ring(slot_id)

func _show_tower_ring(slot_id: StringName) -> void:
	var service := _service()
	if service == null:
		return
	var info := service.get_tower_info(slot_id)
	if info.is_empty() or info.range <= 0.0:
		_ring.hide_ring()
		return
	_ring.show_at(service.get_slot_position(slot_id), info.range)

## Only selections made by SelectionController open the Build panel, and only in PREP.
func _on_slot_selected(slot_id: StringName) -> void:
	var service := _service()
	if service == null or not service.is_prep() or _selection.selected_slot != slot_id:
		return
	_show_build(slot_id)

func _on_tower_selected(slot_id: StringName) -> void:
	_show_tower(slot_id)

## The panel stays open after a transaction: building switches to the new tower.
func _on_tower_built(slot_id: StringName, _type: StringName) -> void:
	if _build_panel.visible and slot_id == _build_panel.slot_id:
		_show_tower(slot_id)

func _on_tower_upgraded(slot_id: StringName, _type: StringName, _level: int) -> void:
	if _tower_panel.visible and slot_id == _tower_panel.slot_id:
		_show_tower_ring(slot_id)

## Selling switches back to the Build panel of the now empty slot.
func _on_tower_sold(slot_id: StringName) -> void:
	if _tower_panel.visible and slot_id == _tower_panel.slot_id:
		_show_build(slot_id)

func _on_tower_destroyed(slot_id: StringName) -> void:
	if _tower_panel.visible and slot_id == _tower_panel.slot_id:
		close_all()

func _on_state_changed(new_state: StringName) -> void:
	if new_state == &"PREP":
		return
	if _tower_panel.visible and _mode == &"COMMANDER":
		return
	close_all()

func _on_mode_changed(mode: StringName) -> void:
	_mode = mode
	var service := _service()
	if service != null and not service.is_prep() and mode != &"COMMANDER" and _any_open():
		close_all()

func _on_preview_requested(slot_id: StringName, radius: float) -> void:
	var service := _service()
	if service == null or radius <= 0.0:
		_ring.hide_ring()
		return
	_ring.show_at(service.get_slot_position(slot_id), radius)

func _service() -> BuildService:
	return get_tree().get_first_node_in_group(&"build_service") as BuildService
