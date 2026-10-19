extends Node3D

## Automated test runner for the Cannon tower (branch week3/cannon-tower):
## - Data: 3 levels, blast radius 2.5 / 3.0 / 3.5 m, min_range 4 m, ground-only targeting (3.6.3)
## - TGT-05: targets inside min_range are ignored; flying targets are ignored
## - PRJ-02: shell lands at the predicted position; blast 100% centre, 50% edge
## - PRJ-03: no damage to the commander or towers
## - PRJ-08: no knockback, no STAGGER on a cluster of Grunts
## - Flying enemies inside the blast are still hit (only targeting skips them)
## - PRJ-04: a fired shell comes back to the pool

const CANNON_SCENE: PackedScene = preload("res://entities/tower/cannon.tscn")
const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const COMMANDER_SCENE: PackedScene = preload("res://entities/commander/commander.tscn")
const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
const POOL_SCENE: PackedScene = preload("res://entities/projectile/projectile_pool.tscn")
const CANNON: TowerData = preload("res://data/towers/cannon.tres")

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []
var done := false


func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED CANNON TOWER RUNNER TEST              ")
	print("=======================================================")

	test_data()
	test_targeting()
	test_blast_falloff()
	test_no_friendly_fire()
	test_no_stagger_or_knockback()
	test_flying_in_blast()
	test_prediction()
	await test_fire_through_pool()

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
func _grunt(pos: Vector3) -> Enemy:
	var g := GRUNT_SCENE.instantiate() as Enemy
	g.position = pos
	add_child(g)
	g.spawn_grace = false
	g.is_in_spawn_zone = false
	return g


func _cannon(pos: Vector3, level := 1) -> Tower:
	var t := CANNON_SCENE.instantiate() as Tower
	t.position = pos
	add_child(t)
	if level != 1:
		t.apply_level(level)
	return t


func _shell(dmg: int, radius: float, src: Node = null) -> CannonProjectile:
	var p := (CANNON.projectile_scene.instantiate()) as CannonProjectile
	add_child(p)
	p.setup_blast(dmg, radius, CANNON.splash_falloff_edge, src)
	return p


func _clear(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.free()
#endregion


func test_data() -> void:
	print("\n[GROUP 1] Cannon data (3.6.3)")
	assert_true(CANNON.levels.size() == 3, "3 levels")
	var radii: Array[float] = []
	for lv in CANNON.levels:
		radii.append(lv.splash_radius)
	var expected: Array[float] = [2.5, 3.0, 3.5]
	assert_true(radii == expected, "blast radius 2.5 / 3.0 / 3.5 m (got %s)" % [radii])
	assert_true(is_equal_approx(CANNON.min_range, 4.0), "min_range 4 m")
	assert_true(CANNON.targets_ground and not CANNON.targets_air, "targets ground only")
	assert_true(CANNON.damage_type == Enums.DamageType.BLAST, "damage type BLAST")
	assert_true(CANNON.default_priority == Enums.TargetPriority.NEAREST, "default priority Nearest")
	assert_true(is_equal_approx(CANNON.splash_falloff_edge, 0.5), "falloff edge 0.5")
	assert_true(CANNON.projectile_scene != null
			and CANNON.projectile_scene.instantiate() is CannonProjectile, "projectile scene is a CannonProjectile")


func test_targeting() -> void:
	print("\n[GROUP 2] Targeting (TGT-05, ground only)")
	var t := _cannon(Vector3.ZERO)
	var near := _grunt(Vector3(3.0, 0, 0))
	var ok := _grunt(Vector3(6.0, 0, 0))
	var far := _grunt(Vector3(13.0, 0, 0))
	var flyer := _grunt(Vector3(0, 0, 7.0))
	flyer.data = flyer.data.duplicate()
	flyer.data.is_flying = true
	assert_true(t.can_attack(), "Cannon can attack (projectile scene set)")
	assert_true(not t._is_valid_target(near), "enemy at 3 m (inside min_range 4 m) is ignored")
	assert_true(t._is_valid_target(ok), "enemy at 6 m is a valid target")
	assert_true(not t._is_valid_target(far), "enemy at 13 m (range 12 m at level 1) is ignored")
	assert_true(not t._is_valid_target(flyer), "flying enemy is not targeted")
	_clear([near, ok, far, flyer, t])


func test_blast_falloff() -> void:
	print("\n[GROUP 3] Blast falloff (PRJ-02, DMG-06)")
	assert_true(CannonProjectile.blast_damage(35, 0.0, 2.5, 0.5) == 35, "centre: 100% (35)")
	assert_true(CannonProjectile.blast_damage(35, 1.25, 2.5, 0.5) == 26, "half radius: 75% (26.25 -> 26)")
	assert_true(CannonProjectile.blast_damage(35, 2.5, 2.5, 0.5) == 18, "edge: 50% (17.5 -> 18)")
	assert_true(CannonProjectile.blast_damage(35, 2.6, 2.5, 0.5) == 0, "outside radius: 0")

	var g0 := _grunt(Vector3(20, 0, 0))
	var g1 := _grunt(Vector3(21.25, 0, 0))
	var g2 := _grunt(Vector3(20, 0, 2.5))
	var g3 := _grunt(Vector3(20, 0, -2.7))
	var hp := [g0.health.hp, g1.health.hp, g2.health.hp, g3.health.hp]
	var p := _shell(35, 2.5)
	var hits := p.explode(Vector3(20, 0, 0))
	assert_true(hits == 3, "3 enemies inside 2.5 m are hit (got %d)" % hits)
	assert_true(hp[0] - g0.health.hp == 35, "enemy at centre loses 35 (lost %d)" % (hp[0] - g0.health.hp))
	assert_true(hp[1] - g1.health.hp == 26, "enemy at 1.25 m loses 26 (lost %d)" % (hp[1] - g1.health.hp))
	assert_true(hp[2] - g2.health.hp == 18, "enemy at 2.5 m loses 18 (lost %d)" % (hp[2] - g2.health.hp))
	assert_true(hp[3] == g3.health.hp, "enemy at 2.7 m loses nothing")
	_clear([g0, g1, g2, g3, p])

	var t3 := _cannon(Vector3(0, 0, 30), 3)
	var lv3: TowerLevelData = t3.data.levels[t3.level - 1]
	assert_true(is_equal_approx(lv3.splash_radius, 3.5) and lv3.damage == 80, "level 3 shell: 80 dmg, 3.5 m")
	_clear([t3])


func test_no_friendly_fire() -> void:
	print("\n[GROUP 4] No friendly fire (PRJ-03)")
	var cmd := COMMANDER_SCENE.instantiate() as Node3D
	cmd.position = Vector3(40, 0, 0)
	add_child(cmd)
	var arrow := ARROW_SCENE.instantiate() as Tower
	arrow.position = Vector3(41, 0, 0)
	add_child(arrow)
	var g := _grunt(Vector3(40, 0, 1))
	var cmd_hp: int = cmd.health.hp
	var tower_hp: int = arrow.health.hp
	var g_hp: int = g.health.hp
	var p := _shell(80, 3.5)
	p.explode(Vector3(40, 0, 0))
	assert_true(cmd.health.hp == cmd_hp, "commander inside the blast takes no damage")
	assert_true(arrow.health.hp == tower_hp, "tower inside the blast takes no damage")
	assert_true(g.health.hp < g_hp, "enemy next to them is still hit")
	_clear([g, p, arrow, cmd])


func test_no_stagger_or_knockback() -> void:
	print("\n[GROUP 5] No knockback, no STAGGER (PRJ-08, test 7.1 #12)")
	var grunts: Array[Enemy] = []
	for i in 10:
		var g := _grunt(Vector3(60 + (i % 5) * 0.6, 0, floorf(i / 5.0) * 0.6))
		g.change_state(Enums.EnemyState.ATTACK)
		grunts.append(g)
	var p := _shell(35, 2.5)
	var before: Array[Vector3] = []
	for g in grunts:
		before.append(g.velocity)
	p.explode(Vector3(61.2, 0, 0.3))
	var staggered := 0
	var pushed := 0
	var still_attacking := 0
	for i in grunts.size():
		var g := grunts[i]
		if g.current_state == Enums.EnemyState.STAGGER:
			staggered += 1
		if g.current_state == Enums.EnemyState.ATTACK:
			still_attacking += 1
		if not g.velocity.is_equal_approx(before[i]) or g.knockback_immunity_timer > 0.0:
			pushed += 1
	assert_true(staggered == 0, "no Grunt enters STAGGER (got %d)" % staggered)
	assert_true(pushed == 0, "no Grunt is knocked back (got %d)" % pushed)
	assert_true(still_attacking == grunts.size(), "all 10 keep attacking (got %d)" % still_attacking)
	_clear(grunts)
	_clear([p])


func test_flying_in_blast() -> void:
	print("\n[GROUP 6] Flying enemy inside the blast is hit")
	var flyer := _grunt(Vector3(80, 1.5, 0))
	flyer.data = flyer.data.duplicate()
	flyer.data.is_flying = true
	var hp: int = flyer.health.hp
	var p := _shell(35, 2.5)
	p.explode(Vector3(80, 0, 0))
	assert_true(flyer.health.hp < hp, "flying enemy 1.5 m above the centre takes blast damage")
	_clear([flyer, p])


func test_prediction() -> void:
	print("\n[GROUP 7] Lead the target (PRJ-02)")
	var g := _grunt(Vector3(10, 0, 0))
	g.velocity = Vector3(-3.0, 0, 0)
	var from := Vector3(0, 2, 0)
	var dest := CannonProjectile.predict_landing(from, g, 20.0)
	# flight ~ 10 m / 20 m/s = 0.5 s, so the Grunt walks ~1.4 m toward the tower
	assert_true(dest.x < 9.0 and dest.x > 8.0, "landing point leads a moving target (x = %.2f)" % dest.x)
	g.velocity = Vector3.ZERO
	var still := CannonProjectile.predict_landing(from, g, 20.0)
	assert_true(still.is_equal_approx(g.global_position), "standing target: lands on it")
	_clear([g])


func test_fire_through_pool() -> void:
	print("\n[GROUP 8] Tower fires on its own through the pool (PRJ-04)")
	var pool := POOL_SCENE.instantiate() as ProjectilePool
	add_child(pool)
	var t := _cannon(Vector3(100, 0, 0))
	var g := _grunt(Vector3(107, 0, 0))
	g.set_physics_process(false)  # keep it standing still
	var hp: int = g.health.hp
	var took_shell := false
	var frames := 0
	while g.health.hp == hp and frames < 600:
		await get_tree().physics_frame
		frames += 1
		if pool.active_count() > 0:
			took_shell = true
	t.set_physics_process(false)  # one shot is enough (cooldown is 2.5 s anyway)
	assert_true(took_shell, "the Cannon took a shell from the pool")
	assert_true(pool.active_count() == 0, "shell returned to the pool after landing")
	assert_true(hp - g.health.hp == 35, "standing target takes the full 35 (lost %d, %d frames)" % [hp - g.health.hp, frames])
	_clear([g, t, pool])
