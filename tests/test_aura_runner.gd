extends Node3D

## Automated test runner for the Frontline aura (branch week6/frontline-aura):
## - a Frontline commander 11 m from an Arrow gives it dealt_mult 1.2 and a real shot deals 12
##   instead of 10; at 13 m nothing changes
## - Commander mode, stun, deploying and death turn the aura off in the same frame and
##   emit aura_changed(false) once; back to Frontline it comes back within one scan_interval
## - recall is checked on a stub commander until the real Recall state exists
## - a Barricade inside the radius never gets the aura
## - shots read dealt_mult on impact, and keep the value saved at fire() when the tower is gone
## - Cannon blast damage is rounded once, after falloff and dealt_mult

const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
const CANNON_SCENE: PackedScene = preload("res://entities/tower/cannon.tscn")
const BARRICADE_SCENE: PackedScene = preload("res://entities/tower/barricade.tscn")
const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const COMMANDER_SCENE: PackedScene = preload("res://entities/commander/commander.tscn")
const POOL_SCENE: PackedScene = preload("res://entities/projectile/projectile_pool.tscn")
const ARROW_SHOT_SCENE: PackedScene = preload("res://entities/projectile/arrow_projectile.tscn")
const CANNON_SHOT_SCENE: PackedScene = preload("res://entities/projectile/cannon_projectile.tscn")
const RECALL_STUB: Script = preload("res://tests/recall_commander_stub.gd")

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []
var done := false

var _aura_events: Array = []
var _hits: Array = []


func _ready() -> void:
	print("\n=======================================================")
	print("          AUTOMATED FRONTLINE AURA RUNNER TEST         ")
	print("=======================================================")
	add_child(POOL_SCENE.instantiate())
	_make_floor()
	_make_camera()
	EventBus.aura_changed.connect(func(active: bool): _aura_events.append(active))
	EventBus.projectile_hit.connect(func(_t: Node, amount: int, _type: StringName, _r: float): _hits.append(amount))

	await test_radius()
	await test_real_shot()
	await test_commander_mode()
	await test_stun_deploy_death()
	await test_recall_stub()
	await test_barricade()
	await test_impact_mult()
	await test_cannon_rounding()

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")
	done = true
	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		failed_names.append(test_name)
		printerr("  [FAIL] %s" % test_name)


#region Helpers
func _make_floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, -0.5, 0)
	add_child(body)


## Commander._physics_process returns early without a camera.
func _make_camera() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 30, 20)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	cam.current = true


## Untyped: the commander script has no class_name.
func _commander(pos: Vector3, script_override: Script = null):
	var c = COMMANDER_SCENE.instantiate()
	if script_override != null:
		c.set_script(script_override)
	c.position = pos
	add_child(c)
	EventBus.state_changed.emit(&"COMBAT")
	return c


## Grunt that stays where it is put: no AI, no grace, no model.
func _grunt(pos: Vector3) -> Enemy:
	var g := GRUNT_SCENE.instantiate() as Enemy
	var model := g.get_node_or_null(^"Model")
	if model != null:
		for child in model.get_children():
			model.remove_child(child)
			child.free()
	g.position = pos
	add_child(g)
	g.set_physics_process(false)
	g.spawn_grace = false
	g.is_in_spawn_zone = false
	return g


func _tower(scene: PackedScene, pos: Vector3) -> Tower:
	var t := scene.instantiate() as Tower
	t.position = pos
	add_child(t)
	return t


func _physics_frames(n := 2) -> void:
	for i in n:
		await get_tree().physics_frame


## Waits one scan_interval of game time plus a frame, so every tower has scanned once.
func _one_scan() -> void:
	await get_tree().create_timer(GameConfig.scan_interval + 0.02, false, true).timeout


func _clear(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.free()
	_aura_events.clear()
	_hits.clear()
#endregion


func test_radius() -> void:
	print("\n[GROUP 1] Radius: 11 m on, 13 m off")
	var t := _tower(ARROW_SCENE, Vector3.ZERO)
	var c = _commander(Vector3(11, 0, 0))
	await _physics_frames()
	assert_true(c.is_aura_source(), "a fresh commander in Frontline is an aura source")
	assert_true(_aura_events == [true], "aura_changed(true) is emitted once when the commander spawns")
	await _one_scan()
	assert_true(t.aura_active and is_equal_approx(t.get_dealt_mult(), 1.2),
		"commander 11 m away: aura_active, dealt_mult 1.2")
	c.global_position = Vector3(13, 0, 0)
	await _one_scan()
	assert_true(not t.aura_active and is_equal_approx(t.get_dealt_mult(), 1.0),
		"commander 13 m away: no aura, dealt_mult 1.0")
	c.global_position = Vector3(0, 0, 11.5)
	await _one_scan()
	assert_true(t.aura_active, "distance is flat: 11.5 m on the z axis still counts")
	_clear([t, c])


func test_real_shot() -> void:
	print("\n[GROUP 2] A real Arrow shot deals 10 x 1.2 = 12 inside the aura")
	var t := _tower(ARROW_SCENE, Vector3.ZERO)
	var c = _commander(Vector3(11, 0, 0))
	var g := _grunt(Vector3(-5, 0, 0))
	await _one_scan()
	_hits.clear()
	await get_tree().create_timer(1.5, false, true).timeout
	assert_true(not _hits.is_empty() and _hits.all(func(a): return a == 12),
		"commander at 11 m: every hit deals 12 (hits %s)" % [_hits])
	c.global_position = Vector3(13, 0, 0)
	g.free()
	await _one_scan()
	await get_tree().create_timer(0.5, false, true).timeout
	_hits.clear()
	g = _grunt(Vector3(-5, 0, 0))
	await get_tree().create_timer(1.5, false, true).timeout
	assert_true(not _hits.is_empty() and _hits.all(func(a): return a == 10),
		"commander at 13 m: every hit deals 10 (hits %s)" % [_hits])
	_clear([t, c, g])


func test_commander_mode() -> void:
	print("\n[GROUP 3] Commander mode turns the aura off in the same frame")
	var t := _tower(ARROW_SCENE, Vector3.ZERO)
	var t2 := _tower(ARROW_SCENE, Vector3(0, 0, 6))
	var c = _commander(Vector3(5, 0, 0))
	await _one_scan()
	assert_true(t.aura_active and t2.aura_active, "both towers within 12 m have the aura")
	_aura_events.clear()
	EventBus.mode_changed.emit(&"COMMANDER")
	assert_true(not t.aura_active and not t2.aura_active,
		"mode_changed(COMMANDER): every tower drops the aura before the next frame")
	assert_true(_aura_events == [false], "aura_changed(false) emitted once")
	await _one_scan()
	assert_true(not t.aura_active, "still off on the next scan while in Commander mode")
	EventBus.mode_changed.emit(&"FRONTLINE")
	assert_true(_aura_events == [false, true], "back to Frontline: aura_changed(true)")
	assert_true(t.aura_active, "back to Frontline: on at once, no wait for the scan")
	_clear([t, t2, c])


func test_stun_deploy_death() -> void:
	print("\n[GROUP 4] Stunned, Deploying and dead commanders give no aura")
	var t := _tower(ARROW_SCENE, Vector3.ZERO)
	var c = _commander(Vector3(5, 0, 0))
	await _one_scan()
	_aura_events.clear()

	assert_true(c.apply_stun(0.5), "stun applied")
	assert_true(not t.aura_active and _aura_events == [false], "Stunned: off in the same frame")
	await get_tree().create_timer(0.6, false, true).timeout
	await _one_scan()
	assert_true(not c.is_stunned and t.aura_active and _aura_events == [false, true],
		"stun over: on again within one scan")

	_aura_events.clear()
	c.is_deploying = true
	await _physics_frames(2)
	assert_true(not t.aura_active and _aura_events == [false], "Deploying: off within one physics frame")
	c.is_deploying = false
	await _one_scan()
	assert_true(t.aura_active, "deploy done: on again within one scan")

	_aura_events.clear()
	c.take_damage(DamageInfo.new(10000, Enums.DamageType.TRUE))
	assert_true(c.is_dead and not t.aura_active and _aura_events == [false], "dead: off in the same frame")
	await _one_scan()
	assert_true(not t.aura_active, "dead: stays off")
	_clear([t, c])


func test_recall_stub() -> void:
	print("\n[GROUP 4b] Recalling (stub until the Recall state exists) gives no aura")
	var t := _tower(ARROW_SCENE, Vector3.ZERO)
	var c = _commander(Vector3(5, 0, 0), RECALL_STUB)
	await _one_scan()
	assert_true(t.aura_active, "stub commander in Frontline gives the aura")
	_aura_events.clear()
	c.stub_recalling = true
	await _physics_frames(2)
	assert_true(not t.aura_active and _aura_events == [false], "Recalling: off within one physics frame")
	c.stub_recalling = false
	await _physics_frames(2)
	assert_true(t.aura_active and _aura_events == [false, true], "recall over: on again")
	_clear([t, c])


func test_barricade() -> void:
	print("\n[GROUP 5] Towers that never attack get no aura")
	var b := _tower(BARRICADE_SCENE, Vector3(3, 0, 0))
	var c = _commander(Vector3(5, 0, 0))
	await _one_scan()
	b._update_aura()
	assert_true(not b.aura_active and is_equal_approx(b.get_dealt_mult(), 1.0),
		"Barricade 2 m from the commander: aura_active false")
	_clear([b, c])


func test_impact_mult() -> void:
	print("\n[GROUP 6] Shots read dealt_mult on impact")
	var t := _tower(ARROW_SCENE, Vector3.ZERO)
	t.aura_active = true
	var p := ARROW_SHOT_SCENE.instantiate() as Projectile
	add_child(p)
	var g := _grunt(Vector3(-30, 0, 0))
	p.fire(Vector3.ZERO, g, 10, Enums.DamageType.PIERCE, 0.0, t)
	t.aura_active = false
	assert_true(is_equal_approx(p.hit_dealt_mult(), 1.0), "aura lost before impact: the hit uses 1.0")
	t.aura_active = true
	assert_true(is_equal_approx(p.hit_dealt_mult(), 1.2), "aura gained before impact: the hit uses 1.2")
	p.fire(Vector3.ZERO, g, 10, Enums.DamageType.PIERCE, 0.0, t)
	t.free()
	assert_true(is_equal_approx(p.hit_dealt_mult(), 1.2), "tower destroyed in flight: the value saved at fire() (1.2)")
	assert_true(Projectile.scaled_damage(10, 1.2) == 12 and Projectile.scaled_damage(1, 0.2) == 1
		and Projectile.scaled_damage(0, 1.2) == 0, "scaled_damage: 12, floor of 1 when raw > 0, 0 when raw is 0")
	_clear([p, g])


func test_cannon_rounding() -> void:
	print("\n[GROUP 7] Cannon blast: one rounding after falloff and dealt_mult")
	var t := _tower(CANNON_SCENE, Vector3(20, 0, 20))
	t.aura_active = true
	var p := CANNON_SHOT_SCENE.instantiate() as CannonProjectile
	add_child(p)
	p.setup_blast(35, 2.5, 0.5, t)
	var g := _grunt(Vector3(1.25, 0, 0))
	g.health.max_hp = 1000
	g.health.hp = 1000
	_hits.clear()
	p.explode(Vector3.ZERO)
	# 35 x 0.75 = 26.25, x 1.2 = 31.5 -> 32. Rounding the falloff first would give 26 x 1.2 = 31.
	assert_true(_hits == [32], "half radius with aura: 32, not 31 (hits %s)" % [_hits])
	t.aura_active = false
	_hits.clear()
	p.explode(Vector3.ZERO)
	assert_true(_hits == [26], "half radius without aura: 26 as before (hits %s)" % [_hits])
	assert_true(CannonProjectile.blast_damage(35, 1.25, 2.5, 0.5) == 26, "blast_damage() still rounds 26.25 to 26")
	_clear([t, p, g])
