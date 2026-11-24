extends Node3D
## Runner for the Assassin, the Knight and the Undead, all driven by EnemyData traits:
## - Assassin (stealth): a tower never picks it and it does not count as a unit in range, a Cannon
##   blast aimed at another unit still hits it, the commander sees it at its stealth opacity and
##   can hit it
## - Knight: a hit that leaves it under its HP threshold makes it invulnerable for its duration
##   (towers drop it, commander hits show IMMUNE), once per unit; a hit from above the threshold
##   to 0 kills it
## - Undead: the first death lays it down with no reward and no enemy_died; it stands up after
##   revive_delay with full HP and more hit damage; the second death pays and counts. Culled
##   while lying down: no reward. hit_by_commander is kept across the revive
## Units run with physics off; the trait clocks are ticked by hand.

const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
const CANNON_PROJECTILE_SCENE: PackedScene = preload("res://entities/projectile/cannon_projectile.tscn")
const POOL_SCENE: PackedScene = preload("res://entities/projectile/projectile_pool.tscn")
const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const ASSASSIN_SCENE: PackedScene = preload("res://entities/enemy/assassin.tscn")
const KNIGHT_SCENE: PackedScene = preload("res://entities/enemy/knight.tscn")
const UNDEAD_SCENE: PackedScene = preload("res://entities/enemy/undead.tscn")

var passes: int = 0
var fails: int = 0
var _commander: Node3D
var _died: Array[Dictionary] = []
var _immune_hits: int = 0
var _commander_kills: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("        STEALTH, KNIGHT AND UNDEAD RUNNER TEST         ")
	print("=======================================================")
	add_child(POOL_SCENE.instantiate())
	_commander = Node3D.new()
	_commander.name = "FakeCommander"
	_commander.add_to_group(&"commander")
	add_child(_commander)
	EventBus.enemy_died.connect(func(id: StringName, _p: Vector3, gold: float, _pr: int, is_cull: bool, by_cmd: bool) -> void:
		_died.append({"id": id, "gold": gold, "cull": is_cull, "by_commander": by_cmd}))
	EventBus.damage_immune.connect(func(_t: Node3D, _i: DamageInfo) -> void: _immune_hits += 1)
	EventBus.commander_enemy_killed.connect(func(_c: Node) -> void: _commander_kills += 1)

	await test_assassin()
	await test_knight()
	await test_undead()

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")
	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		print("  [FAIL] %s" % test_name)


## A unit that stays where it is put: no AI, no grace.
func _unit(scene: PackedScene, pos: Vector3, label: String) -> Enemy:
	var e := scene.instantiate() as Enemy
	e.name = label
	e.position = pos
	add_child(e)
	e.set_physics_process(false)
	e.spawn_grace = false
	e.is_in_spawn_zone = false
	return e


func _physics_frames(n := 2) -> void:
	for i in n:
		await get_tree().physics_frame


func _hit(e: Enemy, amount: float, from_commander := true) -> int:
	var src: Node = _commander if from_commander else null
	return e.take_damage(DamageInfo.outgoing(amount, 1.0, Enums.DamageType.SLASH, src, 0.0, Vector3.ZERO))


func test_assassin() -> void:
	print("\n[GROUP 1] Assassin")
	var data := load("res://data/enemies/assassin.tres") as EnemyData
	assert_true(data.is_stealth and is_equal_approx(data.stealth_opacity, 0.5), "Assassin data is stealth at opacity 0.5")

	var tower := ARROW_SCENE.instantiate() as Tower
	add_child(tower)
	var assassin := _unit(ASSASSIN_SCENE, Vector3(-2, 0, 0), "Assassin")
	await _physics_frames()
	assert_true(not tower._is_valid_target(assassin), "The Arrow never picks the Assassin in range")
	assert_true(tower._pick_target() == null, "With only the Assassin in range the tower stays idle")
	assert_true(not tower.is_immune_blocked, "The Assassin does not count as a unit in range (no immune icon)")
	var grunt := _unit(GRUNT_SCENE, Vector3(-4, 0, 0), "Grunt")
	await _physics_frames()
	tower.priority = Enums.TargetPriority.NEAREST
	assert_true(tower._pick_target() == grunt, "The tower picks the farther Grunt over the closer Assassin")

	var blast := CANNON_PROJECTILE_SCENE.instantiate() as CannonProjectile
	add_child(blast)
	blast.damage = 10
	blast.damage_type = Enums.DamageType.BLAST
	blast._radius = 3.0
	blast._edge_mult = 1.0
	var hp_before := assassin.health.hp
	blast.explode(grunt.global_position)
	assert_true(assassin.health.hp < hp_before, "A Cannon blast on the Grunt also hits the Assassin next to it")

	var hp_now := assassin.health.hp
	assert_true(_hit(assassin, 5.0) > 0 and assassin.health.hp < hp_now, "The commander can hit the Assassin")

	var model := assassin.get_node(^"Model").get_child(0)
	assert_true(model.has_method(&"get_opacity") and is_equal_approx(model.get_opacity(), 0.5), "The Assassin is drawn at opacity 0.5")
	for n in [tower, assassin, grunt, blast]:
		n.free()


func test_knight() -> void:
	print("\n[GROUP 2] Knight")
	var tower := ARROW_SCENE.instantiate() as Tower
	add_child(tower)
	var knight := _unit(KNIGHT_SCENE, Vector3(-3, 0, 0), "Knight")
	await _physics_frames()
	var max_hp := knight.health.max_hp
	assert_true(tower._is_valid_target(knight), "A Knight above its threshold is a valid tower target")

	_hit(knight, ceilf(max_hp * 0.55))
	assert_true(knight.health.hp > 0 and knight.is_invulnerable(), "A hit to 45% HP makes the Knight invulnerable")
	assert_true(knight.get_resist(Enums.DamageType.PIERCE) == 0.0, "Resist is 0 to every type while invulnerable")
	assert_true(not tower._is_valid_target(knight), "The tower drops the invulnerable Knight")
	var immune_before := _immune_hits
	var hp_mid := knight.health.hp
	assert_true(_hit(knight, 50.0) == 0 and knight.health.hp == hp_mid, "No damage while invulnerable")
	assert_true(_immune_hits == immune_before + 1, "A commander hit on the invulnerable Knight shows IMMUNE")

	knight._tick_invuln(4.9)
	assert_true(knight.is_invulnerable(), "Still invulnerable at 4.9 s")
	knight._tick_invuln(0.2)
	assert_true(not knight.is_invulnerable(), "Invulnerability ends after 5 s")
	assert_true(_hit(knight, 5.0) > 0, "Takes damage normally afterwards")
	assert_true(not knight.is_invulnerable(), "No second invulnerable window")
	knight.free()

	var knight2 := _unit(KNIGHT_SCENE, Vector3(-3, 0, 1), "Knight2")
	await _physics_frames()
	_hit(knight2, ceilf(knight2.health.max_hp * 0.4))
	assert_true(not knight2.is_invulnerable(), "Still above the threshold at 60%: not invulnerable")
	_hit(knight2, float(knight2.health.max_hp))
	assert_true(knight2.is_dead and not knight2.is_invulnerable(), "A hit from 60% to 0 kills the Knight")
	tower.free()


func test_undead() -> void:
	print("\n[GROUP 3] Undead")
	var tower := ARROW_SCENE.instantiate() as Tower
	add_child(tower)
	var undead := _unit(UNDEAD_SCENE, Vector3(-3, 0, 0), "Undead")
	await _physics_frames()
	var data := undead.data
	var dmg_before := undead.scaled_damage
	_died.clear()
	_commander_kills = 0

	_hit(undead, float(undead.health.max_hp))
	assert_true(undead.is_reviving and not undead.is_dead, "First death lays the Undead down")
	assert_true(_died.is_empty(), "No enemy_died and no reward on the first death")
	assert_true(_commander_kills == 0, "The first death is not a commander kill")
	assert_true(not undead.can_be_targeted() and not tower._is_valid_target(undead), "Not targetable while lying down")
	assert_true(_hit(undead, 10.0) == 0, "Takes no damage while lying down")
	assert_true(undead.hit_by_commander, "hit_by_commander is set")

	undead._tick_revive(data.revive_delay - 0.1)
	assert_true(undead.is_reviving, "Still lying before revive_delay")
	undead._tick_revive(0.2)
	assert_true(not undead.is_reviving and undead.health.hp == undead.health.max_hp, "Stands up after revive_delay with full HP")
	assert_true(undead.scaled_damage == maxi(1, int(round(dmg_before * data.revive_dmg_mult))), "Hit damage times revive_dmg_mult after the revive")
	assert_true(undead.hit_by_commander, "hit_by_commander is kept across the revive")
	assert_true(undead.can_be_targeted(), "Targetable again")

	_hit(undead, float(undead.health.max_hp))
	assert_true(undead.is_dead, "Second death kills it")
	assert_true(_died.size() == 1 and not _died[0].cull and _died[0].gold > 0.0, "The second death pays and sends enemy_died once")
	assert_true(_died.size() == 1 and _died[0].by_commander, "The kill keeps the commander flag")
	assert_true(_commander_kills == 1, "The second death is a commander kill")

	var lying := _unit(UNDEAD_SCENE, Vector3(-3, 0, 2), "Lying")
	await _physics_frames()
	_died.clear()
	_hit(lying, float(lying.health.max_hp), false)
	assert_true(lying.is_reviving, "Second Undead lies down")
	assert_true(lying.cull(&"HARD_CAP"), "A lying Undead can be culled")
	assert_true(_died.size() == 1 and _died[0].cull and _died[0].gold == 0.0, "Culled while lying: no reward")
	tower.free()
