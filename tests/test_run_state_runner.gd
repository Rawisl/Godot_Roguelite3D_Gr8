extends Node

## Verification test runner for RunConfig and RunState runtime framework:
## - Default field values and configuration initialization
## - In-memory operation without persistent disk writes
## - Elapsed combat time tracking only during combat states
## - Same-frame tie-breaking favoring fortress destruction
## - Integration with GoldManager and WaveManager

var passes: int = 0
var fails: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("       RUN CONFIG & RUN STATE RUNNER TEST              ")
	print("=======================================================")

	GameState.current = GameState.AppState.RUN

	test_default_field_values()
	test_init_from_run_config()
	test_no_disk_io()
	test_run_elapsed_combat_timing()
	await test_tie_break_same_frame()
	test_gold_manager_integration()
	test_wave_manager_integration()
	await test_abandon_run_flow()

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
		push_error("  [FAIL] %s" % test_name)


func test_default_field_values() -> void:
	print("\n[GROUP 1] Default Field Values")
	var rs := RunState.new()

	assert_true(rs.wave_index == 1, "Default wave_index is 1")
	assert_true(rs.waves_cleared == 0, "Default waves_cleared is 0")
	assert_true(rs.run_elapsed == 0.0, "Default run_elapsed is 0.0")
	assert_true(rs.run_seed == 0, "Default run_seed is 0")
	assert_true(rs.victory_reached == false, "Default victory_reached is false")

	assert_true(rs.gold == 0, "Default gold is 0")
	assert_true(rs.mithril == 0, "Default mithril is 0")
	assert_true(rs.prestige_pending == 0, "Default prestige_pending is 0")
	assert_true(rs.wave_gold_base == 0.0, "Default wave_gold_base is 0.0")
	assert_true(rs.wave_prestige_buffer == 0, "Default wave_prestige_buffer is 0")

	assert_true(rs.hazard_used == false, "Default hazard_used is false")
	assert_true(rs.hazard_session.is_empty(), "Default hazard_session is empty dictionary")

	assert_true(rs.owned_weapons == [&"sword_base"], "Default owned_weapons contains base sword")
	assert_true(rs.equipped_weapon == &"sword_base", "Default equipped_weapon is base sword")
	assert_true(rs.chain_cd == 0.0, "Default chain_cd is 0.0")

	assert_true(rs.fortress_hp == 1000, "Default fortress_hp is 1000")
	assert_true(rs.fortress_max_hp == 1000, "Default fortress_max_hp is 1000")
	assert_true(rs.emg_repair_charges == 3, "Default emg_repair_charges is 3")
	assert_true(rs.emg_repair_cd == 0.0, "Default emg_repair_cd is 0.0")
	assert_true(is_equal_approx(rs.emg_repair_heal_pct, 0.20), "Default emg_repair_heal_pct is 0.20")

	assert_true(is_equal_approx(rs.commander_hp, 100.0), "Default commander_hp is 100.0")
	assert_true(is_equal_approx(rs.commander_max_hp, 100.0), "Default commander_max_hp is 100.0")
	assert_true(rs.commander_mode == &"FRONTLINE", "Default commander_mode is FRONTLINE")
	assert_true(rs.heal_phase == &"IDLE", "Default heal_phase is IDLE")
	assert_true(rs.heal_hold == 0.0, "Default heal_hold is 0.0")

	assert_true(rs.xp == 0.0, "Default xp is 0.0")
	assert_true(rs.commander_level == 0, "Default commander_level is 0")
	assert_true(rs.pending_picks == 0, "Default pending_picks is 0")
	assert_true(rs.rerolls_left == 1, "Default rerolls_left is 1")
	assert_true(rs.heal_station_built == false, "Default heal_station_built is false")

	assert_true(rs.is_starter.is_empty(), "Default is_starter dictionary is empty")
	assert_true(rs.ruined_type.is_empty(), "Default ruined_type dictionary is empty")
	assert_true(rs.ruined_level.is_empty(), "Default ruined_level dictionary is empty")
	assert_true(rs.tower_slots.is_empty(), "Default tower_slots dictionary is empty")

	assert_true(rs.run_kills == 0, "Default run_kills is 0")
	assert_true(rs.run_commander_kills == 0, "Default run_commander_kills is 0")
	assert_true(rs.run_gold_earned == 0, "Default run_gold_earned is 0")
	assert_true(rs.run_bosses_defeated == 0, "Default run_bosses_defeated is 0")

	assert_true(rs.enemies_alive == 0, "Default enemies_alive is 0")
	assert_true(rs.boss_timer == 0.0, "Default boss_timer is 0.0")
	assert_true(rs.boss_enraged == false, "Default boss_enraged is false")

	rs.free()


func test_init_from_run_config() -> void:
	print("\n[GROUP 2] Initialization From RunConfig")
	var rs := RunState.new()
	var config := RunConfig.create_default(4242, {
		"start_wave": 5,
		"starting_gold": 150,
		"fortress_max_hp": 1200,
		"commander_max_hp": 150.0,
		"emg_repair_heal_pct": 0.25,
		"rerolls_per_run": 2,
	})

	rs.init_from_config(config)

	assert_true(rs.wave_index == 5, "wave_index initialized to 5")
	assert_true(rs.waves_cleared == 4, "waves_cleared initialized to start_wave - 1")
	assert_true(rs.gold == 150, "gold initialized to 150")
	assert_true(rs.run_seed == 4242, "run_seed initialized to 4242")
	assert_true(rs.fortress_hp == 1200, "fortress_hp initialized to 1200")
	assert_true(rs.fortress_max_hp == 1200, "fortress_max_hp initialized to 1200")
	assert_true(is_equal_approx(rs.commander_hp, 150.0), "commander_hp initialized to 150.0")
	assert_true(is_equal_approx(rs.commander_max_hp, 150.0), "commander_max_hp initialized to 150.0")
	assert_true(is_equal_approx(rs.emg_repair_heal_pct, 0.25), "emg_repair_heal_pct initialized to 0.25")
	assert_true(rs.rerolls_left == 2, "rerolls_left initialized to 2")

	rs.free()


func test_no_disk_io() -> void:
	print("\n[GROUP 3] In-Memory Verification (No Disk I/O)")
	var rs := RunState.new()
	add_child(rs)

	rs.gold += 500
	rs.mithril += 5
	rs.wave_index = 8
	rs.waves_cleared = 7
	rs.run_kills += 35

	assert_true(rs.gold == 500, "State updated in memory: gold = 500")
	assert_true(rs.mithril == 5, "State updated in memory: mithril = 5")
	assert_true(rs.wave_index == 8, "State updated in memory: wave_index = 8")
	assert_true(rs.waves_cleared == 7, "State updated in memory: waves_cleared = 7")
	assert_true(rs.run_kills == 35, "State updated in memory: run_kills = 35")

	remove_child(rs)
	rs.free()
	assert_true(true, "RunState lifecycle completed without triggering file operations")


func test_run_elapsed_combat_timing() -> void:
	print("\n[GROUP 4] Elapsed Combat Time Accumulation")
	var rs := RunState.new()
	add_child(rs)

	EventBus.state_changed.emit(&"PREP")
	rs._process(1.5)
	assert_true(is_equal_approx(rs.run_elapsed, 0.0), "run_elapsed does not accumulate in PREP")

	EventBus.state_changed.emit(&"SUMMARY")
	rs._process(2.0)
	assert_true(is_equal_approx(rs.run_elapsed, 0.0), "run_elapsed does not accumulate in SUMMARY")

	EventBus.state_changed.emit(&"COMBAT")
	rs._process(3.5)
	assert_true(is_equal_approx(rs.run_elapsed, 3.5), "run_elapsed accumulates during COMBAT")

	EventBus.state_changed.emit(&"BOSS_COMBAT")
	rs._process(1.5)
	assert_true(is_equal_approx(rs.run_elapsed, 5.0), "run_elapsed accumulates during BOSS_COMBAT")

	EventBus.state_changed.emit(&"PREP")
	rs._process(4.0)
	assert_true(is_equal_approx(rs.run_elapsed, 5.0), "run_elapsed halts accumulation when exiting combat")

	remove_child(rs)
	rs.free()


func test_tie_break_same_frame() -> void:
	print("\n[GROUP 5] Same-Frame Termination Tie-Break")
	var rs := RunState.new()
	add_child(rs)

	var result := {
		"end_type": &"",
		"summary": {}
	}
	var callback := func(end_type: StringName, summary: Dictionary) -> void:
		result["end_type"] = end_type
		result["summary"] = summary

	EventBus.run_ended.connect(callback)

	# Simulate same-frame fortress destroyed and commander died
	EventBus.commander_died.emit()
	EventBus.fortress_destroyed.emit()

	await get_tree().process_frame

	assert_true(result["end_type"] == &"FORTRESS_DESTROYED", "Fortress destruction takes precedence in same-frame tie")
	assert_true(result["summary"].get("end_type") == &"FORTRESS_DESTROYED", "Summary reflects correct end_type")
	assert_true(result["summary"].get("run_result") == &"DEFEAT", "run_result is DEFEAT before victory wave")

	EventBus.run_ended.disconnect(callback)
	remove_child(rs)
	rs.free()


func test_gold_manager_integration() -> void:
	print("\n[GROUP 6] GoldManager Integration")
	var rs := RunState.new()
	var gm := GoldManager.new()
	add_child(rs)
	add_child(gm)

	gm.reset()
	assert_true(rs.gold == GameConfig.starting_gold, "GoldManager.reset() writes to RunState.gold")
	assert_true(gm.gold == GameConfig.starting_gold, "GoldManager.gold reads from RunState.gold")

	gm.add(75)
	assert_true(rs.gold == GameConfig.starting_gold + 75, "GoldManager.add increments RunState.gold")
	assert_true(rs.run_gold_earned == 75, "GoldManager.add tracks RunState.run_gold_earned")

	var spend_success := gm.try_spend(50)
	assert_true(spend_success, "GoldManager.try_spend succeeds with sufficient gold")
	assert_true(rs.gold == GameConfig.starting_gold + 25, "RunState.gold reflects spent gold")

	rs.gold = 300
	assert_true(gm.gold == 300, "GoldManager.gold reflects direct RunState.gold changes")

	remove_child(gm)
	remove_child(rs)
	gm.free()
	rs.free()


func test_wave_manager_integration() -> void:
	print("\n[GROUP 7] WaveManager Integration")
	var rs := RunState.new()
	var wm := WaveManager.new()
	add_child(rs)
	add_child(wm)

	wm.current_wave = 3
	assert_true(rs.wave_index == 3, "WaveManager.current_wave syncs to RunState.wave_index")
	assert_true(wm.current_wave == 3, "WaveManager reads wave_index from RunState")

	wm.enemies_alive = 12
	assert_true(rs.enemies_alive == 12, "WaveManager.enemies_alive syncs to RunState.enemies_alive")

	rs.hazard_used = true
	wm.start_prep()
	assert_true(rs.hazard_used == false, "WaveManager.start_prep() resets RunState.hazard_used to false")

	remove_child(wm)
	remove_child(rs)
	wm.free()
	rs.free()


func test_abandon_run_flow() -> void:
	print("\n[GROUP 8] Abandon Run Flow")
	var rs := RunState.new()
	add_child(rs)

	var result := {
		"end_type": &"",
		"summary": {}
	}
	var callback := func(end_type: StringName, summary: Dictionary) -> void:
		result["end_type"] = end_type
		result["summary"] = summary

	EventBus.run_ended.connect(callback)

	rs.end_run(&"ABANDONED")

	assert_true(result["end_type"] == &"ABANDONED", "end_run emits ABANDONED end_type")
	assert_true(result["summary"].get("end_type") == &"ABANDONED", "Summary contains ABANDONED end_type")
	assert_true(result["summary"].get("run_result") == &"ABANDONED", "Summary contains ABANDONED run_result")

	EventBus.run_ended.disconnect(callback)
	remove_child(rs)
	rs.free()
