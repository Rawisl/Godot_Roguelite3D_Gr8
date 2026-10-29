class_name BuildService
extends Node
## Build, upgrade, sell, rubble clearing and Fortress repair for the panels. Each call checks the wave state, the slot and
## the gold in the same frame and either finishes or changes nothing. Calls are
## synchronous, so one press can never spend gold twice.

## Lock key for Fortress repairs in _busy; slot ids never take this value.
const FORTRESS_LOCK := &"FORTRESS"

@export var towers: Array[TowerData] = []
@export var tower_scenes: Dictionary[StringName, PackedScene] = {}

var _wave_state: StringName = &""
var _mode: StringName = &"FRONTLINE"
var _commander_level: int = 1
var _busy: Dictionary[StringName, bool] = {}  # slot_id -> true while a transaction runs

func _ready() -> void:
	add_to_group(&"build_service")
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.mode_changed.connect(_on_mode_changed)
	EventBus.run_started.connect(_on_run_started)
	EventBus.level_up.connect(_on_level_up)

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

## Removes the rubble of a destroyed tower. Free; the slot goes back to EMPTY.
func clear_rubble(slot_id: StringName) -> bool:
	if not _begin(slot_id):
		return false
	var ok := _do_clear_rubble(slot_id)
	_end(slot_id)
	return ok

func _do_clear_rubble(slot_id: StringName) -> bool:
	var slot := find_slot(slot_id)
	if not is_prep() or slot == null or slot.state != Enums.SlotState.RUINED:
		return false
	return slot.clear_rubble()

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
		var required := get_upgrade_required_level(t.level + 1)
		info["upgrade_required_level"] = required
		info["upgrade_locked"] = _commander_level < required
	return info

func get_commander_level() -> int:
	return _commander_level

## Commander level needed to upgrade a tower to next_level.
func get_upgrade_required_level(next_level: int) -> int:
	match next_level:
		2:
			return GameConfig.tower_gate_lv2
		3:
			return GameConfig.tower_gate_lv3
	return 0

func can_upgrade(slot_id: StringName) -> bool:
	return get_upgrade_block_reason(slot_id) == &""

## &"" when the upgrade can go ahead, otherwise why it cannot.
func get_upgrade_block_reason(slot_id: StringName) -> StringName:
	var slot := find_slot(slot_id)
	var gold := _gold()
	if not is_prep() or gold == null:
		return &"NOT_PREP"
	if slot == null or slot.state != Enums.SlotState.OCCUPIED or slot.tower == null:
		return &"NO_TOWER"
	var t := slot.tower
	if t.level >= t.data.levels.size():
		return &"MAX_LEVEL"
	# TODO(week 8): commander level comes from XpTracker level_up; tune thresholds with the real XP curve.
	if _commander_level < get_upgrade_required_level(t.level + 1):
		return &"COMMANDER_LEVEL"
	if not gold.can_afford(t.data.levels[t.level].build_cost):
		return &"NOT_ENOUGH_GOLD"
	return &""

func upgrade(slot_id: StringName) -> bool:
	if not _begin(slot_id):
		return false
	var ok := _do_upgrade(slot_id)
	_end(slot_id)
	return ok

func _do_upgrade(slot_id: StringName) -> bool:
	var reason := get_upgrade_block_reason(slot_id)
	var gold := _gold()
	if reason == &"COMMANDER_LEVEL":
		EventBus.build_denied.emit(&"COMMANDER_LEVEL", 0)
		return false
	var t := find_slot(slot_id).tower if reason in [&"", &"NOT_ENOUGH_GOLD"] else null
	if t == null:
		return false
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

## Spends gold and repairs the Fortress in one call. step_ratio as in FortressStats
## (repair_step_small_pct, repair_step_large_pct); <= 0 repairs to full HP.
## Returns true when HP was restored and gold spent.
func repair_fortress(step_ratio: float) -> bool:
	if not _begin(FORTRESS_LOCK):
		return false
	var ok := _do_repair_fortress(step_ratio)
	_end(FORTRESS_LOCK)
	return ok

func _do_repair_fortress(step_ratio: float) -> bool:
	var fortress := _fortress()
	var gold := _gold()
	if not is_prep() or fortress == null or gold == null:
		return false
	if fortress.is_destroyed() or fortress.is_full():
		return false
	var quote := fortress.quote_repair_now(step_ratio, gold.gold)
	if quote.heal <= 0:
		EventBus.build_denied.emit(&"NOT_ENOUGH_GOLD", gold.shortfall(_min_repair_cost(fortress)))
		return false
	var cost: int = quote.cost
	if not gold.try_spend(cost):
		return false
	# Passing the spent gold as the budget makes the Fortress quote the same step again.
	var result := fortress.repair_with_gold(step_ratio, cost)
	var used: int = result.cost if result.heal > 0 else 0
	if used < cost:
		gold.add(cost - used)
	# TODO(week 9): gold repairs give no prestige; keep this spending out of the prestige tally.
	return used > 0

## Gold for the smallest repair the panel allows: 1% of max HP, or the whole gap when it is smaller.
func _min_repair_cost(fortress: Fortress) -> int:
	return ceili(minf(1.0, fortress.get_missing_pct()) * fortress.stats.repair_gold_per_pct - Fortress.PCT_EPSILON)

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

func _fortress() -> Fortress:
	return get_tree().get_first_node_in_group(&"fortress") as Fortress

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
	if new_state == &"PREP" and GameConfig.tower_full_heal_on_prep:
		_heal_towers_for_prep()

func _heal_towers_for_prep() -> void:
	for node in get_tree().get_nodes_in_group(&"slot"):
		var slot := node as Slot
		if slot != null and slot.state == Enums.SlotState.OCCUPIED and slot.tower != null and slot.tower.heals_on_prep():
			slot.tower.restore_full_hp()

func _on_mode_changed(mode: StringName) -> void:
	_mode = mode

func _on_run_started() -> void:
	_commander_level = 1
	_busy.clear()

## The level never goes down, so a late or repeated signal cannot lock upgrades again.
func _on_level_up(new_level: int, _pending_picks: int) -> void:
	_commander_level = maxi(_commander_level, new_level)
