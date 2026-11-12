extends Node3D
## Integration runner for the heal channel with stations placed by BuildService.
## Run with F6, prints OK/FAIL per case then quits.

const TICK := 1.0 / 60.0
const SLOT_SCENE := preload("res://systems/build/slot.tscn")
const STATION_SCENE := preload("res://entities/tower/heal_station.tscn")
const STATION_DATA := preload("res://data/towers/heal_station.tres")
const REWARD_POOL := preload("res://data/config/reward_pool.tres")

var _pass := 0
var _fail := 0
var _commander: CharacterBody3D
var _channel: HealChannel
var _fixture: Node3D
var _build: BuildService
var _rewards: RewardService
var _stations: Array[HealStation] = []
var _events: Array[StringName] = []
var _hold_events := 0

func _ready() -> void:
	EventBus.heal_state_changed.connect(_on_heal_state)
	await _run()
	_release_all()
	TimeManager.reset_time_scale()
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func _on_heal_state(state: StringName, _source: StringName, _progress: float) -> void:
	_events.append(state)
	if state == HealChannel.HOLD:
		_hold_events += 1

# Fresh commander in COMBAT with one station 1 m away, missing 50 HP.
func _setup(station_hp := 300.0, station_distance := 1.0, second_distance := INF) -> void:
	_release_all()
	TimeManager.reset_time_scale()
	if _fixture != null:
		_fixture.free()
	_stations.clear()
	_events.clear()
	_hold_events = 0
	_fixture = Node3D.new()
	add_child(_fixture)
	var gold := GoldManager.new()
	_fixture.add_child(gold)
	gold.gold = 2 * STATION_DATA.get_total_cost(1)
	_build = BuildService.new()
	_build.towers = [STATION_DATA]
	_build.tower_scenes = {STATION_DATA.id: STATION_SCENE}
	_fixture.add_child(_build)
	_rewards = RewardService.new()
	_rewards.pool = REWARD_POOL
	_fixture.add_child(_rewards)
	EventBus.state_changed.emit(&"PREP")
	var second: HealStation
	if is_finite(second_distance):
		second = _add_station(&"b", second_distance, 300.0)
	_stations.append(_add_station(&"a", station_distance, station_hp))
	if second != null:
		_stations.append(second)

	_commander = (load("res://entities/commander/commander.tscn") as PackedScene).instantiate()
	_fixture.add_child(_commander)
	_commander.set_physics_process(false)
	EventBus.mode_changed.emit(&"FRONTLINE")
	EventBus.state_changed.emit(&"COMBAT")
	_commander.health.hp = 50
	_channel = _commander.get_node("HealChannel") as HealChannel
	_channel.set_physics_process(false)

func _add_station(slot_id: StringName, distance: float, hp: float) -> HealStation:
	var slot := SLOT_SCENE.instantiate() as Slot
	slot.slot_id = slot_id
	slot.position = Vector3(distance, 0, 0)
	_fixture.add_child(slot)
	var built := _build.build(slot_id, STATION_DATA.id)
	assert(built, "BuildService must place the real heal station")
	var station := slot.tower as HealStation
	station.drain(station.hp - hp)
	return station

func _tick(seconds: float) -> void:
	var ticks := roundi(seconds / TICK)
	for i in ticks:
		_channel._physics_process(TICK)

func _hold() -> void:
	Input.action_press(&"heal_channel")

func _release_all() -> void:
	Input.action_release(&"heal_channel")
	for action in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(action)

func _station(index := 0) -> HealStation:
	return _stations[index]

func _run() -> void:
	_test_hold_gate()
	_test_conditions()
	_test_cancels()
	await _test_formula()
	_test_edge_cases()
	_test_stations()

func _test_hold_gate() -> void:
	_setup()
	_hold()
	_tick(0.9)
	_check("hold in progress at 0.9 s", _channel.phase == HealChannel.HOLD)
	_check("no HP healed while holding", _commander.health.hp == 50 and _station().hp == 300.0)
	_tick(0.2)
	_check("healing after 1.0 s of hold", _channel.phase == HealChannel.HEALING)
	_check("events are HOLD then HEALING", _events.size() >= 2 and _events[0] == HealChannel.HOLD and _events.back() == HealChannel.HEALING)
	_check("hold progress sent at most 10 times a second", _hold_events <= 11)

	_setup()
	_hold()
	_tick(0.6)
	Input.action_release(&"heal_channel")
	_tick(TICK * 2)
	_check("releasing early resets the hold", _channel.phase == HealChannel.IDLE and _channel.hold_time == 0.0)
	_hold()
	_tick(0.9)
	_check("a new hold starts from zero", _channel.phase == HealChannel.HOLD)

	_setup()
	_hold()
	_tick(1.1)
	Input.action_release(&"heal_channel")
	_tick(0.5)
	_check("releasing E during healing does not stop it", _channel.phase == HealChannel.HEALING and _commander.health.hp > 50)

func _test_conditions() -> void:
	for state in [&"PREP", &"SUMMARY", &"BOSS_INTRO", &"HAZARD_TRIAL"]:
		_setup()
		EventBus.state_changed.emit(state)
		_hold()
		_tick(1.5)
		_check_blocked("no hold in %s" % state, &"WAVE_STATE")

	_setup()
	EventBus.state_changed.emit(&"BOSS_COMBAT")
	_hold()
	_tick(1.2)
	_check("hold works in BOSS_COMBAT", _channel.phase == HealChannel.HEALING)

	_setup()
	EventBus.mode_changed.emit(&"COMMANDER")
	_hold()
	_tick(1.5)
	_check_blocked("no hold in Commander mode", &"COMMANDER_MODE")

	_setup()
	_commander.health.hp = _commander.health.max_hp
	_hold()
	_tick(1.5)
	_check_blocked("no hold at full HP", &"FULL_HP")

	_setup(300.0, 3.5)
	_hold()
	_tick(1.5)
	_check_blocked("no hold beyond 3 m", &"NO_STATION_IN_RANGE")

	_setup(0.0)
	_hold()
	_tick(1.5)
	_check_blocked("no hold on an empty station", &"NO_STATION_IN_RANGE")

	_setup()
	_hold()
	_tick(0.5)
	_commander.global_position = Vector3(-1.0, 0, 0)
	_tick(0.2)
	_check("hold survives while in range and moves on", _channel.phase == HealChannel.HOLD)

func _check_blocked(label: String, reason: StringName) -> void:
	_check(label, _channel.phase == HealChannel.IDLE and _channel.hold_time == 0.0
		and _channel.get_block_reason() == reason)

func _test_cancels() -> void:
	var cancels := {
		"move": func(): Input.action_press(&"move_right"),
		"dodge": func(): _commander.is_dodging = true,
		"attack": func(): _commander.is_attacking = true,
		"skill or battle cry": func(): _commander.is_using_skill = true,
		"recall": func(): _commander._mode_switch.request(),
		"damage": func(): _commander.take_damage(DamageInfo.new(5, Enums.DamageType.SLASH)),
		"area damage": func(): _commander.take_damage(DamageInfo.new(5, Enums.DamageType.BLAST)),
		"stun": func(): _commander.apply_stun(0.5),
		"knockback": func(): _commander._knockback_velocity = Vector3(3, 0, 0),
		"leaving range": func(): _commander.global_position = Vector3(-5, 0, 0),
		"pause": func(): TimeManager.request_pause(TimeManager.REASON_USER),
		"focus loss": func(): _channel.notification(NOTIFICATION_APPLICATION_FOCUS_OUT),
		"death": func(): _commander.take_damage(DamageInfo.new(500, Enums.DamageType.TRUE)),
	}
	for phase_name in [HealChannel.HOLD, HealChannel.HEALING]:
		var wait := 0.5 if phase_name == HealChannel.HOLD else 1.3
		for label in cancels:
			_setup()
			_hold()
			_tick(wait)
			_check("%s: reached %s" % [label, phase_name], _channel.phase == phase_name)
			var hp_before: float = _commander.health.get_precise_hp()
			cancels[label].call()
			var hp_after: float = _commander.health.get_precise_hp()
			var store_after := _station().hp
			_tick(TICK * 2)
			_check("%s cancels %s" % [label, phase_name], _channel.phase == HealChannel.IDLE and _events.has(HealChannel.CANCELLED))
			_check("%s: no healing or drain after cancellation" % label,
				is_equal_approx(_commander.health.get_precise_hp(), hp_after) and is_equal_approx(_station().hp, store_after))
			if phase_name == HealChannel.HEALING and label != "damage" and label != "area damage" and label != "death":
				_check("%s keeps the healed HP" % label, is_equal_approx(hp_after, hp_before))
			_commander.is_dodging = false
			_commander.is_attacking = false
			_commander.is_using_skill = false
			_commander.is_stunned = false
			_commander._knockback_velocity = Vector3.ZERO
			_commander._mode_switch.interrupt_recall()
			TimeManager.release_pause(TimeManager.REASON_USER)
			EventBus.mode_changed.emit(&"FRONTLINE")
			_commander.global_position = Vector3.ZERO
			Input.action_release(&"move_right")
			if label == "death":
				continue
			_tick(2.0)
			_check("%s: E still held does not restart" % label, _channel.phase == HealChannel.IDLE)
			Input.action_release(&"heal_channel")
			_tick(TICK * 2)
			_hold()
			_tick(0.5)
			_check("%s: release and press again holds" % label, _channel.phase == HealChannel.HOLD)

	# A cancel on the same tick the hold completes wins.
	_setup()
	_hold()
	_tick(59.0 * TICK)
	_commander.take_damage(DamageInfo.new(5, Enums.DamageType.TRUE))
	_tick(0.3)
	_check("cancel beats a hold that is about to complete", _channel.phase == HealChannel.IDLE and not _events.has(HealChannel.HEALING))

func _test_formula() -> void:
	# Use engine-driven physics here so TimeManager changes the delta the channel receives.
	for speed in [1, 2, 3]:
		for level in [0, 2]:
			_setup()
			if level == 2:
				_pick_heal_station_twice()
			var rate := 10.0 if level == 0 else 20.0
			var expected_hp := 100.0 + 10.0 * rate
			_commander.health.max_hp = int(expected_hp)
			_commander.health.hp = 100
			var real_tick := 1.0 / Engine.physics_ticks_per_second
			var hold_frames := await _start_timed_heal(speed)
			var label := "heal station skill level %d at x%d" % [level, speed]
			_check("%s starts after 1 game second" % label,
				_channel.phase == HealChannel.HEALING and absf(hold_frames * real_tick - 1.0 / speed) <= 2.0 * real_tick)
			_check("%s reads %.0f HP/s" % [label, rate], is_equal_approx(_channel.get_heal_rate(), rate))
			for _frame in roundi(10.0 / (real_tick * speed)):
				await get_tree().physics_frame
			_channel.set_physics_process(false)
			_check("%s reaches %.0f HP in 10 game seconds" % [label, expected_hp],
				absf(_commander.health.get_precise_hp() - expected_hp) < 1.0)
			_check("%s uses 200 HP from the real station" % label, absf(_station().hp - 100.0) < 1.0)

	# Near full: missing 3 at k 0.5 costs exactly 6 from the station and ends the channel.
	_setup()
	_commander.health.hp = _commander.health.max_hp - 3
	_hold()
	_tick(1.0 + 1.0)
	_check("near full: commander stops at max", _commander.health.hp == _commander.health.max_hp)
	_check("near full: station loses only 6", absf(_station().hp - 294.0) < 0.01)
	_check("near full: channel ends on its own", _channel.phase == HealChannel.IDLE and _events.back() == HealChannel.IDLE)

func _start_timed_heal(speed: int) -> int:
	TimeManager.set_time_scale(speed)
	_hold()
	_channel.set_physics_process(true)
	var frames := 0
	while _channel.phase != HealChannel.HEALING and frames < 2 * Engine.physics_ticks_per_second:
		await get_tree().physics_frame
		frames += 1
	return frames

func _pick_heal_station_twice() -> void:
	EventBus.state_changed.emit(&"REWARD_PICK")
	for level in [1, 2]:
		for _attempt in 30:
			_rewards.offer_next()
			if _rewards.pick(&"heal_station", &"PASSIVE", level):
				break
			_rewards.skip()
		_check("heal station skill level %d picked from the real reward pool" % level, _rewards.state.get_level(&"heal_station") == level)
	EventBus.state_changed.emit(&"COMBAT")

func _test_edge_cases() -> void:
	# A station freed mid-hold ends the hold without errors.
	_setup()
	_hold()
	_tick(0.5)
	_station().free()
	_stations.clear()
	_tick(TICK * 3)
	_check("station freed during hold cancels it", _channel.phase == HealChannel.IDLE and _events.has(HealChannel.CANCELLED))
	_check("a freed source is not returned", _channel.get_source() == null)

	# A station freed mid-healing ends the channel.
	_setup()
	_hold()
	_tick(1.3)
	_check("healing before the station is freed", _channel.phase == HealChannel.HEALING)
	_station().free()
	_stations.clear()
	_tick(TICK * 3)
	_check("station freed during healing ends it", _channel.phase == HealChannel.IDLE and _events.has(HealChannel.DEPLETED))

	# Wave leaving combat stops the channel and E must be pressed again.
	_setup()
	_hold()
	_tick(1.3)
	EventBus.state_changed.emit(&"SUMMARY")
	_tick(TICK * 3)
	_check("leaving combat ends healing", _channel.phase == HealChannel.IDLE and _events.has(HealChannel.CANCELLED))
	EventBus.state_changed.emit(&"COMBAT")
	_tick(1.5)
	_check("E still held after combat resumes does not restart", _channel.phase == HealChannel.IDLE)

	# Hold progress rises to 1 and the state events carry the source slot.
	var progress: Array[float] = []
	var slots: Array[StringName] = []
	var record := func(state: StringName, slot: StringName, value: float) -> void:
		if state == HealChannel.HOLD:
			progress.append(value)
			slots.append(slot)
	EventBus.heal_state_changed.connect(record)
	_setup()
	_hold()
	_tick(0.9)
	EventBus.heal_state_changed.disconnect(record)
	_check("hold progress only goes up", progress.size() > 1 and progress == _sorted(progress))
	_check("hold events name the station", slots.all(func(slot: StringName) -> bool: return slot == &"a"))

func _sorted(values: Array[float]) -> Array[float]:
	var copy: Array[float] = values.duplicate()
	copy.sort()
	return copy

func _test_stations() -> void:
	# Nearest station is the source, even when another is also in range.
	_setup(300.0, 2.0, 1.0)
	_hold()
	_tick(1.1)
	_check("nearest station is the source", _channel.get_source() == _station(1))

	# Slot b is built before a; discovery order must not decide a tie.
	_setup(300.0, 1.0, -1.0)
	_hold()
	_tick(0.1)
	_check("tie goes to the lower slot_id", _channel.get_source() == _station())

	# The source stays fixed once chosen, even if another becomes closer.
	_setup(300.0, 1.0, 2.5)
	var first := _station()
	var other := _station(1)
	_hold()
	_tick(0.1)
	_commander.global_position = Vector3(2.2, 0, 0)
	_tick(1.2)
	_check("source is locked at the start of the hold", _channel.get_source() == first and other.hp == 300.0)

	# An emptied station ends the channel; a new hold can use the next station.
	_setup(5.0, 1.0, 2.0)
	var second := _station(1)
	_hold()
	_tick(1.0 + 0.5)
	_check("empty station ends the channel with DEPLETED", _events.has(HealChannel.DEPLETED))
	_check("the empty station is not drained further", _stations[0].hp == 0.0)
	_tick(1.5)
	_check("E still held does not start on the next station", _channel.phase == HealChannel.IDLE and second.hp == 300.0)
	Input.action_release(&"heal_channel")
	_tick(TICK)
	_hold()
	_tick(0.1)
	_check("a fresh hold selects the next station", _channel.phase == HealChannel.HOLD and _channel.get_source() == second)
	_tick(1.1)
	_check("and drains the next station", _channel.phase == HealChannel.HEALING and second.hp < 300.0)

func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("[test] %s %s" % [label, "OK" if ok else "FAIL"])
