extends Node3D

## Automated test runner for the Heal station:
## - the build cap, rubble counting and the places given back
## - draining (whole and fractional), destruction, no refill, sell value from the store
## - the contract with HealChannel, the store signal and a station destroyed mid-heal

const SLOT_SCENE: PackedScene = preload("res://systems/build/slot.tscn")
const COMMANDER_SCENE: PackedScene = preload("res://entities/commander/commander.tscn")
const ARROW: TowerData = preload("res://data/towers/arrow.tres")
const HEAL: TowerData = preload("res://data/towers/heal_station.tres")
const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
const HEAL_SCENE: PackedScene = preload("res://entities/tower/heal_station.tscn")

const TICK := 1.0 / 60.0

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []

var _gold: GoldManager
var _service: BuildService
var _denied: Array = []
var _destroyed: Array = []
var _store_signals: Array = []
var _heal_states: Array = []
var _commander: CharacterBody3D
var _channel: HealChannel

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED HEAL STATION RUNNER TEST              ")
	print("=======================================================")

	_setup()
	# GoldManager resets itself on a deferred call; let it land before gold is set by hand.
	await get_tree().process_frame
	await test_limit()
	await test_ruined_counts()
	await test_places_given_back()
	await test_wall_refused()
	await test_drained_to_rubble()
	await test_killed_by_damage()
	await test_no_refill()
	await test_sell_value()
	await test_fractional_drain()
	await test_contract()
	await test_no_attack()
	await test_store_signal()
	await test_real_channel()
	await test_destroyed_mid_heal()

	Input.action_release(&"heal_channel")
	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")

	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)

func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		failed_names.append(test_name)
		printerr("  [FAIL] %s" % test_name)

func _setup() -> void:
	_gold = GoldManager.new()
	add_child(_gold)
	_service = BuildService.new()
	_service.towers = [ARROW, HEAL]
	_service.tower_scenes = {&"arrow": ARROW_SCENE, &"heal_station": HEAL_SCENE}
	add_child(_service)
	_make_slot(&"W1", Enums.SlotZone.WALL, Vector3(0, 0, 40))
	# G1 is next to the origin (inside heal_range of a commander there); the rest are far away.
	for i in 5:
		_make_slot(StringName("G%d" % (i + 1)), Enums.SlotZone.GROUND, Vector3(1.0 + 12.0 * i, 0, 0))
	EventBus.build_denied.connect(func(reason, shortfall): _denied.append([reason, shortfall]))
	EventBus.tower_destroyed.connect(func(slot_id): _destroyed.append(slot_id))
	EventBus.heal_tower_hp_changed.connect(func(slot_id, hp, max_hp): _store_signals.append([slot_id, hp, max_hp]))
	EventBus.heal_state_changed.connect(func(state, source, _progress): _heal_states.append([state, source]))

func _make_slot(id: StringName, zone: Enums.SlotZone, pos: Vector3) -> Slot:
	var slot := SLOT_SCENE.instantiate() as Slot
	slot.name = String(id)
	slot.slot_id = id
	slot.zone = zone
	add_child(slot)
	slot.global_position = pos
	return slot

## Empty slots, PREP, lots of gold, no commander, no recorded events.
func _reset() -> void:
	if _commander != null and is_instance_valid(_commander):
		remove_child(_commander)
		_commander.free()
	_commander = null
	_channel = null
	Input.action_release(&"heal_channel")
	for node in get_tree().get_nodes_in_group(&"slot"):
		(node as Slot).set_state(Enums.SlotState.EMPTY)
	# Towers of the last group are freed on the next frame.
	await get_tree().process_frame
	EventBus.run_started.emit()
	EventBus.state_changed.emit(&"PREP")
	EventBus.mode_changed.emit(&"FRONTLINE")
	await get_tree().process_frame
	_gold.gold = 5000
	_denied.clear()
	_destroyed.clear()
	_store_signals.clear()
	_heal_states.clear()

func _slot(id: StringName) -> Slot:
	return _service.find_slot(id)

func _tower(id: StringName = &"G1") -> Tower:
	return _slot(id).tower

func _station(id: StringName = &"G1") -> HealStation:
	return _slot(id).tower as HealStation

func _option(slot_id: StringName, type: StringName, rebuild: bool = false) -> Dictionary:
	for o in _service.get_build_options(slot_id):
		if o.data.id == type and o.rebuild == rebuild:
			return o
	return {}

func _build_two() -> void:
	_service.build(&"G1", &"heal_station")
	_service.build(&"G2", &"heal_station")

func test_limit() -> void:
	print("\n[GROUP 1] Build limit")
	await _reset()
	assert_true(_service.build(&"G1", &"heal_station"), "first station built")
	assert_true(_service.build(&"G2", &"heal_station"), "second station built")
	var gold := _gold.gold
	_denied.clear()
	assert_true(not _service.build(&"G3", &"heal_station"), "third station refused")
	assert_true(_gold.gold == gold, "gold unchanged by the refusal")
	assert_true(_denied == [[&"HEAL_LIMIT", 0]], "build_denied HEAL_LIMIT")
	assert_true(_option(&"G3", &"heal_station").get("locked_reason") == &"HEAL_LIMIT", "station entry locked with HEAL_LIMIT")
	assert_true(_option(&"G3", &"arrow").get("locked_reason") == &"", "arrow entry not locked")
	assert_true(_service.get_heal_station_count() == GameConfig.heal_tower_max_count, "count equals the cap")

func test_ruined_counts() -> void:
	print("\n[GROUP 2] Rubble still counts")
	await _reset()
	_build_two()
	_slot(&"G1").ruin()
	assert_true(_service.get_heal_station_count() == GameConfig.heal_tower_max_count, "count unchanged after ruin")
	_denied.clear()
	assert_true(not _service.build(&"G3", &"heal_station"), "G3 still refused")
	assert_true(_option(&"G1", &"heal_station", true).get("locked_reason") == &"", "rebuild entry not locked")
	assert_true(_option(&"G1", &"heal_station", false).get("locked_reason") == &"", "plain entry on own rubble not locked")
	assert_true(_service.build(&"G1", &"heal_station", 1), "plain build on own rubble allowed")

func test_places_given_back() -> void:
	print("\n[GROUP 3] Places given back")
	await _reset()
	_build_two()
	_slot(&"G1").ruin()
	assert_true(_service.clear_rubble(&"G1"), "rubble cleared")
	assert_true(_service.build(&"G3", &"heal_station"), "G3 builds after clearing rubble")
	await _reset()
	_build_two()
	assert_true(_service.sell(&"G1"), "station sold")
	assert_true(_service.build(&"G3", &"heal_station"), "G3 builds after a sale")
	await _reset()
	_build_two()
	_slot(&"G1").ruin()
	assert_true(_service.build(&"G1", &"arrow"), "arrow built over the station rubble")
	assert_true(_service.get_heal_station_count() == 1, "place given back")
	assert_true(_service.build(&"G3", &"heal_station"), "station builds on another slot")

func test_wall_refused() -> void:
	print("\n[GROUP 4] WALL slot")
	await _reset()
	assert_true(_option(&"W1", &"heal_station").is_empty(), "no station entry on a WALL slot")
	assert_true(not _service.build(&"W1", &"heal_station"), "build on a WALL slot refused")

func test_drained_to_rubble() -> void:
	print("\n[GROUP 5] Drained empty")
	await _reset()
	_service.build(&"G1", &"heal_station")
	var s := _station()
	s.drain(float(s.health.max_hp))
	assert_true(_slot(&"G1").state == Enums.SlotState.RUINED, "slot is RUINED")
	assert_true(_slot(&"G1").last_data.id == HEAL.id, "last_data is the station")
	assert_true(_slot(&"G1").last_level == 1, "last_level is 1")
	assert_true(_destroyed == [&"G1"], "tower_destroyed emitted once")
	var rebuild := _option(&"G1", &"heal_station", true)
	assert_true(rebuild.get("cost") == HEAL.get_total_cost(1), "rebuild cost is the total cost")
	assert_true(_service.build(&"G1", &"heal_station", 1), "rebuild succeeds")
	var fresh := _station()
	assert_true(fresh.health.hp == HEAL.levels[0].max_hp, "new station has a full store")
	assert_true(is_equal_approx(fresh.hp, float(HEAL.levels[0].max_hp)), "hp float equals max")

func test_killed_by_damage() -> void:
	print("\n[GROUP 6] Destroyed by damage")
	await _reset()
	_service.build(&"G1", &"heal_station")
	var s := _station()
	s.take_damage(s.health.max_hp)
	assert_true(_slot(&"G1").state == Enums.SlotState.RUINED, "slot is RUINED")
	assert_true(_slot(&"G1").last_data.id == HEAL.id, "last_data is the station")
	assert_true(_destroyed == [&"G1"], "tower_destroyed emitted once")

func test_no_refill() -> void:
	print("\n[GROUP 7] No refill at PREP")
	await _reset()
	_service.build(&"G1", &"heal_station")
	_service.build(&"G2", &"arrow")
	var s := _station()
	var arrow := _tower(&"G2")
	var left := 120
	s.drain(float(s.health.max_hp - left))
	arrow.take_damage(10)
	assert_true(not s.heals_on_prep(), "heals_on_prep is false")
	EventBus.state_changed.emit(&"COMBAT")
	EventBus.state_changed.emit(&"PREP")
	assert_true(s.health.hp == left, "station keeps its store")
	assert_true(arrow.health.hp == arrow.health.max_hp, "arrow refilled")

func test_sell_value() -> void:
	print("\n[GROUP 8] Sell value")
	await _reset()
	_service.build(&"G1", &"heal_station")
	_service.build(&"G2", &"arrow")
	var pct := GameConfig.sell_refund_pct
	var s := _station()
	var invested := s.invested_gold
	assert_true(_service.get_tower_info(&"G1").sell_value == floori(invested * pct), "full store refunds the normal share")
	assert_true(_service.get_tower_info(&"G2").sell_value == floori(_tower(&"G2").invested_gold * pct), "arrow refund unchanged")
	s.drain(float(s.health.max_hp) / 2.0)
	var half := floori(invested * pct * 0.5)
	assert_true(_service.get_tower_info(&"G1").sell_value == half, "half store refunds half")
	var before := _gold.gold
	assert_true(_service.sell(&"G1"), "sell succeeds")
	assert_true(_gold.gold - before == half, "gold gained equals the shown value")
	_service.build(&"G3", &"heal_station")
	var d := _station(&"G3")
	d.drain(float(d.health.max_hp))
	assert_true(not _service.sell(&"G3"), "a drained station cannot be sold")

func test_fractional_drain() -> void:
	print("\n[GROUP 9] Fractional drain")
	await _reset()
	_service.build(&"G1", &"heal_station")
	var s := _station()
	var m := s.health.max_hp
	for i in 800:
		s.drain(0.25)
	assert_true(s.health.hp == m - 200, "800 x 0.25 removes 200 HP")
	assert_true(absf(s.hp - float(m - 200)) < 0.001, "hp float matches")
	s.drain(0.0)
	s.drain(-1.0)
	assert_true(s.health.hp == m - 200, "zero and negative drain change nothing")
	await _reset()
	_service.build(&"G1", &"heal_station")
	s = _station()
	for i in 3:
		s.drain(0.3)
	assert_true(s.health.hp == m, "0.9 HP drained keeps whole HP")
	assert_true(absf(s.hp - (float(m) - 0.9)) < 0.001, "hp float shows the 0.9")
	s.drain(0.3)
	assert_true(s.health.hp == m - 1, "past 1.0 HP drops one")
	assert_true(absf(s.hp - (float(m) - 1.2)) < 0.001, "hp float shows 1.2")

func test_contract() -> void:
	print("\n[GROUP 10] HealChannel contract")
	await _reset()
	_service.build(&"G1", &"heal_station")
	var s := _station()
	assert_true(s.is_in_group(&"heal_station") and s.is_in_group(&"tower"), "in groups heal_station and tower")
	assert_true(s.slot_id == &"G1", "slot_id is G1")
	assert_true(s.is_alive(), "alive")
	assert_true(s.max_hp == float(s.health.max_hp), "max_hp equals the store capacity")
	_slot(&"G1").ruin()
	assert_true(not s.is_alive(), "not alive right after ruin")

func test_no_attack() -> void:
	print("\n[GROUP 11] Never attacks")
	await _reset()
	_service.build(&"G1", &"heal_station")
	var s := _station()
	assert_true(not s.can_attack(), "can_attack is false")
	assert_true(not s.aura_active, "aura off")
	assert_true(s.get_dealt_mult() == 1.0, "dealt multiplier is 1")
	assert_true(not s.range_area.monitoring, "range area not monitoring")
	assert_true(_service.get_tower_info(&"G1").is_max, "is_max")
	assert_true(not _service.upgrade(&"G1"), "upgrade refused")
	assert_true(_service.get_upgrade_block_reason(&"G1") == &"MAX_LEVEL", "block reason MAX_LEVEL")

func test_store_signal() -> void:
	print("\n[GROUP 12] Store signal")
	await _reset()
	_service.build(&"G1", &"heal_station")
	var s := _station()
	var m := s.health.max_hp
	for i in 5:
		s.drain(1.0)
	assert_true(_store_signals == [[&"G1", m - 1, m]], "five drains in one frame send one signal")
	await get_tree().create_timer(0.15, true, false, true).timeout
	assert_true(_store_signals.size() == 2, "the merged update arrives after the interval")
	assert_true(_store_signals.size() == 2 and _store_signals[1] == [&"G1", m - 5, m], "merged update carries the latest store")
	s.drain(float(s.health.hp))
	assert_true(_store_signals.size() == 3 and _store_signals[2][1] == 0, "empty store signals at once")

## A commander next to G1, in COMBAT with 50 HP.
func _spawn_commander() -> void:
	_commander = COMMANDER_SCENE.instantiate()
	add_child(_commander)
	EventBus.mode_changed.emit(&"FRONTLINE")
	EventBus.state_changed.emit(&"COMBAT")
	_commander.health.hp = 50
	_channel = _commander.get_node("HealChannel") as HealChannel

func _tick(seconds: float) -> void:
	for i in roundi(seconds / TICK):
		_channel._physics_process(TICK)

func test_real_channel() -> void:
	print("\n[GROUP 13] Real heal channel")
	await _reset()
	_service.build(&"G1", &"heal_station")
	var s := _station()
	_spawn_commander()
	Input.action_press(&"heal_channel")
	_tick(1.1)
	assert_true(_channel.phase == HealChannel.HEALING, "channel is HEALING")
	assert_true(_channel.get_source() == s, "source is the station")
	var store := s.hp
	var hp: int = _commander.health.hp
	_tick(0.5)
	assert_true(_commander.health.hp > hp, "commander HP rose")
	assert_true(s.hp < store, "station store fell")

func test_destroyed_mid_heal() -> void:
	print("\n[GROUP 14] Station destroyed while healing")
	await _reset()
	_service.build(&"G1", &"heal_station")
	var s := _station()
	_spawn_commander()
	Input.action_press(&"heal_channel")
	_tick(1.6)
	assert_true(_channel.phase == HealChannel.HEALING, "channel is HEALING before the hit")
	var hp: int = _commander.health.hp
	_destroyed.clear()
	_heal_states.clear()
	s.take_damage(s.health.hp)
	assert_true(_slot(&"G1").state == Enums.SlotState.RUINED, "slot is RUINED")
	assert_true(_destroyed == [&"G1"], "tower_destroyed emitted")
	_tick(0.2)
	assert_true(_channel.phase == HealChannel.IDLE, "channel back to IDLE")
	assert_true(not _heal_states.is_empty() and _heal_states[-1] == [HealChannel.DEPLETED, &"G1"], "last state is DEPLETED for G1")
	assert_true(_commander.health.hp == hp, "commander HP unchanged")
	await get_tree().process_frame
	assert_true(not is_instance_valid(s), "station freed")
	_tick(0.5)
	assert_true(_channel.phase == HealChannel.IDLE, "still IDLE")
	assert_true(_commander.health.hp == hp, "HP still unchanged")
	Input.action_release(&"heal_channel")
