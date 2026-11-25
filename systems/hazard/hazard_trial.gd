class_name HazardTrial
extends Node
## The wave side of the Hazard Trial: a short fight in a side room during PREP, once per wave.
## At the start of each PREP it picks the group for that wave and offers it. On request it checks
## the entry rules, switches the wave to HAZARD_TRIAL, moves the commander into the room and
## spawns the group there. The room ends WON (every unit done, commander alive), LEFT (the leave
## button) or DIED (the commander's HP reached 0), settled once at the end of the frame with DIED
## over WON over LEFT. Leaving pays the gold and XP of the kills, plus Mithril for a win, puts the
## commander back where it stood and returns the wave to the same PREP.
## Kills in the room never touch the real wave: no prestige, no run kills, no boss count.
## The commander side (copying and restoring its state, the damage cap) listens to
## hazard_trial_entered and hazard_trial_exited.

const WON := &"WON"
const LEFT := &"LEFT"
const DIED := &"DIED"

## Why entering is refused. Paused, dialog, frontline and used are the gate's own locale keys.
const REASON_STATE := &"hud.hazard.state"
const REASON_PAUSED := &"hud.hazard.paused"
const REASON_DIALOG := &"hud.hazard.dialog"
const REASON_FRONTLINE := &"hud.hazard.frontline"
const REASON_USED := &"hud.hazard.used"
const REASON_NO_ROOM := &"hud.hazard.no_room"

var wave_manager: WaveManager
## The group offered for the current PREP: {id, scene, boss} per unit, in spawn order.
var group: Array[Dictionary] = []
var group_wave: int = 0

var _active := false
var _wave := 0
var _units: Array[Enemy] = []
var _done: Dictionary = {}  # instance id -> true once the unit is done
var _kills := 0
var _kill_gold := 0.0
var _boss_killed := false
var _xp := 0.0
var _died := false
var _won := false
var _left := false
var _settle_queued := false
var _commander: Node3D
var _commander_return := Transform3D.IDENTITY


func _ready() -> void:
	EventBus.hazard_enter_requested.connect(_on_enter_requested)
	EventBus.hazard_leave_requested.connect(_on_leave_requested)
	EventBus.run_ended.connect(_on_run_ended)


func _exit_tree() -> void:
	_disconnect_commander()


func is_active() -> bool:
	return _active


## Picks the group of this wave and tells the gate. Called at the start of each new PREP.
func offer(wave: int) -> void:
	group = build_group(wave)
	group_wave = wave
	EventBus.hazard_trial_offered.emit(wave, _group_ids(), mithril_for(wave))


## hazard_enemy_count units from the wave's own types, each type at least once, the rest drawn by
## how many of each type the wave has, with an RNG of its own for this wave. A boss wave gives the
## boss plus hazard_boss_escorts units. Fewer types than places repeats the types.
func build_group(wave: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if wave_manager == null:
		return result
	var counts: Dictionary = {}  # id -> count
	var scenes: Dictionary = {}  # id -> scene
	var order: Array[StringName] = []
	for item in wave_manager.generate_wave_composition(wave, wave_manager.run_seed):
		var id: StringName = item.get("id", &"")
		var scene := item.get("scene") as PackedScene
		if id == &"" or scene == null:
			continue
		if not counts.has(id):
			order.append(id)
			scenes[id] = scene
		counts[id] = int(counts.get(id, 0)) + 1
	var places := GameConfig.hazard_enemy_count
	var boss_scene: PackedScene = wave_manager.get_boss_scene(wave)
	if wave_manager.is_boss_wave(wave) and boss_scene != null:
		result.append({"id": wave_manager.get_boss_id(wave), "scene": boss_scene, "boss": true})
		places = GameConfig.hazard_boss_escorts
	if order.is_empty():
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([wave_manager.run_seed, "hazard", wave])
	var picked: Array[StringName] = []
	for id in order:
		if picked.size() >= places:
			break
		picked.append(id)
	var total := 0
	for id in order:
		total += int(counts[id])
	while picked.size() < places:
		var roll := rng.randi_range(1, total)
		for id in order:
			roll -= int(counts[id])
			if roll <= 0:
				picked.append(id)
				break
	for id in picked:
		result.append({"id": id, "scene": scenes[id], "boss": false})
	return result


## Mithril for a win at this wave; past the victory wave it stays at the victory wave's value.
func mithril_for(wave: int) -> int:
	return GameConfig.wave_rewards.get_mithril_reward(mini(wave, GameConfig.victory_wave))


## Empty when the room can be entered now, otherwise why not.
func entry_refusal() -> StringName:
	if wave_manager == null or wave_manager.wave_state != Enums.WaveState.PREP or _active:
		return REASON_STATE
	if TimeManager.is_paused:
		return REASON_PAUSED
	if ScreenManager.has_dialog():
		return REASON_DIALOG
	var rs := _run_state()
	var commander := _find_commander()
	if commander == null or bool(commander.get(&"is_commander_mode")):
		return REASON_FRONTLINE
	if rs != null and rs.hazard_used:
		return REASON_USED
	if _room() == null:
		return REASON_NO_ROOM
	return &""


## Enters the room when the rules allow it. False and nothing changes otherwise.
func enter() -> bool:
	if entry_refusal() != &"":
		return false
	var room := _room()
	_wave = wave_manager.current_wave
	if group.is_empty() or group_wave != _wave:
		group = build_group(_wave)
		group_wave = _wave
	if group.is_empty():
		return false
	_reset_tally()
	_active = true
	wave_manager.enter_hazard_state()
	_move_commander_in(room)
	EventBus.hazard_trial_entered.emit(_wave, _group_ids())
	_spawn_group(room)
	_send_progress()
	return true


## The leave button. The result is settled at the end of the frame.
func request_leave() -> void:
	if not _active:
		return
	_left = true
	_queue_settle()


func _on_enter_requested() -> void:
	enter()


func _on_leave_requested() -> void:
	request_leave()


## Abandoning or quitting in the room ends the run: the room's rewards are lost.
func _on_run_ended(_end_type: StringName, _summary: Dictionary) -> void:
	if not _active:
		return
	_active = false
	_disconnect_commander()
	_clear_units()


func _reset_tally() -> void:
	_units.clear()
	_done.clear()
	_kills = 0
	_kill_gold = 0.0
	_boss_killed = false
	_xp = 0.0
	_died = false
	_won = false
	_left = false
	_settle_queued = false


func _move_commander_in(room: HazardRoom) -> void:
	_commander = _find_commander()
	if _commander == null:
		return
	_commander_return = _commander.global_transform
	var spawn := room.get_commander_spawn()
	if spawn != null:
		_commander.global_position = spawn.global_position
	if _commander is CharacterBody3D:
		(_commander as CharacterBody3D).velocity = Vector3.ZERO
	var health := _commander.get(&"health") as HealthComponent
	if health != null and not health.died.is_connected(_on_commander_died):
		health.died.connect(_on_commander_died)


func _move_commander_out() -> void:
	_disconnect_commander()
	if not is_instance_valid(_commander):
		return
	_commander.global_transform = _commander_return
	if _commander is CharacterBody3D:
		(_commander as CharacterBody3D).velocity = Vector3.ZERO


func _disconnect_commander() -> void:
	if not is_instance_valid(_commander):
		return
	var health := _commander.get(&"health") as HealthComponent
	if health != null and health.died.is_connected(_on_commander_died):
		health.died.disconnect(_on_commander_died)


## The group at the pads of the room, the boss on the large pad. Same data and wave scale as
## the units of this wave outside. They go straight for the commander.
func _spawn_group(room: HazardRoom) -> void:
	var boss_pad := room.get_boss_spawn()
	# With a boss on the large pad the others share the remaining pads.
	var pads := room.get_enemy_spawns()
	if _has_boss() and pads.size() > 1:
		pads.erase(boss_pad)
	var pad_index := 0
	for entry in group:
		var unit := (entry["scene"] as PackedScene).instantiate() as Enemy
		if unit == null:
			continue
		var pad: Marker3D = boss_pad
		if not entry["boss"]:
			pad = pads[pad_index % pads.size()] if not pads.is_empty() else null
			pad_index += 1
		unit.in_hazard_room = true
		if &"in_hazard_trial" in unit:
			unit.set(&"in_hazard_trial", true)
		unit.spawn_grace = false
		unit.is_in_spawn_zone = false
		wave_manager.apply_wave_scale_to(unit, _wave)
		add_child(unit)
		if pad != null:
			unit.global_transform = pad.global_transform
		unit.change_state(Enums.EnemyState.ADVANCE)
		unit.state_changed.connect(_on_unit_state_changed.bind(unit))
		unit.tree_exiting.connect(_on_unit_gone.bind(unit))
		_units.append(unit)
		EventBus.enemy_spawned.emit(unit)


func _has_boss() -> bool:
	for entry in group:
		if entry["boss"]:
			return true
	return false


func _on_unit_state_changed(new_state: Enums.EnemyState, _old: Enums.EnemyState, unit: Enemy) -> void:
	if new_state == Enums.EnemyState.DEAD:
		_mark_done(unit, true)


## A unit freed without dying (removed by its own code) is done but is not a kill.
func _on_unit_gone(unit: Enemy) -> void:
	if _active and not unit.is_dead:
		_mark_done(unit, false)


func _mark_done(unit: Enemy, killed: bool) -> void:
	if not _active:
		return
	var id := unit.get_instance_id()
	if _done.has(id):
		return
	_done[id] = true
	if killed:
		_kills += 1
		if unit.is_boss():
			_boss_killed = true
		else:
			_kill_gold += unit._get_kill_gold()
		_xp += _xp_for(unit)
	_send_progress()
	if _done.size() >= _units.size():
		_won = true
		_queue_settle()


func _xp_for(unit: Enemy) -> float:
	var base := 0
	if unit.data != null and &"xp_value" in unit.data:
		base = int(unit.data.get(&"xp_value"))
	return float(base) * GameConfig.xp_commander_pct * GameConfig.wave_rewards.get_xp_mult(_wave)


func _on_commander_died() -> void:
	if not _active:
		return
	_died = true
	_queue_settle()


func _queue_settle() -> void:
	if _settle_queued:
		return
	_settle_queued = true
	_settle.call_deferred()


## End of frame: one result, DIED over WON over LEFT.
func _settle() -> void:
	_settle_queued = false
	if not _active:
		return
	var result := LEFT
	if _died:
		result = DIED
	elif _won:
		result = WON
	elif not _left:
		return
	_finish(result)


func _finish(result: StringName) -> void:
	_active = false
	_clear_units()
	var gold := room_gold()
	var mithril := mithril_for(_wave) if result == WON else 0
	var rs := _run_state()
	if rs != null:
		rs.hazard_used = true
	_move_commander_out()
	EventBus.hazard_trial_exited.emit(result, _kills, gold, _xp, mithril)
	var gold_manager := get_tree().get_first_node_in_group(&"gold_manager") as GoldManager
	if gold_manager != null and gold > 0:
		gold_manager.add(gold)
	var tracker := wave_manager.get_xp_tracker() if wave_manager != null else null
	if tracker != null and _xp > 0.0:
		tracker.call(&"add_xp", _xp)
	if rs != null and mithril > 0:
		rs.add_mithril(mithril)
	if wave_manager != null:
		wave_manager.leave_hazard_state()


## Gold earned so far: the kills at this wave's kill gold, plus the boss gold when the boss died,
## each with the gold bonus and rounded down. No clear bonus and no Enrage cut in the room.
func room_gold() -> int:
	var pct := wave_manager._gold_pct_total() if wave_manager != null else 0.0
	var gold := WaveRewardTable.floor_gold(_kill_gold * (1.0 + pct))
	if _boss_killed:
		gold += WaveRewardTable.floor_gold(GameConfig.wave_rewards.get_boss_gold(_wave) * (1.0 + pct))
	return gold


func _send_progress() -> void:
	EventBus.hazard_trial_progress.emit(_units.size() - _done.size(), _units.size(), room_gold(), _xp)


func _clear_units() -> void:
	for unit in _units:
		if is_instance_valid(unit):
			if unit.tree_exiting.is_connected(_on_unit_gone):
				unit.tree_exiting.disconnect(_on_unit_gone)
			unit.queue_free()
	_units.clear()


func _group_ids() -> Array:
	var ids: Array = []
	for entry in group:
		ids.append(entry["id"])
	return ids


func _find_commander() -> Node3D:
	return get_tree().get_first_node_in_group(&"commander") as Node3D


func _room() -> HazardRoom:
	return get_tree().get_first_node_in_group(&"hazard_room") as HazardRoom


func _run_state() -> RunState:
	return get_tree().get_first_node_in_group(&"run_state") as RunState
