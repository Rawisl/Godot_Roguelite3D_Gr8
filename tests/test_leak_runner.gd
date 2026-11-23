extends Node

## Ten runs of the run scene in a row: each starts a run, clears wave 1 to its summary,
## abandons, and frees the scene. Memory, object and node counts after the last run stay
## within LEAK_TOLERANCE of the counts after the second run, and no orphan nodes pile up.
## The save goes to user://test_save_leak/, online features are off.

const MAIN_SCENE := preload("res://main.tscn")
const TEST_DIR := "user://test_save_leak"
const TEST_PATH := TEST_DIR + "/endlesswar_save.json"
const RUNS := 10
const BASELINE_RUN := 2
const LEAK_TOLERANCE := 0.05
const WAVE_TIMEOUT_SEC := 30.0
const SETTLE_SEC := 1.5
const KILL_DAMAGE := 1 << 30

var passes: int = 0
var fails: int = 0
var _started: int = 0
var _ended: int = 0


func _ready() -> void:
	print("\n=======================================================")
	print("                  TEN RUNS LEAK TEST                   ")
	print("=======================================================")
	var started_at := Time.get_ticks_msec()
	var real_state := GameState.current
	var real_end_type := GameState.last_run_end_type
	var real_summary := GameState.last_run_summary.duplicate(true)
	var real_online := GameConfig.online_enabled
	var real_repository := SaveManager.repository
	var real_data := SaveManager.data.duplicate(true)
	var real_can_write := SaveManager.can_write
	var real_loaded_from := SaveManager.loaded_from
	var real_load_failure := SaveManager.load_failure
	# RUN_END cannot follow RUN_END, so abandoning never replaces this test scene.
	GameState.current = GameState.AppState.RUN_END
	GameConfig.online_enabled = false
	_clear_test_dir()
	SaveManager.set_repository(LocalSaveRepository.new(TEST_PATH))
	SaveManager.load_save()
	SaveManager.can_write = true
	SaveManager.mark_tutorial_done()
	EventBus.run_started.connect(_on_run_started)
	EventBus.run_ended.connect(_on_run_ended)
	# Let the root finish adding this runner before adding the first run scene.
	await get_tree().process_frame
	var before := _sample()
	_print_sample("before run 1", before)
	var samples: Dictionary = {}
	for index in range(1, RUNS + 1):
		var succeeded := await _play_one_run(index)
		assert_true(succeeded, "run %d reached the summary" % index)
		if not succeeded:
			break
		samples[index] = _sample()
		_print_sample("after run %d" % index, samples[index])
	if samples.has(RUNS):
		_check_samples(before, samples[BASELINE_RUN], samples[RUNS])
	EventBus.run_started.disconnect(_on_run_started)
	EventBus.run_ended.disconnect(_on_run_ended)
	_clear_test_dir()
	GameState.current = real_state
	GameState.last_run_end_type = real_end_type
	GameState.last_run_summary = real_summary
	GameConfig.online_enabled = real_online
	SaveManager.set_repository(real_repository)
	SaveManager.load_save()
	SaveManager.data = real_data
	SaveManager.can_write = real_can_write
	SaveManager.loaded_from = real_loaded_from
	SaveManager.load_failure = real_load_failure
	TimeManager.reset()
	print("  Runner time: %.2f s" % ((Time.get_ticks_msec() - started_at) / 1000.0))
	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")
	get_tree().quit(0 if fails == 0 else 1)


func _play_one_run(index: int) -> bool:
	var started_before := _started
	var ended_before := _ended
	var scene := MAIN_SCENE.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	var deadline := Time.get_ticks_msec() + int(WAVE_TIMEOUT_SEC * 1000.0)
	var wm: WaveManager
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		wm = get_tree().get_first_node_in_group(&"wave_manager") as WaveManager
		if _started == started_before + 1 and wm != null and wm.wave_state == Enums.WaveState.PREP:
			break
	if _started != started_before + 1 or wm == null or wm.wave_state != Enums.WaveState.PREP:
		await _free_run_scene(scene)
		return false
	if index == 1:
		var ordinary_wave := not wm.is_boss_wave(1)
		assert_true(ordinary_wave, "wave 1 is not a boss wave")
		if not ordinary_wave:
			await _free_run_scene(scene)
			return false
	EventBus.wave_start_requested.emit()
	var killed := 0
	deadline = Time.get_ticks_msec() + int(WAVE_TIMEOUT_SEC * 1000.0)
	while wm.wave_state != Enums.WaveState.SUMMARY:
		if Time.get_ticks_msec() >= deadline:
			await _free_run_scene(scene)
			return false
		await get_tree().physics_frame
		wm.spawn_timer = maxf(wm.spawn_timer, 1000.0)
		for enemy in get_tree().get_nodes_in_group(&"enemy"):
			if not enemy is Enemy or enemy.is_dead:
				continue
			enemy.spawn_grace = false
			enemy.is_in_spawn_zone = false
			enemy.take_damage(DamageInfo.new(KILL_DAMAGE, Enums.DamageType.TRUE))
			if enemy.is_dead:
				killed += 1
	var alive := 0
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		if enemy is Enemy and not enemy.is_dead:
			alive += 1
	var wave_cleared := killed > 0 and alive == 0
	assert_true(wave_cleared, "run %d killed %d wave 1 enemies, %d still alive at the summary" % [index, killed, alive])
	var run_flag: Dictionary = _read_save().get("data", {}).get("run_flag", {})
	var summary_saved: bool = int(run_flag.get("waves_cleared", -1)) == 1 and run_flag.get("run_in_progress", false) == true
	assert_true(summary_saved, "run %d summary is on disk and in progress" % index)
	GameState.abandon_run()
	var ended_once := _ended == ended_before + 1
	assert_true(ended_once, "run %d ended exactly once" % index)
	await _free_run_scene(scene)
	var scene_freed := not is_instance_valid(scene)
	assert_true(scene_freed, "run %d scene instance is freed after the settle wait" % index)
	return summary_saved and ended_once and wave_cleared and scene_freed


func _free_run_scene(scene: Node) -> void:
	get_tree().current_scene = self
	scene.queue_free()
	for frame in range(3):
		await get_tree().process_frame
	await get_tree().create_timer(SETTLE_SEC).timeout
	for frame in range(2):
		await get_tree().process_frame


func _sample() -> Dictionary:
	return {
		"memory": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
	}


func _print_sample(label: String, sample: Dictionary) -> void:
	print("  %s: memory %.2f MB, objects %d, nodes %d, resources %d, orphans %d" % [
		label, sample.memory / (1024.0 * 1024.0), sample.objects, sample.nodes, sample.resources, sample.orphans])


func _check_samples(before: Dictionary, base: Dictionary, last: Dictionary) -> void:
	var memory_usable: bool = base.memory > 0
	assert_true(memory_usable, "memory monitor reports a usable value (memory growth not compared otherwise)")
	if memory_usable:
		assert_true(last.memory <= base.memory * (1.0 + LEAK_TOLERANCE), "memory after run 10 within 5% of run 2")
	assert_true(last.objects <= base.objects * (1.0 + LEAK_TOLERANCE), "objects after run 10 within 5% of run 2")
	assert_true(last.nodes <= base.nodes * (1.0 + LEAK_TOLERANCE), "nodes after run 10 within 5% of run 2")
	assert_true(last.orphans <= before.orphans, "no new orphan nodes")
	var stats: Dictionary = _read_save().get("data", {}).get("profile", {}).get("stats", {})
	assert_true(int(stats.get("total_runs", -1)) == RUNS, "every run was counted once in the save")
	for metric in ["memory", "objects", "nodes"]:
		if base[metric] > 0:
			print("  %s growth run 2 -> run 10: %+.2f%%" % [metric, (float(last[metric]) / base[metric] - 1.0) * 100.0])
	print("  Nodes before run 1: %d; after run 10: %d" % [before.nodes, last.nodes])
	if last.nodes > before.nodes:
		print("  Remaining nodes below /root (excluding autoload roots and this runner):")
		for child in get_tree().root.get_children():
			if child == self:
				continue
			if not ProjectSettings.has_setting("autoload/" + String(child.name)):
				print("    %s" % child.get_path())
			_print_children(child)
	if last.orphans > before.orphans:
		Node.print_orphan_nodes()


func _print_children(parent: Node) -> void:
	for child in parent.get_children():
		print("    %s" % child.get_path())
		_print_children(child)


func _read_save() -> Dictionary:
	if not FileAccess.file_exists(TEST_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	return parsed if parsed is Dictionary else {}


func _clear_test_dir() -> void:
	var local := LocalSaveRepository.new(TEST_PATH)
	for source in [SaveRepository.Source.MAIN, SaveRepository.Source.TEMP, SaveRepository.Source.BACKUP]:
		for path in [local.path_of(source), local.corrupt_path(source)]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR)


func _on_run_started() -> void:
	_started += 1


func _on_run_ended(_end_type: StringName, _summary: Dictionary) -> void:
	_ended += 1


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)
