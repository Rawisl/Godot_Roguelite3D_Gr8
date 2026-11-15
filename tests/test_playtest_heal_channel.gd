extends Node
## F6 harness using the real corridor, input, stations, rewards, HUD and camera.

const MAIN_SCENE := preload("res://main.tscn")
const STATION_DATA := preload("res://data/towers/heal_station.tres")
const DIALOG_SCENE := preload("res://ui/screens/confirm_dialog.tscn")

class MemoryRepository extends SaveRepository:
	var envelope: Dictionary = {}

	func save_data(value: Dictionary) -> Error:
		envelope = value.duplicate(true)
		return OK

	func has_data() -> bool:
		return not envelope.is_empty()

	func load_data() -> Dictionary:
		last_error = ERR_FILE_NOT_FOUND if envelope.is_empty() else OK
		return envelope.duplicate(true)

var _main: Node
var _commander: CharacterBody3D
var _waves: WaveManager
var _build: BuildService
var _slots: Array[Slot] = []
var _info: Label
var _controls: PanelContainer
var _busy := false
var _skill_level := 0
var _preset := "In range"
var _previous_repository: SaveRepository
var _previous_data: Dictionary
var _previous_can_write := true
var _previous_backend_url: String
var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_previous_repository = SaveManager.repository
	_previous_data = SaveManager.data
	_previous_can_write = SaveManager.can_write
	SaveManager.set_repository(MemoryRepository.new())
	SaveManager.data = SaveManager.DEFAULT_DATA.duplicate(true)
	SaveManager.can_write = true
	# Boot restores sessions deferred; disable networking before that callback runs.
	_previous_backend_url = GameConfig.backend_url
	GameConfig.backend_url = ""
	_make_controls()
	await reset_fixture()
	if "--walkthrough" in OS.get_cmdline_user_args():
		await _walkthrough()


func _make_controls() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var panel := PanelContainer.new()
	layer.add_child(panel)
	_controls = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -560
	panel.offset_right = -20
	panel.offset_top = 230
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Heal channel playtest"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var help := Label.new()
	help.text = "E: hold to heal. WASD: move/pan.\nSpace: dodge. LMB: attack. 1: skill.\nTab: Recall/Deploy. Use HUD speed buttons.\nHold W across Tab/dialogs to check drift."
	help.add_theme_font_size_override("font_size", 20)
	column.add_child(help)
	_row(column, ["In range", "Out of range", "Full HP"], [
		func(): reset_fixture("In range", _skill_level),
		func(): reset_fixture("Out of range", _skill_level),
		func(): reset_fixture("Full HP", _skill_level)])
	_row(column, ["Missing 3", "One empty", "Both empty"], [
		func(): reset_fixture("Missing 3", _skill_level),
		func(): reset_fixture("One empty", _skill_level),
		func(): reset_fixture("Both empty", _skill_level)])
	_row(column, ["PREP", "COMBAT", "SUMMARY"], [
		func(): set_wave(&"PREP"), func(): set_wave(&"COMBAT"), func(): set_wave(&"SUMMARY")])
	_row(column, ["Skill L0", "L1", "L2", "L3"], [
		func(): reset_fixture(_preset, 0), func(): reset_fixture(_preset, 1),
		func(): reset_fixture(_preset, 2), func(): reset_fixture(_preset, 3)])
	_row(column, ["Hit -10", "Pause", "Dialog", "Reset"], [
		_hurt, _toggle_pause, _open_dialog, func(): reset_fixture()])
	_row(column, ["Knockback", "Drain source", "Two in range"], [
		func(): _hurt(1.0), _drain_source, func(): reset_fixture("Two in range", _skill_level)])
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 20)
	column.add_child(_info)


func _row(parent: Control, names: Array, actions: Array) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	for index in names.size():
		var button := Button.new()
		button.text = names[index]
		button.add_theme_font_size_override("font_size", 20)
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func():
			if not _busy:
				actions[index].call())
		row.add_child(button)


func reset_fixture(preset := "In range", skill_level := 0) -> void:
	_busy = true
	_release_input()
	TimeManager.reset()
	ScreenManager.close_all_dialogs()
	if is_instance_valid(_main):
		_main.free()
	_slots.clear()
	_main = MAIN_SCENE.instantiate()
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_main)
	await get_tree().process_frame
	await get_tree().physics_frame
	_waves = _main.find_child("WaveManager", true, false) as WaveManager
	_build = _main.find_child("BuildService", true, false) as BuildService
	_commander = get_tree().get_first_node_in_group(&"commander") as CharacterBody3D
	# Freeze only the harness's wave clock: state APIs, input and gameplay keep running.
	_waves.set_process(false)
	_waves.set_physics_process(false)
	_waves.start_prep()
	var gold := get_tree().get_first_node_in_group(&"gold_manager") as GoldManager
	gold.gold = 10000
	var candidates := get_tree().get_nodes_in_group(&"slot")
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(Vector3.ZERO) < b.global_position.distance_squared_to(Vector3.ZERO))
	for node in candidates:
		var slot := node as Slot
		if slot != null and slot.is_ground() and _build.build(slot.slot_id, STATION_DATA.id):
			_slots.append(slot)
			if _slots.size() == 2:
				break
	if _slots.size() != 2 or _commander == null:
		push_error("Heal playtest requires two buildable ground slots and the commander")
		_busy = false
		return
	var rewards := _main.find_child("RewardService", true, false) as RewardService
	_pick_card(rewards, &"whirlwind", &"ACTIVE", 1)
	for level in range(1, skill_level + 1):
		_pick_card(rewards, &"heal_station", &"PASSIVE", level)
	_skill_level = skill_level
	_preset = preset
	_waves.start_combat()
	var station := _slots[0].tower as HealStation
	_commander.global_position = station.global_position + Vector3(0, 0.1, 2.0)
	if preset == "Two in range":
		_commander.global_position = (_slots[0].global_position + _slots[1].global_position) * 0.5 + Vector3(0, 0.1, 2.0)
	if preset == "Out of range":
		_commander.global_position = station.global_position + Vector3(0, 0.1, 4.0)
	_commander.health.hp = _commander.health.max_hp if preset == "Full HP" else 40
	if preset == "Missing 3":
		_commander.health.hp = _commander.health.max_hp - 3
	_commander.health.hp_changed.emit(_commander.health.hp, _commander.health.max_hp)
	if preset == "One empty" or preset == "Both empty":
		station.drain(station.hp)
	if preset == "Both empty":
		var second := _slots[1].tower as HealStation
		second.drain(second.hp)
	var summary := _main.find_child("SummaryPanel", true, false)
	summary.set_process(false)
	_busy = false


func _pick_card(rewards: RewardService, id: StringName, kind: StringName, level: int) -> void:
	for _attempt in 100:
		rewards.offer_next()
		if rewards.pick(id, kind, level):
			return
		rewards.skip()
	push_error("Heal playtest could not offer %s level %d" % [id, level])


func set_wave(state: StringName) -> void:
	if _busy:
		return
	if TimeManager.is_paused:
		TimeManager.release_pause(TimeManager.REASON_USER)
	match state:
		&"PREP": _waves.start_prep()
		&"COMBAT": _waves.start_combat()
		&"SUMMARY": _waves._end_combat_to_summary()


func _hurt(knockback_force := 0.0) -> void:
	if _commander.health.hp > 10:
		_commander.take_damage(DamageInfo.new(10, Enums.DamageType.BLAST, null,
			knockback_force, Vector3.RIGHT))


func _drain_source() -> void:
	var channel := _commander.get_node("HealChannel") as HealChannel
	var source := channel.get_source() as HealStation
	if source != null:
		source.drain(source.hp)


func _toggle_pause() -> void:
	if TimeManager.is_paused:
		TimeManager.release_pause(TimeManager.REASON_USER)
	else:
		TimeManager.request_pause(TimeManager.REASON_USER)


func _open_dialog() -> void:
	var dialog := DIALOG_SCENE.instantiate()
	dialog.setup_notice(&"reward.skip.title", &"reward.skip.body")
	ScreenManager.open_dialog(dialog)


func _process(_delta: float) -> void:
	if _busy or not is_instance_valid(_commander):
		return
	var stores: Array[String] = []
	for slot in _slots:
		var station := slot.tower as HealStation
		stores.append("%.1f" % station.hp if station != null else "RUINED")
	var channel := _commander.get_node("HealChannel") as HealChannel
	_info.text = "%s | skill L%d\nHP %.2f/%d | stores %s\n%s | reason: %s\n%.0f HP/s | speed x%d\nSave: memory only | backend disabled" % [
		_preset, _skill_level, _commander.health.get_precise_hp(), _commander.health.max_hp,
		" / ".join(stores), channel.phase, channel.get_block_reason(),
		channel.get_heal_rate(), TimeManager.get_time_scale()]


func _walkthrough() -> void:
	await _wait(0.7)
	_check(get_viewport().get_visible_rect().encloses(_controls.get_global_rect()),
		"playtest controls fit inside the viewport")
	_check(get_tree().get_nodes_in_group(&"enemy").is_empty(), "wave spawning is disabled only in the harness")
	_check(_hud_text() == tr(&"hud.heal.ready"), "corridor HUD is ready with real stations")
	await _capture("ready")
	_key(KEY_E, true)
	await _wait(0.45)
	_check(_hud_text().begins_with(tr(&"hud.heal.hold").get_slice("{seconds}", 0)), "corridor HUD counts down")
	await _capture("hold")
	await _wait(0.9)
	_check(_hud_text() == UiFormat.tr_fmt(&"hud.heal.healing", {"rate": "10"}),
		"corridor HUD shows the real base rate")
	await _capture("healing")
	_key(KEY_E, false)
	_hurt(1.0)
	await _wait(0.15)
	_check((_commander.get_node("HealChannel") as HealChannel).phase == HealChannel.IDLE,
		"a real hit cancels healing")
	_check(_hud_text() == tr(&"hud.heal.under_attack"), "knockback keeps the hit explanation visible")
	await _capture("cancelled")
	await reset_fixture("Missing 3")
	_key(KEY_E, true)
	await _wait(1.5)
	_key(KEY_E, false)
	_check(_commander.health.hp == _commander.health.max_hp, "near-full preset fills exactly")
	_check(absf((_slots[0].tower as HealStation).hp - 294.0) < 0.01, "near-full preset drains only six")
	await _capture("full")
	await reset_fixture("Out of range")
	await _wait(0.7)
	_check(_hud_text() == tr(&"hud.heal.too_far"), "corridor HUD reports range")
	await _capture("outside")
	await reset_fixture("Both empty")
	await _wait(0.7)
	_check(_hud_text() == tr(&"hud.heal.depleted"), "corridor HUD reports rubble stores")
	await _capture("empty")
	await reset_fixture("Two in range")
	await _wait(0.7)
	_key(KEY_E, true)
	await _wait(1.2)
	_drain_source()
	await _wait(0.15)
	_check(_hud_text() == tr(&"hud.heal.depleted"), "depletion explains why the channel stopped with another station alive")
	_key(KEY_W, true)
	await _wait(0.1)
	_check(_hud_text() == tr(&"hud.heal.depleted"), "movement keeps the recent depletion explanation visible")
	await _capture("depleted-moving")
	_key(KEY_W, false)
	_key(KEY_E, false)
	await reset_fixture("In range", 3)
	await _wait(0.7)
	_check(is_equal_approx((_commander.get_node("HealChannel") as HealChannel).get_heal_rate(), 25.0),
		"real rewards apply the level three rate")
	TimeManager.set_time_scale(3)
	_key(KEY_E, true)
	await _wait(0.5)
	_check(_hud_text() == UiFormat.tr_fmt(&"hud.heal.healing", {"rate": "25"}),
		"accelerated healing displays the skill rate")
	await _capture("skill")
	_key(KEY_E, false)
	_toggle_pause()
	await _wait(0.15)
	_check(_hud_text() == tr(&"hud.heal.paused"), "corridor HUD updates during pause")
	await _capture("paused")
	_toggle_pause()
	set_wave(&"PREP")
	await _wait(0.2)
	_check(_hud_text() == tr(&"hud.heal.combat_only"), "PREP blocks healing")
	await _capture("prep")
	set_wave(&"SUMMARY")
	await _wait(0.2)
	_check(_hud_text() == tr(&"hud.heal.combat_only"), "SUMMARY blocks healing")
	await _capture("summary")
	await reset_fixture()
	set_wave(&"PREP")
	_key(KEY_W, true)
	await _wait(0.1)
	_key(KEY_TAB, true)
	_key(KEY_TAB, false)
	await _wait(0.7)
	_check(_commander.is_commander_mode, "real Tab enters commander mode")
	var rig := _main.find_child("CameraRig", true, false) as Node3D
	var focus := rig.global_position
	await _wait(0.25)
	_check(rig.global_position.distance_to(focus) < 0.01, "holding W through Tab does not drift the camera")
	_key(KEY_W, false)
	_open_dialog()
	_key(KEY_W, true)
	var before := _commander.global_position
	focus = rig.global_position
	await _wait(0.2)
	_check(_commander.global_position.distance_to(before) < 0.01, "dialog blocks movement")
	_check(rig.global_position.distance_to(focus) < 0.01, "dialog blocks camera pan")
	await _capture("dialog")
	_key(KEY_W, false)
	ScreenManager.close_all_dialogs()
	_release_input()
	print("HEAL PLAYTEST WALKTHROUGH: %d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless" or "--capture-walkthrough" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var path := "res://.godot/heal-playtest-%s.png" % label
	var error := get_viewport().get_texture().get_image().save_png(path)
	_check(error == OK, "viewport capture saved: %s" % label)


func _hud_text() -> String:
	var hud := _main.find_child("HealStatus", true, false)
	return (hud.get_node("Column/Status") as Label).text


func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _wait(seconds: float) -> void:
	var deadline := TimeManager.real_time + seconds
	while TimeManager.real_time < deadline:
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
	print("[PASS] " if condition else "[FAIL] ", label)


func _release_input() -> void:
	for key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_E, KEY_TAB]:
		_key(key, false)


func _exit_tree() -> void:
	_release_input()
	TimeManager.reset()
	SaveManager.set_repository(_previous_repository)
	SaveManager.data = _previous_data
	SaveManager.can_write = _previous_can_write
	GameConfig.backend_url = _previous_backend_url
