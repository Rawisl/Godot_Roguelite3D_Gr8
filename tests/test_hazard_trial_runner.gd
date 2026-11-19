extends Node
## Runner for the wave side of the Hazard Trial:
## - the group: 5 units from the wave's types, each type at least once, the same for the same seed;
##   a boss wave gives the boss and 4 escorts
## - entry rules, then HAZARD_TRIAL, the commander in the room and the group on the pads,
##   going for the commander only
## - kills in the room never reach the wave or the run tallies
## - results settled at the end of the frame: WON pays Mithril, LEFT and DIED only gold and XP,
##   DIED wins over WON in the same frame; afterwards the same PREP goes on and the room is used
## - ending the run in the room loses the room's rewards
## - x3 drops to x2 when the frame rate stays low
## The commander is a stand-in with the fields the room and the units read.

const ROOM_SCENE: PackedScene = preload("res://levels/corridor/hazard_room.tscn")

var passes: int = 0
var fails: int = 0
var _wm: WaveManager
var _rs: RunState
var _gold: GoldManager
var _room: HazardRoom
var _commander: StandInCommander
var _offers: Array = []
var _exits: Array = []
var _states: Array = []
var _enemy_deaths := 0
var _boss_defeats := 0
var _alerts: Array = []


class StandInCommander extends CharacterBody3D:
	var health := HealthComponent.new()
	var is_commander_mode := false

	func _init() -> void:
		health.max_hp = 100
		add_child(health)
		add_to_group(&"commander")


func _ready() -> void:
	print("\n=======================================================")
	print("              HAZARD TRIAL RUNNER TEST                 ")
	print("=======================================================")
	EventBus.hazard_trial_offered.connect(func(w: int, types: Array, m: int) -> void: _offers.append([w, types, m]))
	EventBus.hazard_trial_exited.connect(func(r: StringName, k: int, g: int, x: float, m: int) -> void: _exits.append({"result": r, "kills": k, "gold": g, "xp": x, "mithril": m}))
	EventBus.state_changed.connect(func(s: StringName) -> void: _states.append(s))
	EventBus.enemy_died.connect(func(_a, _b, _c, _d, _e, _f) -> void: _enemy_deaths += 1)
	EventBus.boss_defeated.connect(func() -> void: _boss_defeats += 1)
	EventBus.alert_requested.connect(func(_t: int, key: StringName, _p: Dictionary) -> void: _alerts.append(key))
	await _setup()

	await test_group()
	await test_offer_on_prep()
	await test_entry_rules()
	await test_enter_and_win()
	await test_leave()
	await test_died_beats_won()
	await test_run_end_in_room()
	await test_boss_room()
	test_frame_rate_downscale()

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")
	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		print("  [FAIL] %s" % test_name)


func _setup() -> void:
	_rs = RunState.new()
	add_child(_rs)
	_rs.run_seed = 1234
	_gold = GoldManager.new()
	add_child(_gold)
	_room = ROOM_SCENE.instantiate() as HazardRoom
	add_child(_room)
	_room.global_position = Vector3(0.0, 0.0, 200.0)
	_commander = StandInCommander.new()
	add_child(_commander)
	_commander.global_position = Vector3(-6.0, 0.0, 1.0)
	_wm = WaveManager.new()
	_wm.auto_advance_summary = false
	add_child(_wm)
	await get_tree().process_frame
	await get_tree().process_frame


func _units() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for unit in _wm.hazard_trial._units:
		if is_instance_valid(unit) and not unit.is_dead:
			result.append(unit)
	return result


func _kill(unit: Enemy) -> void:
	var info := DamageInfo.new(999999, Enums.DamageType.TRUE, _commander)
	info.hit_by_commander = true
	unit.health.hit_by_commander = true
	unit.take_damage(info)


func _fresh_prep(wave: int) -> void:
	_rs.wave_index = wave
	_wm.start_prep()
	await get_tree().process_frame


func test_group() -> void:
	print("\n[GROUP 1] The group")
	var trial := _wm.hazard_trial
	var wave := 6
	var group := trial.build_group(wave)
	var wave_types := {}
	for item in _wm.generate_wave_composition(wave, _wm.run_seed):
		wave_types[item["id"]] = true
	var group_types := {}
	for entry in group:
		group_types[entry["id"]] = true
	assert_true(group.size() == GameConfig.hazard_enemy_count, "5 units on a normal wave")
	assert_true(group_types.keys().all(func(t: StringName) -> bool: return wave_types.has(t)), "Only the wave's own types")
	if wave_types.size() <= GameConfig.hazard_enemy_count:
		assert_true(wave_types.keys().all(func(t: StringName) -> bool: return group_types.has(t)), "Every type of the wave at least once")
	var again := trial.build_group(wave)
	assert_true(again.map(func(e: Dictionary) -> StringName: return e["id"]) == group.map(func(e: Dictionary) -> StringName: return e["id"]),
			"Same seed and wave give the same group")
	var boss_group := trial.build_group(GameConfig.boss_wave_interval)
	assert_true(boss_group.size() == 1 + GameConfig.hazard_boss_escorts and boss_group[0]["boss"]
			and boss_group.slice(1).all(func(e: Dictionary) -> bool: return not e["boss"]), "A boss wave gives the boss and 4 escorts")


func test_offer_on_prep() -> void:
	print("\n[GROUP 2] Offer at the start of PREP")
	_offers.clear()
	await _fresh_prep(3)
	assert_true(_offers.size() == 1 and _offers[0][0] == 3 and (_offers[0][1] as Array).size() == GameConfig.hazard_enemy_count,
			"PREP offers the wave's group to the gate")
	assert_true(_offers[0][2] == _wm.hazard_trial.mithril_for(3), "The offer carries the Mithril for a win")


func test_entry_rules() -> void:
	print("\n[GROUP 3] Entry rules")
	var trial := _wm.hazard_trial
	assert_true(trial.entry_refusal() == &"", "Frontline in PREP with the room free can enter")
	TimeManager.request_pause(TimeManager.REASON_USER)
	assert_true(trial.entry_refusal() == HazardTrial.REASON_PAUSED, "Not while paused")
	TimeManager.release_pause(TimeManager.REASON_USER)
	_commander.is_commander_mode = true
	assert_true(trial.entry_refusal() == HazardTrial.REASON_FRONTLINE, "Not in Commander mode")
	_commander.is_commander_mode = false
	_rs.hazard_used = true
	assert_true(trial.entry_refusal() == HazardTrial.REASON_USED, "Once per wave")
	_rs.hazard_used = false
	_wm.wave_state = Enums.WaveState.COMBAT
	assert_true(not trial.enter(), "Not outside PREP")
	_wm.wave_state = Enums.WaveState.PREP


func test_enter_and_win() -> void:
	print("\n[GROUP 4] Enter, kill the group, win")
	var trial := _wm.hazard_trial
	var outside := _commander.global_position
	var queue_before := _wm.spawn_queue.size()
	var kills_before := _rs.run_kills
	var prestige_before := _rs.wave_prestige_buffer
	var gold_before := _gold.gold
	var tracker := _wm.get_xp_tracker()
	var xp_before: float = tracker.get(&"xp") + 0.0
	var level_before: int = tracker.get(&"commander_level")
	_states.clear()
	_enemy_deaths = 0
	EventBus.hazard_enter_requested.emit()
	assert_true(trial.is_active() and _wm.wave_state == Enums.WaveState.HAZARD_TRIAL and _states.has(&"HAZARD_TRIAL"),
			"E asks to enter and the wave switches to HAZARD_TRIAL")
	var spawn := _room.get_commander_spawn().global_position
	assert_true(_commander.global_position.distance_to(spawn) < 0.01, "The commander stands in the middle of the room")
	var units := _units()
	assert_true(units.size() == GameConfig.hazard_enemy_count and units.all(func(u: Enemy) -> bool: return u.in_hazard_room),
			"The group is in the room")
	assert_true(units.all(func(u: Enemy) -> bool: return u.global_position.distance_to(_room.global_position) < 40.0), "On the room's pads")
	for unit in units:
		unit._find_best_target()
	assert_true(units.all(func(u: Enemy) -> bool: return u.current_target == _commander), "Every unit goes for the commander")
	var expected_kill_gold := 0.0
	for unit in units:
		# Only the commander fights in the room, so every kill pays the commander's kill gold.
		unit.hit_by_commander = true
		expected_kill_gold += unit._get_kill_gold()
	for unit in units:
		_kill(unit)
	assert_true(_enemy_deaths == 0 and _rs.run_kills == kills_before and _rs.wave_prestige_buffer == prestige_before,
			"Room kills reach neither the wave nor the run tallies")
	assert_true(trial.is_active(), "The result waits for the end of the frame")
	await get_tree().process_frame
	var exit: Dictionary = _exits.back() if not _exits.is_empty() else {}
	assert_true(exit.get("result") == HazardTrial.WON and exit.get("kills") == GameConfig.hazard_enemy_count, "WON with 5 kills")
	assert_true(exit.get("mithril") == trial.mithril_for(3) and _rs.mithril == exit.get("mithril"), "A win pays the Mithril")
	assert_true(exit.get("gold") == WaveRewardTable.floor_gold(expected_kill_gold) and _gold.gold == gold_before + int(exit.get("gold")),
			"The kill gold of the wave goes to the wallet on leaving")
	var xp_now: float = tracker.get(&"xp")
	var level_now: int = tracker.get(&"commander_level")
	assert_true(float(exit.get("xp", 0.0)) > 0.0 and (xp_now > xp_before or level_now > level_before), "The room XP is added on leaving")
	assert_true(_wm.wave_state == Enums.WaveState.PREP and _states.back() == &"PREP" and _rs.hazard_used, "Back to PREP, room used")
	assert_true(_wm.spawn_queue.size() == queue_before, "The wave's own queue is untouched")
	assert_true(_commander.global_position.distance_to(outside) < 0.01, "The commander is back where it stood")
	assert_true(not trial.enter(), "No second room in the same wave")


func test_leave() -> void:
	print("\n[GROUP 5] Leave")
	await _fresh_prep(4)
	var trial := _wm.hazard_trial
	var mithril_before := _rs.mithril
	assert_true(not _rs.hazard_used and trial.enter(), "A new wave opens the room again")
	var units := _units()
	units[0].hit_by_commander = true
	units[1].hit_by_commander = true
	var expected := units[0]._get_kill_gold() + units[1]._get_kill_gold()
	_kill(units[0])
	_kill(units[1])
	EventBus.hazard_leave_requested.emit()
	await get_tree().process_frame
	var exit: Dictionary = _exits.back()
	assert_true(exit["result"] == HazardTrial.LEFT and exit["kills"] == 2 and exit["mithril"] == 0, "LEFT keeps the 2 kills, no Mithril")
	assert_true(exit["gold"] == WaveRewardTable.floor_gold(expected) and _rs.mithril == mithril_before, "Gold of the kills only")
	assert_true(_units().is_empty(), "The units left behind are removed")


func test_died_beats_won() -> void:
	print("\n[GROUP 6] Commander falls in the room")
	await _fresh_prep(7)
	var trial := _wm.hazard_trial
	assert_true(trial.enter(), "Enter")
	var units := _units()
	for unit in units:
		_kill(unit)
	_commander.health.take_damage(DamageInfo.new(999, Enums.DamageType.TRUE, null))
	await get_tree().process_frame
	var exit: Dictionary = _exits.back()
	assert_true(exit["result"] == HazardTrial.DIED and exit["mithril"] == 0, "Dying in the same frame as the last kill is DIED, no Mithril")
	assert_true(exit["kills"] == units.size() and exit["gold"] > 0, "DIED still pays the kills")
	assert_true(_wm.wave_state == Enums.WaveState.PREP, "The run goes on in PREP")
	_commander.health.hp = 100
	_commander.health.set_max_hp(100)


func test_run_end_in_room() -> void:
	print("\n[GROUP 7] Run ends in the room")
	await _fresh_prep(8)
	var trial := _wm.hazard_trial
	assert_true(trial.enter(), "Enter")
	var exits_before := _exits.size()
	var gold_before := _gold.gold
	_kill(_units()[0])
	EventBus.run_ended.emit(&"ABANDONED", {})
	await get_tree().process_frame
	assert_true(not trial.is_active() and _exits.size() == exits_before and _gold.gold == gold_before,
			"Abandoning in the room loses the room's rewards")
	assert_true(_units().is_empty(), "The room is emptied")
	_wm.wave_state = Enums.WaveState.PREP


func test_boss_room() -> void:
	print("\n[GROUP 8] Boss in the room")
	await _fresh_prep(GameConfig.boss_wave_interval)
	var trial := _wm.hazard_trial
	_boss_defeats = 0
	assert_true(trial.enter(), "Enter on a boss wave")
	var units := _units()
	var boss: Enemy = null
	for unit in units:
		if unit.is_boss():
			boss = unit
	assert_true(boss != null and bool(boss.get(&"in_hazard_trial")), "The boss is in the room as the room boss")
	var exits_before := _exits.size()
	for unit in units:
		if not unit.is_boss():
			_kill(unit)
	# The boss goes through its armour phase first; keep hitting until it is down.
	for i in 900:
		if not is_instance_valid(boss) or boss.is_dead:
			break
		_commander.health.hp = 100
		_kill(boss)
		await get_tree().physics_frame
	await get_tree().process_frame
	assert_true(_exits.size() == exits_before + 1, "The room settles once the boss is down")
	var exit: Dictionary = _exits.back()
	var boss_gold := WaveRewardTable.floor_gold(GameConfig.wave_rewards.get_boss_gold(GameConfig.boss_wave_interval))
	assert_true(exit["result"] == HazardTrial.WON and exit["gold"] >= boss_gold, "The room pays the boss gold")
	assert_true(_boss_defeats == 0 and _rs.run_bosses_defeated == 0, "The room boss is not the wave's boss")


func test_frame_rate_downscale() -> void:
	print("\n[GROUP 9] Low frame rate at x3")
	TimeManager.set_time_scale(3)
	_alerts.clear()
	TimeManager.check_frame_rate(1.0, 20.0)
	TimeManager.check_frame_rate(1.0, 20.0)
	assert_true(TimeManager.get_time_scale() == 3, "2 s under the floor keeps x3")
	TimeManager.check_frame_rate(1.0, 60.0)
	TimeManager.check_frame_rate(1.0, 20.0)
	TimeManager.check_frame_rate(1.0, 20.0)
	assert_true(TimeManager.get_time_scale() == 3, "A good frame starts the count again")
	TimeManager.check_frame_rate(1.0, 20.0)
	assert_true(TimeManager.get_time_scale() == 2 and _alerts.has(&"alert.fps_downscale"), "3 s under the floor drops to x2 and tells the player")
	for i in 5:
		TimeManager.check_frame_rate(1.0, 10.0)
	assert_true(TimeManager.get_time_scale() == 2, "x2 is never lowered further")
	TimeManager.set_time_scale(1)
