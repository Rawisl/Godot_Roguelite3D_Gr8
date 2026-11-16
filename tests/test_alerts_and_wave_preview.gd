extends Control
## New alerts, the fight time on the wave counter, the next wave preview with enemy traits, the
## traits in the Hazard Trial tooltip and in the enemy hover box. Press F6: the checks run first
## and print a summary, then click the window once and use the keys:
## 1: commander low HP banner. 2: boss enrage warning, then the enrage banner 2 s later.
## 3: one tower destroyed. 4: three towers in the same frame. 5: PREP before a boss wave.
## 6: wave preview of a normal wave with traits. 7: boss wave preview with the weapon drop.
## 8: fight time running on the wave counter. 9: enemy hover box with traits.
## Traits come from EnemyTraits.overrides until the enemy data has them.

const GRUNT_SCENE := preload("res://entities/enemy/grunt.tscn")
const FAKE_TRAITS := {&"grunt": [&"stealth"], &"brute": [&"undying", &"charge"], &"archer": [&"explode", &"revive"]}

## Answers find_slot() like BuildService, with one destroyed Cannon.
class AlertsFakeBuilds:
	extends Node
	var slot := Slot.new()

	func find_slot(_slot_id: StringName) -> Slot:
		return slot

var _passed := 0
var _failed := 0
var _alerts: Array[Array] = []
var _fake := AlertsFakeBuilds.new()
var _enemy: Enemy

@onready var _layer: AlertLayer = $AlertLayer
@onready var _counter: Control = $WaveCounter
@onready var _preview: WavePreview = $WavePreview
@onready var _gate: Control = $HazardGate
@onready var _bars: EnemyBarLayer = $EnemyBarLayer

func _ready() -> void:
	EnemyTraits.overrides = FAKE_TRAITS.duplicate(true)
	_fake.add_to_group(&"build_service")
	add_child(_fake)
	_fake.slot.last_data = load("res://data/towers/cannon.tres")
	_fake.slot.last_level = 2
	EventBus.alert_requested.connect(func(tier: int, key: StringName, params: Dictionary) -> void: _alerts.append([tier, key, params]))
	_enemy = GRUNT_SCENE.instantiate()
	await get_tree().process_frame
	await _run_checks()
	print("test_alerts_and_wave_preview: %d passed, %d failed" % [_passed, _failed])

func _exit_tree() -> void:
	EnemyTraits.overrides = {}
	_fake.slot.free()
	_enemy.free()

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	_layer.clear()
	match key.keycode:
		KEY_1:
			EventBus.commander_hp_changed.emit(100, 100)
			EventBus.commander_hp_changed.emit(20, 100)
		KEY_2:
			EventBus.boss_timer_milestone.emit(int(GameConfig.enrage_warn_time))
			await TimeManager.wait_real(2.0)
			EventBus.boss_enraged.emit()
		KEY_3:
			EventBus.tower_destroyed.emit(&"W3")
		KEY_4:
			for slot_id in [&"W1", &"W2", &"G_0_4"]:
				EventBus.tower_destroyed.emit(slot_id)
		KEY_5:
			EventBus.run_started.emit()
			EventBus.wave_started.emit(4)
			EventBus.state_changed.emit(&"PREP")
		KEY_6:
			EventBus.state_changed.emit(&"PREP")
			_preview.show_preview(3, {&"grunt": 12, &"archer": 6, &"brute": 2}, false)
		KEY_7:
			EventBus.run_started.emit()
			EventBus.state_changed.emit(&"PREP")
			_preview.show_preview(5, {&"grunt": 10, &"brute": 3, &"bulwark_boss": 1}, true)
		KEY_8:
			EventBus.wave_started.emit(7)
			EventBus.state_changed.emit(&"COMBAT")
			EventBus.enemy_spawned.emit(null)
		KEY_9:
			# No enemy is really hovered here, so stop the layer from hiding the box again.
			_bars.set_process(false)
			_bars._fill_hover_info(_enemy)
			_bars._hover_info.position = Vector2(860, 500)
			_bars._hover_info.visible = true

func _run_checks() -> void:
	_check_commander()
	_check_boss_timer()
	await _check_towers()
	_check_boss_next()
	await _check_clear_time()
	_check_preview()
	_check_hazard_tooltip()
	_check_hover()
	_expect(tr(&"hud.mode.denied.hazard").contains("Hazard Trial"), "strings: the mode lock names the Hazard Trial")

func _check_commander() -> void:
	_alerts.clear()
	EventBus.commander_hp_changed.emit(100, 100)
	EventBus.commander_hp_changed.emit(24, 100)
	EventBus.commander_hp_changed.emit(10, 100)
	_expect(_keys() == [&"alert.commander_low"] and _alerts[0][0] == 1, "alerts: the commander under 25% raises one T1 banner")
	EventBus.commander_hp_changed.emit(60, 100)
	EventBus.commander_hp_changed.emit(20, 100)
	_expect(_keys().size() == 2, "alerts: healing back up arms the banner again")
	_expect(_layer._banner.visible, "alerts: the banner shows")

func _check_boss_timer() -> void:
	_alerts.clear()
	EventBus.boss_timer_milestone.emit(int(GameConfig.enrage_warn_time))
	EventBus.boss_timer_milestone.emit(10)
	EventBus.boss_enraged.emit()
	_expect(_keys() == [&"alert.boss_enrage_soon", &"alert.boss_enraged"] and _alerts[0][0] == 2 and _alerts[1][0] == 1,
		"alerts: T-30 is a T2 toast and the enrage a T1 banner, the countdown adds nothing")

func _check_towers() -> void:
	EventBus.run_started.emit()
	_layer.clear()
	_alerts.clear()
	EventBus.tower_destroyed.emit(&"W3")
	await get_tree().process_frame
	var p: Dictionary = _alerts[0][2] if not _alerts.is_empty() else {}
	_expect(_keys() == [&"alert.tower_ruined"] and p.get("name") == tr(&"tower.cannon") and p.get("level") == 2 and p.get("slot") == &"W3"
		and p.get("cost") == _fake.slot.get_rebuild_cost(), "alerts: one destroyed tower names its type, level, slot and rebuild price")
	_expect(_layer.shown_texts() == [UiFormat.tr_fmt(&"alert.tower_ruined", p)] and _toast_sub_visible(),
		"alerts: the toast has the tower on its main line and the rebuild price on the second line")
	# A second loss inside the window replaces the toast with a count instead of stacking a new one.
	EventBus.tower_destroyed.emit(&"W1")
	await get_tree().process_frame
	_expect(_layer.visible_toast_count() == 1 and _layer.shown_keys() == [&"alert.towers_ruined"]
		and _alerts[-1][2].get("count") == 2, "alerts: a loss within the merge window updates the same toast to a count")
	for slot_id in [&"W2", &"G_0_4"]:
		EventBus.tower_destroyed.emit(slot_id)
	await get_tree().process_frame
	_expect(_layer.visible_toast_count() == 1 and _alerts[-1][2].get("count") == 4 and _alerts[-1][2].get("slots") == "W3, W1, W2, G_0_4",
		"alerts: towers lost in one frame join the count and the second line lists the slots")
	# After the window, a new loss starts a new toast of its own.
	# Stands in for the window running out, without waiting five real seconds.
	(_layer.find_child("AlertSources", false, false) as AlertSources)._ruined_until = 0.0
	EventBus.tower_destroyed.emit(&"W2")
	await get_tree().process_frame
	_expect(_alerts[-1][1] == &"alert.tower_ruined", "alerts: a loss after the window is told on its own")
	_layer.clear()

func _toast_sub_visible() -> bool:
	for toast in _layer._top.get_children():
		if (toast as Control).visible:
			return (toast.get_child(0).get_child(1).get_child(1) as Label).visible
	return false

func _check_boss_next() -> void:
	_alerts.clear()
	EventBus.run_started.emit()
	EventBus.wave_started.emit(4)
	EventBus.state_changed.emit(&"PREP")
	EventBus.state_changed.emit(&"PREP")
	_expect(_keys() == [&"alert.boss_next"] and _alerts[0][2].get("wave") == 5 and _alerts[0][2].get("sub_key") == &"alert.boss_next_sub",
		"alerts: the PREP before a boss wave warns once, with the immunity reminder on the second line")
	_expect(not tr(&"alert.boss_next").contains(".") and not tr(&"alert.boss_next_sub").contains("."), "alerts: no sentence punctuation in the boss warning")
	_alerts.clear()
	EventBus.wave_started.emit(6)
	EventBus.wave_preview_ready.emit(7, {}, true)
	EventBus.state_changed.emit(&"PREP")
	_expect(_keys() == [&"alert.boss_next"], "alerts: the wave preview decides when it says boss")
	_alerts.clear()
	EventBus.wave_started.emit(9)
	EventBus.wave_preview_ready.emit(10, {}, false)
	EventBus.state_changed.emit(&"PREP")
	_expect(_alerts.is_empty(), "alerts: no warning when the preview says no boss")

func _check_clear_time() -> void:
	var label := _counter.get_node("%ClearTime") as Label
	EventBus.wave_started.emit(3)
	EventBus.state_changed.emit(&"COMBAT")
	var start := TimeManager.game_time
	while TimeManager.game_time - start < 0.3:
		await get_tree().process_frame
	_expect(label.text == UiFormat.time_mmss(0.0), "fight time: it waits for the first enemy")
	EventBus.enemy_spawned.emit(null)
	start = TimeManager.game_time
	while TimeManager.game_time - start < 1.2:
		await get_tree().process_frame
	# Rounded up like the summary's clear time, so both show the same number at the end.
	var counted: float = _counter._clear_seconds
	_expect(counted >= 1.0 and label.text == UiFormat.time_mmss(counted) and label.is_visible_in_tree(), "fight time: it counts in combat")
	EventBus.state_changed.emit(&"SUMMARY")
	var frozen := label.text
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(label.text == frozen and not label.is_visible_in_tree(), "fight time: it stops and hides after combat")
	EventBus.wave_started.emit(4)
	_expect(label.text == UiFormat.time_mmss(0.0), "fight time: a new wave starts from zero")

func _check_preview() -> void:
	EventBus.run_started.emit()
	EventBus.state_changed.emit(&"PREP")
	_preview.show_preview(5, {&"grunt": 10, "brute": 3, &"bulwark_boss": 1, &"archer": 4}, true)
	var rows := _preview.get_node("%Rows").get_children()
	var first := rows[0] as WavePreviewRow
	_expect(_preview.visible and first._name.text == EnemyTraits.display_name(&"bulwark_boss") and not first._count.visible,
		"preview: the boss comes first, without a count")
	_expect((rows[1] as WavePreviewRow)._name.text == tr(&"enemy.grunt") and (rows[1] as WavePreviewRow)._count.text == UiFormat.tr_fmt(&"hud.preview.count", {"value": 10}),
		"preview: then the most numerous, with String or StringName keys")
	var brute := rows[3] as WavePreviewRow
	_expect(brute.trait_count() == 2 and (brute._badges.get_child(0) as TraitBadge)._name.text == tr(&"enemy.trait.undying"),
		"preview: each trait shows its icon and its name")
	_expect(not (rows[4] as Control).visible, "preview: unused rows stay hidden")
	var note := _preview.get_node("%WeaponNote") as Label
	_expect(note.visible and note.text == UiFormat.tr_fmt(&"hud.preview.weapon_drop", {"left": 5}), "preview: a boss wave that drops tells how many weapons are left")
	for i in 5:
		EventBus.weapon_gained.emit(&"frost")
	_preview.show_preview(10, {&"bulwark_boss": 1}, true)
	_expect(not note.visible, "preview: no drop line once every weapon is owned")
	_preview.show_preview(6, {&"grunt": 1, &"archer": 1, &"brute": 1, &"grunt_b": 1, &"grunt_c": 1, &"grunt_d": 1}, false)
	_expect(rows.filter(func(r: Node) -> bool: return (r as Control).visible).size() == 5, "preview: at most five types")
	(_preview.get_node("%Toggle") as Button).pressed.emit()
	_expect(not _preview.get_node("%Body").visible and _preview.visible and (_preview.get_node("%ToggleArrow") as ArrowGlyph).pointing_up,
		"preview: the arrow folds the list away and keeps the title")
	EventBus.run_started.emit()
	_expect(_preview.expanded and _preview.get_node("%Body").visible, "preview: a new run shows the list again")
	EventBus.state_changed.emit(&"PREP")
	_preview.show_preview(5, {&"grunt": 1}, true)
	EventBus.state_changed.emit(&"COMBAT")
	_expect(not _preview.visible, "preview: hidden outside PREP")

func _check_hazard_tooltip() -> void:
	EventBus.state_changed.emit(&"PREP")
	EventBus.hazard_trial_offered.emit(4, [&"grunt", &"brute"], 1)
	var text: String = _gate._tooltip(&"")
	_expect(text.contains(EnemyTraits.name_with_traits(&"brute")) and text.contains(tr(&"enemy.trait.charge")),
		"hazard tooltip: the group lists each type with its traits")

func _check_hover() -> void:
	_bars._fill_hover_info(_enemy)
	var badges := _bars._hover_badges.get_children()
	_expect(_bars._hover_name.text == tr(&"enemy.grunt") and (badges[0] as Control).visible and not (badges[1] as Control).visible,
		"hover: the enemy box names the enemy and its trait")

func _keys() -> Array:
	return _alerts.map(func(a: Array) -> StringName: return a[1])

func _expect(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		push_error("test_alerts_and_wave_preview FAILED: " + what)
