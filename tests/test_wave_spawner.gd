extends Node

## Comprehensive verification runner for the wave spawner:
## - Deterministic wave generation (same run_seed + wave -> identical composition)
## - Intro count: wave 3 exactly 2 Archers, wave 6 exactly 1 Brute
## - Wave 1 and 2 only contain Grunts
## - Archer <= 40% of total wave composition
## - Brute cap: Brute count <= floor(w / 4)
## - Wave 0 fallback: forces exactly 1 Grunt
## - Grouping: group_count = clamp(2 + floor(w/5), 2, 6), melee first and ranged after in each group
## - Delays: 0.4-0.8s within group, 3.0s between groups
## - Queue Throttling: surplus enemies remain in queue when enemies_alive >= max_alive (70)
## - Candidate position in spawn_zone, overlap check (1m), 0.2s retry, 3s force spawn

var passes: int = 0
var fails: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED WAVE SPAWNER TEST RUNNER       ")
	print("=======================================================")

	test_deterministic_by_run_seed()
	test_intro_count_archer_w3_and_brute_w6()
	test_spn08_waves_1_and_2_grunt_only()
	test_spn05_archer_max_40_percent()
	test_brute_cap_floor_w_over_4()
	test_wave_0_forces_one_grunt()
	test_grouping_and_melee_first()
	test_queue_throttling_max_alive()
	test_spn03_overlap_retry_and_timeout()
	test_wave_table_dynamic_tuning()
	test_scripted_waves_follow_wave_script()
	test_schedule_lasts_spawn_duration()
	test_generated_waves_max_types()
	test_scripted_wave_scale()
	test_catalog_has_ten_types()
	test_wave_plan_matches_queue()

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
		printerr("  [FAIL] %s" % test_name)


func test_deterministic_by_run_seed() -> void:
	print("\n[GROUP 1] Testing Deterministic Composition by run_seed")
	var wm := WaveManager.new()
	add_child(wm)

	var run_seed_test := 123456
	var comp1 := wm.generate_wave_composition(3, run_seed_test)
	var comp2 := wm.generate_wave_composition(3, run_seed_test)

	assert_true(comp1.size() == comp2.size(), "Identical total enemy count for same run_seed")
	assert_true(comp1.size() > 0, "Wave composition is non-empty")

	var identical: bool = true
	for i in range(comp1.size()):
		if comp1[i].id != comp2[i].id or not is_equal_approx(comp1[i].delay, comp2[i].delay) or comp1[i].group_index != comp2[i].group_index:
			identical = false
			break
	assert_true(identical, "All enemy IDs, group indices, and delays are 100% identical across same seed runs")

	# Different seed produces variation for generated waves (past victory_wave)
	var comp_diff := wm.generate_wave_composition(37, 99999)
	var comp_base := wm.generate_wave_composition(37, 11111)
	var diff_found: bool = false
	if comp_diff.size() != comp_base.size():
		diff_found = true
	else:
		for i in range(comp_diff.size()):
			if comp_diff[i].id != comp_base[i].id or not is_equal_approx(comp_diff[i].delay, comp_base[i].delay):
				diff_found = true
				break
	assert_true(diff_found, "Different run_seeds yield different random distributions")

	wm.queue_free()


func test_intro_count_archer_w3_and_brute_w6() -> void:
	print("\n[GROUP 2] Testing Intro Count (Wave 3 exactly 2 Archers, Wave 6 exactly 1 Brute)")
	var wm := WaveManager.new()
	add_child(wm)

	# Test across various seeds to ensure it holds universally
	for test_seed in [0, 42, 123, 9999]:
		var comp_w3 := wm.generate_wave_composition(3, test_seed)
		var archers_w3 := 0
		for u in comp_w3:
			if u.id == &"archer":
				archers_w3 += 1
		assert_true(archers_w3 == 2, "Wave 3 (seed %d) has EXACTLY 2 Archers" % test_seed)

		var comp_w6 := wm.generate_wave_composition(6, test_seed)
		var brutes_w6 := 0
		for u in comp_w6:
			if u.id == &"brute":
				brutes_w6 += 1
		assert_true(brutes_w6 == 1, "Wave 6 (seed %d) has EXACTLY 1 Brute" % test_seed)

	wm.queue_free()


func test_spn08_waves_1_and_2_grunt_only() -> void:
	print("\n[GROUP 3] Waves 1 & 2 are Grunt only")
	var wm := WaveManager.new()
	add_child(wm)

	var comp_w1 := wm.generate_wave_composition(1, 42)
	var all_grunts_w1 := true
	for u in comp_w1:
		if u.id != &"grunt":
			all_grunts_w1 = false
	assert_true(all_grunts_w1 and comp_w1.size() == 8, "Wave 1 contains exactly 8 enemies, all Grunts")

	var comp_w2 := wm.generate_wave_composition(2, 42)
	var all_grunts_w2 := true
	for u in comp_w2:
		if u.id != &"grunt":
			all_grunts_w2 = false
	assert_true(all_grunts_w2 and comp_w2.size() == 10, "Wave 2 contains exactly 10 enemies, all Grunts")

	wm.queue_free()


func test_spn05_archer_max_40_percent() -> void:
	print("\n[GROUP 4] Archer <= 40% of wave composition")
	var wm := WaveManager.new()
	add_child(wm)

	var all_within_cap := true
	for w in [3, 4, 5, 7, 8, 10, 15, 31, 33, 37, 44]:
		for s in [0, 77, 333, 9999]:
			var comp := wm.generate_wave_composition(w, s)
			var archers := 0
			for u in comp:
				if u.id == &"archer":
					archers += 1
			var ratio: float = float(archers) / float(comp.size())
			if ratio > 0.4001:
				all_within_cap = false
				printerr("Wave %d Seed %d exceeded 40%% Archer cap: %d/%d (%.2f%%)" % [w, s, archers, comp.size(), ratio * 100.0])

	assert_true(all_within_cap, "All waves across all seeds respect Archer <= 40% cap")
	wm.queue_free()


func test_brute_cap_floor_w_over_4() -> void:
	print("\n[GROUP 5] Testing Brute Cap (Brute <= floor(w / 4))")
	var wm := WaveManager.new()
	add_child(wm)

	var all_within_brute_cap := true
	for w in [6, 7, 8, 9, 10, 11, 12, 16, 31, 34, 38]:
		var max_allowed: int = int(floor(float(w) / 4.0))
		for s in [10, 20, 30, 40]:
			var comp := wm.generate_wave_composition(w, s)
			var brutes := 0
			for u in comp:
				if u.id == &"brute":
					brutes += 1
			if brutes > max_allowed:
				all_within_brute_cap = false
				printerr("Wave %d Seed %d exceeded Brute cap: %d > %d" % [w, s, brutes, max_allowed])

	assert_true(all_within_brute_cap, "Brute count never exceeds floor(w / 4)")
	wm.queue_free()


func test_wave_0_forces_one_grunt() -> void:
	print("\n[GROUP 6] Testing Wave 0 Fallback (Forces exactly 1 Grunt)")
	var wm := WaveManager.new()
	add_child(wm)

	var comp_w0 := wm.generate_wave_composition(0, 42)
	assert_true(comp_w0.size() == 1, "Wave 0 composition has size 1")
	assert_true(comp_w0.size() > 0 and comp_w0[0].id == &"grunt", "Wave 0 unit is Grunt")

	var comp_neg := wm.generate_wave_composition(-1, 42)
	assert_true(comp_neg.size() == 1 and comp_neg[0].id == &"grunt", "Negative wave index also forces 1 Grunt")

	wm.queue_free()


func test_grouping_and_melee_first() -> void:
	print("\n[GROUP 7] Testing Grouping & Melee-First Ordering within Groups")
	var wm := WaveManager.new()
	add_child(wm)

	# Wave 5: group_count = clamp(2 + floor(5/5), 2, 6) = 3
	var comp_w5 := wm.generate_wave_composition(5, 42)
	var max_group_w5 := 0
	for u in comp_w5:
		max_group_w5 = maxi(max_group_w5, u.group_index)
	assert_true(max_group_w5 == 2, "Wave 5 splits into 3 groups (indices 0..2)")

	# Wave 10: group_count = clamp(2 + floor(10/5), 2, 6) = 4
	var comp_w10 := wm.generate_wave_composition(10, 42)
	var max_group_w10 := 0
	for u in comp_w10:
		max_group_w10 = maxi(max_group_w10, u.group_index)
	assert_true(max_group_w10 == 3, "Wave 10 splits into 4 groups (indices 0..3)")

	# Verify melee-first ordering within every single group
	var all_melee_first := true
	for w in [3, 5, 6, 8, 10]:
		var comp := wm.generate_wave_composition(w, 42)
		var current_group := -1
		var seen_ranged_in_group := false
		for u in comp:
			if u.group_index != current_group:
				current_group = u.group_index
				seen_ranged_in_group = false

			if u.is_ranged:
				seen_ranged_in_group = true
			else:
				if seen_ranged_in_group:
					all_melee_first = false
					printerr("Wave %d Group %d had Melee unit after Ranged unit!" % [w, current_group])

	assert_true(all_melee_first, "Within every group, all Melee units appear before Ranged units")
	wm.queue_free()


func test_queue_throttling_max_alive() -> void:
	print("\n[GROUP 8] Testing Queue Throttling (Holding surplus enemies when enemies_alive >= max_alive)")
	var wm := WaveManager.new()
	var custom_table := wm.wave_table.duplicate() as WaveTable
	custom_table.group_spawn_delay_min = 0.01
	custom_table.group_spawn_delay_max = 0.01
	custom_table.group_pause = 0.01
	wm.wave_table = custom_table
	wm.spawn_interval = 0.01
	add_child(wm)

	# Populate queue
	wm.current_wave = 1
	wm.start_combat()
	var initial_queued := wm.spawn_queue.size()
	assert_true(initial_queued == 8, "Combat started with 8 queued enemies")

	# Pretend enemies_alive is at max_alive (70)
	wm.enemies_alive = GameConfig.max_alive

	# Step physics multiple times
	for _i in range(10):
		wm._physics_process(0.1)

	assert_true(wm.spawn_queue.size() == initial_queued, "No enemies spawned while enemies_alive >= max_alive (surplus holds in queue)")

	# Drop enemies_alive below max_alive
	wm.enemies_alive = GameConfig.max_alive - 1
	wm._physics_process(0.1)

	assert_true(wm.spawn_queue.size() < initial_queued, "Enemy spawned immediately once enemies_alive dropped below max_alive")

	wm.queue_free()


func test_spn03_overlap_retry_and_timeout() -> void:
	print("\n[GROUP 9] Testing Overlap Avoidance and 3s Force-Spawn Timeout")
	var wm := WaveManager.new()
	var custom_table := wm.wave_table.duplicate() as WaveTable
	custom_table.group_spawn_delay_min = 0.01
	custom_table.group_spawn_delay_max = 0.01
	custom_table.spawn_retry_delay = 0.01
	wm.wave_table = custom_table
	wm.spawn_interval = 0.01
	add_child(wm)

	# Mock spawn_point and extents
	wm.spawn_point = Vector3(14.0, 0.0, 0.0)
	wm.spawn_zone_half_extents = Vector3(6.0, 2.0, 8.0)

	# Test occupied detection
	var dummy_enemy := CharacterBody3D.new()
	dummy_enemy.position = Vector3(14.0, 0.0, 0.0)
	dummy_enemy.add_to_group(&"enemy")
	add_child(dummy_enemy)

	assert_true(wm._is_position_occupied(Vector3(14.2, 0.0, 0.1), 1.0) == true, "Position within 1m of existing enemy detected as occupied")
	assert_true(wm._is_position_occupied(Vector3(14.0, 0.0, 5.0), 1.0) == false, "Position outside 1m of existing enemy detected as clear")

	dummy_enemy.queue_free()
	wm.queue_free()


func test_wave_table_dynamic_tuning() -> void:
	print("\n[GROUP 10] Testing WaveTable Dynamic Tuning via Resource")
	var wm := WaveManager.new()
	var custom_table: WaveTable = wm.wave_table.duplicate() as WaveTable
	for g in custom_table.groups:
		if g.enemy != null and g.enemy.id == &"grunt":
			g.weight = 0.1
		elif g.enemy != null and g.enemy.id == &"archer":
			g.weight = 100.0
	custom_table.group_pause = 1.5
	wm.wave_table = custom_table
	add_child(wm)

	var comp := wm.generate_wave_composition(34, 42)
	assert_true(comp.size() > 0, "Composition generated with custom WaveTable")

	var group1_first_delay: float = -1.0
	for u in comp:
		if u.group_index == 1:
			group1_first_delay = u.delay
			break
	assert_true(group1_first_delay >= 1.5 - 0.0001, "Group 1 pause starts from custom WaveTable.group_pause (1.5s) and only grows")

	wm.queue_free()


## Units per id of a schedule.
func _count_ids(comp: Array[Dictionary]) -> Dictionary:
	var counts := {}
	for u in comp:
		counts[u.id] = int(counts.get(u.id, 0)) + 1
	return counts


## Game seconds from the start of combat to the last planned spawn.
func _last_spawn_time(comp: Array[Dictionary]) -> float:
	var t := 0.0
	for u in comp:
		t += float(u.delay)
	return t


func test_scripted_waves_follow_wave_script() -> void:
	print("\n[GROUP 11] Waves 1-30 follow the WaveScript, whatever the run seed")
	var wm := WaveManager.new()
	add_child(wm)
	var all_match := true
	var seed_free := true
	for w in range(1, GameConfig.victory_wave + 1):
		var expected := {}
		for entry in wm.wave_script.get_wave(w):
			if entry.enemy_type == wm.boss_data.id:
				continue
			expected[entry.enemy_type] = int(expected.get(entry.enemy_type, 0)) + int(entry.count)
		var a := _count_ids(wm.generate_wave_composition(w, 1))
		var b := _count_ids(wm.generate_wave_composition(w, 987654))
		if a != expected:
			all_match = false
			printerr("Wave %d: %s, script says %s" % [w, a, expected])
		if a != b:
			seed_free = false
	assert_true(all_match, "Every scripted wave spawns exactly the WaveScript units (escorts in, boss out)")
	assert_true(seed_free, "Scripted wave units do not depend on the run seed")

	# A scripted wave with no units: one Grunt and an error, the wave still runs.
	var empty_script := WaveScript.new()
	wm.wave_script = empty_script
	var comp := wm.generate_wave_composition(4, 1)
	assert_true(comp.size() == 1 and comp[0].id == &"grunt", "Scripted wave without data falls back to one Grunt")
	wm.queue_free()


func test_schedule_lasts_spawn_duration() -> void:
	print("\n[GROUP 12] Every schedule lasts at least the wave's spawn duration")
	var wm := WaveManager.new()
	add_child(wm)
	var all_long_enough := true
	var stretched_exact := true
	for w in range(1, 46):
		for s in [3, 4242]:
			var comp := wm.generate_wave_composition(w, s)
			var last := _last_spawn_time(comp)
			var dur := wm.get_spawn_duration(w)
			if last < dur - 0.001:
				all_long_enough = false
				printerr("Wave %d seed %d: last spawn at %.2f s < %.2f s" % [w, s, last, dur])
	# Wave 1 is short (8 Grunts), so it is stretched to exactly its spawn duration.
	var w1 := wm.generate_wave_composition(1, 0)
	stretched_exact = is_equal_approx(_last_spawn_time(w1), wm.get_spawn_duration(1))
	assert_true(all_long_enough, "Last unit of waves 1-45 spawns at or after spawn_duration")
	assert_true(stretched_exact, "A short schedule ends exactly at spawn_duration")
	assert_true(is_equal_approx(wm.get_spawn_duration(1), wm.wave_script.get_spawn_duration(1)), "Scripted spawn_duration comes from the WaveScript")
	assert_true(is_equal_approx(wm.get_spawn_duration(35), wm.scale_config.get_spawn_duration(35)), "Generated waves use the ScaleConfig spawn_duration")

	# A single group only moves its last unit.
	var units: Array[Dictionary] = [{"id": &"grunt", "scene": null, "is_ranged": false}]
	var rng := RandomNumberGenerator.new()
	var single := wm._schedule_units(units, 1, rng)
	assert_true(single.size() == 1 and is_equal_approx(single[0].delay, wm.get_spawn_duration(1)), "One unit spawns right at spawn_duration")
	wm.queue_free()


func test_generated_waves_max_types() -> void:
	print("\n[GROUP 13] Waves 31-40 have at most 5 types, the boss counted")
	var wm := WaveManager.new()
	add_child(wm)
	var ok := true
	var seen := {}
	for w in range(31, 41):
		for s in [1, 2, 3, 77, 9001]:
			var ids := _count_ids(wm.generate_wave_composition(w, s))
			var types := ids.size() + (1 if wm.is_boss_wave(w) else 0)
			if types > GameConfig.wave_max_enemy_types:
				ok = false
				printerr("Wave %d seed %d has %d types" % [w, s, types])
			seen.merge(ids)
	assert_true(ok, "No generated wave 31-40 has more than wave_max_enemy_types types")
	assert_true(seen.size() > 5, "Generated waves draw from the whole catalogue (saw %d types)" % seen.size())
	wm.queue_free()


func test_scripted_wave_scale() -> void:
	print("\n[GROUP 14] Scale comes from the WaveScript up to victory_wave, the ScaleConfig after")
	var wm := WaveManager.new()
	add_child(wm)
	var m10 := wm.get_wave_mults(10)
	assert_true(is_equal_approx(m10.x, wm.wave_script.get_hp_mult(10)) and is_equal_approx(m10.y, wm.wave_script.get_dmg_mult(10)) and is_equal_approx(m10.z, wm.wave_script.get_speed_mult(10)), "Boss wave 10 uses WaveScript multipliers")
	var m31 := wm.get_wave_mults(31)
	assert_true(is_equal_approx(m31.x, wm.scale_config.get_hp_mult(31)), "Wave 31 uses the ScaleConfig formula")

	var script := WaveScript.new()
	script.hp_mult = PackedFloat32Array([3.0])
	script.dmg_mult = PackedFloat32Array([2.0])
	script.speed_mult = PackedFloat32Array([1.5])
	wm.wave_script = script
	var m1 := wm.get_wave_mults(1)
	assert_true(m1 == Vector3(3.0, 2.0, 1.5), "Multipliers are read from the WaveScript")
	var m2 := wm.get_wave_mults(2)
	assert_true(is_equal_approx(m2.x, wm.scale_config.get_hp_mult(2)), "A wave missing from the WaveScript falls back to the formula")

	var grunt := (wm.get_enemy_scene(&"grunt").instantiate()) as Enemy
	wm.apply_wave_scale_to(grunt, 1)
	assert_true(is_equal_approx(grunt.wave_hp_mult, 3.0) and is_equal_approx(grunt.wave_speed_mult, 1.5), "apply_wave_scale_to applies the scripted multipliers")
	grunt.free()
	wm.queue_free()


func test_catalog_has_ten_types() -> void:
	print("\n[GROUP 15] The spawner can send all ten unit types")
	var wm := WaveManager.new()
	add_child(wm)
	assert_true(wm.enemy_scenes.size() == 10, "Catalogue has 10 types")
	var all_ok := true
	for id in wm.enemy_scenes:
		var unit := wm.enemy_scenes[id].instantiate() as Enemy
		if unit == null or unit.data == null or unit.data.id != id:
			all_ok = false
			printerr("Scene of '%s' does not carry matching EnemyData" % id)
		if unit != null:
			unit.free()
		if wm.get_enemy_data(id) == null:
			all_ok = false
	assert_true(all_ok, "Every catalogue scene instantiates with its own EnemyData")
	wm.queue_free()


func test_wave_plan_matches_queue() -> void:
	print("\n[GROUP 16] The PREP preview lists the queued units and the boss")
	var wm := WaveManager.new()
	add_child(wm)
	wm.current_wave = 10
	wm.start_prep()
	var plan := wm.get_wave_plan()
	var expected := {}
	for entry in wm.wave_script.get_wave(10):
		expected[entry.enemy_type] = int(expected.get(entry.enemy_type, 0)) + int(entry.count)
	assert_true(plan == expected, "Wave 10 preview equals the WaveScript (boss included): %s" % plan)
	assert_true(plan.size() <= GameConfig.wave_max_enemy_types, "Preview has at most wave_max_enemy_types types")
	wm.queue_free()
