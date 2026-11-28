extends Node
## Runner for the cheat scene:
## - HealthComponent ignores damage while its invulnerable flag is set
## - the cheat scene starts one run by itself, never writes the save, and restores it on exit
## - account sync answers offline inside the scene and gets its real api back on exit
## - PageUp toggles the panel; the summon list holds the plain enemies and the listed bosses
## - gold, level, wave jump, summon, kill, invincibility and heal act on the real systems
## - a summoned boss tells the boss bar its id and announces its spawn
## The save runs on an in-memory repository, so the player's save is never touched.

const GRUNT_PATH := "res://entities/enemy/grunt.tscn"
const CENTIPEDE_PATH := "res://entities/enemy/skeletal_centipede.tscn"

var passes: int = 0
var fails: int = 0
var _real_repo: SaveRepository
var _real_sync_api: Variant
var _memory: MemorySaveRepository
var _prev_state: GameState.AppState
var _cheat: Node
var _panel: Node
var _wm: WaveManager
var _rs: RunState
var _run_started_count := 0
var _level_up_count := 0
var _spawned: Array = []
var _boss_events: Array = []
var _hc_damaged := 0
var _hc_hp_changed := 0
var _hc_died := 0


class MemorySaveRepository extends SaveRepository:
	var stored: Dictionary = {}

	func has_data() -> bool:
		return not stored.is_empty()

	func load_data() -> Dictionary:
		last_error = OK if has_data() else ERR_FILE_NOT_FOUND
		return stored.duplicate(true)

	func save_data(envelope: Dictionary) -> Error:
		stored = envelope.duplicate(true)
		return OK


func _ready() -> void:
	print("\n=======================================================")
	print("            CHEAT PANEL VERIFICATION                   ")
	print("=======================================================")

	_real_repo = SaveManager.repository
	_memory = MemorySaveRepository.new()
	SaveManager.set_repository(_memory)
	SaveManager.load_save()
	SaveManager.mark_tutorial_done()
	_prev_state = GameState.current
	_real_sync_api = SyncService.api

	test_health_invulnerable()

	EventBus.run_started.connect(_count_run_started)
	_cheat = (load("res://tests/cheat_main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_cheat)
	# Queued before the scene's own deferred start: when the scene is run with F6 the SaveManager
	# autoload loads the save after the scene entered the tree, which turns writes back on. The
	# scene must switch them off again right before it starts the run.
	SaveManager.load_save.call_deferred()
	await get_tree().process_frame
	get_tree().current_scene = _cheat
	await _frames(6)
	_panel = _cheat.get_node("CheatPanel")
	_wm = get_tree().get_first_node_in_group(&"wave_manager") as WaveManager
	_rs = get_tree().get_first_node_in_group(&"run_state") as RunState

	test_startup()
	await test_sync_offline()
	test_panel_and_input()
	test_gold_and_level()
	test_skill_picker()
	test_jump_and_phase_gating()
	await test_combat_cheats()

	_cheat.queue_free()
	await _frames(2)
	get_tree().current_scene = self
	GameState.current = _prev_state
	if EventBus.run_started.is_connected(_count_run_started):
		EventBus.run_started.disconnect(_count_run_started)
	test_leave_scene()
	SaveManager.set_repository(_real_repo)
	SaveManager.load_save()

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


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _count_run_started() -> void:
	_run_started_count += 1


func _count_level_up(_level: int, _picks: int) -> void:
	_level_up_count += 1


func _catch_spawn(enemy: Node) -> void:
	_spawned.append(enemy)


func _count_damaged(_amount: int, _info: DamageInfo) -> void:
	_hc_damaged += 1


func _count_hp_changed(_hp: int, _max_hp: int) -> void:
	_hc_hp_changed += 1


func _count_died() -> void:
	_hc_died += 1


func _page_up(pressed: bool, echo: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_PAGEUP
	ev.pressed = pressed
	ev.echo = echo
	get_viewport().push_input(ev)


func _gold() -> int:
	return (get_tree().get_first_node_in_group(&"gold_manager") as GoldManager).gold


func test_health_invulnerable() -> void:
	print("\n[GROUP A] HealthComponent invulnerable flag")
	var hc := HealthComponent.new()
	hc.max_hp = 100
	add_child(hc)
	hc.damaged.connect(_count_damaged)
	hc.hp_changed.connect(_count_hp_changed)
	hc.died.connect(_count_died)
	assert_true(not hc.invulnerable, "test_a1_invulnerable_default_false")
	hc.invulnerable = true
	var taken := hc.take_damage(30)
	assert_true(taken == 0 and hc.hp == 100 and _hc_damaged == 0 and _hc_hp_changed == 0,
		"test_a2_invulnerable_ignores_damage")
	taken = hc.take_damage(DamageInfo.new(1000, Enums.DamageType.TRUE))
	assert_true(taken == 0 and _hc_died == 0 and hc.is_alive(), "test_a3_invulnerable_ignores_lethal_hit")
	hc.invulnerable = false
	taken = hc.take_damage(30)
	assert_true(taken == 30 and hc.hp == 70 and _hc_damaged == 1, "test_a4_damage_works_after_switch_off")
	hc.take_damage(DamageInfo.new(1000, Enums.DamageType.TRUE))
	assert_true(_hc_died == 1, "test_a5_lethal_hit_still_emits_died")
	hc.queue_free()


func test_startup() -> void:
	print("\n[GROUP B] Cheat scene startup")
	assert_true(_run_started_count == 1, "test_b1_run_started_once")
	assert_true(_rs != null and _wm != null and _rs.wave_index == 1
		and _wm.wave_state == Enums.WaveState.PREP, "test_b2_starts_in_prep_wave_1")
	assert_true(GameState.current == GameState.AppState.RUN, "test_b3_app_state_is_run")
	var in_progress: bool = _memory.stored.get("data", {}).get("run_flag", {}).get("run_in_progress", false)
	assert_true(not SaveManager.can_write and not in_progress, "test_b4_save_is_not_written")
	assert_true(not get_tree().get_nodes_in_group(&"tower").is_empty(), "test_b5_starter_towers_exist")


func test_sync_offline() -> void:
	print("\n[GROUP B2] Account sync inside the scene")
	var api: Variant = SyncService.api
	assert_true(api != _real_sync_api, "test_b6_sync_api_swapped")
	var pull: Dictionary = await api.pull_save()
	var push: Dictionary = await api.push_save(5, "device", SaveManager.data)
	assert_true(not pull.get("ok", true) and pull.get("error") == AuthService.ERR_OFFLINE
		and not push.get("ok", true) and not push.get("conflict", true), "test_b7_sync_never_pulls_or_pushes")


func test_panel_and_input() -> void:
	print("\n[GROUP C] Panel and input")
	assert_true(not _panel.visible, "test_c1_hidden_on_open")
	_page_up(true, false)
	assert_true(_panel.visible, "test_c2_page_up_shows_panel")
	_page_up(true, true)
	_page_up(false, false)
	assert_true(_panel.visible, "test_c3_echo_and_release_ignored")
	_page_up(true, false)
	assert_true(not _panel.visible, "test_c4_page_up_hides_panel")
	assert_true(tr(&"debug.cheat.title") != "debug.cheat.title", "test_c5_strings_imported")
	var scenes: Array[PackedScene] = _panel.get_summon_scenes()
	var paths: Array[String] = []
	for scene in scenes:
		paths.append(scene.resource_path)
	var labels_ok := true
	for i in _panel.summon_option.item_count:
		var label: String = _panel.summon_option.get_item_text(i)
		if label.is_empty() or label.begins_with("enemy."):
			labels_ok = false
	assert_true(paths.has(GRUNT_PATH) and paths.has("res://entities/enemy/archer.tscn")
		and paths.has("res://entities/enemy/brute.tscn")
		and not paths.has("res://entities/enemy/enemy.tscn")
		and not paths.has("res://entities/enemy/bulwark.tscn")
		and paths.has(CENTIPEDE_PATH)
		and _panel.summon_option.item_count == scenes.size() and labels_ok,
		"test_c6_summon_list_plain_enemies_and_listed_bosses")
	var focus_free := true
	for control in _panel.get_clickable_controls():
		if control.focus_mode != Control.FOCUS_NONE:
			focus_free = false
	assert_true(focus_free, "test_c7_controls_never_take_focus")


func test_gold_and_level() -> void:
	print("\n[GROUP D] Gold and level")
	var gold_before := _gold()
	var earned_before := _rs.run_gold_earned
	_panel.add_gold()
	assert_true(_gold() == gold_before + _panel.gold_amount and _rs.run_gold_earned == earned_before,
		"test_d1_add_gold_not_counted_as_earned")
	var tracker := get_tree().get_first_node_in_group(&"xp_tracker") as XpTracker
	var level_before := tracker.commander_level
	var picks_before := tracker.pending_picks
	_level_up_count = 0
	EventBus.level_up.connect(_count_level_up)
	var gained: bool = _panel.add_level()
	assert_true(gained and tracker.commander_level == level_before + 1
		and tracker.pending_picks == picks_before + 1 and _level_up_count == 1,
		"test_d2_add_level_gains_one_level")
	_panel.add_level()
	EventBus.level_up.disconnect(_count_level_up)
	assert_true(tracker.commander_level == level_before + 2, "test_d3_add_level_twice")


func test_skill_picker() -> void:
	print("
[GROUP D2] Skill picker")
	var commander := get_tree().get_first_node_in_group(&"commander")
	var runner: SkillRunner = commander.skill_runner
	var ids: Array[StringName] = []
	for i in _panel.skill_option.item_count:
		ids.append(_panel.skill_option.get_item_metadata(i))
	assert_true(ids.size() == 4 and ids.has(&"blade_tempest") and ids.has(&"whirlwind")
		and ids.has(&"sword_wave") and ids.has(&"firebomb")
		and not _panel.skill_option.get_item_text(0).begins_with("skill."),
		"test_d2_skill_list_holds_four_active_skills")
	runner.reset()
	var slot: int = _panel.add_skill(&"blade_tempest")
	assert_true(slot == 0 and runner.state.get_level(&"blade_tempest") == 1,
		"test_d3_add_skill_takes_lowest_slot_at_level_1")
	_panel.add_skill(&"blade_tempest")
	assert_true(runner.state.get_level(&"blade_tempest") == 2, "test_d4_second_add_raises_level")
	_panel.add_skill(&"blade_tempest")
	_panel.add_skill(&"blade_tempest")
	assert_true(runner.state.get_level(&"blade_tempest") == 3, "test_d5_level_capped_at_max")
	runner.reset()
	_panel.add_skill(&"whirlwind")
	_panel.add_skill(&"sword_wave")
	_panel.add_skill(&"firebomb")
	assert_true(_panel.add_skill(&"blade_tempest") == -1, "test_d6_no_free_slot_returns_minus_one")
	assert_true(_panel.add_skill(&"missing_skill") == -1, "test_d7_unknown_skill_returns_minus_one")
	runner.reset()
	assert_true(not _panel.skill_button.disabled, "test_d8_button_enabled_while_run_goes")


func test_jump_and_phase_gating() -> void:
	print("\n[GROUP E] Wave jump and phase gating")
	assert_true(not _wm.is_boss_wave(3), "test_e0_wave_3_is_not_boss")
	assert_true(not _panel.jump_button.disabled and _panel.summon_button.disabled,
		"test_e1_prep_buttons")
	var jumped: bool = _panel.jump_to_wave(3)
	assert_true(jumped and _wm.current_wave == 3 and _rs.waves_cleared == 2
		and _wm.wave_state == Enums.WaveState.PREP and not _wm.spawn_queue.is_empty(),
		"test_e2_jump_to_wave_3")
	assert_true(not _panel.jump_to_wave(0) and _wm.current_wave == 3, "test_e3_jump_to_wave_0_refused")
	var grunt := load(GRUNT_PATH) as PackedScene
	var alive_before := _wm.enemies_alive
	assert_true(_panel.summon(grunt) == null and _wm.enemies_alive == alive_before,
		"test_e4_summon_refused_in_prep")
	_wm.start_combat()
	assert_true(not _panel.summon_button.disabled and _panel.jump_button.disabled,
		"test_e5_combat_buttons")
	assert_true(not _panel.jump_to_wave(7) and _wm.current_wave == 3, "test_e6_jump_refused_in_combat")


func test_combat_cheats() -> void:
	print("\n[GROUP F] Combat cheats")
	var grunt := load(GRUNT_PATH) as PackedScene
	var alive_before := _wm.enemies_alive
	var total_before := _wm.total_wave_enemies
	_spawned.clear()
	EventBus.enemy_spawned.connect(_catch_spawn)
	var enemy := _panel.summon(grunt) as Enemy
	var expected_parent: Node = _wm.enemy_container if is_instance_valid(_wm.enemy_container) else _wm
	EventBus.enemy_spawned.disconnect(_catch_spawn)
	assert_true(enemy != null and _wm.enemies_alive == alive_before + 1
		and _wm.total_wave_enemies == total_before + 1 and _spawned.size() == 1 and _spawned[0] == enemy
		and enemy.scene_file_path == GRUNT_PATH and enemy.spawn_wave == 3
		and enemy.get_parent() == expected_parent, "test_f1_summon_adds_scaled_enemy")

	var cmd: Node = get_tree().get_first_node_in_group(&"commander")
	var sword_before: float = cmd.get_sword_dealt_mult()
	var skill_before: float = cmd.stat_block.get_mul_total(&"skill_damage")
	var bonus: float = _panel.instant_kill_mult - 1.0
	_panel.set_instant_kill(true)
	assert_true(is_equal_approx(cmd.get_sword_dealt_mult(), sword_before + bonus)
		and is_equal_approx(cmd.stat_block.get_mul_total(&"skill_damage"), skill_before + bonus)
		and _panel.instant_kill_check.button_pressed, "test_f2a_instant_kill_buffs_commander")

	var kills_before := _rs.run_kills
	enemy.spawn_grace = false
	var hit := DamageInfo.outgoing(cmd.stat_block.get_base(&"sword_damage"), cmd.get_sword_dealt_mult(),
		cmd.stats.sword_damage_type, cmd)
	enemy.take_damage(hit)
	assert_true(enemy.is_dead and _rs.run_kills == kills_before + 1, "test_f2b_one_sword_hit_kills")

	cmd.stat_block.clear_source(_panel.INSTANT_KILL_SOURCE)
	await get_tree().create_timer(0.6).timeout
	assert_true(is_equal_approx(cmd.get_sword_dealt_mult(), sword_before + bonus),
		"test_f2c_refresh_puts_bonus_back")

	_panel.set_instant_kill(false)
	assert_true(is_equal_approx(cmd.get_sword_dealt_mult(), sword_before)
		and is_equal_approx(cmd.stat_block.get_mul_total(&"skill_damage"), skill_before)
		and not _panel.instant_kill_check.button_pressed, "test_f2d_switch_off_restores_damage")

	var fortress := get_tree().get_first_node_in_group(&"fortress")
	var commander := get_tree().get_first_node_in_group(&"commander")
	_panel.set_invincible(true)
	var all_flagged: bool = fortress.health.invulnerable and commander.health.invulnerable
	for tower in get_tree().get_nodes_in_group(&"tower"):
		all_flagged = all_flagged and tower.health.invulnerable
	assert_true(all_flagged and _panel.invincible_check.button_pressed, "test_f3_invincible_flags_everyone")

	var fortress_hp: int = fortress.health.hp
	var commander_hp: int = commander.health.hp
	fortress.take_damage(50)
	commander.health.take_damage(10)
	assert_true(fortress.health.hp == fortress_hp and commander.health.hp == commander_hp,
		"test_f4_no_damage_while_invincible")

	var tower := get_tree().get_first_node_in_group(&"tower")
	tower.health.invulnerable = false
	await get_tree().create_timer(0.6).timeout
	assert_true(tower.health.invulnerable, "test_f5_refresh_reapplies_flag")

	_panel.set_invincible(false)
	var none_flagged: bool = not fortress.health.invulnerable and not commander.health.invulnerable
	for t in get_tree().get_nodes_in_group(&"tower"):
		none_flagged = none_flagged and not t.health.invulnerable
	fortress.take_damage(50)
	assert_true(none_flagged and fortress.health.hp < fortress_hp, "test_f6_damage_returns_after_switch_off")

	var healed: int = _panel.heal_all()
	assert_true(healed >= 1 and fortress.health.hp == fortress.health.max_hp, "test_f7_heal_all")

	var alive_before_boss := _wm.enemies_alive
	_boss_events.clear()
	EventBus.boss_intro_started.connect(_catch_boss_intro)
	EventBus.boss_spawned.connect(_catch_boss_spawned)
	var boss := _panel.summon(load(CENTIPEDE_PATH) as PackedScene) as Enemy
	EventBus.boss_intro_started.disconnect(_catch_boss_intro)
	EventBus.boss_spawned.disconnect(_catch_boss_spawned)
	assert_true(boss is SkeletalCentipede and boss.is_inside_tree() and boss.spawn_wave == 3
		and _wm.enemies_alive == alive_before_boss + 1
		and _boss_events == [&"skeletal_centipede", &"spawned"], "test_f8_summon_centipede_boss")


func _catch_boss_intro(boss_id: StringName) -> void:
	_boss_events.append(boss_id)


func _catch_boss_spawned() -> void:
	_boss_events.append(&"spawned")


func test_leave_scene() -> void:
	print("\n[GROUP G] Leaving the scene")
	assert_true(SaveManager.can_write, "test_g1_can_write_restored")
	assert_true(SyncService.api == _real_sync_api, "test_g1b_sync_api_restored")
