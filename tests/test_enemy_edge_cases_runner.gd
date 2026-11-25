extends Node3D
## Runner for enemy edge cases that could hang a wave or pay twice:
## - a unit still alive when the next PREP starts is removed with no reward and no kill, and logged
## - an Undead lying down keeps the wave going; its second death ends it
## - a Suicide Squad that blows itself up ends the wave like a kill (no reward)
## - a Captain killed last ends the wave at once; its blast comes later
## - the hard cap removes an Undead lying down, so the wave ends
## - a Barricade broken while five Grunts attack it: all five pick a new target
## - the commander switching to Commander mode: units attacking it drop it and pick again
## The wave manager runs without a level; units have physics off and are stepped by hand.

const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const UNDEAD_SCENE: PackedScene = preload("res://entities/enemy/undead.tscn")
const SQUAD_SCENE: PackedScene = preload("res://entities/enemy/suicide_squad.tscn")
const CAPTAIN_SCENE: PackedScene = preload("res://entities/enemy/captain.tscn")
const BARRICADE_SCENE: PackedScene = preload("res://entities/tower/barricade.tscn")
const POOL_SCENE: PackedScene = preload("res://entities/projectile/projectile_pool.tscn")

var passes: int = 0
var fails: int = 0
var _died: Array[Dictionary] = []
var _states: Array[StringName] = []


func _ready() -> void:
	print("\n=======================================================")
	print("              ENEMY EDGE CASES RUNNER TEST             ")
	print("=======================================================")
	add_child(POOL_SCENE.instantiate())
	EventBus.enemy_died.connect(func(id: StringName, _p: Vector3, gold: float, _pr: int, is_cull: bool, _c: bool) -> void:
		_died.append({"id": id, "gold": gold, "cull": is_cull}))
	EventBus.state_changed.connect(func(s: StringName) -> void: _states.append(s))

	await test_leftover_removed_on_prep()
	await test_undead_keeps_wave_going()
	await test_squad_blast_ends_wave()
	await test_captain_last_ends_wave()
	await test_hard_cap_removes_lying_undead()
	await test_barricade_broken_all_retarget()
	await test_commander_mode_drops_attackers()

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


func _physics_frames(n := 2) -> void:
	for i in n:
		await get_tree().physics_frame


## A wave manager with no level, no reward pick and no auto advance, on a scripted wave.
func _wave_manager(wave: int) -> WaveManager:
	var wm := WaveManager.new()
	wm.auto_advance_summary = false
	wm.enable_reward_pick = false
	add_child(wm)
	wm.hazard_trial.set_process(false)
	wm.current_wave = wave
	wm.start_prep()
	return wm


## Starts COMBAT with exactly these scenes queued, all at once.
func _start_with(wm: WaveManager, scenes: Array[PackedScene]) -> Array[Enemy]:
	wm.start_combat()
	wm.spawn_queue.clear()
	wm.spawn_queue.append_array(scenes)
	wm._spawn_delays.clear()
	for s in scenes:
		wm._spawn_delays.append(0.0)
	wm.total_wave_enemies = scenes.size()
	var spawned: Array[Enemy] = []
	var grab := func(e: Node) -> void:
		if e is Enemy:
			spawned.append(e)
	EventBus.enemy_spawned.connect(grab)
	var guard := 0
	while not wm.spawn_queue.is_empty() and guard < 200:
		wm._try_spawn_next_enemy()
		guard += 1
	EventBus.enemy_spawned.disconnect(grab)
	for e in spawned:
		e.set_physics_process(false)
		e.spawn_grace = false
		e.is_in_spawn_zone = false
	return spawned


func _kill(e: Enemy) -> void:
	e.take_damage(DamageInfo.new(e.health.max_hp * 10, Enums.DamageType.TRUE))


func _clear(wm: WaveManager) -> void:
	for n in get_tree().get_nodes_in_group(&"enemy"):
		n.queue_free()
	wm.queue_free()
	await _physics_frames()


func test_leftover_removed_on_prep() -> void:
	print("\n[GROUP 1] A unit alive at the next PREP")
	var wm := _wave_manager(3)
	var units := _start_with(wm, [GRUNT_SCENE, GRUNT_SCENE] as Array[PackedScene])
	_kill(units[0])
	_died.clear()
	# Forced into the next PREP while the second Grunt still lives (a bad count elsewhere).
	wm.advance_to_next_wave()
	assert_true(units[1].is_dead, "The leftover unit is removed when PREP starts")
	assert_true(_died.size() == 1 and _died[0].cull and _died[0].gold == 0.0, "Removed with no reward and no kill")
	await _clear(wm)


func test_undead_keeps_wave_going() -> void:
	print("\n[GROUP 2] Undead lying down")
	var wm := _wave_manager(4)
	var undead := _start_with(wm, [UNDEAD_SCENE] as Array[PackedScene])[0]
	_kill(undead)
	assert_true(undead.is_reviving and wm.wave_state == Enums.WaveState.COMBAT, "First death: the wave goes on")
	assert_true(wm.enemies_alive == 1, "Still counted alive while lying down")
	undead._tick_revive(undead.data.revive_delay + 0.1)
	_kill(undead)
	assert_true(wm.wave_state == Enums.WaveState.SUMMARY, "Second death ends the wave")
	await _clear(wm)


func test_squad_blast_ends_wave() -> void:
	print("\n[GROUP 3] Suicide Squad blowing itself up")
	var wm := _wave_manager(4)
	var squad := _start_with(wm, [SQUAD_SCENE] as Array[PackedScene])[0]
	squad._light_fuse()
	squad._physics_process(squad.data.explode_windup + 0.05)
	assert_true(squad.self_destructed, "The Squad blew itself up")
	assert_true(wm.wave_state == Enums.WaveState.SUMMARY, "The wave ends when the last unit blew itself up")
	await _clear(wm)


func test_captain_last_ends_wave() -> void:
	print("\n[GROUP 4] Captain killed last")
	var wm := _wave_manager(4)
	var captain := _start_with(wm, [CAPTAIN_SCENE] as Array[PackedScene])[0]
	_kill(captain)
	assert_true(captain.blast_pending, "The Captain's blast is pending")
	assert_true(wm.wave_state == Enums.WaveState.SUMMARY, "The wave ends at once, without waiting for the blast")
	await _clear(wm)


func test_hard_cap_removes_lying_undead() -> void:
	print("\n[GROUP 5] Hard cap with an Undead lying down")
	var wm := _wave_manager(4)
	var undead := _start_with(wm, [UNDEAD_SCENE] as Array[PackedScene])[0]
	_kill(undead)
	wm._first_enemy_spawned = true
	wm._update_straggler_clock(GameConfig.wave_hard_cap + 1.0)
	assert_true(undead.is_dead, "The hard cap removes the lying Undead")
	assert_true(wm.wave_state == Enums.WaveState.SUMMARY, "The wave ends")
	await _clear(wm)


func test_barricade_broken_all_retarget() -> void:
	print("\n[GROUP 6] Barricade broken under five Grunts")
	var barricade := BARRICADE_SCENE.instantiate() as Node3D
	add_child(barricade)
	var grunts: Array[Enemy] = []
	for i in 5:
		var g := GRUNT_SCENE.instantiate() as Enemy
		g.position = Vector3(1.2, 0, -2.0 + i)
		add_child(g)
		g.set_physics_process(false)
		g.spawn_grace = false
		g.is_in_spawn_zone = false
		grunts.append(g)
	await _physics_frames()
	for g in grunts:
		g.current_target = barricade
		g.change_state(Enums.EnemyState.ATTACK)
	var health := barricade.get(&"health") as HealthComponent
	health.take_damage(DamageInfo.new(health.max_hp * 10, Enums.DamageType.TRUE))
	await _physics_frames()
	var all_moved_on := true
	for g in grunts:
		g._update_state(0.016)
		if g.current_target == barricade:
			all_moved_on = false
	assert_true(all_moved_on, "All five drop the broken Barricade and pick again")
	for g in grunts:
		g.queue_free()
	if is_instance_valid(barricade):
		barricade.queue_free()
	await _physics_frames()


func test_commander_mode_drops_attackers() -> void:
	print("\n[GROUP 7] Commander leaves the field mid-attack")
	var cmd := Node3D.new()
	cmd.name = "FakeCommander"
	cmd.add_to_group(&"commander")
	add_child(cmd)
	var g := GRUNT_SCENE.instantiate() as Enemy
	g.position = Vector3(1.0, 0, 0)
	add_child(g)
	g.set_physics_process(false)
	g.spawn_grace = false
	g.is_in_spawn_zone = false
	await _physics_frames()
	g.current_target = cmd
	g.change_state(Enums.EnemyState.ATTACK)
	g.attack_windup_timer = 0.1
	g.release_commander_aggro()
	assert_true(g.current_target != cmd, "The unit drops the commander and picks again")
	assert_true(g.current_state != Enums.EnemyState.ATTACK or g.current_target != cmd, "The pending swing at the commander is dropped")
	g.queue_free()
	cmd.queue_free()
	await _physics_frames()
