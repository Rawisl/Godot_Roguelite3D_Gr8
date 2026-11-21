extends Node
## Runner for the enemy traits and the wave preview:
## - every trait flag is off by default and the units in the game today have none
## - the trait ids come from the flags, in the order the HUD shows them, and EnemyTraits reads
##   them from the data without test overrides
## - each PREP sends the wave preview before PREP itself, with exactly the units that will spawn
##   and the boss on a boss wave

var passes: int = 0
var fails: int = 0
var _events: Array = []


func _ready() -> void:
	print("\n=======================================================")
	print("              ENEMY TRAITS RUNNER TEST                 ")
	print("=======================================================")
	test_defaults_off()
	test_trait_ids()
	await test_wave_preview()
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


func test_defaults_off() -> void:
	print("\n[GROUP 1] Off by default")
	var blank := EnemyData.new()
	assert_true(not blank.is_stealth and not blank.explode_on_contact and not blank.explode_on_death
			and blank.invuln_duration == 0.0 and not blank.is_charger and blank.revive_count == 0,
			"A new EnemyData has every trait off")
	assert_true(blank.traits.is_empty(), "No trait ids without flags")
	for id in [&"grunt", &"archer"]:
		var data := EnemyTraits.data_of(id)
		assert_true(data != null and data.traits.is_empty(), "%s has no trait" % id)
	var brute := EnemyTraits.data_of(&"brute")
	assert_true(brute != null and brute.traits == [&"charge"], "The Brute charges and shows only that trait")


func test_trait_ids() -> void:
	print("\n[GROUP 2] Trait ids from the flags")
	var data := EnemyData.new()
	data.revive_count = 1
	data.is_stealth = true
	assert_true(data.traits == [&"stealth", &"revive"], "Ids follow the HUD order, not the order they were set")
	data = EnemyData.new()
	data.explode_on_death = true
	assert_true(data.traits == [&"explode"], "Exploding on death is the explode trait")
	data = EnemyData.new()
	data.invuln_duration = 5.0
	assert_true(data.traits.is_empty(), "Undying needs both a duration and an HP threshold")
	data.invuln_hp_threshold = 0.5
	data.is_charger = true
	assert_true(data.traits == [&"undying", &"charge"], "Undying and charge")
	assert_true(EnemyTraits.ALL.all(func(id: StringName) -> bool: return id in [&"stealth", &"explode", &"undying", &"revive", &"charge"]),
			"The ids match the ones the HUD knows")
	assert_true(EnemyTraits.of(&"grunt").is_empty(), "EnemyTraits reads the data directly")


func test_wave_preview() -> void:
	print("\n[GROUP 3] Wave preview in PREP")
	var rs := RunState.new()
	add_child(rs)
	rs.run_seed = 77
	var on_preview := func(w: int, plan: Dictionary, boss: bool) -> void: _events.append(["preview", w, plan, boss])
	var on_state := func(s: StringName) -> void: _events.append(["state", s])
	EventBus.wave_preview_ready.connect(on_preview)
	EventBus.state_changed.connect(on_state)
	var wm := WaveManager.new()
	wm.auto_advance_summary = false
	add_child(wm)
	await get_tree().process_frame
	assert_true(_events.filter(func(e: Array) -> bool: return e[0] == "preview").size() >= 2,
			"The first PREP is sent again once the HUD is ready")

	_events.clear()
	rs.wave_index = 4
	wm.start_prep()
	var preview_at := _events.find_custom(func(e: Array) -> bool: return e[0] == "preview")
	var prep_at := _events.find_custom(func(e: Array) -> bool: return e[0] == "state" and e[1] == &"PREP")
	assert_true(preview_at >= 0 and preview_at < prep_at, "The preview comes before PREP is announced")
	var plan: Dictionary = _events[preview_at][2]
	var total := 0
	for id in plan:
		total += int(plan[id])
	assert_true(_events[preview_at][1] == 4 and not _events[preview_at][3], "Wave 4, no boss")
	assert_true(total == wm.spawn_queue.size(), "The preview counts exactly the units queued")

	_events.clear()
	rs.wave_index = GameConfig.boss_wave_interval
	wm.start_prep()
	preview_at = _events.find_custom(func(e: Array) -> bool: return e[0] == "preview")
	plan = _events[preview_at][2]
	var boss_id: StringName = wm.boss_data.id
	assert_true(_events[preview_at][3] and plan.get(boss_id, 0) == 1, "A boss wave lists the boss once")

	EventBus.wave_preview_ready.disconnect(on_preview)
	EventBus.state_changed.disconnect(on_state)
	wm.queue_free()
	rs.queue_free()
	await get_tree().process_frame
