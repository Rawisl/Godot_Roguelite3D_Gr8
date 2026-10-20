extends Node3D

## Automated test runner for tower targeting (branch week4/tower-targeting):
## - TWR-16: nav_progress from lane_curve, same for walking and flying units, x fallback without a lane
## - TGT-01: First / Nearest on a fixed 5-enemy scene give the same pick whatever the spawn order;
##   ties go to the closer enemy, then the smaller entity id
## - EN-04, TGT-02: dead, spawn_grace and spawn-zone enemies are never targeted
## - TGT-04, DMG-02: an enemy immune to the tower's damage type (resist 0) is skipped
## - TGT-03, TIME-10: a priority change applies after retarget_delay in real time, at x1 and x3
## - TWR-15, ACP-01: 14 towers scanning 70 enemies stay under 1 ms per frame
## - TWR-15, test 7.1 item 6: the tower picks again on every scan, so a unit that overtakes
##   becomes the First target (and a unit that comes closer the Nearest target) within one scan

const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
const CANNON_SCENE: PackedScene = preload("res://entities/tower/cannon.tscn")
const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const POOL_SCENE: PackedScene = preload("res://entities/projectile/projectile_pool.tscn")
const IMMUNE_STUB: Script = preload("res://tests/resist_enemy_stub.gd")

## Same shape as the corridor level: spawn at x = 20, Fortress gate at x = -15 (35 m).
const LANE_FROM := Vector3(20, 0, 0)
const LANE_TO := Vector3(-15, 0, 0)
const SCAN_BUDGET_USEC := 1000

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []
var done := false
var _lane: Path3D


func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED TOWER TARGETING RUNNER TEST           ")
	print("=======================================================")
	add_child(POOL_SCENE.instantiate())
	_lane = _make_lane()

	await test_nav_progress()
	await test_first_nearest_deterministic()
	await test_tie_break()
	await test_valid_targets()
	await test_retarget_delay()
	await test_scan_cost()
	await test_repick_every_scan()

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
func _make_lane() -> Path3D:
	var path := Path3D.new()
	path.name = "LaneCurve"
	path.curve = Curve3D.new()
	path.curve.add_point(LANE_FROM)
	path.curve.add_point(LANE_TO)
	path.add_to_group(&"lane_curve")
	add_child(path)
	return path


## The runner only needs bodies and positions. Each KayKit Grunt model has about 10 meshes
## using the toon shader's instance uniform, so 70 of them overflow the instance buffer
## (256 meshes) when the scene is rendered. Removing the model keeps the log clean with F6.
func _strip_model(g: Enemy) -> void:
	var model := g.get_node_or_null(^"Model")
	if model == null:
		return
	for child in model.get_children():
		model.remove_child(child)
		child.free()


## A Grunt that stays where it is put: no AI, no grace, no model, progress computed now.
func _grunt(pos: Vector3, label := "") -> Enemy:
	var g := GRUNT_SCENE.instantiate() as Enemy
	_strip_model(g)
	if label != "":
		g.name = label
	g.position = pos
	add_child(g)
	g.set_physics_process(false)
	g.spawn_grace = false
	g.is_in_spawn_zone = false
	g.update_nav_progress()
	return g


func _arrow(pos: Vector3) -> Tower:
	var t := ARROW_SCENE.instantiate() as Tower
	t.position = pos
	add_child(t)
	return t


## Area overlaps are only refreshed on a physics step.
func _physics_frames(n := 2) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _clear(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.free()


## Physics frames until the tower's own scan sets `want` as its target, -1 if it never does.
func _frames_until_target(t: Tower, want: Enemy, max_frames: int) -> int:
	for i in max_frames:
		await get_tree().physics_frame
		if t.target == want:
			return i + 1
	return -1


func _pick_name(t: Tower) -> String:
	var e := t._pick_target()
	return String(e.name) if e != null else "<none>"
#endregion


func test_nav_progress() -> void:
	print("\n[GROUP 1] nav_progress along lane_curve (TWR-16, TWR-15)")
	var length := LANE_FROM.distance_to(LANE_TO)
	var a := _grunt(Vector3(10, 0, 0))
	var b := _grunt(Vector3(10, 0, 3.5))
	var flyer := _grunt(Vector3(10, 0, 0))
	flyer.global_position = Vector3(10, 5, 0)
	flyer.update_nav_progress()
	var gate := _grunt(Vector3(-15, 0, 0))
	var spawn := _grunt(Vector3(20, 0, 0))
	assert_true(is_equal_approx(spawn.nav_progress, 0.0), "spawn end of the lane: 0 m (%.2f)" % spawn.nav_progress)
	assert_true(is_equal_approx(gate.nav_progress, length), "Fortress gate: lane length %.0f m (%.2f)" % [length, gate.nav_progress])
	assert_true(is_equal_approx(a.nav_progress, 10.0), "x = 10 on the lane: 10 m (%.2f)" % a.nav_progress)
	assert_true(absf(b.nav_progress - a.nav_progress) < 0.01, "off the centre line, same x: same progress (%.2f)" % b.nav_progress)
	assert_true(absf(flyer.nav_progress - a.nav_progress) < 0.01, "flying unit above the same point: same progress (%.2f)" % flyer.nav_progress)

	# Without a lane the x projection is used.
	remove_child(_lane)
	a.update_nav_progress()
	assert_true(is_equal_approx(a.nav_progress, -10.0), "no lane_curve: fallback -x (%.2f)" % a.nav_progress)
	add_child(_lane)
	a.update_nav_progress()
	assert_true(is_equal_approx(a.nav_progress, 10.0), "lane added back: lane progress again (%.2f)" % a.nav_progress)
	# Enemy._setup_navigation is deferred and then waits one physics frame; free only after it ran.
	await get_tree().process_frame
	await _physics_frames()
	_clear([a, b, flyer, gate, spawn])


## Five enemies around one Arrow. Expected picks are fixed by the layout, so the result must
## not depend on the order the enemies were spawned in.
func test_first_nearest_deterministic() -> void:
	print("\n[GROUP 2] First / Nearest on a fixed 5-enemy scene (TGT-01, TWR-16)")
	var layout := {
		"E1": Vector3(8, 0, 2),    # far from the gate, far from the tower
		"E2": Vector3(2, 0, -1),   # closest to the tower
		"E3": Vector3(-6, 0, 4),   # closest to the gate (First)
		"E4": Vector3(4, 0, 6),
		"E5": Vector3(-3, 0, -5),
	}
	var orders := [["E1", "E2", "E3", "E4", "E5"], ["E5", "E4", "E3", "E2", "E1"], ["E3", "E1", "E5", "E2", "E4"]]
	var firsts: Array[String] = []
	var nearests: Array[String] = []
	for order in orders:
		var t := _arrow(Vector3.ZERO)
		var spawned: Array = []
		for id in order:
			spawned.append(_grunt(layout[id], id))
		await _physics_frames()
		t.priority = Enums.TargetPriority.FIRST
		firsts.append(_pick_name(t))
		t.priority = Enums.TargetPriority.NEAREST
		nearests.append(_pick_name(t))
		_clear(spawned + [t])
	print("    First picks %s, Nearest picks %s" % [firsts, nearests])
	assert_true(firsts == ["E3", "E3", "E3"], "First picks E3 (largest nav_progress) in every spawn order")
	assert_true(nearests == ["E2", "E2", "E2"], "Nearest picks E2 (closest to the tower) in every spawn order")


func test_tie_break() -> void:
	print("\n[GROUP 3] Tie-break: closer to the tower, then smaller entity id (TGT-01)")
	var t := _arrow(Vector3.ZERO)
	# Same x, so the same nav_progress; B is closer to the tower.
	var a := _grunt(Vector3(-4, 0, 6), "A")
	var b := _grunt(Vector3(-4, 0, 2), "B")
	await _physics_frames()
	t.priority = Enums.TargetPriority.FIRST
	assert_true(is_equal_approx(a.nav_progress, b.nav_progress), "A and B have the same nav_progress")
	assert_true(_pick_name(t) == "B", "First tie: the closer enemy wins (B)")
	_clear([a, b])

	# Same x and the same distance (mirrored on z): the smaller entity id wins.
	var c := _grunt(Vector3(-4, 0, 3), "C")
	var d := _grunt(Vector3(-4, 0, -3), "D")
	await _physics_frames()
	var expected := "C" if c.get_instance_id() < d.get_instance_id() else "D"
	assert_true(_pick_name(t) == expected, "First tie at equal distance: smaller entity id wins (%s)" % expected)
	t.priority = Enums.TargetPriority.NEAREST
	assert_true(_pick_name(t) == expected, "Nearest tie at equal distance: smaller entity id wins (%s)" % expected)
	_clear([c, d, t])


func test_valid_targets() -> void:
	print("\n[GROUP 4] Valid targets (EN-04, TGT-02, TGT-04)")
	var t := _arrow(Vector3.ZERO)
	var ok := _grunt(Vector3(-3, 0, 0), "Ok")
	var grace := _grunt(Vector3(-2, 0, 1), "Grace")
	grace.spawn_grace = true
	var in_zone := _grunt(Vector3(-2, 0, -1), "InZone")
	in_zone.is_in_spawn_zone = true
	var dead := _grunt(Vector3(-1, 0, 0), "Dead")
	dead.is_dead = true
	await _physics_frames()
	assert_true(t._is_valid_target(ok), "normal enemy in range is valid")
	assert_true(not t._is_valid_target(grace), "enemy in spawn_grace is not targeted (EN-04)")
	assert_true(not t._is_valid_target(in_zone), "enemy still inside the spawn zone is not targeted (EN-04)")
	assert_true(not t._is_valid_target(dead), "dead enemy is not targeted")
	t.priority = Enums.TargetPriority.NEAREST
	assert_true(_pick_name(t) == "Ok", "Nearest skips the closer untargetable ones and picks Ok")
	_clear([ok, grace, in_zone, dead])

	var immune := _resist_grunt(Vector3(-2, 0, 0), {Enums.DamageType.PIERCE: 0.0})
	var resists := _resist_grunt(Vector3(-4, 0, 0), {Enums.DamageType.PIERCE: 0.5})
	await _physics_frames()
	assert_true(not t._is_valid_target(immune), "resist 0 to PIERCE: the Arrow skips it (TGT-04, DMG-02)")
	assert_true(t._is_valid_target(resists), "resist 0.5 to PIERCE: still a valid target")
	var cannon := CANNON_SCENE.instantiate() as Tower
	cannon.position = Vector3(-10, 0, 0)
	add_child(cannon)
	await _physics_frames()
	assert_true(cannon._is_valid_target(immune), "the same enemy is valid for the Cannon (BLAST not resisted)")
	_clear([immune, resists, cannon])

	# TGT-02: nothing valid left, the tower idles.
	assert_true(t._pick_target() == null, "no valid enemy: no target (idle)")
	_clear([t])


func _resist_grunt(pos: Vector3, table: Dictionary) -> Enemy:
	var g := GRUNT_SCENE.instantiate() as Enemy
	_strip_model(g)
	var data := g.data
	g.set_script(IMMUNE_STUB)
	g.set(&"data", data)
	g.set(&"resist_table", table)
	g.position = pos
	add_child(g)
	g.set_physics_process(false)
	g.spawn_grace = false
	g.is_in_spawn_zone = false
	g.update_nav_progress()
	return g


func test_retarget_delay() -> void:
	print("\n[GROUP 5] Priority change after retarget_delay in real time (TGT-03, TIME-10)")
	var delay := GameConfig.retarget_delay
	for level in [1, 3]:
		TimeManager.set_time_scale(level)
		var t := _arrow(Vector3(0, 0, 40))
		await _physics_frames()
		t.priority = Enums.TargetPriority.FIRST
		t.set_priority(Enums.TargetPriority.NEAREST)
		var asked := TimeManager.real_time
		await _wait_real(delay * 0.5)
		var early := t.priority
		while t.priority != Enums.TargetPriority.NEAREST and TimeManager.real_time - asked < 2.0:
			await get_tree().physics_frame
		var took := TimeManager.real_time - asked
		assert_true(early == Enums.TargetPriority.FIRST, "x%d: not applied yet after %.2f s" % [level, delay * 0.5])
		assert_true(t.priority == Enums.TargetPriority.NEAREST and took >= delay and took < delay + 0.2,
			"x%d: applied after %.2f s of real time (retarget_delay %.1f s)" % [level, took, delay])
		_clear([t])
	TimeManager.reset_time_scale()


## Towers get their scan phase from the slot_id (TWR-15), so in a real frame only the towers
## whose phase falls in that frame pick a target. The 14 slot ids of the corridor are used here,
## and the worst frame of one scan_interval at 60 FPS is measured.
func test_scan_cost() -> void:
	print("\n[GROUP 6] Scan cost: 14 towers, 70 enemies (TWR-15, ACP-01)")
	var slot_ids := ["W1", "W2", "W3", "W4", "W5", "W6",
		"G_0_0", "G_0_1", "G_0_2", "G_0_3", "G_1_0", "G_1_1", "G_1_2", "G_1_3"]
	var towers: Array = []
	for i in 14:
		var t := _arrow(Vector3(-12 + (i % 7) * 4.0, 0, -4 if i < 7 else 4))
		t.scan_phase = _slot_phase(StringName(slot_ids[i]))
		towers.append(t)
	var enemies: Array = []
	for i in 70:
		enemies.append(_grunt(Vector3(-14 + (i % 14) * 2.0, 0, -6 + (i / 14) * 3.0)))
	await _physics_frames(3)
	var overlap := 0
	for t in towers:
		overlap += (t as Tower).range_area.get_overlapping_bodies().size()
	print("    average enemies in range per tower: %.1f" % (overlap / 14.0))

	# Cost of one pick per tower, averaged over many rounds.
	var rounds := 50
	var pick_usec: Array[float] = []
	for t in towers:
		var start := Time.get_ticks_usec()
		for r in rounds:
			(t as Tower)._pick_target()
		pick_usec.append(float(Time.get_ticks_usec() - start) / rounds)

	# Group the picks by the physics frame their phase falls in.
	var frames_per_scan := int(round(GameConfig.scan_interval * 60.0))
	var per_frame: Array[float] = []
	per_frame.resize(frames_per_scan)
	per_frame.fill(0.0)
	var all_in_one := 0.0
	for i in towers.size():
		var slot := int((towers[i] as Tower).scan_phase * frames_per_scan) % frames_per_scan
		per_frame[slot] += pick_usec[i]
		all_in_one += pick_usec[i]
	var worst: float = per_frame.max()
	print("    one pick: %.0f us on average; worst frame with slot phases: %.0f us; all 14 in one frame: %.0f us"
		% [all_in_one / towers.size(), worst, all_in_one])
	assert_true(worst < SCAN_BUDGET_USEC, "worst frame of scans under 1 ms (%.0f us)" % worst)
	_clear(towers + enemies)


## Same formula as Slot._scan_phase.
func _slot_phase(slot_id: StringName) -> float:
	return float(absi(rand_from_seed(hash(slot_id))[0]) % 1000) / 1000.0


## The tower runs on its own here (_physics_process and _scan), not through _pick_target.
## It keeps no target between scans: a valid target that is no longer the best is replaced
## at the next scan. Shots are held back so no enemy dies during the test.
func test_repick_every_scan() -> void:
	print("\n[GROUP 7] Pick again on every scan (TWR-15, test 7.1 item 6)")
	var scan_frames := int(ceil(GameConfig.scan_interval * Engine.physics_ticks_per_second))
	var budget := scan_frames + 2
	var t := _arrow(Vector3.ZERO)
	t.priority = Enums.TargetPriority.FIRST
	var a := _grunt(Vector3(-3, 0, 2), "A")
	var b := _grunt(Vector3(2, 0, -2), "B")
	t._cooldown = 1.0e9
	var first_a := await _frames_until_target(t, a, budget * 2)
	assert_true(first_a > 0, "First: A leads (%.1f m vs %.1f m) and becomes the target" % [a.nav_progress, b.nav_progress])

	# B overtakes A while A is still a valid target.
	b.global_position = Vector3(-5, 0, -2)
	b.update_nav_progress()
	var took := await _frames_until_target(t, b, budget * 2)
	assert_true(took > 0 and took <= budget,
		"First: B overtakes A, target switches to B within one scan (%d frames, budget %d)" % [took, budget])

	t.priority = Enums.TargetPriority.NEAREST
	var near_a := await _frames_until_target(t, a, budget * 2)
	assert_true(near_a > 0, "Nearest: A is closer and becomes the target")
	b.global_position = Vector3(1, 0, -1)
	b.update_nav_progress()
	took = await _frames_until_target(t, b, budget * 2)
	assert_true(took > 0 and took <= budget,
		"Nearest: B comes closer, target switches to B within one scan (%d frames, budget %d)" % [took, budget])
	_clear([a, b, t])
