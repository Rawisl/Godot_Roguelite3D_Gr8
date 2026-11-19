extends Node
## Runner for late and stuck units:
## - a walking unit that makes no progress gets a new path, then goes back to the spawn zone,
##   then is removed once it was sent back the allowed number of times
## - queueing, arriving and being blocked by the commander never count as stuck
## - FRENZY is for good: kept through spawning again and a stagger, and taunt is ignored
## - the wave clock marks stragglers, starts FRENZY and removes the units left at the hard cap,
##   so the wave ends
## Units run with physics off; each stuck check is called by hand with the check interval.

const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const STEP := Enemy.STUCK_CHECK_INTERVAL

var passes: int = 0
var fails: int = 0
var _stuck_events: Array = []
var _deaths: Array = []


func _ready() -> void:
	print("\n=======================================================")
	print("              STUCK LADDER RUNNER TEST                 ")
	print("=======================================================")
	EventBus.stuck_event_logged.connect(_on_stuck_event)
	EventBus.enemy_died.connect(_on_enemy_died)

	await test_stuck_climbs_the_ladder()
	await test_progress_is_not_stuck()
	await test_queue_and_arrival_are_not_stuck()
	await test_commander_block_is_not_stuck()
	await test_third_detection_recycles()
	await test_frenzy_is_for_good()
	await test_wave_clock()

	EventBus.stuck_event_logged.disconnect(_on_stuck_event)
	EventBus.enemy_died.disconnect(_on_enemy_died)
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


func _on_stuck_event(tier: int, _type: StringName, _pos: Vector3, _wave: int) -> void:
	_stuck_events.append(tier)


func _on_enemy_died(_type: StringName, _pos: Vector3, gold: float, prestige: int, is_cull: bool, _cmd: bool) -> void:
	_deaths.append({"gold": gold, "prestige": prestige, "is_cull": is_cull})


## A grunt walking to a point far down the lane, physics off so it only moves when told.
func _walker(pos: Vector3 = Vector3.ZERO) -> Enemy:
	var grunt := GRUNT_SCENE.instantiate() as Enemy
	grunt.position = pos
	add_child(grunt)
	grunt.set_physics_process(false)
	grunt.spawn_grace = false
	grunt.is_in_spawn_zone = false
	grunt.change_state(Enums.EnemyState.ADVANCE)
	grunt.set_target_position(Vector3(-20.0, 0.0, 0.0))
	grunt.nav.target_position = Vector3(-20.0, 0.0, 0.0)
	return grunt


## Runs n stuck checks without moving the unit.
func _hold(grunt: Enemy, n: int) -> void:
	for i in n:
		if grunt.is_dead:
			return
		grunt.check_stuck(STEP)


func _free(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await get_tree().process_frame


func test_stuck_climbs_the_ladder() -> void:
	print("\n[GROUP 1] Stuck unit: new path, back to the spawn zone, removed")
	var grunt := _walker()
	_stuck_events.clear()
	_deaths.clear()
	var culls_before := Enemy.stuck_cull_count
	_hold(grunt, 1 + 5)
	assert_true(grunt.stuck_tier == 0, "2.5 s without progress is not stuck yet")
	_hold(grunt, 1)
	assert_true(grunt.stuck_tier == 1 and _stuck_events == [1], "3 s without progress asks for a new path")
	_hold(grunt, 6)
	assert_true(grunt.recycle_count == 1 and _stuck_events.has(3), "Still stuck 3 s later: sent back")
	assert_true(grunt.current_state == Enums.EnemyState.SPAWN and grunt.global_position.x > 8.0,
			"Sent back to the spawn zone to walk again")
	var hp_before := grunt.health.hp
	# Walk out of the spawn zone again and get stuck until the last time it can be sent back.
	for i in GameConfig.recycle_max:
		grunt.global_position = Vector3.ZERO
		grunt.spawn_grace = false
		grunt.change_state(Enums.EnemyState.ADVANCE)
		grunt.set_target_position(Vector3(-20.0, 0.0, 0.0))
		grunt.nav.target_position = Vector3(-20.0, 0.0, 0.0)
		_hold(grunt, 1 + 12)
	assert_true(grunt.health.hp == hp_before, "Being sent back keeps the unit's HP")
	assert_true(grunt.is_dead and _deaths.size() == 1, "Stuck again after recycle_max times: removed")
	assert_true(_deaths.size() == 1 and _deaths[0]["is_cull"] and _deaths[0]["gold"] == 0.0 and _deaths[0]["prestige"] == 0,
			"Removed as a cull: no gold, no prestige, no kill")
	assert_true(_stuck_events.has(4) and Enemy.stuck_cull_count == culls_before + 1, "The removal is logged and counted")
	await _free(grunt)


func test_progress_is_not_stuck() -> void:
	print("\n[GROUP 2] Slow but moving")
	var grunt := _walker()
	grunt.check_stuck(STEP)
	for i in 30:
		grunt.global_position.x -= 0.3
		grunt.check_stuck(STEP)
	assert_true(grunt.stuck_tier == 0 and grunt.recycle_count == 0, "0.6 m every second along the path is progress")
	await _free(grunt)


func test_queue_and_arrival_are_not_stuck() -> void:
	print("\n[GROUP 3] Waiting in line and arriving")
	var grunt := _walker()
	grunt.change_state(Enums.EnemyState.WAIT)
	_hold(grunt, 40)
	assert_true(grunt.stuck_tier == 0 and grunt.recycle_count == 0, "Waiting for a slot never counts as stuck")
	grunt.change_state(Enums.EnemyState.ADVANCE)
	grunt.global_position = Vector3(-18.5, 0.0, 0.0)
	_hold(grunt, 40)
	assert_true(grunt.stuck_tier == 0 and grunt.recycle_count == 0, "Standing at the end of the path is not stuck")
	grunt.change_state(Enums.EnemyState.ATTACK)
	grunt.global_position = Vector3.ZERO
	_hold(grunt, 40)
	assert_true(grunt.stuck_tier == 0, "Attacking never counts as stuck")
	await _free(grunt)


func test_commander_block_is_not_stuck() -> void:
	print("\n[GROUP 4] The commander in a narrow point")
	var commander := Node3D.new()
	commander.add_to_group(&"commander")
	add_child(commander)
	commander.global_position = Vector3(-1.5, 0.0, 0.0)
	var grunt := _walker()
	_hold(grunt, 60)
	assert_true(grunt.stuck_tier == 0 and grunt.recycle_count == 0, "A unit behind the commander is never sent back")
	commander.global_position = Vector3(1.5, 0.0, 0.0)
	_hold(grunt, 1 + 6)
	assert_true(grunt.stuck_tier == 1, "The commander behind the unit does not excuse it")
	await _free(grunt)
	await _free(commander)


func test_third_detection_recycles() -> void:
	print("\n[GROUP 5] Third time stuck in the wave")
	var grunt := _walker()
	_hold(grunt, 1 + 6)
	assert_true(grunt.stuck_tier == 1 and grunt.stuck_detections == 1, "First time: new path")
	# Moves well for the reset time, so the ladder starts over, then gets stuck again.
	for i in int(GameConfig.stuck_reset_time / STEP) + 1:
		grunt.global_position.x -= 0.6
		grunt.check_stuck(STEP)
	assert_true(grunt.stuck_tier == 0, "10 s of normal progress resets the ladder")
	grunt.global_position = Vector3.ZERO
	_hold(grunt, 1 + 6)
	assert_true(grunt.stuck_tier == 1 and grunt.stuck_detections == 2, "Second time: new path again")
	for i in int(GameConfig.stuck_reset_time / STEP) + 1:
		grunt.global_position.x -= 0.6
		grunt.check_stuck(STEP)
	grunt.global_position = Vector3.ZERO
	_hold(grunt, 1 + 6)
	assert_true(grunt.recycle_count == 1, "Third time: sent back at once")
	await _free(grunt)


func test_frenzy_is_for_good() -> void:
	print("\n[GROUP 6] FRENZY")
	var grunt := _walker()
	grunt.enter_frenzy()
	assert_true(grunt.is_frenzied and grunt.current_state == Enums.EnemyState.FRENZY, "A walking unit goes into FRENZY")
	assert_true(is_equal_approx(grunt.speed_multiplier, grunt.wave_speed_mult * GameConfig.frenzy_speed_mult), "FRENZY is faster")
	var commander := Node3D.new()
	commander.add_to_group(&"commander")
	add_child(commander)
	grunt.apply_commander_taunt(commander, 3.0)
	assert_true(not grunt.taunted_by_player, "Taunt is ignored in FRENZY")
	grunt.recycle()
	assert_true(grunt.is_frenzied and grunt.current_state == Enums.EnemyState.SPAWN, "Sent back, the unit keeps FRENZY")
	grunt.global_position = Vector3(5.0, 0.0, 0.0)
	grunt._update_state(0.1)
	assert_true(grunt.current_state == Enums.EnemyState.FRENZY, "Out of the spawn zone it walks in FRENZY again")
	await _free(grunt)

	var spawning := _walker()
	spawning.change_state(Enums.EnemyState.SPAWN)
	spawning.enter_frenzy()
	assert_true(spawning.is_frenzied and spawning.current_state == Enums.EnemyState.SPAWN, "A spawning unit gets the flag first")
	spawning.global_position = Vector3(5.0, 0.0, 0.0)
	spawning._update_state(0.1)
	assert_true(spawning.current_state == Enums.EnemyState.FRENZY, "and walks in FRENZY once out of the zone")
	await _free(spawning)
	await _free(commander)


func test_wave_clock() -> void:
	print("\n[GROUP 7] Wave clock after the last spawn")
	var wm := WaveManager.new()
	wm.auto_advance_summary = false
	add_child(wm)
	var a := _walker(Vector3(-2.0, 0.0, 0.0))
	var b := _walker(Vector3(-4.0, 0.0, 3.0))
	wm.wave_state = Enums.WaveState.COMBAT
	wm.spawn_queue.clear()
	wm._first_enemy_spawned = true
	wm.enemies_alive = 2
	var marked := []
	var on_marker := func(e: Node) -> void: marked.append(e)
	EventBus.straggler_marker_shown.connect(on_marker)
	_deaths.clear()

	wm._update_straggler_clock(GameConfig.straggler_marker_time - 1.0)
	assert_true(marked.is_empty(), "No marker before the marker time")
	wm._update_straggler_clock(1.0)
	assert_true(marked.size() == 2, "Every unit left gets the marker once")
	wm._update_straggler_clock(1.0)
	assert_true(marked.size() == 2, "The marker is not sent again")
	wm._update_straggler_clock(GameConfig.frenzy_time - GameConfig.straggler_marker_time)
	assert_true(a.is_frenzied and b.is_frenzied, "FRENZY after the frenzy time")
	wm._update_straggler_clock(GameConfig.wave_hard_cap - GameConfig.frenzy_time)
	assert_true(a.is_dead and b.is_dead and _deaths.size() == 2 and _deaths.all(func(d: Dictionary) -> bool: return d["is_cull"]),
			"The hard cap removes every unit left as a cull")
	assert_true(wm.enemies_alive == 0 and wm.wave_state == Enums.WaveState.SUMMARY, "The wave ends")
	EventBus.straggler_marker_shown.disconnect(on_marker)

	wm._reset_straggler_clock()
	wm.spawn_queue.append(GRUNT_SCENE)
	wm._update_straggler_clock(GameConfig.wave_hard_cap + 1.0)
	assert_true(wm._since_last_spawn < 0.0, "The clock waits while units are still queued")
	wm.spawn_queue.clear()
	await _free(wm)
