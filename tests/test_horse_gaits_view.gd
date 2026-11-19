extends Node3D
## Visual check of the Rider's horse gaits: one Rider moving along a ground with lines, a side
## camera that follows it, and the gait it plays shown on screen. Not shipped. F6 only; headless
## it runs a short smoke check and quits.
## Keys: 1 walk (2 m/s), 2 gallop (5.5 m/s), 3 stop, Left / Right speed -/+ 0.5 m/s,
## A auto (walk, gallop, stop in turn), S slow motion x0.25 to see each step.

const RIDER := preload("res://contents/assets/characters/enemy and boss/rider/rider_model.tscn")

var _rider: Node3D
var _cam: Camera3D
var _label: Label
var _speed := 0.0
var _auto := false
var _auto_left := 0.0
var _auto_step := 0
var _slow := false


func _ready() -> void:
	_build_stage()
	_rider = RIDER.instantiate()
	add_child(_rider)
	if DisplayServer.get_name() == "headless":
		# Smoke check: the scene builds and the horse answers to the speed.
		for s in [2.0, 5.5, 0.0]:
			for i in 16:
				_rider.position.z += s * 0.05
				_rider.call(&"_process", 0.05)
			print("[gaits] %.1f m/s -> %s" % [s, _rider.call(&"get_gait")])
		get_tree().quit()
		return
	_set_speed(2.0)


func _build_stage() -> void:
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 5.0
	add_child(_cam)
	_cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#3A4A5A")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	add_child(env)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 4000)
	ground.mesh = plane
	ground.material_override = load("res://art/materials/env_grass.tres")
	ground.position = Vector3(0, 0, 1900)
	add_child(ground)
	# Lines across the ground every 2 m, so the forward motion reads.
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(1, 1, 1, 0.5)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for z in range(-100, 4000, 2):
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(12, 0.01, 0.06)
		line.mesh = box
		line.material_override = line_mat
		line.position = Vector3(0, 0.01, z)
		add_child(line)
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_label)


func _set_speed(value: float) -> void:
	_speed = clampf(value, 0.0, 8.0)


func _process(delta: float) -> void:
	if _rider == null or DisplayServer.get_name() == "headless":
		return
	if _auto:
		_auto_left -= delta
		if _auto_left <= 0.0:
			_auto_step = (_auto_step + 1) % 3
			_set_speed([2.0, 5.5, 0.0][_auto_step])
			_auto_left = 3.0
	_rider.position.z += _speed * delta
	# Side view from the left of the horse, following it.
	_cam.look_at_from_position(_rider.position + Vector3(-9, 1.6, 0), _rider.position + Vector3(0, 1.1, 0))
	var gait: StringName = _rider.call(&"get_gait")
	_label.text = "\n".join([
		"1 walk   2 gallop   3 stop   Left/Right speed   A auto: %s   S slow motion: %s" % ["on" if _auto else "off", "on" if _slow else "off"],
		"speed %.1f m/s   horse: %s" % [_speed, "standing" if gait == &"" else String(gait)],
	])


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_auto = false
			_set_speed(2.0)
		KEY_2:
			_auto = false
			_set_speed(5.5)
		KEY_3:
			_auto = false
			_set_speed(0.0)
		KEY_LEFT:
			_set_speed(_speed - 0.5)
		KEY_RIGHT:
			_set_speed(_speed + 0.5)
		KEY_A:
			_auto = not _auto
			_auto_left = 0.0
		KEY_S:
			_slow = not _slow
			Engine.time_scale = 0.25 if _slow else 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0
