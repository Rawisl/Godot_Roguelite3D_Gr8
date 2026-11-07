extends Node

const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const BULWARK_SCENE: PackedScene = preload("res://entities/enemy/bulwark.tscn")
const EPS := 0.0001

var passes: int = 0
var fails: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("          DAMAGE FORMULA VERIFICATION RUNNER           ")
	print("=======================================================")
	test_mult_stacking()
	test_rounding_and_floor()
	test_boss_rules()
	test_dot_remainder()
	test_true_damage()
	test_reused_info_and_boss_by_data()
	await test_resolve_on_enemy()
	await test_cap_hook()
	print("=======================================================")
	print("DAMAGE FORMULA TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================")
	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


func assert_near(actual: float, expected: float, test_name: String) -> void:
	assert_true(absf(actual - expected) < EPS, "%s (got %s, want %s)" % [test_name, actual, expected])


func test_mult_stacking() -> void:
	print("\n[GROUP 1] dealt adds, taken multiplies")
	assert_near(DamageCalc.dealt_mult([0.2, 0.1]), 1.3, "dealt +20% and +10% = x1.3")
	assert_near(DamageCalc.taken_mult([0.8, 0.5]), 0.4, "taken 0.8 x 0.5 = 0.4")
	assert_true(DamageCalc.hit(10.0, 1.3, 1.0, 1.0, false) == 13, "raw 10 x1.3 = 13")


func test_rounding_and_floor() -> void:
	print("\n[GROUP 2] one rounding at the end, floor of 1 on regular enemies")
	assert_true(DamageCalc.hit(20.0, 1.25, 0.8, 1.0, false) == 20, "Fury + Armored on raw 20 = exactly 20")
	assert_true(DamageCalc.hit(1.0, 1.25, 0.8, 1.0, false) == 1, "raw 1 stays 1")
	assert_true(DamageCalc.hit(1.0, 1.0, 0.1, 1.0, false) == 1, "floor of 1 when raw > 0")
	assert_true(DamageCalc.hit(0.0, 1.0, 1.0, 1.0, false) == 0, "raw 0 stays 0")


func test_boss_rules() -> void:
	print("\n[GROUP 3] boss resist, no floor, immunity")
	assert_true(DamageCalc.hit(1.0, 1.0, 1.0, 0.6, true) == 1, "boss raw 1 x0.6 = 1")
	assert_true(DamageCalc.hit(1.0, 1.0, 1.0, 0.4, true) == 0, "boss raw 1 x0.4 = 0 (no floor)")
	assert_true(DamageCalc.hit(100.0, 1.0, 1.0, 0.0, true) == 0, "resist 0 = 0")
	var info := DamageInfo.outgoing(100.0, 1.0, Enums.DamageType.PIERCE)
	var stub: Node = preload("res://tests/resist_enemy_stub.gd").new()
	stub.set(&"resist_table", {Enums.DamageType.PIERCE: 0.0})
	assert_true(DamageCalc.resolve(info, stub) == 0 and info.immune, "resist 0 marks the hit IMMUNE")
	stub.free()


func test_dot_remainder() -> void:
	print("\n[GROUP 4] DoT keeps the fractional part")
	var rem := 0.0
	var total := 0
	for i in 5:
		var t := DamageCalc.dot_tick(rem, 2.5, 1.0, 1.0, 1.0)
		total += int(t[0])
		rem = float(t[1])
	assert_true(total == 12, "5 ticks of 2.5 deal 12")
	assert_near(rem, 0.5, "remainder 0.5 kept")
	rem = 0.0
	total = 0
	for i in 4:
		var t := DamageCalc.dot_tick(rem, 6.0, 1.05, 1.0, 1.0)
		total += int(t[0])
		rem = float(t[1])
	assert_true(total == 25, "4 ticks of 6 x1.05 deal 25")


func test_true_damage() -> void:
	print("\n[GROUP 5] TRUE ignores multipliers")
	var info := DamageInfo.outgoing(10.0, 2.0, Enums.DamageType.TRUE)
	assert_true(DamageCalc.resolve(info, null) == 10, "TRUE deals raw only")


func _new_grunt() -> Enemy:
	var g: Enemy = GRUNT_SCENE.instantiate() as Enemy
	add_child(g)
	g.spawn_grace = false
	return g


func test_resolve_on_enemy() -> void:
	print("\n[GROUP 6] Enemy.take_damage applies the formula")
	var g := _new_grunt()
	await get_tree().process_frame
	g.spawn_grace = false
	var before := g.health.hp
	var dealt: int = g.take_damage(DamageInfo.outgoing(10.0, 1.3, Enums.DamageType.SLASH))
	assert_true(dealt == 13 and g.health.hp == before - 13, "x1.3 on raw 10 removes 13 HP")
	var dot := DamageInfo.outgoing(2.5, 1.0, Enums.DamageType.BLAST, null, 0.0, Vector3.ZERO, true)
	g.take_damage(dot)
	assert_near(g.health.dot_remainder, 0.5, "DoT tick stores remainder on the HealthComponent")
	g.queue_free()


func test_cap_hook() -> void:
	print("\n[GROUP 7] cap hook can be switched on and off")
	var g := _new_grunt()
	await get_tree().process_frame
	g.spawn_grace = false
	g.health.set_max_hp(1000)
	g.health.hp = 1000
	var caller := Node3D.new()
	caller.add_to_group(&"commander")
	add_child(caller)
	DamageCalc.set_cap_hook(func(_i: DamageInfo, _t: Node) -> int: return 10)
	assert_true(DamageCalc.has_cap_hook(), "hook installed")
	assert_true(g.take_damage(DamageInfo.outgoing(100.0, 1.0, Enums.DamageType.SLASH, caller)) == 10, "capped to 10")
	DamageCalc.clear_cap_hook()
	assert_true(not DamageCalc.has_cap_hook(), "hook cleared")
	assert_true(g.take_damage(DamageInfo.outgoing(100.0, 1.0, Enums.DamageType.SLASH, caller)) == 100, "uncapped again")
	DamageCalc.set_cap_hook(func(_i: DamageInfo, _t: Node) -> int: return -1)
	assert_true(g.take_damage(DamageInfo.outgoing(100.0, 1.0, Enums.DamageType.SLASH, caller)) == 100, "negative cap means no cap")
	DamageCalc.clear_cap_hook()
	caller.queue_free()
	g.queue_free()


func test_reused_info_and_boss_by_data() -> void:
	print("\n[GROUP 8] one DamageInfo reused across targets")
	var info := DamageInfo.outgoing(10.0, 1.0, Enums.DamageType.PIERCE)
	var plain: Node = preload("res://tests/resist_enemy_stub.gd").new()
	var immune: Node = preload("res://tests/resist_enemy_stub.gd").new()
	immune.set(&"resist_table", {Enums.DamageType.PIERCE: 0.0})
	assert_true(DamageCalc.resolve(info, immune) == 0 and info.immune, "first target immune")
	assert_true(DamageCalc.resolve(info, plain) == 10 and not info.immune, "second target takes full damage")
	plain.free()
	immune.free()
	var boss := BULWARK_SCENE.instantiate()
	assert_true(boss.get(&"data") is BossData, "Bulwark is a boss by data before _ready")
	boss.free()
