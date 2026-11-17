extends Node

## Test runner for Bulwark Attack sequences:
## - Attack 1 (Stomp)
## - Attack 2 (Combo: Block -> 1H Slash -> 1H Stab -> 2H Attack)
## - Attack 3 (2H Slash combo: 2H Attack x2)
## - Attack 4 (Dual-wield sequence: Dualwield Slash -> Dualwield SlashCombo)
## - Attack 5 (1H Slash into reverse combo: 1H Slash -> Dualwield SlashCombo)
## - Single moves: 1H Slash, 2H Attack, Dualwield Slash, Offhand/Reverse Slash, 1H Stab
## - Attack interruption & lifecycle safety

var passes: int = 0
var fails: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("       BULWARK ATTACK SEQUENCES VERIFICATION           ")
	print("=======================================================")

	await test_attack_1_lifecycle()
	await test_attack_2_combo_lifecycle()
	await test_attack_3_2h_combo()
	await test_attack_4_dualwield()
	await test_attack_5_reverse_combo()
	await test_attack_combo_slam()
	await test_triple_stomp()
	await test_single_attacks()
	await test_attack_interruption()

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
		push_error("  [FAIL] %s" % test_name)


func test_attack_1_lifecycle() -> void:
	print("\n[GROUP 1] Testing Attack 1 (Stomp)")
	var bulwark_scene: PackedScene = load("res://entities/enemy/bulwark.tscn")
	var bulwark: Bulwark = bulwark_scene.instantiate() as Bulwark
	add_child(bulwark)

	var steps: Array[StringName] = []
	bulwark.attack_step_started.connect(func(atk_id: int, step_name: StringName, _c: StringName, _d: float) -> void:
		if atk_id == 1:
			steps.append(step_name)
	)

	bulwark.play_attack_1()
	assert_true(bulwark.is_in_attack_sequence, "Attack 1 sets is_in_attack_sequence = true")
	assert_true(bulwark.current_attack_id == 1, "Attack 1 sets current_attack_id = 1")

	await get_tree().process_frame
	assert_true(steps.has(&"STOMP_WINDUP"), "Attack 1 emitted STOMP_WINDUP step")

	bulwark.stop_attack_sequence()
	bulwark.queue_free()
	await get_tree().process_frame


func test_attack_2_combo_lifecycle() -> void:
	print("\n[GROUP 2] Testing Attack 2 (Combo: Block -> Slash -> Stab -> 2H)")
	var bulwark_scene: PackedScene = load("res://entities/enemy/bulwark.tscn")
	var bulwark: Bulwark = bulwark_scene.instantiate() as Bulwark
	add_child(bulwark)

	var steps: Array[StringName] = []
	var clips: Array[StringName] = []
	bulwark.attack_step_started.connect(func(atk_id: int, step_name: StringName, clip: StringName, _d: float) -> void:
		if atk_id == 2:
			steps.append(step_name)
			clips.append(clip)
	)

	bulwark.play_attack_2()
	assert_true(bulwark.is_in_attack_sequence, "Attack 2 sets is_in_attack_sequence = true")
	assert_true(bulwark.current_attack_id == 2, "Attack 2 sets current_attack_id = 2")

	await get_tree().process_frame
	assert_true(steps.has(&"BLOCK_POSE"), "Step 1 is BLOCK_POSE")
	assert_true(clips.has(&"melee/Melee_Block"), "Step 1 clip is melee/Melee_Block")

	bulwark.stop_attack_sequence()
	bulwark.queue_free()
	await get_tree().process_frame


func test_attack_3_2h_combo() -> void:
	print("\n[GROUP 3] Testing Attack 3 (2H Slash Combo)")
	var bulwark_scene: PackedScene = load("res://entities/enemy/bulwark.tscn")
	var bulwark: Bulwark = bulwark_scene.instantiate() as Bulwark
	add_child(bulwark)

	var steps: Array[StringName] = []
	var clips: Array[StringName] = []
	bulwark.attack_step_started.connect(func(atk_id: int, step_name: StringName, clip: StringName, _d: float) -> void:
		if atk_id == 3:
			steps.append(step_name)
			clips.append(clip)
	)

	bulwark.play_attack_3()
	assert_true(bulwark.is_in_attack_sequence, "Attack 3 sets is_in_attack_sequence = true")
	assert_true(bulwark.current_attack_id == 3, "Attack 3 sets current_attack_id = 3")

	await get_tree().process_frame
	assert_true(steps.has(&"2H_SLASH_1"), "Step 1 is 2H_SLASH_1")
	assert_true(clips.has(&"melee/Melee_2H_Attack"), "Step 1 clip is melee/Melee_2H_Attack")

	bulwark.stop_attack_sequence()
	bulwark.queue_free()
	await get_tree().process_frame


func test_attack_4_dualwield() -> void:
	print("\n[GROUP 4] Testing Attack 4 (Dual-wield Slash Sequence)")
	var bulwark_scene: PackedScene = load("res://entities/enemy/bulwark.tscn")
	var bulwark: Bulwark = bulwark_scene.instantiate() as Bulwark
	add_child(bulwark)

	var steps: Array[StringName] = []
	var clips: Array[StringName] = []
	bulwark.attack_step_started.connect(func(atk_id: int, step_name: StringName, clip: StringName, _d: float) -> void:
		if atk_id == 4:
			steps.append(step_name)
			clips.append(clip)
	)

	bulwark.play_attack_4()
	assert_true(bulwark.is_in_attack_sequence, "Attack 4 sets is_in_attack_sequence = true")
	assert_true(bulwark.current_attack_id == 4, "Attack 4 sets current_attack_id = 4")

	await get_tree().process_frame
	assert_true(steps.has(&"DUAL_SLASH"), "Step 1 is DUAL_SLASH")
	assert_true(clips.has(&"melee/Melee_Dualwield_Slash"), "Step 1 clip is melee/Melee_Dualwield_Slash")

	bulwark.stop_attack_sequence()
	bulwark.queue_free()
	await get_tree().process_frame


func test_attack_5_reverse_combo() -> void:
	print("\n[GROUP 5] Testing Attack 5 (1H Slash into Reverse Combo)")
	var bulwark_scene: PackedScene = load("res://entities/enemy/bulwark.tscn")
	var bulwark: Bulwark = bulwark_scene.instantiate() as Bulwark
	add_child(bulwark)

	var steps: Array[StringName] = []
	var clips: Array[StringName] = []
	bulwark.attack_step_started.connect(func(atk_id: int, step_name: StringName, clip: StringName, _d: float) -> void:
		if atk_id == 5:
			steps.append(step_name)
			clips.append(clip)
	)

	bulwark.play_attack_5()
	assert_true(bulwark.is_in_attack_sequence, "Attack 5 sets is_in_attack_sequence = true")
	assert_true(bulwark.current_attack_id == 5, "Attack 5 sets current_attack_id = 5")

	await get_tree().process_frame
	assert_true(steps.has(&"SLASH_1H"), "Step 1 is SLASH_1H")
	assert_true(clips.has(&"melee/Melee_1H_Slash"), "Step 1 clip is melee/Melee_1H_Slash")

	bulwark.stop_attack_sequence()
	bulwark.queue_free()
	await get_tree().process_frame


func test_attack_combo_slam() -> void:
	print("\n[GROUP 6] Testing Combo Slam (1H Slash -> 1H Stab -> 2H Ground Slam)")
	var bulwark_scene: PackedScene = load("res://entities/enemy/bulwark.tscn")
	var bulwark: Bulwark = bulwark_scene.instantiate() as Bulwark
	add_child(bulwark)

	var steps: Array[StringName] = []
	var clips: Array[StringName] = []
	bulwark.attack_step_started.connect(func(atk_id: int, step_name: StringName, clip: StringName, _d: float) -> void:
		if atk_id == 6:
			steps.append(step_name)
			clips.append(clip)
	)

	bulwark.play_attack_combo_slam()
	assert_true(bulwark.is_in_attack_sequence, "Attack 6 sets is_in_attack_sequence = true")
	assert_true(bulwark.current_attack_id == 6, "Attack 6 sets current_attack_id = 6")

	await get_tree().process_frame
	assert_true(steps.has(&"SLASH_1H"), "Step 1 is SLASH_1H")
	assert_true(clips.has(&"melee/Melee_1H_Slash"), "Step 1 clip is melee/Melee_1H_Slash")

	bulwark.stop_attack_sequence()
	bulwark.queue_free()
	await get_tree().process_frame


func test_triple_stomp() -> void:
	print("\n[GROUP 7] Testing Triple Stomp (3 Consecutive Expanding Stomps)")
	var bulwark_scene: PackedScene = load("res://entities/enemy/bulwark.tscn")
	var bulwark: Bulwark = bulwark_scene.instantiate() as Bulwark
	add_child(bulwark)

	var steps: Array[StringName] = []
	var clips: Array[StringName] = []
	bulwark.attack_step_started.connect(func(atk_id: int, step_name: StringName, clip: StringName, _d: float) -> void:
		if atk_id == 7:
			steps.append(step_name)
			clips.append(clip)
	)

	bulwark.play_triple_stomp()
	assert_true(bulwark.is_in_attack_sequence, "Attack 7 sets is_in_attack_sequence = true")
	assert_true(bulwark.current_attack_id == 7, "Attack 7 sets current_attack_id = 7")

	await get_tree().process_frame
	assert_true(steps.has(&"TRIPLE_STOMP_1"), "Step 1 is TRIPLE_STOMP_1")
	assert_true(clips.has(&"melee/Melee_2H_Slam"), "Step 1 clip is melee/Melee_2H_Slam")

	bulwark.stop_attack_sequence()
	bulwark.queue_free()
	await get_tree().process_frame


func test_single_attacks() -> void:
	print("\n[GROUP 8] Testing Single Attack Moves")
	var bulwark_scene: PackedScene = load("res://entities/enemy/bulwark.tscn")
	var bulwark: Bulwark = bulwark_scene.instantiate() as Bulwark
	add_child(bulwark)

	# 1H Slash
	bulwark.play_slash_1h()
	assert_true(bulwark.is_in_attack_sequence, "play_slash_1h sets is_in_attack_sequence = true")
	bulwark.stop_attack_sequence()

	# 2H Attack
	bulwark.play_attack_2h()
	assert_true(bulwark.is_in_attack_sequence, "play_attack_2h sets is_in_attack_sequence = true")
	bulwark.stop_attack_sequence()

	# Dualwield Slash
	bulwark.play_dualwield_slash()
	assert_true(bulwark.is_in_attack_sequence, "play_dualwield_slash sets is_in_attack_sequence = true")
	bulwark.stop_attack_sequence()

	# Offhand / Reverse Slash
	bulwark.play_offhand_slash()
	assert_true(bulwark.is_in_attack_sequence, "play_offhand_slash sets is_in_attack_sequence = true")
	bulwark.stop_attack_sequence()

	# 1H Stab
	bulwark.play_stab_1h()
	assert_true(bulwark.is_in_attack_sequence, "play_stab_1h sets is_in_attack_sequence = true")
	bulwark.stop_attack_sequence()

	bulwark.queue_free()
	await get_tree().process_frame


func test_attack_interruption() -> void:
	print("\n[GROUP 9] Testing Attack Sequence Interruption & Stop")
	var bulwark_scene: PackedScene = load("res://entities/enemy/bulwark.tscn")
	var bulwark: Bulwark = bulwark_scene.instantiate() as Bulwark
	add_child(bulwark)

	bulwark.play_attack_2()
	assert_true(bulwark.is_in_attack_sequence, "Attack in progress")

	bulwark.stop_attack_sequence()
	assert_true(not bulwark.is_in_attack_sequence, "stop_attack_sequence sets is_in_attack_sequence = false")
	assert_true(bulwark.current_attack_id == 0, "stop_attack_sequence resets current_attack_id to 0")

	bulwark.queue_free()
	await get_tree().process_frame
