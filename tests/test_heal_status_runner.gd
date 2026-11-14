extends Node
## Integration checks for the real heal channel, build lifecycle and HUD.

const SLOT_SCENE := preload("res://systems/build/slot.tscn")
const STATION_SCENE := preload("res://entities/tower/heal_station.tscn")
const STATION_DATA := preload("res://data/towers/heal_station.tres")
const HUD_SCENE := preload("res://ui/hud/parts/heal_status.tscn")
const COMMANDER_SCENE := preload("res://entities/commander/commander.tscn")

var _passed := 0
var _failed := 0
var _fixture: Node3D
var _commander: CharacterBody3D
var _channel: HealChannel
var _build: BuildService
var _hud: Control
var _slots: Array[Slot] = []
var _samples: Array[float] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	TranslationServer.set_locale("vi")
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)
	EventBus.heal_status_updated.connect(_on_status)
	await _test_conditions()
	await _test_hold_and_rate()
	await _test_flash_priority()
	await _test_station_lifecycle()
	await _test_station_identity()
	await _test_late_listener_and_reset()
	await _test_translation_refresh()
	_release()
	TimeManager.reset()
	print("HEAL STATUS TEST SUMMARY: %d PASSED, %d FAILED" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _setup(two_stations := false) -> void:
	_release()
	TimeManager.reset()
	if is_instance_valid(_fixture):
		_fixture.free()
	_slots.clear()
	_fixture = Node3D.new()
	_fixture.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_fixture)
	var gold := GoldManager.new()
	_fixture.add_child(gold)
	gold.gold = 10000
	_build = BuildService.new()
	_build.towers = [STATION_DATA]
	_build.tower_scenes = {STATION_DATA.id: STATION_SCENE}
	_fixture.add_child(_build)
	EventBus.state_changed.emit(&"PREP")
	for index in (2 if two_stations else 1):
		var slot := SLOT_SCENE.instantiate() as Slot
		slot.slot_id = StringName("heal_%d" % index)
		slot.position = Vector3(1 + index, 0, 0)
		_fixture.add_child(slot)
		_slots.append(slot)
		_check(_build.build(slot.slot_id, STATION_DATA.id), "real station builds")
	_commander = COMMANDER_SCENE.instantiate()
	_fixture.add_child(_commander)
	_commander.set_physics_process(false)
	_commander.health.max_hp = 100
	_commander.health.hp = 50
	_channel = _commander.get_node("HealChannel") as HealChannel
	_channel.set_physics_process(false)
	EventBus.mode_changed.emit(&"FRONTLINE")
	EventBus.state_changed.emit(&"COMBAT")


func _test_conditions() -> void:
	_setup()
	await _settle()
	_check(_hud.visible, "real station makes HUD visible")
	_expect(&"hud.heal.ready")
	for state in [&"PREP", &"SUMMARY", &"BOSS_INTRO", &"HAZARD_TRIAL"]:
		EventBus.state_changed.emit(state)
		await _settle()
		_expect(&"hud.heal.combat_only")
	EventBus.state_changed.emit(&"BOSS_COMBAT")
	await _settle()
	_expect(&"hud.heal.ready")
	EventBus.mode_changed.emit(&"COMMANDER")
	await _settle()
	_expect(&"hud.heal.frontline_only")
	EventBus.mode_changed.emit(&"FRONTLINE")
	_commander.global_position = Vector3(4, 0, 0)
	await _settle()
	_expect(&"hud.heal.ready")
	_commander.global_position.x += 0.001
	await _settle()
	_expect(&"hud.heal.too_far")
	_commander.global_position = Vector3.ZERO
	_commander.health.hp = 100
	await _settle()
	_expect(&"hud.heal.full_hp")
	_commander.health.hp = 99
	_commander.health.heal_fractional(0.6)
	EventBus.commander_hp_changed.emit(_commander.health.hp, 100)
	await _settle()
	_expect(&"hud.heal.ready")
	Input.action_press(&"move_right")
	await _settle()
	_expect(&"hud.heal.busy")
	Input.action_release(&"move_right")
	TimeManager.request_pause(TimeManager.REASON_USER)
	await _settle()
	_expect(&"hud.heal.paused")
	TimeManager.release_pause(TimeManager.REASON_USER)
	_commander.health.hp = 50
	_commander.health.hp_changed.emit(50, 100)
	await _settle()
	_commander.take_damage(DamageInfo.new(5, Enums.DamageType.BLAST))
	EventBus.state_changed.emit(&"PREP")
	await _settle()
	_expect(&"hud.heal.combat_only")
	EventBus.state_changed.emit(&"COMBAT")
	_station().drain(_station().hp)
	await _settle()
	_expect(&"hud.heal.depleted")
	_check(_hud.visible, "ruined station keeps the empty-store reason visible")


func _test_hold_and_rate() -> void:
	for speed in [1, 2, 3]:
		_setup()
		TimeManager.set_time_scale(speed)
		Input.action_press(&"heal_channel")
		_advance(0.4)
		await _settle()
		_check(_text() == UiFormat.tr_fmt(&"hud.heal.hold", {"seconds": "0.6"}),
			"hold countdown uses game seconds at x%d" % speed)
		var bar := _hud.get_node("Column/HoldBar") as ProgressBar
		_check(bar.visible and absf(bar.value - 0.4) < 0.03, "hold bar follows real channel progress")
		_advance(0.7)
		await _settle()
		_expect_rate(10.0)
		_commander.stat_block.set_add(&"heal_rate_add", &"test_reward", 10.0)
		await _settle()
		_expect_rate(20.0)
		_check(not bar.visible, "hold bar hides during healing")
		_channel.cancel()
		await _settle()
		_expect(&"hud.heal.release")
		_release()
		_advance(0.05)
		TimeManager.real_time += 2.0
		await _settle()
		_expect(&"hud.heal.ready")
		_samples.clear()
		var start := TimeManager.real_time
		await _wait(1.05)
		_check(_samples.size() >= 9 and _samples.size() <= 11,
			"status refreshes at most ten times per real second at x%d" % speed)
		for index in range(1, _samples.size()):
			_check(_samples[index] - _samples[index - 1] >= 0.099,
				"status samples are spaced by real time")
		_check(TimeManager.real_time - start >= 1.05, "sampling interval completes")
	_setup()
	Input.action_press(&"heal_channel")
	_advance(0.4)
	TimeManager.request_pause(TimeManager.REASON_USER)
	await _settle()
	_expect(&"hud.heal.paused")
	_check(not (_hud.get_node("Column/HoldBar") as ProgressBar).visible, "pause clears the hold bar")
	TimeManager.release_pause(TimeManager.REASON_USER)
	await _settle()
	_expect(&"hud.heal.release")


func _test_flash_priority() -> void:
	_setup(true)
	await _settle()
	Input.action_press(&"heal_channel")
	_advance(1.1)
	await _settle()
	_commander.take_damage(DamageInfo.new(5, Enums.DamageType.BLAST, null, 1.0, Vector3.RIGHT))
	_check(not _commander.is_idle(), "a real hit starts knockback")
	await _settle()
	_expect(&"hud.heal.under_attack")
	_commander._knockback_velocity = Vector3.ZERO
	Input.action_press(&"move_right")
	_advance(0.05)
	await _settle()
	_expect(&"hud.heal.under_attack")
	Input.action_release(&"move_right")
	_commander.is_attacking = true
	await _settle()
	_expect(&"hud.heal.under_attack")
	await _wait(1.5)
	_expect(&"hud.heal.busy")
	_commander.is_attacking = false
	await _settle()
	_expect(&"hud.heal.release")
	_release()
	_advance(0.05)
	Input.action_press(&"heal_channel")
	_advance(0.4)
	_commander.take_damage(DamageInfo.new(5, Enums.DamageType.BLAST, null, 1.0, Vector3.RIGHT))
	TimeManager.request_pause(TimeManager.REASON_USER)
	await _settle()
	_expect(&"hud.heal.paused")
	TimeManager.release_pause(TimeManager.REASON_USER)
	EventBus.state_changed.emit(&"SUMMARY")
	await _settle()
	_expect(&"hud.heal.combat_only")

	_setup(true)
	_station().drain(_station().hp - 1.0)
	await _settle()
	Input.action_press(&"heal_channel")
	_advance(1.2)
	await _settle()
	_expect_counts(1, 2)
	_expect(&"hud.heal.depleted")
	Input.action_press(&"move_right")
	_advance(0.05)
	await _settle()
	_expect(&"hud.heal.depleted")
	await _wait(1.5)
	_expect(&"hud.heal.busy")
	Input.action_release(&"move_right")
	await _settle()
	_expect(&"hud.heal.release")


func _test_station_lifecycle() -> void:
	_setup(true)
	await _settle()
	_expect_counts(2, 2)
	_station().drain(_station().hp)
	await _settle()
	_expect_counts(1, 2)
	_slots[1].tower.take_damage(DamageInfo.new(1000, Enums.DamageType.SLASH))
	await _settle()
	_expect_counts(0, 2)
	_expect(&"hud.heal.depleted")
	EventBus.state_changed.emit(&"PREP")
	(get_tree().get_first_node_in_group(&"gold_manager") as GoldManager).gold = 10000
	_check(_build.build(_slots[0].slot_id, STATION_DATA.id), "real station rebuilds")
	await _settle()
	_expect_counts(1, 2)
	_check(_build.sell(_slots[0].slot_id), "real station sells")
	await _settle()
	_expect_counts(0, 1)
	_check(_build.clear_rubble(_slots[1].slot_id), "real rubble clears")
	await _settle()
	_expect_counts(0, 0)
	_check(not _hud.visible, "clearing the last station hides HUD")


func _test_station_identity() -> void:
	_setup()
	var data := STATION_DATA.duplicate() as TowerData
	data.id = &"test_healing_building"
	_build.heal_station_data = data
	_station().data = data
	await _settle()
	_expect_counts(1, 1)
	_check(_build.get_heal_station_count(_slots[0].slot_id) == 0, "station query excludes its requested slot")
	_station().drain(_station().hp)
	await _settle()
	_expect_counts(0, 1)
	_check(_build.get_heal_station_count() == 1, "build limit and HUD share configured station identity")


func _test_late_listener_and_reset() -> void:
	_setup()
	_commander.global_position = Vector3(10, 0, 0)
	await _settle()
	_hud.free()
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)
	await _settle()
	_check(_hud.visible, "late HUD receives station counts without input")
	_expect(&"hud.heal.too_far")
	_fixture.free()
	_check(not _hud.visible, "commander teardown clears stale HUD")
	_setup()
	await _settle()
	_expect(&"hud.heal.ready")
	_expect_counts(1, 1)
	TimeManager.reset_clocks()
	_samples.clear()
	await _settle()
	_check(not _samples.is_empty(), "clock reset does not stall the status heartbeat")
	TimeManager.request_pause(TimeManager.REASON_USER)
	_samples.clear()
	await _wait(0.35)
	_check(_samples.size() >= 3, "status continues refreshing while paused")
	_expect(&"hud.heal.paused")
	TimeManager.release_pause(TimeManager.REASON_USER)


func _test_translation_refresh() -> void:
	_setup()
	await _settle()
	_expect(&"hud.heal.ready")
	var translation := Translation.new()
	translation.locale = "en"
	translation.add_message(&"hud.heal.ready", &"Ready to heal")
	translation.add_message(&"hud.heal.stations", &"Stations {alive}/{total}")
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("en")
	await _settle()
	_check(_text() == "Ready to heal", "unchanged status refreshes after a language change")
	_check((_hud.get_node("Column/Stations") as Label).text == "Stations 1/1",
		"unchanged station counts refresh after a language change")
	TranslationServer.set_locale("vi")
	TranslationServer.remove_translation(translation)
	await _settle()
	_expect(&"hud.heal.ready")
	_expect_counts(1, 1)


func _station() -> HealStation:
	return _slots[0].tower as HealStation


func _advance(seconds: float) -> void:
	for _tick in roundi(seconds * 60.0):
		_channel._physics_process(1.0 / 60.0)


func _settle() -> void:
	await _wait(0.15)


func _wait(seconds: float) -> void:
	var deadline := TimeManager.real_time + seconds
	while TimeManager.real_time < deadline:
		await get_tree().process_frame


func _release() -> void:
	Input.action_release(&"heal_channel")
	Input.action_release(&"move_right")


func _text() -> String:
	return (_hud.get_node("Column/Status") as Label).text


func _expect(key: StringName) -> void:
	_check(_text() == tr(key), "HUD shows %s (got %s)" % [key, _text()])


func _expect_rate(rate: float) -> void:
	_check(_text() == UiFormat.tr_fmt(&"hud.heal.healing", {"rate": UiFormat.num(rate)}),
		"HUD shows the current %.0f HP/s" % rate)


func _expect_counts(alive: int, total: int) -> void:
	var text := (_hud.get_node("Column/Stations") as Label).text
	_check(text == UiFormat.tr_fmt(&"hud.heal.stations", {"alive": alive, "total": total}),
		"station counts are %d/%d (got %s)" % [alive, total, text])


func _on_status(_state: StringName, _reason: StringName, _progress: float,
		_remaining: float, _rate: float, _alive: int, _total: int) -> void:
	_samples.append(TimeManager.real_time)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] ", label)
	else:
		_failed += 1
		printerr("[FAIL] ", label)
