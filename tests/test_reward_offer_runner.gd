extends Node

## Automated test runner verifying the reward offer generator, the reward pool
## resource and the RewardService offer, skip and flag behaviour.

const WHIRLWIND: SkillData = preload("res://data/skills/whirlwind.tres")
const SHARPNESS: SkillData = preload("res://data/skills/sharpness.tres")
const VITALITY: SkillData = preload("res://data/skills/vitality.tres")
const HEAL_STATION: SkillData = preload("res://data/skills/heal_station.tres")
const POOL_PATH := "res://data/config/reward_pool.tres"
const SEED_RUNS := 200

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED REWARD OFFER RUNNER TEST              ")
	print("=======================================================")

	test_tc1_seed_reproducible()
	test_tc2_count_and_distinct()
	test_tc3_filters()
	test_tc4_heal_station_flag_filter()
	test_tc5_empty_and_small_pools()
	test_tc7_card_format()
	test_tc9_pool_and_main_scene()
	test_tc10_offer_next_emits()
	await test_tc11_skip_and_pick()
	test_tc12_heal_station_flag_flow()
	test_tc15_request_signals_flow()
	test_tc16_listeners_see_new_state()
	test_tc17_unknown_id_ignored()
	await test_tc18_no_open_offer_ignored()
	test_pick_writes_run_state()
	test_picked_signal_ignores_ui_values()
	test_empty_pool_request_emits_empty_offer()
	await test_empty_pool_drains_pending_picks()

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

func _make_skill(id: StringName, kind: SkillData.Kind) -> SkillData:
	var d := SkillData.new()
	d.id = id
	d.kind = kind
	return d

## 3 ACTIVE, 4 PASSIVE and 2 STAT skills.
func _make_catalog() -> Array[SkillData]:
	var catalog: Array[SkillData] = []
	for i in 3:
		catalog.append(_make_skill(StringName("act%d" % i), SkillData.Kind.ACTIVE))
	for i in 4:
		catalog.append(_make_skill(StringName("pas%d" % i), SkillData.Kind.PASSIVE))
	for i in 2:
		catalog.append(_make_skill(StringName("stat%d" % i), SkillData.Kind.STAT))
	return catalog

func _ids(cards: Array[Dictionary]) -> Array[StringName]:
	var out: Array[StringName] = []
	for c in cards:
		out.append(c["id"])
	return out

func _has_id(cards: Array[Dictionary], id: StringName) -> bool:
	return _ids(cards).has(id)

func _all_distinct(ids: Array[StringName]) -> bool:
	for i in ids.size():
		if ids.find(ids[i]) != i:
			return false
	return true

## Same as _ids for the untyped arrays that signal handlers receive.
func _ids_any(cards: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for c in cards:
		out.append(c["id"])
	return out

func _pool() -> RewardPool:
	return load(POOL_PATH) as RewardPool

func _make_service() -> RewardService:
	var service := RewardService.new()
	service.pool = _pool()
	add_child(service)
	return service

## Fills every slot of one kind with ids that are not in any test catalog.
func _fill_slots(state: RunSkillState, kind: SkillData.Kind) -> void:
	var slots: Array[StringName] = state.active if kind == SkillData.Kind.ACTIVE else state.passive
	for i in slots.size():
		slots[i] = StringName("filler_%d_%d" % [kind, i])

## Runs generate for SEED_RUNS different seeds. Returns how many offers contained id.
func _count_appearances(state: RunSkillState, catalog: Array[SkillData], id: StringName, count: int) -> int:
	var hits := 0
	for s in SEED_RUNS:
		var cards := RewardOfferGenerator.generate(state, catalog, RewardOfferGenerator.make_rng(s, 0), count)
		if _has_id(cards, id):
			hits += 1
	return hits

func test_tc1_seed_reproducible() -> void:
	var catalog := _make_catalog()
	var state := RunSkillState.new()
	var first := _ids(RewardOfferGenerator.generate(state, catalog, RewardOfferGenerator.make_rng(777, 0), 3))
	var second := _ids(RewardOfferGenerator.generate(state, catalog, RewardOfferGenerator.make_rng(777, 0), 3))
	assert_true(not first.is_empty() and first == second, "TC1: same seed gives the same ids in the same order: %s vs %s" % [first, second])
	assert_true(RewardOfferGenerator.make_rng(777, 3).randi() == RewardOfferGenerator.make_rng(777, 3).randi(), "TC1: make_rng gives the same first randi for the same inputs")

	var sequences: Array = []
	for picks in 10:
		var ids := _ids(RewardOfferGenerator.generate(state, catalog, RewardOfferGenerator.make_rng(777, picks), 3))
		if not sequences.has(ids):
			sequences.append(ids)
	assert_true(sequences.size() >= 2, "TC1: picks_used 0..9 gives at least 2 different offers (%d)" % sequences.size())

	var seed_differs := false
	for s in range(1, 11):
		var ids := _ids(RewardOfferGenerator.generate(state, catalog, RewardOfferGenerator.make_rng(s, 0), 3))
		if ids != first:
			seed_differs = true
	assert_true(seed_differs, "TC1: a different run_seed gives at least one different offer")

func test_tc2_count_and_distinct() -> void:
	var catalog := _make_catalog()
	var state := RunSkillState.new()
	var cards := RewardOfferGenerator.generate(state, catalog, RewardOfferGenerator.make_rng(1, 0), 3)
	assert_true(cards.size() == 3, "TC2: count 3 returns 3 cards (%d)" % cards.size())
	assert_true(_all_distinct(_ids(cards)), "TC2: the 3 cards have different ids")
	assert_true(RewardOfferGenerator.generate(state, catalog, RewardOfferGenerator.make_rng(1, 0), 0).is_empty(), "TC2: count 0 returns []")
	assert_true(RewardOfferGenerator.generate(state, catalog, RewardOfferGenerator.make_rng(1, 0), -1).is_empty(), "TC2: count -1 returns []")

	var four: Array[SkillData] = [catalog[0], catalog[3], catalog[4], catalog[7]]
	var all_four := RewardOfferGenerator.generate(state, four, RewardOfferGenerator.make_rng(1, 0), 5)
	assert_true(all_four.size() == 4, "TC2: count 5 on 4 candidates returns 4 (%d)" % all_four.size())

	var messy: Array[SkillData] = [catalog[0], catalog[0], null, catalog[3]]
	var dedup := RewardOfferGenerator.generate(state, messy, RewardOfferGenerator.make_rng(1, 0), 3)
	assert_true(dedup.size() == 2 and _all_distinct(_ids(dedup)), "TC2: duplicate and null catalog entries give distinct cards (%s)" % [_ids(dedup)])

func test_tc3_filters() -> void:
	var catalog := _make_catalog()
	var count := catalog.size()

	# (a) maxed skill
	var maxed := catalog[0]
	var state_a := RunSkillState.new()
	state_a.levels[maxed.id] = maxed.get_max_level()
	assert_true(RewardOfferGenerator.get_weight(state_a, maxed) == 0, "TC3a: maxed skill has weight 0")
	assert_true(_count_appearances(state_a, catalog, maxed.id, count) == 0, "TC3a: maxed skill never offered")

	# (b) new ACTIVE with all active slots taken
	var new_active := catalog[1]
	var state_b := RunSkillState.new()
	_fill_slots(state_b, SkillData.Kind.ACTIVE)
	assert_true(RewardOfferGenerator.get_weight(state_b, new_active) == 0, "TC3b: new ACTIVE with full slots has weight 0")
	assert_true(_count_appearances(state_b, catalog, new_active.id, count) == 0, "TC3b: new ACTIVE with full slots never offered")

	# (c) ACTIVE already in a slot, slots full, not maxed
	var owned := catalog[2]
	var state_c := RunSkillState.new()
	state_c.take(owned)
	for i in range(1, state_c.active.size()):
		state_c.active[i] = StringName("filler_c_%d" % i)
	assert_true(state_c.free_slot_index(SkillData.Kind.ACTIVE) == -1, "TC3c: active slots are full")
	assert_true(RewardOfferGenerator.get_weight(state_c, owned) == GameConfig.reward_weight_owned, "TC3c: owned ACTIVE in a slot has the owned weight")
	assert_true(_count_appearances(state_c, catalog, owned.id, 3) > 0, "TC3c: owned ACTIVE is offered at least once")

	var fresh := RunSkillState.new()
	assert_true(RewardOfferGenerator.get_weight(fresh, catalog[0]) == GameConfig.reward_weight_new, "TC3c: new skill with a free slot has the new weight")
	assert_true(RewardOfferGenerator.get_weight(fresh, catalog[7]) == GameConfig.reward_weight_stat, "TC3c: unstacked STAT has the stat weight")

	# (d) new PASSIVE with all passive slots taken
	var new_passive := catalog[3]
	var state_d := RunSkillState.new()
	_fill_slots(state_d, SkillData.Kind.PASSIVE)
	assert_true(RewardOfferGenerator.get_weight(state_d, new_passive) == 0, "TC3d: new PASSIVE with full slots has weight 0")
	assert_true(_count_appearances(state_d, catalog, new_passive.id, count) == 0, "TC3d: new PASSIVE with full slots never offered")

	# (e) STAT at max stacks
	var stat := catalog[7]
	var state_e := RunSkillState.new()
	state_e.levels[stat.id] = GameConfig.stat_max_stacks
	assert_true(RewardOfferGenerator.get_weight(state_e, stat) == 0, "TC3e: STAT at max stacks has weight 0")
	assert_true(_count_appearances(state_e, catalog, stat.id, count) == 0, "TC3e: STAT at max stacks never offered")

	# (f) null data
	var with_null: Array[SkillData] = [null, catalog[0], catalog[3]]
	assert_true(RewardOfferGenerator.get_weight(RunSkillState.new(), null) == 0, "TC3f: null data has weight 0")
	var null_cards := RewardOfferGenerator.generate(RunSkillState.new(), with_null, RewardOfferGenerator.make_rng(1, 0), 3)
	var null_card := false
	for c in null_cards:
		if c["data"] == null:
			null_card = true
	assert_true(not null_card and null_cards.size() == 2, "TC3f: null data never becomes a card")

func test_tc4_heal_station_flag_filter() -> void:
	var catalog: Array[SkillData] = [HEAL_STATION, WHIRLWIND, SHARPNESS, VITALITY]
	var state := RunSkillState.new()
	assert_true(HEAL_STATION.requires_flag == RewardService.HEAL_STATION_FLAG, "TC4: heal_station requires the service flag")
	assert_true(RewardOfferGenerator.get_weight(state, HEAL_STATION) == 0, "TC4: no flag gives weight 0")
	assert_true(_count_appearances(state, catalog, HEAL_STATION.id, 3) == 0, "TC4: no flag, never offered")

	state.set_flag(HEAL_STATION.requires_flag)
	assert_true(RewardOfferGenerator.get_weight(state, HEAL_STATION) == GameConfig.reward_weight_new, "TC4: flag on gives the new weight")
	assert_true(_count_appearances(state, catalog, HEAL_STATION.id, 3) > 0, "TC4: flag on, offered at least once")

	state.set_flag(HEAL_STATION.requires_flag, false)
	assert_true(RewardOfferGenerator.get_weight(state, HEAL_STATION) == 0, "TC4: flag turned off gives weight 0 again")
	assert_true(_count_appearances(state, catalog, HEAL_STATION.id, 3) == 0, "TC4: flag turned off, never offered")

func test_tc5_empty_and_small_pools() -> void:
	var catalog := _make_catalog()
	var state := RunSkillState.new()

	var empty: Array[SkillData] = []
	assert_true(RewardOfferGenerator.generate(state, empty, RewardOfferGenerator.make_rng(1, 0), 3).is_empty(), "TC5a: empty catalog generates []")
	assert_true(not RewardOfferGenerator.has_offer(state, empty), "TC5a: empty catalog has no offer")

	var exhausted := RunSkillState.new()
	_fill_slots(exhausted, SkillData.Kind.ACTIVE)
	_fill_slots(exhausted, SkillData.Kind.PASSIVE)
	for d in catalog:
		if not d.is_slotted():
			exhausted.levels[d.id] = d.get_max_level()
	assert_true(RewardOfferGenerator.generate(exhausted, catalog, RewardOfferGenerator.make_rng(1, 0), 3).is_empty(), "TC5b: nothing offerable generates []")
	assert_true(not RewardOfferGenerator.has_offer(exhausted, catalog), "TC5b: nothing offerable has no offer")

	# One valid card, then two, next to cards that are filtered out.
	var maxed := catalog[0]
	var filtered_state := RunSkillState.new()
	filtered_state.levels[maxed.id] = maxed.get_max_level()
	var one: Array[SkillData] = [maxed, null, catalog[3]]
	var cards_one := RewardOfferGenerator.generate(filtered_state, one, RewardOfferGenerator.make_rng(1, 0), 3)
	assert_true(cards_one.size() == 1, "TC5c: one valid candidate gives 1 card (%d)" % cards_one.size())
	assert_true(RewardOfferGenerator.has_offer(filtered_state, one), "TC5c: has_offer true with one candidate")
	var two: Array[SkillData] = [maxed, null, catalog[3], catalog[7]]
	var cards_two := RewardOfferGenerator.generate(filtered_state, two, RewardOfferGenerator.make_rng(1, 0), 3)
	assert_true(cards_two.size() == 2, "TC5c: two valid candidates give 2 cards (%d)" % cards_two.size())
	assert_true(RewardOfferGenerator.has_offer(filtered_state, two), "TC5c: has_offer true with two candidates")

func test_tc7_card_format() -> void:
	var state := RunSkillState.new()
	state.take(WHIRLWIND)
	state.set_flag(HEAL_STATION.requires_flag)
	var catalog: Array[SkillData] = [WHIRLWIND, SHARPNESS, VITALITY, HEAL_STATION]
	var cards := RewardOfferGenerator.generate(state, catalog, RewardOfferGenerator.make_rng(1, 0), catalog.size())
	assert_true(cards.size() == catalog.size(), "TC7: every candidate became a card (%d)" % cards.size())
	var keys_ok := true
	var kind_ok := true
	var level_ok := true
	var new_ok := true
	var data_ok := true
	for c in cards:
		var keys: Array = c.keys()
		keys.sort()
		keys_ok = keys_ok and keys == ["data", "id", "is_new", "kind", "level", "next_level"]
		var data: SkillData = c["data"]
		kind_ok = kind_ok and c["kind"] is StringName and c["kind"] == StringName(SkillData.Kind.keys()[data.kind])
		level_ok = level_ok and c["next_level"] == c["level"] + 1
		new_ok = new_ok and c["is_new"] == (c["level"] == 0)
		data_ok = data_ok and data.id == c["id"]
	assert_true(keys_ok, "TC7: every card has exactly the 6 keys")
	assert_true(kind_ok, "TC7: kind is the StringName of SkillData.Kind")
	assert_true(level_ok, "TC7: next_level == level + 1")
	assert_true(new_ok, "TC7: is_new == (level == 0)")
	assert_true(data_ok, "TC7: data.id == id")
	for c in cards:
		match c["id"]:
			&"whirlwind":
				assert_true(c["kind"] == &"ACTIVE" and c["level"] == 1 and c["next_level"] == 2 and not c["is_new"], "TC7: owned level 1 card has next_level 2 and is_new false")
			&"sharpness", &"heal_station":
				assert_true(c["kind"] == &"PASSIVE" and c["is_new"], "TC7: new passive card is PASSIVE and is_new (%s)" % c["id"])
			&"vitality":
				assert_true(c["kind"] == &"STAT" and c["is_new"], "TC7: new stat card is STAT and is_new")

func test_tc9_pool_and_main_scene() -> void:
	var pool := _pool()
	assert_true(pool != null, "TC9: reward_pool.tres loads as RewardPool")
	if pool == null:
		return
	var ids: Array[StringName] = []
	var no_null := true
	for d in pool.skills:
		if d == null:
			no_null = false
		else:
			ids.append(d.id)
	assert_true(no_null and pool.skills.size() == 9, "TC9: pool has 9 non-null skills (%d)" % pool.skills.size())
	assert_true(_all_distinct(ids), "TC9: pool ids are distinct")
	for id: StringName in [&"whirlwind", &"sword_wave", &"firebomb", &"sharpness", &"armored", &"lifesteal", &"heal_station", &"vitality", &"mastery"]:
		assert_true(ids.has(id), "TC9: pool contains %s" % id)
	assert_true(pool.cards_per_pick == 3, "TC9: cards_per_pick is 3")

	var scene := load("res://main.tscn") as PackedScene
	assert_true(scene != null, "TC9: main.tscn loads")
	if scene == null:
		return
	var scene_state := scene.get_state()
	var found := false
	var pool_ok := false
	for i in scene_state.get_node_count():
		if scene_state.get_node_name(i) != &"RewardService":
			continue
		found = true
		for p in scene_state.get_node_property_count(i):
			if scene_state.get_node_property_name(i, p) == &"pool":
				pool_ok = scene_state.get_node_property_value(i, p) != null
	assert_true(found, "TC9: main.tscn has a RewardService node")
	assert_true(pool_ok, "TC9: main.tscn RewardService has a pool")

func test_tc10_offer_next_emits() -> void:
	var service := _make_service()
	var emitted: Array = []
	var on_offered := func(cards: Array, rerolls_left: int) -> void:
		emitted.append({"cards": cards, "rerolls_left": rerolls_left})
	EventBus.reward_offered.connect(on_offered)

	var first := service.offer_next()
	assert_true(emitted.size() == 1, "TC10: first offer_next emits reward_offered once (%d)" % emitted.size())
	var second := service.offer_next()
	assert_true(emitted.size() == 2, "TC10: second offer_next emits reward_offered once more (%d)" % emitted.size())
	EventBus.reward_offered.disconnect(on_offered)

	var expected := RewardOfferGenerator.generate(RunSkillState.new(), service.get_catalog(), RewardOfferGenerator.make_rng(0, 0), service.pool.cards_per_pick)
	assert_true(emitted.size() == 2 and emitted[0]["rerolls_left"] == 0 and emitted[1]["rerolls_left"] == 0, "TC10: rerolls_left is 0")
	assert_true(first.size() <= service.pool.cards_per_pick and not first.is_empty(), "TC10: card count is within cards_per_pick (%d)" % first.size())
	assert_true(emitted.size() == 2 and emitted[0]["cards"] == first and emitted[1]["cards"] == second, "TC10: emitted cards equal the returned cards")
	assert_true(_ids(first) == _ids(second), "TC10: two offers before a pick have the same ids")
	assert_true(_ids(first) == _ids(expected), "TC10: offer matches generate with make_rng(0, 0)")
	assert_true(_ids(service.get_current_offer()) == _ids(second), "TC10: get_current_offer returns the same cards")
	assert_true(service.has_offer(), "TC10: has_offer is true")
	service.free()

func test_tc11_skip_and_pick() -> void:
	var xp := XpTracker.new()
	add_child(xp)
	xp.pending_picks = 2
	var service := _make_service()
	var picked: Array = []
	var on_picked := func(card_id: StringName, slot_kind: StringName, new_level: int) -> void:
		picked.append([card_id, slot_kind, new_level])
	EventBus.reward_picked.connect(on_picked)

	assert_true(not service.skip(), "TC11: skip before any offer_next returns false")
	assert_true(picked.is_empty(), "TC11: skip before any offer emits nothing")

	service.offer_next()
	assert_true(service.skip(), "TC11: first skip returns true")
	assert_true(picked.size() == 1 and picked[0] == [&"", &"SKIP", 0], "TC11: skip emits reward_picked(&\"\", &\"SKIP\", 0): %s" % [picked])
	assert_true(service.state.picks_used == 1, "TC11: picks_used is 1 after a skip (%d)" % service.state.picks_used)
	assert_true(service.get_current_offer().is_empty(), "TC11: skip closes the offer")
	assert_true(not service.skip(), "TC11: second skip returns false")
	assert_true(picked.size() == 1, "TC11: second skip emits nothing")
	assert_true(xp.pending_picks == 1, "TC11: XpTracker pending_picks went 2 -> 1 (%d)" % xp.pending_picks)

	var next_offer := service.offer_next()
	var expected := RewardOfferGenerator.generate(RunSkillState.new(), service.get_catalog(), RewardOfferGenerator.make_rng(0, 1), service.pool.cards_per_pick)
	assert_true(_ids(next_offer) == _ids(expected), "TC11: next offer uses make_rng(seed, picks_used 1)")

	var card := next_offer[0]
	assert_true(service.pick(card["id"], card["kind"], card["next_level"]), "TC11: pick of a card in the offer returns true")
	EventBus.reward_picked.disconnect(on_picked)
	assert_true(service.state.picks_used == 2, "TC11: a picked card adds to picks_used (%d)" % service.state.picks_used)
	assert_true(not service.skip(), "TC11: skip after a picked card returns false")
	assert_true(service.get_current_offer().is_empty(), "TC11: a picked card closes the offer")
	# A pick writes the card to the run state.
	assert_true(service.state.get_level(card["id"]) == 1, "TC11: a picked card is written to the run state at level 1 (%d)" % service.state.get_level(card["id"]))

	service.free()
	# XpTracker defers its first xp_changed, so let that call run before freeing it.
	await get_tree().process_frame
	xp.free()

func test_tc12_heal_station_flag_flow() -> void:
	var flag := RewardService.HEAL_STATION_FLAG

	# Before the flag: 20 offers, none holds heal_station.
	var before := _make_service()
	var seen_before := false
	for i in 20:
		if _has_id(before.offer_next(), HEAL_STATION.id):
			seen_before = true
		before.skip()
	before.free()
	assert_true(not seen_before, "TC12: no offer holds heal_station before the flag")

	var service := _make_service()
	EventBus.tower_built.emit(&"G1", &"arrow")
	assert_true(not service.state.has_flag(flag), "TC12: building an arrow tower does not set the flag")
	EventBus.tower_built.emit(&"G1", &"heal_station")
	assert_true(service.state.flags.get(flag, false), "TC12: building heal_station sets the flag")
	EventBus.tower_sold.emit(&"G1")
	assert_true(service.state.has_flag(flag), "TC12: selling the tower keeps the flag")
	EventBus.tower_destroyed.emit(&"G1")
	assert_true(service.state.has_flag(flag), "TC12: a destroyed tower keeps the flag")

	var seen_after := false
	for i in 20:
		if _has_id(service.offer_next(), HEAL_STATION.id):
			seen_after = true
		service.skip()
	assert_true(seen_after, "TC12: heal_station shows up in an offer once the flag is on")

	service.offer_next()
	assert_true(service.state.picks_used > 0, "TC12: picks_used is above 0 before run_started")
	EventBus.run_started.emit()
	assert_true(not service.state.has_flag(flag), "TC12: run_started clears the flag")
	assert_true(service.state.picks_used == 0, "TC12: run_started resets picks_used")
	assert_true(service.state.levels.is_empty(), "TC12: run_started clears levels")
	assert_true(not service.skip(), "TC12: run_started closes the open offer")
	service.free()

func test_tc15_request_signals_flow() -> void:
	var service := _make_service()
	var offered: Array = []
	var picked: Array = []
	var on_offered := func(cards: Array, rerolls_left: int) -> void:
		offered.append({"ids": _ids_any(cards), "rerolls_left": rerolls_left})
	var on_picked := func(card_id: StringName, slot_kind: StringName, new_level: int) -> void:
		picked.append([card_id, slot_kind, new_level])
	EventBus.reward_offered.connect(on_offered)
	EventBus.reward_picked.connect(on_picked)
	var per_pick := service.pool.cards_per_pick

	EventBus.reward_offer_requested.emit()
	var expected_first := _ids(RewardOfferGenerator.generate(RunSkillState.new(), service.get_catalog(), RewardOfferGenerator.make_rng(0, 0), per_pick))
	assert_true(offered.size() == 1, "TC15: first reward_offer_requested emits reward_offered once (%d)" % offered.size())
	assert_true(offered.size() == 1 and offered[0]["rerolls_left"] == 0, "TC15: rerolls_left is 0")
	assert_true(offered.size() == 1 and offered[0]["ids"] == expected_first and not expected_first.is_empty(), "TC15: first offer matches generate with make_rng(0, 0)")
	var card := service.get_current_offer()[0]

	EventBus.reward_offer_requested.emit()
	assert_true(offered.size() == 2 and offered[1]["ids"] == expected_first, "TC15: a second request re-emits the same offer in the same order")
	assert_true(service.state.picks_used == 0 and picked.is_empty(), "TC15: a second request neither counts a pick nor emits reward_picked")

	EventBus.reward_pick_requested.emit(card["id"], card["kind"], card["next_level"])
	assert_true(picked.size() == 1 and picked[0] == [card["id"], card["kind"], card["next_level"]], "TC15: pick request emits reward_picked with the card values: %s" % [picked])
	assert_true(service.state.picks_used == 1, "TC15: picks_used is 1 after the pick request (%d)" % service.state.picks_used)
	assert_true(service.get_current_offer().is_empty(), "TC15: the pick request closes the offer")

	EventBus.reward_offer_requested.emit()
	var expected_next := _ids(RewardOfferGenerator.generate(RunSkillState.new(), service.get_catalog(), RewardOfferGenerator.make_rng(0, 1), per_pick))
	assert_true(offered.size() == 3 and offered[2]["ids"] == expected_next, "TC15: the next request builds a new offer with make_rng(0, 1)")

	EventBus.reward_skip_requested.emit()
	assert_true(picked.size() == 2 and picked[1] == [&"", &"SKIP", 0], "TC15: skip request emits reward_picked(&\"\", &\"SKIP\", 0): %s" % [picked])
	assert_true(service.state.picks_used == 2, "TC15: picks_used is 2 after the skip request (%d)" % service.state.picks_used)
	assert_true(service.get_current_offer().is_empty(), "TC15: the skip request closes the offer")

	EventBus.reward_offered.disconnect(on_offered)
	EventBus.reward_picked.disconnect(on_picked)
	service.free()

func test_tc16_listeners_see_new_state() -> void:
	var service := _make_service()
	var seen_a: Array = []
	var seen_b: Array = []
	var on_picked_a := func(_card_id: StringName, _slot_kind: StringName, _new_level: int) -> void:
		seen_a.append([service.state.picks_used, service.get_current_offer().size()])
	var on_picked_b := func(_card_id: StringName, _slot_kind: StringName, _new_level: int) -> void:
		seen_b.append([service.state.picks_used, service.get_current_offer().size()])
	EventBus.reward_picked.connect(on_picked_a)
	EventBus.reward_picked.connect(on_picked_b)

	# Round 1: pick through the request signal.
	var card := service.offer_next()[0]
	EventBus.reward_pick_requested.emit(card["id"], card["kind"], card["next_level"])
	assert_true(seen_a == [[1, 0]], "TC16: listener A sees picks_used 1 and an empty offer after a pick request: %s" % [seen_a])
	assert_true(seen_b == [[1, 0]], "TC16: listener B connected later sees the same values: %s" % [seen_b])

	# Round 2: skip through the request signal.
	service.offer_next()
	EventBus.reward_skip_requested.emit()
	assert_true(seen_a == [[1, 0], [2, 0]], "TC16: listener A sees picks_used 2 after a skip request: %s" % [seen_a])
	assert_true(seen_b == [[1, 0], [2, 0]], "TC16: listener B sees picks_used 2 after a skip request: %s" % [seen_b])

	# Round 3: direct call.
	card = service.offer_next()[0]
	assert_true(service.pick(card["id"], card["kind"], card["next_level"]), "TC16: direct pick returns true")
	assert_true(seen_a == [[1, 0], [2, 0], [3, 0]], "TC16: listener A sees picks_used 3 after a direct pick: %s" % [seen_a])
	assert_true(seen_b == [[1, 0], [2, 0], [3, 0]], "TC16: listener B sees picks_used 3 after a direct pick: %s" % [seen_b])

	EventBus.reward_picked.disconnect(on_picked_a)
	EventBus.reward_picked.disconnect(on_picked_b)
	service.free()

func test_tc17_unknown_id_ignored() -> void:
	var service := _make_service()
	var picked: Array = []
	var on_picked := func(card_id: StringName, slot_kind: StringName, new_level: int) -> void:
		picked.append([card_id, slot_kind, new_level])
	EventBus.reward_picked.connect(on_picked)

	var offer := service.offer_next()
	var offer_ids := _ids(offer)
	EventBus.reward_pick_requested.emit(&"missing_id", &"ACTIVE", 1)
	assert_true(picked.is_empty(), "TC17: a pick request with an unknown id emits nothing")
	assert_true(not service.pick(&"missing_id", &"ACTIVE", 1), "TC17: pick with an unknown id returns false")
	assert_true(not service.pick(&"", &"SKIP", 0), "TC17: pick with an empty id returns false")
	assert_true(picked.is_empty(), "TC17: rejected picks emit nothing")
	assert_true(service.state.picks_used == 0, "TC17: picks_used stays 0 after rejected picks (%d)" % service.state.picks_used)
	assert_true(_ids(service.get_current_offer()) == offer_ids and not offer_ids.is_empty(), "TC17: the open offer is unchanged")
	assert_true(service.has_offer(), "TC17: has_offer is still true")

	var card := offer[0]
	assert_true(service.pick(card["id"], card["kind"], card["next_level"]), "TC17: a valid card is still accepted afterwards")
	assert_true(picked.size() == 1 and service.state.picks_used == 1, "TC17: the valid pick emits once and counts once (%d, %d)" % [picked.size(), service.state.picks_used])
	assert_true(service.get_current_offer().is_empty(), "TC17: the valid pick closes the offer")

	EventBus.reward_picked.disconnect(on_picked)
	service.free()

func test_tc18_no_open_offer_ignored() -> void:
	var xp := XpTracker.new()
	add_child(xp)
	xp.pending_picks = 2
	var service := _make_service()
	var picked: Array = []
	var on_picked := func(card_id: StringName, slot_kind: StringName, new_level: int) -> void:
		picked.append([card_id, slot_kind, new_level])
	EventBus.reward_picked.connect(on_picked)

	# No offer was ever opened.
	EventBus.reward_pick_requested.emit(&"whirlwind", &"ACTIVE", 1)
	EventBus.reward_skip_requested.emit()
	assert_true(not service.pick(&"whirlwind", &"ACTIVE", 1), "TC18: pick before any offer returns false")
	assert_true(not service.skip(), "TC18: skip before any offer returns false")
	assert_true(picked.is_empty(), "TC18: nothing is emitted before any offer")
	assert_true(service.state.picks_used == 0, "TC18: picks_used stays 0 before any offer (%d)" % service.state.picks_used)
	assert_true(xp.pending_picks == 2, "TC18: pending_picks is untouched before any offer (%d)" % xp.pending_picks)

	# One valid skip, then requests against the closed offer.
	var closed_id: StringName = service.offer_next()[0]["id"]
	EventBus.reward_skip_requested.emit()
	assert_true(picked.size() == 1 and service.state.picks_used == 1, "TC18: the one valid skip emits once and counts once (%d, %d)" % [picked.size(), service.state.picks_used])
	assert_true(xp.pending_picks == 1, "TC18: pending_picks went 2 -> 1 after the valid skip (%d)" % xp.pending_picks)
	EventBus.reward_skip_requested.emit()
	EventBus.reward_pick_requested.emit(closed_id, &"ACTIVE", 1)
	assert_true(not service.skip() and not service.pick(closed_id, &"ACTIVE", 1), "TC18: skip and pick on the closed offer return false")
	assert_true(picked.size() == 1, "TC18: requests on the closed offer emit nothing")
	assert_true(service.state.picks_used == 1, "TC18: picks_used stays 1 after the closed offer is hit again (%d)" % service.state.picks_used)
	assert_true(xp.pending_picks == 1, "TC18: pending_picks stays 1 after the closed offer is hit again (%d)" % xp.pending_picks)

	# run_started closes an open offer.
	service.offer_next()
	EventBus.run_started.emit()
	assert_true(service.get_current_offer().is_empty(), "TC18: run_started closes the open offer")
	assert_true(service.state.picks_used == 0, "TC18: run_started resets picks_used (%d)" % service.state.picks_used)
	EventBus.reward_skip_requested.emit()
	assert_true(picked.size() == 1 and service.state.picks_used == 0, "TC18: skip request after run_started emits nothing and counts nothing (%d, %d)" % [picked.size(), service.state.picks_used])

	EventBus.reward_picked.disconnect(on_picked)
	service.free()
	# XpTracker defers its first xp_changed, so let that call run before freeing it.
	await get_tree().process_frame
	xp.free()

func _make_service_with(skills: Array[SkillData]) -> RewardService:
	var service := RewardService.new()
	var pool := RewardPool.new()
	pool.skills = skills
	service.pool = pool
	add_child(service)
	return service

func _card_by_id(cards: Array[Dictionary], id: StringName) -> Dictionary:
	for c in cards:
		if c["id"] == id:
			return c
	return {}

func test_pick_writes_run_state() -> void:
	var service := _make_service_with([WHIRLWIND, SHARPNESS, VITALITY])
	var first := service.offer_next()
	var card := _card_by_id(first, &"whirlwind")
	assert_true(not card.is_empty(), "pick state: whirlwind is in the first offer")
	assert_true(service.pick(&"whirlwind", &"ACTIVE", 1), "pick state: pick returns true")
	assert_true(service.state.get_level(&"whirlwind") == 1, "pick state: whirlwind level is 1 after the pick (%d)" % service.state.get_level(&"whirlwind"))
	assert_true(service.state.active.has(&"whirlwind"), "pick state: whirlwind sits in an active slot")
	assert_true(service.state.picks_used == 1, "pick state: picks_used is 1")

	var next_offer := service.offer_next()
	var owned := _card_by_id(next_offer, &"whirlwind")
	assert_true(not owned.is_empty() and owned["level"] == 1 and owned["next_level"] == 2 and owned["kind"] == &"ACTIVE" and not owned["is_new"], "pick state: next offer shows whirlwind as owned level 1 -> 2: %s" % [owned])
	assert_true(RewardOfferGenerator.get_weight(service.state, WHIRLWIND) == GameConfig.reward_weight_owned, "pick state: owned weight applies to the picked skill")

	# A pool with one skill: it keeps coming back until max, then the pool is empty.
	var single := _make_service_with([WHIRLWIND])
	var max_level := WHIRLWIND.get_max_level()
	for i in max_level:
		var offer := single.offer_next()
		assert_true(_ids(offer) == [&"whirlwind"], "pick state: round %d still offers whirlwind" % (i + 1))
		single.pick(&"whirlwind", &"", 0)
	assert_true(single.state.get_level(&"whirlwind") == max_level, "pick state: level reaches max (%d)" % single.state.get_level(&"whirlwind"))
	assert_true(single.offer_next().is_empty() and not single.has_offer(), "pick state: a maxed skill is not offered again")
	single.free()
	service.free()

func test_picked_signal_ignores_ui_values() -> void:
	var service := _make_service_with([WHIRLWIND, SHARPNESS, VITALITY])
	var picked: Array = []
	var on_picked := func(card_id: StringName, slot_kind: StringName, new_level: int) -> void:
		picked.append([card_id, slot_kind, new_level])
	EventBus.reward_picked.connect(on_picked)

	service.offer_next()
	EventBus.reward_pick_requested.emit(&"whirlwind", &"PASSIVE", 0)
	assert_true(picked == [[&"whirlwind", &"ACTIVE", 1]], "ui values: wrong kind and level 0 are replaced by the card's: %s" % [picked])

	service.offer_next()
	EventBus.reward_pick_requested.emit(&"whirlwind", &"STAT", 99)
	assert_true(picked.size() == 2 and picked[1] == [&"whirlwind", &"ACTIVE", 2], "ui values: second pick reports level 2 from the state: %s" % [picked])

	service.offer_next()
	EventBus.reward_pick_requested.emit(&"vitality", &"", -5)
	assert_true(picked.size() == 3 and picked[2] == [&"vitality", &"STAT", 1], "ui values: a stat card reports STAT level 1: %s" % [picked])

	EventBus.reward_picked.disconnect(on_picked)
	service.free()

func test_empty_pool_request_emits_empty_offer() -> void:
	var service := _make_service_with([])
	var offered: Array = []
	var picked: Array = []
	var on_offered := func(cards: Array, rerolls_left: int) -> void:
		offered.append([cards.size(), rerolls_left])
	var on_picked := func(card_id: StringName, slot_kind: StringName, new_level: int) -> void:
		picked.append([card_id, slot_kind, new_level])
	EventBus.reward_offered.connect(on_offered)
	EventBus.reward_picked.connect(on_picked)

	EventBus.reward_offer_requested.emit()
	assert_true(offered == [[0, 0]], "empty pool: the request emits reward_offered([], 0) once: %s" % [offered])
	assert_true(picked == [[&"", &"SKIP", 0]], "empty pool: the request emits reward_picked skip once: %s" % [picked])
	assert_true(service.state.picks_used == 1, "empty pool: the request counts as one skip (%d)" % service.state.picks_used)
	assert_true(service.get_current_offer().is_empty(), "empty pool: no offer is opened")
	assert_true(not service.skip(), "empty pool: skip() still returns false without an open offer")

	EventBus.reward_offer_requested.emit()
	assert_true(offered.size() == 2 and picked.size() == 2 and service.state.picks_used == 2, "empty pool: each request is answered once and skipped once")

	service.offer_next()
	assert_true(offered.size() == 2 and picked.size() == 2, "empty pool: offer_next called directly stays silent (%d)" % offered.size())

	EventBus.reward_offered.disconnect(on_offered)
	EventBus.reward_picked.disconnect(on_picked)
	service.free()

## Real XpTracker with 3 pending picks and an empty pool: a listener standing in for the screen asks again
## after every pick until the tracker has nothing pending.
func test_empty_pool_drains_pending_picks() -> void:
	var service := _make_service_with([])
	var tracker := XpTracker.new()
	add_child(tracker)
	tracker.pending_picks = 3
	var skips := [0]
	var requests := [0]
	var max_requests := 10
	var ask_next := func() -> void:
		if tracker.pending_picks > 0 and requests[0] < max_requests:
			requests[0] += 1
			EventBus.reward_offer_requested.emit()
	var on_picked := func(_card_id: StringName, slot_kind: StringName, _new_level: int) -> void:
		if slot_kind == &"SKIP":
			skips[0] += 1
		ask_next.call_deferred()
	EventBus.reward_picked.connect(on_picked)

	requests[0] += 1
	EventBus.reward_offer_requested.emit()
	for i in 20:
		await get_tree().process_frame

	assert_true(tracker.pending_picks == 0, "empty pool drain: pending_picks reaches 0 (%d)" % tracker.pending_picks)
	assert_true(skips[0] == 3, "empty pool drain: three skips are reported (%d)" % skips[0])
	assert_true(requests[0] == 3, "empty pool drain: no request beyond the pending picks (%d)" % requests[0])

	EventBus.reward_picked.disconnect(on_picked)
	tracker.free()
	service.free()

