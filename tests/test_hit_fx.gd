extends Node

## Automated test runner verifying HitFxManager:
## - commander sword hits and enemy melee hits play the slash
## - tower arrow hits and enemy arrows play arrow hits
## - cannon shells exploding play a blast
## - pools never grow; when the particle budget is full, secondary effects are skipped
##   but cannon blasts still play
## - effects follow time_scale: twice as fast at x2

@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var mgr: HitFxManager

class FakeCommander extends Node3D:
	var current_combo_hit := 1

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED HIT FX TEST                           ")
	print("=======================================================")

	mgr = HitFxManager.new()
	add_child(mgr)
	var enemy := _unit(&"enemy", Vector3(2, 0, 0))
	var commander := FakeCommander.new()
	commander.add_to_group(&"commander")
	add_child(commander)
	var cmd_health := HealthComponent.new()
	cmd_health.max_hp = 1000
	commander.add_child(cmd_health)
	await get_tree().process_frame
	var e_health: HealthComponent = enemy.get_node("Health")

	# Commander combo, every hit the same slash
	for step in [1, 2, 3]:
		commander.current_combo_hit = step
		e_health.take_damage(DamageInfo.new(5, Enums.DamageType.SLASH, commander, 1.5 if step == 3 else 0.0, Vector3.RIGHT))
		assert_true(_playing_sword_style() == mgr.slash, "commander hit %d plays the slash" % step)
		_stop_all()

	# Tower arrow on an enemy
	var tower := Tower.new()
	e_health.take_damage(DamageInfo.new(5, Enums.DamageType.PIERCE, tower, 0.0, Vector3.RIGHT))
	assert_true(_count_playing(HitFxManager.ARROW_HIT) == 1, "tower arrow hit plays an arrow hit")
	_stop_all()

	# Enemies hitting the commander
	var grunt := Enemy.new()
	var brute := Brute.new()
	var archer := Archer.new()
	cmd_health.take_damage(DamageInfo.new(5, Enums.DamageType.SLASH, grunt, 0.0, Vector3.LEFT))
	assert_true(_playing_sword_style() == mgr.slash, "grunt hit on commander plays the slash")
	_stop_all()
	cmd_health.take_damage(DamageInfo.new(5, Enums.DamageType.SLASH, brute, 0.0, Vector3.LEFT))
	assert_true(_playing_sword_style() == mgr.slash, "brute hit on commander plays the slash")
	_stop_all()
	cmd_health.take_damage(DamageInfo.new(5, Enums.DamageType.PIERCE, archer, 0.0, Vector3.LEFT))
	assert_true(mgr._enemy_arrows.any(func(fx): return fx.is_playing()), "archer hit on commander plays an enemy arrow hit")
	_stop_all()

	# Cannon explosion
	mgr.play_blast(Vector3(2, 0, 0), Vector3.DOWN, 2.0)
	assert_true(_count_playing(HitFxManager.CANNON_BLAST) == 1, "cannon explosion plays a blast")
	_stop_all()

	# Pools and budget
	for i in 100:
		mgr.play_sword(Vector3.ZERO, Vector3.RIGHT, mgr.slash)
	assert_true(mgr._pools[HitFxManager.SWORD_HIT].size() == mgr.sword_pool, "sword pool stays at %d" % mgr.sword_pool)
	_stop_all()
	mgr.particle_budget = 0
	mgr.play_muzzle(Vector3.ZERO, Vector3.RIGHT, mgr.cannon_muzzle)
	mgr.play_arrow(Vector3.ZERO, Vector3.RIGHT)
	assert_true(_count_playing(HitFxManager.MUZZLE) == 0 and _count_playing(HitFxManager.ARROW_HIT) == 0,
		"over budget: muzzle flash and arrow hit are skipped")
	mgr.play_blast(Vector3.ZERO, Vector3.DOWN, 2.0)
	assert_true(_count_playing(HitFxManager.CANNON_BLAST) == 1, "over budget: cannon blast still plays")
	_stop_all()
	mgr.particle_budget = 1500

	# time_scale: the same 0.06 s flash takes about half the real time at x2
	var at_x1 := await _flash_real_time(1.0)
	var at_x2 := await _flash_real_time(2.0)
	print("    flash: %.3f s at x1, %.3f s at x2" % [at_x1, at_x2])
	assert_true(at_x2 < at_x1 * 0.75, "effects run faster at x2 (%.3f s vs %.3f s)" % [at_x2, at_x1])

	for n in [tower, grunt, brute, archer]:
		n.free()
	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")
	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)

## Real seconds a muzzle flash plays at the given time_scale, timed from a settled frame.
func _flash_real_time(scale: float) -> float:
	await get_tree().process_frame
	await get_tree().process_frame
	Engine.time_scale = scale
	mgr.play_muzzle(Vector3.ZERO, Vector3.RIGHT, mgr.arrow_muzzle)
	var fx: MuzzleFlash = _first_playing(HitFxManager.MUZZLE)
	var start := Time.get_ticks_usec()
	while fx.is_playing() and Time.get_ticks_usec() - start < 2000000:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	return (Time.get_ticks_usec() - start) / 1000000.0

func _unit(group: StringName, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.add_to_group(group)
	n.position = pos
	var h := HealthComponent.new()
	h.name = "Health"
	h.max_hp = 1000
	n.add_child(h)
	add_child(n)
	return n

func _playing_sword_style() -> SwordHitStyle:
	for fx in mgr._pools[HitFxManager.SWORD_HIT]:
		if fx.is_playing():
			return fx._play_style
	return null

func _count_playing(scene: PackedScene) -> int:
	return mgr._pools[scene].filter(func(fx): return fx.is_playing()).size()

func _first_playing(scene: PackedScene) -> Node3D:
	for fx in mgr._pools[scene]:
		if fx.is_playing():
			return fx
	return null

func _stop_all() -> void:
	for list in mgr._pools.values():
		for fx in list:
			if fx._tween:
				fx._tween.kill()
	for fx in mgr._enemy_arrows:
		if fx._tween:
			fx._tween.kill()

func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)
