extends Node

## Automated test runner for:
## - W7-KT1: Wave FSM (PREP-COMBAT-SUMMARY), clear time, par_time, clear_mult, TIME-03 x1 downscale, PRJ-06 projectile cleanup
## - W7-KT2: Early call gold bonus (WAVE-07, GLD-09, early_call_cap = 40, loss cancellation GLD-03)
## - W7-KT3: XpTracker (XP-01..05, BOSS-42, hit_by_commander 100% vs 50%, level curve 5, 14, 27, 44, pending_picks)
## - Commander kill gold bonus (FRT-02, RWD-01, RWD-02, frontline_gold_mult = 1.25)

const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const ARCHER_SCENE: PackedScene = preload("res://entities/enemy/archer.tscn")
const BRUTE_SCENE: PackedScene = preload("res://entities/enemy/brute.tscn")
const XP_TRACKER_SCRIPT := preload("res://systems/xp/xp_tracker.gd")

var passes: int = 0
var fails: int = 0

class MemorySaveRepository extends SaveRepository:
	var stored: Dictionary = {}
	func has_data() -> bool: return not stored.is_empty()
	func load_data() -> Dictionary:
		last_error = OK if has_data() else ERR_FILE_NOT_FOUND
		return stored.duplicate(true)
	func save_data(envelope: Dictionary) -> Error:
		stored = envelope.duplicate(true)
		last_error = OK
		return OK


func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED WAVE REWARDS & XP TRACKER TEST        ")
	print("=======================================================")

	var real_repo := SaveManager.repository
	SaveManager.set_repository(MemorySaveRepository.new())
	SaveManager.load_save()

	test_xp_tracker_level_curve_and_caps()
	test_xp_tracker_damage_sources_and_cull()
	test_commander_kill_gold_multiplier()
	test_early_call_bonus_calculation_and_cap()
	test_clear_time_multiplier_and_tiers()
	test_wave_summary_and_wallet_crediting()
	test_ruined_towers_from_slots()
	test_boss_gold_only_on_boss_defeated()
	test_loss_cancels_wave_gold_and_bonus()
	test_summary_continue_requested_advances_wave()

	SaveManager.set_repository(real_repo)
	SaveManager.load_save()

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
		printerr("  [FAIL] %s" % test_name)


func test_xp_tracker_level_curve_and_caps() -> void:
	print("\n[GROUP 1] Testing XpTracker Level Curve (5, 14, 27, 44)")
	var xp_tracker = XP_TRACKER_SCRIPT.new()
	add_child(xp_tracker)
	xp_tracker.reset()

	assert_true(xp_tracker.commander_level == 0, "Commander starts at level 0 (XP-04)")
	assert_true(xp_tracker.pending_picks == 0, "pending_picks starts at 0")
	assert_true(GameConfig.get_xp_to_level(1) == 5, "Level 1 requires 5 XP")
	assert_true(GameConfig.get_xp_to_level(2) == 9, "Level 2 requires 9 XP")
	assert_true(GameConfig.get_xp_to_level(3) == 13, "Level 3 requires 13 XP")
	assert_true(GameConfig.get_xp_to_level(4) == 17, "Level 4 requires 17 XP")

	var levels_emitted: Array[int] = []
	var on_level_up := func(lv: int, _picks: int): levels_emitted.append(lv)
	EventBus.level_up.connect(on_level_up)

	# Add 4.0 XP -> Still Level 0
	xp_tracker.add_xp(4.0)
	assert_true(xp_tracker.commander_level == 0, "4 XP is not enough for Level 1")
	assert_true(xp_tracker.xp == 4.0, "Current level XP is 4.0")

	# Add 1.0 XP -> Reaches 5.0 XP -> Level 1 (Accumulated 5)
	xp_tracker.add_xp(1.0)
	assert_true(xp_tracker.commander_level == 1, "5 accumulated XP reaches Level 1")
	assert_true(xp_tracker.pending_picks == 1, "pending_picks is 1 after 1 level up")
	assert_true(xp_tracker.xp == 0.0, "XP progress resets to 0 upon exact level up")

	# Add 9.0 XP -> Reaches 14.0 XP -> Level 2 (Accumulated 14)
	xp_tracker.add_xp(9.0)
	assert_true(xp_tracker.commander_level == 2, "14 accumulated XP reaches Level 2")
	assert_true(xp_tracker.pending_picks == 2, "pending_picks is 2 after 2 level ups")

	# Add 13.0 XP -> Reaches 27.0 XP -> Level 3 (Accumulated 27)
	xp_tracker.add_xp(13.0)
	assert_true(xp_tracker.commander_level == 3, "27 accumulated XP reaches Level 3")
	assert_true(xp_tracker.pending_picks == 3, "pending_picks is 3 after 3 level ups")

	# Add 17.0 XP -> Reaches 44.0 XP -> Level 4 (Accumulated 44)
	xp_tracker.add_xp(17.0)
	assert_true(xp_tracker.commander_level == 4, "44 accumulated XP reaches Level 4")
	assert_true(xp_tracker.pending_picks == 4, "pending_picks is 4 after 4 level ups")

	# Test reward_picked decrements pending_picks
	EventBus.reward_picked.emit(&"whirlwind", &"active", 1)
	assert_true(xp_tracker.pending_picks == 3, "reward_picked decrements pending_picks to 3")

	EventBus.level_up.disconnect(on_level_up)
	xp_tracker.free()


func test_xp_tracker_damage_sources_and_cull() -> void:
	print("\n[GROUP 2] Testing XP Multipliers: Commander (100%), Tower-only (50%), Cull (0%)")
	var xp_tracker = XP_TRACKER_SCRIPT.new()
	add_child(xp_tracker)
	xp_tracker.reset()

	# 1. Grunt killed by tower only (base XP 1, 50% = 0.5 XP)
	EventBus.enemy_died.emit(&"grunt", Vector3.ZERO, 4, 1, false, false)
	assert_true(xp_tracker.xp == 0.5, "Tower-only Grunt kill gives 0.5 XP (50%)")
	assert_true(xp_tracker.total_xp_from_towers == 0.5, "total_xp_from_towers recorded 0.5")

	# 2. Grunt killed with hit_by_commander (base XP 1, 100% = 1.0 XP)
	EventBus.enemy_died.emit(&"grunt", Vector3.ZERO, 4, 1, false, true)
	assert_true(xp_tracker.xp == 1.5, "Commander Grunt kill adds 1.0 XP (100%)")
	assert_true(xp_tracker.total_xp_from_commander == 1.0, "total_xp_from_commander recorded 1.0")

	# 3. Archer killed by tower only (base XP 2, 50% = 1.0 XP)
	EventBus.enemy_died.emit(&"archer", Vector3.ZERO, 7, 2, false, false)
	assert_true(xp_tracker.xp == 2.5, "Tower-only Archer kill adds 1.0 XP (50% of 2)")

	# 4. Brute killed with hit_by_commander (base XP 5, 100% = 5.0 XP -> triggers level up from 2.5 + 5 = 7.5 >= 5)
	EventBus.enemy_died.emit(&"brute", Vector3.ZERO, 20, 5, false, true)
	assert_true(xp_tracker.commander_level == 1, "XP from Brute triggers Level 1")
	assert_true(is_equal_approx(xp_tracker.xp, 2.5), "XP remainder carries over to Level 1 (7.5 - 5 = 2.5)")

	# 5. Culled enemy gives 0 XP (RWD-03, XP-01)
	var xp_before: float = float(xp_tracker.xp)
	EventBus.enemy_died.emit(&"brute", Vector3.ZERO, 20, 5, true, false)
	assert_true(xp_tracker.xp == xp_before, "Culled enemy gives 0 XP (is_cull == true)")

	# 6. Boss kill gives 30 XP (BOSS-42)
	EventBus.enemy_died.emit(&"bulwark", Vector3.ZERO, 100, 15, false, true)
	assert_true(xp_tracker.commander_level >= 2, "Boss kill (30 XP) advances Commander Level")

	xp_tracker.free()


func test_commander_kill_gold_multiplier() -> void:
	print("\n[GROUP 3] Testing Commander Kill Gold Multiplier (frontline_gold_mult = 1.25)")
	assert_true(GameConfig.frontline_gold_mult == 1.25, "GameConfig.frontline_gold_mult is 1.25 (FRT-02)")

	var grunt: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt.position = Vector3(0.0, 0.0, 0.0)
	add_child(grunt)

	var deltas: Array[int] = []
	var on_gold_delta := func(d: int): deltas.append(d)
	EventBus.gold_delta.connect(on_gold_delta)

	# 1. Kill without hit_by_commander -> Base gold 4 -> floating delta 4
	grunt.spawn_grace = false
	grunt.hit_by_commander = false
	grunt._on_died()
	assert_true(deltas.size() == 1 and deltas[0] == 4, "Regular enemy death emits gold_delta = 4 (base)")

	grunt.free()

	# 2. Kill with hit_by_commander -> 4 * 1.25 = 5.0 -> floating delta 5
	deltas.clear()
	var grunt_comm: Enemy = GRUNT_SCENE.instantiate() as Enemy
	grunt_comm.position = Vector3(0.0, 0.0, 0.0)
	add_child(grunt_comm)

	grunt_comm.spawn_grace = false
	grunt_comm.hit_by_commander = true
	grunt_comm._on_died()
	assert_true(deltas.size() == 1 and deltas[0] == 5, "Commander hit enemy death emits gold_delta = 5 (4 * 1.25, FRT-02)")

	grunt_comm.free()
	EventBus.gold_delta.disconnect(on_gold_delta)


func test_early_call_bonus_calculation_and_cap() -> void:
	print("\n[GROUP 4] Testing Early Call Gold Bonus & Cap (WAVE-07, GLD-09)")
	var wave_manager := WaveManager.new()
	wave_manager.auto_advance_summary = false
	add_child(wave_manager)

	# In PREP with 25s remaining: bonus = mini(40, floor(25 * 2)) = 40 (capped)
	wave_manager.prep_timer = 25.0
	wave_manager.call_early()
	assert_true(wave_manager.get("_early_call_bonus") == 40, "Early call at 25s hits cap of 40 gold")

	# In PREP with 10.5s remaining: bonus = mini(40, floor(10.5 * 2)) = 21
	wave_manager.start_prep()
	wave_manager.prep_timer = 10.5
	wave_manager.call_early()
	assert_true(wave_manager.get("_early_call_bonus") == 21, "Early call at 10.5s gives 21 gold (10.5 * 2 = 21)")

	wave_manager.free()


func test_clear_time_multiplier_and_tiers() -> void:
	print("\n[GROUP 5] Testing Par Time & Clear Multiplier (Fast 1.25, Normal 1.00, Slow 0.80)")
	var par_time := 30.0 # e.g. 15s spawn + 15s offset
	# Fast: <= 0.7 * 30.0 = 21.0s -> 1.25
	assert_true(GameConfig.get_clear_mult(20.0, par_time) == 1.25, "Clear time 20s (<= 21s) gets Fast 1.25x")
	assert_true(GameConfig.get_clear_mult(21.0, par_time) == 1.25, "Clear time 21s (== 21s) gets Fast 1.25x")

	# Normal: <= 1.3 * 30.0 = 39.0s -> 1.00
	assert_true(GameConfig.get_clear_mult(25.0, par_time) == 1.00, "Clear time 25s (21..39s) gets Normal 1.00x")
	assert_true(GameConfig.get_clear_mult(39.0, par_time) == 1.00, "Clear time 39s (== 39s) gets Normal 1.00x")

	# Slow: > 39.0s -> 0.80
	assert_true(GameConfig.get_clear_mult(40.0, par_time) == 0.80, "Clear time 40s (> 39s) gets Slow 0.80x")


func test_wave_summary_and_wallet_crediting() -> void:
	print("\n[GROUP 6] Testing Wave Summary & Wallet Crediting (GLD-02, GLD-08, SAV-05)")
	var gold_mgr := GoldManager.new()
	add_child(gold_mgr)
	gold_mgr.reset()
	var starting_gold := gold_mgr.gold # 150

	var wave_manager := WaveManager.new()
	wave_manager.auto_advance_summary = false
	add_child(wave_manager)

	var summaries: Array[Dictionary] = []
	var on_summary := func(s: Dictionary): summaries.append(s)
	EventBus.wave_summary_ready.connect(on_summary)

	# 1. Start prep and early call at 10s -> early_bonus = 20
	wave_manager.prep_timer = 10.0
	wave_manager.call_early()
	assert_true(gold_mgr.gold == starting_gold, "Wallet does NOT change upon early call (GLD-02)")

	# 2. Simulate 4 Grunts dying: 2 with hit_by_commander (4 * 1.25 = 5.0), 2 tower-only (4 * 1.0 = 4.0)
	# Total wave_gold_base = 5.0 + 5.0 + 4.0 + 4.0 = 18.0
	EventBus.enemy_died.emit(&"grunt", Vector3.ZERO, 4, 1, false, true)
	EventBus.enemy_died.emit(&"grunt", Vector3.ZERO, 4, 1, false, true)
	EventBus.enemy_died.emit(&"grunt", Vector3.ZERO, 4, 1, false, false)
	EventBus.enemy_died.emit(&"grunt", Vector3.ZERO, 4, 1, false, false)

	assert_true(gold_mgr.gold == starting_gold, "Wallet does NOT change when enemies die in COMBAT (GLD-02)")

	# Set clear time to 15s (Fast tier on Wave 1: par_time is 15 + 15 = 30s -> Fast <= 21s)
	wave_manager.set("_clear_time", 15.0)
	wave_manager.set("spawn_queue", [])
	wave_manager.set("enemies_alive", 0)

	# Transition to SUMMARY
	wave_manager._end_combat_to_summary()

	# Verify wallet crediting:
	# wave_gold_base = 18.0 * 1.25 (Fast) = 22.5 -> floor = 22
	# early_call_bonus = 20
	# Expected gain = 22 + 20 = 42 gold
	var expected_gain := 42
	assert_true(gold_mgr.gold == starting_gold + expected_gain, "Wallet credited exactly 42 gold at SUMMARY (GLD-08)")

	# Verify Summary dictionary
	assert_true(summaries.size() == 1, "EventBus.wave_summary_ready emitted exactly once")
	var s: Dictionary = summaries[0]
	assert_true(s.get("wave_index") == 1, "Summary wave_index is 1")
	assert_true(s.get("clear_tier") == "FAST", "Summary clear_tier is FAST")
	assert_true(s.get("gold_mult") == 1.25, "Summary gold_mult is 1.25")
	assert_true(s.get("early_call_bonus") == 20, "Summary early_call_bonus is 20")
	assert_true(s.get("gold_total") == expected_gain, "Summary gold_total is 42")
	assert_true(s.get("kills_by_type", {}).get("grunt") == 4, "Summary records 4 Grunt kills")

	# Verify TIME-03: Time scale auto resets to x1
	assert_true(TimeManager.get_time_scale() == 1, "TimeManager speed auto drops to x1 on SUMMARY (TIME-03)")

	EventBus.wave_summary_ready.disconnect(on_summary)
	wave_manager.free()
	gold_mgr.free()


func test_ruined_towers_from_slots() -> void:
	print("\n[GROUP 7] Testing Ruined Towers Read from Slots (not Towers)")
	var slot_scene := preload("res://systems/build/slot.tscn")
	var slot: Slot = slot_scene.instantiate()
	slot.slot_id = &"slot_test"
	slot.state = Enums.SlotState.RUINED
	slot.last_data = preload("res://data/towers/arrow.tres")
	slot.last_level = 2
	add_child(slot)

	var wave_manager := WaveManager.new()
	wave_manager.auto_advance_summary = false
	add_child(wave_manager)

	var summaries: Array[Dictionary] = []
	var on_summary := func(s: Dictionary): summaries.append(s)
	EventBus.wave_summary_ready.connect(on_summary)

	wave_manager._end_combat_to_summary()

	assert_true(summaries.size() == 1, "Summary emitted")
	var s: Dictionary = summaries[0]
	var ruined: Array = s.get("ruined_towers", [])
	assert_true(ruined.size() == 1, "ruined_towers contains 1 ruined slot")
	assert_true(ruined[0].get("type") == &"arrow", "Ruined tower type is arrow")
	assert_true(ruined[0].get("level") == 2, "Ruined tower level is 2")
	assert_true(ruined[0].get("rebuild_cost") == slot.get_rebuild_cost(), "Ruined tower rebuild_cost matches slot.get_rebuild_cost()")

	EventBus.wave_summary_ready.disconnect(on_summary)
	wave_manager.free()
	slot.free()


func test_boss_gold_only_on_boss_defeated() -> void:
	print("\n[GROUP 8] Testing Boss Gold Only on Boss Defeated")
	var gold_mgr := GoldManager.new()
	add_child(gold_mgr)
	gold_mgr.reset()
	var starting_gold := gold_mgr.gold

	var wave_manager := WaveManager.new()
	wave_manager.auto_advance_summary = false
	wave_manager.current_wave = 5 # wave 5 is boss wave interval
	add_child(wave_manager)

	# 1. End combat on wave 5 WITHOUT boss_defeated firing -> No boss gold
	wave_manager._end_combat_to_summary()
	assert_true(gold_mgr.gold == starting_gold, "Wave 5 without boss_defeated gives 0 boss gold")
	wave_manager.free()

	# 2. End combat on wave 5 WITH boss_defeated firing -> Grants boss gold
	var wave_manager_boss := WaveManager.new()
	wave_manager_boss.auto_advance_summary = false
	wave_manager_boss.current_wave = 5
	add_child(wave_manager_boss)

	EventBus.boss_defeated.emit()
	wave_manager_boss._end_combat_to_summary()

	var expected_boss_gold := int(floor(float(GameConfig.boss_gold_base) * (1.0 + GameConfig.gold_reward_growth_per_wave * 4.0)))
	assert_true(gold_mgr.gold == starting_gold + expected_boss_gold, "Wave 5 with boss_defeated gives scaled boss gold")

	wave_manager_boss.free()
	gold_mgr.free()


func test_loss_cancels_wave_gold_and_bonus() -> void:
	print("\n[GROUP 9] Testing Loss (WAVE-02, GLD-03): Abandons pending gold & bonus")
	var gold_mgr := GoldManager.new()
	add_child(gold_mgr)
	gold_mgr.reset()
	var starting_gold := gold_mgr.gold

	var wave_manager := WaveManager.new()
	wave_manager.auto_advance_summary = false
	add_child(wave_manager)

	wave_manager.prep_timer = 15.0
	wave_manager.call_early() # 30 bonus

	# Kill enemy
	EventBus.enemy_died.emit(&"grunt", Vector3.ZERO, 4, 1, false, true)

	# Fortress destroyed before summary
	EventBus.fortress_destroyed.emit()

	wave_manager._end_combat_to_summary()

	assert_true(gold_mgr.gold == starting_gold, "No gold gained after Fortress destroyed (WAVE-02, GLD-03)")

	wave_manager.free()
	gold_mgr.free()


func test_summary_continue_requested_advances_wave() -> void:
	print("\n[GROUP 10] Testing Summary Continue Request")
	var wave_manager := WaveManager.new()
	wave_manager.auto_advance_summary = false
	add_child(wave_manager)

	wave_manager.start_combat()
	wave_manager.set("spawn_queue", [])
	wave_manager.set("enemies_alive", 0)
	wave_manager._end_combat_to_summary()

	assert_true(wave_manager.wave_state == Enums.WaveState.SUMMARY, "In SUMMARY state")
	assert_true(wave_manager.current_wave == 1, "Current wave is 1")

	# Player clicks Continue on SummaryPanel
	EventBus.summary_continue_requested.emit()

	assert_true(wave_manager.wave_state == Enums.WaveState.PREP, "summary_continue_requested advances to PREP")
	assert_true(wave_manager.current_wave == 2, "Current wave incremented to 2")

	wave_manager.free()
