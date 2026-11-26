extends "res://tests/cheat_main.gd"
## Wave bot: plays main.tscn by itself and writes what happened, one JSON line per run.
## Nothing reaches the save, the cloud or the leaderboard (see cheat_main.gd).
##
## Arguments after "--" on the command line:
##   --seed=N          run seed (default 1)
##   --mode=afk        the commander goes to Commander mode and stays there
##   --mode=frontline  the commander walks to the nearest unit, swings at it and uses its skills
##                     and Battle Cry as soon as they are ready; it keeps 6 m from a boss while
##                     other units are left, then fights the boss; under half HP it retreats to Commander mode
##                     until the next PREP (default)
##   --waves=N         stop after N waves are cleared (default 20)
##   --speed=N         time scale during combat, 1..3 (default 3)
##   --soak            gold for every build and upgrade, the Fortress and the commander kept alive
##                     and a boss that reached Enrage put down, to check that every wave ends and
##                     how many units get stuck
##   --out=PATH        append the JSON line to this file too (default: print only)
##
## The run starts with the starter towers. Both bots build the same way in every PREP: from wave
## 4 one Heal station on the free ground cell nearest the Fortress, Arrow and Cannon in turn on
## the wall slots, then upgrades of the lowest tower while the gold lasts. The level-up cards are picked first card first. The Hazard Trial is skipped.
## A wave counts as hung when its combat lasts past the hard cap plus its spawn duration plus
## HANG_MARGIN game seconds; the run then stops.

const HANG_MARGIN := 60.0
const FRONTLINE_REACH := 1.8
const FRONTLINE_SPEED := 5.0
const SKILL_REACH := 4.0
const HEAL_FROM_WAVE := 4
const BOSS_KEEP_AWAY := 6.0
const RETREAT_HP_RATIO := 0.5
const SOAK_GOLD := 100000

var seed_value := 1
var mode := &"frontline"
var max_waves := 20
var speed := 3
var soak := false
var out_path := ""

var _wm: WaveManager
var _rs: RunState
var _build: BuildService
var _commander: Node3D
var _fortress: Node3D
var _prep_done_for := -1
var _combat_time := 0.0
var _finished := false
var _result := &"RUNNING"
var _waves: Array[Dictionary] = []
var _wave_row: Dictionary = {}
var _spawned_total := 0
var _stuck_culls := 0
var _hard_cap_culls := 0
var _heal_built := false
var _cannon_turn := false
var _boss_assists := 0
var _started := false
var _retreats := 0
var _heal_depleted := 0
var _skill_casts := 0
var _levels_at := {}
var _tower_level_at := {}


func _enter_tree() -> void:
	_read_args()
	# The tutorial would hold the first build; this bot never plays it.
	var tutorial := get_node_or_null(^"Gameplay/TutorialService")
	if tutorial != null:
		tutorial.get_parent().remove_child(tutorial)
		tutorial.queue_free()
	super._enter_tree()


func _ready() -> void:
	super._ready()
	_wm = get_node(^"Gameplay/WaveManager") as WaveManager
	_rs = get_node(^"Gameplay/RunState") as RunState
	_build = get_node(^"Gameplay/BuildService") as BuildService
	_wm.enable_victory_screen = false
	EventBus.enemy_spawned.connect(func(_e: Node) -> void: _spawned_total += 1; _wave_row["spawned"] = int(_wave_row.get("spawned", 0)) + 1)
	EventBus.stuck_event_logged.connect(_on_stuck_logged)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.reward_offered.connect(_on_reward_offered)
	EventBus.heal_state_changed.connect(_on_heal_state)
	EventBus.skill_cast.connect(func(_id: StringName, _slot: int, _lv: int, _o: Vector3, _r: float) -> void: _skill_casts += 1)
	EventBus.heal_tower_hp_changed.connect(_on_heal_tower_hp)
	EventBus.fortress_destroyed.connect(func() -> void: _finish(&"FORTRESS_DESTROYED"))
	EventBus.commander_died.connect(func() -> void: _finish(&"COMMANDER_DIED"))


func _start_run() -> void:
	# As after the tutorial: the run starts with the starter towers. In memory only, never saved.
	SaveManager.get_section(SaveManager.FLAGS)["tutorial_done"] = true
	super._start_run()
	_rs.run_seed = seed_value
	# The first PREP queue was built before the seed was set.
	_wm._build_spawn_queue_for_wave(_wm.current_wave)
	_started = true
	print("[bot] seed %d, mode %s, %d waves at x%d%s" % [seed_value, mode, max_waves, speed, ", soak" if soak else ""])


func _read_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		var key := parts[0]
		var value := parts[1] if parts.size() > 1 else ""
		match key:
			"seed": seed_value = int(value)
			"mode": mode = StringName(value)
			"waves": max_waves = int(value)
			"speed": speed = clampi(int(value), 1, 3)
			"soak": soak = true
			"out": out_path = value


func _physics_process(delta: float) -> void:
	if _finished or _wm == null or not _started or not is_inside_tree():
		return
	if _commander == null or not is_instance_valid(_commander):
		_commander = get_tree().get_first_node_in_group(&"commander") as Node3D
	if _fortress == null or not is_instance_valid(_fortress):
		_fortress = get_tree().get_first_node_in_group(&"fortress") as Node3D
	if soak:
		_keep_alive()
		_assist_enraged_boss()
	match _wm.wave_state:
		Enums.WaveState.PREP:
			_play_prep()
		Enums.WaveState.COMBAT, Enums.WaveState.BOSS_COMBAT:
			if TimeManager.get_time_scale() != speed:
				TimeManager.set_time_scale(speed)
			_combat_time += delta
			if mode == &"frontline":
				_frontline_step(delta)
			var limit := GameConfig.wave_hard_cap + _wm.get_spawn_duration(_wm.current_wave) + HANG_MARGIN
			if _combat_time > limit:
				_wave_row["hung"] = true
				_finish(&"WAVE_HUNG")
		Enums.WaveState.REWARD_PICK:
			EventBus.reward_offer_requested.emit()


func _play_prep() -> void:
	if _prep_done_for == _wm.current_wave:
		return
	if _commander == null:
		return
	_prep_done_for = _wm.current_wave
	# AFK goes to Commander mode; Frontline goes back to the field after a retreat.
	var in_command := bool(_commander.get(&"is_commander_mode"))
	if (mode == &"afk") != in_command:
		var switch: Node = _commander.get(&"_mode_switch")
		if switch != null and not switch.is_busy():
			switch.request()
	if OS.has_environment("BOT_TRACE"):
		EventBus.build_denied.connect(func(r: StringName, sh: int) -> void: print("[bot] denied ", r, " ", sh), CONNECT_ONE_SHOT)
		print("[bot] prep ", _wm.current_wave, " gold ", (get_node(^"Gameplay/GoldManager") as GoldManager).gold)
	if soak:
		# Strong towers so units die the normal way; the soak checks movement, not the economy.
		(get_node(^"Gameplay/GoldManager") as GoldManager).gold = SOAK_GOLD
	_spend_gold()
	_record_tower_levels()
	_wave_row = {"wave": _wm.current_wave, "spawned": 0, "stuck_culls": 0, "hard_cap_culls": 0}
	EventBus.wave_start_requested.emit()


func _spend_gold() -> void:
	if not is_inside_tree():
		return
	var slots: Array[Slot] = []
	for node in get_tree().get_nodes_in_group(&"slot"):
		var slot := node as Slot
		if slot != null:
			slots.append(slot)
	var gold := get_node(^"Gameplay/GoldManager") as GoldManager
	# One Heal station from HEAL_FROM_WAVE, on the free ground cell nearest the Fortress, before
	# any other spending.
	if not _heal_built and _fortress != null and _wm.current_wave >= HEAL_FROM_WAVE 			and gold.gold >= _build.get_data(&"heal_station").get_total_cost(1):
		var best: Slot = null
		for slot in slots:
			if slot.zone == Enums.SlotZone.GROUND and slot.state == Enums.SlotState.EMPTY:
				if best == null or slot.global_position.distance_to(_fortress.global_position) < best.global_position.distance_to(_fortress.global_position):
					best = slot
		if best != null and _build.build(best.slot_id, &"heal_station", 1):
			_heal_built = true
	# Arrow and Cannon in turn on the wall slots (the Cannon hurts the Bulwark's armoured phase),
	# then any rubble rebuilt.
	for slot in slots:
		if slot.zone != Enums.SlotZone.GROUND and slot.state == Enums.SlotState.EMPTY:
			var type := &"cannon" if _cannon_turn else &"arrow"
			if _build.build(slot.slot_id, type, 1):
				_cannon_turn = not _cannon_turn
		elif slot.state == Enums.SlotState.RUINED and slot.last_data != null:
			_build.build(slot.slot_id, slot.last_data.id, slot.last_level)
	# Upgrades, lowest tower first, while they go through.
	var guard := 0
	while guard < 64:
		guard += 1
		var lowest: Slot = null
		for slot in slots:
			if slot.state != Enums.SlotState.OCCUPIED or slot.tower == null:
				continue
			if _build.get_upgrade_block_reason(slot.slot_id) != &"":
				continue
			if lowest == null or slot.tower.level < lowest.tower.level:
				lowest = slot
		if lowest == null or not _build.upgrade(lowest.slot_id):
			break


func _record_tower_levels() -> void:
	if not is_inside_tree():
		return
	var top := 0
	for node in get_tree().get_nodes_in_group(&"tower"):
		var tower := node as Tower
		if tower != null and not (tower.data != null and tower.data.id == &"heal_station"):
			top = maxi(top, tower.level)
	_tower_level_at[_wm.current_wave] = top


## The commander walks to the nearest unit it may hit and swings at it.
func _frontline_step(delta: float) -> void:
	if not is_inside_tree():
		return
	if _commander == null or bool(_commander.get(&"is_commander_mode")) or bool(_commander.get(&"is_dead")):
		return
	# Low on HP: retreat to Commander mode for the rest of the wave, like a careful player.
	var h := _commander.get(&"health") as HealthComponent
	if h != null and h.get_health_ratio() < RETREAT_HP_RATIO:
		var switch: Node = _commander.get(&"_mode_switch")
		if switch != null and not switch.is_busy():
			switch.request()
			if bool(_commander.get(&"is_commander_mode")) or switch.is_busy():
				_retreats += 1
		return
	var target: Enemy = null
	var best := INF
	var boss: Enemy = null
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var e := node as Enemy
		if e == null or not e.can_be_targeted():
			continue
		# The boss is fought only when no other unit is left, from outside its reach.
		if e.is_boss():
			boss = e
			continue
		var d := e.global_position.distance_squared_to(_commander.global_position)
		if d < best:
			best = d
			target = e
	var away := Vector3.ZERO
	if boss != null:
		away = _commander.global_position - boss.global_position
		away.y = 0.0
	if target == null and boss != null:
		target = boss
	elif boss != null and away.length() < BOSS_KEEP_AWAY:
		_commander.global_position += away.normalized() * FRONTLINE_SPEED * delta
		return
	if target == null:
		return
	var to := target.global_position - _commander.global_position
	to.y = 0.0
	if target != boss and boss != null and (target.global_position - boss.global_position).length() < BOSS_KEEP_AWAY:
		return
	if to.length() > FRONTLINE_REACH:
		var step := to.normalized() * FRONTLINE_SPEED * delta
		var next: Vector3 = _commander.global_position + step
		_commander.global_position = next
	_commander.call(&"face_toward", to)
	# Skills when a unit is close: each slot goes as soon as it is ready, then Battle Cry.
	if to.length() <= SKILL_REACH:
		for slot in 3:
			_commander.call(&"_try_skill", slot)
		_commander.call(&"_try_battle_cry")
	if not bool(_commander.get(&"is_attacking")) and not bool(_commander.get(&"is_using_skill")):
		_commander.call(&"_try_attack")


## Soak only: a boss that reached Enrage is put down, so the soak keeps checking the waves after
## it instead of waiting on a fight the bot cannot win. Counted in boss_assists.
func _assist_enraged_boss() -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(&"boss"):
		var boss := node as Enemy
		if boss != null and not boss.is_dead and bool(boss.get(&"is_enraged")):
			_boss_assists += 1
			boss.health.take_damage(DamageInfo.new(boss.health.max_hp * 10, Enums.DamageType.TRUE))


func _keep_alive() -> void:
	if _fortress != null:
		var h := _fortress.get(&"health") as HealthComponent
		if h != null and h.hp < h.max_hp:
			h.hp = h.max_hp
	if _commander != null:
		var h := _commander.get(&"health") as HealthComponent
		if h != null and h.hp > 0 and h.hp < h.max_hp:
			h.hp = h.max_hp


func _on_wave_started(_index: int) -> void:
	_combat_time = 0.0


func _on_stuck_logged(tier: int, _type: StringName, _pos: Vector3, _wave: int) -> void:
	if tier == 4:
		_stuck_culls += 1
		_wave_row["stuck_culls"] = int(_wave_row.get("stuck_culls", 0)) + 1


func _on_enemy_died(_id: StringName, _p: Vector3, _g: float, _pr: int, is_cull: bool, _c: bool) -> void:
	if is_cull and _wm.wave_state != Enums.WaveState.PREP and _combat_time >= GameConfig.wave_hard_cap:
		_hard_cap_culls += 1
		_wave_row["hard_cap_culls"] = int(_wave_row.get("hard_cap_culls", 0)) + 1


func _on_wave_cleared(index: int) -> void:
	var xp := _wm.get_xp_tracker()
	var level: int = int(xp.commander_level) if xp != null else 0
	_levels_at[index] = level
	_wave_row["combat_s"] = snappedf(_combat_time, 0.1)
	_wave_row["commander_level"] = level
	_wave_row["min_duration"] = _wm.get_spawn_duration(index)
	_waves.append(_wave_row.duplicate())
	if index >= max_waves:
		_finish(&"DONE")


func _on_reward_offered(cards: Array, _rerolls: int) -> void:
	if cards.is_empty():
		EventBus.reward_skip_requested.emit()
		return
	var card: Dictionary = cards[0]
	EventBus.reward_pick_requested.emit(card.get("id", &""), card.get("kind", &""), int(card.get("level", 1)))


func _on_heal_state(state: StringName, _slot: StringName, _progress: float) -> void:
	if state == &"DEPLETED":
		_heal_depleted += 1


func _on_heal_tower_hp(_slot: StringName, new_hp: int, _max: int) -> void:
	if new_hp <= 0:
		_heal_depleted += 1


func _finish(result: StringName) -> void:
	if _finished:
		return
	_finished = true
	_result = result
	TimeManager.reset_time_scale()
	var row := {
		"seed": seed_value, "mode": String(mode), "speed": speed, "soak": soak,
		"result": String(result), "waves_cleared": _waves.size(),
		"spawned": _spawned_total, "stuck_culls": _stuck_culls, "hard_cap_culls": _hard_cap_culls,
		"cull_pct": 100.0 * float(_stuck_culls + _hard_cap_culls) / float(maxi(1, _spawned_total)),
		"commander_level": _levels_at, "top_tower_level": _tower_level_at,
		"heal_station_built": _heal_built, "heal_depleted": _heal_depleted, "skill_casts": _skill_casts, "boss_assists": _boss_assists, "retreats": _retreats,
		"hung": _waves.any(func(w: Dictionary) -> bool: return w.get("hung", false)) or result == &"WAVE_HUNG",
		"short_waves": _waves.filter(func(w: Dictionary) -> bool: return float(w.get("combat_s", 0.0)) + 0.05 < float(w.get("min_duration", 0.0))).map(func(w: Dictionary) -> int: return int(w.wave)),
		"waves": _waves,
	}
	var line := JSON.stringify(row)
	print("[bot] RESULT ", line)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.READ_WRITE if FileAccess.file_exists(out_path) else FileAccess.WRITE)
		if f != null:
			f.seek_end()
			f.store_line(line)
			f.close()
	get_tree().quit(0 if result == &"DONE" else 1)
