extends Node

## Automated test runner for the save hooks:
## - the wave SUMMARY is written before the summary shows, and absorbs a save held back in combat
## - clearing a wave pays prestige and moves the wave's pending part into the run total
## - the run end adds the run to the profile once, also during combat
## - the run flag at run start, and the tutorial flag

var passes: int = 0
var fails: int = 0

var _repo: MemorySaveRepository
var _saves: int = 0
var _failures: int = 0
var _balances: Array[int] = []
var _tutorial_signals: int = 0
var _pending: Array[int] = []
var _summary_saves: int = -1
var _summary_run_flag: Dictionary = {}
var _summaries: Array[Dictionary] = []


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
	print("              AUTOMATED SAVE HOOKS TEST                ")
	print("=======================================================")

	var real_repo := SaveManager.repository
	EventBus.save_completed.connect(_on_save_completed)
	EventBus.save_failed.connect(_on_save_failed)
	EventBus.prestige_balance_changed.connect(_on_balance_changed)
	EventBus.tutorial_completed.connect(_on_tutorial_completed)
	EventBus.prestige_pending_changed.connect(_on_pending_changed)
	EventBus.wave_summary_ready.connect(_on_summary_ready)

	test_summary_saved_before_summary_shows()
	test_held_save_joins_summary_write()
	test_wave_clear_prestige_added()
	test_wave_clear_prestige_formula()
	test_prestige_gain_formula()
	test_wave1_buffer_only()
	test_run_end_updates_profile()
	test_run_end_in_combat_writes_now()
	test_run_end_recorded_once()
	test_best_by_start_keeps_max()
	test_run_only_stats_not_saved()
	test_empty_summary_not_recorded()
	test_run_start_flag()
	test_summary_blocked_save_silent()
	test_tutorial_done_saved()
	test_tutorial_done_in_combat_deferred()
	test_run_state_summary_keys()

	EventBus.save_completed.disconnect(_on_save_completed)
	EventBus.save_failed.disconnect(_on_save_failed)
	EventBus.prestige_balance_changed.disconnect(_on_balance_changed)
	EventBus.tutorial_completed.disconnect(_on_tutorial_completed)
	EventBus.prestige_pending_changed.disconnect(_on_pending_changed)
	EventBus.wave_summary_ready.disconnect(_on_summary_ready)
	EventBus.state_changed.emit(&"PREP")
	SaveManager.can_write = true
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


func _on_save_completed() -> void:
	_saves += 1


func _on_save_failed(_reason: StringName) -> void:
	_failures += 1


func _on_balance_changed(value: int) -> void:
	_balances.append(value)


func _on_tutorial_completed() -> void:
	_tutorial_signals += 1


func _on_pending_changed(value: int) -> void:
	_pending.append(value)


## Records what is already on disk at the moment the summary is announced.
func _on_summary_ready(summary: Dictionary) -> void:
	_summaries.append(summary)
	_summary_saves = _saves
	_summary_run_flag = _disk(&"run_flag").duplicate(true)


## Fresh in-memory save, nothing held back, and the "new run" marker cleared.
func _begin() -> void:
	EventBus.state_changed.emit(&"PREP")
	_repo = MemorySaveRepository.new()
	SaveManager.set_repository(_repo)
	SaveManager.load_save()
	SaveManager.can_write = true
	_start_new_run_marker()
	_saves = 0
	_failures = 0
	_balances.clear()
	_tutorial_signals = 0
	_pending.clear()
	_summaries.clear()
	_summary_saves = -1
	_summary_run_flag = {}


## Same signal the game sends when a run begins; lets the next run_ended count again.
func _start_new_run_marker() -> void:
	GameState.app_state_changed.emit(GameState.AppState.RUN, GameState.AppState.RUN_LOADING)


func _disk(section: StringName) -> Dictionary:
	var stored_data: Dictionary = _repo.stored.get("data", {})
	return stored_data.get(String(section), {})


func _disk_stat(key: String) -> int:
	var profile := _disk(&"profile")
	var stats: Dictionary = profile.get("stats", {})
	return int(stats.get(key, 0))


func _new_run_state() -> RunState:
	var rs := RunState.new()
	add_child(rs)
	return rs


## A wave manager standing in the wave `wave`, in PREP, that stays in SUMMARY once it gets there.
func _new_wave_manager(wave: int) -> WaveManager:
	var wm := WaveManager.new()
	wm.auto_advance_summary = false
	add_child(wm)
	# Set after add_child so the wave is written to the RunState when there is one.
	wm.current_wave = wave
	return wm


## Puts the manager in combat with one unit left, then kills it so the wave ends.
func _clear_wave(wm: WaveManager, prestige: int) -> void:
	EventBus.state_changed.emit(&"COMBAT")
	wm.wave_state = Enums.WaveState.COMBAT
	wm.spawn_queue.clear()
	wm.enemies_alive = 1
	EventBus.enemy_died.emit(&"grunt", Vector3.ZERO, 1.0, prestige, false, false)


func _expected_gain(pending: int, buffer: int, start_mult: float) -> int:
	var raw: float = (float(pending) + GameConfig.prestige_buffer_ratio * float(buffer)) * GameConfig.conversion_rate * start_mult
	return WaveRewardTable.floor_gold(raw)


func _set_profile(balance: int, runs: int, kills: int, bosses: int, max_wave: int, best: Dictionary) -> void:
	var profile := SaveManager.get_section(SaveManager.PROFILE)
	profile["prestige_balance"] = balance
	profile["max_wave_cleared"] = max_wave
	profile["best_by_start"] = best
	profile["stats"] = {"total_runs": runs, "total_kills": kills, "bosses_defeated": bosses}


func test_summary_saved_before_summary_shows() -> void:
	print("\n[CASE] test_summary_saved_before_summary_shows")
	_begin()
	var rs := _new_run_state()
	var wm := _new_wave_manager(3)
	_clear_wave(wm, 4)
	assert_true(_summary_saves == 1, "One write is done by the time the summary is announced")
	var run_flag := _summary_run_flag
	assert_true(int(run_flag.get("waves_cleared", -1)) == 3, "The disk already holds waves_cleared 3")
	assert_true(int(run_flag.get("prestige_pending", -1)) == rs.prestige_pending, "The disk already holds the pending prestige")
	assert_true(run_flag.get("run_in_progress", false) == true, "The disk marks the run as in progress")
	assert_true(int(run_flag.get("start_wave", 0)) == 1 and is_equal_approx(float(run_flag.get("start_mult", 0.0)), 1.0), "The disk holds the default start wave and multiplier")
	wm.free()
	rs.free()


func test_held_save_joins_summary_write() -> void:
	print("\n[CASE] test_held_save_joins_summary_write")
	_begin()
	var wm := _new_wave_manager(3)
	EventBus.state_changed.emit(&"COMBAT")
	SaveManager.get_section(SaveManager.PROFILE)["prestige_balance"] = 7
	assert_true(SaveManager.save() == ERR_BUSY, "A save in combat is held back")
	assert_true(_saves == 0, "Nothing is written yet")
	_clear_wave(wm, 0)
	assert_true(_summary_saves == 1, "Exactly one write happened before the summary was announced")
	assert_true(int(_disk(&"profile").get("prestige_balance", 0)) == 7, "That write carries the held back data")
	assert_true(_saves == 1, "The state change to SUMMARY adds no second write")
	wm.free()


func test_wave_clear_prestige_added() -> void:
	print("\n[CASE] test_wave_clear_prestige_added")
	_begin()
	var rs := _new_run_state()
	var wm := _new_wave_manager(3)
	var kill_prestige := 3
	_clear_wave(wm, kill_prestige)
	var expected := kill_prestige + PrestigeCalc.wave_clear_prestige(3)
	assert_true(rs.prestige_pending == expected, "Pending holds the kill prestige plus the wave clear prestige")
	var summary: Dictionary = _summaries.back() if not _summaries.is_empty() else {}
	assert_true(not summary.is_empty() and summary.prestige_gain_wave == expected, "The summary shows the same number")
	assert_true(rs.wave_prestige_buffer == 0, "The wave buffer is emptied once it moved into pending")
	assert_true(not _pending.is_empty() and _pending.back() == rs.prestige_pending, "prestige_pending_changed carries the total")
	wm.advance_to_next_wave()
	_clear_wave(wm, 0)
	assert_true(rs.prestige_pending == expected + PrestigeCalc.wave_clear_prestige(4), "The next wave adds its own wave clear prestige on top")
	wm.free()
	rs.free()


func test_wave_clear_prestige_formula() -> void:
	print("\n[CASE] test_wave_clear_prestige_formula")
	var base: int = GameConfig.wave_prestige_base
	var step: int = GameConfig.wave_prestige_step
	assert_true(PrestigeCalc.wave_clear_prestige(1) == base + 1 / step, "Wave 1 pays the base plus floor(1 / step)")
	assert_true(PrestigeCalc.wave_clear_prestige(step - 1) == base, "The wave before the first step pays the base")
	assert_true(PrestigeCalc.wave_clear_prestige(step) == base + 1, "The first step wave pays one more")
	assert_true(PrestigeCalc.wave_clear_prestige(step * 2) == base + 2, "Two steps pay two more")
	assert_true(PrestigeCalc.wave_clear_prestige(0) == PrestigeCalc.wave_clear_prestige(1), "Wave below 1 counts as wave 1")


func test_prestige_gain_formula() -> void:
	print("\n[CASE] test_prestige_gain_formula")
	assert_true(PrestigeCalc.prestige_gain(100, 10, 1.0) == _expected_gain(100, 10, 1.0), "Gain follows pending, buffer ratio and conversion rate")
	assert_true(PrestigeCalc.prestige_gain(100, 10, 0.6) == _expected_gain(100, 10, 0.6), "The start multiplier scales the gain")
	assert_true(PrestigeCalc.prestige_gain(0, 0, 1.0) == 0, "Nothing pending gives nothing")


func test_wave1_buffer_only() -> void:
	print("\n[CASE] test_wave1_buffer_only")
	_begin()
	var rs := _new_run_state()
	rs.wave_prestige_buffer = 4
	rs.prestige_pending = 0
	rs.end_run(&"COMMANDER_DIED")
	var expected := WaveRewardTable.floor_gold(GameConfig.prestige_buffer_ratio * 4.0 * GameConfig.conversion_rate)
	assert_true(int(_disk(&"profile").get("prestige_balance", -1)) == expected, "A run lost in wave 1 still converts the unfinished wave buffer")
	rs.free()


func test_run_end_updates_profile() -> void:
	print("\n[CASE] test_run_end_updates_profile")
	_begin()
	_set_profile(20, 2, 30, 1, 4, {"1": 4})
	var rs := _new_run_state()
	rs.run_kills = 12
	rs.run_bosses_defeated = 1
	rs.waves_cleared = 7
	rs.prestige_pending = 50
	var gain := _expected_gain(50, 0, 1.0)
	rs.end_run(&"FORTRESS_DESTROYED")
	var profile := _disk(&"profile")
	var best: Dictionary = profile.get("best_by_start", {})
	assert_true(int(profile.get("prestige_balance", -1)) == 20 + gain, "Balance grows by the converted prestige")
	assert_true(_disk_stat("total_runs") == 3, "Total runs grows by one")
	assert_true(_disk_stat("total_kills") == 42, "Total kills adds the run kills")
	assert_true(_disk_stat("bosses_defeated") == 2, "Bosses defeated adds the run bosses")
	assert_true(int(profile.get("max_wave_cleared", 0)) == 7, "Best wave cleared is raised")
	assert_true(int(best.get("1", 0)) == 7, "Best for the starting wave is raised")
	assert_true(_disk(&"run_flag").get("run_in_progress", true) == false, "The run flag is cleared")
	assert_true(_balances.size() == 1 and _balances[0] == 20 + gain, "The new balance is announced once")
	rs.free()


func test_run_end_in_combat_writes_now() -> void:
	print("\n[CASE] test_run_end_in_combat_writes_now")
	_begin()
	var rs := _new_run_state()
	EventBus.state_changed.emit(&"COMBAT")
	rs.end_run(&"FORTRESS_DESTROYED")
	assert_true(_disk_stat("total_runs") == 1, "The run end is on disk right after it, even from combat")
	assert_true(SaveManager.save() == OK, "Saving works again after the run end")
	rs.free()


func test_run_end_recorded_once() -> void:
	print("\n[CASE] test_run_end_recorded_once")
	_begin()
	var rs := _new_run_state()
	rs.run_kills = 5
	rs.prestige_pending = 20
	var summary := rs.build_summary(&"FORTRESS_DESTROYED", &"DEFEAT")
	EventBus.run_ended.emit(&"FORTRESS_DESTROYED", summary)
	EventBus.run_ended.emit(&"FORTRESS_DESTROYED", summary)
	assert_true(_disk_stat("total_runs") == 1, "A repeated run_ended counts one run")
	assert_true(_disk_stat("total_kills") == 5, "The kills are added once")
	assert_true(_balances.size() == 1, "The balance is announced once")
	_start_new_run_marker()
	EventBus.run_ended.emit(&"FORTRESS_DESTROYED", summary)
	assert_true(_disk_stat("total_runs") == 2, "The next run counts again")
	rs.free()


func test_best_by_start_keeps_max() -> void:
	print("\n[CASE] test_best_by_start_keeps_max")
	_begin()
	_set_profile(0, 0, 0, 0, 9, {"1": 9})
	EventBus.run_ended.emit(&"ABANDONED", {"waves_cleared": 5, "start_wave": 1})
	var profile := SaveManager.get_section(SaveManager.PROFILE)
	var best: Dictionary = profile["best_by_start"]
	assert_true(int(profile["max_wave_cleared"]) == 9 and int(best["1"]) == 9, "A shorter run keeps both records")
	_start_new_run_marker()
	EventBus.run_ended.emit(&"ABANDONED", {"waves_cleared": 12, "start_wave": 1})
	assert_true(int(profile["max_wave_cleared"]) == 12 and int(best["1"]) == 12, "A longer run raises both records")
	_start_new_run_marker()
	EventBus.run_ended.emit(&"ABANDONED", {"waves_cleared": 14, "start_wave": 11})
	assert_true(int(best["11"]) == 14, "A run from another start wave has its own record")
	assert_true(int(best["1"]) == 12, "The record of the first start wave is untouched")


func test_run_only_stats_not_saved() -> void:
	print("\n[CASE] test_run_only_stats_not_saved")
	_begin()
	var rs := _new_run_state()
	rs.run_gold_earned = 500
	rs.run_commander_kills = 3
	rs.damage_by_tower_type = {"arrow": 10}
	rs.end_run(&"FORTRESS_DESTROYED")
	var text := JSON.stringify(_repo.stored)
	assert_true(not text.is_empty() and _disk_stat("total_runs") == 1, "The run end was written")
	assert_true(not text.contains("run_gold_earned"), "Run gold is not saved")
	assert_true(not text.contains("run_commander_kills"), "Commander kills of the run are not saved")
	assert_true(not text.contains("damage_by_tower_type"), "Damage by tower type is not saved")
	rs.free()


func test_empty_summary_not_recorded() -> void:
	print("\n[CASE] test_empty_summary_not_recorded")
	_begin()
	EventBus.state_changed.emit(&"COMBAT")
	EventBus.run_ended.emit(&"ABANDONED", {})
	assert_true(_disk_stat("total_runs") == 0, "An empty summary does not count a run")
	assert_true(_balances.is_empty(), "No balance change is announced")
	assert_true(SaveManager.save() == OK, "The combat hold is lifted all the same")


func test_run_start_flag() -> void:
	print("\n[CASE] test_run_start_flag")
	_begin()
	assert_true(SaveManager.record_run_start(1, 1.0) == OK, "Run start is written")
	var run_flag := _disk(&"run_flag")
	assert_true(run_flag.get("run_in_progress", false) == true, "The run is marked in progress")
	assert_true(int(run_flag.get("start_wave", 0)) == 1 and is_equal_approx(float(run_flag.get("start_mult", 0.0)), 1.0), "Start wave and multiplier are stored")
	assert_true(int(run_flag.get("waves_cleared", -1)) == 0 and int(run_flag.get("prestige_pending", -1)) == 0, "Nothing cleared and nothing pending yet")
	assert_true(SaveManager.record_run_start(11, 0.6) == OK, "A later start wave is written")
	run_flag = _disk(&"run_flag")
	assert_true(int(run_flag.get("waves_cleared", -1)) == 10, "Waves before the start wave count as cleared")
	assert_true(is_equal_approx(float(run_flag.get("start_mult", 0.0)), 0.6), "The multiplier is stored")


func test_summary_blocked_save_silent() -> void:
	print("\n[CASE] test_summary_blocked_save_silent")
	_begin()
	SaveManager.can_write = false
	assert_true(SaveManager.record_wave_summary(3, 9, 1, 1.0) == ERR_UNAVAILABLE, "A blocked save reports unavailable")
	assert_true(_failures == 0, "No failure is announced")
	assert_true(_saves == 0, "Nothing is written")
	assert_true(int(SaveManager.get_section(SaveManager.RUN_FLAG)["waves_cleared"]) == 3, "The flag is still updated in memory")
	SaveManager.can_write = true


func test_tutorial_done_saved() -> void:
	print("\n[CASE] test_tutorial_done_saved")
	_begin()
	assert_true(SaveManager.mark_tutorial_done() == OK, "Marking the tutorial done works")
	assert_true(_disk(&"flags").get("tutorial_done", false) == true, "The flag is on disk")
	assert_true(_tutorial_signals == 1, "tutorial_completed is sent once")
	var saves := _saves
	assert_true(SaveManager.mark_tutorial_done() == OK, "Marking it again is fine")
	assert_true(_tutorial_signals == 1 and _saves == saves, "The second call neither sends the signal nor writes")


func test_tutorial_done_in_combat_deferred() -> void:
	print("\n[CASE] test_tutorial_done_in_combat_deferred")
	_begin()
	EventBus.state_changed.emit(&"COMBAT")
	assert_true(SaveManager.mark_tutorial_done() == ERR_BUSY, "In combat the write is held back")
	assert_true(_tutorial_signals == 1, "The signal is sent at once")
	assert_true(_disk(&"flags").get("tutorial_done", false) == false, "The disk is not written yet")
	EventBus.state_changed.emit(&"SUMMARY")
	assert_true(_disk(&"flags").get("tutorial_done", false) == true, "The held back flag is written when combat ends")


func test_run_state_summary_keys() -> void:
	print("\n[CASE] test_run_state_summary_keys")
	var rs := _new_run_state()
	rs.init_from_config(RunConfig.create_default(0, {"start_wave": 11, "start_mult": 0.6}))
	rs.prestige_pending = 40
	rs.wave_prestige_buffer = 6
	assert_true(rs.start_wave == 11 and is_equal_approx(rs.start_mult, 0.6), "The run state keeps the start wave and multiplier")
	var summary := rs.build_summary(&"FORTRESS_DESTROYED", &"DEFEAT")
	assert_true(summary.has("start_wave") and summary.has("start_mult") and summary.has("wave_prestige_buffer") and summary.has("prestige_gain"), "The summary carries the new keys")
	assert_true(summary.get("prestige_gain") == PrestigeCalc.prestige_gain(40, 6, 0.6), "The summary gain comes from the shared formula")
	rs.free()
