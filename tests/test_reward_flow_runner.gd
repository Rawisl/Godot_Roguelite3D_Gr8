extends Node

## Automated test runner for the whole REWARD_PICK loop with real nodes: XP from enemy deaths,
## the wave manager entering and leaving REWARD_PICK, the reward service, the REWARD_PICK screen
## asking for offers one at a time, and the skill runner reacting to picks.

const POOL_PATH := "res://data/config/reward_pool.tres"
const REWARD_PICK_SCREEN: PackedScene = preload("res://ui/screens/reward_pick.tscn")
const GRUNT_ID := &"grunt"
const MAX_FRAMES := 60
const MAX_WAVES := 10
const SEEDS_TO_COMPARE := 20

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []

## One set of real nodes plus a log of what went over EventBus.
class Env extends RefCounted:
	var world: Node
	var run_state: RunState
	var wm: WaveManager
	var service: RewardService
	var skill_runner: SkillRunner
	var tracker: Node
	## The XpTracker the case added on its own before the wave manager, or null.
	var standalone_tracker: Node
	## One letter per event: O reward_offered, P reward_picked, S skill_slots_changed.
	var log := ""
	var offer: Array = []
	var offer_pending := false
	var offered_picks_used: Array[int] = []
	var picked_ids: Array[StringName] = []
	var skips := 0
	var empty_offers := 0
	var states: Array[StringName] = []

	func connect_log() -> void:
		EventBus.reward_offered.connect(_on_offered)
		EventBus.reward_picked.connect(_on_picked)
		EventBus.skill_slots_changed.connect(_on_slots)
		EventBus.state_changed.connect(_on_state)

	func disconnect_log() -> void:
		EventBus.reward_offered.disconnect(_on_offered)
		EventBus.reward_picked.disconnect(_on_picked)
		EventBus.skill_slots_changed.disconnect(_on_slots)
		EventBus.state_changed.disconnect(_on_state)

	func _on_offered(cards: Array, _rerolls_left: int) -> void:
		log += "O"
		offer = cards
		offer_pending = true
		offered_picks_used.append(service.state.picks_used)
		if cards.is_empty():
			empty_offers += 1

	func _on_picked(card_id: StringName, slot_kind: StringName, _new_level: int) -> void:
		log += "P"
		offer_pending = false
		picked_ids.append(card_id)
		if slot_kind == &"SKIP":
			skips += 1

	func _on_slots(_active: Array, _passive: Array, _levels: Dictionary) -> void:
		log += "S"

	func _on_state(new_state: StringName) -> void:
		states.append(new_state)

func _ready() -> void:
	# REWARD_PICK pauses the tree; the runner has to keep going.
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("\n=======================================================")
	print("       AUTOMATED REWARD FLOW RUNNER TEST               ")
	print("=======================================================")

	await test_three_actives_from_real_xp()
	await test_sequential_offers()
	await test_exit_after_last_pick()
	await test_zero_pending_skips()
	await test_seed_from_run_state()
	await test_empty_pool_mid_pick()

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

## Builds the nodes under a fresh world. Options: run_state (bool, default true), seed, wm_seed,
## standalone_tracker, screen (bool, default true), pool.
func _build(opts: Dictionary = {}) -> Env:
	TimeManager.reset()
	var env := Env.new()
	env.world = Node.new()
	add_child(env.world)
	if opts.get("run_state", true):
		env.run_state = RunState.new()
		env.world.add_child(env.run_state)
		env.run_state.init_from_config(RunConfig.create_default(opts.get("seed", 0)))
	if opts.get("standalone_tracker", false):
		var tracker := XpTracker.new()
		env.world.add_child(tracker)
		env.standalone_tracker = tracker
	env.service = RewardService.new()
	env.service.pool = opts.get("pool", load(POOL_PATH))
	env.world.add_child(env.service)
	env.skill_runner = SkillRunner.new()
	env.world.add_child(env.skill_runner)
	env.wm = WaveManager.new()
	env.wm.auto_advance_summary = false
	env.wm.run_seed = opts.get("wm_seed", 0)
	env.world.add_child(env.wm)
	if opts.get("screen", true):
		env.world.add_child(REWARD_PICK_SCREEN.instantiate())
	env.tracker = env.wm.get("_xp_tracker")
	env.connect_log()
	return env

func _teardown(env: Env) -> void:
	env.disconnect_log()
	env.world.free()
	TimeManager.reset()

## Kills commander-hit grunts until the tracker holds at least this many pending picks.
func _earn_picks(env: Env, picks: int) -> void:
	var guard := 0
	while env.tracker.pending_picks < picks and guard < 1000:
		EventBus.enemy_died.emit(GRUNT_ID, Vector3.ZERO, 0, 0, false, true)
		guard += 1

## The combat part of a wave is not under test here, so the case jumps straight to SUMMARY and lets the
## wave manager take it from there.
func _advance_from_summary(env: Env) -> void:
	env.wm.wave_state = Enums.WaveState.SUMMARY
	env.wm.advance_from_summary()

## Answers each offer with the chooser (Callable: Array of cards -> card Dictionary, {} to stop)
## until the wave manager leaves REWARD_PICK. Returns the number of picks sent.
func _drive_picks(env: Env, chooser: Callable) -> int:
	var made := 0
	for frame in MAX_FRAMES:
		while env.offer_pending and env.wm.wave_state == Enums.WaveState.REWARD_PICK:
			var card: Dictionary = chooser.call(env.offer)
			env.offer_pending = false
			if card.is_empty():
				break
			EventBus.reward_pick_requested.emit(card["id"], card["kind"], card["next_level"])
			made += 1
		if env.wm.wave_state != Enums.WaveState.REWARD_PICK:
			break
		await get_tree().process_frame
	return made

## Sends one pick for the open offer and waits a frame for the screen to ask again.
func _drive_one_pick(env: Env) -> void:
	for i in MAX_FRAMES:
		if env.offer_pending:
			break
		await get_tree().process_frame
	var card := _first_card(env.offer)
	env.offer_pending = false
	EventBus.reward_pick_requested.emit(card["id"], card["kind"], card["next_level"])
	await get_tree().process_frame

func _first_card(cards: Array) -> Dictionary:
	return cards[0] if not cards.is_empty() else {}

func _active_or_first(cards: Array) -> Dictionary:
	for card in cards:
		if card["kind"] == &"ACTIVE":
			return card
	return _first_card(cards)

func _ids(cards: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for card in cards:
		out.append(card["id"])
	return out

func test_three_actives_from_real_xp() -> void:
	print("\n[TEST] three actives picked from real XP")
	var env := _build()
	await get_tree().process_frame
	var waves := 0
	var wave_ended_in_prep := true
	while waves < MAX_WAVES and env.service.state.active.count(&"") > 0:
		waves += 1
		_earn_picks(env, 3)
		var earned: int = env.tracker.pending_picks
		assert_true(earned >= 3, "tc_actives: wave %d earned %d picks from enemy deaths" % [waves, earned])
		_advance_from_summary(env)
		assert_true(env.wm.wave_state == Enums.WaveState.REWARD_PICK, "tc_actives: wave %d enters REWARD_PICK" % waves)
		var made := await _drive_picks(env, _active_or_first)
		assert_true(made == earned, "tc_actives: wave %d made %d picks for %d earned" % [waves, made, earned])
		wave_ended_in_prep = wave_ended_in_prep and env.wm.wave_state == Enums.WaveState.PREP
		await get_tree().process_frame

	var active_ids: Array[StringName] = []
	for id in env.service.state.active:
		if id != &"":
			active_ids.append(id)
	assert_true(active_ids.size() == GameConfig.skill_slots_active, "tc_actives: %d active ids in the slots (%s)" % [active_ids.size(), active_ids])
	assert_true(wave_ended_in_prep, "tc_actives: every wave leaves REWARD_PICK for PREP")
	assert_true(env.wm.wave_state == Enums.WaveState.PREP, "tc_actives: final state is PREP")
	assert_true(not TimeManager.has_pause_reason(TimeManager.REASON_REWARD_PICK), "tc_actives: REWARD_PICK pause released")

	var catalog_ids: Array[StringName] = []
	for data in env.skill_runner.catalog:
		catalog_ids.append(data.id)
	for id in active_ids:
		assert_true(catalog_ids.has(id), "tc_actives: picked active '%s' is in the SkillRunner catalog" % id)
	for slot in GameConfig.skill_slots_active:
		assert_true(env.skill_runner.state.active[slot] == env.service.state.active[slot],
			"tc_actives: SkillRunner slot %d holds the same skill as the service (%s)" % [slot, env.skill_runner.state.active[slot]])
	_teardown(env)

func test_sequential_offers() -> void:
	print("\n[TEST] offers are built one at a time")
	var env := _build()
	await get_tree().process_frame
	_earn_picks(env, 3)
	var earned: int = env.tracker.pending_picks
	_advance_from_summary(env)
	var made := await _drive_picks(env, _first_card)
	await get_tree().process_frame

	assert_true(made == earned and made >= 3, "tc_sequential: %d picks made for %d earned" % [made, earned])
	assert_true(env.log == "OPS".repeat(earned), "tc_sequential: log is offer, pick, slots per turn (%s)" % env.log)
	var expected_picks_used: Array[int] = []
	for k in earned:
		expected_picks_used.append(k)
	assert_true(env.offered_picks_used == expected_picks_used, "tc_sequential: offer k+1 arrives after picks_used == k+1 (%s)" % [env.offered_picks_used])
	assert_true(env.service.state.picks_used == earned, "tc_sequential: picks_used ends at %d" % earned)
	_teardown(env)

func test_exit_after_last_pick() -> void:
	print("\n[TEST] REWARD_PICK ends exactly after the last pick")
	for standalone in [false, true]:
		var label := "standalone tracker" if standalone else "wave manager's own tracker"
		var env := _build({"standalone_tracker": standalone})
		await get_tree().process_frame
		var owner_ok: bool = env.tracker == env.standalone_tracker if standalone else env.tracker.get_parent() == env.wm
		assert_true(owner_ok, "tc_exit (%s): wave manager uses the expected tracker" % label)
		_earn_picks(env, 3)
		var earned: int = env.tracker.pending_picks
		_advance_from_summary(env)
		assert_true(env.wm.wave_state == Enums.WaveState.REWARD_PICK, "tc_exit (%s): enters REWARD_PICK" % label)

		var stayed := true
		for k in earned:
			await _drive_one_pick(env)
			var expected := Enums.WaveState.REWARD_PICK if k < earned - 1 else Enums.WaveState.PREP
			stayed = stayed and env.wm.wave_state == expected
			assert_true(env.tracker.pending_picks == earned - k - 1, "tc_exit (%s): pending is %d after pick %d" % [label, earned - k - 1, k + 1])
		assert_true(stayed, "tc_exit (%s): still in REWARD_PICK before the last pick, PREP right after it" % label)
		assert_true(not TimeManager.has_pause_reason(TimeManager.REASON_REWARD_PICK), "tc_exit (%s): pause released" % label)
		var offers_before := env.log.count("O")
		for i in 5:
			await get_tree().process_frame
		assert_true(env.log.count("O") == offers_before, "tc_exit (%s): no offer after the last pick" % label)
		_teardown(env)

func test_zero_pending_skips() -> void:
	print("\n[TEST] no pending picks skips REWARD_PICK")
	var env := _build()
	await get_tree().process_frame
	var wave_before: int = env.wm.current_wave
	assert_true(env.tracker.pending_picks == 0, "tc_zero: no pending picks to start with")
	_advance_from_summary(env)
	assert_true(env.wm.wave_state == Enums.WaveState.PREP, "tc_zero: goes straight to PREP")
	assert_true(not env.states.has(&"REWARD_PICK"), "tc_zero: REWARD_PICK never announced")
	assert_true(env.wm.current_wave == wave_before + 1, "tc_zero: next wave reached")
	assert_true(not TimeManager.has_pause_reason(TimeManager.REASON_REWARD_PICK), "tc_zero: no REWARD_PICK pause")
	assert_true(env.log == "", "tc_zero: no offer asked")
	_teardown(env)

func _first_offer_ids(env: Env) -> Array[StringName]:
	return _ids(env.service.offer_next())

## The offer the generator makes for a seed on a fresh run state.
func _expected_ids(env: Env, run_seed: int) -> Array[StringName]:
	var rng := RewardOfferGenerator.make_rng(run_seed, 0)
	var cards := RewardOfferGenerator.generate(RunSkillState.new(), env.service.get_catalog(), rng, env.service.pool.cards_per_pick)
	return _ids(cards)

func test_seed_from_run_state() -> void:
	print("\n[TEST] offer seed comes from RunState")
	var first := _build({"seed": 12345, "wm_seed": 999, "screen": false})
	var first_ids := _first_offer_ids(first)
	assert_true(not first_ids.is_empty(), "tc_seed: the first offer has cards")
	assert_true(first_ids == _expected_ids(first, 12345), "tc_seed: RunState seed wins over the wave manager seed")
	_teardown(first)

	var again := _build({"seed": 12345, "wm_seed": 1, "screen": false})
	assert_true(_first_offer_ids(again) == first_ids, "tc_seed: same RunState seed gives the same first offer")
	_teardown(again)

	var distinct := {}
	for run_seed in range(1, SEEDS_TO_COMPARE + 1):
		var env := _build({"seed": run_seed, "screen": false})
		distinct[_first_offer_ids(env)] = true
		_teardown(env)
	assert_true(distinct.size() > 1, "tc_seed: %d seeds give %d different first offers" % [SEEDS_TO_COMPARE, distinct.size()])

	var no_run_state := _build({"run_state": false, "wm_seed": 777, "screen": false})
	assert_true(_first_offer_ids(no_run_state) == _expected_ids(no_run_state, 777), "tc_seed: without RunState the wave manager seed is used")
	_teardown(no_run_state)

	var neither := _build({"run_state": false, "screen": false})
	neither.wm.remove_from_group(&"wave_manager")
	assert_true(_first_offer_ids(neither) == _expected_ids(neither, 0), "tc_seed: without both the seed is 0")
	_teardown(neither)
	await get_tree().process_frame

func test_empty_pool_mid_pick() -> void:
	print("\n[TEST] pool runs out while picks remain")
	var only := SkillData.new()
	only.id = &"flow_test_active"
	only.kind = SkillData.Kind.ACTIVE
	only.max_level_override = 1
	var tiny := RewardPool.new()
	tiny.skills = [only]
	var env := _build({"pool": tiny})
	await get_tree().process_frame
	_earn_picks(env, 3)
	var earned: int = env.tracker.pending_picks
	_advance_from_summary(env)
	assert_true(env.wm.wave_state == Enums.WaveState.REWARD_PICK, "tc_empty: enters REWARD_PICK while one card is left")
	var made := await _drive_picks(env, _first_card)
	for i in 3:
		await get_tree().process_frame

	assert_true(made == 1, "tc_empty: one real pick made (%d)" % made)
	assert_true(env.wm.wave_state == Enums.WaveState.PREP, "tc_empty: REWARD_PICK still exits")
	assert_true(env.tracker.pending_picks == 0, "tc_empty: pending picks drained")
	assert_true(env.skips == earned - 1, "tc_empty: remaining %d turns auto-skipped (%d)" % [earned - 1, env.skips])
	assert_true(env.empty_offers == earned - 1, "tc_empty: screen told about each empty offer (%d)" % env.empty_offers)
	assert_true(env.service.state.picks_used == earned, "tc_empty: every turn counted")
	assert_true(not TimeManager.has_pause_reason(TimeManager.REASON_REWARD_PICK), "tc_empty: pause released")
	_teardown(env)
