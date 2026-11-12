extends Node
## Manual test for the speed buttons and the heal station status. Not shipped.
## Speed: click x1/x2/x3.   B: BOSS_INTRO   S: SUMMARY   C: COMBAT   P: pause on/off
## Heal: 0 cycles stations 2/2, 1/2, 0/0   H: hold then heal (game time, try at x3)
##       X: cancel   D: depleted   J: hit   F: full HP on/off   M: Commander mode on/off
## The fake channel follows the real one: no hold in Commander mode, outside combat or
## at full HP; mode switch and hits cancel; full HP ends healing as IDLE.

const MAX_HP := 200
## About 20 HP per second of game time, like a base heal rate.
const HEAL_PER_TICK := 2

var _stations_step := 0
var _full := false
var _commander := false
var _wave_state: StringName = &"PREP"
var _phase: StringName = &"IDLE"
var _hp := 150
var _counts := [2, 2]
var _progress := 0.0
var _next_status := 0.0

func _ready() -> void:
	await get_tree().process_frame
	EventBus.commander_hp_changed.emit(_hp, MAX_HP)
	EventBus.state_changed.emit(&"PREP")
	_publish_status()

func _process(_delta: float) -> void:
	if TimeManager.real_time >= _next_status:
		_publish_status()

func _publish_status() -> void:
	_next_status = TimeManager.real_time + 0.1
	var reason: StringName = &""
	if _commander:
		reason = &"COMMANDER_MODE"
	elif _wave_state not in [&"COMBAT", &"BOSS_COMBAT"]:
		reason = &"WAVE_STATE"
	elif TimeManager.is_paused:
		reason = &"PAUSED"
	elif _full:
		reason = &"FULL_HP"
	elif _counts[0] == 0:
		reason = &"DEPLETED"
	EventBus.heal_status_updated.emit(_phase, reason, _progress,
		1.0 - _progress if _phase == &"HOLD" else 0.0,
		10.0 * HEAL_PER_TICK, _counts[0], _counts[1])

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_B:
			_wave(&"BOSS_INTRO")
		KEY_S:
			_wave(&"SUMMARY")
		KEY_C:
			_wave(&"COMBAT")
		KEY_P:
			if TimeManager.is_paused:
				TimeManager.release_pause(TimeManager.REASON_USER)
			else:
				TimeManager.request_pause(TimeManager.REASON_USER)
				_cancel_channel()
		KEY_0:
			_stations_step = (_stations_step + 1) % 3
			var counts := [[2, 2], [1, 2], [0, 0]]
			_counts = counts[_stations_step]
			_publish_status()
		KEY_H:
			_hold_then_heal()
		KEY_X:
			_cancel_channel()
		KEY_D:
			_send_heal(&"DEPLETED", 0.0)
		KEY_J:
			_set_hp(maxi(_hp - 30, 1))
			_cancel_channel()
		KEY_F:
			_set_hp(MAX_HP if _hp < MAX_HP else 150)
			# Full HP ends the channel quietly, not as a cancel.
			if _full and _phase != &"IDLE":
				_send_heal(&"IDLE", 0.0)
		KEY_M:
			_commander = not _commander
			EventBus.mode_changed.emit(&"COMMANDER" if _commander else &"FRONTLINE")
			_cancel_channel()

func _wave(state: StringName) -> void:
	_wave_state = state
	if state not in [&"COMBAT", &"BOSS_COMBAT"]:
		_cancel_channel()
	print("[test] state -> %s" % state)
	# Mirrors the wave FSM: these states reset the speed to x1.
	if state == &"BOSS_INTRO" or state == &"SUMMARY":
		TimeManager.reset_time_scale()
	EventBus.state_changed.emit(state)

## Same gate as the heal channel: no hold in Commander mode, outside combat or at full HP.
func _can_hold() -> bool:
	return not _commander and not _full and not TimeManager.is_paused \
		and _counts[0] > 0 and _wave_state in [&"COMBAT", &"BOSS_COMBAT"]

## Hold progress and healing tick on game time, so both finish sooner at x2 and x3.
func _hold_then_heal() -> void:
	if _phase != &"IDLE" or not _can_hold():
		print("[test] hold refused, as the heal channel would")
		return
	for i in 11:
		_send_heal(&"HOLD", i / 10.0)
		await TimeManager.wait_game(0.1)
		# Stopped by X, J, M or F while waiting.
		if _phase != &"HOLD":
			return
	_send_heal(&"HEALING", 1.0)
	while _hp < MAX_HP:
		await TimeManager.wait_game(0.1)
		if _phase != &"HEALING":
			return
		_set_hp(mini(_hp + HEAL_PER_TICK, MAX_HP))
	# Full HP: the channel ends by itself and reports IDLE.
	_send_heal(&"IDLE", 0.0)

func _set_hp(hp: int) -> void:
	_hp = hp
	_full = _hp >= MAX_HP
	EventBus.commander_hp_changed.emit(_hp, MAX_HP)

## Like the channel's cancel(): only a running hold or heal is reported.
func _cancel_channel() -> void:
	if _phase != &"IDLE":
		_send_heal(&"CANCELLED", 0.0)

func _send_heal(state: StringName, progress: float) -> void:
	_phase = state if state == &"HOLD" or state == &"HEALING" else &"IDLE"
	_progress = progress
	EventBus.heal_state_changed.emit(state, &"G_1_1", progress)
	_publish_status()
