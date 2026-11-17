extends Node

## Automated test runner for the boss weapon drop:
## - WeaponDrop picks an unowned weapon, evenly, by its own seed
## - the wave summary step grants it once per boss wave 5/10/15/20/25 and reports it
## - nothing drops on a lost wave, a non-drop wave, a Hazard Trial boss or a full set
## - RunState.grant_weapon sends weapon_gained only when a weapon is added

const FORTRESS_GROUP: StringName = &"fortress"
const SEED_A: int = 12345
const DROP_WAVES: Array[int] = [5, 10, 15, 20, 25]
const ALL_FIVE: Array[StringName] = [&"burn", &"chain_lightning", &"frost", &"rampage", &"swift"]

var passes: int = 0
var fails: int = 0

# Listener logs, cleared by _reset_logs() at the start of every case.
var _summaries: Array[Dictionary] = []
var _gained: Array[StringName] = []
var _equipped: Array[StringName] = []
var _deltas: Array[int] = []
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
	print("            AUTOMATED WEAPON DROP TEST                 ")
	print("=======================================================")

	var real_repo := SaveManager.repository
	SaveManager.set_repository(MemorySaveRepository.new())
	SaveManager.load_save()

	EventBus.weapon_gained.connect(_on_gained)
	EventBus.weapon_equipped.connect(_on_equipped)
	EventBus.wave_summary_ready.connect(_on_summary)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.gold_delta.connect(_on_delta)

	test_pool_matches_weapon_files()
	test_pick_from_unowned_only()
	test_pick_full_set_returns_empty()
	test_pick_ignores_pool_order()
	test_pick_ignores_bad_pool_entries()
	test_pick_matches_hash_seed()
	test_pick_uniform()
	test_same_seed_same_order()
	test_other_seed_other_order()

	test_wave5_drop()
	test_full_set_by_wave25()
	test_full_set_no_more_drop()
	test_wave30_no_drop()
	test_same_seed_same_order_in_run()
	test_lost_same_frame_no_drop()
	test_lost_by_signal_no_drop()
	test_enraged_boss_still_drops()
	test_boss_not_defeated_no_drop()
	test_non_drop_wave_no_drop()
	test_non_drop_boss_wave_key_empty()
	test_two_boss_signals_one_drop()
	test_late_start_no_compensation()
	test_no_run_state_no_drop()
	test_summary_after_summary_state()

	test_hazard_boss_gives_no_drop()
	test_hazard_boss_then_real_boss_drops()

	test_grant_sends_signal_once()
	test_grant_owned_or_empty_no_signal()
	test_grant_does_not_equip()

	EventBus.weapon_gained.disconnect(_on_gained)
	EventBus.weapon_equipped.disconnect(_on_equipped)
	EventBus.wave_summary_ready.disconnect(_on_summary)
	EventBus.state_changed.disconnect(_on_state_changed)
	EventBus.gold_delta.disconnect(_on_delta)
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


func _on_gained(id: StringName) -> void:
	_gained.append(id)
	_order.append("weapon_gained")


func _on_equipped(id: StringName) -> void:
	_equipped.append(id)


func _on_summary(summary: Dictionary) -> void:
	_summaries.append(summary)
	_order.append("summary")


func _on_state_changed(state: StringName) -> void:
	_order.append(String(state))


func _on_delta(delta: int) -> void:
	_deltas.append(delta)


func _reset_logs() -> void:
	_summaries.clear()
	_gained.clear()
	_equipped.clear()
	_deltas.clear()
	_order.clear()


func _last_summary() -> Dictionary:
	if _summaries.is_empty():
		return {}
	return _summaries.back()


func _new_run(run_seed: int) -> RunState:
	var rs := RunState.new()
	add_child(rs)
	rs.run_seed = run_seed
	rs.owned_weapons.clear()
	rs.owned_weapons.append(RunState.BASE_WEAPON)
	rs.equipped_weapon = RunState.BASE_WEAPON
	rs.start_wave = 1
	rs.waves_cleared = 0
	return rs


## current_wave is set after add_child: with a RunState in the tree it writes to the run.
func _new_wave_manager(wave: int) -> WaveManager:
	var wm := WaveManager.new()
	wm.auto_advance_summary = false
	wm.enable_reward_pick = false
	wm.enable_victory_screen = false
	add_child(wm)
	wm.current_wave = wave
	return wm


func _clear_boss_wave(wm: WaveManager, wave: int) -> void:
	wm.current_wave = wave
	wm.start_prep()
	EventBus.boss_defeated.emit()
	wm._end_combat_to_summary()


func _new_fake_fortress(hp: int) -> FakeFortress:
	var fortress := FakeFortress.new()
	fortress.add_to_group(FORTRESS_GROUP)
	fortress.health = HealthComponent.new()
	fortress.add_child(fortress.health)
	add_child(fortress)
	fortress.health.hp = hp
	return fortress


func _owned_with(extra: Array[StringName]) -> Array[StringName]:
	var owned: Array[StringName] = [RunState.BASE_WEAPON]
	owned.append_array(extra)
	return owned


func _sorted_ids(ids: Array[StringName]) -> Array[StringName]:
	var sorted_ids: Array[StringName] = ids.duplicate()
	sorted_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return sorted_ids


## Drops of waves 5..25 in a pure run, one pick per boss wave.
func _simulate_drops(run_seed: int) -> Array[StringName]:
	var owned: Array[StringName] = [RunState.BASE_WEAPON]
	var order: Array[StringName] = []
	for wave in DROP_WAVES:
		var id := WeaponDrop.pick(run_seed, wave, owned, GameConfig.boss_drop_weapons)
		order.append(id)
		owned.append(id)
	return order


## Drops of a real run: one RunState and one wave manager through the five boss waves.
func _run_five_boss_waves(run_seed: int) -> Array[StringName]:
	_reset_logs()
	var rs := _new_run(run_seed)
	var wm := _new_wave_manager(5)
	for wave in DROP_WAVES:
		_clear_boss_wave(wm, wave)
	var order: Array[StringName] = _gained.duplicate()
	wm.free()
	rs.free()
	return order


# --- pick ---

func test_pool_matches_weapon_files() -> void:
	print("\n[CASE] test_pool_matches_weapon_files")
	var pool: Array[StringName] = GameConfig.boss_drop_weapons
	assert_true(pool.size() == 5, "Pool holds five weapons")
	assert_true(not pool.has(RunState.BASE_WEAPON), "Pool does not hold the base sword")
	var all_files := true
	for id in pool:
		var path := "res://data/weapons/%s.tres" % id
		if not ResourceLoader.exists(path) or (load(path) as WeaponData).id != id:
			all_files = false
	assert_true(all_files, "Every pool id has a weapon file with the same id")


func test_pick_from_unowned_only() -> void:
	print("\n[CASE] test_pick_from_unowned_only")
	var owned := _owned_with([&"frost", &"burn"])
	var allowed: Array[StringName] = [&"chain_lightning", &"rampage", &"swift"]
	var ok := true
	for s in 50:
		if not allowed.has(WeaponDrop.pick(s, 5, owned, GameConfig.boss_drop_weapons)):
			ok = false
	assert_true(ok, "Only unowned weapons are picked")


func test_pick_full_set_returns_empty() -> void:
	print("\n[CASE] test_pick_full_set_returns_empty")
	var owned := _owned_with(ALL_FIVE)
	assert_true(WeaponDrop.pick(SEED_A, 25, owned, GameConfig.boss_drop_weapons) == &"", "A full set picks nothing")
	var empty_pool: Array[StringName] = []
	var base_only: Array[StringName] = [RunState.BASE_WEAPON]
	assert_true(WeaponDrop.pick(SEED_A, 5, base_only, empty_pool) == &"", "An empty pool picks nothing")


func test_pick_ignores_pool_order() -> void:
	print("\n[CASE] test_pick_ignores_pool_order")
	var pool: Array[StringName] = GameConfig.boss_drop_weapons.duplicate()
	var reversed_pool: Array[StringName] = pool.duplicate()
	reversed_pool.reverse()
	var owned: Array[StringName] = [RunState.BASE_WEAPON]
	var same := true
	for s in 50:
		if WeaponDrop.pick(s, 5, owned, pool) != WeaponDrop.pick(s, 5, owned, reversed_pool):
			same = false
	assert_true(same, "The pool order does not change the pick")


func test_pick_ignores_bad_pool_entries() -> void:
	print("\n[CASE] test_pick_ignores_bad_pool_entries")
	var pool: Array[StringName] = [&"", &"frost", &"frost"]
	var owned: Array[StringName] = [RunState.BASE_WEAPON]
	var ok := true
	for s in 10:
		if WeaponDrop.pick(s, 5, owned, pool) != &"frost":
			ok = false
	assert_true(ok, "Empty and duplicate pool ids are dropped before the draw")


func test_pick_matches_hash_seed() -> void:
	print("\n[CASE] test_pick_matches_hash_seed")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([SEED_A, "weapon", 5])
	var expected: StringName = ALL_FIVE[rng.randi_range(0, 4)]
	var owned: Array[StringName] = [RunState.BASE_WEAPON]
	assert_true(WeaponDrop.pick(SEED_A, 5, owned, GameConfig.boss_drop_weapons) == expected, "The pick follows the hashed seed over the sorted candidates")


func test_pick_uniform() -> void:
	print("\n[CASE] test_pick_uniform")
	var owned: Array[StringName] = [RunState.BASE_WEAPON]
	var counts: Dictionary = {}
	for s in 1000:
		var id := WeaponDrop.pick(s, 5, owned, GameConfig.boss_drop_weapons)
		counts[id] = int(counts.get(id, 0)) + 1
	var even := counts.size() == 5
	for id in counts:
		var n: int = counts[id]
		if n < 150 or n > 250:
			even = false
	print("  [INFO] counts: %s" % str(counts))
	assert_true(even, "Each weapon is picked about 20 percent of the time")


func test_same_seed_same_order() -> void:
	print("\n[CASE] test_same_seed_same_order")
	var first := _simulate_drops(SEED_A)
	var second := _simulate_drops(SEED_A)
	assert_true(first == second, "The same seed gives the same drop order")
	assert_true(_sorted_ids(first) == ALL_FIVE, "The five drops are the five weapons, none twice")


func test_other_seed_other_order() -> void:
	print("\n[CASE] test_other_seed_other_order")
	var orders: Dictionary = {}
	for s in range(1, 21):
		orders[str(_simulate_drops(s))] = true
	assert_true(orders.size() >= 2, "Different seeds give different orders")


# --- summary step ---

func test_wave5_drop() -> void:
	print("\n[CASE] test_wave5_drop")
	_reset_logs()
	var rs := _new_run(SEED_A)
	var wm := _new_wave_manager(5)
	_clear_boss_wave(wm, 5)
	var summary := _last_summary()
	var base_only: Array[StringName] = [RunState.BASE_WEAPON]
	var expected := WeaponDrop.pick(SEED_A, 5, base_only, GameConfig.boss_drop_weapons)
	assert_true(rs.owned_weapons.size() == 2, "The run owns two weapons")
	assert_true(not summary.is_empty() and rs.owned_weapons[1] == summary.weapon_gained, "The summary names the new weapon")
	assert_true(GameConfig.boss_drop_weapons.has(summary.get("weapon_gained", &"")), "The new weapon is from the boss pool")
	assert_true(summary.get("weapon_gained", &"") == expected, "The new weapon is the seeded pick")
	assert_true(rs.equipped_weapon == RunState.BASE_WEAPON, "The new weapon is not equipped")
	assert_true(_gained.size() == 1 and _gained[0] == expected, "weapon_gained is sent once with that id")
	assert_true(_order.find("weapon_gained") < _order.find("summary"), "weapon_gained comes before the summary")
	wm.free()
	rs.free()


func test_full_set_by_wave25() -> void:
	print("\n[CASE] test_full_set_by_wave25")
	_reset_logs()
	var rs := _new_run(SEED_A)
	var wm := _new_wave_manager(5)
	for wave in DROP_WAVES:
		_clear_boss_wave(wm, wave)
	assert_true(rs.owned_weapons.size() == 6, "The run owns all six weapons after wave 25")
	assert_true(_sorted_ids(_gained) == ALL_FIVE, "The five drops are all different")
	assert_true(_gained == _simulate_drops(SEED_A), "The drop order matches the seeded order")
	assert_true(_gained.size() == 5, "weapon_gained is sent five times")
	wm.free()
	rs.free()


func test_full_set_no_more_drop() -> void:
	print("\n[CASE] test_full_set_no_more_drop")
	_reset_logs()
	var rs := _new_run(SEED_A)
	var wm := _new_wave_manager(5)
	for wave in DROP_WAVES:
		_clear_boss_wave(wm, wave)
	_reset_logs()
	_clear_boss_wave(wm, 25)
	assert_true(_gained.is_empty(), "A full set sends no weapon_gained")
	assert_true(_last_summary().get("weapon_gained", &"x") == &"", "A full set leaves the summary key empty")
	assert_true(rs.owned_weapons.size() == 6, "A full set stays at six weapons")
	wm.free()
	rs.free()


func test_wave30_no_drop() -> void:
	print("\n[CASE] test_wave30_no_drop")
	_reset_logs()
	var rs := _new_run(SEED_A)
	var wm := _new_wave_manager(30)
	_clear_boss_wave(wm, 30)
	assert_true(_last_summary().get("weapon_gained", &"x") == &"", "Wave 30 summary key is empty")
	assert_true(rs.owned_weapons.size() == 1, "Wave 30 adds no weapon")
	assert_true(_gained.is_empty(), "Wave 30 sends no weapon_gained")
	wm.free()
	rs.free()


func test_same_seed_same_order_in_run() -> void:
	print("\n[CASE] test_same_seed_same_order_in_run")
	var first := _run_five_boss_waves(SEED_A)
	var second := _run_five_boss_waves(SEED_A)
	assert_true(first.size() == 5 and first == second, "Two runs with the same seed drop in the same order")


func test_lost_same_frame_no_drop() -> void:
	print("\n[CASE] test_lost_same_frame_no_drop")
	_reset_logs()
	var rs := _new_run(SEED_A)
	var fortress := _new_fake_fortress(0)
	var wm := _new_wave_manager(5)
	wm.start_prep()
	EventBus.boss_defeated.emit()
	wm._end_combat_to_summary()
	assert_true(rs.owned_weapons.size() == 1, "A lost wave adds no weapon")
	assert_true(_gained.is_empty(), "A lost wave sends no weapon_gained")
	assert_true(_summaries.is_empty(), "A lost wave builds no summary")
	wm.free()
	fortress.free()
	rs.free()


func test_lost_by_signal_no_drop() -> void:
	print("\n[CASE] test_lost_by_signal_no_drop")
	_reset_logs()
	var rs := _new_run(SEED_A)
	var wm := _new_wave_manager(5)
	wm.start_prep()
	EventBus.boss_defeated.emit()
	EventBus.fortress_destroyed.emit()
	wm._end_combat_to_summary()
	assert_true(rs.owned_weapons.size() == 1, "A run lost by signal adds no weapon")
	assert_true(_gained.is_empty(), "A run lost by signal sends no weapon_gained")
	wm.free()
	rs.free()


func test_enraged_boss_still_drops() -> void:
	print("\n[CASE] test_enraged_boss_still_drops")
	_reset_logs()
	var rs := _new_run(SEED_A)
	var wm := _new_wave_manager(5)
	wm.start_prep()
	EventBus.boss_enraged.emit()
	EventBus.boss_defeated.emit()
	wm._end_combat_to_summary()
	assert_true(rs.owned_weapons.size() == 2, "A boss killed after Enrage still drops a weapon")
	assert_true(_last_summary().get("weapon_gained", &"") != &"", "The summary names the weapon")
	wm.free()
	rs.free()


func test_boss_not_defeated_no_drop() -> void:
	print("\n[CASE] test_boss_not_defeated_no_drop")
	_reset_logs()
	var rs := _new_run(SEED_A)
	var wm := _new_wave_manager(5)
	wm.start_prep()
	EventBus.boss_enraged.emit()
	wm._end_combat_to_summary()
	assert_true(rs.owned_weapons.size() == 1, "A boss that is not defeated drops nothing")
	assert_true(_last_summary().get("weapon_gained", &"x") == &"", "The summary key is empty")
	assert_true(_gained.is_empty(), "No weapon_gained without a defeated boss")
	wm.free()
	rs.free()


func test_non_drop_wave_no_drop() -> void:
	print("\n[CASE] test_non_drop_wave_no_drop")
	_reset_logs()
	var rs := _new_run(SEED_A)
	var wm := _new_wave_manager(7)
	_clear_boss_wave(wm, 7)
	assert_true(_last_summary().get("weapon_gained", &"x") == &"", "A wave outside the list has an empty key")
	assert_true(rs.owned_weapons.size() == 1, "A wave outside the list adds no weapon")
	wm.free()
	rs.free()


func test_non_drop_boss_wave_key_empty() -> void:
	print("\n[CASE] test_non_drop_boss_wave_key_empty")
	_reset_logs()
	var rs := _new_run(SEED_A)
	var wm := _new_wave_manager(4)
	wm.start_prep()
	wm._end_combat_to_summary()
	var summary := _last_summary()
	assert_true(summary.has("weapon_gained") and summary.weapon_gained == &"", "The key is always present, empty without a drop")
	assert_true(typeof(summary.get("weapon_gained")) == TYPE_STRING_NAME, "The key holds a StringName")
	wm.free()
	rs.free()


func test_two_boss_signals_one_drop() -> void:
	print("\n[CASE] test_two_boss_signals_one_drop")
	_reset_logs()
	var rs := _new_run(SEED_A)
	var wm := _new_wave_manager(5)
	wm.start_prep()
	EventBus.boss_defeated.emit()
	EventBus.boss_defeated.emit()
	wm._end_combat_to_summary()
	assert_true(rs.owned_weapons.size() == 2, "Two boss deaths in one wave give one weapon")
	assert_true(_gained.size() == 1, "weapon_gained is sent once")
	wm.free()
	rs.free()


func test_late_start_no_compensation() -> void:
	print("\n[CASE] test_late_start_no_compensation")
	_reset_logs()
	var rs := _new_run(SEED_A)
	rs.start_wave = 11
	rs.waves_cleared = 10
	var wm := _new_wave_manager(15)
	_clear_boss_wave(wm, 15)
	var base_only: Array[StringName] = [RunState.BASE_WEAPON]
	var expected := WeaponDrop.pick(SEED_A, 15, base_only, GameConfig.boss_drop_weapons)
	assert_true(rs.owned_weapons.size() == 2, "A late start gets one weapon, no catch-up for waves 5 and 10")
	assert_true(_last_summary().get("weapon_gained", &"") == expected, "The weapon is the seeded pick of wave 15")
	wm.free()
	rs.free()


func test_no_run_state_no_drop() -> void:
	print("\n[CASE] test_no_run_state_no_drop")
	_reset_logs()
	var wm := _new_wave_manager(5)
	wm.start_prep()
	EventBus.boss_defeated.emit()
	wm._end_combat_to_summary()
	assert_true(_last_summary().get("weapon_gained", &"x") == &"", "Without a RunState the key is empty")
	assert_true(_gained.is_empty(), "Without a RunState no weapon_gained is sent")
	wm.free()


func test_summary_after_summary_state() -> void:
	print("\n[CASE] test_summary_after_summary_state")
	_reset_logs()
	var rs := _new_run(SEED_A)
	var wm := _new_wave_manager(5)
	_clear_boss_wave(wm, 5)
	var gained_at := _order.find("weapon_gained")
	var state_at := _order.find("SUMMARY")
	var summary_at := _order.find("summary")
	assert_true(gained_at >= 0 and gained_at < state_at and state_at < summary_at, "Order is weapon_gained, SUMMARY state, then the summary")
	wm.free()
	rs.free()


# --- Hazard Trial ---

func test_hazard_boss_gives_no_drop() -> void:
	print("\n[CASE] test_hazard_boss_gives_no_drop")
	_reset_logs()
	var rs := _new_run(SEED_A)
	var wm := _new_wave_manager(5)
	wm.wave_state = Enums.WaveState.HAZARD_TRIAL
	EventBus.boss_defeated.emit()
	assert_true(not wm._boss_defeated_this_wave, "A boss dying in the room does not mark the wave boss")
	assert_true(_deltas.is_empty(), "A boss dying in the room shows no gold number")
	wm.wave_state = Enums.WaveState.BOSS_COMBAT
	wm._end_combat_to_summary()
	var summary := _last_summary()
	assert_true(_gained.is_empty(), "No weapon_gained after a room boss")
	assert_true(summary.get("weapon_gained", &"x") == &"", "The summary key is empty after a room boss")
	assert_true(summary.get("emg_repair_gained", -1) == 0, "No repair charge after a room boss")
	assert_true(rs.owned_weapons.size() == 1, "No weapon is added after a room boss")
	wm.free()
	rs.free()


func test_hazard_boss_then_real_boss_drops() -> void:
	print("\n[CASE] test_hazard_boss_then_real_boss_drops")
	_reset_logs()
	var rs := _new_run(SEED_A)
	var wm := _new_wave_manager(5)
	wm.wave_state = Enums.WaveState.HAZARD_TRIAL
	EventBus.boss_defeated.emit()
	wm.wave_state = Enums.WaveState.BOSS_COMBAT
	EventBus.boss_defeated.emit()
	wm._end_combat_to_summary()
	assert_true(rs.owned_weapons.size() == 2, "The wave boss still drops after a room boss")
	assert_true(_gained.size() == 1, "weapon_gained is sent once")
	wm.free()
	rs.free()


# --- grant_weapon ---

func test_grant_sends_signal_once() -> void:
	print("\n[CASE] test_grant_sends_signal_once")
	_reset_logs()
	var rs := _new_run(SEED_A)
	assert_true(rs.grant_weapon(&"frost"), "A new weapon is granted")
	assert_true(_gained.size() == 1 and _gained[0] == &"frost", "weapon_gained is sent once with the id")
	rs.free()


func test_grant_owned_or_empty_no_signal() -> void:
	print("\n[CASE] test_grant_owned_or_empty_no_signal")
	_reset_logs()
	var rs := _new_run(SEED_A)
	rs.grant_weapon(&"frost")
	_gained.clear()
	var owned_again := rs.grant_weapon(&"frost")
	var empty_id := rs.grant_weapon(&"")
	var base_again := rs.grant_weapon(RunState.BASE_WEAPON)
	assert_true(not owned_again and not empty_id and not base_again, "Owned and empty ids are refused")
	assert_true(_gained.is_empty(), "A refused grant sends no weapon_gained")
	assert_true(rs.owned_weapons.size() == 2, "The weapon count is unchanged")
	rs.free()


func test_grant_does_not_equip() -> void:
	print("\n[CASE] test_grant_does_not_equip")
	_reset_logs()
	var rs := _new_run(SEED_A)
	rs.grant_weapon(&"swift")
	assert_true(rs.equipped_weapon == RunState.BASE_WEAPON, "A granted weapon is not equipped")
	assert_true(_equipped.is_empty(), "A grant sends no weapon_equipped")
	rs.free()
