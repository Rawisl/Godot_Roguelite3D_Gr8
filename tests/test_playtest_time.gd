extends Node3D
## Playable arena to feel TimeManager and commander input: speed buttons, Pause (Esc), the
## three clocks, three 5 s timers, the input buffer and held-key blocking. Fight the dummies
## at x1/x2/x3 to check attack, dodge and cooldown feel.

const COMMANDER_SCENE := preload("res://entities/commander/commander.tscn")
const GRUNT_SCENE := preload("res://entities/enemy/grunt.tscn")
const GRASS := preload("res://art/materials/env_grass.tres")

const TIMER_SECONDS := 5.0

var _commander: CharacterBody3D
var _spinner: MeshInstance3D
var _info: Label
var _timer_info: Label
var _speed_buttons: Dictionary = {}  # level -> Button
var _pause_button: Button
var _mode_button: Button
var _timers: Array[Dictionary] = []

func _ready() -> void:
	# The UI and Esc must keep working while paused; the world below pauses normally.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var world := Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	_build_world(world)
	_build_ui()
	TimeManager.reset()

func _exit_tree() -> void:
	TimeManager.reset()

func _process(delta: float) -> void:
	if not get_tree().paused:
		_spinner.rotate_y(delta * 2.0)
	_update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if TimeManager.has_pause_reason(TimeManager.REASON_USER):
			TimeManager.release_pause(TimeManager.REASON_USER)
		else:
			TimeManager.request_pause(TimeManager.REASON_USER)
		get_viewport().set_input_as_handled()

func _build_world(world: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 45, 0)
	sun.shadow_enabled = true
	world.add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.65, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)

	var ground := StaticBody3D.new()
	ground.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(80, 0.5, 80)
	shape.shape = box_shape
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(80, 0.5, 80)
	mesh.mesh = box_mesh
	mesh.set_surface_override_material(0, GRASS)
	ground.add_child(mesh)
	world.add_child(ground)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 22.0
	world.add_child(camera)
	camera.look_at_from_position(Vector3(16, 16, 16), Vector3.ZERO)
	camera.current = true

	_commander = COMMANDER_SCENE.instantiate() as CharacterBody3D
	world.add_child(_commander)
	_commander.health.hp = _commander.health.max_hp

	for pos in [Vector3(4, 0, 0), Vector3(-5, 0, 3), Vector3(0, 0, 6), Vector3(5, 0, -5)]:
		_spawn_dummy(world, pos)

	# A spinning block makes the world speed and the Pause freeze easy to see.
	_spinner = MeshInstance3D.new()
	var spinner_mesh := BoxMesh.new()
	spinner_mesh.size = Vector3(2.0, 0.4, 0.4)
	_spinner.mesh = spinner_mesh
	_spinner.position = Vector3(-6, 1.5, -6)
	world.add_child(_spinner)

func _spawn_dummy(world: Node3D, pos: Vector3) -> void:
	var enemy := GRUNT_SCENE.instantiate() as Enemy
	world.add_child(enemy)
	enemy.position = pos
	enemy.spawn_grace = false
	enemy.is_in_spawn_zone = false
	enemy.speed_multiplier = 0.6
	enemy.health.max_hp = 99999
	enemy.health.hp = 99999

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	margin.position = Vector2(16, 16)
	layer.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	_info = Label.new()
	box.add_child(_info)

	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	for level in [1, 2, 3]:
		var button := _make_button("x%d" % level)
		button.pressed.connect(func(): TimeManager.toggle_time_scale(level))
		buttons.add_child(button)
		_speed_buttons[level] = button
	_pause_button = _make_button("Pause")
	_pause_button.pressed.connect(_toggle_user_pause)
	buttons.add_child(_pause_button)

	_mode_button = _make_button("Commander mode (hold WASD while toggling)")
	_mode_button.pressed.connect(_toggle_mode)
	box.add_child(_mode_button)

	var start_timers := _make_button("Start 3 x %d s timers" % int(TIMER_SECONDS))
	start_timers.pressed.connect(_start_timers)
	box.add_child(start_timers)
	_timer_info = Label.new()
	box.add_child(_timer_info)

func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	# Keeps Space for Dodge instead of activating the focused button.
	button.focus_mode = Control.FOCUS_NONE
	return button

func _toggle_user_pause() -> void:
	if TimeManager.has_pause_reason(TimeManager.REASON_USER):
		TimeManager.release_pause(TimeManager.REASON_USER)
	else:
		TimeManager.request_pause(TimeManager.REASON_USER)

func _toggle_mode() -> void:
	EventBus.mode_changed.emit(&"FRONTLINE" if _commander.is_commander_mode else &"COMMANDER")

func _start_timers() -> void:
	_timers.clear()
	var sources := {
		"game time (scaled, pauses)": TimeManager.wait_game(TIMER_SECONDS),
		"pausable real (not scaled, pauses)": TimeManager.wait_pausable_real(TIMER_SECONDS),
		"real time (not scaled, never pauses)": TimeManager.wait_real(TIMER_SECONDS),
	}
	for title in sources:
		var entry := {"title": title, "start": TimeManager.real_time, "end": -1.0}
		_timers.append(entry)
		sources[title].connect(func(): entry["end"] = TimeManager.real_time)

func _update_ui() -> void:
	for level in _speed_buttons:
		_speed_buttons[level].set_pressed_no_signal(TimeManager.get_time_scale() == level)
		_speed_buttons[level].disabled = TimeManager.is_paused
	_pause_button.set_pressed_no_signal(TimeManager.is_paused)
	_mode_button.set_pressed_no_signal(_commander.is_commander_mode)

	_info.text = """[TIME PLAYTEST]
time_scale: x%d    paused: %s    Engine.time_scale: %.1f
game time: %.1f s
pausable real time: %.1f s
real time: %.1f s
Dodge cooldown left: %.2f s    Battle Cry cooldown left: %.2f s
Combo hit: %d    attacking: %s    dodging: %s    skill: %s
Buffered command: %s    Blocked (release to use again): %s
Esc / Pause button: pause. WASD, Space, Q, left click to fight.""" % [
			TimeManager.get_time_scale(), TimeManager.is_paused, Engine.time_scale,
			TimeManager.game_time, TimeManager.pausable_real_time, TimeManager.real_time,
			_commander._dodge_cooldown_timer, _commander._battle_cry_cd_timer,
			_commander.current_combo_hit, _commander.is_attacking, _commander.is_dodging,
			_commander.is_using_skill, _commander._cmd_input.get_buffered(),
			_commander._cmd_input.get_blocked()]

	var lines: Array[String] = []
	for entry in _timers:
		if entry["end"] < 0.0:
			lines.append("%s: running, %.1f real s so far" % [entry["title"], TimeManager.real_time - entry["start"]])
		else:
			lines.append("%s: fired after %.1f real s" % [entry["title"], entry["end"] - entry["start"]])
	_timer_info.text = "\n".join(lines)
