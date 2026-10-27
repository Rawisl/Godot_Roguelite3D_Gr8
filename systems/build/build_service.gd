class_name BuildService
extends Node
## Build, upgrade and sell for the panels. Each call checks the wave state, the slot and
## the gold in the same frame and either finishes or changes nothing. Calls are
## synchronous, so one press can never spend gold twice.

@export var towers: Array[TowerData] = []
@export var tower_scenes: Dictionary[StringName, PackedScene] = {}

var _wave_state: StringName = &""
var _mode: StringName = &"FRONTLINE"
var _busy: Dictionary[StringName, bool] = {}  # slot_id -> true while a transaction runs

func _ready() -> void:
	add_to_group(&"build_service")
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.mode_changed.connect(_on_mode_changed)
	EventBus.run_started.connect(_on_run_started)

func is_prep() -> bool:
	return _wave_state == &"PREP"

func is_commander_mode() -> bool:
	return _mode == &"COMMANDER"

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
	if not _begin(slot_id):
		return false
	var ok := _do_build(slot_id, type, level)
	_end(slot_id)
	return ok

func _do_build(slot_id: StringName, type: StringName, level: int) -> bool:
	var slot := find_slot(slot_id)
	var data := get_data(type)
	var gold := _gold()
	if not is_prep() or slot == null or data == null or gold == null:
		return false
	if level < 1 or level > data.levels.size():
		return false
	if not tower_scenes.has(type) or not slot.can_build(data):
		return false
	# A level above 1 is only a rebuild of the tower that stood here, at the level it had.
	var is_rebuild := level > 1
	if is_rebuild and not (slot.can_rebuild(data) and level == slot.last_level):
		return false
	var cost := slot.get_rebuild_cost() if is_rebuild else data.get_total_cost(1)
	if not gold.try_spend(cost):
		EventBus.build_denied.emit(&"NOT_ENOUGH_GOLD", gold.shortfall(cost))
		return false
	var tower := tower_scenes[type].instantiate() as Tower
	slot.place_tower(tower)
	if is_rebuild:
		tower.apply_level(level)
	tower.invested_gold = cost
	EventBus.tower_built.emit(slot_id, type)
	return true

## Everything the Tower panel shows. Empty when the slot holds no tower.
func get_tower_info(slot_id: StringName) -> Dictionary:
	var slot := find_slot(slot_id)
	var gold := _gold()
	if slot == null or gold == null or slot.state != Enums.SlotState.OCCUPIED or slot.tower == null:
		return {}
	var t := slot.tower
	var lv: TowerLevelData = t.data.levels[t.level - 1]
	var info := {
		"data": t.data,
		"level": t.level,
		"hp": t.health.hp,
		"max_hp": t.health.max_hp,
		"range": lv.attack_range,
		"priority": t.priority,
		"can_target": t.can_attack(),
		"is_max": t.level >= t.data.levels.size(),
		"sell_value": floori(float(t.invested_gold) * GameConfig.sell_refund_pct),
	}
	if not info.is_max:
		var cost: int = t.data.levels[t.level].build_cost
		info["upgrade_cost"] = cost
		info["upgrade_shortfall"] = gold.shortfall(cost)
	return info

func upgrade(slot_id: StringName) -> bool:
	if not _begin(slot_id):
		return false
	var ok := _do_upgrade(slot_id)
	_end(slot_id)
	return ok

func _do_upgrade(slot_id: StringName) -> bool:
	var slot := find_slot(slot_id)
	var gold := _gold()
	if not is_prep() or slot == null or gold == null or slot.state != Enums.SlotState.OCCUPIED:
		return false
	var t := slot.tower
	if t == null or t.level >= t.data.levels.size():
		return false
	# TODO: block by commander level once the XP tracker exists
	var cost: int = t.data.levels[t.level].build_cost
	if not gold.try_spend(cost):
		EventBus.build_denied.emit(&"NOT_ENOUGH_GOLD", gold.shortfall(cost))
		return false
	# apply_level refills HP to the new max and keeps the target priority.
	t.apply_level(t.level + 1)
	t.invested_gold += cost
	EventBus.tower_upgraded.emit(slot_id, t.data.id, t.level)
	return true

func sell(slot_id: StringName) -> bool:
	if not _begin(slot_id):
		return false
	var ok := _do_sell(slot_id)
	_end(slot_id)
	return ok

func _do_sell(slot_id: StringName) -> bool:
	var slot := find_slot(slot_id)
	var gold := _gold()
	if not is_prep() or slot == null or gold == null or slot.state != Enums.SlotState.OCCUPIED or slot.tower == null:
		return false
	var refund := floori(float(slot.tower.invested_gold) * GameConfig.sell_refund_pct)
	slot.clear_tower()
	gold.add(refund)
	EventBus.tower_sold.emit(slot_id)
	return true

## In combat only Commander mode can change it, and never while paused.
func can_change_priority() -> bool:
	if is_prep():
		return true
	return is_commander_mode() and not TimeManager.is_paused

func set_priority(slot_id: StringName, priority: Enums.TargetPriority) -> bool:
	if not _begin(slot_id):
		return false
	var ok := _do_set_priority(slot_id, priority)
	_end(slot_id)
	return ok

func _do_set_priority(slot_id: StringName, priority: Enums.TargetPriority) -> bool:
	var slot := find_slot(slot_id)
	if slot == null or slot.tower == null or not can_change_priority():
		return false
	slot.tower.set_priority(priority)
	EventBus.tower_priority_changed.emit(slot_id, StringName(Enums.TargetPriority.keys()[priority]))
	return true

func _gold() -> GoldManager:
	return get_tree().get_first_node_in_group(&"gold_manager") as GoldManager

## Returns false when a transaction on this slot is already running.
func _begin(slot_id: StringName) -> bool:
	if _busy.get(slot_id, false):
		return false
	_busy[slot_id] = true
	return true

func _end(slot_id: StringName) -> void:
	_busy.erase(slot_id)

func _on_state_changed(new_state: StringName) -> void:
	_wave_state = new_state

func _on_mode_changed(mode: StringName) -> void:
	_mode = mode

func _on_run_started() -> void:
	_busy.clear()
