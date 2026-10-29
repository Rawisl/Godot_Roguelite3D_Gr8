extends Node3D
## Manual playtest for Recall, Deploy and Commander mode. Not shipped. Run with F6.
## Tab is the real mode_switch action, the number keys set up the situations to try.

const COMMANDER_SCENE := preload("res://entities/commander/commander.tscn")
const GRUNT_SCENE := preload("res://entities/enemy/grunt.tscn")
const BRUTE_SCENE := preload("res://entities/enemy/brute.tscn")

const DEPLOY_POINT := Vector3(-13.0, 0.0, 0.0)
const COMMAND_POST := Vector3(-20.0, 3.0, 0.0)
const ZONE_CENTER := Vector3(-12.0, 0.0, 0.0)
const ZONE_RADIUS := 5.0
const START_POS := Vector3(0.0, 0.05, 0.0)
const DUMMY_HP := 99999

var _commander: CharacterBody3D
var _switch: ModeSwitch
var _state: StringName = &"COMBAT"
var _log_lines: Array[String] = []
var _info: Label
var _log_label: Label
var _camera_rig: Node3D


func _ready() -> void:
	_build_world()
	_build_ui()
	_commander = COMMANDER_SCENE.instantiate() as CharacterBody3D
	_commander.position = START_POS
	add_child(_commander)
	_switch = _commander.get_node("ModeSwitch") as ModeSwitch
	EventBus.state_changed.emit(_state)
	EventBus.mode_changed.emit(&"FRONTLINE")
	EventBus.recall_started.connect(func(duration: float) -> void: _log("Recall started (%.1f s)" % duration))
	EventBus.recall_cancelled.connect(func() -> void: _log("Recall cancelled"))
	EventBus.recall_completed.connect(func() -> void: _log("Recall completed"))
	EventBus.mode_changed.connect(func(mode: StringName) -> void: _log("Mode -> %s" % mode))
	EventBus.mode_switch_denied.connect(func(reason: StringName, remaining: float) -> void:
		_log("Denied: %s (%.1f s)" % [reason, remaining])
	)
	_commander.health.damaged.connect(func(amount: int, _hit: DamageInfo) -> void:
		_log("Commander took %d damage (%d/%d)" % [amount, _commander.health.hp, _commander.health.max_hp])
	)
	_log("Ready. Tab switches mode. Keys 1-6 set up situations, R resets.")


func _process(delta: float) -> void:
	if is_instance_valid(_commander):
		_camera_rig.global_position = _camera_rig.global_position.lerp(_commander.global_position, clampf(delta * 6.0, 0.0, 1.0))
	_update_info()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return
	match event.physical_keycode:
		KEY_1:
			_crowd_gate()
		KEY_2:
			_commander.take_damage(DamageInfo.new(30, Enums.DamageType.SLASH))
		KEY_3:
			_state = &"PREP" if _state != &"PREP" else &"COMBAT"
			EventBus.state_changed.emit(_state)
			_log("Wave state -> %s" % _state)
		KEY_4:
			_clear_enemies()
		KEY_5:
			_spawn_enemy(GRUNT_SCENE, DEPLOY_POINT + Vector3(0.0, 0.0, 1.5), false)
			_spawn_enemy(BRUTE_SCENE, DEPLOY_POINT + Vector3(0.0, 0.0, -1.5), false)
			_log("Spawned a grunt and a brute next to the deploy point")
		KEY_6:
			var pos: Vector3 = _commander.global_position + Vector3(3.0, 0.0, 0.0)
			_spawn_enemy(GRUNT_SCENE, pos, true)
			_log("Spawned a hunting grunt")
		KEY_R:
			get_tree().reload_current_scene()


## Fills the deploy point and the first ring around it with idle grunts.
func _crowd_gate() -> void:
	_spawn_enemy(GRUNT_SCENE, DEPLOY_POINT, false)
	for i in 8:
		var offset := Vector3.RIGHT.rotated(Vector3.UP, TAU * float(i) / 8.0)
		_spawn_enemy(GRUNT_SCENE, DEPLOY_POINT + offset, false)
	_log("Gate crowded. Recall, then Tab to Deploy.")


func _clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		enemy.queue_free()
	_log("Enemies cleared")


## active: the enemy hunts the commander. Otherwise it stands still but can still be staggered.
func _spawn_enemy(scene: PackedScene, pos: Vector3, active: bool) -> void:
	var enemy := scene.instantiate() as Enemy
	add_child(enemy)
	enemy.global_position = pos
	enemy.spawn_grace = false
	enemy.is_in_spawn_zone = false
	if not active:
		enemy.set_physics_process(false)
	if enemy.health != null:
		enemy.health.max_hp = DUMMY_HP
		enemy.health.hp = DUMMY_HP


func _update_info() -> void:
	if not is_instance_valid(_commander):
		return
	var phase_name: String = ModeSwitch.Phase.keys()[_switch.phase]
	_info.text = """[MODE SWITCH PLAYTEST]
Mode: %s     Phase: %s     Wave state: %s
HP: %d / %d
Switch cooldown: %.1f s
Aura source: %s     Deploying: %s
Zone: inside = %s

[Tab] Recall / Deploy   [WASD] move   [Left click] attack   [Space] dodge
[1] Crowd the gate   [2] Take 30 damage   [3] Toggle PREP / COMBAT
[4] Clear enemies   [5] Grunt + Brute for the shockwave   [6] Hunting grunt   [R] Reset""" % [
		"COMMANDER" if _commander.is_commander_mode else "FRONTLINE", phase_name, _state,
		_commander.health.hp, _commander.health.max_hp,
		_switch.cooldown_left,
		_commander.is_aura_source(), _commander.is_deploying,
		Vector2(_commander.global_position.x - ZONE_CENTER.x, _commander.global_position.z - ZONE_CENTER.z).length() <= ZONE_RADIUS,
	]


func _log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > 8:
		_log_lines.pop_front()
	if _log_label != null:
		_log_label.text = "\n".join(_log_lines)


func _build_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 45.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.65, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	add_child(env)

	var ground := StaticBody3D.new()
	ground.collision_mask = 0
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120.0, 0.5, 60.0)
	ground_shape.shape = box
	ground.add_child(ground_shape)
	var ground_mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = box.size
	ground_mesh.mesh = plane
	ground_mesh.material_override = _flat_material(Color(0.35, 0.55, 0.3))
	ground.add_child(ground_mesh)
	ground.position = Vector3(0.0, -0.25, 0.0)
	add_child(ground)

	var markers := Node3D.new()
	markers.name = "Markers"
	add_child(markers)
	_add_marker(markers, &"DeployPoint", DEPLOY_POINT, Color(0.2, 0.9, 0.3))
	_add_marker(markers, &"CommandPost", COMMAND_POST, Color(0.3, 0.5, 1.0))

	var zone := Area3D.new()
	zone.name = "ReturnZone"
	var zone_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = ZONE_RADIUS
	cylinder.height = 4.0
	zone_shape.shape = cylinder
	zone.add_child(zone_shape)
	zone.position = ZONE_CENTER + Vector3(0.0, 2.0, 0.0)
	markers.add_child(zone)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = ZONE_RADIUS - 0.1
	torus.outer_radius = ZONE_RADIUS
	ring.mesh = torus
	ring.material_override = _flat_material(Color(1.0, 0.85, 0.2))
	ring.position = ZONE_CENTER + Vector3(0.0, 0.05, 0.0)
	add_child(ring)

	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(2.0, 0.5, 2.0)
	post.mesh = post_mesh
	post.material_override = _flat_material(Color(0.3, 0.5, 1.0))
	post.position = COMMAND_POST + Vector3(0.0, -0.3, 0.0)
	add_child(post)

	_camera_rig = Node3D.new()
	add_child(_camera_rig)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24.0
	camera.position = Vector3(16.0, 16.0, 16.0)
	camera.rotation_degrees = Vector3(-35.0, 45.0, 0.0)
	_camera_rig.add_child(camera)
	camera.make_current()


func _add_marker(parent: Node3D, marker_name: StringName, pos: Vector3, color: Color) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = pos
	parent.add_child(marker)
	var disc := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.4
	cylinder.bottom_radius = 0.4
	cylinder.height = 0.1
	disc.mesh = cylinder
	disc.material_override = _flat_material(color)
	marker.add_child(disc)


func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	margin.offset_left = 16.0
	margin.offset_top = 16.0
	margin.offset_right = 760.0
	margin.offset_bottom = 460.0
	layer.add_child(margin)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 16)
	box.add_child(_info)
	_log_label = Label.new()
	_log_label.add_theme_font_size_override("font_size", 14)
	_log_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	box.add_child(_log_label)
