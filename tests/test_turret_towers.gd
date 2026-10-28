extends Node3D
## Automated test for the rigged Arrow (ballista) and Cannon tower models:
## - level 1, 2 and 3 show the LVL_1, LVL_2 and LVL_4 meshes, one at a time
## - the barrel or bolt turns toward the target, wherever it is around the tower
## - the ballista tilts down at a close target, the cannon rises with distance
## - the muzzle sits at the tip, follows the turn, and is where shots leave from
## Run with F6. Set quit_when_done off to watch the towers turn.

const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
const CANNON_SCENE: PackedScene = preload("res://entities/tower/cannon.tscn")
const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const POOL_SCENE: PackedScene = preload("res://entities/projectile/projectile_pool.tscn")

@export var quit_when_done := true

var passes := 0
var fails := 0
var _shots: Array = []


func _ready() -> void:
	print("\n[turret] start")
	add_child(POOL_SCENE.instantiate())
	_make_world()
	await test_levels(ARROW_SCENE, "Arrow")
	await test_levels(CANNON_SCENE, "Cannon")
	await test_aim(ARROW_SCENE, "Arrow")
	await test_aim(CANNON_SCENE, "Cannon")
	await test_pitch()
	await test_muzzle(ARROW_SCENE, "Arrow")
	await test_muzzle(CANNON_SCENE, "Cannon")
	print("[turret] done: %d passed, %d failed" % [passes, fails])
	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, label: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % label)
	else:
		fails += 1
		printerr("  [FAIL] %s" % label)


#region Helpers
func _make_world() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, -0.5, 0)
	add_child(body)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 18, 16)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)


func _tower(scene: PackedScene, pos := Vector3.ZERO) -> Tower:
	var t := scene.instantiate() as Tower
	t.position = pos
	add_child(t)
	return t


## Grunt that stays where it is put: no AI, no grace.
func _grunt(pos: Vector3) -> Enemy:
	var g := GRUNT_SCENE.instantiate() as Enemy
	g.position = pos
	add_child(g)
	g.set_physics_process(false)
	g.spawn_grace = false
	g.is_in_spawn_zone = false
	return g


func _model(t: Tower) -> TurretTowerModel:
	return t.find_children("*", "TurretTowerModel", true, false)[0] as TurretTowerModel


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false, true).timeout


func _flat_angle(a: Vector3, b: Vector3) -> float:
	return rad_to_deg(Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z)))


func _clear(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.free()
	_shots.clear()
#endregion


func test_levels(scene: PackedScene, label: String) -> void:
	print("\n[GROUP] %s: one level mesh at a time" % label)
	var t := _tower(scene)
	var m := _model(t)
	for lv in [1, 2, 3]:
		t.apply_level(lv)
		await get_tree().process_frame
		var shown := []
		for i in 3:
			if (m.get_node("Level%d" % (i + 1)) as Node3D).visible:
				shown.append(i + 1)
		assert_true(shown == [lv], "%s level %d shows Level%d only (shown %s)" % [label, lv, lv, shown])
		assert_true(t._muzzle_node == m.muzzle(), "%s level %d: the tower shoots from this level's muzzle" % [label, lv])
	_clear([t])


func test_aim(scene: PackedScene, label: String) -> void:
	print("\n[GROUP] %s: turns toward the target" % label)
	var t := _tower(scene)
	var m := _model(t)
	for dir in [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, -1).normalized(), Vector3(-0.3, 0, 1).normalized()]:
		var g := _grunt(dir * 6.0)
		await _wait(GameConfig.scan_interval + 1.0)
		var to := g.global_position - m.muzzle().global_position
		var err := absf(_flat_angle(m.barrel_direction(), to))
		assert_true(t.target == g and err < 4.0, "%s aims at a target toward %s (off by %.1f deg)" % [label, dir.snapped(Vector3.ONE * 0.1), err])
		g.free()
	_clear([t])


func test_pitch() -> void:
	print("\n[GROUP] Pitch: ballista tilts down at a close target, cannon rises with distance")
	var arrow := _tower(ARROW_SCENE)
	var g := _grunt(Vector3(3, 0, 0))
	await _wait(GameConfig.scan_interval + 1.0)
	var down := _model(arrow).barrel_direction().y
	assert_true(down < -0.2, "ballista bolt points down at a unit 3 m away (dir.y %.2f)" % down)
	_clear([arrow, g])

	var cannon := _tower(CANNON_SCENE)
	var cm := _model(cannon)
	g = _grunt(Vector3(cannon.data.min_range + 1.0, 0, 0))
	await _wait(GameConfig.scan_interval + 1.0)
	var near := cm.barrel_direction().y
	g.global_position = Vector3(cannon.data.levels[0].attack_range - 0.5, 0, 0)
	await _wait(1.0)
	var far := cm.barrel_direction().y
	assert_true(near > 0.0 and far > near + 0.1, "cannon barrel rises with distance (near %.2f, far %.2f)" % [near, far])
	_clear([cannon, g])


func test_muzzle(scene: PackedScene, label: String) -> void:
	print("\n[GROUP] %s: muzzle at the tip, shots leave from it" % label)
	var t := _tower(scene)
	var m := _model(t)
	t.shot_released.connect(func(from: Vector3, _target: Node3D): _shots.append([from, m.muzzle().global_position]))
	var g := _grunt(Vector3(5, 0, 0))
	await _wait(2.5)
	var mz := m.muzzle().global_position
	var top := 0.0
	for n in m.get_node("Level1").find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		top = maxf(top, (mi.global_transform * mi.get_aabb()).end.y)
	assert_true(mz.y > 2.0 and mz.y < top, "%s muzzle is up on the weapon (y %.2f, model top %.2f)" % [label, mz.y, top])
	var off := Vector2(mz.x - t.global_position.x, mz.z - t.global_position.z)
	assert_true(off.length() > 0.2 and off.normalized().dot(Vector2(1, 0)) > 0.8,
		"%s muzzle swung to the target's side (offset %s)" % [label, off.snapped(Vector2.ONE * 0.01)])
	assert_true(not _shots.is_empty(), "%s fired (%d shots)" % [label, _shots.size()])
	if not _shots.is_empty():
		var gap := 0.0
		for s in _shots:
			gap = maxf(gap, (s[0] as Vector3).distance_to(s[1]))
		assert_true(gap < 0.05, "%s every shot leaves from the muzzle (worst %.2f m away)" % [label, gap])
	_clear([t, g])
