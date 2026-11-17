extends Node
## Playable check for the boss weapon drop. Run with F6 and use the keys listed on screen.
## The real HUD (weapon slot, alerts, summary panel), a real RunState and a real WaveManager run
## the flow; the save goes to memory, never to the real save file.

const BOSS_WAVES: Array[int] = [5, 10, 15, 20, 25, 30]
const MAX_LOG_LINES: int = 10
const FORTRESS_GROUP: StringName = &"fortress"
const HUD_SCENE := preload("res://ui/hud/hud.tscn")

var _run_state: RunState
var _wave_manager: WaveManager
var _boss_index: int = 0
var _real_repository: SaveRepository
var _summary_seen: bool = false
var _info: Label
var _log_label: Label
var _log_lines: Array[String] = []


## Keeps the save in memory so a playtest never touches the real save.
class MemorySaveRepository extends SaveRepository:
	var stored: Dictionary = {}
	func has_data() -> bool: return not stored.is_empty()
	func load_data() -> Dictionary:
		last_error = OK if has_data() else ERR_FILE_NOT_FOUND
		return stored.duplicate(true)
	func save_data(envelope: Dictionary) -> Error:
		stored = envelope.duplicate(true)
		last_error = OK
		return OK


## Stands in for a destroyed Fortress: the wave manager only reads its health.
class FakeFortress extends Node:
	var health: HealthComponent


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # hotkeys keep working under Pause
	_real_repository = SaveManager.repository
	SaveManager.set_repository(MemorySaveRepository.new())
	SaveManager.load_save()
	_build_ui()
	EventBus.weapon_gained.connect(_on_weapon_gained)
	EventBus.wave_summary_ready.connect(_on_summary_ready)
	new_run()


func _exit_tree() -> void:
	if EventBus.weapon_gained.is_connected(_on_weapon_gained):
		EventBus.weapon_gained.disconnect(_on_weapon_gained)
	if EventBus.wave_summary_ready.is_connected(_on_summary_ready):
		EventBus.wave_summary_ready.disconnect(_on_summary_ready)
	SaveManager.set_repository(_real_repository)
	SaveManager.load_save()


func _build_ui() -> void:
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.position = Vector2(-16, 16)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_info = Label.new()
	box.add_child(_info)
	_log_label = Label.new()
	box.add_child(_log_label)
	_info.text = """[BOSS WEAPON DROP PLAYTEST]
1 clear the next boss wave (5, 10, 15, 20, 25, 30)
2 lose the next boss wave on the same frame
3 boss dies in the Hazard Trial room, wave ends with no real boss
R new run (new seed) | S print seed and owned weapons"""


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return
	match event.physical_keycode:
		KEY_1:
			clear_next_boss_wave()
		KEY_2:
			lose_next_boss_wave()
		KEY_3:
			hazard_boss_then_wave_end()
		KEY_R:
			new_run()
		KEY_S:
			print_status()


## Wave of the next boss; stays at the last one once the list is used up.
func _next_boss_wave() -> int:
	return BOSS_WAVES[mini(_boss_index, BOSS_WAVES.size() - 1)]


func clear_next_boss_wave() -> void:
	var wave := _next_boss_wave()
	_begin_action("Boss wave %d cleared" % wave)
	_wave_manager.current_wave = wave
	_wave_manager.start_prep()
	EventBus.boss_defeated.emit()
	_wave_manager._end_combat_to_summary()
	_boss_index += 1
	_end_action()


func lose_next_boss_wave() -> void:
	var wave := _next_boss_wave()
	_begin_action("Boss wave %d lost (boss dies, Fortress at 0 HP); the run stays lost, press R" % wave)
	var fortress := FakeFortress.new()
	fortress.add_to_group(FORTRESS_GROUP)
	fortress.health = HealthComponent.new()
	fortress.add_child(fortress.health)
	add_child(fortress)
	fortress.health.hp = 0
	_wave_manager.current_wave = wave
	_wave_manager.start_prep()
	EventBus.boss_defeated.emit()
	_wave_manager._end_combat_to_summary()
	fortress.free()
	_end_action()


func hazard_boss_then_wave_end() -> void:
	var wave := _next_boss_wave()
	_begin_action("Boss wave %d: boss dies in the Hazard Trial room" % wave)
	_wave_manager.current_wave = wave
	_wave_manager.start_prep()
	_wave_manager.wave_state = Enums.WaveState.HAZARD_TRIAL
	EventBus.boss_defeated.emit()
	_wave_manager.wave_state = Enums.WaveState.BOSS_COMBAT
	_wave_manager._end_combat_to_summary()
	_end_action()


func new_run() -> void:
	if _wave_manager != null:
		_wave_manager.free()
	if _run_state != null:
		_run_state.free()
	_boss_index = 0
	_run_state = RunState.new()
	add_child(_run_state)
	_run_state.run_seed = randi()
	_run_state.owned_weapons.clear()
	_run_state.owned_weapons.append(RunState.BASE_WEAPON)
	_run_state.equipped_weapon = RunState.BASE_WEAPON
	_wave_manager = WaveManager.new()
	_wave_manager.auto_advance_summary = false
	_wave_manager.enable_reward_pick = false
	_wave_manager.enable_victory_screen = false
	add_child(_wave_manager)
	EventBus.run_started.emit()
	EventBus.state_changed.emit(&"PREP")
	_log("New run, seed %d" % _run_state.run_seed)
	_log_owned()


func print_status() -> void:
	_log("Seed %d, owned: %s" % [_run_state.run_seed, ", ".join(_owned_names())])


func _begin_action(text: String) -> void:
	_summary_seen = false
	_log(text)


func _end_action() -> void:
	if not _summary_seen:
		_log("No summary built")
	_log_owned()


func _log_owned() -> void:
	_log("Owned %d/6, equipped: %s" % [_run_state.owned_weapons.size(), _run_state.equipped_weapon])


func _owned_names() -> Array[String]:
	var names: Array[String] = []
	for id in _run_state.owned_weapons:
		names.append(String(id))
	return names


func _on_weapon_gained(id: StringName) -> void:
	_log("weapon_gained: %s" % id)


func _on_summary_ready(summary: Dictionary) -> void:
	_summary_seen = true
	var gained: StringName = summary.get("weapon_gained", &"")
	_log("Summary weapon_gained: '%s'" % gained)


func _log(text: String) -> void:
	print(text)
	_log_lines.append(text)
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	if _log_label != null:
		_log_label.text = "\n".join(_log_lines)
