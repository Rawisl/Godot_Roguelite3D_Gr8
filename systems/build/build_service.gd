class_name BuildService
extends Node
## Build transactions for the panels. Each call checks the wave state, the slot and
## the gold in the same frame and either finishes or changes nothing. Calls are
## synchronous, so one press can never spend gold twice.

@export var towers: Array[TowerData] = []
@export var tower_scenes: Dictionary[StringName, PackedScene] = {}

var _wave_state: StringName = &""

func _ready() -> void:
	add_to_group(&"build_service")
	EventBus.state_changed.connect(_on_state_changed)

func is_prep() -> bool:
	return _wave_state == &"PREP"

## Looks slots up by group so it works with or without a SlotManager in the level.
func find_slot(slot_id: StringName) -> Slot:
	for node in get_tree().get_nodes_in_group(&"slot"):
		var slot := node as Slot
		if slot != null and slot.slot_id == slot_id:
			return slot
	return null

func get_data(type: StringName) -> TowerData:
	for data in towers:
		if data.id == type:
			return data
	return null

func get_slot_position(slot_id: StringName) -> Vector3:
	var slot := find_slot(slot_id)
	return slot.global_position if slot != null else Vector3.ZERO

## Menu entries for the Build panel. Types the slot does not allow are left out.
## A ruined slot gets the rebuild entry first, at the level it had.
func get_build_options(slot_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var slot := find_slot(slot_id)
	var gold := _gold()
	if slot == null or gold == null or not slot.is_free():
		return result
	if slot.state == Enums.SlotState.RUINED and slot.last_data != null:
		var rebuild_cost := slot.get_rebuild_cost()
		result.append({"data": slot.last_data, "level": slot.last_level,
			"cost": rebuild_cost, "shortfall": gold.shortfall(rebuild_cost), "rebuild": true})
	for data in towers:
		if not slot.allows(data):
			continue
		var cost := data.get_total_cost(1)
		result.append({"data": data, "level": 1,
			"cost": cost, "shortfall": gold.shortfall(cost), "rebuild": false})
	return result

func build(slot_id: StringName, type: StringName, level: int = 1) -> bool:
	var slot := find_slot(slot_id)
	var data := get_data(type)
	var gold := _gold()
	if not is_prep() or slot == null or data == null or gold == null:
		return false
	if not tower_scenes.has(type) or not slot.can_build(data):
		return false
	var is_rebuild := level > 1
	if is_rebuild and not slot.can_rebuild(data):
		return false
	var cost := slot.get_rebuild_cost() if is_rebuild else data.get_total_cost(1)
	if not gold.try_spend(cost):
		EventBus.build_denied.emit(&"NOT_ENOUGH_GOLD", gold.shortfall(cost))
		return false
	var tower := tower_scenes[type].instantiate() as Tower
	slot.place_tower(tower)
	if is_rebuild:
		tower.apply_level(level)
	EventBus.tower_built.emit(slot_id, type)
	return true

func _gold() -> GoldManager:
	return get_tree().get_first_node_in_group(&"gold_manager") as GoldManager

func _on_state_changed(new_state: StringName) -> void:
	_wave_state = new_state
