extends Node
## Runner for enemy Slow and Burn, the way the Bulwark takes them, and the RESIST / IMMUNE numbers.
## Prints PASS/FAIL then quits.

const GRUNT := "res://entities/enemy/grunt.tscn"
const BULWARK := "res://entities/enemy/bulwark.tscn"
const RESIST_STUB := preload("res://tests/resist_enemy_stub.gd")

var passes: int = 0
var fails: int = 0
var _layer: DamageNumberLayer


func _ready() -> void:
	print("\n=======================================================")
	print("          STATUS EFFECTS VERIFICATION                   ")
	print("=======================================================")

	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 10, 10)
	camera.look_at(Vector3.ZERO)
	camera.make_current()

	test_slow()
	test_slow_refusals()
	test_burn()
	test_burn_refresh_and_clock()
	test_bulwark_status()
	await test_numbers()

	print("=======================================================")
	print("STATUS EFFECTS TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================")
	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


func _new_enemy(scene: String, pos: Vector3 = Vector3.ZERO) -> Enemy:
	var enemy: Enemy = (load(scene) as PackedScene).instantiate()
	add_child(enemy)
	enemy.global_position = pos
	enemy.spawn_grace = false
	enemy.is_in_spawn_zone = false
	enemy.set_physics_process(false)
	return enemy


## Walking speed the unit would use on the next step along +X.
func _walk_speed(enemy: Enemy) -> float:
	enemy._move_towards_direction(Vector3.RIGHT)
	return enemy.velocity.x


func _commander_stub() -> Node3D:
	var node := Node3D.new()
	node.add_to_group(&"commander")
	add_child(node)
	return node


func test_slow() -> void:
	print("\n[GROUP 1] Slow 20% for 3 s")
	var enemy := _new_enemy(GRUNT)
	var base := _walk_speed(enemy)
	assert_true(base > 0.0 and enemy.get_slow_factor() == 1.0, "no slow at the start")
	assert_true(enemy.apply_slow(0.2, 3.0), "slow is accepted")
	assert_true(is_equal_approx(_walk_speed(enemy), base * 0.8), "speed is x0.8")
	enemy._tick_status(1.0)
	enemy._tick_status(1.0)
	assert_true(is_equal_approx(enemy.slow_timer, 1.0), "1 s left at second 2")
	enemy.apply_slow(0.2, 3.0)
	assert_true(is_equal_approx(enemy.slow_timer, 3.0), "a second hit resets the timer to 3 s")
	assert_true(is_equal_approx(_walk_speed(enemy), base * 0.8), "it does not stack to 40%")
	enemy._tick_status(3.0)
	assert_true(enemy.slow_timer == 0.0 and is_equal_approx(_walk_speed(enemy), base), "after 3 s the speed is back to x1.0")
	enemy.apply_slow(0.2, 3.0)
	enemy.speed_multiplier = 1.5
	assert_true(is_equal_approx(_walk_speed(enemy), base * 1.5 * 0.8), "slow multiplies with the enrage factor")
	enemy.speed_multiplier = 1.0
	enemy.free()


func test_slow_refusals() -> void:
	print("\n[GROUP 2] Slow is refused for the dead, spawning units and resist 0")
	var dead := _new_enemy(GRUNT)
	dead.is_dead = true
	assert_true(not dead.apply_slow(0.2, 3.0) and dead.slow_timer == 0.0, "dead unit")
	dead.is_dead = false
	dead.spawn_grace = true
	assert_true(not dead.apply_slow(0.2, 3.0) and dead.slow_timer == 0.0, "unit in spawn_grace")
	dead.free()

	var stub := _new_enemy("res://entities/enemy/grunt.tscn")
	stub.set_script(RESIST_STUB)
	stub.spawn_grace = false
	stub.resist_table = {Enums.DamageType.PIERCE: 0.0}
	assert_true(not stub.apply_slow(0.2, 3.0, Enums.DamageType.PIERCE), "resist 0 for the hit's damage type")
	assert_true(stub.apply_slow(0.2, 3.0, Enums.DamageType.SLASH), "resist 1 for another type")
	stub.free()


func test_burn() -> void:
	print("\n[GROUP 3] Burn: 5 ticks, the fractions are kept")
	var enemy := _new_enemy(GRUNT)
	enemy.health.max_hp = 1000
	enemy.health.hp = 1000
	var owner_node := _commander_stub()
	assert_true(enemy.apply_burn(12.5, 5.0, Enums.DamageType.SLASH, owner_node), "burn is accepted")
	var lost: Array[int] = []
	var before := enemy.health.hp
	for i in 5:
		enemy._tick_status(1.0)
		lost.append(before - enemy.health.hp)
		before = enemy.health.hp
	assert_true(lost == [2, 3, 2, 3, 2], "2.5 per tick gives 2, 3, 2, 3, 2 (%s)" % [lost])
	assert_true(1000 - enemy.health.hp == 12, "12 in total, the 0.5 left over stays in the remainder")
	assert_true(enemy.burn_timer == 0.0, "burn is over after 5 s")
	assert_true(enemy.hit_by_commander, "burn from the commander counts as a commander hit")
	enemy._tick_status(1.0)
	assert_true(1000 - enemy.health.hp == 12, "no tick after the end")

	enemy.health.hp = 1000
	enemy.health.dot_remainder = 0.0
	enemy.apply_burn(10.0, 5.0, Enums.DamageType.SLASH, owner_node)
	for i in 300:
		enemy._tick_status(1.0 / 60.0)
	assert_true(1000 - enemy.health.hp == 10, "5 s in 1/60 s steps still gives 5 ticks")
	enemy.free()
	owner_node.free()


func test_burn_refresh_and_clock() -> void:
	print("\n[GROUP 4] A new hit resets the time, not the damage")
	var enemy := _new_enemy(GRUNT)
	enemy.health.max_hp = 1000
	enemy.health.hp = 1000
	enemy.apply_burn(10.0, 5.0, Enums.DamageType.BLAST)
	for i in 3:
		enemy._tick_status(1.0)
	assert_true(1000 - enemy.health.hp == 6 and is_equal_approx(enemy.burn_timer, 2.0), "3 ticks of 2, 2 s left")
	enemy.apply_burn(10.0, 5.0, Enums.DamageType.BLAST)
	assert_true(is_equal_approx(enemy.burn_timer, 5.0) and is_equal_approx(enemy.burn_per_tick, 2.0), "timer is back to 5 s, still 2 per tick")
	for i in 5:
		enemy._tick_status(1.0)
	assert_true(1000 - enemy.health.hp == 16, "5 more ticks: 16 in total, not 10 + 10")
	assert_true(enemy.burn_timer == 0.0, "burn is over")
	enemy.free()

	var stub := _new_enemy("res://entities/enemy/grunt.tscn")
	stub.set_script(RESIST_STUB)
	stub.spawn_grace = false
	stub.resist_table = {Enums.DamageType.BLAST: 0.0}
	assert_true(not stub.apply_burn(10.0, 5.0, Enums.DamageType.BLAST) and stub.burn_timer == 0.0, "burn is refused when resist is 0 for its type")
	stub.free()

	var grace := _new_enemy(GRUNT)
	grace.spawn_grace = true
	assert_true(not grace.apply_burn(10.0, 5.0, Enums.DamageType.BLAST), "burn is refused in spawn_grace")
	grace.free()


func test_bulwark_status() -> void:
	print("\n[GROUP 5] Bulwark takes Slow and Burn, still ignores knockback")
	var boss := _new_enemy(BULWARK) as Bulwark
	boss.current_phase = Enums.BossPhase.ARMORED
	var base := _walk_speed(boss)
	assert_true(boss.apply_slow(0.2, 3.0, Enums.DamageType.SLASH), "slow by a SLASH hit is accepted in phase 1")
	assert_true(is_equal_approx(_walk_speed(boss), base * 0.8), "boss speed is x0.8")
	boss.velocity = Vector3.ZERO
	boss.apply_knockback(Vector3.RIGHT * 5.0)
	assert_true(boss.velocity == Vector3.ZERO, "knockback is still ignored")
	boss.apply_commander_taunt(null, 4.0)
	assert_true(not boss.taunted_by_player, "taunt is still ignored")
	boss.slow_timer = 0.0
	assert_true(not boss.apply_slow(0.2, 3.0, Enums.DamageType.PIERCE), "no slow from PIERCE (resist 0 in phase 1)")
	assert_true(boss.slow_timer == 0.0, "nothing was set")
	assert_true(not boss.apply_burn(10.0, 5.0, Enums.DamageType.MAGIC), "no burn from MAGIC (resist 0 in phase 1)")

	boss.apply_burn(10.0, 5.0, Enums.DamageType.BLAST)
	boss.apply_slow(0.2, 3.0, Enums.DamageType.SLASH)
	boss.current_phase = Enums.BossPhase.TRANSITION
	boss._transition_timer = 10.0
	boss._physics_process(1.0)
	assert_true(is_equal_approx(boss.burn_timer, 4.0) and is_equal_approx(boss.slow_timer, 2.0), "both clocks run during TRANSITION")
	boss.free()


func _count_items(kind: DamageNumberLayer.Kind) -> int:
	var n := 0
	for item in _layer._items:
		if not item.is_empty() and item.kind == kind:
			n += 1
	return n


func test_numbers() -> void:
	print("\n[GROUP 6] RESIST and IMMUNE numbers")
	_layer = DamageNumberLayer.new()
	add_child(_layer)
	var boss := _new_enemy(BULWARK) as Bulwark
	boss.current_phase = Enums.BossPhase.ARMORED
	await get_tree().process_frame

	var immune_events: Array = []
	var on_immune := func(target: Node3D, info: DamageInfo) -> void: immune_events.append([target, info])
	EventBus.damage_immune.connect(on_immune)

	var commander := _commander_stub()
	boss.take_damage(DamageInfo.outgoing(20.0, 1.0, Enums.DamageType.SLASH, commander))
	assert_true(_count_items(DamageNumberLayer.Kind.RESIST) == 1, "a sword hit on phase 1 shows RESIST")
	assert_true(immune_events.is_empty(), "no immune signal for a hit that does damage")
	boss.take_damage(DamageInfo.outgoing(20.0, 1.0, Enums.DamageType.BLAST, commander))
	assert_true(_count_items(DamageNumberLayer.Kind.RESIST) == 1 and _count_items(DamageNumberLayer.Kind.NORMAL) == 1, "BLAST at 100% shows a plain number")

	var hp := boss.health.hp
	boss.take_damage(DamageInfo.outgoing(20.0, 1.0, Enums.DamageType.PIERCE, commander))
	assert_true(boss.health.hp == hp, "PIERCE does no damage")
	assert_true(immune_events.size() == 1 and immune_events[0][0] == boss, "a commander PIERCE hit emits damage_immune")
	assert_true(_count_items(DamageNumberLayer.Kind.IMMUNE) == 1, "and shows IMMUNE")

	boss.take_damage(DamageInfo.outgoing(20.0, 1.0, Enums.DamageType.PIERCE, null))
	assert_true(immune_events.size() == 1, "a PIERCE hit from a tower does not")

	var grunt := _new_enemy("res://entities/enemy/grunt.tscn")
	grunt.set_script(RESIST_STUB)
	grunt.spawn_grace = false
	grunt.resist_table = {Enums.DamageType.PIERCE: 0.0}
	grunt.take_damage(DamageInfo.outgoing(20.0, 1.0, Enums.DamageType.PIERCE, commander))
	assert_true(immune_events.size() == 2 and immune_events[1][0] == grunt, "a regular enemy with resist 0 emits it too")
	EventBus.damage_immune.disconnect(on_immune)
	for node in [grunt, boss, commander, _layer]:
		node.free()
