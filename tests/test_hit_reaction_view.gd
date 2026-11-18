extends Node3D
## Visual check of the hit reaction: the real Grunt, Archer, Brute, Bulwark and commander stand in
## a row under a game-like camera, playing their idle or walk clip, and get hit on a key.
## Their AI is switched off, only their AnimationPlayer runs, so they stay in place.
## The sword and arrow sparks of HitFxManager play too. Not shipped.
## Keys: 1..5 hit one unit, Space hit all, A auto-hit every 0.7 s, R Reduce flashing on/off,
## D a damage over time tick (nothing should happen), F slow freeze (x10 so it can be seen),
## Up / Down game speed.

const UNITS := [
	["Grunt", preload("res://entities/enemy/grunt.tscn")],
	["Archer", preload("res://entities/enemy/archer.tscn")],
	["Brute", preload("res://entities/enemy/brute.tscn")],
	["Bulwark", preload("res://entities/enemy/bulwark.tscn")],
	["Commander", preload("res://entities/commander/commander.tscn")],
]

var _units: Array[Node3D] = []
var _manager: HitReactionManager
var _label: Label
var _auto := false
var _auto_left := 0.0
var _reduce := false
var _slow := false
var _hits := 0


func _ready() -> void:
	_build_stage()
	_manager = HitReactionManager.new()
	add_child(_manager)
	add_child(HitFxManager.new())
	for i in UNITS.size():
		var unit: Node3D = UNITS[i][1].instantiate()
		unit.position = Vector3((i - 2) * 3.2, 0, 0)
		add_child(unit)
		_hold_still(unit)
		_units.append(unit)
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_label)
	_update_label()


func _build_stage() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 11.0
	add_child(cam)
	cam.look_at_from_position(Vector3(7.255, 21.213, 19.934) * 0.6, Vector3(0, 0.8, 0))
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
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
	plane.size = Vector2(30, 14)
	ground.mesh = plane
	ground.material_override = load("res://art/materials/env_grass.tres")
	add_child(ground)


## AI off, animation on: the unit stays where it is and keeps its idle or walk clip playing.
func _hold_still(unit: Node3D) -> void:
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	for node in unit.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		var clip := ""
		for name in player.get_animation_list():
			var lower := String(name).to_lower()
			if "idle" in lower:
				clip = name
				break
			if clip == "" and "walk" in lower:
				clip = name
		if clip != "":
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			player.play(clip)


func _hit(unit: Node3D, dot := false) -> void:
	var health := unit.find_children("*", "HealthComponent", true, false)
	if health.is_empty():
		return
	var h := health[0] as HealthComponent
	var info := DamageInfo.new(5)
	info.is_dot = dot
	info.hit_direction = Vector3(0, 0, -1)
	h.take_damage(info)
	h.heal(5)
	_hits += 1
	_update_label()


func _process(delta: float) -> void:
	if _auto:
		_auto_left -= delta
		if _auto_left <= 0.0:
			_auto_left = 0.7
			for unit in _units:
				_hit(unit)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			_hit(_units[key.keycode - KEY_1])
		KEY_SPACE:
			for unit in _units:
				_hit(unit)
		KEY_A:
			_auto = not _auto
		KEY_R:
			_reduce = not _reduce
			EventBus.settings_changed.emit(&"reduce_flash", _reduce)
		KEY_D:
			for unit in _units:
				_hit(unit, true)
		KEY_F:
			_slow = not _slow
			_manager.freeze_time = 0.5 if _slow else 0.05
		KEY_UP:
			Engine.time_scale = minf(Engine.time_scale + 1.0, 3.0)
		KEY_DOWN:
			Engine.time_scale = maxf(Engine.time_scale - 1.0, 1.0)
	_update_label()


func _update_label() -> void:
	if _label == null:
		return
	_label.text = "\n".join([
		"1..5 hit Grunt / Archer / Brute / Bulwark / Commander   Space: hit all   D: DoT tick",
		"A auto-hit: %s   R Reduce flashing: %s   F slow freeze (x10): %s   Up/Down speed: x%d" % [
			"on" if _auto else "off", "on" if _reduce else "off", "on" if _slow else "off", int(Engine.time_scale)],
		"hits: %d" % _hits,
	])


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	EventBus.settings_changed.emit(&"reduce_flash", false)
