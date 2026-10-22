extends Node3D

## Automated test runner for melee attack slots (branch week4/attack-slots, W6-MH3):
## - A tower on a GROUND cell has max_attackers_per_tower (3) positions, the
##   Barricade keeps max_attackers_per_barricade (5), all on the side facing the spawn
## - The 4th unit is refused, a released or freed holder frees its slot,
##   a destroyed tower frees every slot and refuses new claims
## - A tower on a WALL slot is in group tower_wall, refuses melee slots and melee
##   units never target it; ranged units still do and never take a slot
## - Live Grunts on an Arrow: 3 attack, the rest wait on crowd_wait_ring and
##   switch target after crowd_wait_retarget_time; a waiter takes a slot freed by a death and
##   walks round the tower to it
## - 20 Grunts at the Fortress in the level: 12 attack from their slots, 8 wait
##   behind them, a dead attacker is replaced
## - The same on an Arrow built on a GROUND cell of the level (navmesh, lane next to it)

const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
const CANNON_SCENE: PackedScene = preload("res://entities/tower/cannon.tscn")
const BARRICADE_SCENE: PackedScene = preload("res://entities/tower/barricade.tscn")
const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const ARCHER_SCENE: PackedScene = preload("res://entities/enemy/archer.tscn")
const SLOT_SCENE: PackedScene = preload("res://systems/build/slot.tscn")
const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []
var done := false


func _ready() -> void:
	print("\n=======================================================")
	print("          AUTOMATED ATTACK SLOT RUNNER TEST            ")
	print("=======================================================")

	_add_floor()
	test_marker_layout()
	test_claim_cap()
	await test_wall_tower()
	test_ranged_units_skip_slots()
	await test_grunts_on_arrow()
	await test_waiter_takes_freed_slot()
	await test_fortress_in_level()

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
## Enemies fall without a floor; the first groups have no level.
var _floor: StaticBody3D


func _add_floor() -> void:
	_floor = StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 400)
	col.shape = box
	_floor.add_child(col)
	_floor.position = Vector3(0, -0.5, -150)
	add_child(_floor)


## A tower that never shoots (no ProjectilePool here) and does not fall during the test.
func _tower(scene: PackedScene, pos: Vector3) -> Tower:
	var t := scene.instantiate() as Tower
	t.position = pos
	add_child(t)
	_harden(t)
	return t


func _harden(t: Tower) -> void:
	t.set_physics_process(false)
	t.health.max_hp = 100000
	t.health.hp = 100000


func _grunt(pos: Vector3, rules: Array[StringName] = [], scene: PackedScene = GRUNT_SCENE, parent: Node = self) -> Enemy:
	var g := scene.instantiate() as Enemy
	if not rules.is_empty():
		g.data = g.data.duplicate()
		g.data.target_rules = rules
	g.position = pos
	parent.add_child(g)
	g.spawn_grace = false
	g.is_in_spawn_zone = false
	g.change_state(Enums.EnemyState.ADVANCE)
	return g


## Where enemies walk when they have nothing to attack (Enemy._get_fortress_fallback_position).
func _goal(pos: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.position = pos
	add_child(m)
	m.add_to_group(&"fortress_spawn")
	return m


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _secs(frames: int) -> float:
	return frames / float(Engine.physics_ticks_per_second)


## Enemy keeps a per-frame static cache of towers; clear it after adding or removing some.
func _reset_enemy_cache() -> void:
	Enemy._last_cache_frame = -1


func _clear(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.free()
	_reset_enemy_cache()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _count(units: Array, pred: Callable) -> int:
	var n := 0
	for u in units:
		if is_instance_valid(u) and pred.call(u):
			n += 1
	return n


func _states(units: Array) -> String:
	var out := PackedStringArray()
	for u in units:
		if is_instance_valid(u):
			out.append(Enums.EnemyState.keys()[(u as Enemy).current_state])
	return ", ".join(out)
#endregion


func test_marker_layout() -> void:
	print("\n[GROUP 1] Attack positions: 3 per grid tower, 5 per Barricade, facing the spawn side")
	assert_true(GameConfig.max_attackers_per_tower == 3 and GameConfig.max_attackers_per_barricade == 5,
			"GameConfig: max_attackers_per_tower 3, max_attackers_per_barricade 5")
	for scene in [ARROW_SCENE, CANNON_SCENE]:
		var t := _tower(scene, Vector3(0, 0, -40))
		var label := String(t.data.id)
		var radius := ((t.get_node(^"CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D).radius
		var pts := t.melee_slots.get_world_points()
		assert_true(t.melee_slots is TowerMeleeSlots and not t.melee_slots is BarricadeMeleeSlots,
				"%s: uses TowerMeleeSlots" % label)
		assert_true(pts.size() == GameConfig.max_attackers_per_tower,
				"%s: %d attack positions (got %d)" % [label, GameConfig.max_attackers_per_tower, pts.size()])
		var front := true
		var clear := true
		var min_gap := INF
		for i in pts.size():
			var p := pts[i] - t.global_position
			front = front and p.x > 0.0
			# A Grunt (radius 0.4) standing here does not overlap the tower body.
			clear = clear and Vector2(p.x, p.z).length() - radius >= 0.4
			if i > 0:
				min_gap = minf(min_gap, pts[i].distance_to(pts[i - 1]))
		assert_true(front, "%s: every position is on the +X side (enemies come from +X)" % label)
		assert_true(clear, "%s: every position is a Grunt width clear of the body (radius %.1f)" % [label, radius])
		assert_true(min_gap >= 1.0, "%s: neighbours at least 1.0 m apart (got %.2f)" % [label, min_gap])
		var mid := pts[1] - t.global_position
		assert_true(absf(mid.z) < 0.01, "%s: the middle position is straight in front" % label)
		var walker := Node3D.new()
		assert_true(t.get_melee_slot_position(walker).is_equal_approx(pts[1]),
				"%s: a unit with no slot walks to the middle position" % label)
		walker.free()
		_clear([t])

	var b := _tower(BARRICADE_SCENE, Vector3(0, 0, -40)) as Barricade
	assert_true(b.melee_slots is BarricadeMeleeSlots, "Barricade: MeleeSlots uses BarricadeMeleeSlots")
	assert_true(b.melee_slots.get_world_points().size() == GameConfig.max_attackers_per_barricade,
			"Barricade: still %d attack positions" % GameConfig.max_attackers_per_barricade)
	assert_true(b.find_children("MeleeSlots*", "", false, false).size() == 1,
			"Barricade: one MeleeSlots node, the one inherited from tower.tscn")
	_clear([b])


func test_claim_cap() -> void:
	print("\n[GROUP 2] At most 3 attackers on a grid tower")
	for scene in [ARROW_SCENE, CANNON_SCENE]:
		var t := _tower(scene, Vector3(0, 0, -40))
		var label := String(t.data.id)
		var units: Array[Node3D] = []
		var took := 0
		for i in 4:
			var u := Node3D.new()
			u.position = t.position + Vector3(3, 0, -1.5 + i)
			add_child(u)
			units.append(u)
			if t.claim_melee_slot(u):
				took += 1
		assert_true(took == 3, "%s: 3 of 4 units get a slot (got %d)" % [label, took])
		assert_true(not t.has_melee_slot(units[3]) and t.get_free_melee_slots() == 0, "%s: the 4th is refused" % label)
		var spots := {}
		for u in units.slice(0, 3):
			spots[t.get_melee_slot_position(u)] = true
		assert_true(spots.size() == 3, "%s: each attacker has its own position" % label)
		t.release_melee_slot(units[0])
		assert_true(t.claim_melee_slot(units[3]), "%s: a released slot goes to the waiting unit" % label)
		units[1].free()
		units.remove_at(1)
		assert_true(t.get_free_melee_slots() == 1, "%s: a unit leaving the tree frees its slot" % label)
		t.take_damage(1000000)
		assert_true(t.health.hp == 0 and t.melee_slots.free_count() == 3 and not t.claim_melee_slot(units[0]),
				"%s: destroyed, every slot freed and no new claims" % label)
		_clear(units)
		_clear([t])


func test_wall_tower() -> void:
	print("\n[GROUP 3] Tower on a WALL slot: no melee slots, melee units skip it")
	var wall := SLOT_SCENE.instantiate() as Slot
	wall.slot_id = &"W_9"
	wall.zone = Enums.SlotZone.WALL
	wall.position = Vector3(0, 0, -60)  # same height as the floor: only the group tells it is a WALL tower
	add_child(wall)
	var on_wall := ARROW_SCENE.instantiate() as Tower
	wall.place_tower(on_wall)
	_harden(on_wall)
	var ground := SLOT_SCENE.instantiate() as Slot
	ground.slot_id = &"G_9_9"
	ground.zone = Enums.SlotZone.GROUND
	ground.position = Vector3(0, 0, -70)
	add_child(ground)
	var on_ground := ARROW_SCENE.instantiate() as Tower
	ground.place_tower(on_ground)
	_harden(on_ground)

	assert_true(on_wall.is_in_group(&"tower_wall") and not on_ground.is_in_group(&"tower_wall"),
			"Slot.place_tower adds group tower_wall only on WALL slots")
	var dummy := Node3D.new()
	add_child(dummy)
	assert_true(not on_wall.claim_melee_slot(dummy) and not on_wall.accepts_melee() and not on_wall.has_melee_slot(dummy),
			"WALL tower refuses melee slots (accepts_melee false)")
	assert_true(on_ground.claim_melee_slot(dummy), "GROUND tower gives a slot")
	on_ground.release_melee_slot(dummy)

	_clear([ground, dummy])

	# 2.5 m to the side, as a WALL tower is beside the lane: the check is about targeting, not the body.
	var g := _grunt(Vector3(4, 0, -62.5), [&"TOWER_GROUND"] as Array[StringName])
	var archer := _grunt(Vector3(14, 0, -60), [&"TOWER"] as Array[StringName], ARCHER_SCENE)
	var goal := _goal(Vector3(-20, 0, -60))
	_reset_enemy_cache()
	assert_true(not g._is_target_valid(on_wall), "a Grunt never takes the WALL tower as a target")
	assert_true(archer._is_target_valid(on_wall), "an Archer still may (ETG: ranged units hit TOWER_WALL)")
	_clear([archer])
	var touched := false
	for i in 120:
		await get_tree().physics_frame
		touched = touched or g.current_target == on_wall
	assert_true(not touched and g.current_state != Enums.EnemyState.ATTACK, "and walks past it (%s)" % _states([g]))
	assert_true(g.global_position.x < -1.0, "the Grunt is past the tower (x %.1f)" % g.global_position.x)
	assert_true(on_wall.health.hp == on_wall.health.max_hp, "the WALL tower is never hit")
	_clear([g, goal])
	_clear([wall])


func test_ranged_units_skip_slots() -> void:
	print("\n[GROUP 4] Ranged units do not take slots and aim at the tower body")
	var t := _tower(ARROW_SCENE, Vector3(0, 0, -90))
	var archer := _grunt(Vector3(12, 0, -90), [&"TOWER"] as Array[StringName], ARCHER_SCENE)
	var g := _grunt(Vector3(4, 0, -90), [&"TOWER_GROUND"] as Array[StringName])
	assert_true(not archer._uses_melee_slot(t) and g._uses_melee_slot(t), "only the Grunt uses the slots")
	assert_true(archer._get_attack_point(t).is_equal_approx(t.global_position),
			"Archer measures range to the tower centre, not to a slot")
	assert_true(g._get_attack_point(t).is_equal_approx(t.get_melee_slot_position(g)), "Grunt walks to a slot")
	_clear([archer, g, t])


func test_grunts_on_arrow() -> void:
	print("\n[GROUP 5] 6 Grunts on an Arrow: 3 attack, 3 wait on the ring, then switch target")
	var a := _tower(ARROW_SCENE, Vector3(0, 0, -120))
	var b := _tower(ARROW_SCENE, Vector3(-12, 0, -120))
	var goal := _goal(Vector3(-30, 0, -120))
	var rules: Array[StringName] = [&"TOWER_GROUND", &"FORTRESS"]
	var grunts: Array[Enemy] = []
	for i in 6:
		grunts.append(_grunt(Vector3(5.0 + (i % 2) * 0.6, 0, -122.5 + i), rules))
	_reset_enemy_cache()

	var on_a := func(g: Enemy) -> bool: return g.current_target == a
	var holding_a := func(g: Enemy) -> bool: return a.has_melee_slot(g)
	var attacking_a := func(g: Enemy) -> bool: return g.current_target == a and g.current_state == Enums.EnemyState.ATTACK
	var waiting_a := func(g: Enemy) -> bool: return g.current_target == a and g.current_state == Enums.EnemyState.WAIT
	var max_holders := 0
	var frames := 0
	while frames < 240:
		await get_tree().physics_frame
		frames += 1
		max_holders = maxi(max_holders, _count(grunts, holding_a))
		if _count(grunts, attacking_a) == 3 and _count(grunts, waiting_a) == 3:
			break
	assert_true(_count(grunts, on_a) == 6, "all 6 pick the nearest tower first")
	assert_true(_count(grunts, attacking_a) == 3, "3 attack it (%.1f s; %s)" % [_secs(frames), _states(grunts)])
	assert_true(_count(grunts, waiting_a) == 3, "the other 3 WAIT")

	# Let the waiters reach the ring, then check where they stand.
	await _frames(45)
	max_holders = maxi(max_holders, _count(grunts, holding_a))
	var ring_ok := true
	var dists := PackedStringArray()
	var waiters: Array[Enemy] = []
	for g in grunts:
		if waiting_a.call(g):
			waiters.append(g)
			var d := _flat(g.global_position, a.global_position)
			dists.append("%.2f" % d)
			ring_ok = ring_ok and d <= GameConfig.crowd_wait_ring + 0.6 and d >= 1.8
	assert_true(waiters.size() == 3 and ring_ok,
			"waiters stand on crowd_wait_ring %.0f m (distances %s)" % [GameConfig.crowd_wait_ring, ", ".join(dists)])
	var still := _count(waiters, func(g: Enemy) -> bool: return Vector2(g.velocity.x, g.velocity.z).length() < 0.2)
	assert_true(still == waiters.size(), "and stand still there (%d of %d)" % [still, waiters.size()])
	assert_true(a.health.hp < a.health.max_hp, "the 3 attackers are hitting the Arrow (HP %d)" % a.health.hp)

	# After crowd_wait_retarget_time the waiters skip the full Arrow and choose the next one.
	if waiters.is_empty():
		_clear(grunts)
		_clear([a, b, goal])
		return
	var first := waiters[0]
	var already := first.wait_timer
	frames = 0
	while first.current_target == a and frames < 300:
		await get_tree().physics_frame
		frames += 1
		max_holders = maxi(max_holders, _count(grunts, holding_a))
	var waited := already + _secs(frames)
	await _frames(2)
	var switched := _count(waiters, func(g: Enemy) -> bool: return g.current_target == b)
	assert_true(switched == 3, "the 3 waiters switch to the other Arrow (got %d; %s)" % [switched, _states(waiters)])
	assert_true(absf(waited - GameConfig.crowd_wait_retarget_time) < 0.2,
			"after waiting crowd_wait_retarget_time (%.2f s)" % waited)
	await _frames(60)
	max_holders = maxi(max_holders, _count(grunts, holding_a))
	assert_true(_count(waiters, on_a) == 0, "and do not come back while the first is full")
	assert_true(max_holders == 3, "never more than 3 slot holders on one Arrow (max %d)" % max_holders)
	_clear(grunts)
	_clear([a, b, goal])


func test_waiter_takes_freed_slot() -> void:
	print("\n[GROUP 6] A waiter takes the slot of a Grunt that dies")
	var a := _tower(CANNON_SCENE, Vector3(0, 0, -160))
	var goal := _goal(Vector3(-30, 0, -160))
	var rules: Array[StringName] = [&"TOWER_GROUND", &"FORTRESS"]
	var grunts: Array[Enemy] = []
	for i in 4:
		grunts.append(_grunt(Vector3(5.0, 0, -161.5 + i), rules))
	_reset_enemy_cache()
	var attacking := func(g: Enemy) -> bool: return g.current_target == a and g.current_state == Enums.EnemyState.ATTACK
	var waiting := func(g: Enemy) -> bool: return g.current_target == a and g.current_state == Enums.EnemyState.WAIT
	var frames := 0
	while frames < 240 and not (_count(grunts, attacking) == 3 and _count(grunts, waiting) == 1):
		await get_tree().physics_frame
		frames += 1
	assert_true(_count(grunts, attacking) == 3 and _count(grunts, waiting) == 1,
			"Cannon: 3 attack, 1 waits (%s)" % _states(grunts))
	var waiter: Enemy = null
	var victim: Enemy = null
	for g in grunts:
		if waiting.call(g):
			waiter = g
		elif victim == null and a.has_melee_slot(g):
			victim = g
	if waiter == null or victim == null:
		_clear(grunts)
		_clear([a, goal])
		return
	victim.take_damage(DamageInfo.new(999, Enums.DamageType.TRUE))
	frames = 0
	while frames < 30 and not a.has_melee_slot(waiter):
		await get_tree().physics_frame
		frames += 1
	assert_true(victim.is_dead and a.has_melee_slot(waiter),
			"the waiter takes the freed slot within %.2f s, before its wait timer runs out" % _secs(frames))
	frames = 0
	while frames < 180 and waiter.current_state != Enums.EnemyState.ATTACK:
		await get_tree().physics_frame
		frames += 1
	# It waited on the far side from the freed position: it walks round, not into the body.
	assert_true(waiter.current_state == Enums.EnemyState.ATTACK and waiter.current_target == a,
			"and attacks from it, walking round the tower (%.1f s)" % _secs(frames))
	# On its position, or boxed in within strike reach of it (Enemy stall rule, STALL_ATTACK_TIME).
	var off_slot := _flat(waiter.global_position, a.get_melee_slot_position(waiter))
	assert_true(off_slot <= waiter._melee_reach(), "at its position, within strike reach (%.2f m off)" % off_slot)
	assert_true(a.melee_slots.free_count() == 0, "3 holders again")
	_clear(grunts)
	_clear([a, goal])


func test_fortress_in_level() -> void:
	print("\n[GROUP 7] 20 Grunts at the Fortress in the level: 12 attack, 8 wait")
	_floor.free()
	var level := LEVEL_SCENE.instantiate()
	add_child(level)
	var fortress := get_tree().get_first_node_in_group(&"fortress") as Fortress
	EventBus.state_changed.emit(&"COMBAT")
	await _frames(3)
	var probe := Node3D.new()
	var gate_x := fortress.get_melee_slot_position(probe).x
	probe.free()

	var grunts: Array[Enemy] = []
	for i in 20:
		grunts.append(_grunt(Vector3(-8.0 + (i % 4) * 1.2, 0.1, -6.0 + floori(i / 4.0) * 3.0),
				[&"FORTRESS"] as Array[StringName], GRUNT_SCENE, level))
	_reset_enemy_cache()

	var holding := func(g: Enemy) -> bool: return fortress.has_melee_slot(g)
	var attacking := func(g: Enemy) -> bool: return g.current_target == fortress and g.current_state == Enums.EnemyState.ATTACK
	var waiting := func(g: Enemy) -> bool: return g.current_target == fortress and g.current_state == Enums.EnemyState.WAIT
	var max_holders := 0
	var frames := 0
	var settled := 0
	while frames < 900:
		await get_tree().physics_frame
		frames += 1
		max_holders = maxi(max_holders, _count(grunts, holding))
		if _count(grunts, attacking) == 12 and _count(grunts, waiting) == 8:
			settled += 1
			if settled >= 30:
				break
		else:
			settled = 0
	assert_true(_count(grunts, attacking) == 12 and _count(grunts, waiting) == 8,
			"12 ATTACK and 8 WAIT together for 0.5 s (%.1f s; %d attack, %d wait)"
			% [_secs(frames), _count(grunts, attacking), _count(grunts, waiting)])
	assert_true(max_holders == 12, "never more than 12 slot holders (max %d)" % max_holders)
	# Offsets from the slot line (stand_off in front of the wall), along the corridor.
	var on_slot := true
	var front := 0.0
	for g in grunts:
		if attacking.call(g):
			var off := g.global_position.x - gate_x
			on_slot = on_slot and off <= Tower.MELEE_ARRIVE_DISTANCE + 0.1
			front = maxf(front, off)
	assert_true(on_slot, "attackers stand on their slot along the wall (furthest %.2f m out)" % front)
	# Waiters walk in from where they were refused (up to crowd_claim_distance) towards
	# crowd_wait_ring; a crowd arriving together locks side by side in avoidance a little short of
	# it. A waiter queued right behind another one is a second row and may stand further out.
	var waiters: Array[Enemy] = []
	for g in grunts:
		if waiting.call(g):
			waiters.append(g)
	var ring_ok := true
	var offs := PackedStringArray()
	for w in waiters:
		var off := w.global_position.x - gate_x
		var behind_one := waiters.any(func(o: Enemy) -> bool:
			return o != w and o.global_position.x < w.global_position.x - 0.3 and _flat(o.global_position, w.global_position) < 1.5)
		offs.append("%.1f%s" % [off, " (2nd row)" if behind_one else ""])
		var far_limit := GameConfig.crowd_claim_distance - (0.3 if behind_one else 1.0)
		ring_ok = ring_ok and off >= GameConfig.crowd_wait_ring - 0.5 and off <= far_limit
	assert_true(ring_ok, "waiters stand behind the attackers, front row %.1f to %.1f m from the slot line (x offsets %s)"
			% [GameConfig.crowd_wait_ring - 0.5, GameConfig.crowd_claim_distance - 1.0, ", ".join(offs)])
	assert_true(fortress.get_hp() < fortress.get_max_hp(),
			"the attackers damage the Fortress (HP %d / %d)" % [fortress.get_hp(), fortress.get_max_hp()])

	var victim: Enemy = null
	for g in grunts:
		if attacking.call(g):
			victim = g
			break
	victim.take_damage(DamageInfo.new(999, Enums.DamageType.TRUE))
	await get_tree().physics_frame
	assert_true(fortress.get_free_melee_slots() >= 1 or _count(grunts, holding) == 12, "the dead Grunt frees its slot")
	frames = 0
	while frames < 60 and _count(grunts, holding) < 12:
		await get_tree().physics_frame
		frames += 1
	assert_true(_count(grunts, holding) == 12, "a waiter takes it within %.2f s" % _secs(frames))
	frames = 0
	while frames < 240 and _count(grunts, attacking) < 12:
		await get_tree().physics_frame
		frames += 1
	# Waiters cycle WAIT -> choose again -> WAIT every crowd_wait_retarget_time, so count the
	# living units without a slot rather than the WAIT state on one frame.
	# The killed Grunt is freed by now: untyped so the freed reference can be checked.
	var alive := grunts.filter(func(g) -> bool: return is_instance_valid(g) and not g.is_dead)
	var spare := alive.filter(func(g: Enemy) -> bool: return not holding.call(g))
	var spare_attacking := spare.filter(func(g: Enemy) -> bool: return g.current_state == Enums.EnemyState.ATTACK)
	assert_true(_count(grunts, attacking) == 12 and spare.size() == 7 and spare_attacking.is_empty(),
			"12 attack again, the other 7 have no slot and do not attack (%.1f s)" % _secs(frames))
	_clear(grunts)
	await test_tower_in_level(level)
	level.queue_free()
	await get_tree().process_frame


func test_tower_in_level(level: Node) -> void:
	print("\n[GROUP 8] Arrow on a GROUND cell of the level: 3 attack, 3 wait, a dead one is replaced")
	var slot: Slot = null
	var want := Vector3(2, 0, -3.5)  # cell next to the lane, toward the spawn side
	for s in get_tree().get_nodes_in_group(&"slot"):
		var sl := s as Slot
		if sl.zone == Enums.SlotZone.GROUND and (slot == null
				or _flat(sl.global_position, want) < _flat(slot.global_position, want)):
			slot = sl
	var t := ARROW_SCENE.instantiate() as Tower
	slot.place_tower(t)
	_harden(t)
	var pts := t.melee_slots.get_world_points()
	var map := t.get_world_3d().navigation_map
	var on_nav := true
	for p in pts:
		var c := NavigationServer3D.map_get_closest_point(map, p)
		on_nav = on_nav and _flat(c, p) <= t.melee_slots.nav_snap_distance + 0.01
	assert_true(on_nav, "all 3 positions are on the navmesh (slot %s)" % slot.slot_id)

	var grunts: Array[Enemy] = []
	for i in 6:
		grunts.append(_grunt(Vector3(8.0 + (i % 2) * 0.8, 0.1, -2.5 + i * 0.6),
				[&"TOWER_GROUND", &"FORTRESS"] as Array[StringName], GRUNT_SCENE, level))
	_reset_enemy_cache()
	var holding := func(g: Enemy) -> bool: return t.has_melee_slot(g)
	var attacking := func(g: Enemy) -> bool: return g.current_target == t and g.current_state == Enums.EnemyState.ATTACK
	var waiting := func(g: Enemy) -> bool: return g.current_target == t and g.current_state == Enums.EnemyState.WAIT
	var max_holders := 0
	var frames := 0
	while frames < 420 and not (_count(grunts, attacking) == 3 and _count(grunts, waiting) == 3):
		await get_tree().physics_frame
		frames += 1
		max_holders = maxi(max_holders, _count(grunts, holding))
	assert_true(_count(grunts, attacking) == 3 and _count(grunts, waiting) == 3,
			"3 attack, 3 wait (%.1f s; %s)" % [_secs(frames), _states(grunts)])
	var reach_ok := true
	for g in grunts:
		if attacking.call(g):
			reach_ok = reach_ok and _flat(g.global_position, t.get_melee_slot_position(g)) <= g._melee_reach()
	assert_true(reach_ok, "every attacker is within strike reach of its own position")
	await _frames(30)
	var dists := PackedStringArray()
	var ring_ok := true
	for g in grunts:
		if waiting.call(g):
			var d := _flat(g.global_position, t.global_position)
			dists.append("%.2f" % d)
			ring_ok = ring_ok and d >= GameConfig.crowd_wait_ring - 0.5 and d <= GameConfig.crowd_claim_distance - 1.0
	assert_true(ring_ok, "waiters stand near crowd_wait_ring (distances %s)" % ", ".join(dists))

	var victim: Enemy = null
	for g in grunts:
		if attacking.call(g):
			victim = g
			break
	victim.take_damage(DamageInfo.new(999, Enums.DamageType.TRUE))
	frames = 0
	while frames < 240 and _count(grunts, attacking) < 3:
		await get_tree().physics_frame
		frames += 1
		max_holders = maxi(max_holders, _count(grunts, holding))
	assert_true(_count(grunts, attacking) == 3, "a waiter replaces the dead attacker within %.1f s" % _secs(frames))
	assert_true(max_holders == 3, "never more than 3 slot holders (max %d)" % max_holders)
	_clear(grunts)
	slot.clear_tower()
	await get_tree().process_frame
