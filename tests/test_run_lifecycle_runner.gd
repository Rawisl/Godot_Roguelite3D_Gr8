extends Node
## Runner for the start and the end of a run:
## - the loading screen builds the run config from the meta shop levels and a new seed,
##   and hands it to the RunState of the run scene once
## - RunState resets the run, puts the meta upgrades on the Fortress, the commander and
##   Emergency repair, and places the starter towers only when it should
## - the wave manager follows the run seed and the meta gold bonus of RunState
## - the run result is DEFEAT or SURVIVED whatever the end type, the run ends once, and the
##   summary carries the new record and recovered flags
## The save runs on an in-memory repository, so the player's save is never touched.

const COMMANDER_STATS: CharacterStats = preload("res://data/config/commander_stats.tres")

var passes: int = 0
var fails: int = 0
var _real_repo: SaveRepository
var _ended: Array = []


class MemorySaveRepository extends SaveRepository:
	var stored: Dictionary = {}

	func has_data() -> bool:
		return not stored.is_empty()

	func load_data() -> Dictionary:
		last_error = OK if has_data() else ERR_FILE_NOT_FOUND
		return stored.duplicate(true)

	func save_data(envelope: Dictionary) -> Error:
		stored = envelope.duplicate(true)
		return OK


## Stands in for the commander: the same fields RunState reads, without the scene.
class StubCommander extends Node3D:
	var stat_block := StatBlock.new(COMMANDER_STATS)
	var health := HealthComponent.new()

	func _init() -> void:
		health.name = "Health"
		add_child(health)
		var repair := EmergencyRepair.new()
		repair.name = "EmergencyRepair"
		add_child(repair)
		add_to_group(&"commander")


class StubFortress extends Node3D:
	var health := HealthComponent.new()

	func _init() -> void:
		health.max_hp = 1000
		add_child(health)
		add_to_group(&"fortress")


class StubBuildService extends Node:
	var calls := 0

	func _init() -> void:
		add_to_group(&"build_service")

	func place_starter_towers() -> bool:
		calls += 1
		return true


func _ready() -> void:
	print("\n=======================================================")
	print("              RUN LIFECYCLE RUNNER TEST                ")
	print("=======================================================")
	# RUN_END cannot follow RUN_END, so a run end here never changes the screen.
	GameState.current = GameState.AppState.RUN_END
	_real_repo = SaveManager.repository
	SaveManager.set_repository(MemorySaveRepository.new())
	SaveManager.load_save()
	SaveManager.can_write = true
	EventBus.run_ended.connect(_on_run_ended)

	test_build_config_from_meta()
	test_hand_over_once()
	test_init_resets_the_run()
	await test_apply_to_scene()
	test_starter_towers()
	test_wave_manager_follows_run_state()
	test_run_result()
	test_new_record()
	test_abandon_through_game_state()

	EventBus.run_ended.disconnect(_on_run_ended)
	SaveManager.set_repository(_real_repo)
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
		print("  [FAIL] %s" % test_name)


func _on_run_ended(end_type: StringName, summary: Dictionary) -> void:
	_ended.append({"end_type": end_type, "summary": summary})


func test_build_config_from_meta() -> void:
	print("\n[GROUP 1] Run config from the meta shop")
	var levels := {"FORT_HP": 2, "GOLD_PCT": 1, "CMD_HP": 3, "EMG_REPAIR": 1}
	var mods := MetaUpgrades.get_run_modifiers(levels)
	var config := RunLoader.build_config(levels)
	assert_true(config.start_wave == 1 and config.starting_gold == 0 and is_equal_approx(config.start_mult, 1.0),
			"A new run starts at wave 1 with 0 gold and start_mult 1")
	assert_true(config.run_seed != 0, "A new run gets a seed that is not 0")
	assert_true(config.fortress_max_hp == int(mods["fortress_max_hp"]), "Fortress HP includes the meta upgrade")
	assert_true(is_equal_approx(config.commander_max_hp, float(mods["commander_max_hp"])), "Commander HP includes the meta upgrade")
	assert_true(is_equal_approx(config.emg_repair_heal_pct, float(mods["emg_repair_heal_pct"])), "Repair heal includes the meta upgrade")
	assert_true(is_equal_approx(config.gold_pct_meta, float(mods["gold_pct_meta"])) and config.gold_pct_meta > 0.0,
			"Gold bonus comes from the meta upgrade")
	assert_true(config.fortress_max_hp > RunLoader.build_config({}).fortress_max_hp, "Meta levels raise the Fortress HP above level 0")
	assert_true(RunLoader.build_config({}, 77).run_seed == 77, "A given seed is kept")


func test_hand_over_once() -> void:
	print("\n[GROUP 2] Hand-over to the run scene")
	var config := RunLoader.build_config({}, 1234)
	RunLoader.hand_over(config)
	assert_true(RunLoader.has_pending(), "The config waits for the run scene")
	assert_true(RunLoader.take() == config, "The run scene takes the config built by the loading screen")
	assert_true(not RunLoader.has_pending(), "The config is taken only once")
	var fallback := RunLoader.take()
	assert_true(fallback != null and fallback != config and fallback.run_seed != 0,
			"Opening the run scene directly builds a fresh config from the save")


func test_init_resets_the_run() -> void:
	print("\n[GROUP 3] RunState starts clean")
	var rs := RunState.new()
	rs.xp = 40.0
	rs.commander_level = 4
	rs.pending_picks = 2
	rs.stat_stacks = {&"hp": 2}
	rs.mithril = 3
	rs.hazard_used = true
	rs.victory_reached = true
	rs.emg_repair_charges = 1
	rs.emg_repair_cd = 12.0
	rs.heal_station_built = true
	rs.chain_cd = 3.0
	var config := RunLoader.build_config({"GOLD_PCT": 2}, 99)
	rs.init_from_config(config)
	assert_true(rs.xp == 0.0 and rs.commander_level == 0 and rs.pending_picks == 0 and rs.stat_stacks.is_empty(),
			"Skill and XP start empty")
	assert_true(rs.mithril == 0 and not rs.hazard_used and not rs.victory_reached, "Mithril, Hazard Trial and victory reset")
	assert_true(rs.emg_repair_charges == GameConfig.emg_repair_charges_start and rs.emg_repair_cd == 0.0,
			"Emergency repair starts full with no cooldown")
	assert_true(not rs.heal_station_built and rs.chain_cd == 0.0, "Heal station and weapon cooldown reset")
	assert_true(rs.run_seed == 99 and rs.gold == 0 and rs.wave_index == 1, "Seed, gold and wave come from the config")
	assert_true(is_equal_approx(rs.gold_pct_meta, config.gold_pct_meta), "Gold bonus comes from the config")
	rs.free()


func test_apply_to_scene() -> void:
	print("\n[GROUP 4] Meta upgrades on the Fortress, the commander and Emergency repair")
	var fortress := StubFortress.new()
	var commander := StubCommander.new()
	add_child(fortress)
	add_child(commander)
	var rs := RunState.new()
	add_child(rs)
	await get_tree().process_frame
	rs.init_from_config(RunConfig.create_default(5, {
		"fortress_max_hp": 1100, "commander_max_hp": 130.0, "emg_repair_heal_pct": 0.26,
	}))
	var fortress_hp := []
	var on_fortress_hp := func(hp: int, max_hp: int, _delta: int) -> void: fortress_hp.append([hp, max_hp])
	EventBus.fortress_hp_changed.connect(on_fortress_hp)
	commander.health.take_damage(30)
	rs.apply_to_scene()
	EventBus.fortress_hp_changed.disconnect(on_fortress_hp)
	assert_true(fortress.health.max_hp == 1100 and fortress.health.hp == 1100, "Fortress gets the run's max HP, full")
	assert_true(commander.health.max_hp == 130 and commander.health.hp == 130, "Commander gets the run's max HP, full")
	assert_true(commander.stat_block.get_max_hp() == 130, "The commander's stat block carries the meta HP for later stat cards")
	var repair := commander.get_node("EmergencyRepair") as EmergencyRepair
	assert_true(is_equal_approx(repair.get_heal_pct(), 0.26), "Emergency repair heals the run's percent")
	rs.apply_to_scene()
	assert_true(commander.stat_block.get_max_hp() == 130, "Applying twice does not add the meta HP twice")
	for node in [rs, commander, fortress]:
		remove_child(node)
		node.free()


func test_starter_towers() -> void:
	print("\n[GROUP 5] Starter towers")
	var build := StubBuildService.new()
	add_child(build)
	var rs := RunState.new()
	add_child(rs)
	var flags := SaveManager.get_section(&"flags")
	flags["tutorial_done"] = false
	assert_true(not rs.place_starter_towers() and build.calls == 0, "No starter towers while the tutorial is not done")
	flags["tutorial_done"] = true
	assert_true(rs.place_starter_towers() and build.calls == 1, "Starter towers once the tutorial is done")
	rs.start_wave = 11
	assert_true(not rs.place_starter_towers() and build.calls == 1, "No starter towers for a later start wave")
	flags["tutorial_done"] = false
	for node in [rs, build]:
		remove_child(node)
		node.free()


func test_wave_manager_follows_run_state() -> void:
	print("\n[GROUP 6] Wave manager reads the run")
	var rs := RunState.new()
	add_child(rs)
	rs.init_from_config(RunLoader.build_config({"GOLD_PCT": 3}, 4321))
	var wm := WaveManager.new()
	add_child(wm)
	assert_true(wm.run_seed == 4321, "Waves use the seed of the run")
	assert_true(is_equal_approx(wm._gold_pct_total(), rs.gold_pct_meta) and rs.gold_pct_meta > 0.0,
			"Wave and boss gold get the meta gold bonus")
	for node in [wm, rs]:
		remove_child(node)
		node.free()


func test_run_result() -> void:
	print("\n[GROUP 7] Run result and a single end")
	var cases := [
		[&"ABANDONED", false, &"DEFEAT"],
		[&"FORTRESS_DESTROYED", false, &"DEFEAT"],
		[&"ABANDONED", true, &"SURVIVED"],
		[&"COMMANDER_DIED", true, &"SURVIVED"],
	]
	for c in cases:
		var rs := RunState.new()
		add_child(rs)
		rs.victory_reached = c[1]
		_ended.clear()
		rs.end_run(c[0])
		rs.end_run(&"FORTRESS_DESTROYED")
		var summary: Dictionary = _ended[0]["summary"] if _ended.size() == 1 else {}
		assert_true(_ended.size() == 1, "%s ends the run once" % c[0])
		assert_true(summary.get("end_type") == c[0] and summary.get("run_result") == c[2],
				"%s with victory %s gives %s" % [c[0], c[1], c[2]])
		assert_true(summary.has_all(["commander_level", "run_commander_kills", "run_elapsed", "run_seed", "recovered"])
				and summary["recovered"] == false, "The summary carries the leaderboard fields")
		remove_child(rs)
		rs.free()


func test_new_record() -> void:
	print("\n[GROUP 8] New record against the best for the start wave")
	var profile := SaveManager.get_section(&"profile")
	profile["best_by_start"] = {"1": 6, "11": 20}
	var rs := RunState.new()
	rs.waves_cleared = 6
	assert_true(not rs.is_new_record(), "Equal to the best is not a record")
	rs.waves_cleared = 7
	assert_true(rs.is_new_record(), "More waves than the best is a record")
	rs.start_wave = 11
	rs.waves_cleared = 15
	assert_true(not rs.is_new_record(), "The best of the run's own start wave counts")
	rs.start_wave = 21
	rs.waves_cleared = 21
	assert_true(rs.is_new_record(), "A start wave never played before is a record")
	assert_true(rs.build_summary(&"ABANDONED", &"DEFEAT").get("new_record") == true, "The summary carries new_record")
	rs.free()
	profile["best_by_start"] = {}


func test_abandon_through_game_state() -> void:
	print("\n[GROUP 9] Abandon from the pause menu")
	var rs := RunState.new()
	add_child(rs)
	rs.waves_cleared = 3
	_ended.clear()
	GameState.abandon_run()
	assert_true(_ended.size() == 1 and _ended[0]["end_type"] == &"ABANDONED", "Abandon ends the run through RunState")
	assert_true(rs.is_run_ended(), "RunState knows the run is over")
	GameState.abandon_run()
	assert_true(_ended.size() == 1, "A second abandon does nothing")
	var snapshot := GameState.run_snapshot()
	assert_true(snapshot.get("run_result") == &"DEFEAT", "The pause snapshot uses the same run result")
	remove_child(rs)
	rs.free()
