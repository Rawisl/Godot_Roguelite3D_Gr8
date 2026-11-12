class_name BuildService
extends Node
## Build, upgrade, sell, rubble clearing and Fortress repair (paid in Mithril) for the panels. Each call checks the wave state, the slot and
## the gold or Mithril in the same frame and either finishes or changes nothing. Calls are
## synchronous, so one press can never spend gold twice. A ground build that would seal the
## lane is refused before any gold is spent.
# TODO(kiezroth): when tower data for levels 1 to 36 lands, give all four tower types those levels

## Lock key for Fortress repairs in _busy; slot ids never take this value.
const FORTRESS_LOCK := &"FORTRESS"
const HEAL_LIMIT := &"HEAL_LIMIT"
const BLOCKS_PATH := &"BLOCKS_PATH"

@export var towers: Array[TowerData] = []
@export var tower_scenes: Dictionary[StringName, PackedScene] = {}
## Towers of this type count against GameConfig.heal_tower_max_count.
@export var heal_station_data: TowerData = preload("res://data/towers/heal_station.tres")

var _wave_state: StringName = &""
var _mode: StringName = &"FRONTLINE"
var _commander_level: int = 0
## A transaction that stops on a script error never reaches _end(), so its key stays
## locked until run_started clears _busy.
var _busy: Dictionary[StringName, bool] = {}  # slot_id -> true while a transaction runs

func _ready() -> void:
	add_to_group(&"build_service")
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.mode_changed.connect(_on_mode_changed)
	EventBus.run_started.connect(_on_run_started)
	EventBus.level_up.connect(_on_level_up)
	EventBus.xp_changed.connect(_on_xp_changed)

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

## Highest level a tower of this type reaches: its data, capped by GameConfig.tower_max_level.
func get_max_level(data: TowerData) -> int:
	return mini(data.levels.size(), GameConfig.tower_max_level)

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
	var locked_reason: StringName = &"GROUND_FULL" if _ground_blocks(slot) else &""
	var path_sealed := locked_reason == &"" and _seals_path(slot)
	if slot.state == Enums.SlotState.RUINED and slot.last_data != null:
		var rebuild_cost := slot.get_rebuild_cost()
		result.append({"data": slot.last_data, "level": slot.last_level,
			"cost": rebuild_cost, "shortfall": gold.shortfall(rebuild_cost), "rebuild": true,
			"locked_reason": locked_reason})
	for data in towers:
		if not slot.allows(data):
			continue
		var reason := _option_lock_reason(slot, data, locked_reason, path_sealed)
		var cost := data.get_total_cost(1)
		result.append({"data": data, "level": 1,
			"cost": cost, "shortfall": gold.shortfall(cost), "rebuild": false,
			"locked_reason": reason})
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
	if level < 1 or level > get_max_level(data):
		return false
	if not tower_scenes.has(type) or not slot.can_build(data):
		return false
	if _ground_blocks(slot):
		EventBus.build_denied.emit(&"GROUND_FULL", 0)
		return false
	if _heal_limit_blocks(slot, data):
		EventBus.build_denied.emit(HEAL_LIMIT, 0)
		return false
	# A level above 1 is only a rebuild of the tower that stood here, at the level it had.
	var is_rebuild := level > 1
	if is_rebuild and not (slot.can_rebuild(data) and level == slot.last_level):
		return false
	if would_block_path(slot, data):
		EventBus.build_denied.emit(BLOCKS_PATH, 0)
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

## GROUND slots holding a tower or rubble. Counted from the slots on every call, so slots
## created later (by the ground grid) never leave a stale number.
func get_ground_used() -> int:
	var used := 0
	for node in get_tree().get_nodes_in_group(&"slot"):
		var slot := node as Slot
		if slot != null and slot.uses_ground_space():
			used += 1
	return used

func is_ground_full() -> bool:
	return get_ground_used() >= GameConfig.max_ground_buildings

## A new building on an EMPTY ground slot needs a free place; rubble already holds one.
func _ground_blocks(slot: Slot) -> bool:
	return slot.is_ground() and slot.state == Enums.SlotState.EMPTY and is_ground_full()

func is_heal_station(data: TowerData) -> bool:
	return data != null and heal_station_data != null and data.id == heal_station_data.id

## Heal stations standing or left as rubble, except on except_slot. Counted from the slots
## on every call, like get_ground_used().
func get_heal_station_count(except_slot: StringName = &"") -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(&"slot"):
		var slot := node as Slot
		if slot == null or slot.slot_id == except_slot:
			continue
		if slot.state == Enums.SlotState.OCCUPIED and slot.tower != null and is_heal_station(slot.tower.data):
			count += 1
		elif slot.state == Enums.SlotState.RUINED and is_heal_station(slot.last_data):
			count += 1
	return count

## A new station may not pass the cap. Its own rubble on this slot does not count, so a rebuild
## never adds one; building another type on a station's rubble frees that place.
func _heal_limit_blocks(slot: Slot, data: TowerData) -> bool:
	return is_heal_station(data) and get_heal_station_count(slot.slot_id) >= GameConfig.heal_tower_max_count

## Why the menu greys out data on slot, or &"". ground_reason and path_sealed are worked out
## once per slot by get_build_options.
func _option_lock_reason(slot: Slot, data: TowerData, ground_reason: StringName, path_sealed: bool) -> StringName:
	if ground_reason != &"":
		return ground_reason
	if _heal_limit_blocks(slot, data):
		return HEAL_LIMIT
	if path_sealed and not slot.can_rebuild(data):
		return BLOCKS_PATH
	return &""

## True when building data on slot would leave the boss-sized lane no way from spawn to the
## Fortress gate or to the Bulwark's standing point. Wall slots never block. Building the same
## type on its own rubble leaves the obstacles unchanged, so it is not checked.
func would_block_path(slot: Slot, data: TowerData) -> bool:
	if slot == null or not slot.is_ground():
		return false
	if slot.can_rebuild(data):
		return false
	return _seals_path(slot)

## The path check for any new building on slot. False (no check) when the slot is not a cell
## of a GroundGrid or the level lacks spawn_zone or lane.
func _seals_path(slot: Slot) -> bool:
	if not slot.is_ground():
		return false
	var grid := slot.get_parent() as GroundGrid
	if grid == null or grid.grid_data == null:
		return false
	var cell := GridData.cell_of(slot.slot_id)
	if cell.x < 0:
		return false
	if grid.spawn_zone == null:
		push_warning("BuildService: %s has no spawn_zone, the path check is skipped" % grid.name)
		return false
	if not _has_lane_end(grid):
		push_warning("BuildService: %s has no lane, the path check is skipped" % grid.name)
		return false
	var min_width := GameConfig.path_check_min_width
	var gate := _lane_end(grid)
	var goals: Array[Vector3] = [grid.grid_data.gate_goal(gate, min_width), grid.get_boss_point()]
	var obstacles := _ground_obstacles(grid)
	obstacles.append(cell)
	return not grid.grid_data.is_path_open(obstacles, grid.spawn_zone.global_position, gate, goals, min_width)

## Cells of grid holding a tower or rubble.
func _ground_obstacles(grid: GroundGrid) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for node in grid.cells.values():
		var s := node as Slot
		if s == null or not is_instance_valid(s):
			continue
		if not s.uses_ground_space():
			continue
		var cell := GridData.cell_of(s.slot_id)
		if cell.x < 0:
			continue
		out.append(cell)
	return out

func _has_lane_end(grid: GroundGrid) -> bool:
	return grid.lane != null and grid.lane.curve != null and grid.lane.curve.point_count > 0

## The gate end of the lane, as GroundGrid uses for the boss point fallback.
func _lane_end(grid: GroundGrid) -> Vector3:
	return grid.lane.global_transform * grid.lane.curve.get_point_position(grid.lane.curve.point_count - 1)

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
		"is_max": t.level >= get_max_level(t.data),
		"sell_value": t.get_sell_value(),
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

## Commander level needed to upgrade a tower to next_level. Only the first level of
## tiers 2 and 3 has a gate; every other upgrade needs none.
func get_upgrade_required_level(next_level: int) -> int:
	if next_level == GameConfig.tower_tier3_level:
		return GameConfig.tower_gate_tier3
	if next_level == GameConfig.tower_tier2_level:
		return GameConfig.tower_gate_tier2
	return 0

func can_upgrade(slot_id: StringName) -> bool:
	return get_upgrade_block_reason(slot_id) == &""

## &"" when the upgrade can go ahead, otherwise why it cannot.
func get_upgrade_block_reason(slot_id: StringName) -> StringName:
	var slot := find_slot(slot_id)
	var gold := _gold()
	if gold == null:
		return &"NO_GOLD_MANAGER"
	if not is_prep():
		return &"NOT_PREP"
	if slot == null or slot.state != Enums.SlotState.OCCUPIED or slot.tower == null:
		return &"NO_TOWER"
	var t := slot.tower
	if t.level >= get_max_level(t.data):
		return &"MAX_LEVEL"
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
	var refund := slot.tower.get_sell_value()
	slot.clear_tower()
	gold.add(refund, true, false)
	EventBus.tower_sold.emit(slot_id)
	return true

## Spends 1 Mithril and repairs the Fortress in one call. Returns true when HP was restored and the Mithril spent.
func repair_fortress_mithril() -> bool:
	if not _begin(FORTRESS_LOCK):
		return false
	var ok := _do_repair_fortress_mithril()
	_end(FORTRESS_LOCK)
	return ok

func _do_repair_fortress_mithril() -> bool:
	if not is_prep():
		return false
	var fortress := _fortress()
	if fortress == null or fortress.is_destroyed():
		return false
	if fortress.is_full():
		return false
	var rs := _run_state()
	if rs == null:
		return false
	if rs.mithril <= 0:
		EventBus.build_denied.emit(&"NOT_ENOUGH_MITHRIL", 1)
		return false
	# The Mithril is taken only after the Fortress healed, so a refusal leaves the wallet and the HUD untouched.
	var healed := fortress.repair_with_mithril()
	if healed <= 0:
		return false
	# Cannot fail: mithril > 0 was checked above inside the same locked transaction. The warning only
	# guards a future change to that contract.
	if not rs.spend_mithril(1):
		push_warning("BuildService: Mithril no longer available after repair")
		return false
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

func _run_state() -> RunState:
	return get_tree().get_first_node_in_group(&"run_state") as RunState

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
	_commander_level = 0
	_busy.clear()

## The level never goes down, so a late or repeated signal cannot lock upgrades again.
func _on_level_up(new_level: int, _pending_picks: int) -> void:
	_commander_level = maxi(_commander_level, new_level)

## XpTracker sends its level on start, reset and every XP change, so a restored run
## that never emits level_up still opens the right upgrades.
func _on_xp_changed(_xp: float, level: int, _to_next: float, _pending_picks: int) -> void:
	_commander_level = maxi(_commander_level, level)
