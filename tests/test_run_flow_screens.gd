extends Control
## RunEnd, victory screen, wave summary and pause menu with fake run data. Press F6: the checks run
## first and print a summary, then click the window once and use the keys:
## 1: RunEnd, defeat at wave 7. 2: RunEnd, survived to wave 34 with a new record.
## 3: victory screen after wave 30. 4: wave summary with low Fortress and no Mithril, a weapon drop
## and a Hazard Trial done. 5: the same summary with Mithril. 6: pause menu at wave 12.
## 7: pause menu, Abandon pressed (the dialog names the wave and the prestige; Esc closes it).
## 8: Fortress bar at 25% in PREP without Mithril (Hazard Trial hint). 9: the same with Mithril.

var _passed := 0
var _failed := 0
var _continue_count := 0

@onready var _run_end: Control = $RunEnd
@onready var _victory: VictoryScreen = $VictoryScreen
@onready var _summary: SummaryPanel = $SummaryPanel
@onready var _pause: Control = $PauseMenu
@onready var _fortress_bar: Control = $FortressBar

func _ready() -> void:
	EventBus.victory_continue_requested.connect(func() -> void: _continue_count += 1)
	await get_tree().process_frame
	await _run_checks()
	print("test_run_flow_screens: %d passed, %d failed" % [_passed, _failed])
	_only(_run_end)
	_run_end.show_summary(&"FORTRESS_DESTROYED", _defeat(), 340)

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_only(_run_end)
			_run_end.show_summary(&"FORTRESS_DESTROYED", _defeat(), 340)
		KEY_2:
			_only(_run_end)
			_run_end.show_summary(&"COMMANDER_DIED", _survived(), 1210)
		KEY_3:
			_only(_victory)
			_victory.show_stats(30, _victory_stats())
		KEY_4:
			_only(_summary)
			_show_summary(0)
		KEY_5:
			_only(_summary)
			_show_summary(3)
		KEY_6:
			_only(_pause)
			_pause.show_run_info({"wave_index": 12, "run_elapsed": 125.0})
		KEY_7:
			_only(_pause)
			_pause.show_run_info({"wave_index": 12, "run_elapsed": 125.0, "prestige_gain": 48, "victory_reached": false})
			_pause._abandon.pressed.emit()
		KEY_8:
			_only(_fortress_bar)
			_show_low_fortress_prep(0)
		KEY_9:
			_only(_fortress_bar)
			_show_low_fortress_prep(3)

func _run_checks() -> void:
	_check_run_end()
	await _check_victory()
	_check_summary()
	_check_fortress_bar()
	await _check_pause()

func _check_run_end() -> void:
	_run_end.show_summary(&"FORTRESS_DESTROYED", _defeat(), 340)
	_expect(_run_end._result.text == UiFormat.tr_fmt(&"run_end.result.defeat", {"wave": 7}), "run end: defeat names the wave it ended on")
	_expect(_run_end._cause.text == UiFormat.tr_fmt(&"run_end.cause", {"cause": tr(&"run_end.type.fortress_destroyed")}), "run end: the defeat reason shows under the result")
	_expect(not _run_end._victory_badge.visible and not _run_end._record_badge.visible, "run end: a defeat has no victory or record tag")
	_expect(_value(_run_end._gain) == UiFormat.tr_fmt(&"summary.value.plus", {"value": 12}), "run end: prestige gain shows")
	_expect(_value(_run_end._balance) == "340", "run end: the new balance comes from the save")
	_expect(_value(_run_end._collected) == UiFormat.tr_fmt(&"run_end.value.collected",
		{"pending": 30, "buffer": 8, "ratio": UiFormat.num(GameConfig.prestige_buffer_ratio * 100.0)}), "run end: collected prestige counts the unfinished wave")
	_expect(not _run_end._top_tower.visible and not _run_end._unlocks.visible, "run end: rows without data stay hidden")

	_run_end.show_summary(&"COMMANDER_DIED", _survived(), 1210)
	_expect(_run_end._result.text == UiFormat.tr_fmt(&"run_end.result.survived", {"wave": 34}), "run end: survived names the wave reached")
	_expect(_run_end._victory_badge.visible and _run_end._record_badge.visible, "run end: survived shows the victory and record tags")
	_expect(_value(_run_end._top_tower) == UiFormat.tr_fmt(&"run_end.value.top_tower",
		{"name": tr(&"tower.cannon"), "damage": 9000}), "run end: the top tower skips Barricade")
	_expect(_run_end._unlocks.visible, "run end: new start waves show")

	_run_end.show_summary(&"", {}, -1)
	_expect(not _run_end._waves.visible and not _run_end._balance.visible and _run_end._rate.visible, "run end: an empty summary only keeps the config rows")

func _check_victory() -> void:
	_continue_count = 0
	_victory.show_stats(30, _victory_stats())
	_expect(_victory.visible and _victory._continue.has_focus(), "victory: shows with Continue focused")
	_expect(_value(_victory._weapons) == ", ".join([tr(&"weapon.sword_base.name"), tr(&"weapon.frost.name")]), "victory: weapons owned are named")
	_victory._continue.pressed.emit()
	_victory._continue.pressed.emit()
	_expect(_continue_count == 1 and not _victory.visible, "victory: Continue is sent once and the screen closes")
	EventBus.run_victory.emit(30, _victory_stats())
	await get_tree().process_frame
	_expect(_victory.visible, "victory: run_victory opens the screen")
	_expect(_victory._weapons.visible, "victory: the signal carries the owned weapons")
	_victory._continue.pressed.emit()

func _check_summary() -> void:
	_show_summary(0)
	_expect(_summary._fortress_hint.visible and _summary._fortress_hint.text == tr(&"summary.fortress_hint_hazard"),
		"summary: low Fortress without Mithril points to the Hazard Trial")
	_expect(_summary._weapon.visible and _value(_summary._weapon) == tr(&"weapon.frost.name"), "summary: the dropped weapon is named")
	_expect(_summary._hazard_note.visible, "summary: the Hazard Trial note shows after a trial")
	_expect(_value_color(_summary._fortress) == _summary.fortress_low_color, "summary: a low Fortress value takes the hint colour")
	_show_summary(3)
	_expect(_summary._fortress_hint.text == tr(&"summary.fortress_hint"), "summary: with Mithril the hint says repair")
	EventBus.wave_started.emit(9)
	_summary._on_summary_ready({"wave_index": 9, "fortress_hp": 900, "fortress_max_hp": 1000})
	_expect(not _summary._weapon.visible and not _summary._hazard_note.visible and not _summary._fortress_hint.visible,
		"summary: a new wave clears the weapon, the note and the hint")
	_expect(_value_color(_summary._fortress) == _summary._fortress.value_color, "summary: a safe Fortress value keeps its colour")

func _check_fortress_bar() -> void:
	_show_low_fortress_prep(0)
	_expect(_fortress_bar._hint_box.visible and _fortress_bar._hint.text == tr(&"hud.fortress_hint_hazard"),
		"fortress bar: low HP in PREP without Mithril points to the Hazard Trial")
	EventBus.mithril_changed.emit(3, 3)
	_expect(_fortress_bar._hint.text == tr(&"hud.fortress_hint"), "fortress bar: with Mithril the hint says repair")
	EventBus.state_changed.emit(&"COMBAT")
	_expect(not _fortress_bar._hint_box.visible and _fortress_bar._low_tag.visible, "fortress bar: in combat only the warning stays")
	EventBus.state_changed.emit(&"PREP")
	EventBus.fortress_hp_changed.emit(900, 1000, 650)
	_expect(not _fortress_bar._hint_box.visible, "fortress bar: no hint once the Fortress is safe")

func _show_low_fortress_prep(mithril: int) -> void:
	EventBus.fortress_hp_changed.emit(250, 1000, -50)
	EventBus.mithril_changed.emit(mithril, 0)
	EventBus.state_changed.emit(&"PREP")

func _check_pause() -> void:
	_pause.show_run_info({})
	_expect(not _pause._run_info.visible, "pause: no run info outside a run")
	_pause.show_run_info({"wave_index": 12, "run_elapsed": 125.0, "prestige_gain": 48, "victory_reached": false})
	_expect(_pause._run_info.text == UiFormat.tr_fmt(&"menu.paused_info", {"wave": 12, "time": "02:05"}), "pause: shows the wave and the time")
	_pause._abandon.pressed.emit()
	_expect(_dialog_has(UiFormat.tr_fmt(&"dialog.abandon.body_run", {"wave": 12, "gain": 48})), "pause: Abandon names the wave and the prestige")
	ScreenManager.close_top_dialog()
	await get_tree().process_frame
	_pause.show_run_info({"wave_index": 33, "run_elapsed": 125.0, "prestige_gain": 90, "victory_reached": true})
	_pause._quit.pressed.emit()
	_expect(_dialog_has(UiFormat.tr_fmt(&"dialog.quit_run.body_survived", {"wave": 33, "gain": 90})), "pause: Quit after the victory says survived")
	ScreenManager.close_top_dialog()
	await get_tree().process_frame

func _show_summary(mithril: int) -> void:
	EventBus.wave_started.emit(8)
	EventBus.mithril_changed.emit(mithril, 0)
	EventBus.hazard_trial_exited.emit(&"WON", 5, 30, 12.0, 1)
	EventBus.weapon_gained.emit(&"frost")
	_summary._on_state_changed(&"SUMMARY")
	_summary._on_summary_ready({"wave_index": 8, "fortress_hp": 250, "fortress_max_hp": 1000, "commander_level": 4})

func _defeat() -> Dictionary:
	return {"run_result": &"DEFEAT", "wave_index": 7, "waves_cleared": 6, "run_elapsed": 640.0, "run_kills": 182,
		"run_commander_kills": 61, "run_gold_earned": 1450, "run_bosses_defeated": 1, "commander_level": 5,
		"prestige_pending": 30, "wave_prestige_buffer": 8, "start_mult": 1.0, "prestige_gain": 12}

func _survived() -> Dictionary:
	var summary := _defeat()
	summary.merge({"run_result": &"SURVIVED", "wave_index": 34, "waves_cleared": 33, "prestige_gain": 160,
		"new_record": true, "damage_by_tower_type": {"arrow": 5200, "cannon": 9000, "barricade": 20000},
		"unlocked_starts": [10, 20]}, true)
	return summary

func _victory_stats() -> Dictionary:
	return {"waves_cleared": 30, "run_elapsed": 2710.0, "run_kills": 1320, "run_gold_earned": 9800,
		"prestige_pending": 410, "run_bosses_defeated": 6, "commander_level": 12,
		"owned_weapons": [&"sword_base", &"frost"]}

func _only(screen: Control) -> void:
	for s: Control in [_run_end, _victory, _summary, _pause, _fortress_bar]:
		s.visible = s == screen

func _value(row: Control) -> String:
	return row._value.text

func _value_color(row: Control) -> Color:
	return (row._value as Label).get_theme_color(&"font_color")

func _dialog_has(text: String) -> bool:
	for node in ScreenManager.find_children("*", "Label", true, false):
		if (node as Label).text == text:
			return true
	return false

func _expect(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		push_error("test_run_flow_screens FAILED: " + what)
