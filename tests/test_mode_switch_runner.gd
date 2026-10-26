extends Node3D
## Automated checks for Recall, Deploy and Commander mode. Run with F6, quits with a pass/fail exit code.

const COMMANDER_SCENE: PackedScene = preload("res://entities/commander/commander.tscn")
const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const BRUTE_SCENE: PackedScene = preload("res://entities/enemy/brute.tscn")

const DEPLOY_POINT := Vector3(-13.0, 0.0, 0.0)
const COMMAND_POST := Vector3(-20.0, 5.0, 0.0)
const RETURN_ZONE_CENTER := Vector3(-12.0, 2.0, 0.0)
const IN_ZONE_POS := Vector3(-10.0, 0.05, 0.0)
const OUT_ZONE_POS := Vector3(0.0, 0.05, 0.0)

var passes: int = 0
var fails: int = 0
var _world: Node3D
var _commander: CharacterBody3D
var _switch: ModeSwitch
var _modes: Array[StringName] = []
var _denied: Array[Array] = []
var _recall_events: Array[String] = []


func _ready() -> void:
	print("\n=======================================================")
	print("          MODE SWITCH VERIFICATION RUNNER              ")
	print("=======================================================")
	EventBus.mode_changed.connect(func(mode: StringName) -> void: _modes.append(mode))
	EventBus.mode_switch_denied.connect(func(reason: StringName, remaining: float) -> void:
		_denied.append([reason, remaining])
	)
	EventBus.recall_started.connect(func(duration: float) -> void: _recall_events.append("started:%.2f" % duration))
	EventBus.recall_cancelled.connect(func() -> void: _recall_events.append("cancelled"))
	EventBus.recall_completed.connect(func() -> void: _recall_events.append("completed"))

	test_finder_pure()
	await test_recall_in_zone()
	await test_recall_outside_zone()
	await test_recall_cancelled_by_damage()
	await test_recall_cancelled_by_actions()
	await test_cooldown_and_denials()
	await test_prep_is_free()
	await test_untouchable()
	await test_no_regen()
	await test_aggro_reset()
	await test_deploy_with_crowded_gate()
	await test_shockwave()
	await test_priority_access_in_prep()

	if is_instance_valid(_world):
		_world.queue_free()
	print("=======================================================")
	print("MODE SWITCH TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================")
	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


func _wait(seconds: float) -> void:
	var frames := ceili(seconds * float(Engine.physics_ticks_per_second))
	for i in frames:
		await get_tree().physics_frame


func _press_tab() -> void:
	_commander._cmd_input.register_press(&"mode_switch")


## Fresh level pieces and a commander standing at `at`, in COMBAT.
func _setup(at: Vector3 = IN_ZONE_POS, state: StringName = &"COMBAT") -> void:
	if is_instance_valid(_world):
		_world.free()
	_modes.clear()
	_denied.clear()
	_recall_events.clear()
	_world = Node3D.new()
	add_child(_world)

	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120.0, 0.5, 60.0)
	ground_shape.shape = box
	ground.add_child(ground_shape)
	ground.position = Vector3(0.0, -0.25, 0.0)
	_world.add_child(ground)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 30.0
	camera.position = Vector3(16.0, 16.0, 16.0)
	camera.rotation_degrees = Vector3(-35.0, 45.0, 0.0)
	_world.add_child(camera)
	camera.make_current()

	var markers := Node3D.new()
	markers.name = "Markers"
	_world.add_child(markers)
	_add_marker(markers, &"DeployPoint", DEPLOY_POINT)
	_add_marker(markers, &"CommandPost", COMMAND_POST)
	var zone := Area3D.new()
	zone.name = "ReturnZone"
	var zone_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 5.0
	cylinder.height = 4.0
	zone_shape.shape = cylinder
	zone.add_child(zone_shape)
	zone.position = RETURN_ZONE_CENTER
	markers.add_child(zone)

	_commander = COMMANDER_SCENE.instantiate() as CharacterBody3D
	_commander.position = at
	_world.add_child(_commander)
	_switch = _commander.get_node("ModeSwitch") as ModeSwitch
	EventBus.mode_changed.emit(&"FRONTLINE")
	EventBus.state_changed.emit(state)
	_modes.clear()


func _add_marker(parent: Node3D, marker_name: StringName, pos: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = pos
	parent.add_child(marker)


func _add_enemy(scene: PackedScene, pos: Vector3, frozen: bool = true) -> Enemy:
	var enemy := scene.instantiate() as Enemy
	_world.add_child(enemy)
	enemy.global_position = pos
	enemy.spawn_grace = false
	enemy.is_in_spawn_zone = false
	if frozen:
		enemy.set_physics_process(false)
	return enemy


func test_finder_pure() -> void:
	print("\n[GROUP 1] Deploy point search")
	var accept_all := func(candidate: Vector3) -> Variant: return candidate
	var origin := Vector3.ZERO
	var toward := Vector3(10.0, 0.0, 0.0)

	var free: Variant = DeployPointFinder.find(origin, toward, PackedVector3Array(), 0.8, 4.0, accept_all)
	assert_true(free == origin, "free deploy point is used as is")

	var crowd := PackedVector3Array([origin])
	var first: Variant = DeployPointFinder.find(origin, toward, crowd, 0.8, 4.0, accept_all)
	assert_true(first != null and (first as Vector3).is_equal_approx(Vector3(1.0, 0.0, 0.0)),
		"first candidate is one metre toward the fortress")

	crowd.append(Vector3(1.0, 0.0, 0.0))
	var second: Variant = DeployPointFinder.find(origin, toward, crowd, 0.5, 4.0, accept_all)
	var expected := Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, -TAU / 8.0)
	assert_true(second != null and (second as Vector3).is_equal_approx(expected), "next candidate turns clockwise")
	assert_true(expected.z > 0.0, "clockwise from above moves toward +Z when facing +X")

	var ring_one_blocked := func(candidate: Vector3) -> Variant:
		return null if candidate.length() < 1.5 else candidate
	var ring_two: Variant = DeployPointFinder.find(origin, toward, crowd, 0.8, 4.0, ring_one_blocked)
	assert_true(ring_two != null and (ring_two as Vector3).is_equal_approx(Vector3(2.0, 0.0, 0.0)),
		"a blocked inner ring falls through to the next ring")

	var all_blocked := func(_candidate: Vector3) -> Variant: return null
	var none: Variant = DeployPointFinder.find(origin, toward, crowd, 0.8, 4.0, all_blocked)
	assert_true(none == null, "no valid candidate gives null")

	var only_outer := func(candidate: Vector3) -> Variant:
		return null if candidate.length() < 3.5 else candidate
	var outer: Variant = DeployPointFinder.find(origin, toward, crowd, 0.8, 4.0, only_outer)
	assert_true(outer != null and absf((outer as Vector3).length() - 4.0) < 0.01, "rings out to the search radius are tried")

	var again: Variant = DeployPointFinder.find(origin, toward, crowd, 0.5, 4.0, accept_all)
	assert_true(again == second, "same input gives the same point")


func test_recall_in_zone() -> void:
	print("\n[GROUP 2] Recall inside the return zone")
	_setup(IN_ZONE_POS)
	_press_tab()
	await _wait(0.1)
	assert_true(_switch.is_recalling(), "Tab starts a Recall")
	assert_true(_recall_events.has("started:0.60"), "recall_started carries the in-zone time")
	assert_true(not _commander.is_aura_source(), "no aura while recalling")
	assert_true(not _commander.is_commander_mode, "still Frontline while channelling")
	await _wait(0.3)
	assert_true(_switch.is_recalling(), "channel is not finished early")
	await _wait(0.4)
	assert_true(_commander.is_commander_mode, "Recall completes into Commander mode")
	assert_true(_modes == [&"COMMANDER"], "mode_changed(COMMANDER) is emitted once")
	assert_true(_recall_events.has("completed"), "recall_completed is emitted")
	assert_true(_commander.global_position.distance_to(COMMAND_POST) < 0.5, "commander stands at the command post")
	assert_true(absf(_switch.cooldown_left - 5.0) < 0.5, "cooldown starts when the switch completes")


func test_recall_outside_zone() -> void:
	print("\n[GROUP 3] Recall outside the return zone")
	_setup(OUT_ZONE_POS)
	_press_tab()
	await _wait(0.1)
	assert_true(_recall_events.has("started:3.00"), "recall_started carries the outside time")
	await _wait(0.8)
	assert_true(_switch.is_recalling(), "still channelling after the in-zone time")


func test_recall_cancelled_by_damage() -> void:
	print("\n[GROUP 4] Recall cancelled by damage")
	_setup(IN_ZONE_POS)
	_press_tab()
	await _wait(0.2)
	_commander.take_damage(DamageInfo.new(10, Enums.DamageType.SLASH))
	await _wait(0.1)
	assert_true(not _switch.is_recalling(), "damage cancels the Recall")
	assert_true(_recall_events.has("cancelled"), "recall_cancelled is emitted")
	assert_true(_switch.cooldown_left == 0.0, "a cancelled Recall costs no cooldown")
	assert_true(_commander.is_aura_source(), "aura comes back after the cancel")
	await _wait(1.0)
	assert_true(not _commander.is_commander_mode, "the cancelled Recall never completes")


func test_recall_cancelled_by_actions() -> void:
	print("\n[GROUP 5] Recall cancelled by movement, dodge, attack")
	_setup(IN_ZONE_POS)
	_press_tab()
	await _wait(0.2)
	Input.action_press(&"move_up")
	await _wait(0.1)
	Input.action_release(&"move_up")
	assert_true(not _switch.is_recalling(), "movement cancels the Recall")

	_setup(IN_ZONE_POS)
	_press_tab()
	await _wait(0.2)
	_commander._cmd_input.register_press(&"dodge")
	await _wait(0.1)
	assert_true(not _switch.is_recalling(), "dodge cancels the Recall")
	assert_true(_commander.is_dodging, "the dodge itself still happens")

	_setup(IN_ZONE_POS)
	_press_tab()
	await _wait(0.2)
	_commander._cmd_input.register_press(&"attack")
	await _wait(0.1)
	assert_true(not _switch.is_recalling(), "attack cancels the Recall")

	_setup(IN_ZONE_POS)
	_press_tab()
	await _wait(0.2)
	_commander.apply_stun(0.5)
	assert_true(not _switch.is_recalling(), "stun cancels the Recall")


func test_cooldown_and_denials() -> void:
	print("\n[GROUP 6] Cooldown, busy and locked states")
	_setup(IN_ZONE_POS)
	_press_tab()
	await _wait(1.3)
	assert_true(_commander.is_commander_mode, "arrived in Commander mode")
	_press_tab()
	await _wait(0.1)
	assert_true(_commander.is_commander_mode and not _denied.is_empty() and _denied[0][0] == &"COOLDOWN",
		"Tab during the cooldown is denied with the reason")
	assert_true(_denied[0][1] > 0.0, "the denial carries the time left")

	_switch.cooldown_left = 0.0
	_denied.clear()
	_press_tab()
	await _wait(0.1)
	assert_true(not _commander.is_commander_mode and _commander.is_deploying, "Deploy runs once the cooldown is over")

	_setup(IN_ZONE_POS)
	_commander.is_attacking = true
	_commander._has_struck = true
	_commander._attack_timer = 5.0
	_press_tab()
	await _wait(0.1)
	assert_true(not _switch.is_recalling(), "Tab while attacking is ignored")
	_commander.is_attacking = false

	_setup(IN_ZONE_POS)
	EventBus.state_changed.emit(&"BOSS_INTRO")
	_press_tab()
	await _wait(0.1)
	assert_true(not _switch.is_recalling() and not _denied.is_empty() and _denied[0][0] == &"BOSS_INTRO",
		"switching is locked during the boss intro")


func test_prep_is_free() -> void:
	print("\n[GROUP 7] Switching in PREP")
	_setup(OUT_ZONE_POS, &"PREP")
	_press_tab()
	await _wait(0.1)
	assert_true(_commander.is_commander_mode and not _switch.is_recalling(), "PREP switches at once, no channel")
	assert_true(_switch.cooldown_left == 0.0, "PREP switch has no cooldown")
	await _wait(0.6)
	_press_tab()
	await _wait(0.1)
	assert_true(not _commander.is_commander_mode, "PREP switches back at once")


func test_untouchable() -> void:
	print("\n[GROUP 8] Commander mode is untouchable")
	_setup(IN_ZONE_POS)
	_press_tab()
	await _wait(0.8)
	assert_true(_switch.is_arriving(), "arriving right after the Recall")
	var hp: int = _commander.health.hp
	_commander.take_damage(DamageInfo.new(50, Enums.DamageType.SLASH))
	_commander.take_damage(DamageInfo.new(50, Enums.DamageType.TRUE))
	assert_true(_commander.health.hp == hp, "no damage while arriving")
	await _wait(0.6)
	assert_true(not _switch.is_arriving() and _commander.is_commander_mode, "Commanding follows Arriving")
	_commander.take_damage(DamageInfo.new(50, Enums.DamageType.BLAST, null, 8.0, Vector3.RIGHT))
	assert_true(_commander.health.hp == hp, "no damage while commanding")
	assert_true(not _commander.apply_stun(1.0), "no stun while commanding")
	assert_true(_commander.global_position.distance_to(COMMAND_POST) < 0.5, "no knockback while commanding")
	assert_true(not _commander.is_aura_source(), "no aura in Commander mode")


func test_no_regen() -> void:
	print("\n[GROUP 9] No regeneration in Commander mode")
	_setup(IN_ZONE_POS)
	_press_tab()
	await _wait(1.0)
	_commander.health.hp = 50
	await _wait(2.0)
	assert_true(_commander.health.hp == 50, "HP does not move over time")


func test_aggro_reset() -> void:
	print("\n[GROUP 10] Recall resets enemy aggro")
	_setup(IN_ZONE_POS)
	var grunt := _add_enemy(GRUNT_SCENE, IN_ZONE_POS + Vector3(3.0, 0.0, 0.0))
	grunt.provoked_by_player = true
	grunt.provoked_timer = 4.0
	grunt.taunted_by_player = true
	grunt.taunt_timer = 4.0
	grunt.set_target(_commander)
	_press_tab()
	await _wait(1.0)
	assert_true(_commander.is_commander_mode, "recall completed")
	assert_true(not grunt.provoked_by_player and not grunt.taunted_by_player, "provocation and taunt are cleared")
	assert_true(grunt.current_target != _commander, "the commander is no longer targeted")


func test_deploy_with_crowded_gate() -> void:
	print("\n[GROUP 11] Deploy into a crowded gate")
	_setup(IN_ZONE_POS)
	_switch.cooldown_left = 0.0
	_press_tab()
	await _wait(1.3)
	_switch.cooldown_left = 0.0

	_add_enemy(GRUNT_SCENE, DEPLOY_POINT)
	for i in 8:
		var offset := Vector3.RIGHT.rotated(Vector3.UP, TAU * float(i) / 8.0)
		_add_enemy(GRUNT_SCENE, DEPLOY_POINT + offset)
	# Without a Fortress in the scene the rings start toward +X.
	var expected := DEPLOY_POINT + Vector3.RIGHT * 2.0

	_press_tab()
	await _wait(0.1)
	assert_true(not _commander.is_commander_mode, "Deploy leaves Commander mode")
	assert_true(_commander.global_position.distance_to(expected) < 0.2,
		"lands on the first free candidate (got %s, want %s)" % [_commander.global_position, expected])
	var clear := true
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		var flat := Vector2(enemy.global_position.x - _commander.global_position.x,
			enemy.global_position.z - _commander.global_position.z)
		if flat.length() < 0.8:
			clear = false
	assert_true(clear, "no enemy within the clear radius of the landing point")
	assert_true(_commander.is_deploying, "invulnerable window is running")
	var hp: int = _commander.health.hp
	_commander.take_damage(DamageInfo.new(50, Enums.DamageType.SLASH))
	assert_true(_commander.health.hp == hp, "no damage while deploying")
	await _wait(0.7)
	assert_true(not _commander.is_deploying, "invulnerable window ends after the deploy time")


func test_shockwave() -> void:
	print("\n[GROUP 12] Deploy shockwave")
	_setup(IN_ZONE_POS)
	_press_tab()
	await _wait(1.3)
	_switch.cooldown_left = 0.0

	var grunt := _add_enemy(GRUNT_SCENE, DEPLOY_POINT + Vector3(0.0, 0.0, 1.5), false)
	var brute := _add_enemy(BRUTE_SCENE, DEPLOY_POINT + Vector3(0.0, 0.0, -1.5), true)
	var far := _add_enemy(GRUNT_SCENE, DEPLOY_POINT + Vector3(0.0, 0.0, 6.0), true)
	var grunt_start := grunt.global_position
	_press_tab()
	await _wait(0.1)
	assert_true(grunt.current_state == Enums.EnemyState.STAGGER, "grunt in range is staggered")
	assert_true(brute.current_state != Enums.EnemyState.STAGGER, "brute is immune")
	assert_true(far.current_state != Enums.EnemyState.STAGGER, "enemy outside the radius is untouched")
	await _wait(0.6)
	var moved := Vector2(grunt.global_position.x - grunt_start.x, grunt.global_position.z - grunt_start.z).length()
	assert_true(moved > 1.0, "grunt is pushed back (moved %.2f m)" % moved)


func test_priority_access_in_prep() -> void:
	print("\n[GROUP 13] Priority changes follow the mode")
	_setup(IN_ZONE_POS, &"PREP")
	var service := BuildService.new()
	_world.add_child(service)
	EventBus.state_changed.emit(&"PREP")
	EventBus.mode_changed.emit(&"FRONTLINE")
	assert_true(service.can_change_priority(), "PREP, Frontline: allowed")
	EventBus.mode_changed.emit(&"COMMANDER")
	assert_true(service.can_change_priority(), "PREP, Commander: allowed")
	EventBus.state_changed.emit(&"COMBAT")
	assert_true(service.can_change_priority(), "COMBAT, Commander: allowed")
	EventBus.mode_changed.emit(&"FRONTLINE")
	assert_true(not service.can_change_priority(), "COMBAT, Frontline: denied")
