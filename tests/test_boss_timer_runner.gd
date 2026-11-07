class_name TestBossTimerRunner
extends Node3D

const BULWARK_SCENE: PackedScene = preload("res://entities/enemy/bulwark.tscn")
const BULWARK_DATA: BossData = preload("res://data/bosses/bulwark_boss.tres")
const BOSS_TIMER_SCRIPT := preload("res://systems/wave/boss_timer.gd")

@export var quit_when_done: bool = true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []

var _timer: BossTimer = null
var _run_state: RunState = null
var _changed_values: Array = []
var _milestones: Array = []
var _enraged_count: Array = [0]


func assert_true(condition: bool, message: String) -> void:
	if condition:
		passes += 1
		print("  [PASS] %s" % message)
	else:
		fails += 1
		failed_names.append(message)
		print("  [FAIL] %s" % message)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("\n=======================================================")
	print("            BOSS TIMER AND ENRAGE TESTS                ")
	print("=======================================================")

	_setup()
	test_duration()
	test_intro_holds_full()
	await test_paused_stops()
	test_milestones()
	await test_enrage_once()
	await test_zero_and_death_same_frame()
	await test_boss_dies_early()
	await test_enrage_effects()
	await test_enrage_survives_phase_change()
	await test_reset_next_wave()
	_teardown()

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	if fails > 0:
		print("FAILURES:")
		for name in failed_names:
			print(" - %s" % name)
	print("=======================================================\n")

	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)


func _setup() -> void:
	_run_state = RunState.new()
	add_child(_run_state)
	_timer = BOSS_TIMER_SCRIPT.new()
	add_child(_timer)
	EventBus.boss_timer_changed.connect(_on_timer_changed)
	EventBus.boss_timer_milestone.connect(_on_milestone)
	EventBus.boss_enraged.connect(_on_enraged)


func _teardown() -> void:
	EventBus.boss_timer_changed.disconnect(_on_timer_changed)
	EventBus.boss_timer_milestone.disconnect(_on_milestone)
	EventBus.boss_enraged.disconnect(_on_enraged)
	_timer.free()
	_run_state.free()


func _on_timer_changed(t: float) -> void:
	_changed_values.append(t)


func _on_milestone(mark: int) -> void:
	_milestones.append(mark)


func _on_enraged() -> void:
	_enraged_count[0] += 1


func _clear_records() -> void:
	_changed_values.clear()
	_milestones.clear()
	_enraged_count[0] = 0


# Back to a clean PREP state, then a boss wave in combat.
func _start_boss_wave(wave: int) -> void:
	EventBus.state_changed.emit(&"PREP")
	_clear_records()
	EventBus.wave_started.emit(wave)
	EventBus.state_changed.emit(&"BOSS_COMBAT")


func _spawn_boss() -> Bulwark:
	var boss := BULWARK_SCENE.instantiate() as Bulwark
	add_child(boss)
	boss.spawn_grace = false
	return boss


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func test_duration() -> void:
	print("\n[GROUP 1] Duration per boss wave")
	_start_boss_wave(5)
	assert_true(is_equal_approx(_timer.time_left, GameConfig.get_boss_timer(1)), "test_duration: wave 5 uses the first boss timer")
	_start_boss_wave(10)
	assert_true(is_equal_approx(_timer.time_left, GameConfig.get_boss_timer(2)), "test_duration: wave 10 uses the second boss timer")
	_start_boss_wave(155)
	assert_true(is_equal_approx(_timer.time_left, GameConfig.boss_timer_max), "test_duration: late wave is capped at boss_timer_max")
	assert_true(_timer.running, "test_duration: timer runs in BOSS_COMBAT")


func test_intro_holds_full() -> void:
	print("\n[GROUP 2] Intro holds the full value")
	EventBus.state_changed.emit(&"PREP")
	_clear_records()
	EventBus.wave_started.emit(5)
	EventBus.state_changed.emit(&"BOSS_INTRO")
	var full: float = GameConfig.get_boss_timer(1)
	_timer.tick(5.0)
	assert_true(is_equal_approx(_timer.time_left, full), "test_intro_holds_full: time does not drop during BOSS_INTRO")
	assert_true(_changed_values.size() == 1 and is_equal_approx(_changed_values[0], full), "test_intro_holds_full: full value announced exactly once")
	EventBus.state_changed.emit(&"BOSS_COMBAT")
	_timer.tick(5.0)
	assert_true(is_equal_approx(_timer.time_left, full - 5.0), "test_intro_holds_full: time drops once BOSS_COMBAT starts")


func test_paused_stops() -> void:
	print("\n[GROUP 3] Paused tree stops the timer")
	_start_boss_wave(5)
	var before: float = _timer.time_left
	get_tree().paused = true
	await _wait_frames(2)
	var during: float = _timer.time_left
	get_tree().paused = false
	assert_true(is_equal_approx(during, before), "test_paused_stops: time_left unchanged while the tree is paused")
	# Positive control: the same setup unpaused must tick down.
	_start_boss_wave(5)
	var start: float = _timer.time_left
	await _wait_frames(2)
	assert_true(_timer.time_left < start, "test_paused_stops: time_left decreases when not paused")


func test_milestones() -> void:
	print("\n[GROUP 4] Milestones")
	_start_boss_wave(5)
	var guard := 0
	while _timer.time_left > 0.0 and guard < 10000:
		_timer.tick(0.25)
		guard += 1
	var expected: Array = [int(GameConfig.enrage_warn_time)]
	for s in range(int(GameConfig.enrage_countdown_time), 0, -1):
		expected.append(s)
	assert_true(_milestones == expected, "test_milestones: warn mark then countdown, each once (got %s)" % str(_milestones))


func test_enrage_once() -> void:
	print("\n[GROUP 5] Enrage fires once")
	var boss := _spawn_boss()
	_start_boss_wave(5)
	_timer.tick(_timer.time_left + 1.0)
	await _wait_frames(1)
	assert_true(_enraged_count[0] == 1, "test_enrage_once: boss_enraged emitted once")
	assert_true(_run_state.boss_enraged, "test_enrage_once: RunState.boss_enraged set")
	assert_true(_timer.enraged and boss.is_enraged, "test_enrage_once: timer and boss both enraged")
	await _wait_frames(30)
	assert_true(_enraged_count[0] == 1, "test_enrage_once: still once after 30 more frames")
	boss.free()


func test_zero_and_death_same_frame() -> void:
	print("\n[GROUP 6] Zero and death in the same frame")
	# (a) timer reaches zero, then the boss dies
	var boss := _spawn_boss()
	_start_boss_wave(5)
	_timer.tick(_timer.time_left + 1.0)
	boss._on_died()
	await _wait_frames(2)
	assert_true(_enraged_count[0] == 0, "test_zero_and_death_same_frame: zero then death does not enrage")
	boss.free()

	# (b) boss dies, then the timer reaches zero
	boss = _spawn_boss()
	_start_boss_wave(5)
	boss._on_died()
	_timer.tick(_timer.time_left + 1.0)
	await _wait_frames(2)
	assert_true(_enraged_count[0] == 0, "test_zero_and_death_same_frame: death then zero does not enrage")
	boss.free()

	# (b2) boss dead without boss_defeated being emitted: the alive guard alone must block Enrage
	boss = _spawn_boss()
	_start_boss_wave(5)
	boss.is_dead = true
	_timer.tick(_timer.time_left + 1.0)
	await _wait_frames(2)
	assert_true(_enraged_count[0] == 0, "test_zero_and_death_same_frame: dead boss without boss_defeated does not enrage")
	boss.free()

	# (c) timer reaches zero, then the fortress is destroyed
	boss = _spawn_boss()
	_start_boss_wave(5)
	_timer.tick(_timer.time_left + 1.0)
	EventBus.fortress_destroyed.emit()
	await _wait_frames(2)
	assert_true(_enraged_count[0] == 0, "test_zero_and_death_same_frame: zero then fortress loss does not enrage")
	boss.free()


func test_boss_dies_early() -> void:
	print("\n[GROUP 7] Boss dies early")
	var boss := _spawn_boss()
	_start_boss_wave(5)
	_timer.tick(_timer.time_left - 40.0)
	boss._on_died()
	assert_true(not _timer.running, "test_boss_dies_early: timer stops when the boss dies")
	var left: float = _timer.time_left
	_clear_records()
	_timer.tick(5.0)
	assert_true(is_equal_approx(_timer.time_left, left), "test_boss_dies_early: further ticks do not move the time")
	assert_true(_changed_values.is_empty() and _milestones.is_empty() and _enraged_count[0] == 0, "test_boss_dies_early: nothing is emitted after death")
	await _wait_frames(2)
	boss.free()


func test_enrage_effects() -> void:
	print("\n[GROUP 8] Enrage effects")
	var boss := _spawn_boss()
	boss.wave_speed_mult = 1.1
	boss.speed_multiplier = 1.1
	boss.wave_dmg_mult = 1.4
	boss.current_phase = Enums.BossPhase.ARMORED
	var hp_before: int = boss.health.hp
	var resist_before: float = boss.get_resist(Enums.DamageType.SLASH)
	boss.enter_enrage()
	boss.enter_enrage()
	assert_true(boss.is_enraged, "test_enrage_effects: is_enraged set")
	assert_true(is_equal_approx(boss.speed_multiplier, 1.1 * GameConfig.enrage_speed_mult), "test_enrage_effects: speed multiplied once")
	assert_true(is_equal_approx(boss._get_attack_interval(), BULWARK_DATA.attack_interval / GameConfig.enrage_attack_rate_mult), "test_enrage_effects: attack interval shortened")
	var expected_dmg: int = maxi(1, int(round(float(BULWARK_DATA.stomp_damage) * 1.4 * GameConfig.enrage_damage_mult)))
	assert_true(boss.effective_stomp_damage == expected_dmg, "test_enrage_effects: stomp damage multiplied")
	assert_true(boss.health.hp == hp_before and is_equal_approx(boss.get_resist(Enums.DamageType.SLASH), resist_before), "test_enrage_effects: HP and resist unchanged")
	await _wait_frames(2)
	boss.free()


func test_enrage_survives_phase_change() -> void:
	print("\n[GROUP 9] Enrage survives the phase change")
	var boss := _spawn_boss()
	boss.wave_speed_mult = 1.1
	boss.speed_multiplier = 1.1
	boss.current_phase = Enums.BossPhase.ARMORED
	boss.enter_enrage()
	boss._start_armor_break_transition()
	boss._transition_timer = 0.05
	var guard := 0
	while boss.current_phase != Enums.BossPhase.EXPOSED and guard < 120:
		await get_tree().physics_frame
		guard += 1
	assert_true(boss.current_phase == Enums.BossPhase.EXPOSED, "test_enrage_survives_phase_change: reached EXPOSED")
	assert_true(is_equal_approx(boss.speed_multiplier, 1.1 * BULWARK_DATA.phase2_speed_mult * GameConfig.enrage_speed_mult), "test_enrage_survives_phase_change: speed keeps both multipliers")
	var expected_interval: float = BULWARK_DATA.attack_interval / BULWARK_DATA.phase2_attack_rate_mult / GameConfig.enrage_attack_rate_mult
	assert_true(is_equal_approx(boss._get_attack_interval(), expected_interval), "test_enrage_survives_phase_change: interval keeps both multipliers")
	boss.free()


func test_reset_next_wave() -> void:
	print("\n[GROUP 10] Reset for the next boss wave")
	var boss := _spawn_boss()
	_start_boss_wave(5)
	_timer.tick(_timer.time_left + 1.0)
	await _wait_frames(3)
	assert_true(_enraged_count[0] == 1 and _timer.enraged, "test_reset_next_wave: first wave enraged")
	boss.free()
	EventBus.state_changed.emit(&"SUMMARY")
	assert_true(_run_state.boss_enraged and not _timer.running, "test_reset_next_wave: SUMMARY keeps boss_enraged readable")
	EventBus.state_changed.emit(&"PREP")
	assert_true(not _timer.enraged and not _timer.running and not _run_state.boss_enraged, "test_reset_next_wave: flags cleared after PREP")
	boss = _spawn_boss()
	_start_boss_wave(10)
	assert_true(not _timer.enraged and _timer.running, "test_reset_next_wave: next boss wave starts fresh")
	_timer.tick(_timer.time_left + 1.0)
	await _wait_frames(3)
	assert_true(_enraged_count[0] == 1, "test_reset_next_wave: enrage can fire once more")
	EventBus.state_changed.emit(&"SUMMARY")
	EventBus.wave_started.emit(15)
	assert_true(not _timer.enraged and not _run_state.boss_enraged, "test_reset_next_wave: next wave_started clears boss_enraged")
	boss.free()
