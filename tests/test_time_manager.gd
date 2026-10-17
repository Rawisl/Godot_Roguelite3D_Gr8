extends Node
## Manual test for TimeManager. Not shipped. Run with F6, prints OK/FAIL per case then quits.

var _pass := 0
var _fail := 0
var _scale_signals: Array[int] = []
var _pause_signals: Array[bool] = []

func _ready() -> void:
	EventBus.time_scale_changed.connect(func(s: int): _scale_signals.append(s))
	EventBus.pause_changed.connect(func(p: bool): _pause_signals.append(p))
	await _run()
	TimeManager.reset()
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func _run() -> void:
	TimeManager.reset()
	_scale_signals.clear()
	_pause_signals.clear()

	# Speed buttons.
	_check("starts at x1", TimeManager.get_time_scale() == 1 and Engine.time_scale == 1.0)
	TimeManager.toggle_time_scale(2)
	_check("x2 on", TimeManager.get_time_scale() == 2 and Engine.time_scale == 2.0)
	TimeManager.toggle_time_scale(2)
	_check("x2 again -> x1", TimeManager.get_time_scale() == 1)
	TimeManager.toggle_time_scale(2)
	TimeManager.toggle_time_scale(3)
	_check("x2 then x3 switches straight to x3", TimeManager.get_time_scale() == 3)
	TimeManager.toggle_time_scale(1)
	_check("x1 button always -> x1", TimeManager.get_time_scale() == 1)
	_check("rejects x0 and x4", not TimeManager.set_time_scale(0) and not TimeManager.set_time_scale(4))
	_check("time_scale_changed only on real change", _scale_signals == [2, 1, 2, 3, 1])

	# Pause is its own state and blocks speed changes.
	TimeManager.request_pause(TimeManager.REASON_USER)
	_check("paused", TimeManager.is_paused and get_tree().paused)
	_check("time_scale untouched by pause", Engine.time_scale == 1.0)
	_check("speed change refused while paused", not TimeManager.set_time_scale(3))

	# Several pause reasons at once.
	TimeManager.request_pause(TimeManager.REASON_REWARD_PICK)
	TimeManager.release_pause(TimeManager.REASON_USER)
	_check("still paused after USER released (REWARD_PICK left)", TimeManager.is_paused)
	TimeManager.release_pause(TimeManager.REASON_REWARD_PICK)
	_check("resumed when last reason released", not TimeManager.is_paused and not get_tree().paused)
	_check("pause_changed only on real change", _pause_signals == [true, false])
	TimeManager.request_pause(&"BOGUS")
	_check("unknown reason ignored", not TimeManager.is_paused)

	# The three clocks, x3 for 0.5 s of real time.
	TimeManager.reset()
	TimeManager.set_time_scale(3)
	var g0 := TimeManager.game_time
	var p0 := TimeManager.pausable_real_time
	var r0 := TimeManager.real_time
	await TimeManager.wait_real(0.5)
	var dg := TimeManager.game_time - g0
	var dp := TimeManager.pausable_real_time - p0
	var dr := TimeManager.real_time - r0
	_check("x3: game time ~3x real (%.2f vs %.2f)" % [dg, dr], absf(dg - 3.0 * dr) < 0.15)
	_check("x3: pausable real time ~ real (%.2f vs %.2f)" % [dp, dr], absf(dp - dr) < 0.05)

	# Pause freezes game time and pausable real time, not real time.
	TimeManager.reset_time_scale()
	TimeManager.request_pause(TimeManager.REASON_USER)
	g0 = TimeManager.game_time
	p0 = TimeManager.pausable_real_time
	r0 = TimeManager.real_time
	await TimeManager.wait_real(0.3)
	_check("pause: game time frozen", is_equal_approx(TimeManager.game_time, g0))
	_check("pause: pausable real time frozen", is_equal_approx(TimeManager.pausable_real_time, p0))
	_check("pause: real time keeps running", TimeManager.real_time - r0 > 0.25)

	# wait_game / wait_pausable_real do not fire while paused, fire after resume.
	var fired := [false, false]
	TimeManager.wait_game(0.2).connect(func(): fired[0] = true)
	TimeManager.wait_pausable_real(0.2).connect(func(): fired[1] = true)
	await TimeManager.wait_real(0.4)
	_check("timers frozen during pause", not fired[0] and not fired[1])
	TimeManager.release_pause(TimeManager.REASON_USER)
	await TimeManager.wait_real(0.4)
	_check("timers fire after resume", fired[0] and fired[1])

	# Game timer follows time_scale (0.6 game s at x3 is about 0.2 real s).
	TimeManager.set_time_scale(3)
	var t0 := TimeManager.real_time
	await TimeManager.wait_game(0.6)
	var took := TimeManager.real_time - t0
	_check("wait_game(0.6) at x3 took %.2f real s (expect ~0.2)" % took, absf(took - 0.2) < 0.1)

	# reset() when leaving a run.
	TimeManager.request_pause(TimeManager.REASON_REWARD_PICK)
	TimeManager.reset()
	_check("reset clears pause, speed and clocks",
			not TimeManager.is_paused and TimeManager.get_time_scale() == 1
			and TimeManager.game_time == 0.0)

func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("[test] %s %s" % [label, "OK" if ok else "FAIL"])
