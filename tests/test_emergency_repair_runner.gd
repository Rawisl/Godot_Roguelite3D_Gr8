extends Node
## F6 acceptance scene for Emergency repair: charges, cooldown, refusals, boss refund and UI signals.
## Prints PASS/FAIL then quits.

const FORTRESS_SCENE: PackedScene = preload("res://entities/fortress/fortress.tscn")
const COMMANDER_SCENE: PackedScene = preload("res://entities/commander/commander.tscn")

var passes: int = 0
var fails: int = 0

var _commander: CharacterBody3D
var _repair: EmergencyRepair
var _fortress: Fortress
var _denied: Array[StringName] = []
var _states: Array = []
var _cooldowns: Array = []
var _granted: Array[int] = []
var _repaired: Array = []


func _ready() -> void:
	print("\n=======================================================")
	print("          EMERGENCY REPAIR VERIFICATION                  ")
	print("=======================================================")

	_fortress = FORTRESS_SCENE.instantiate()
	add_child(_fortress)
	_commander = COMMANDER_SCENE.instantiate()
	add_child(_commander)
	_commander.set_physics_process(false)
	_repair = _commander.get_node("EmergencyRepair")
	EventBus.emergency_repair_denied.connect(func(reason: StringName) -> void: _denied.append(reason))
	EventBus.emergency_repair_state_changed.connect(func(c: int, cd: float, pct: float) -> void: _states.append([c, cd, pct]))
	EventBus.skill_cooldown_changed.connect(func(id: StringName, left: float, total: float) -> void:
		if id == &"emg_repair":
			_cooldowns.append([left, total]))
	EventBus.emergency_repair_charge_granted.connect(func(c: int) -> void: _granted.append(c))
	EventBus.fortress_repaired.connect(func(amount: int, source: StringName) -> void: _repaired.append([amount, source]))
	await get_tree().process_frame

	test_start_state()
	test_refusals()
	test_use_and_cooldown()
	test_overheal()
	test_exhausted()
	test_boss_refund()
	test_run_reset_and_bonus()
	await test_key_press()
	await test_cooldown_time_scale()

	print("=======================================================")
	print("EMERGENCY REPAIR TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================")
	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


func _fresh(hp: int, commander_mode: bool = true) -> void:
	_denied.clear()
	_states.clear()
	_cooldowns.clear()
	_granted.clear()
	_repaired.clear()
	_repair.reset()
	_fortress.health.hp = hp
	EventBus.mode_changed.emit(&"COMMANDER" if commander_mode else &"FRONTLINE")


func test_start_state() -> void:
	print("\n[GROUP 1] A run starts at 3/3 with no cooldown")
	_fresh(500)
	assert_true(_repair.charges == 3, "3 charges")
	assert_true(is_equal_approx(_repair.get_cooldown_left(), 0.0), "no cooldown")
	assert_true(_states.size() == 1 and _states[0] == [3, 0.0, 0.2], "state signal (3, 0, 0.2) sent on reset")
	assert_true(GameConfig.emg_repair_charges_max == 3 and is_equal_approx(GameConfig.emergency_repair_cooldown, 60.0), "constants: 3 charges, 60 s")


func test_refusals() -> void:
	print("\n[GROUP 2] Refusals cost nothing and say why")
	_fresh(500, false)
	assert_true(_repair.try_use() == 0 and _denied == [EmergencyRepair.REASON_NOT_COMMANDER], "Frontline: refused, reason NOT_COMMANDER")
	assert_true(_fortress.get_hp() == 500 and _repair.charges == 3 and _repair.get_cooldown_left() == 0.0, "Frontline: no HP, charge or cooldown change")

	_fresh(1000)
	assert_true(_repair.try_use() == 0 and _denied == [EmergencyRepair.REASON_FORTRESS_FULL], "Full HP: refused, reason FORTRESS_FULL")
	assert_true(_repair.charges == 3 and _repair.get_cooldown_left() == 0.0, "Full HP: no charge spent, no cooldown")
	assert_true(_states.size() == 1 and _cooldowns.size() == 1, "Full HP: no state or cooldown update beyond the reset")

	_fresh(500)
	TimeManager.request_pause(TimeManager.REASON_USER)
	assert_true(_repair.try_use() == 0 and _denied == [EmergencyRepair.REASON_PAUSED], "Paused: refused, reason PAUSED")
	assert_true(_repair.charges == 3 and _fortress.get_hp() == 500, "Paused: nothing spent")
	TimeManager.release_pause(TimeManager.REASON_USER)

	_fresh(500, false)
	TimeManager.request_pause(TimeManager.REASON_USER)
	_repair.try_use()
	assert_true(_denied == [EmergencyRepair.REASON_PAUSED], "Paused wins over the Frontline reason")
	TimeManager.release_pause(TimeManager.REASON_USER)


func test_use_and_cooldown() -> void:
	print("\n[GROUP 3] First use: 2/3, 20% heal, 60 s cooldown")
	_fresh(500)
	var healed: int = _repair.try_use()
	assert_true(healed == 200 and _fortress.get_hp() == 700, "heals exactly 20%% of 1000: 500 -> 700")
	assert_true(_repair.charges == 2, "charges 2/3")
	assert_true(is_equal_approx(_repair.get_cooldown_left(), 60.0), "cooldown 60 s")
	assert_true(_states.back() == [2, 60.0, 0.2], "state signal (2, 60, 0.2)")
	assert_true(_cooldowns.back() == [60.0, 60.0], "skill_cooldown_changed(emg_repair, 60, 60)")
	assert_true(_repaired == [[200, &"EMERGENCY"]], "fortress_repaired reports the EMERGENCY source")

	_denied.clear()
	assert_true(_repair.try_use() == 0 and _denied == [EmergencyRepair.REASON_COOLDOWN], "second press: refused, reason COOLDOWN")
	assert_true(_repair.charges == 2 and is_equal_approx(_repair.get_cooldown_left(), 60.0), "refusal keeps the charge and the cooldown")


func test_overheal() -> void:
	print("\n[GROUP 4] Healing more than is missing still costs a charge and a cooldown")
	_fresh(950)
	var healed: int = _repair.try_use()
	assert_true(healed == 50 and _fortress.get_hp() == 1000, "clamped at max HP: 950 -> 1000")
	assert_true(_repair.charges == 2 and is_equal_approx(_repair.get_cooldown_left(), 60.0), "charge and cooldown spent")


func test_exhausted() -> void:
	print("\n[GROUP 5] 0/3 locks the key even with the cooldown at 0")
	_fresh(100)
	for i in 3:
		_repair._cooldown_left = 0.0
		assert_true(_repair.try_use() > 0, "use %d works" % (i + 1))
	assert_true(_repair.charges == 0, "0/3 after three uses")
	_repair._cooldown_left = 0.0
	_fortress.health.hp = 100
	_denied.clear()
	assert_true(_repair.try_use() == 0 and _denied == [EmergencyRepair.REASON_NO_CHARGES], "locked: reason NO_CHARGES")
	_repair._cooldown_left = 30.0
	_denied.clear()
	_repair.try_use()
	assert_true(_denied == [EmergencyRepair.REASON_NO_CHARGES], "no charges wins over cooldown")


func test_boss_refund() -> void:
	print("\n[GROUP 6] +1 charge when the boss dies and the wave reaches SUMMARY")
	_fresh(500)
	_repair.charges = 0
	_repair._cooldown_left = 42.0
	EventBus.boss_defeated.emit()
	assert_true(_repair.charges == 0, "nothing yet when the boss dies")
	EventBus.wave_cleared.emit(5)
	assert_true(_repair.charges == 1 and _granted == [1], "wave cleared with a dead boss: 1/3 and charge_granted(1)")
	assert_true(is_equal_approx(_repair._cooldown_left, 42.0), "the bonus charge leaves the cooldown alone")
	EventBus.wave_cleared.emit(6)
	assert_true(_repair.charges == 1, "a normal wave gives nothing")
	EventBus.wave_cleared.emit(7)
	assert_true(_repair.charges == 1, "the refund is used up after one wave")

	EventBus.boss_defeated.emit()
	EventBus.wave_started.emit(8)
	EventBus.wave_cleared.emit(8)
	assert_true(_repair.charges == 1, "a boss flag from an earlier wave does not carry over")

	EventBus.boss_defeated.emit()
	# GameState also listens to run_ended and would warn about the state jump, so it sits this one out.
	EventBus.run_ended.disconnect(GameState._on_run_ended)
	EventBus.run_ended.emit(&"FORTRESS_DESTROYED", {})
	EventBus.run_ended.connect(GameState._on_run_ended)
	EventBus.wave_cleared.emit(9)
	assert_true(_repair.charges == 1, "no refund when the run ended in that wave")

	_repair.charges = 2
	EventBus.boss_defeated.emit()
	EventBus.wave_cleared.emit(10)
	assert_true(_repair.charges == 3, "2/3 becomes 3/3")
	_granted.clear()
	EventBus.boss_defeated.emit()
	EventBus.wave_cleared.emit(15)
	assert_true(_repair.charges == 3 and _granted.is_empty(), "3/3 stays 3/3, the spare charge is lost")


func test_run_reset_and_bonus() -> void:
	print("\n[GROUP 7] New run resets; meta bonus raises only the heal")
	_repair.charges = 0
	_repair._cooldown_left = 20.0
	EventBus.run_started.emit()
	assert_true(_repair.charges == 3 and _repair.get_cooldown_left() == 0.0, "run_started: back to 3/3, cooldown 0")
	_repair.heal_bonus_pct = 0.09
	_fortress.health.hp = 500
	assert_true(is_equal_approx(_repair.get_heal_pct(), 0.29), "bonus 0.09 gives 29%")
	assert_true(_repair.try_use() == 290, "heals 290 of 1000 at 29%")
	assert_true(_repair.charges == 2 and is_equal_approx(_repair.get_cooldown_left(), 60.0), "charges and cooldown are unchanged by the bonus")
	_repair.heal_bonus_pct = 0.0


func test_key_press() -> void:
	print("\n[GROUP 8] The R action reaches the node")
	_fresh(500)
	var event := InputEventAction.new()
	event.action = &"emergency_repair"
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(_repair.charges == 2 and _fortress.get_hp() == 700, "pressing R in Commander mode repairs")

	_fresh(500, false)
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(_repair.charges == 3 and _denied == [EmergencyRepair.REASON_NOT_COMMANDER], "pressing R in Frontline is refused")


func test_cooldown_time_scale() -> void:
	print("\n[GROUP 9] Cooldown follows game time: x1, x2, x3 and Pause")
	await TimeManager.wait_real(0.3)
	for scale in [1, 2, 3]:
		_fresh(500)
		TimeManager.set_time_scale(scale)
		_repair._cooldown_left = 60.0
		_repair._last_game_time = TimeManager.game_time
		var start: float = TimeManager.game_time
		await TimeManager.wait_real(0.8)
		var game_elapsed: float = TimeManager.game_time - start
		var used: float = 60.0 - _repair.get_cooldown_left()
		assert_true(absf(used - game_elapsed) < 0.2 and used > 0.7 * scale, "x%d: cooldown used %.2f s of game time %.2f s" % [scale, used, game_elapsed])

	TimeManager.set_time_scale(1)
	_fresh(500)
	_repair._cooldown_left = 60.0
	_repair._last_game_time = TimeManager.game_time
	TimeManager.request_pause(TimeManager.REASON_USER)
	await TimeManager.wait_real(0.5)
	assert_true(is_equal_approx(_repair.get_cooldown_left(), 60.0), "Pause freezes the cooldown")
	TimeManager.release_pause(TimeManager.REASON_USER)

	_repair._cooldown_left = 0.5
	_repair._last_game_time = TimeManager.game_time
	await TimeManager.wait_real(0.8)
	assert_true(_repair.get_cooldown_left() == 0.0 and _cooldowns.back()[0] == 0.0, "cooldown ends at 0 and reports it")
	TimeManager.reset()
