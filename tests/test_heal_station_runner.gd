extends Node3D

## Automated test runner for the Heal station:
## - the build cap, rubble counting and the places given back
## - draining (whole and fractional), destruction, no refill, sell value from the store
## - the contract with HealChannel, the store signal and a station destroyed mid-heal
## - an upgrade adds only the store it gains, up to the top level; a rebuild comes back with a full store

const SLOT_SCENE: PackedScene = preload("res://systems/build/slot.tscn")
const COMMANDER_SCENE: PackedScene = preload("res://entities/commander/commander.tscn")
const ARROW: TowerData = preload("res://data/towers/arrow.tres")
const HEAL: TowerData = preload("res://data/towers/heal_station.tres")
const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
const HEAL_SCENE: PackedScene = preload("res://entities/tower/heal_station.tscn")

const TICK := 1.0 / 60.0
## Level lost and rebuilt in the rebuild group.
const REBUILD_LEVEL := 14

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

class FakeWaveManager extends Node:
	var current_wave := 10
	var scale_config: ScaleConfig = preload("res://data/config/scale_config.tres")

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
	await test_damage_normalization()
	await test_fractional_drain()
	await test_contract()
	await test_no_attack()
	await test_store_signal()
	await test_real_channel()
	await test_destroyed_mid_heal()
	await test_upgrade_keeps_store()
	await test_upgrade_to_max_station()
	await test_rebuild_full_store()

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

## Upgrades the tower on slot_id until it reaches level; false as soon as one upgrade fails.
func _upgrade_to(slot_id: StringName, level: int) -> bool:
	if _slot(slot_id) == null or _slot(slot_id).tower == null:
		return false
	while _slot(slot_id).tower.level < level:
		if not _service.upgrade(slot_id):
			return false
	return true

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

func test_damage_normalization() -> void:
	print("\n[HT8] Incoming damage normalization")
	await _reset()
	_service.build(&"G1", &"heal_station")
	var station := _station()
	var manager := FakeWaveManager.new()
	add_child(manager)
	manager.add_to_group(&"wave_manager")
	var hit := DamageInfo.new(17, Enums.DamageType.PIERCE, self, 2.0, Vector3.LEFT, true)
	hit.raw = 8.5
	hit.dealt_mult = 2.0
	hit.is_dot = true
	hit.resist = 0.5
	hit.immune = true
	var received: Array[DamageInfo] = []
	station.health.damaged.connect(func(_amount: int, info: DamageInfo): received.append(info))
	assert_true(station.take_damage(hit) == 14, "HT8 wave 10 raw 17 becomes 14")
	assert_true(hit.amount == 17, "HT8 shared input remains unchanged")
	assert_true(received[0].source == self and received[0].damage_type == hit.damage_type
		and received[0].knockback_force == 2.0 and received[0].hit_direction == Vector3.LEFT
		and received[0].hit_by_commander, "HT8 damage metadata is preserved")
	assert_true(received[0].raw == hit.raw and received[0].dealt_mult == hit.dealt_mult
		and received[0].is_dot == hit.is_dot and received[0].resist == hit.resist
		and received[0].immune == hit.immune, "HT8 resolved damage metadata is preserved")
	manager.current_wave = 20
	assert_true(station.take_damage(40) == 24, "HT8 wave 20 raw 40 becomes 24")
	assert_true(station.take_damage(DamageInfo.new(40)) == 24, "HT8 DamageInfo uses current impact wave")
	assert_true(station.take_damage(1) == 1, "HT8 minimum damage is one")
	assert_true(station.take_damage(0) == 0 and station.take_damage(-5) == 0, "HT8 nonpositive hits do no damage")
	var before := station.hp
	station.drain(17.5)
	assert_true(is_equal_approx(before - station.hp, 17.5), "HT8 drain is not normalized")
	manager.free()
	assert_true(station.take_damage(17) == 17, "HT8 missing wave manager uses unscaled damage")
	var detached := HEAL_SCENE.instantiate() as HealStation
	assert_true(detached.take_damage(1) == 0, "HT8 uninitialized station ignores hits")
	add_child(detached)
	remove_child(detached)
	var hp_before := detached.health.hp
	assert_true(detached.take_damage(1) == 0 and detached.health.hp == hp_before,
		"HT8 detached station ignores hits")
	detached.free()
	station.take_damage(station.health.hp)
	assert_true(station.take_damage(1) == 0, "HT8 destroyed station ignores further hits")

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
	assert_true(not _service.get_tower_info(&"G1").is_max, "level 1 of 36 is not the top level")
	assert_true(_service.get_upgrade_block_reason(&"G1") != &"MAX_LEVEL", "the block reason is not MAX_LEVEL")

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

func test_upgrade_keeps_store() -> void:
	print("
[GROUP 15] Upgrade keeps the store")
	await _reset()
	EventBus.level_up.emit(GameConfig.tower_gate_tier2, 0)
	_service.build(&"G1", &"heal_station")
	var s := _station()
	s.drain(float(s.health.max_hp - 120))
	s.drain(0.5)
	var g := _gold.gold
	_store_signals.clear()
	assert_true(_service.upgrade(&"G1"), "the station upgrades")
	var gain: int = HEAL.levels[1].max_hp - HEAL.levels[0].max_hp
	assert_true(s.level == 2, "level is 2")
	assert_true(s.health.max_hp == HEAL.levels[1].max_hp, "capacity is the level 2 capacity")
	assert_true(s.health.hp == 120 + gain, "store grew by the capacity gained")
	assert_true(absf(s.hp - (float(s.health.hp) - 0.5)) < 0.001, "the drained fraction survives the upgrade")
	assert_true(g - _gold.gold == HEAL.levels[1].build_cost, "gold spent is the level 2 cost")
	assert_true(s.invested_gold == HEAL.get_total_cost(2), "invested gold is the total cost")
	assert_true(s.health.hp < s.health.max_hp, "the upgrade does not refill the store")
	var expected := floori(float(s.invested_gold) * GameConfig.sell_refund_pct * s.hp / float(s.health.max_hp) + HealStation.EPSILON)
	assert_true(_service.get_tower_info(&"G1").sell_value == expected, "sell value follows the store left")
	await get_tree().create_timer(0.15, true, false, true).timeout
	assert_true(not _store_signals.is_empty() and _store_signals.back() == [&"G1", s.health.hp, s.health.max_hp], "last store signal carries the new store")
	var flashed := false
	for sig in _store_signals:
		if sig[1] == sig[2]:
			flashed = true
	assert_true(not flashed, "no store signal shows a full store")
	var hp := s.health.hp
	EventBus.state_changed.emit(&"COMBAT")
	EventBus.state_changed.emit(&"PREP")
	assert_true(s.health.hp == hp, "the store is not refilled at PREP")

func test_upgrade_to_max_station() -> void:
	print("
[GROUP 16] Station upgrades to the top level")
	await _reset()
	EventBus.level_up.emit(GameConfig.tower_gate_tier3, 0)
	_gold.gold = 1000000
	_service.build(&"G1", &"heal_station")
	var s := _station()
	s.drain(float(s.health.max_hp) / 2.0)
	var bad_level := 0
	var bad_gain := 0
	var bad_cost := 0
	for n in range(2, GameConfig.tower_max_level + 1):
		var hp0 := s.health.hp
		var gold0 := _gold.gold
		if not _service.upgrade(&"G1") or s.level != n:
			bad_level = n
			break
		if bad_gain == 0 and s.health.hp - hp0 != HEAL.levels[n - 1].max_hp - HEAL.levels[n - 2].max_hp:
			bad_gain = n
		if bad_cost == 0 and gold0 - _gold.gold != HEAL.levels[n - 1].build_cost:
			bad_cost = n
	assert_true(bad_level == 0, "every upgrade to the top succeeds (first miss at level %d)" % bad_level)
	assert_true(bad_gain == 0, "the store gains only the added capacity at each level (first miss at level %d)" % bad_gain)
	assert_true(bad_cost == 0, "gold spent equals the level cost at each level (first miss at level %d)" % bad_cost)
	assert_true(s.level == GameConfig.tower_max_level, "the station is at the top level")
	assert_true(_service.get_upgrade_block_reason(&"G1") == &"MAX_LEVEL", "reason is MAX_LEVEL at the top")
	assert_true(_service.get_tower_info(&"G1").is_max, "info reports the top level")
	var g := _gold.gold
	assert_true(not _service.upgrade(&"G1"), "upgrade past the top refused")
	assert_true(_gold.gold == g, "gold unchanged by the refusal")
	await _reset()
	_service.build(&"G1", &"heal_station")
	assert_true(_upgrade_to(&"G1", GameConfig.tower_tier2_level - 1), "upgrades run up to just below the tier 2 level")
	assert_true(not _service.upgrade(&"G1"), "the tier 2 level is gated by the commander level")
	assert_true(_service.get_upgrade_block_reason(&"G1") == &"COMMANDER_LEVEL", "reason is COMMANDER_LEVEL")

func test_rebuild_full_store() -> void:
	print("
[GROUP 17] Rebuild at the lost level with a full store")
	await _reset()
	EventBus.level_up.emit(GameConfig.tower_gate_tier3, 0)
	_gold.gold = 1000000
	_service.build(&"G1", &"heal_station")
	assert_true(_upgrade_to(&"G1", REBUILD_LEVEL), "the station reaches the level to lose")
	var s := _station()
	s.drain(float(s.health.max_hp))
	assert_true(_slot(&"G1").state == Enums.SlotState.RUINED, "slot is RUINED")
	assert_true(_slot(&"G1").last_level == REBUILD_LEVEL, "last_level is the lost level")
	EventBus.run_started.emit()
	EventBus.state_changed.emit(&"PREP")
	_gold.gold = 1000000
	var o := _option(&"G1", &"heal_station", true)
	var summed := 0
	for lv in HEAL.levels.slice(0, REBUILD_LEVEL):
		summed += lv.build_cost
	assert_true(o.get("level") == REBUILD_LEVEL, "rebuild entry is at the lost level")
	assert_true(o.get("cost") == HEAL.get_total_cost(REBUILD_LEVEL), "rebuild cost is the total cost of the levels")
	assert_true(o.get("cost") == summed, "rebuild cost equals the summed level costs")
	var gold := _gold.gold
	assert_true(_service.build(&"G1", &"heal_station", REBUILD_LEVEL), "rebuild succeeds at commander level 0")
	var fresh := _station()
	var cap: int = HEAL.levels[REBUILD_LEVEL - 1].max_hp
	assert_true(fresh.level == REBUILD_LEVEL, "rebuilt at the lost level")
	assert_true(fresh.health.max_hp == cap and fresh.health.hp == cap, "the store is full at that level")
	assert_true(is_equal_approx(fresh.hp, float(cap)), "hp float equals max")
	assert_true(fresh.invested_gold == o.get("cost"), "invested gold equals the rebuild cost")
	assert_true(gold - _gold.gold == o.get("cost"), "gold spent equals the rebuild cost")
	assert_true(_service.get_heal_station_count() == 1, "one station counted")
