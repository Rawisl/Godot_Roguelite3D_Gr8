class_name PanelHost
extends Control
## Shows one panel at a time and closes it when PREP ends, on Esc, on an early
## wave call or when the selection is cleared.

@onready var _build_panel: BuildPanel = %BuildPanel
@onready var _selection: SelectionController = %SelectionController
@onready var _ring: RangeRing = %RangeRing

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_panel.visible = false
	_build_panel.closed.connect(close_all)
	_build_panel.preview_requested.connect(_on_preview_requested)
	_build_panel.preview_cleared.connect(_ring.hide_ring)
	_selection.selection_cleared.connect(close_all)
	EventBus.slot_selected.connect(_on_slot_selected)
	EventBus.tower_selected.connect(_on_tower_selected)
	EventBus.tower_built.connect(_on_tower_built)
	EventBus.state_changed.connect(_on_state_changed)
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
	_ring.hide_ring()

func _any_open() -> bool:
	return _build_panel.visible

## Only selections made by SelectionController open the Build panel, and only in PREP.
func _on_slot_selected(slot_id: StringName) -> void:
	var service := get_tree().get_first_node_in_group(&"build_service") as BuildService
	if service == null or not service.is_prep() or _selection.selected_slot != slot_id:
		return
	_hide_panels()
	_build_panel.visible = true
	_build_panel.open(slot_id)

func _on_tower_selected(_slot_id: StringName) -> void:
	_hide_panels()

func _on_tower_built(slot_id: StringName, _type: StringName) -> void:
	if _build_panel.visible and slot_id == _build_panel.slot_id:
		close_all()

func _on_state_changed(new_state: StringName) -> void:
	if new_state != &"PREP":
		close_all()

func _on_preview_requested(slot_id: StringName, radius: float) -> void:
	var service := get_tree().get_first_node_in_group(&"build_service") as BuildService
	if service == null or radius <= 0.0:
		_ring.hide_ring()
		return
	_ring.show_at(service.get_slot_position(slot_id), radius)
