extends Node
## Boss HUD with fake EventBus signals. Press F6 on this scene: the checks below run first and
## print a summary, then the keys replay each step by hand.
## 1: boss intro card. 2: boss fight starts (bar, armor phase immunities). 3: hit the armor.
## 4: armor breaks, core exposed. 5: hit the core. T: run the timer from 35 s to 0, then enrage.
## D: boss defeated. P: back to PREP.

var _countdown := false
var _passed := 0
var _failed := 0

func _ready() -> void:
	# Keys and the fake timer must work while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	EventBus.run_started.emit()
	EventBus.wave_started.emit(5)
	_run_checks()
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

## Counts down fast in real time: plain, then the warning colour with an icon, then red and larger.
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


## Signals are handled on the spot, so every check reads the HUD right after the emit.
func _run_checks() -> void:
	var bar := get_tree().root.find_child("BossBar", true, false) as Control
	var intro := get_tree().root.find_child("BossIntro", true, false) as Control
	_check(bar != null and intro != null, "boss bar and intro card are in the HUD")
	if bar == null or intro == null:
		return
	var timer := bar.get_node("%Timer") as Label
	var icon := bar.get_node("%TimerIcon") as TextureRect
	var armor := bar.get_node("%ArmorBar") as ProgressBar
	var core := bar.get_node("%CoreBar") as ProgressBar
	var resist_row := bar.get_node("%ResistRow") as Control
	var header := bar.get_node("Body/Header") as Control

	EventBus.state_changed.emit(&"BOSS_INTRO")
	EventBus.boss_intro_started.emit(&"bulwark")
	EventBus.boss_timer_changed.emit(90.0)
	_check(intro.visible, "intro card shows in BOSS_INTRO")
	_check((intro.get_node("%BossName") as Label).text == tr(&"enemy.bulwark"), "intro card names the boss")
	_check((intro.get_node("%Immune") as Label).text != "", "intro card lists the armor phase immunities")
	_check(bar.visible and timer.text == "01:30", "timer stands still at the full time in the intro")
	_check(not (bar.get_node("%Bars") as Control).visible, "no HP bar before the boss spawns")

	EventBus.state_changed.emit(&"BOSS_COMBAT")
	EventBus.boss_spawned.emit()
	EventBus.boss_hp_changed.emit(1200, 900, &"ARMORED")
	_check(not intro.visible, "intro card hides in BOSS_COMBAT")
	_check(armor.max_value == 1200 and core.max_value == 900, "armor and core segments take their full values")
	_check(resist_row.visible, "armor phase shows the immunity line")
	EventBus.boss_hp_changed.emit(500, 900, &"ARMORED")
	_check(armor.value == 500 and core.value == 900, "a hit on the armor lowers only the armor segment")

	var header_height := header.get_combined_minimum_size().y
	EventBus.boss_timer_changed.emit(45.0)
	_check(not icon.visible and not timer.has_theme_color_override(&"font_color"), "45 s: plain timer, no icon")
	# TODO(WhoKeng): drop this skip once enrage_warn_time and enrage_countdown_time are in GameConfig on main.
	if GameConfig.get(&"enrage_warn_time") == null:
		print("  [SKIP] timer colours: GameConfig has no enrage_warn_time yet")
	else:
		EventBus.boss_timer_changed.emit(25.0)
		_check(icon.visible and timer.get_theme_color(&"font_color") == bar.get(&"warn_color"), "25 s: warning colour and icon")
		EventBus.boss_timer_changed.emit(8.0)
		_check(timer.get_theme_color(&"font_color") == bar.get(&"danger_color")
			and timer.get_theme_font_size(&"font_size") == bar.get(&"danger_font_size"), "8 s: red and larger")
		_check(is_equal_approx(header.get_combined_minimum_size().y, header_height), "the larger timer does not grow the box")

	EventBus.boss_phase_changed.emit(&"EXPOSED")
	EventBus.boss_hp_changed.emit(0, 900, &"EXPOSED")
	_check(not resist_row.visible, "exposed core: no immunity line")
	EventBus.boss_timer_changed.emit(0.0)
	EventBus.boss_enraged.emit()
	EventBus.boss_timer_changed.emit(0.0)
	_check(timer.text == tr(&"hud.boss.enraged") and icon.visible, "ENRAGED tag with its icon, kept after 0")
	EventBus.boss_defeated.emit()
	_check(not bar.visible, "the bar hides when the boss dies")
	print("[test_boss_hud] %d passed, %d failed" % [_passed, _failed])

func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("[test_boss_hud] FAIL: " + label)
