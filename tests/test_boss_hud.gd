extends Node
## Drives the boss HUD with fake EventBus signals. Press F6 on this scene.
## 1: boss intro card. 2: boss fight starts (bar, armor phase immunities). 3: hit the armor.
## 4: armor breaks, core exposed. 5: hit the core. T: run the timer from 35 s to 0, then enrage.
## D: boss defeated. P: back to PREP.

var _countdown := false

func _ready() -> void:
	# Keys and the fake timer must work while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	EventBus.run_started.emit()
	EventBus.wave_started.emit(5)
	EventBus.state_changed.emit(&"PREP")

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			EventBus.state_changed.emit(&"BOSS_INTRO")
			EventBus.boss_intro_started.emit(&"bulwark")
			EventBus.boss_timer_changed.emit(90.0)
		KEY_2:
			EventBus.state_changed.emit(&"BOSS_COMBAT")
			EventBus.boss_spawned.emit()
			EventBus.boss_hp_changed.emit(1200, 900, &"ARMORED")
			EventBus.boss_phase_changed.emit(&"ARMORED")
		KEY_3:
			EventBus.boss_hp_changed.emit(500, 900, &"ARMORED")
		KEY_4:
			_break_armor()
		KEY_5:
			EventBus.boss_hp_changed.emit(0, 350, &"EXPOSED")
		KEY_T:
			_run_timer()
		KEY_D:
			_countdown = false
			EventBus.boss_defeated.emit()
		KEY_P:
			_countdown = false
			EventBus.state_changed.emit(&"PREP")

## Armor gone: a short transition, then the core is exposed and nothing is immune any more.
func _break_armor() -> void:
	EventBus.boss_phase_changed.emit(&"TRANSITION")
	EventBus.boss_hp_changed.emit(0, 900, &"TRANSITION")
	await get_tree().create_timer(1.0).timeout
	EventBus.boss_phase_changed.emit(&"EXPOSED")
	EventBus.boss_hp_changed.emit(0, 900, &"EXPOSED")

## Counts down fast in real time: plain, yellow with an icon at 30 s, red and larger at 10 s.
func _run_timer() -> void:
	_countdown = true
	var left := 35.0
	while _countdown and left > 0.0:
		EventBus.boss_timer_changed.emit(left)
		await get_tree().create_timer(0.25).timeout
		left -= 1.0
	if _countdown:
		EventBus.boss_timer_changed.emit(0.0)
		EventBus.boss_enraged.emit()
	_countdown = false
