extends Node3D
## Playable arena for SkillRunner and Whirlwind. Run with F6, then play with the keys listed on screen.
## Dummies stand still with 99999 HP and show the last damage they took above their head.

const COMMANDER_SCENE := preload("res://entities/commander/commander.tscn")
const GRUNT_SCENE := preload("res://entities/enemy/grunt.tscn")
const BRUTE_SCENE := preload("res://entities/enemy/brute.tscn")
const BULWARK_SCENE := preload("res://entities/enemy/bulwark.tscn")
const CAMERA_OFFSET := Vector3(16, 16, 16)
const DUMMY_HP := 99999

var _commander: CharacterBody3D
var _camera: Camera3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _dummies: Array[Enemy] = []
var _log_lines: Array[String] = []
var _whirlwind_level: int = 0
var _info: Label
var _log_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # hotkeys keep working under Pause; the arena below is pausable
	_build_world()
	_build_hud()
	EventBus.skill_cast.connect(_on_skill_cast)
	_reset_arena()


func _build_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 45, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.65, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.6
	add_child(env)

	var ground := StaticBody3D.new()
	ground.process_mode = Node.PROCESS_MODE_PAUSABLE
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 0.5, 80)
	shape.shape = box
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.35, 0.55, 0.3)
	mesh.material_override = grass
	ground.add_child(mesh)
	ground.position.y = -0.25
	add_child(ground)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 22.0
	add_child(_camera)
	_camera.global_position = CAMERA_OFFSET
	_camera.look_at(Vector3.ZERO)
	_camera.make_current()

	# Flat ring that shows the 3 m sweep around the commander.
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.94
	torus.outer_radius = 3.06
	_ring.mesh = torus
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(1, 0.8, 0.2, 0.25)
	_ring.material_override = _ring_mat
	add_child(_ring)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 16)
	box.add_child(_info)
	_log_label = Label.new()
	_log_label.add_theme_font_size_override("font_size", 14)
	_log_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	box.add_child(_log_label)


func _reset_arena() -> void:
	if _commander != null:
		_commander.queue_free()
	for dummy in _dummies:
		if is_instance_valid(dummy):
			dummy.queue_free()
	_dummies.clear()
	_whirlwind_level = 0

	_commander = COMMANDER_SCENE.instantiate() as CharacterBody3D
	_commander.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_commander)
	_commander.health.hp = _commander.health.max_hp

	# Rings at 2.0 m and 2.9 m are inside the sweep, 3.4 m must stay untouched.
	for i in 4:
		_spawn(GRUNT_SCENE, Vector3.RIGHT.rotated(Vector3.UP, TAU * i / 4.0) * 2.0, "Grunt 2.0 m")
	for i in 6:
		_spawn(GRUNT_SCENE, Vector3.RIGHT.rotated(Vector3.UP, TAU * (i + 0.5) / 6.0) * 2.9, "Grunt 2.9 m")
	for i in 4:
		_spawn(GRUNT_SCENE, Vector3.RIGHT.rotated(Vector3.UP, TAU * (i + 0.5) / 4.0) * 3.4, "Grunt 3.4 m (OUT)")
	_spawn(BRUTE_SCENE, Vector3(0, 0, -6), "Brute 6 m (OUT)")
	_spawn(BRUTE_SCENE, Vector3(-2.0, 0, 1.0), "Brute 2.2 m")
	var boss := _spawn(BULWARK_SCENE, Vector3(1.5, 0, -2.0), "Bulwark ARMORED 2.5 m") as Bulwark
	if boss != null:
		boss.current_phase = Enums.BossPhase.ARMORED
	_log("Arena ready. F1 to learn / level up Whirlwind, then press 1.")


func _spawn(scene: PackedScene, pos: Vector3, title: String) -> Enemy:
	var enemy := scene.instantiate() as Enemy
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(enemy)
	enemy.position = pos
	enemy.spawn_grace = false
	enemy.is_in_spawn_zone = false
	enemy.set_physics_process(false)  # stands still
	enemy.health.max_hp = DUMMY_HP
	enemy.health.hp = DUMMY_HP
	var label := Label3D.new()
	label.position = Vector3(0, 2.4, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 36
	label.outline_size = 8
	label.pixel_size = 0.01
	label.text = title
	enemy.add_child(label)
	enemy.health.damaged.connect(func(amount: int, _info_unused: DamageInfo) -> void:
		label.text = "%s\n-%d (total %d)" % [title, amount, DUMMY_HP - enemy.health.hp]
		label.modulate = Color(1, 0.4, 0.3)
		get_tree().create_timer(0.4).timeout.connect(func() -> void:
			if is_instance_valid(label):
				label.modulate = Color.WHITE))
	_dummies.append(enemy)
	return enemy


func _process(_delta: float) -> void:
	if _commander == null or not is_instance_valid(_commander):
		return
	_camera.global_position = _commander.global_position + CAMERA_OFFSET
	_ring.global_position = _commander.global_position + Vector3(0, 0.05, 0)
	_ring_mat.albedo_color.a = lerpf(_ring_mat.albedo_color.a, 0.25, 0.1)
	_update_info()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return
	match event.physical_keycode:
		KEY_F1:
			_whirlwind_level = mini(_whirlwind_level + 1, GameConfig.skill_max_level)
			EventBus.reward_picked.emit(&"whirlwind", &"ACTIVE", _whirlwind_level)
			_log("Picked Whirlwind, level %d" % _whirlwind_level)
		KEY_F2:
			var to_commander: bool = not _commander.is_commander_mode
			EventBus.mode_changed.emit(&"COMMANDER" if to_commander else &"FRONTLINE")
			_log("Mode: %s" % ("COMMANDER (keys 1-3 must do nothing)" if to_commander else "FRONTLINE"))
		KEY_F3:
			var next := 1 if TimeManager.get_time_scale() == 3 else TimeManager.get_time_scale() + 1
			TimeManager.set_time_scale(next)
			_log("Game speed x%d" % next)
		KEY_F4:
			if TimeManager.is_paused:
				TimeManager.release_pause(TimeManager.REASON_USER)
			else:
				TimeManager.request_pause(TimeManager.REASON_USER)
			_log("Paused" if TimeManager.is_paused else "Resumed")
		KEY_R:
			TimeManager.reset()
			_reset_arena()


func _on_skill_cast(skill_id: StringName, slot: int, level: int, _origin: Vector3, radius: float) -> void:
	_ring_mat.albedo_color.a = 0.9
	_log("CAST %s slot %d level %d radius %.1f m" % [skill_id, slot + 1, level, radius])


func _update_info() -> void:
	var runner: SkillRunner = _commander.skill_runner
	var slots := PackedStringArray()
	for i in 3:
		var id := runner.get_skill_id(i)
		if id == &"":
			slots.append("[%d] empty" % (i + 1))
		else:
			var left := runner.get_cooldown_left(i)
			slots.append("[%d] %s L%d  %s" % [i + 1, id, runner.get_level(i), "READY" if left <= 0.0 else "%.1f s" % left])
	_info.text = """[SKILL RUNNER / WHIRLWIND PLAYTEST]
Mode: %s    Speed: x%d%s    HP: %d/%d
%s

WASD move | Space dodge | Left click attack
1 2 3 : skill slots (Frontline only)
F1 learn / level up Whirlwind | F2 toggle Commander mode
F3 cycle speed x1/x2/x3 | F4 pause | R reset arena""" % [
		"COMMANDER" if _commander.is_commander_mode else "FRONTLINE",
		TimeManager.get_time_scale(), "  PAUSED" if TimeManager.is_paused else "",
		_commander.health.hp, _commander.health.max_hp, "\n".join(slots)]


func _log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > 8:
		_log_lines.pop_front()
	if _log_label != null:
		_log_label.text = "\n".join(_log_lines)
