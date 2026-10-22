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

var _heal: Node
var _stations_step := 0
var _full := false
var _commander := false
var _wave_state: StringName = &"PREP"
var _phase: StringName = &"IDLE"
var _hp := 150

func _ready() -> void:
	_heal = $Hud.find_child("HealStatus", true, false)
	await get_tree().process_frame
	EventBus.commander_hp_changed.emit(_hp, MAX_HP)
	EventBus.state_changed.emit(&"PREP")
	_heal.set_stations(2, 2)

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
		KEY_0:
			_stations_step = (_stations_step + 1) % 3
			var counts := [[2, 2], [1, 2], [0, 0]]
			_heal.set_stations(counts[_stations_step][0], counts[_stations_step][1])
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
	print("[test] state -> %s" % state)
	# Mirrors the wave FSM: these states reset the speed to x1.
	if state == &"BOSS_INTRO" or state == &"SUMMARY":
		TimeManager.reset_time_scale()
	EventBus.state_changed.emit(state)

## Same gate as the heal channel: no hold in Commander mode, outside combat or at full HP.
func _can_hold() -> bool:
	return not _commander and not _full and _wave_state in [&"COMBAT", &"BOSS_COMBAT"]

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

## Fake heal_state_changed: emitted for real once the signal is on main.
func _send_heal(state: StringName, progress: float) -> void:
	_phase = state if state == &"HOLD" or state == &"HEALING" else &"IDLE"
	if EventBus.has_signal(&"heal_state_changed"):
		EventBus.emit_signal(&"heal_state_changed", state, &"G_1_1", progress)
	else:
		_heal.show_heal_state(state, &"G_1_1", progress)
