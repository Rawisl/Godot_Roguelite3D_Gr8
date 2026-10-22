extends Node3D
## Manual test for the heal channel with fake stations. Not shipped.
## Run with F6, prints OK/FAIL per case then quits.

const TICK := 1.0 / 60.0

var _pass := 0
var _fail := 0
var _commander: CharacterBody3D
var _channel: HealChannel
var _stations: Array[FakeHealStation] = []
var _events: Array[StringName] = []
var _hold_events := 0

func _ready() -> void:
	EventBus.heal_state_changed.connect(_on_heal_state)
	_run()
	_release_all()
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func _on_heal_state(state: StringName, _source: StringName, _progress: float) -> void:
	_events.append(state)
	if state == HealChannel.HOLD:
		_hold_events += 1

# Fresh commander in COMBAT with one station 1 m away, missing 50 HP.
func _setup(station_hp := 300.0, station_distance := 1.0) -> void:
	_release_all()
	if _commander != null:
		_commander.free()
	for station in _stations:
		station.free()
	_stations.clear()
	_events.clear()
	_hold_events = 0
	_commander = (load("res://entities/commander/commander.tscn") as PackedScene).instantiate()
	add_child(_commander)
	EventBus.mode_changed.emit(&"FRONTLINE")
	EventBus.state_changed.emit(&"COMBAT")
	_commander.health.hp = 50
	_channel = _commander.get_node("HealChannel") as HealChannel
	_add_station(&"a", station_distance, station_hp)

func _add_station(slot: StringName, distance: float, hp: float) -> FakeHealStation:
	var station := FakeHealStation.new()
	station.slot_id = slot
	station.max_hp = hp
	add_child(station)
	station.global_position = Vector3(distance, 0, 0)
	_stations.append(station)
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

func _station(index := 0) -> FakeHealStation:
	return _stations[index]

func _run() -> void:
	_test_hold_gate()
	_test_conditions()
	_test_cancels()
	_test_formula()
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
	_setup()
	EventBus.state_changed.emit(&"PREP")
	_hold()
	_tick(1.5)
	_check("no hold in PREP", _channel.phase == HealChannel.IDLE)

	for state in [&"SUMMARY", &"BOSS_INTRO"]:
		_setup()
		EventBus.state_changed.emit(state)
		_hold()
		_tick(1.5)
		_check("no hold in %s" % state, _channel.phase == HealChannel.IDLE)

	_setup()
	EventBus.state_changed.emit(&"BOSS_COMBAT")
	_hold()
	_tick(1.2)
	_check("hold works in BOSS_COMBAT", _channel.phase == HealChannel.HEALING)

	_setup()
	EventBus.mode_changed.emit(&"COMMANDER")
	_hold()
	_tick(1.5)
	_check("no hold in Commander mode", _channel.phase == HealChannel.IDLE)

	_setup()
	_commander.health.hp = _commander.health.max_hp
	_hold()
	_tick(1.5)
	_check("no hold at full HP", _channel.phase == HealChannel.IDLE)

	_setup(300.0, 3.5)
	_hold()
	_tick(1.5)
	_check("no hold beyond 3 m", _channel.phase == HealChannel.IDLE)

	_setup(0.0)
	_hold()
	_tick(1.5)
	_check("no hold on an empty station", _channel.phase == HealChannel.IDLE)

	_setup()
	_hold()
	_tick(0.5)
	_station().global_position = Vector3(2.0, 0, 0)
	_tick(0.2)
	_check("hold survives while in range and moves on", _channel.phase == HealChannel.HOLD)

func _test_cancels() -> void:
	var cancels := {
		"move": func(): Input.action_press(&"move_right"),
		"dodge": func(): _commander.is_dodging = true,
		"attack": func(): _commander.is_attacking = true,
		"skill or battle cry": func(): _commander.is_using_skill = true,
		"mode switch": func(): EventBus.mode_changed.emit(&"COMMANDER"),
		"damage": func(): _commander.take_damage(DamageInfo.new(5, Enums.DamageType.SLASH)),
		"area damage": func(): _commander.take_damage(DamageInfo.new(5, Enums.DamageType.TRUE)),
		"stun": func(): _commander.apply_stun(0.5),
		"knockback": func(): _commander._knockback_velocity = Vector3(3, 0, 0),
		"leaving range": func(): _station().global_position = Vector3(6, 0, 0),
		"pause": func(): EventBus.pause_changed.emit(true),
		"death": func(): _commander.take_damage(DamageInfo.new(500, Enums.DamageType.TRUE)),
	}
	for phase_name in [HealChannel.HOLD, HealChannel.HEALING]:
		var wait := 0.5 if phase_name == HealChannel.HOLD else 1.3
		for label in cancels:
			_setup()
			_hold()
			_tick(wait)
			_check("%s: reached %s" % [label, phase_name], _channel.phase == phase_name)
			var hp_before: int = _commander.health.hp
			cancels[label].call()
			_tick(TICK * 2)
			_check("%s cancels %s" % [label, phase_name], _channel.phase == HealChannel.IDLE and _events.has(HealChannel.CANCELLED))
			if phase_name == HealChannel.HEALING and label != "damage" and label != "area damage" and label != "death":
				_check("%s keeps the healed HP" % label, _commander.health.hp >= hp_before)
			_commander.is_dodging = false
			_commander.is_attacking = false
			_commander.is_using_skill = false
			_commander.is_stunned = false
			_commander._knockback_velocity = Vector3.ZERO
			EventBus.mode_changed.emit(&"FRONTLINE")
			_station().global_position = Vector3(1, 0, 0)
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
	# No skill: missing 100, 300 in the pool -> commander +100, station -200.
	_setup()
	_commander.health.max_hp = 200
	_commander.health.hp = 100
	_hold()
	_tick(1.0 + 10.0)
	_check("rate 10: commander gains 100", absf(_commander.health.hp - 200) <= 1)
	_check("rate 10: station loses 200", absf(_station().hp - 100.0) <= 1.0)

	# Skill level 2: 20 HP/s, k = 1.
	_setup()
	_channel.skill_level = 2
	_commander.health.max_hp = 300
	_commander.health.hp = 100
	_hold()
	_tick(1.0 + 10.0)
	_check("rate 20: commander gains 200", absf(_commander.health.hp - 300) <= 1)
	_check("rate 20: station loses 200", absf(_station().hp - 100.0) <= 1.0)

	# Near full: missing 3 at k 0.5 costs exactly 6 from the station and ends the channel.
	_setup()
	_commander.health.hp = _commander.health.max_hp - 3
	_hold()
	_tick(1.0 + 1.0)
	_check("near full: commander stops at max", _commander.health.hp == _commander.health.max_hp)
	_check("near full: station loses only 6", absf(_station().hp - 294.0) < 0.01)
	_check("near full: channel ends on its own", _channel.phase == HealChannel.IDLE and _events.back() == HealChannel.IDLE)

	# Same result at x3: the channel counts physics ticks, which are game time.
	_setup()
	Engine.time_scale = 3.0
	_commander.health.max_hp = 200
	_commander.health.hp = 100
	_hold()
	_tick(1.0 + 10.0)
	Engine.time_scale = 1.0
	_check("x3: same HP result", absf(_commander.health.hp - 200) <= 1)
	_check("x3: same station result", absf(_station().hp - 100.0) <= 1.0)

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
	_setup()
	_station().global_position = Vector3(2.0, 0, 0)
	var near := _add_station(&"b", 1.0, 300.0)
	_hold()
	_tick(1.1)
	_check("nearest station is the source", _channel.get_source() == near)

	# Tie goes to the lower slot id.
	_setup()
	_station().slot_id = &"z"
	_add_station(&"c", 1.0, 300.0)
	var lower := _add_station(&"b", 1.0, 300.0)
	_hold()
	_tick(0.1)
	_check("tie goes to the lower slot_id", _channel.get_source() == lower)

	# The source stays fixed once chosen, even if another becomes closer.
	_setup()
	var first := _station()
	var other := _add_station(&"b", 2.5, 300.0)
	_hold()
	_tick(0.1)
	other.global_position = Vector3(0.2, 0, 0)
	_tick(1.2)
	_check("source is locked at the start of the hold", _channel.get_source() == first and other.hp == 300.0)

	# An emptied station ends the channel; holding again drains the next one.
	_setup(5.0)
	var second := _add_station(&"b", 2.0, 300.0)
	_hold()
	_tick(1.0 + 0.5)
	_check("empty station ends the channel with DEPLETED", _events.has(HealChannel.DEPLETED))
	_check("the empty station is not drained further", _stations[0].hp == 0.0)
	_check("holding again starts a new hold", _channel.phase == HealChannel.HOLD and _channel.get_source() == second)
	_tick(1.0)
	_check("and drains the next station", _channel.phase == HealChannel.HEALING and second.hp < 300.0)

func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("[test] %s %s" % [label, "OK" if ok else "FAIL"])
