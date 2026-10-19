extends Node3D

## Automated test runner for the Barricade (branch week3/barricade):
## - Data: 3 levels, HP 300 / 500 / 800, aggro_weight 1.0 / 1.2 / 1.5, GROUND only, never attacks (3.6.3)
## - TWR-06: 5 attack positions on an arc in front of the Barricade, a 6th unit is refused
## - TWR-05: enemies pick the Barricade with the smallest distance / aggro_weight
## - TWR-07, ETG-03: destroyed while 5 Grunts attack it, all 5 choose again at once; slot turns RUINED
## - CRD-02: the 6th Grunt waits, then skips the full Barricade and picks another target
## - SLOT-03: a unit that does not target the Barricade steers around it (avoidance, no re-bake)

const BARRICADE_SCENE: PackedScene = preload("res://entities/tower/barricade.tscn")
const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const BRUTE_SCENE: PackedScene = preload("res://entities/enemy/brute.tscn")
const SLOT_SCENE: PackedScene = preload("res://systems/build/slot.tscn")
const BARRICADE: TowerData = preload("res://data/towers/barricade.tres")

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []
var done := false


func _ready() -> void:
	print("\n=======================================================")
	print("          AUTOMATED BARRICADE RUNNER TEST              ")
	print("=======================================================")

	_add_floor()
	test_data()
	test_arc_slots()
	test_attacker_cap()
	test_aggro_weight()
	await test_destroyed_while_attacked()
	await test_extra_unit_skips_full()
	await test_avoidance()

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
## Enemies fall without a floor; this scene has no level.
func _add_floor() -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 400)
	col.shape = box
	body.add_child(col)
	body.position = Vector3(0, -0.5, -100)
	add_child(body)


func _barricade(pos: Vector3, level := 1) -> Barricade:
	var b := BARRICADE_SCENE.instantiate() as Barricade
	b.position = pos
	add_child(b)
	if level != 1:
		b.apply_level(level)
	return b


func _grunt(pos: Vector3, scene: PackedScene = GRUNT_SCENE) -> Enemy:
	var g := scene.instantiate() as Enemy
	g.position = pos
	add_child(g)
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


## Enemy keeps a per-frame static cache of towers; clear it after adding or removing some.
func _reset_enemy_cache() -> void:
	Enemy._last_cache_frame = -1


func _clear(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.free()
	_reset_enemy_cache()
#endregion


func test_data() -> void:
	print("\n[GROUP 1] Barricade data (3.6.3)")
	assert_true(BARRICADE.levels.size() == 3, "3 levels")
	var hp: Array[int] = []
	var w: Array[float] = []
	var cost: Array[int] = []
	for lv in BARRICADE.levels:
		hp.append(lv.max_hp)
		w.append(lv.aggro_weight)
		cost.append(lv.build_cost)
	var hp_ok: Array[int] = [300, 500, 800]
	var w_ok: Array[float] = [1.0, 1.2, 1.5]
	var cost_ok: Array[int] = [40, 60, 90]
	assert_true(hp == hp_ok, "HP 300 / 500 / 800 (got %s)" % [hp])
	assert_true(w == w_ok, "aggro_weight 1.0 / 1.2 / 1.5 (got %s)" % [w])
	assert_true(cost == cost_ok, "cost 40 / 60 / 90 (got %s)" % [cost])
	assert_true(BARRICADE.allowed_zones.size() == 1 and BARRICADE.allowed_zones[0] == Enums.SlotZone.GROUND, "GROUND zone only")

	var b := _barricade(Vector3(0, 0, -40))
	assert_true(b.is_in_group(&"barricade") and b.is_in_group(&"tower"), "in groups barricade and tower")
	assert_true(not b.can_attack() and not b.is_physics_processing(), "never attacks (TWR: tank building)")
	assert_true(is_equal_approx(b.aggro_weight, 1.0) and b.health.max_hp == 300, "level 1: weight 1.0, HP 300")
	b.apply_level(3)
	assert_true(is_equal_approx(b.aggro_weight, 1.5) and b.health.hp == 800, "level 3: weight 1.5, HP 800")
	var model_ok := true
	for i in range(1, 4):
		var n := b.find_child("Level%d" % i, true, false) as Node3D
		model_ok = model_ok and n != null and n.visible == (i == 3)
	assert_true(model_ok, "model shows only the Level3 mesh at level 3")
	var obstacle := b.get_node(^"NavigationObstacle3D") as NavigationObstacle3D
	assert_true(obstacle.avoidance_enabled and not obstacle.affect_navigation_mesh,
			"obstacle steers agents and does not change the navmesh (SLOT-03)")
	_clear([b])


func test_arc_slots() -> void:
	print("\n[GROUP 2] Attack positions: markers P0..P4 on a half circle in front of the blocking face (TWR-06)")
	var b := _barricade(Vector3(0, 0, -40))
	var body := (b.get_node(^"CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	assert_true(body.size.z > body.size.x, "the wall runs across the path (long side along Z)")
	var half := body.size * 0.5
	var pts := b.melee_slots.get_world_points()
	assert_true(pts.size() == GameConfig.max_attackers_per_barricade and pts.size() == 5, "5 attack positions")
	var marker_ok := true
	for i in pts.size():
		var m := b.melee_slots.get_node("P%d" % i) as Marker3D
		marker_ok = marker_ok and m != null and pts[i].is_equal_approx(m.global_position)
	assert_true(marker_ok, "positions come from the markers P0..P4 (no navmesh here, nothing moved)")
	# The half circle faces +X, where enemies come from.
	var on_front := true
	var clear := true
	var min_gap := INF
	for i in pts.size():
		var p := pts[i] - b.global_position
		on_front = on_front and p.x >= -0.01
		# Distance from the body box: a Grunt (radius 0.4) standing here does not touch the wall.
		var dx := maxf(absf(p.x) - half.x, 0.0)
		var dz := maxf(absf(p.z) - half.z, 0.0)
		clear = clear and Vector2(dx, dz).length() >= 0.4
		if i > 0:
			min_gap = minf(min_gap, pts[i].distance_to(pts[i - 1]))
	assert_true(on_front, "every position is on the front side")
	assert_true(clear, "every position is a Grunt width away from the wall")
	assert_true(min_gap >= 1.0, "neighbours at least 1.0 m apart (got %.2f)" % min_gap)
	var mid := pts[2] - b.global_position
	assert_true(absf(mid.z) < 0.01 and mid.x > half.x + 0.4, "middle position straight in front of the face (%.2f m out)" % (mid.x - half.x))
	var e0 := pts[0] - b.global_position
	var span := absf(e0.z)
	var e4 := pts[4] - b.global_position
	assert_true(absf(e0.z + span) < 0.01 and absf(e4.z - span) < 0.01 and absf(e0.x) < 0.01 and absf(e4.x) < 0.01,
			"half circle: ends %.1f m to each side, level with the centre" % span)
	# SLOT-03: Barricades in the two cells next to the 5 m lane (z = +-3.5) leave >= 3 m between
	# their attackers, enough for a Brute (avoid_radius 0.9).
	var gap_left := 2.0 * (3.5 - span - 0.5)
	assert_true(gap_left >= 3.0, "attackers of facing Barricades leave %.1f m of lane" % gap_left)
	_clear([b])


func test_attacker_cap() -> void:
	print("\n[GROUP 3] At most 5 attackers (TWR-06)")
	var b := _barricade(Vector3(0, 0, -40))
	var units: Array[Node3D] = []
	var took := 0
	for i in 6:
		var u := Node3D.new()
		u.position = b.position + Vector3(3, 0, -2.0 + i * 0.8)
		add_child(u)
		units.append(u)
		if b.claim_melee_slot(u):
			took += 1
	assert_true(took == 5, "5 of 6 units get a slot (got %d)" % took)
	assert_true(not b.has_melee_slot(units[5]) and b.get_free_melee_slots() == 0, "the 6th is refused")
	var spots := {}
	for u in units.slice(0, 5):
		spots[b.get_melee_slot_position(u)] = true
	assert_true(spots.size() == 5, "each attacker has its own position")
	b.release_melee_slot(units[0])
	assert_true(b.claim_melee_slot(units[5]), "a released slot goes to the waiting unit")
	units[1].free()
	units.remove_at(1)
	assert_true(b.get_free_melee_slots() == 1, "a unit leaving the tree frees its slot")
	b.take_damage(10000)
	assert_true(b.get_free_melee_slots() == 5 and not b.claim_melee_slot(units[0]),
			"destroyed: every slot freed, no new claims (TWR-07)")
	_clear(units)
	_clear([b])

	var b2 := _barricade(Vector3(0, 0, -40))
	var left := Node3D.new()
	left.position = b2.position + Vector3(0.5, 0, -3)
	var right := Node3D.new()
	right.position = b2.position + Vector3(0.5, 0, 3)
	add_child(left)
	add_child(right)
	b2.claim_melee_slot(right)
	b2.claim_melee_slot(left)
	var lz := b2.get_melee_slot_position(left).z - b2.position.z
	var rz := b2.get_melee_slot_position(right).z - b2.position.z
	var span := absf((b2.melee_slots.get_node("P0") as Marker3D).position.z)
	assert_true(is_equal_approx(lz, -span) and is_equal_approx(rz, span), "each unit takes the free position nearest to it")
	_clear([left, right, b2])


func test_aggro_weight() -> void:
	print("\n[GROUP 4] distance / aggro_weight (TWR-05)")
	var g := _grunt(Vector3(10, 0, -60))
	var near := _barricade(Vector3(4, 0, -60), 1)  # 6 m / 1.0 = 6.0
	var far := _barricade(Vector3(2, 0, -60), 3)   # 8 m / 1.5 = 5.3
	_reset_enemy_cache()
	assert_true(g._find_closest_valid_barricade() == far, "level 3 at 8 m beats level 1 at 6 m")
	far.apply_level(1)  # 8 / 1.0
	_reset_enemy_cache()
	assert_true(g._find_closest_valid_barricade() == near, "same level: the nearer one")
	_clear([g, near, far])


func test_destroyed_while_attacked() -> void:
	print("\n[GROUP 5] Destroyed while 5 Grunts attack it (TWR-07, ETG-03, EN-07)")
	var slot := SLOT_SCENE.instantiate() as Slot
	slot.slot_id = &"G_9_9"
	slot.position = Vector3(0, 0, -80)
	add_child(slot)
	var b := BARRICADE_SCENE.instantiate() as Barricade
	slot.place_tower(b)
	var goal := _goal(Vector3(-20, 0, -80))
	var grunts: Array[Enemy] = []
	for i in 5:
		grunts.append(_grunt(Vector3(5, 0, -82.0 + i)))
	_reset_enemy_cache()
	var frames := 0
	while frames < 600:
		await get_tree().physics_frame
		frames += 1
		var attacking := 0
		for g in grunts:
			if g.current_target == b and g.current_state == Enums.EnemyState.ATTACK:
				attacking += 1
		if attacking == 5:
			break
	var holding := 0
	var attacking_now := 0
	var states := PackedStringArray()
	for g in grunts:
		if b.has_melee_slot(g):
			holding += 1
		if g.current_target == b and g.current_state == Enums.EnemyState.ATTACK:
			attacking_now += 1
		states.append("%s@%s" % [Enums.EnemyState.keys()[g.current_state], str(g.global_position.snapped(Vector3.ONE * 0.1))])
	assert_true(holding == 5, "all 5 Grunts hold a slot")
	assert_true(attacking_now == 5, "all 5 attack at the same time (%d frames; %s)" % [frames, ", ".join(states)])
	await _frames(90)  # let the first swings land (wind-up)
	assert_true(b.health.hp < b.health.max_hp, "they are hitting it (HP %d)" % b.health.hp)

	b.take_damage(10000)
	assert_true(slot.state == Enums.SlotState.RUINED, "slot turns RUINED")
	await _frames(2)
	var moved_on := 0
	for g in grunts:
		# b is freed by now: compare by validity, a freed reference is not reliable with != .
		var new_target := g.has_target_position or (is_instance_valid(g.current_target) and g.current_target != b)
		if new_target and g.current_state != Enums.EnemyState.ATTACK and g.current_state != Enums.EnemyState.WAIT:
			moved_on += 1
	assert_true(moved_on == 5, "all 5 choose again within 2 frames (got %d)" % moved_on)
	await _frames(30)
	var walking := 0
	for g in grunts:
		if Vector2(g.velocity.x, g.velocity.z).length() > 0.5:
			walking += 1
	assert_true(walking == 5, "none of them stands still afterwards (got %d walking)" % walking)
	assert_true(slot.rubble_obstacle.avoidance_enabled, "rubble keeps an obstacle (SLOT-02)")
	_clear(grunts)
	_clear([slot, goal])


func test_extra_unit_skips_full() -> void:
	print("\n[GROUP 6] 6th Grunt waits, then picks another target (TWR-06, CRD-02)")
	var a := _barricade(Vector3(0, 0, -120))
	var b2 := _barricade(Vector3(-10, 0, -120))
	var goal := _goal(Vector3(-30, 0, -120))
	var grunts: Array[Enemy] = []
	for i in 6:
		grunts.append(_grunt(Vector3(5 + i * 0.3, 0, -122.5 + i)))
	_reset_enemy_cache()
	await _frames(90)
	var on_a := 0
	var waiting: Enemy = null
	for g in grunts:
		if a.has_melee_slot(g):
			on_a += 1
		elif g.current_state == Enums.EnemyState.WAIT and g.current_target == a:
			waiting = g
	assert_true(on_a == 5, "5 Grunts hold a slot on the first Barricade (got %d)" % on_a)
	assert_true(waiting != null, "the 6th waits")
	if waiting == null:
		_clear(grunts)
		_clear([a, b2, goal])
		return
	var already := waiting.wait_timer
	var frames := 0
	while waiting.current_target == a and frames < 300:
		await get_tree().physics_frame
		frames += 1
	var waited := already + frames / float(Engine.physics_ticks_per_second)
	assert_true(waiting.current_target == b2, "it switches to the other Barricade")
	assert_true(absf(waited - GameConfig.crowd_wait_retarget_time) < 0.2, "after waiting crowd_wait_retarget_time (%.2f s)" % waited)
	await _frames(30)
	assert_true(waiting.current_target == b2, "and does not come back while the first stays full")
	_clear(grunts)
	_clear([a, b2, goal])


func test_avoidance() -> void:
	print("\n[GROUP 7] Steering around a Barricade it does not target (SLOT-03)")
	var b := _barricade(Vector3(0, 0, -160))
	var goal := _goal(Vector3(-12, 0, -160))
	var brute := _grunt(Vector3(8, 0, -160), BRUTE_SCENE)  # Brute: FORTRESS only, ignores Barricades
	brute.set_target_position(goal.global_position)
	_reset_enemy_cache()
	var frames := 0
	while brute.global_position.x > -4.0 and frames < 900:
		await get_tree().physics_frame
		frames += 1
	var secs := frames / float(Engine.physics_ticks_per_second)
	assert_true(brute.global_position.x <= -4.0, "the Brute gets past the Barricade (%.1f s)" % secs)
	assert_true(b.health.hp == b.health.max_hp, "and never attacks it")
	_clear([brute, b, goal])
