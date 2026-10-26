class_name PriorityPanel
extends VBoxContainer
## First / Nearest choice for the selected tower. Shown in PREP and in Commander mode.

signal changed

const BUTTON_LOCK_TIME := 0.15

var slot_id: StringName = &""
var _locked := false
var _shown: int = -1

@onready var _heading: Label = %PriorityHeading
@onready var _first: Button = %FirstButton
@onready var _nearest: Button = %NearestButton

func _ready() -> void:
	_heading.text = tr(&"panel.tower.priority")
	_first.text = tr(&"panel.priority.first")
	_nearest.text = tr(&"panel.priority.nearest")
	_first.pressed.connect(_on_pressed.bind(Enums.TargetPriority.FIRST))
	_nearest.pressed.connect(_on_pressed.bind(Enums.TargetPriority.NEAREST))
	EventBus.tower_priority_changed.connect(_on_priority_changed)

## Called by the Tower panel on every refresh.
func refresh(id: StringName, info: Dictionary, service: BuildService) -> void:
	if id != slot_id:
		slot_id = id
		_shown = -1
	visible = info.can_target and (service.is_prep() or service.is_commander_mode())
	var can_change := service.can_change_priority()
	for b: Button in [_first, _nearest]:
		b.disabled = not can_change
		b.tooltip_text = "" if can_change else tr(&"panel.priority.paused")
	var current: int = _shown if _shown >= 0 else info.priority
	_first.set_pressed_no_signal(current == Enums.TargetPriority.FIRST)
	_nearest.set_pressed_no_signal(current == Enums.TargetPriority.NEAREST)

## A refused change still re-syncs, so a toggle button never stays wrongly pressed.
func _on_pressed(priority: Enums.TargetPriority) -> void:
	var service := get_tree().get_first_node_in_group(&"build_service") as BuildService
	if service != null and _try_lock():
		service.set_priority(slot_id, priority)
	changed.emit()

func _on_priority_changed(id: StringName, priority: StringName) -> void:
	if id == slot_id:
		_shown = Enums.TargetPriority.get(String(priority), -1)
		changed.emit()

func _try_lock() -> bool:
	if _locked:
		return false
	_locked = true
	_unlock_later()
	return true

func _unlock_later() -> void:
	await TimeManager.wait_real(BUTTON_LOCK_TIME)
	_locked = false
