extends Node

## Automated test runner for the boss reward:
## - boss gold from the reward table, shown on death and paid at the summary step
## - boss prestige paid at the summary step, both halved when the boss died after Enrage
## - boss killed as the last unit of the wave still counts (Emergency repair charge, gold)

const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const BULWARK_SCENE: PackedScene = preload("res://entities/enemy/bulwark.tscn")
const GRUNT_DATA: EnemyData = preload("res://data/enemies/grunt.tres")
const FORTRESS_GROUP: StringName = &"fortress"
const BOSS_WAVE: int = 5

var passes: int = 0
var fails: int = 0

# Listener logs, cleared by _reset_logs() at the start of every case.
var _summaries: Array[Dictionary] = []
var _deltas: Array[int] = []
var _pending: Array[int] = []
var _died: Array = []
var _order: Array[String] = []


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


## Stands in for a destroyed Fortress: the wave manager only reads its health.
class FakeFortress extends Node:
	var health: HealthComponent


func _ready() -> void:
	print("\n=======================================================")
	print("             AUTOMATED BOSS REWARD TEST                ")
	print("=======================================================")

	var real_repo := SaveManager.repository
	SaveManager.set_repository(MemorySaveRepository.new())
	SaveManager.load_save()

	EventBus.wave_summary_ready.connect(_on_summary)
	EventBus.gold_delta.connect(_on_delta)
	EventBus.prestige_pending_changed.connect(_on_pending)
	EventBus.enemy_died.connect(_on_died)
	EventBus.boss_defeated.connect(_on_boss_defeated_logged)
	EventBus.wave_cleared.connect(_on_wave_cleared_logged)

	await test_boss_gold_from_table_at_summary()
	await test_boss_popup_without_wallet_change()
	await test_boss_gold_ignores_clear_mult_and_commander_flag()
	await test_enraged_boss_halves_gold_and_prestige()
	await test_boss_prestige_at_summary()
	test_summary_keys_unchanged()
	await test_escort_reward_normal_after_enrage()
	test_enrage_flag_resets_next_boss_wave()
	test_enrage_after_boss_death_ignored()
	await test_boss_killed_last_pays_reward()
	await test_emergency_charge_cap_and_normal_wave()
	await test_enraged_boss_still_gives_charge()
	test_boss_par_time()
	await test_bosses_defeated_counted()
	await test_no_boss_reward_when_run_lost()
	await test_boss_reward_past_table()
	test_no_popup_without_boss()

	EventBus.wave_summary_ready.disconnect(_on_summary)
	EventBus.gold_delta.disconnect(_on_delta)
	EventBus.prestige_pending_changed.disconnect(_on_pending)
	EventBus.enemy_died.disconnect(_on_died)
	EventBus.boss_defeated.disconnect(_on_boss_defeated_logged)
	EventBus.wave_cleared.disconnect(_on_wave_cleared_logged)
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


func _on_summary(summary: Dictionary) -> void:
	_summaries.append(summary)


func _on_delta(delta: int) -> void:
	_deltas.append(delta)


func _on_pending(value: int) -> void:
	_pending.append(value)


func _on_died(enemy_type: StringName, _pos: Vector3, gold_base: float, prestige: int, _is_cull: bool, _hit_by_commander: bool) -> void:
	_died.append([enemy_type, gold_base, prestige])
	_order.append("enemy_died")


func _on_boss_defeated_logged() -> void:
	_order.append("boss_defeated")


func _on_wave_cleared_logged(_wave_index: int) -> void:
	_order.append("wave_cleared")


func _reset_logs() -> void:
	_summaries.clear()
	_deltas.clear()
	_pending.clear()
	_died.clear()
	_order.clear()


func _last_summary() -> Dictionary:
	if _summaries.is_empty():
		return {}
	return _summaries.back()


func _new_wave_manager(wave: int) -> WaveManager:
	var wm := WaveManager.new()
	wm.auto_advance_summary = false
	wm.current_wave = wave
	add_child(wm)
	return wm


func _new_gold_manager() -> GoldManager:
	var gold_mgr := GoldManager.new()
	add_child(gold_mgr)
	gold_mgr.reset()
	return gold_mgr


func _spawn_bulwark() -> Bulwark:
	var bulwark: Bulwark = BULWARK_SCENE.instantiate() as Bulwark
	bulwark.data = preload("res://data/bosses/bulwark_boss.tres")
	bulwark.spawn_grace = false
	bulwark.is_in_spawn_zone = false
	add_child(bulwark)
	return bulwark


## Kills a fresh boss while the wave manager is not fighting, so the wave cannot end on it.
func _kill_boss_in_prep() -> void:
	var bulwark := _spawn_bulwark()
	bulwark._on_died()
	await _free_after_nav_setup([bulwark])


## Puts the manager in the boss fight with the boss as the only unit left.
func _enter_boss_combat_with_last_boss(wm: WaveManager) -> void:
	wm.wave_state = Enums.WaveState.BOSS_COMBAT
	wm.spawn_queue.clear()
	wm.enemies_alive = 1


func _free_after_nav_setup(nodes: Array) -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	for n in nodes:
		if is_instance_valid(n):
			n.free()


func _boss_gold(wave: int) -> int:
	return WaveRewardTable.floor_gold(GameConfig.wave_rewards.get_boss_gold(wave))


func _enraged_boss_gold(wave: int) -> int:
	return WaveRewardTable.floor_gold(GameConfig.wave_rewards.get_boss_gold(wave) * GameConfig.enrage_reward_mult)


func _enraged_boss_prestige() -> int:
	return WaveRewardTable.floor_gold(float(GameConfig.boss_prestige) * GameConfig.enrage_reward_mult)


## Gold the summary paid for the wave kills, so the rest of gold_total is the boss part.
func _escort_gold(wm: WaveManager, summary: Dictionary) -> int:
	return WaveRewardTable.floor_gold(wm._wave_gold_base * float(summary.gold_mult))


## Kills one Grunt scaled to `wave`; free it only after navigation setup ran.
func _kill_grunt(wave: int) -> Enemy:
	var e: Enemy = GRUNT_SCENE.instantiate() as Enemy
	e.apply_wave_scale(1.0, 1.0, 1.0, wave)
	add_child(e)
	e.spawn_grace = false
	e.hit_by_commander = false
	e._on_died()
	return e


func test_boss_gold_from_table_at_summary() -> void:
	print("\n[CASE] test_boss_gold_from_table_at_summary")
	_reset_logs()
	var gold_mgr := _new_gold_manager()
	var wm := _new_wave_manager(BOSS_WAVE)
	var start := gold_mgr.gold
	EventBus.boss_defeated.emit()
	wm._end_combat_to_summary()
	var summary := _last_summary()
	assert_true(not summary.is_empty(), "Summary was built")
	var expected: int = _escort_gold(wm, summary) + _boss_gold(BOSS_WAVE)
	assert_true(gold_mgr.gold - start == expected, "Wallet gains the wave gold plus the table boss gold")
	print("  [INFO] boss gold at wave %d: %d" % [BOSS_WAVE, _boss_gold(BOSS_WAVE)])
	wm.free()
	gold_mgr.free()


func test_boss_popup_without_wallet_change() -> void:
	print("\n[CASE] test_boss_popup_without_wallet_change")
	_reset_logs()
	var gold_mgr := _new_gold_manager()
	var wm := _new_wave_manager(BOSS_WAVE)
	var start := gold_mgr.gold
	await _kill_boss_in_prep()
	assert_true(_deltas.size() == 1 and _deltas[0] == _boss_gold(BOSS_WAVE), "Boss death shows exactly one number equal to the table boss gold")
	assert_true(gold_mgr.gold == start, "Wallet is unchanged before the summary")
	wm._end_combat_to_summary()
	assert_true(gold_mgr.gold - start == _boss_gold(BOSS_WAVE), "Summary pays the wallet exactly the number that was shown")
	assert_true(_deltas.size() == 1, "Summary shows no second number")
	wm.free()
	gold_mgr.free()


func test_boss_gold_ignores_clear_mult_and_commander_flag() -> void:
	print("\n[CASE] test_boss_gold_ignores_clear_mult_and_commander_flag")
	_reset_logs()
	var gold_mgr := _new_gold_manager()
	var wm := _new_wave_manager(BOSS_WAVE)
	wm._wave_gold_base = 50.0
	wm._clear_time = 0.0
	var start := gold_mgr.gold
	var bulwark := _spawn_bulwark()
	bulwark.hit_by_commander = true
	bulwark._on_died()
	wm._end_combat_to_summary()
	var summary := _last_summary()
	assert_true(not summary.is_empty(), "Summary was built")
	assert_true(summary.gold_total - _escort_gold(wm, summary) == _boss_gold(BOSS_WAVE), "Boss part of gold_total ignores the clear multiplier and the commander bonus")
	assert_true(gold_mgr.gold - start == summary.gold_total, "Wallet gains gold_total")
	wm.free()
	gold_mgr.free()
	await _free_after_nav_setup([bulwark])


func test_enraged_boss_halves_gold_and_prestige() -> void:
	print("\n[CASE] test_enraged_boss_halves_gold_and_prestige")
	_reset_logs()
	var gold_mgr := _new_gold_manager()
	var wm := _new_wave_manager(BOSS_WAVE)
	var start := gold_mgr.gold
	EventBus.boss_enraged.emit()
	await _kill_boss_in_prep()
	wm._end_combat_to_summary()
	var summary := _last_summary()
	assert_true(_deltas.size() == 1 and _deltas[0] == _enraged_boss_gold(BOSS_WAVE), "Shown boss gold is cut by the Enrage multiplier")
	assert_true(gold_mgr.gold - start == _enraged_boss_gold(BOSS_WAVE) + _escort_gold(wm, summary), "Wallet gains the cut boss gold")
	assert_true(summary.prestige_gain_wave == _enraged_boss_prestige(), "Boss prestige is cut by the Enrage multiplier and rounded down")
	print("  [INFO] enraged boss gold %d, prestige %d" % [_enraged_boss_gold(BOSS_WAVE), _enraged_boss_prestige()])
	wm.free()
	gold_mgr.free()


func test_boss_prestige_at_summary() -> void:
	print("\n[CASE] test_boss_prestige_at_summary")
	_reset_logs()
	var wm := _new_wave_manager(BOSS_WAVE)
	await _kill_boss_in_prep()
	assert_true(_died.size() == 1 and _died[0][2] == 0, "Boss enemy_died carries 0 prestige")
	assert_true(wm._wave_prestige == 0, "Wave prestige is unchanged before the summary")
	wm._end_combat_to_summary()
	var summary := _last_summary()
	assert_true(summary.prestige_gain_wave == GameConfig.boss_prestige, "Summary adds the full boss prestige")
	assert_true(not _pending.is_empty() and _pending.back() == GameConfig.boss_prestige, "Pending prestige includes the boss prestige")
	wm.free()


func test_summary_keys_unchanged() -> void:
	print("\n[CASE] test_summary_keys_unchanged")
	_reset_logs()
	var wm := _new_wave_manager(BOSS_WAVE)
	EventBus.boss_defeated.emit()
	wm._end_combat_to_summary()
	var summary := _last_summary()
	assert_true(not summary.is_empty(), "Summary was built")
	assert_true(not summary.has("boss_gold"), "Summary has no boss_gold key")
	assert_true(not summary.has("boss_enraged"), "Summary has no boss_enraged key")
	wm.free()


func test_escort_reward_normal_after_enrage() -> void:
	print("\n[CASE] test_escort_reward_normal_after_enrage")
	_reset_logs()
	var wm := _new_wave_manager(BOSS_WAVE)
	EventBus.boss_enraged.emit()
	var grunt := _kill_grunt(BOSS_WAVE)
	var expected: float = GameConfig.wave_rewards.get_kill_gold(GRUNT_DATA.gold_reward, BOSS_WAVE, false)
	assert_true(is_equal_approx(wm._wave_gold_base, expected), "Escort kill gold is not cut after Enrage")
	assert_true(wm._wave_prestige == GRUNT_DATA.prestige_reward, "Escort prestige is not cut after Enrage")
	wm.free()
	await _free_after_nav_setup([grunt])


func test_enrage_flag_resets_next_boss_wave() -> void:
	print("\n[CASE] test_enrage_flag_resets_next_boss_wave")
	_reset_logs()
	var wm := _new_wave_manager(BOSS_WAVE)
	EventBus.boss_enraged.emit()
	EventBus.boss_defeated.emit()
	wm._end_combat_to_summary()
	assert_true(wm._boss_enraged_this_wave, "Flag is set while the wave 5 boss dies enraged")
	_reset_logs()
	wm.current_wave = BOSS_WAVE * 2
	wm.start_prep()
	assert_true(not wm._boss_enraged_this_wave, "start_prep clears the Enrage flag")
	EventBus.boss_defeated.emit()
	wm._end_combat_to_summary()
	var summary := _last_summary()
	assert_true(summary.gold_total - _escort_gold(wm, summary) == _boss_gold(BOSS_WAVE * 2), "Next boss wave pays the full boss gold")
	assert_true(summary.prestige_gain_wave == GameConfig.boss_prestige, "Next boss wave pays the full boss prestige")
	wm.free()


func test_enrage_after_boss_death_ignored() -> void:
	print("\n[CASE] test_enrage_after_boss_death_ignored")
	_reset_logs()
	var wm := _new_wave_manager(BOSS_WAVE)
	EventBus.boss_defeated.emit()
	EventBus.boss_enraged.emit()
	wm._end_combat_to_summary()
	var summary := _last_summary()
	assert_true(summary.gold_total - _escort_gold(wm, summary) == _boss_gold(BOSS_WAVE), "Enrage after the boss died leaves the boss gold whole")
	assert_true(summary.prestige_gain_wave == GameConfig.boss_prestige, "Enrage after the boss died leaves the boss prestige whole")
	wm.free()


## Builds a boss fight where the boss is the last unit, with a real Emergency repair holding `charges`.
func _setup_last_boss_fight(charges: int, enraged: bool) -> Dictionary:
	_reset_logs()
	var gold_mgr := _new_gold_manager()
	var repair := EmergencyRepair.new()
	add_child(repair)
	# reset() is deferred from _ready; let it run before choosing the charges.
	await get_tree().process_frame
	repair.charges = charges
	var wm := _new_wave_manager(BOSS_WAVE)
	_enter_boss_combat_with_last_boss(wm)
	if enraged:
		EventBus.boss_enraged.emit()
	_order.clear()
	return {"gold_mgr": gold_mgr, "repair": repair, "wm": wm}


func _free_fight(fight: Dictionary) -> void:
	fight.wm.free()
	fight.repair.free()
	fight.gold_mgr.free()


func test_boss_killed_last_pays_reward() -> void:
	print("\n[CASE] test_boss_killed_last_pays_reward")
	var fight := await _setup_last_boss_fight(2, false)
	var start: int = fight.gold_mgr.gold
	var bulwark := _spawn_bulwark()
	bulwark._on_died()
	assert_true(_summaries.size() == 1, "Exactly one summary is built")
	var summary := _last_summary()
	assert_true(not summary.is_empty() and fight.gold_mgr.gold - start == _escort_gold(fight.wm, summary) + _boss_gold(BOSS_WAVE), "Wallet includes the boss gold")
	assert_true(not summary.is_empty() and summary.emg_repair_gained == 1, "Summary reports the extra Emergency repair charge")
	var defeated_at: int = _order.find("boss_defeated")
	assert_true(defeated_at != -1 and defeated_at < _order.find("wave_cleared"), "boss_defeated arrives before wave_cleared")
	assert_true(fight.repair.charges == 3, "Emergency repair gained one charge")
	_free_fight(fight)
	await _free_after_nav_setup([bulwark])


func test_emergency_charge_cap_and_normal_wave() -> void:
	print("\n[CASE] test_emergency_charge_cap_and_normal_wave")
	var fight := await _setup_last_boss_fight(GameConfig.emg_repair_charges_max, false)
	var bulwark := _spawn_bulwark()
	bulwark._on_died()
	assert_true(fight.repair.charges == GameConfig.emg_repair_charges_max, "Charges stay at the maximum")
	_free_fight(fight)
	await _free_after_nav_setup([bulwark])

	var normal := await _setup_last_boss_fight(2, false)
	normal.wm.current_wave = BOSS_WAVE - 1
	normal.wm.wave_state = Enums.WaveState.COMBAT
	var grunt := _kill_grunt(BOSS_WAVE - 1)
	var summary := _last_summary()
	assert_true(not summary.is_empty() and summary.emg_repair_gained == 0, "Normal wave reports no extra charge")
	assert_true(normal.repair.charges == 2, "Normal wave leaves the charges alone")
	_free_fight(normal)
	await _free_after_nav_setup([grunt])


func test_enraged_boss_still_gives_charge() -> void:
	print("\n[CASE] test_enraged_boss_still_gives_charge")
	var fight := await _setup_last_boss_fight(2, true)
	var bulwark := _spawn_bulwark()
	bulwark._on_died()
	var summary := _last_summary()
	assert_true(fight.repair.charges == 3, "Enraged boss death still refunds a charge")
	assert_true(not summary.is_empty() and summary.emg_repair_gained == 1, "Summary reports the charge")
	_free_fight(fight)
	await _free_after_nav_setup([bulwark])


func test_boss_par_time() -> void:
	print("\n[CASE] test_boss_par_time")
	_reset_logs()
	var wm := _new_wave_manager(BOSS_WAVE)
	wm._end_combat_to_summary()
	var summary := _last_summary()
	assert_true(not summary.is_empty() and is_equal_approx(summary.par_time, GameConfig.par_time_boss_ratio * GameConfig.get_boss_timer(1)), "Boss wave par time follows the boss timer")
	wm.free()


func test_bosses_defeated_counted() -> void:
	print("\n[CASE] test_bosses_defeated_counted")
	_reset_logs()
	var rs := RunState.new()
	add_child(rs)
	var wm := _new_wave_manager(BOSS_WAVE)
	var before := rs.run_bosses_defeated
	await _kill_boss_in_prep()
	assert_true(rs.run_bosses_defeated == before + 1, "Boss death counts once in the run statistics")
	wm.free()
	rs.free()


func test_no_boss_reward_when_run_lost() -> void:
	print("\n[CASE] test_no_boss_reward_when_run_lost")
	_reset_logs()
	var gold_mgr := _new_gold_manager()
	var fortress := FakeFortress.new()
	fortress.add_to_group(FORTRESS_GROUP)
	fortress.health = HealthComponent.new()
	fortress.add_child(fortress.health)
	add_child(fortress)
	fortress.health.hp = 0
	var wm := _new_wave_manager(BOSS_WAVE)
	var start := gold_mgr.gold
	await _kill_boss_in_prep()
	wm._end_combat_to_summary()
	assert_true(gold_mgr.gold == start, "Wallet is unchanged when the run is lost")
	assert_true(_summaries.is_empty(), "No summary is built when the run is lost")
	assert_true(_pending.is_empty(), "No pending prestige is announced when the run is lost")
	wm.free()
	fortress.free()
	gold_mgr.free()


func test_boss_reward_past_table() -> void:
	print("\n[CASE] test_boss_reward_past_table")
	_reset_logs()
	var wave: int = GameConfig.victory_wave + 5
	var wm := _new_wave_manager(wave)
	EventBus.boss_enraged.emit()
	await _kill_boss_in_prep()
	wm._end_combat_to_summary()
	var summary := _last_summary()
	var formula: float = float(GameConfig.boss_gold_base) * (1.0 + GameConfig.gold_reward_growth_per_wave * float(wave - 1))
	assert_true(is_equal_approx(GameConfig.wave_rewards.get_boss_gold(wave), formula), "Table gives the formula boss gold past the last row")
	assert_true(not summary.is_empty() and summary.gold_total - _escort_gold(wm, summary) == _enraged_boss_gold(wave), "Boss gold past the table is cut by Enrage")
	assert_true(not summary.is_empty() and summary.prestige_gain_wave == _enraged_boss_prestige(), "Boss prestige past the table is the same cut value")
	wm.free()


func test_no_popup_without_boss() -> void:
	print("\n[CASE] test_no_popup_without_boss")
	_reset_logs()
	var wm := _new_wave_manager(BOSS_WAVE)
	wm._end_combat_to_summary()
	var summary := _last_summary()
	assert_true(_deltas.is_empty(), "No boss number without a boss death")
	assert_true(not summary.is_empty() and summary.gold_total == _escort_gold(wm, summary), "No boss gold without a boss death")
	assert_true(not summary.is_empty() and summary.prestige_gain_wave == 0, "No boss prestige without a boss death")
	wm.free()
