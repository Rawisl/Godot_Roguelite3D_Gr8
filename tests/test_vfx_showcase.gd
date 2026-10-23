extends Node

## Visual showcase of every hit and firing effect with the real models, on grass, from the
## game camera. Five stations loop forever, each with a caption:
## 1. commander combo 1-2-3 on a Grunt
## 2. Grunt and Brute hitting the commander
## 3. Arrow tower shooting a Grunt (muzzle flash, arrow, hit)
## 4. Cannon tower shelling a Grunt (muzzle flash, shell arc, blast)
## 5. enemy Archer shooting the commander
## Effects come from a HitFxManager, so its styles and budget can be tuned in the Inspector.
## Keys: 1-5 zoom onto a station, 0 back to the whole row at the game camera size.

const COMMANDER := preload("res://contents/assets/characters/commander/commander_model.tscn")
const GRUNT := preload("res://contents/assets/characters/enemy and boss/grunt_model.tscn")
const BRUTE := preload("res://contents/assets/characters/enemy and boss/brute_model.tscn")
const ARCHER := preload("res://contents/assets/characters/enemy and boss/archer_model.tscn")
const ARROW_TOWER := preload("res://contents/assets/towers/arrow_tower_model.tscn")
const CANNON_TOWER := preload("res://contents/assets/towers/cannon_tower_model.tscn")
const ARROW_SHELL := preload("res://contents/assets/towers/arrow_shell_model.tscn")
const CANNON_SHELL := preload("res://contents/assets/towers/cannon_shell_model.tscn")

const COMBO_ANIMS: Array[StringName] = [
	&"melee/Melee_1H_Attack_Chop",
	&"melee/Melee_1H_Attack_Slice_Diagonal",
	&"melee/Melee_2H_Attack_Spinning",
]
const ANIM_IDLE := &"general/Idle_A"
const ANIM_HIT := &"general/Hit_A"

## Seconds from the swing starting to the blade landing.
@export var strike_delay := 0.25
## Height of the tower muzzles above the tower base.
@export var muzzle_height := 3.0
## Ortho size for the whole row (about the in-game Frontline size) and for a single station.
@export var overview_size := 13.0
@export var station_size := 4.5
## Station to start on: 0 = whole row, 1-5 = one station.
@export_range(0, 5) var start_view := 1
## Blast radius of the cannon, as at level 1.
@export var blast_radius := 2.0

var fx: HitFxManager
var _cam: Camera3D
var _stations: Array[Vector3] = [Vector3.ZERO, Vector3(-10, 0, 0), Vector3(-5, 0, 0), Vector3.ZERO, Vector3(5, 0, 0), Vector3(10, 0, 0)]
## Everything sits on this, turned with the camera yaw so the stations line up across the screen.
var _stage := Node3D.new()

func _ready() -> void:
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(_cam)
	_cam.global_basis = Basis.from_euler(Vector3(deg_to_rad(-45), deg_to_rad(20), 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.shadow_enabled = true
	add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 40)
	ground.mesh = plane
	ground.material_override = preload("res://art/materials/env_grass.tres")
	add_child(ground)

	fx = HitFxManager.new()
	add_child(fx)
	_stage.rotation_degrees.y = 20.0
	add_child(_stage)

	_view(start_view)
	_station_combo(_stations[1])
	_station_enemy_melee(_stations[2])
	_station_arrow_tower(_stations[3])
	_station_cannon_tower(_stations[4])
	_station_enemy_archer(_stations[5])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.keycode - KEY_0
		if n >= 0 and n <= 5:
			_view(n)


## 0 = the whole row at about the game camera size, 1-5 = close on one station.
func _view(n: int) -> void:
	var focus := _stage.transform * (_stations[n] + Vector3(0, 0.8, 0))
	_cam.size = overview_size if n == 0 else station_size
	_cam.global_position = focus + _cam.global_basis.z * 30.0


## 1. Commander combo 1-2-3 on a Grunt.
func _station_combo(at: Vector3) -> void:
	_caption(at, "Combo chỉ huy 1-2-3")
	var cmd := _spawn(COMMANDER, at + Vector3(-0.9, 0, 0))
	var grunt := _spawn(GRUNT, at + Vector3(0.9, 0, 0))
	_face(cmd, grunt)
	_face(grunt, cmd)
	while is_inside_tree():
		for i in 3:
			_anim(cmd, COMBO_ANIMS[i], 1.5)
			await _wait(strike_delay)
			fx.play_sword(_chest(grunt, cmd), _flat(grunt.global_position - cmd.global_position), fx.slash)
			_anim(grunt, ANIM_HIT)
			await _wait(0.5)
		_anim(cmd, ANIM_IDLE)
		_anim(grunt, ANIM_IDLE)
		await _wait(1.2)


## 2. Grunt, then Brute, hitting the commander.
func _station_enemy_melee(at: Vector3) -> void:
	_caption(at, "Grunt / Brute đánh chỉ huy")
	var cmd := _spawn(COMMANDER, at + Vector3(-1.0, 0, 0))
	var grunt := _spawn(GRUNT, at + Vector3(0.8, 0, -0.9))
	var brute := _spawn(BRUTE, at + Vector3(1.0, 0, 1.0))
	_face(grunt, cmd)
	_face(brute, cmd)
	_face(cmd, grunt)
	while is_inside_tree():
		for pair in [[grunt, fx.slash, &"melee/Melee_1H_Attack_Slice_Diagonal"],
				[brute, fx.slash, &"melee/Melee_1H_Attack_Slice_Horizontal"]]:
			var attacker: Node3D = pair[0]
			_anim(attacker, pair[2], 1.3)
			await _wait(strike_delay + 0.1)
			fx.play_sword(_chest(cmd, attacker), _flat(cmd.global_position - attacker.global_position), pair[1])
			_anim(cmd, ANIM_HIT)
			await _wait(0.9)
			_anim(attacker, ANIM_IDLE)
		_anim(cmd, ANIM_IDLE)
		await _wait(0.8)


## 3. Arrow tower shooting a Grunt.
func _station_arrow_tower(at: Vector3) -> void:
	_caption(at, "Tháp Arrow bắn")
	var tower := _spawn_tower(ARROW_TOWER, at + Vector3(-1.2, 0, 0))
	var grunt := _spawn(GRUNT, at + Vector3(2.0, 0, 0))
	_face(grunt, tower)
	var muzzle := tower.global_position + Vector3.UP * muzzle_height
	while is_inside_tree():
		var target := _chest(grunt, tower)
		fx.play_muzzle(muzzle, target - muzzle, fx.arrow_muzzle)
		var dir := await _fly(ARROW_SHELL, muzzle, target, 0.25, 0.3)
		fx.play_arrow(target, dir)
		_anim(grunt, ANIM_HIT)
		await _wait(0.9)


## 4. Cannon tower shelling a Grunt.
func _station_cannon_tower(at: Vector3) -> void:
	_caption(at, "Tháp Cannon bắn")
	var tower := _spawn_tower(CANNON_TOWER, at + Vector3(-1.2, 0, 0))
	var grunt := _spawn(GRUNT, at + Vector3(2.2, 0, 0))
	_face(grunt, tower)
	var muzzle := tower.global_position + Vector3.UP * muzzle_height
	while is_inside_tree():
		var land := grunt.global_position + Vector3.UP * 0.4
		fx.play_muzzle(muzzle, land - muzzle, fx.cannon_muzzle)
		var dir := await _fly(CANNON_SHELL, muzzle, land, 0.6, 1.5)
		fx.play_blast(land, dir, blast_radius)
		_anim(grunt, ANIM_HIT)
		await _wait(1.6)


## 5. Enemy Archer shooting the commander.
func _station_enemy_archer(at: Vector3) -> void:
	_caption(at, "Archer địch bắn chỉ huy")
	var cmd := _spawn(COMMANDER, at + Vector3(-1.4, 0, 0))
	var archer := _spawn(ARCHER, at + Vector3(1.8, 0, 0))
	_face(archer, cmd)
	_face(cmd, archer)
	while is_inside_tree():
		_anim(archer, &"ranged/Ranged_2H_Shoot")
		await _wait(0.3)
		var from := archer.global_position + Vector3(0, 1.3, 0)
		var target := _chest(cmd, archer)
		var dir := await _fly(ARROW_SHELL, from, target, 0.25, 0.2)
		fx.play_arrow(target, dir, true)
		_anim(cmd, ANIM_HIT)
		await _wait(1.2)
		_anim(archer, ANIM_IDLE)


## Moves a shell model from a to b on an arc; returns its direction at landing.
func _fly(scene: PackedScene, a: Vector3, b: Vector3, time: float, arc: float) -> Vector3:
	var shell: Node3D = scene.instantiate()
	add_child(shell)
	var last := a
	var dir := b - a
	var t := 0.0
	while t < time:
		await get_tree().process_frame
		t += get_process_delta_time()
		var k := minf(t / time, 1.0)
		var p := a.lerp(b, k) + Vector3.UP * (4.0 * arc * k * (1.0 - k))
		if (p - last).length_squared() > 0.000001:
			dir = p - last
			shell.look_at_from_position(p, p + dir, Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.FORWARD)
		last = p
	shell.queue_free()
	return dir


func _spawn(scene: PackedScene, at: Vector3) -> Node3D:
	var n: Node3D = scene.instantiate()
	_stage.add_child(n)
	n.position = at
	_anim(n, ANIM_IDLE)
	return n


func _spawn_tower(scene: PackedScene, at: Vector3) -> Node3D:
	var n: Node3D = scene.instantiate()
	_stage.add_child(n)
	n.position = at
	for i in [2, 3]:
		var lv := n.get_node_or_null("Level%d" % i) as Node3D
		if lv:
			lv.visible = false
	return n


func _face(who: Node3D, target: Node3D) -> void:
	var to := _flat(target.global_position - who.global_position)
	if to.length_squared() > 0.0001:
		who.look_at(who.global_position + to, Vector3.UP, true)


func _anim(who: Node, anim: StringName, speed := 1.0) -> void:
	for p in who.find_children("*", "AnimationPlayer", true, false):
		var player := p as AnimationPlayer
		if player.has_animation(anim):
			player.stop()
			player.play(anim, -1, speed)
			return


## Where a hit from the given side shows, the same way HitFxManager places it.
func _chest(who: Node3D, from: Node3D = null) -> Vector3:
	var p := who.global_position + Vector3.UP * fx.hit_height
	if from != null:
		p -= _flat(who.global_position - from.global_position).normalized() * fx.hit_offset
	return p


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _caption(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.outline_size = 12
	label.position = at + Vector3(0, 0.1, 1.7)
	_stage.add_child(label)


func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout
