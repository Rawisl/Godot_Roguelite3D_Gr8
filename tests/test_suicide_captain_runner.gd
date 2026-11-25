extends Node3D
## Runner for the Suicide Squad and its Captain, driven by the explode_* traits of EnemyData:
## - Suicide Squad: in reach of its target it lights the fuse (red ring telegraph) and blows up
##   after explode_windup: BLAST in explode_radius to the commander in Frontline, towers (wall
##   slots too), Barricades and the Fortress, never to other units; it leaves with no gold, XP or
##   kill and the wave counts it as gone. Killed before the blast: no blast, normal reward
## - Captain: killed, it pays normally and blows up where it fell after explode_windup; culled,
##   it does not blow up
## - the commander takes nothing while dodging or in Commander mode
## Units run with physics off; the state step and the fuse are driven by hand.

const COMMANDER_SCENE: PackedScene = preload("res://entities/commander/commander.tscn")
const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
const BARRICADE_SCENE: PackedScene = preload("res://entities/tower/barricade.tscn")
const POOL_SCENE: PackedScene = preload("res://entities/projectile/projectile_pool.tscn")
const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const SQUAD_SCENE: PackedScene = preload("res://entities/enemy/suicide_squad.tscn")
const CAPTAIN_SCENE: PackedScene = preload("res://entities/enemy/captain.tscn")

var passes: int = 0
var fails: int = 0
var _died: Array[Dictionary] = []
var _telegraphs: Array[Dictionary] = []
var _cancels: Array[Dictionary] = []


func _ready() -> void:
	print("\n=======================================================")
	print("          SUICIDE SQUAD AND CAPTAIN RUNNER TEST        ")
	print("=======================================================")
	add_child(POOL_SCENE.instantiate())
	EventBus.enemy_died.connect(func(id: StringName, _p: Vector3, gold: float, _pr: int, is_cull: bool, _c: bool) -> void:
		_died.append({"id": id, "gold": gold, "cull": is_cull}))
	EventBus.telegraph_started.connect(func(kind: StringName, pos: Vector3, radius: float, duration: float) -> void:
		_telegraphs.append({"kind": kind, "pos": pos, "radius": radius, "duration": duration}))
	EventBus.telegraph_cancelled.connect(func(kind: StringName, pos: Vector3) -> void:
		_cancels.append({"kind": kind, "pos": pos}))
	EventBus.state_changed.emit(&"COMBAT")

	test_data()
	await test_squad_blast()
	await test_squad_killed_before_blast()
	await test_commander_dodge_and_mode()
	await test_captain()
	await test_ring_cancelled()

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


func _unit(scene: PackedScene, pos: Vector3, label: String) -> Enemy:
	var e := scene.instantiate() as Enemy
	e.name = label
	e.position = pos
	add_child(e)
	e.set_physics_process(false)
	e.spawn_grace = false
	e.is_in_spawn_zone = false
	return e


func _tower(scene: PackedScene, pos: Vector3) -> Node3D:
	var t := scene.instantiate() as Node3D
	t.position = pos
	add_child(t)
	return t


## Untyped: the commander script has no class_name.
func _commander(pos: Vector3):
	var c = COMMANDER_SCENE.instantiate()
	c.position = pos
	add_child(c)
	EventBus.state_changed.emit(&"COMBAT")
	return c


func _physics_frames(n := 2) -> void:
	for i in n:
		await get_tree().physics_frame


## Puts the unit in ATTACK on a target and runs its state step once, as the AI would.
func _attack(e: Enemy, target: Node3D) -> void:
	e.current_target = target
	e.change_state(Enums.EnemyState.ATTACK)
	e._update_state(0.016)


func _hp(n: Node) -> int:
	return (n.get(&"health") as HealthComponent).hp


func test_data() -> void:
	print("\n[GROUP 1] Data")
	var squad := load("res://data/enemies/suicide_squad.tres") as EnemyData
	var captain := load("res://data/enemies/captain.tres") as EnemyData
	assert_true(squad.explode_on_contact and not squad.explode_on_death and squad.explode_radius > 0.0 and squad.explode_damage > 0, "Suicide Squad blows up on contact")
	assert_true(captain.explode_on_death and not captain.explode_on_contact and captain.explode_radius > 0.0, "Captain blows up on death")
	assert_true(squad.damage_type == Enums.DamageType.BLAST, "Suicide Squad damage type is BLAST")


func test_squad_blast() -> void:
	print("\n[GROUP 2] Suicide Squad blast")
	var barricade := _tower(BARRICADE_SCENE, Vector3(0, 0, 0))
	var tower := _tower(ARROW_SCENE, Vector3(1.5, 0, 1.5))
	var wall_tower := _tower(ARROW_SCENE, Vector3(-1.0, 0, -1.5))
	wall_tower.add_to_group(&"tower_wall")
	var far_tower := _tower(ARROW_SCENE, Vector3(12, 0, 12))
	var neighbour := _unit(GRUNT_SCENE, Vector3(1.0, 0, 0), "Neighbour")
	var squad := _unit(SQUAD_SCENE, Vector3(0.8, 0, 0), "Squad")
	await _physics_frames()
	var hp := {"barricade": _hp(barricade), "tower": _hp(tower), "wall": _hp(wall_tower), "far": _hp(far_tower), "grunt": neighbour.health.hp}
	_died.clear()
	_telegraphs.clear()
	_cancels.clear()

	_attack(squad, barricade)
	assert_true(squad.is_fuse_lit(), "In reach of the Barricade the Squad lights its fuse")
	assert_true(_telegraphs.size() == 1 and is_equal_approx(_telegraphs[0].radius, squad.data.explode_radius) and is_equal_approx(_telegraphs[0].duration, squad.data.explode_windup), "A red ring telegraph of the blast radius and wind-up")
	assert_true(_hp(barricade) == hp.barricade, "No damage during the wind-up")

	squad._physics_process(squad.data.explode_windup * 0.5)
	assert_true(not squad.is_dead and squad.is_fuse_lit(), "Still winding up halfway")
	squad._physics_process(squad.data.explode_windup)
	assert_true(_hp(barricade) < hp.barricade, "The blast hits the Barricade")
	assert_true(_hp(tower) < hp.tower, "The blast hits a tower in its radius")
	assert_true(_hp(wall_tower) < hp.wall, "The blast hits a wall-slot tower in its radius")
	assert_true(_hp(far_tower) == hp.far, "A tower outside the radius is untouched")
	assert_true(neighbour.health.hp == hp.grunt, "No friendly fire on other units")
	assert_true(squad.is_dead and squad.self_destructed, "The Squad is gone after its blast")
	assert_true(_died.size() == 1 and _died[0].cull and _died[0].gold == 0.0, "Blowing up pays no gold, XP or kill, and the wave counts it as gone")
	await _physics_frames()
	assert_true(_cancels.is_empty(), "The ring is not cancelled when the blast comes")
	for n in [barricade, tower, wall_tower, far_tower, neighbour]:
		n.free()
	await _physics_frames()


func test_squad_killed_before_blast() -> void:
	print("\n[GROUP 3] Suicide Squad killed during its wind-up")
	var barricade := _tower(BARRICADE_SCENE, Vector3(0, 0, 0))
	var squad := _unit(SQUAD_SCENE, Vector3(0.8, 0, 0), "Squad2")
	await _physics_frames()
	var hp_before := _hp(barricade)
	_died.clear()
	_telegraphs.clear()
	_cancels.clear()
	_attack(squad, barricade)
	squad.take_damage(DamageInfo.new(squad.health.max_hp, Enums.DamageType.SLASH))
	assert_true(squad.is_dead and not squad.self_destructed and not squad.is_fuse_lit(), "Killed during the wind-up: dead, fuse out")
	assert_true(_cancels.size() == 1 and _cancels[0].kind == &"explode" and _telegraphs.size() == 1 and _cancels[0].pos.is_equal_approx(_telegraphs[0].pos), "Killed during the wind-up: its ring is cancelled where it was drawn")
	await get_tree().create_timer(squad.data.explode_windup + 0.2).timeout
	assert_true(_hp(barricade) == hp_before, "No blast when killed first")
	assert_true(_died.size() == 1 and not _died[0].cull and _died[0].gold > 0.0, "Killed first: normal reward")
	barricade.free()
	await _physics_frames()


func test_commander_dodge_and_mode() -> void:
	print("\n[GROUP 4] Commander: Frontline, Dodge and Commander mode")
	var commander = _commander(Vector3(0, 0, 0))
	await _physics_frames()
	var cases := [["Frontline", false, false], ["Dodging", true, false], ["Commander mode", false, true]]
	for c in cases:
		commander.is_dodging = c[1]
		commander.is_commander_mode = c[2]
		var before: int = commander.health.hp
		var squad := _unit(SQUAD_SCENE, Vector3(1.0, 0, 0), "Squad_" + c[0])
		await _physics_frames()
		squad.detonate()
		var took: bool = commander.health.hp < before
		if c[1] or c[2]:
			assert_true(not took, "%s: the blast does nothing to the commander" % c[0])
		else:
			assert_true(took, "Frontline: the blast hits the commander")
		squad.free()
	commander.is_dodging = false
	commander.is_commander_mode = false
	commander.queue_free()
	await _physics_frames()


func test_captain() -> void:
	print("\n[GROUP 5] Captain")
	var barricade := _tower(BARRICADE_SCENE, Vector3(0, 0, 0))
	var captain := _unit(CAPTAIN_SCENE, Vector3(1.0, 0, 0), "Captain")
	await _physics_frames()
	var hp_before := _hp(barricade)
	_died.clear()
	_telegraphs.clear()
	_cancels.clear()
	captain.take_damage(DamageInfo.new(captain.health.max_hp, Enums.DamageType.SLASH))
	assert_true(captain.is_dead and captain.blast_pending, "Killed, the Captain waits to blow up")
	assert_true(_died.size() == 1 and not _died[0].cull and _died[0].gold > 0.0, "Killed, the Captain still pays")
	assert_true(_telegraphs.size() == 1, "A red ring telegraph where it fell")
	assert_true(_hp(barricade) == hp_before, "No damage before the wind-up ends")
	await get_tree().create_timer(captain.data.explode_windup + 0.1, true, true).timeout
	assert_true(_hp(barricade) < hp_before, "The blast after the wind-up hits the Barricade")
	assert_true(not is_instance_valid(captain) or not captain.blast_pending, "The blast went off once")
	assert_true(_cancels.is_empty(), "The Captain's ring is not cancelled: its blast came")

	var hp_mid := _hp(barricade)
	var culled := _unit(CAPTAIN_SCENE, Vector3(1.0, 0, 0.5), "CulledCaptain")
	await _physics_frames()
	_died.clear()
	_telegraphs.clear()
	assert_true(culled.cull(&"HARD_CAP"), "A Captain can be culled")
	await get_tree().create_timer(culled.data.explode_windup + 0.2 if culled.data else 1.2).timeout
	assert_true(_hp(barricade) == hp_mid and _telegraphs.is_empty(), "Culled: no blast")
	assert_true(_died.size() == 1 and _died[0].cull, "Culled: no reward")
	barricade.free()


func test_ring_cancelled() -> void:
	print("\n[GROUP 6] The red ring is cancelled when no blast follows (FBK-06)")
	var barricade := _tower(BARRICADE_SCENE, Vector3(0, 0, 0))
	var squad := _unit(SQUAD_SCENE, Vector3(0.8, 0, 0), "CulledSquad")
	await _physics_frames()
	var hp_before := _hp(barricade)
	_telegraphs.clear()
	_cancels.clear()
	_attack(squad, barricade)
	assert_true(squad.is_fuse_lit() and _telegraphs.size() == 1, "The Squad lights its fuse")
	assert_true(squad.cull(&"STUCK"), "A lit Squad can be culled")
	assert_true(_cancels.size() == 1 and _cancels[0].kind == &"explode" and _cancels[0].pos.is_equal_approx(_telegraphs[0].pos), "Culled during the wind-up: its ring is cancelled")
	await _physics_frames()
	assert_true(_cancels.size() == 1, "Cancelled once, not again when it leaves the tree")

	var captain := _unit(CAPTAIN_SCENE, Vector3(1.0, 0, 0), "FreedCaptain")
	await _physics_frames()
	_telegraphs.clear()
	_cancels.clear()
	captain.take_damage(DamageInfo.new(captain.health.max_hp, Enums.DamageType.SLASH))
	assert_true(captain.blast_pending and _telegraphs.size() == 1 and _cancels.is_empty(), "Killed, the Captain shows its ring")
	var windup: float = captain.data.explode_windup
	captain.free()
	assert_true(_cancels.size() == 1 and _cancels[0].pos.is_equal_approx(_telegraphs[0].pos), "Freed before its blast: its ring is cancelled")
	await get_tree().create_timer(windup + 0.2, true, true).timeout
	assert_true(_hp(barricade) == hp_before, "Freed before its blast: no blast")

	var alive := _unit(CAPTAIN_SCENE, Vector3(1.0, 0, 0.5), "AliveCaptain")
	await _physics_frames()
	_cancels.clear()
	alive.cull(&"HARD_CAP")
	await _physics_frames()
	assert_true(_cancels.is_empty(), "A unit with no fuse lit sends no cancel")
	barricade.free()