extends Node

## Automated test runner for WaveRewardTable:
## - table values, formula past the table, short-table fallbacks, wave below 1
## - kill gold and boss gold formulas, floor_gold
## - enemy_died carries the float kill gold; WaveManager and XpTracker consume it

const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const ARCHER_SCENE: PackedScene = preload("res://entities/enemy/archer.tscn")
const BULWARK_SCENE: PackedScene = preload("res://entities/enemy/bulwark.tscn")
const XP_TRACKER_SCRIPT := preload("res://systems/xp/xp_tracker.gd")
const GRUNT_DATA: EnemyData = preload("res://data/enemies/grunt.tres")
const ARCHER_DATA: EnemyData = preload("res://data/enemies/archer.tres")

var passes: int = 0
var fails: int = 0
var _orig_table: WaveRewardTable
var _orig_victory_wave: int


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
	print("          AUTOMATED WAVE REWARD TABLE TEST             ")
	print("=======================================================")

	_orig_table = GameConfig.wave_rewards
	_orig_victory_wave = GameConfig.victory_wave
	var real_repo := SaveManager.repository
	SaveManager.set_repository(MemorySaveRepository.new())
	SaveManager.load_save()

	test_table_loaded()
	test_gold_mult_inside_table()
	test_gold_mult_beyond_table()
	test_xp_mult_beyond_table()
	test_mithril_beyond_table()
	test_boundary_follows_victory_wave()
	test_victory_wave_change_moves_boundary()
	test_short_table_fallback()
	test_wave_below_one()
	test_kill_gold_formula()
	test_boss_gold_formula()
	test_floor_gold()
	await test_enemy_died_gold_is_float()
	await test_popup_rounds_kill_gold()
	await test_f5_wave1()
	await test_hz12_wave3_gold()
	test_wave_manager_adds_gold_as_is()
	await test_boss_kill_adds_no_kill_gold()
	test_summary_boss_gold_from_table()
	test_xp_mult_applied()
	test_xp_wave_resets_on_run_started()
	await test_fake_table_injected()

	_restore()
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


func _restore() -> void:
	GameConfig.wave_rewards = _orig_table
	GameConfig.victory_wave = _orig_victory_wave


## Builds a table with `rows` rows holding the given per-column fill values.
func _make_table(rows: int, gold: float, xp: float, mithril: int) -> WaveRewardTable:
	var t := WaveRewardTable.new()
	var g := PackedFloat32Array()
	var x := PackedFloat32Array()
	var m := PackedInt32Array()
	for i in rows:
		g.append(gold)
		x.append(xp)
		m.append(mithril)
	t.gold_mult = g
	t.xp_mult = x
	t.mithril_reward = m
	return t


func _formula(wave: int) -> float:
	return 1.0 + GameConfig.gold_reward_growth_per_wave * float(wave - 1)


## Spawns a unit scaled to `wave` and kills it; free it only after navigation setup ran.
func _kill_unit(scene: PackedScene, wave: int, commander: bool) -> Enemy:
	var e: Enemy = scene.instantiate() as Enemy
	e.apply_wave_scale(1.0, 1.0, 1.0, wave)
	add_child(e)
	e.spawn_grace = false
	e.hit_by_commander = commander
	e._on_died()
	return e


func _free_after_nav_setup(nodes: Array) -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	for n in nodes:
		if is_instance_valid(n):
			n.free()


func test_table_loaded() -> void:
	print("\n[CASE] test_table_loaded")
	var t := GameConfig.wave_rewards
	assert_true(t != null, "GameConfig.wave_rewards is loaded")
	assert_true(t.resource_path == "res://data/waves/wave_rewards.tres", "Table comes from data/waves/wave_rewards.tres")
	assert_true(t.gold_mult.size() == GameConfig.victory_wave, "gold_mult has victory_wave rows")
	assert_true(t.xp_mult.size() == GameConfig.victory_wave, "xp_mult has victory_wave rows")
	assert_true(t.mithril_reward.size() == GameConfig.victory_wave, "mithril_reward has victory_wave rows")
	var non_negative := true
	for v in t.gold_mult:
		non_negative = non_negative and v >= 0.0
	for v in t.xp_mult:
		non_negative = non_negative and v >= 0.0
	for v in t.mithril_reward:
		non_negative = non_negative and v >= 0
	assert_true(non_negative, "No negative table value")


func test_gold_mult_inside_table() -> void:
	print("\n[CASE] test_gold_mult_inside_table")
	var t := GameConfig.wave_rewards
	var gold_ok := true
	var xp_ok := true
	for w in range(1, GameConfig.victory_wave + 1):
		gold_ok = gold_ok and t.get_gold_mult(w) == snappedf(t.gold_mult[w - 1], WaveRewardTable.SNAP_STEP)
		xp_ok = xp_ok and t.get_xp_mult(w) == snappedf(t.xp_mult[w - 1], WaveRewardTable.SNAP_STEP)
	assert_true(gold_ok, "get_gold_mult matches the snapped table rows for every wave")
	assert_true(xp_ok, "get_xp_mult matches the snapped table rows for every wave")


func test_gold_mult_beyond_table() -> void:
	print("\n[CASE] test_gold_mult_beyond_table")
	var t := GameConfig.wave_rewards
	for w in [GameConfig.victory_wave + 1, GameConfig.victory_wave + 10]:
		assert_true(is_equal_approx(t.get_gold_mult(w), _formula(w)), "Gold multiplier of wave %d follows the growth formula" % w)


func test_xp_mult_beyond_table() -> void:
	print("\n[CASE] test_xp_mult_beyond_table")
	assert_true(GameConfig.wave_rewards.get_xp_mult(GameConfig.victory_wave + 1) == 1.0, "XP multiplier past the table is 1")


func test_mithril_beyond_table() -> void:
	print("\n[CASE] test_mithril_beyond_table")
	var t := GameConfig.wave_rewards
	var last := t.get_mithril_reward(GameConfig.victory_wave)
	assert_true(t.get_mithril_reward(GameConfig.victory_wave + 1) == last, "Mithril of the wave after victory_wave equals the victory_wave value")
	assert_true(t.get_mithril_reward(GameConfig.victory_wave + 5) == last, "Mithril five waves past victory_wave equals the victory_wave value")


func test_boundary_follows_victory_wave() -> void:
	print("\n[CASE] test_boundary_follows_victory_wave")
	var vw := GameConfig.victory_wave
	var t := _make_table(vw + 3, 1.0, 1.0, 0)
	t.gold_mult[vw] = 9.0
	t.xp_mult[vw] = 9.0
	t.mithril_reward[vw - 1] = 2
	t.mithril_reward[vw] = 7
	assert_true(is_equal_approx(t.get_gold_mult(vw + 1), _formula(vw + 1)) and t.get_gold_mult(vw + 1) != 9.0, "Extra gold rows are ignored")
	assert_true(t.get_xp_mult(vw + 1) == 1.0, "Extra XP rows are ignored")
	assert_true(t.get_mithril_reward(vw + 1) == 2, "Mithril past victory_wave uses the victory_wave row, not extra rows")


func test_victory_wave_change_moves_boundary() -> void:
	print("\n[CASE] test_victory_wave_change_moves_boundary")
	var t := _make_table(30, 3.0, 1.0, 1)
	GameConfig.wave_rewards = t
	GameConfig.victory_wave = 10
	assert_true(t.get_gold_mult(10) == 3.0, "Last row wave still reads the table")
	assert_true(is_equal_approx(t.get_gold_mult(11), _formula(11)), "The wave after the new victory_wave uses the formula")
	_restore()


func test_short_table_fallback() -> void:
	print("\n[CASE] test_short_table_fallback")
	print("[INFO] expect 6 'Wave reward table has no' errors below")
	var vw := GameConfig.victory_wave
	var t := _make_table(10, 3.0, 2.0, 1)
	t.mithril_reward[9] = 4
	assert_true(is_equal_approx(t.get_gold_mult(12), _formula(12)), "Missing gold row falls back to the formula")
	assert_true(t.get_xp_mult(12) == 1.0, "Missing XP row falls back to 1")
	assert_true(t.get_mithril_reward(12) == 4, "Missing Mithril row falls back to the last row")
	assert_true(t.get_mithril_reward(vw + 1) == 4, "Mithril past victory_wave on a short table uses the last row")
	var empty := WaveRewardTable.new()
	assert_true(empty.get_mithril_reward(1) == 0, "Empty table pays 0 Mithril")
	assert_true(is_equal_approx(empty.get_gold_mult(1), _formula(1)), "Empty table gold multiplier uses the formula")


func test_wave_below_one() -> void:
	print("\n[CASE] test_wave_below_one")
	print("[INFO] expect 3 'queried with wave' errors below")
	var t := GameConfig.wave_rewards
	assert_true(t.get_gold_mult(0) == t.get_gold_mult(1), "Wave 0 returns the wave 1 gold multiplier")
	assert_true(t.get_gold_mult(-3) == t.get_gold_mult(1), "Negative wave returns the wave 1 gold multiplier")
	assert_true(t.get_mithril_reward(0) == t.get_mithril_reward(1), "Wave 0 returns the wave 1 Mithril")


func test_kill_gold_formula() -> void:
	print("\n[CASE] test_kill_gold_formula")
	var t := GameConfig.wave_rewards
	var g := GRUNT_DATA.gold_reward
	var w := 3
	assert_true(is_equal_approx(t.get_kill_gold(g, w, false), float(g) * t.get_gold_mult(w)), "Kill gold without the commander is gold_reward * gold_mult")
	assert_true(is_equal_approx(t.get_kill_gold(g, w, true), float(g) * t.get_gold_mult(w) * GameConfig.frontline_gold_mult), "Kill gold with the commander applies frontline_gold_mult once")
	assert_true(t.get_kill_gold(0, w, true) == 0.0, "Zero gold_reward pays nothing")


func test_boss_gold_formula() -> void:
	print("\n[CASE] test_boss_gold_formula")
	var t := GameConfig.wave_rewards
	assert_true(is_equal_approx(t.get_boss_gold(5), float(GameConfig.boss_gold_base) * t.get_gold_mult(5)), "Boss gold is boss_gold_base * gold_mult")
	var past := GameConfig.victory_wave + 5
	assert_true(is_equal_approx(t.get_boss_gold(past), float(GameConfig.boss_gold_base) * _formula(past)), "Boss gold past the table uses the formula")


func test_floor_gold() -> void:
	print("\n[CASE] test_floor_gold")
	assert_true(WaveRewardTable.floor_gold(115.99999999999999) == 116, "Float error just under an integer rounds to it")
	assert_true(WaveRewardTable.floor_gold(35.1) == 35, "35.1 floors to 35")
	assert_true(WaveRewardTable.floor_gold(115.99) == 115, "115.99 floors to 115")
	assert_true(WaveRewardTable.floor_gold(0.0) == 0, "0 floors to 0")
	var x: float = float(GameConfig.boss_gold_base) * GameConfig.wave_rewards.get_gold_mult(5)
	if is_equal_approx(x, round(x)):
		assert_true(WaveRewardTable.floor_gold(x) == int(round(x)), "Boss gold on wave 5 floors to its rounded integer")
	else:
		print("  [SKIP] wave 5 boss gold is not an integer in the current data")


func test_enemy_died_gold_is_float() -> void:
	print("\n[CASE] test_enemy_died_gold_is_float")
	var got := {"gold": null}
	var on_died := func(_t, _p, gold, _pr, _c, _h): got.gold = gold
	EventBus.enemy_died.connect(on_died)
	var e := _kill_unit(GRUNT_SCENE, 2, false)
	EventBus.enemy_died.disconnect(on_died)
	assert_true(typeof(got.gold) == TYPE_FLOAT, "enemy_died carries a float gold value")
	assert_true(typeof(got.gold) == TYPE_FLOAT and is_equal_approx(got.gold, float(GRUNT_DATA.gold_reward) * GameConfig.wave_rewards.get_gold_mult(2)), "Gold is gold_reward * gold_mult, not rounded")
	await _free_after_nav_setup([e])


func test_popup_rounds_kill_gold() -> void:
	print("\n[CASE] test_popup_rounds_kill_gold")
	var deltas: Array[int] = []
	var on_delta := func(d: int): deltas.append(d)
	EventBus.gold_delta.connect(on_delta)
	var e := _kill_unit(GRUNT_SCENE, 2, true)
	EventBus.gold_delta.disconnect(on_delta)
	assert_true(deltas.size() == 1 and deltas[0] == int(round(GameConfig.wave_rewards.get_kill_gold(GRUNT_DATA.gold_reward, 2, true))), "Floating number is the rounded commander kill gold")
	await _free_after_nav_setup([e])


func _new_wave_manager(wave: int = 1) -> WaveManager:
	var wm := WaveManager.new()
	wm.auto_advance_summary = false
	wm.current_wave = wave
	add_child(wm)
	return wm


func test_f5_wave1() -> void:
	print("\n[CASE] test_f5_wave1")
	var t := GameConfig.wave_rewards
	var wm := _new_wave_manager()
	EventBus.wave_start_requested.emit()
	var first := _kill_unit(GRUNT_SCENE, 1, true)
	var after_first: float = wm._wave_gold_base
	assert_true(is_equal_approx(after_first, t.get_kill_gold(GRUNT_DATA.gold_reward, 1, true)), "Flagged Grunt adds its commander kill gold")
	var second := _kill_unit(GRUNT_SCENE, 1, false)
	var gain: float = wm._wave_gold_base - after_first
	assert_true(is_equal_approx(gain, t.get_kill_gold(GRUNT_DATA.gold_reward, 1, false)), "Unflagged Grunt adds its plain kill gold")
	if GRUNT_DATA.gold_reward == 4 and t.get_gold_mult(1) == 1.0 and GameConfig.frontline_gold_mult == 1.25:
		assert_true(is_equal_approx(after_first, 5.0) and is_equal_approx(gain, 4.0), "Pinned example: flagged Grunt 5.0, unflagged 4.0")
	else:
		print("  [SKIP] F5 pinned numbers: data changed")
	wm.free()
	await _free_after_nav_setup([first, second])


func test_hz12_wave3_gold() -> void:
	print("\n[CASE] test_hz12_wave3_gold")
	var t := GameConfig.wave_rewards
	var wm := _new_wave_manager()
	EventBus.wave_start_requested.emit()
	var units: Array = []
	for i in 3:
		units.append(_kill_unit(GRUNT_SCENE, 3, true))
	for i in 2:
		units.append(_kill_unit(ARCHER_SCENE, 3, true))
	var expected: float = 3.0 * t.get_kill_gold(GRUNT_DATA.gold_reward, 3, true) + 2.0 * t.get_kill_gold(ARCHER_DATA.gold_reward, 3, true)
	assert_true(is_equal_approx(wm._wave_gold_base, expected), "Wave gold base is the sum of the commander kill gold")
	assert_true(WaveRewardTable.floor_gold(wm._wave_gold_base) == WaveRewardTable.floor_gold(expected), "Floored wave gold matches the expected sum")
	assert_true(WaveRewardTable.floor_gold(wm._wave_gold_base) != WaveRewardTable.floor_gold(wm._wave_gold_base * GameConfig.frontline_gold_mult), "Commander multiplier is not applied twice")
	if GRUNT_DATA.gold_reward == 4 and ARCHER_DATA.gold_reward == 7 and t.get_gold_mult(3) == 1.08 and GameConfig.frontline_gold_mult == 1.25:
		var floored := WaveRewardTable.floor_gold(wm._wave_gold_base)
		assert_true(floored == 35 and floored != 43, "Pinned example: wave 3 gold is 35, not 43")
	else:
		print("  [SKIP] HZ12 pinned numbers: data changed")
	wm.free()
	await _free_after_nav_setup(units)


func test_wave_manager_adds_gold_as_is() -> void:
	print("\n[CASE] test_wave_manager_adds_gold_as_is")
	var wm := _new_wave_manager()
	EventBus.wave_start_requested.emit()
	var before: float = wm._wave_gold_base
	EventBus.enemy_died.emit(&"grunt", Vector3.ZERO, 5.4, 1, false, true)
	assert_true(is_equal_approx(wm._wave_gold_base - before, 5.4), "WaveManager adds the emitted gold without another multiplier")
	var after: float = wm._wave_gold_base
	EventBus.enemy_died.emit(&"grunt", Vector3.ZERO, 5.4, 1, true, true)
	assert_true(wm._wave_gold_base == after, "Culled kill adds no gold")
	wm.free()


func test_boss_kill_adds_no_kill_gold() -> void:
	print("\n[CASE] test_boss_kill_adds_no_kill_gold")
	var wm := _new_wave_manager(5)
	var boss_gold := {"gold": -1.0}
	var on_died := func(_t, _p, gold, _pr, _c, _h): boss_gold.gold = gold
	var deltas: Array[int] = []
	var on_delta := func(d: int): deltas.append(d)
	EventBus.enemy_died.connect(on_died)
	EventBus.gold_delta.connect(on_delta)
	var bulwark: Bulwark = BULWARK_SCENE.instantiate() as Bulwark
	bulwark.data = preload("res://data/bosses/bulwark_boss.tres")
	bulwark.spawn_grace = false
	bulwark.is_in_spawn_zone = false
	add_child(bulwark)
	bulwark.hit_by_commander = true
	bulwark._on_died()
	EventBus.enemy_died.disconnect(on_died)
	EventBus.gold_delta.disconnect(on_delta)
	assert_true(boss_gold.gold == 0.0, "Boss enemy_died carries 0 gold")
	assert_true(wm._wave_gold_base == 0.0, "Boss death leaves wave_gold_base unchanged")
	assert_true(deltas.is_empty(), "Boss death shows no gold number")
	assert_true(wm._boss_defeated_this_wave, "Boss death still marks the boss as defeated")
	wm.free()
	await _free_after_nav_setup([bulwark])


func test_summary_boss_gold_from_table() -> void:
	print("\n[CASE] test_summary_boss_gold_from_table")
	var gold_mgr := GoldManager.new()
	add_child(gold_mgr)
	gold_mgr.reset()
	var start := gold_mgr.gold
	var t := _make_table(30, 1.0, 1.0, 1)
	t.gold_mult[4] = 2.5
	GameConfig.wave_rewards = t
	var wm := _new_wave_manager(5)
	EventBus.boss_defeated.emit()
	wm._end_combat_to_summary()
	assert_true(gold_mgr.gold - start == WaveRewardTable.floor_gold(float(GameConfig.boss_gold_base) * 2.5), "Summary boss gold comes from the table row")
	_restore()
	wm.free()
	gold_mgr.free()


func _new_xp_tracker() -> Node:
	var x = XP_TRACKER_SCRIPT.new()
	add_child(x)
	x.reset()
	return x


## Commander XP gained by one flagged Grunt kill.
func _xp_of_commander_kill(x: Node) -> float:
	var before: float = x.total_xp_from_commander
	EventBus.enemy_died.emit(&"grunt", Vector3.ZERO, 0.0, 1, false, true)
	return x.total_xp_from_commander - before


func test_xp_mult_applied() -> void:
	print("\n[CASE] test_xp_mult_applied")
	var t := _make_table(30, 1.0, 1.0, 1)
	t.xp_mult[2] = 2.0
	GameConfig.wave_rewards = t
	var x := _new_xp_tracker()
	var base := float(GRUNT_DATA.xp_value) * GameConfig.xp_commander_pct
	EventBus.wave_started.emit(3)
	assert_true(is_equal_approx(_xp_of_commander_kill(x), base * 2.0), "Wave 3 kill gains XP times xp_mult")
	EventBus.wave_started.emit(4)
	assert_true(is_equal_approx(_xp_of_commander_kill(x), base), "Wave 4 kill gains the plain XP")
	x.free()
	_restore()


func test_xp_wave_resets_on_run_started() -> void:
	print("\n[CASE] test_xp_wave_resets_on_run_started")
	var t := _make_table(30, 1.0, 1.0, 1)
	t.xp_mult[2] = 2.0
	GameConfig.wave_rewards = t
	var x := _new_xp_tracker()
	var base := float(GRUNT_DATA.xp_value) * GameConfig.xp_commander_pct
	EventBus.wave_started.emit(3)
	EventBus.run_started.emit()
	assert_true(is_equal_approx(_xp_of_commander_kill(x), base * t.get_xp_mult(1)), "A new run starts from the wave 1 XP multiplier")
	x.free()
	_restore()


func test_fake_table_injected() -> void:
	print("\n[CASE] test_fake_table_injected")
	var t := _make_table(30, 1.0, 1.0, 1)
	t.gold_mult[0] = 3.0
	GameConfig.wave_rewards = t
	var got := {"gold": -1.0}
	var on_died := func(_t, _p, gold, _pr, _c, _h): got.gold = gold
	EventBus.enemy_died.connect(on_died)
	var e := _kill_unit(GRUNT_SCENE, 1, false)
	assert_true(is_equal_approx(got.gold, float(GRUNT_DATA.gold_reward) * 3.0), "Enemy kill gold follows the injected table")
	_restore()
	var e2 := _kill_unit(GRUNT_SCENE, 1, false)
	EventBus.enemy_died.disconnect(on_died)
	assert_true(is_equal_approx(got.gold, GameConfig.wave_rewards.get_kill_gold(GRUNT_DATA.gold_reward, 1, false)), "After restoring, kill gold follows the real table")
	await _free_after_nav_setup([e, e2])
