extends Node3D
## Playable check for Emergency repair. Run with F6 and use the keys listed on screen.

const FORTRESS_SCENE := preload("res://entities/fortress/fortress.tscn")
const COMMANDER_SCENE := preload("res://entities/commander/commander.tscn")
const CAMERA_OFFSET := Vector3(16, 16, 16)

var _fortress: Fortress
var _commander: CharacterBody3D
var _repair: EmergencyRepair
var _camera: Camera3D
var _info: Label
var _log_label: Label
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # hotkeys keep working under Pause
	_build_world()
	_fortress = FORTRESS_SCENE.instantiate()
	_fortress.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_fortress)
	_commander = COMMANDER_SCENE.instantiate()
	_commander.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_commander)
	_commander.position = Vector3(0, 0, 6)
	_repair = _commander.get_node("EmergencyRepair")
	EventBus.emergency_repair_denied.connect(func(reason: StringName) -> void: _log("DENIED: %s" % reason))
	EventBus.emergency_repair_charge_granted.connect(func(c: int) -> void: _log("Bonus charge, now %d/3" % c))
	EventBus.fortress_repaired.connect(func(amount: int, source: StringName) -> void: _log("Fortress +%d HP (%s)" % [amount, source]))
	_log("Press F2 for Commander mode, F1 to damage the Fortress, then R.")


func _build_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 45, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.65, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	add_child(env)
	var ground := StaticBody3D.new()
	ground.process_mode = Node.PROCESS_MODE_PAUSABLE
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 0.5, 60)
	shape.shape = box
	ground.add_child(shape)
	ground.position.y = -0.25
	add_child(ground)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 22.0
	add_child(_camera)
	_camera.global_position = CAMERA_OFFSET
	_camera.look_at(Vector3.ZERO)
	_camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	layer.add_child(panel)
	var box_ui := VBoxContainer.new()
	panel.add_child(box_ui)
	_info = Label.new()
	box_ui.add_child(_info)
	_log_label = Label.new()
	_log_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	box_ui.add_child(_log_label)


func _process(_delta: float) -> void:
	if _repair == null:
		return
	var left := _repair.get_cooldown_left()
	_info.text = """[EMERGENCY REPAIR PLAYTEST]
Mode: %s    Speed: x%d%s
Fortress HP: %d/%d
Charges: %d/3    Cooldown: %s

R repair (Commander mode only)
F1 damage Fortress by 30%% | F2 toggle Commander mode
F3 cycle speed | F4 pause | F7 boss killed + wave cleared (+1 charge)
F8 new run (3/3, cooldown 0)""" % [
		"COMMANDER" if _commander.is_commander_mode else "FRONTLINE",
		TimeManager.get_time_scale(), "  PAUSED" if TimeManager.is_paused else "",
		_fortress.get_hp(), _fortress.get_max_hp(),
		_repair.charges, "READY" if left <= 0.0 else "%.1f s" % left]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return
	match event.physical_keycode:
		KEY_F1:
			_fortress.health.hp = maxi(1, _fortress.health.hp - int(_fortress.get_max_hp() * 0.3))
		KEY_F2:
			EventBus.mode_changed.emit(&"FRONTLINE" if _commander.is_commander_mode else &"COMMANDER")
		KEY_F3:
			TimeManager.set_time_scale(1 if TimeManager.get_time_scale() == 3 else TimeManager.get_time_scale() + 1)
		KEY_F4:
			if TimeManager.is_paused:
				TimeManager.release_pause(TimeManager.REASON_USER)
			else:
				TimeManager.request_pause(TimeManager.REASON_USER)
		KEY_F7:
			EventBus.boss_defeated.emit()
			EventBus.wave_cleared.emit(5)
		KEY_F8:
			TimeManager.reset()
			EventBus.run_started.emit()


func _log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > 8:
		_log_lines.pop_front()
	if _log_label != null:
		_log_label.text = "\n".join(_log_lines)
