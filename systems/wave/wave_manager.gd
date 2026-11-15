class_name WaveManager
extends Node

## Wave FSM (PREP - COMBAT - SUMMARY) and Spawner.
## Supports queue-based spawning, spawn_zone placement, spawn_grace,
## deterministic wave composition generation by run_seed, group scheduling, and queue throttling.
# TODO(Ender-Via): when meta progression lands, return gold_pct_meta + gold_pct_buff from _gold_pct_total(); it feeds both the wave gold and the boss gold.
# TODO(Ender-Via): when the start_wave run flag lands, account for start_wave > 1 when computing waves_cleared in the summary step.
# TODO(Ender-Via): when waves past 30 are scripted, spawn boss escorts at 0.5x budget from wave 31 instead of reading them from the WaveScript.
# TODO(Ender-Via): pause with REASON_VICTORY once the victory screen lands; currently disabled by default.

signal wave_fsm_state_changed(new_state: Enums.WaveState, old_state: Enums.WaveState)

@export var run_seed: int = 0
@export var grunt_scene: PackedScene = preload("res://entities/enemy/grunt.tscn")
@export var archer_scene: PackedScene = preload("res://entities/enemy/archer.tscn")
@export var brute_scene: PackedScene = preload("res://entities/enemy/brute.tscn")
@export var bulwark_scene: PackedScene = preload("res://entities/enemy/bulwark.tscn")
@export var boss_data: BossData = preload("res://data/bosses/bulwark_boss.tres")
@export var scale_config: ScaleConfig = preload("res://data/config/scale_config.tres")
@export var wave_table: WaveTable = preload("res://data/waves/wave_table.tres")

@export var spawn_interval: float = 0.6
@export var default_wave_1_count: int = 8
@export var auto_advance_summary: bool = true
@export var enable_reward_pick: bool = true
@export var enable_victory_screen: bool = false

var _intro_timer: float = 0.0
var _intro_elapsed: float = 0.0
var _victory_handled: bool = false
var _waiting_victory_continue: bool = false

var _fallback_current_wave: int = 1
var current_wave: int:
	get:
		var rs := _get_run_state()
		return rs.wave_index if rs != null else _fallback_current_wave
	set(value):
		_fallback_current_wave = value
		var rs := _get_run_state()
		if rs != null:
			rs.wave_index = value

var wave_state: Enums.WaveState = Enums.WaveState.PREP

var spawn_queue: Array[PackedScene] = []
var _spawn_delays: Array[float] = []
var _next_spawn_delay: float = 0.6

var _fallback_enemies_alive: int = 0
var enemies_alive: int:
	get:
		var rs := _get_run_state()
		return rs.enemies_alive if rs != null else _fallback_enemies_alive
	set(value):
		_fallback_enemies_alive = value
		var rs := _get_run_state()
		if rs != null:
			rs.enemies_alive = value

var total_wave_enemies: int = 0

var spawn_timer: float = 0.0
var summary_timer: float = 0.0

var spawn_point: Vector3 = Vector3(14.0, 0.0, 0.0)
var spawn_zone_half_extents: Vector3 = Vector3(6.0, 2.0, 8.0)
var enemy_container: Node3D = null

var _wave_rng: RandomNumberGenerator = null
var _retry_elapsed: float = 0.0
var _last_candidate_pos: Vector3 = Vector3.ZERO

var _fallback_wave_gold_base: float = 0.0
var _wave_gold_base: float:
	get:
		var rs := _get_run_state()
		return rs.wave_gold_base if rs != null else _fallback_wave_gold_base
	set(value):
		_fallback_wave_gold_base = value
		var rs := _get_run_state()
		if rs != null:
			rs.wave_gold_base = value

var _fallback_wave_prestige: int = 0
var _wave_prestige: int:
	get:
		var rs := _get_run_state()
		return rs.wave_prestige_buffer if rs != null else _fallback_wave_prestige
	set(value):
		_fallback_wave_prestige = value
		var rs := _get_run_state()
		if rs != null:
			rs.wave_prestige_buffer = value
var _kills_by_type: Dictionary = {}

const XP_TRACKER_SCRIPT := preload("res://systems/xp/xp_tracker.gd")
const BOSS_TIMER_SCRIPT := preload("res://systems/wave/boss_timer.gd")

# Clear time tracking
var _combat_timer: float = 0.0
var _clear_time: float = 0.0
var _first_enemy_spawned: bool = false
var _is_run_lost: bool = false
var _boss_defeated_this_wave: bool = false
var _boss_enraged_this_wave: bool = false
var _boss_instance: Enemy = null

var _xp_tracker: Node = null
var _boss_timer: Node = null


func _ready() -> void:
	add_to_group(&"wave_manager")
	EventBus.wave_start_requested.connect(_on_wave_start_requested)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.summary_continue_requested.connect(_on_summary_continue_requested)
	EventBus.fortress_destroyed.connect(_on_run_lost)
	EventBus.commander_died.connect(_on_run_lost)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.boss_enraged.connect(_on_boss_enraged)
	_setup_xp_tracker()
	_setup_boss_timer()
	EventBus.reward_picked.connect(_on_reward_picked)
	EventBus.victory_continue_requested.connect(_on_victory_continue_requested)
	_setup_container.call_deferred()
	start_prep()


func _exit_tree() -> void:
	if EventBus.wave_start_requested.is_connected(_on_wave_start_requested):
		EventBus.wave_start_requested.disconnect(_on_wave_start_requested)
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)
	if EventBus.summary_continue_requested.is_connected(_on_summary_continue_requested):
		EventBus.summary_continue_requested.disconnect(_on_summary_continue_requested)
	if EventBus.fortress_destroyed.is_connected(_on_run_lost):
		EventBus.fortress_destroyed.disconnect(_on_run_lost)
	if EventBus.commander_died.is_connected(_on_run_lost):
		EventBus.commander_died.disconnect(_on_run_lost)
	if EventBus.boss_defeated.is_connected(_on_boss_defeated):
		EventBus.boss_defeated.disconnect(_on_boss_defeated)
	if EventBus.boss_enraged.is_connected(_on_boss_enraged):
		EventBus.boss_enraged.disconnect(_on_boss_enraged)
	if EventBus.reward_picked.is_connected(_on_reward_picked):
		EventBus.reward_picked.disconnect(_on_reward_picked)
	if EventBus.victory_continue_requested.is_connected(_on_victory_continue_requested):
		EventBus.victory_continue_requested.disconnect(_on_victory_continue_requested)


func _on_boss_defeated() -> void:
	if _boss_defeated_this_wave:
		return
	_boss_defeated_this_wave = true
	_boss_instance = null
	# Floating "+xx" only; the wallet gets the same amount at the summary step.
	var shown: int = _boss_gold_amount()
	if shown > 0:
		EventBus.gold_delta.emit(shown)


func _on_boss_enraged() -> void:
	# An Enrage that arrives after the boss died does not cut the reward.
	if _boss_defeated_this_wave:
		return
	_boss_enraged_this_wave = true


## 1.0, or enrage_reward_mult when the boss enraged this wave.
func _boss_reward_mult() -> float:
	return GameConfig.enrage_reward_mult if _boss_enraged_this_wave else 1.0


## Gold bonus percent applied to wave gold and boss gold.
func _gold_pct_total() -> float:
	return 0.0


## Boss gold paid at the summary step and shown when the boss dies: table gold, Enrage cut, gold bonus, rounded down once.
func _boss_gold_amount() -> int:
	var boss_gold: float = GameConfig.wave_rewards.get_boss_gold(current_wave)
	return WaveRewardTable.floor_gold(boss_gold * _boss_reward_mult() * (1.0 + _gold_pct_total()))


## Boss prestige added at the summary step, rounded down after the Enrage cut.
func _boss_prestige_amount() -> int:
	return WaveRewardTable.floor_gold(float(GameConfig.boss_prestige) * _boss_reward_mult())


func _setup_xp_tracker() -> void:
	_xp_tracker = get_tree().get_first_node_in_group(&"xp_tracker")
	if _xp_tracker == null:
		_xp_tracker = XP_TRACKER_SCRIPT.new()
		_xp_tracker.name = "XpTracker"
		add_child(_xp_tracker)


func _setup_boss_timer() -> void:
	_boss_timer = get_tree().get_first_node_in_group(&"boss_timer")
	if _boss_timer == null:
		_boss_timer = BOSS_TIMER_SCRIPT.new()
		_boss_timer.name = "BossTimer"
		add_child(_boss_timer)


func _setup_container() -> void:
	if enemy_container == null:
		var gameplay_enemy := get_tree().get_first_node_in_group(&"enemy_container") as Node3D
		if gameplay_enemy != null:
			enemy_container = gameplay_enemy
		else:
			var root := get_tree().current_scene
			if root != null:
				var candidate := root.find_child("Enemy", true, false) as Node3D
				if candidate != null:
					enemy_container = candidate

	var sz := get_tree().get_first_node_in_group(&"spawn_zone") as Area3D
	if sz == null:
		var root := get_tree().current_scene
		if root != null:
			sz = root.find_child("SpawnZone", true, false) as Area3D
	if sz != null:
		spawn_point = sz.global_position
		spawn_point.y = 0.0
		var col := sz.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col != null and col.shape is BoxShape3D:
			var box := col.shape as BoxShape3D
			spawn_zone_half_extents = box.size * 0.5


func _get_scene_for_enemy_id(enemy_id: StringName) -> PackedScene:
	match enemy_id:
		&"archer":
			return archer_scene
		&"brute":
			return brute_scene
		_:
			return grunt_scene


func start_prep() -> void:
	var old_state := wave_state
	wave_state = Enums.WaveState.PREP
	_build_spawn_queue_for_wave(current_wave)

	# Reset per-wave tracking
	_wave_gold_base = 0.0
	_wave_prestige = 0
	_kills_by_type.clear()
	_combat_timer = 0.0
	_clear_time = 0.0
	_first_enemy_spawned = false
	_boss_defeated_this_wave = false
	_boss_enraged_this_wave = false
	_boss_instance = null

	var rs := _get_run_state()
	if rs != null:
		rs.hazard_used = false

	wave_fsm_state_changed.emit(wave_state, old_state)
	EventBus.state_changed.emit(&"PREP")


func is_boss_wave(w: int = -1) -> bool:
	var wave_num := current_wave if w < 0 else w
	return (wave_num > 0 and wave_num % GameConfig.boss_wave_interval == 0)


func _on_wave_start_requested() -> void:
	if wave_state == Enums.WaveState.PREP:
		if is_boss_wave(current_wave):
			start_boss_intro()
		else:
			start_combat()


func start_boss_intro() -> void:
	var old_state := wave_state
	wave_state = Enums.WaveState.BOSS_INTRO
	_intro_timer = GameConfig.boss_intro_duration
	_intro_elapsed = 0.0
	TimeManager.set_time_scale(1)
	wave_fsm_state_changed.emit(wave_state, old_state)
	EventBus.state_changed.emit(&"BOSS_INTRO")
	var b_id: StringName = boss_data.id if boss_data != null else &"bulwark"
	EventBus.boss_intro_started.emit(b_id)


func skip_boss_intro() -> void:
	if wave_state != Enums.WaveState.BOSS_INTRO:
		return
	if _intro_elapsed < GameConfig.boss_intro_skip_delay:
		return
	start_combat()


func _unhandled_input(event: InputEvent) -> void:
	if wave_state == Enums.WaveState.BOSS_INTRO:
		if event.is_action_pressed(&"pause"):
			return
		if event.is_action_pressed(&"select") or event.is_action_pressed(&"ui_accept"):
			if _intro_elapsed >= GameConfig.boss_intro_skip_delay:
				skip_boss_intro()


func start_combat() -> void:
	var old_state := wave_state
	var is_boss: bool = is_boss_wave(current_wave)
	wave_state = Enums.WaveState.BOSS_COMBAT if is_boss else Enums.WaveState.COMBAT
	wave_fsm_state_changed.emit(wave_state, old_state)
	EventBus.state_changed.emit(&"BOSS_COMBAT" if is_boss else &"COMBAT")
	EventBus.wave_started.emit(current_wave)

	if spawn_queue.is_empty():
		_build_spawn_queue_for_wave(current_wave)
	total_wave_enemies = spawn_queue.size()
	enemies_alive = 0
	_retry_elapsed = 0.0
	spawn_timer = 0.0
	_combat_timer = 0.0
	_first_enemy_spawned = false

	if is_boss:
		_spawn_boss()

	if not _spawn_delays.is_empty():
		_next_spawn_delay = _spawn_delays.pop_front()
	else:
		_next_spawn_delay = wave_table.group_spawn_delay_min if wave_table != null else spawn_interval

	EventBus.enemy_count_changed.emit(enemies_alive, spawn_queue.size(), total_wave_enemies)


## Generates the structured wave composition according to budget, intro counts,
## archetype weights, grouping, and melee-first ordering.
func generate_wave_composition(wave_num: int, p_run_seed: int = 0) -> Array[Dictionary]:
	var cfg: ScaleConfig = scale_config if scale_config != null else ScaleConfig.new()
	var budget: int = cfg.get_budget(wave_num)
	var is_boss: bool = is_boss_wave(wave_num)
	if is_boss:
		# TODO(Ender-Via): SPN-10: escorts for waves 1-30 come from WaveScript; only from wave 31 is it 0.5x budget.
		budget = maxi(1, int(floor(float(budget) * 0.5)))

	var rng := RandomNumberGenerator.new()
	rng.seed = hash([p_run_seed, wave_num])

	var table: WaveTable = wave_table if wave_table != null else WaveTable.new()
	var archetypes: Array[Dictionary] = []
	for g in table.groups:
		if g == null or g.enemy == null:
			continue
		archetypes.append({
			"id": g.enemy.id,
			"scene": _get_scene_for_enemy_id(g.enemy.id),
			"cost": g.enemy.spawn_cost,
			"weight": g.weight,
			"min_wave": g.min_wave,
			"is_ranged": g.enemy.is_ranged,
			"intro_count": g.intro_count,
			"max_per_wave": g.max_per_wave
		})

	if archetypes.is_empty():
		archetypes.append({
			"id": &"grunt",
			"scene": grunt_scene,
			"cost": 1,
			"weight": 10.0,
			"min_wave": 1,
			"is_ranged": false,
			"intro_count": 0,
			"max_per_wave": -1
		})

	var chosen: Array[Dictionary] = []

	# Acceptance criteria: wave 0 (or non-positive wave) forces 1 Grunt
	if wave_num <= 0:
		push_warning("Wave %d has 0 enemies. Forced minimum 1 Grunt." % wave_num)
		chosen.append(archetypes[0])
	else:
		# Step 2: Newly introduced enemy types guaranteed intro_count, deducted first
		for arch in archetypes:
			if arch.intro_count > 0 and arch.min_wave == wave_num:
				var needed: int = arch.intro_count
				for i in range(needed):
					if budget >= arch.cost:
						budget -= arch.cost
						chosen.append(arch)

		# Step 3: Loop candidates satisfying min_wave, budget, caps, and weight
		while true:
			var candidates: Array[Dictionary] = []
			var current_archers: int = 0
			var current_brutes: int = 0
			for item in chosen:
				if item.id == &"archer":
					current_archers += 1
				elif item.id == &"brute":
					current_brutes += 1
			var current_total: int = chosen.size()

			for arch in archetypes:
				# 1. Must satisfy min_wave
				if wave_num < arch.min_wave:
					continue
				# 2. Waves 1-2 only contain Grunt
				if wave_num <= 2 and arch.id != &"grunt":
					continue
				# 3. On intro wave (w == min_wave), new unit count is fixed to intro_count
				if arch.intro_count > 0 and wave_num == arch.min_wave:
					continue
				# 4. Budget check
				if arch.cost > budget:
					continue
				# 5. Brute cap: floor(w / 4)
				if arch.id == &"brute":
					var max_brutes: int = int(floor(float(wave_num) / 4.0))
					if current_brutes >= max_brutes:
						continue
				# 6. Archer <= archer_max_ratio of total wave composition
				if arch.id == &"archer":
					var projected_ratio: float = float(current_archers + 1) / float(current_total + 1)
					if projected_ratio > table.archer_max_ratio:
						continue

				candidates.append(arch)

			if candidates.is_empty():
				break

			var total_weight: float = 0.0
			for c in candidates:
				total_weight += c.weight
			var roll: float = rng.randf_range(0.0, total_weight)
			var accum: float = 0.0
			var selected: Dictionary = candidates[0]
			for c in candidates:
				accum += c.weight
				if roll <= accum:
					selected = c
					break

			chosen.append(selected)
			budget -= selected.cost

	# Fallback if somehow empty
	if chosen.is_empty():
		push_warning("Wave %d generated 0 enemies. Forced minimum 1 Grunt." % wave_num)
		chosen.append(archetypes[0])

	# Step 4 & 5: Grouping and melee-first ordering
	var group_count: int = clampi(2 + int(floor(float(wave_num) / 5.0)), 2, 6)
	if chosen.size() < group_count:
		group_count = maxi(1, chosen.size())

	var melee_units: Array[Dictionary] = []
	var ranged_units: Array[Dictionary] = []
	for item in chosen:
		if item.is_ranged:
			ranged_units.append(item)
		else:
			melee_units.append(item)

	var groups: Array[Array] = []
	for g in range(group_count):
		groups.append([])

	# Distribute melee units across groups
	for i in range(melee_units.size()):
		var g_idx: int = i % group_count
		groups[g_idx].append(melee_units[i])

	# Distribute ranged units across groups (placed AFTER melee in each group)
	for i in range(ranged_units.size()):
		var g_idx: int = i % group_count
		groups[g_idx].append(ranged_units[i])

	# Flatten into final schedule with delays from wave_table
	var result: Array[Dictionary] = []

	for g_idx in range(group_count):
		var grp: Array = groups[g_idx]
		for m_idx in range(grp.size()):
			var unit: Dictionary = grp[m_idx]
			var delay: float
			if g_idx == 0 and m_idx == 0:
				delay = 0.0
			elif m_idx == 0:
				delay = table.group_pause
			else:
				delay = rng.randf_range(table.group_spawn_delay_min, table.group_spawn_delay_max)

			result.append({
				"id": unit.id,
				"scene": unit.scene,
				"is_ranged": unit.is_ranged,
				"group_index": g_idx,
				"delay": delay
			})

	return result


func _build_spawn_queue_for_wave(wave_num: int) -> void:
	spawn_queue.clear()
	_spawn_delays.clear()

	_wave_rng = RandomNumberGenerator.new()
	_wave_rng.seed = hash([run_seed, wave_num])

	var composition := generate_wave_composition(wave_num, run_seed)
	for item in composition:
		var scene := item.scene as PackedScene
		if scene != null:
			spawn_queue.append(scene)
			_spawn_delays.append(float(item.delay))


func _physics_process(delta: float) -> void:
	match wave_state:
		Enums.WaveState.PREP:
			pass

		Enums.WaveState.BOSS_INTRO:
			_intro_elapsed += delta
			_intro_timer -= delta
			if _intro_timer <= 0.0:
				start_combat()

		Enums.WaveState.COMBAT, Enums.WaveState.BOSS_COMBAT:
			if _first_enemy_spawned:
				_combat_timer += delta
			spawn_timer += delta
			if spawn_timer >= _next_spawn_delay and not spawn_queue.is_empty():
				var non_boss_count: int = enemies_alive - (1 if (_boss_instance != null and is_instance_valid(_boss_instance)) else 0)
				if non_boss_count < GameConfig.max_alive:
					_try_spawn_next_enemy()

		Enums.WaveState.SUMMARY:
			if auto_advance_summary:
				summary_timer -= delta
				if summary_timer <= 0.0:
					advance_from_summary()

		Enums.WaveState.REWARD_PICK:
			pass


func _is_position_occupied(pos: Vector3, min_dist: float = 1.0) -> bool:
	if not is_inside_tree():
		return false
	var enemies := get_tree().get_nodes_in_group(&"enemy")
	for e in enemies:
		var e3d := e as Node3D
		if e3d != null and is_instance_valid(e3d) and not e3d.is_queued_for_deletion():
			if "is_dead" in e3d and e3d.is_dead:
				continue
			var diff := e3d.global_position - pos
			diff.y = 0.0
			if diff.length() < min_dist:
				return true
	return false


## Position candidate rolled via RNG in spawn_zone.
## If occupied within overlap radius, retry; after timeout, force spawn at the last attempted position.
func _try_spawn_next_enemy() -> void:
	if spawn_queue.is_empty():
		return

	var rng: RandomNumberGenerator = _wave_rng if _wave_rng != null else RandomNumberGenerator.new()
	var offset_x: float = rng.randf_range(-spawn_zone_half_extents.x + 0.5, spawn_zone_half_extents.x - 0.5)
	var offset_z: float = rng.randf_range(-spawn_zone_half_extents.z + 0.5, spawn_zone_half_extents.z - 0.5)
	var candidate_pos: Vector3 = spawn_point + Vector3(offset_x, 0.0, offset_z)
	_last_candidate_pos = candidate_pos

	var overlap_r: float = wave_table.spawn_overlap_radius if wave_table != null else 1.0
	var retry_delay: float = wave_table.spawn_retry_delay if wave_table != null else 0.2
	var retry_timeout: float = wave_table.spawn_retry_timeout if wave_table != null else 3.0

	if _is_position_occupied(candidate_pos, overlap_r):
		if _retry_elapsed < retry_timeout:
			_retry_elapsed += retry_delay
			# Delay next attempt
			spawn_timer = maxf(0.0, _next_spawn_delay - retry_delay)
			return

	# Position accepted or forced after timeout
	_retry_elapsed = 0.0
	_spawn_enemy_at(candidate_pos)

	# Advance to next enemy's delay
	spawn_timer = 0.0
	if not _spawn_delays.is_empty():
		_next_spawn_delay = _spawn_delays.pop_front()
	else:
		_next_spawn_delay = wave_table.group_spawn_delay_min if wave_table != null else spawn_interval


func _spawn_enemy_at(spawn_pos: Vector3) -> void:
	if spawn_queue.is_empty():
		return

	var scene := spawn_queue.pop_front() as PackedScene
	if scene == null:
		return

	var enemy := scene.instantiate() as Enemy
	if enemy == null:
		return

	enemy.position = spawn_pos
	enemy.spawn_grace = true
	enemy.is_in_spawn_zone = true

	# Apply wave scale factors at spawn time. Immutable while alive.
	var cfg: ScaleConfig = scale_config if scale_config != null else ScaleConfig.new()
	var hp_mult: float = cfg.get_hp_mult(current_wave)
	var dmg_mult: float = cfg.get_dmg_mult(current_wave)
	var speed_mult: float = cfg.get_speed_mult(current_wave)
	enemy.apply_wave_scale(hp_mult, dmg_mult, speed_mult, current_wave, cfg)

	if enemy_container != null and is_instance_valid(enemy_container):
		enemy_container.add_child(enemy)
	else:
		add_child(enemy)

	_first_enemy_spawned = true
	enemies_alive += 1
	EventBus.enemy_spawned.emit(enemy)
	EventBus.enemy_count_changed.emit(enemies_alive, spawn_queue.size(), total_wave_enemies)


func _on_enemy_died(enemy_type: StringName, _pos: Vector3, gold_base: float, prestige: int, is_cull: bool, _hit_by_commander: bool = false) -> void:
	if not is_cull:
		var type_key := String(enemy_type)
		_kills_by_type[type_key] = _kills_by_type.get(type_key, 0) + 1
		_wave_gold_base += gold_base
		_wave_prestige += prestige

	if wave_state == Enums.WaveState.COMBAT or wave_state == Enums.WaveState.BOSS_COMBAT:
		enemies_alive = maxi(0, enemies_alive - 1)
		EventBus.enemy_count_changed.emit(enemies_alive, spawn_queue.size(), total_wave_enemies)
		if spawn_queue.is_empty() and enemies_alive == 0:
			_clear_time = _combat_timer
			_end_combat_to_summary()


func _end_combat_to_summary() -> void:
	var fort := get_tree().get_first_node_in_group(&"fortress")
	if fort != null and "health" in fort and fort.health != null and fort.health.hp <= 0:
		_is_run_lost = true

	var cmd := get_tree().get_first_node_in_group(&"commander")
	if cmd != null and "health" in cmd and cmd.health != null and cmd.health.hp <= 0:
		_is_run_lost = true

	if _is_run_lost:
		return

	var old_state := wave_state
	wave_state = Enums.WaveState.SUMMARY
	summary_timer = GameConfig.summary_auto_advance

	# Return to x1 on entering SUMMARY
	TimeManager.reset_time_scale()

	# Par time & Clear multiplier
	var cfg: ScaleConfig = scale_config if scale_config != null else ScaleConfig.new()
	var spawn_dur: float = cfg.get_spawn_duration(current_wave)
	var is_boss: bool = (current_wave % GameConfig.boss_wave_interval == 0)
	var boss_n: int = current_wave / GameConfig.boss_wave_interval
	var boss_time: float = GameConfig.get_boss_timer(boss_n)
	var par_time: float = GameConfig.get_par_time(spawn_dur, is_boss, boss_time)
	var clear_mult: float = GameConfig.get_clear_mult(_clear_time, par_time)

	var clear_tier: String = "NORMAL"
	if par_time > 0.0:
		if _clear_time <= GameConfig.clear_fast_threshold * par_time:
			clear_tier = "FAST"
		elif _clear_time > GameConfig.clear_slow_threshold * par_time:
			clear_tier = "SLOW"

	# Total gold gain
	var gold_pct_total: float = _gold_pct_total()
	var wave_gold_scaled: int = WaveRewardTable.floor_gold(_wave_gold_base * (1.0 + gold_pct_total) * clear_mult)
	# Boss gold - only granted if boss was defeated this wave
	var boss_gold_scaled: int = _boss_gold_amount() if _boss_defeated_this_wave else 0
	var total_gold_gain: int = wave_gold_scaled + boss_gold_scaled

	# Credit gold to GoldManager, false avoids double "+xx" popup on SUMMARY
	var gold_mgr := get_tree().get_first_node_in_group(&"gold_manager") as GoldManager
	if gold_mgr != null:
		gold_mgr.add(total_gold_gain, false)

	# Boss prestige is paid here, after the run-lost check above
	if _boss_defeated_this_wave:
		_wave_prestige += _boss_prestige_amount()

	# Pending prestige
	if _wave_prestige > 0:
		EventBus.prestige_pending_changed.emit(_wave_prestige)

	# Save progress
	if SaveManager != null and SaveManager.can_write:
		var run_flag: Dictionary = SaveManager.get_section(SaveManager.RUN_FLAG)
		run_flag["waves_cleared"] = current_wave
		SaveManager.save()

	var rs := _get_run_state()
	if rs != null:
		rs.waves_cleared = current_wave

	# Fortress HP
	var fortress_hp := 0
	var fortress_max_hp := 0
	if fort != null and "health" in fort and fort.health != null:
		fortress_hp = fort.health.hp
		fortress_max_hp = fort.health.max_hp

	# Ruined towers read from Slot instances (Slot.state == RUINED)
	var ruined_towers: Array = []
	for s in get_tree().get_nodes_in_group(&"slot"):
		var slot := s as Slot
		if slot != null and slot.state == Enums.SlotState.RUINED and slot.last_data != null:
			ruined_towers.append({
				"type": slot.last_data.id,
				"level": slot.last_level,
				"rebuild_cost": slot.get_rebuild_cost(),
			})

	# XP stats
	var xp_cmd: int = 0
	var xp_tow: int = 0
	var cmd_lv: int = 0
	var pend_picks: int = 0
	if _xp_tracker != null:
		xp_cmd = int(round(_xp_tracker.wave_xp_commander))
		xp_tow = int(round(_xp_tracker.wave_xp_towers))
		cmd_lv = _xp_tracker.commander_level
		pend_picks = _xp_tracker.pending_picks

	var summary: Dictionary = {
		"wave_index": current_wave,
		"clear_time": _clear_time,
		"clear_tier": clear_tier,
		"par_time": par_time,
		"kills_by_type": _kills_by_type.duplicate(),
		"gold_base": int(round(_wave_gold_base)),
		"gold_mult": clear_mult,
		"gold_total": total_gold_gain,
		"prestige_gain_wave": _wave_prestige,
		"fortress_hp": fortress_hp,
		"fortress_max_hp": fortress_max_hp,
		"ruined_towers": ruined_towers,
		"emg_repair_gained": 1 if _boss_defeated_this_wave else 0,
		"xp_from_commander": xp_cmd,
		"xp_from_towers": xp_tow,
		"commander_level": cmd_lv,
		"pending_picks": pend_picks,
	}

	EventBus.wave_summary_ready.emit(summary)
	wave_fsm_state_changed.emit(wave_state, old_state)
	EventBus.state_changed.emit(&"SUMMARY")
	EventBus.wave_cleared.emit(current_wave)


func advance_from_summary() -> void:
	if wave_state != Enums.WaveState.SUMMARY:
		return

	_cleanup_projectiles()

	if current_wave == GameConfig.victory_wave and not _victory_handled:
		_victory_handled = true
		EventBus.run_victory.emit(current_wave)
		# TODO(Ender-Via): pause with REASON_VICTORY once SCR-20 victory screen lands; currently disabled by default.
		if enable_victory_screen:
			_waiting_victory_continue = true
			TimeManager.request_pause(TimeManager.REASON_VICTORY)
			return

	_advance_past_summary_and_rewards()


func _on_victory_continue_requested() -> void:
	if not _waiting_victory_continue:
		return
	_waiting_victory_continue = false
	TimeManager.release_pause(TimeManager.REASON_VICTORY)
	_advance_past_summary_and_rewards()


func _advance_past_summary_and_rewards() -> void:
	var pending: int = _xp_tracker.pending_picks if _xp_tracker != null else 0
	if enable_reward_pick and pending > 0 and _has_reward_offer():
		start_reward_pick()
	else:
		advance_to_next_wave()


func _has_reward_offer() -> bool:
	var service := get_tree().get_first_node_in_group(&"reward_service")
	if service == null:
		return true
	if service.has_method(&"has_offer"):
		return service.has_offer()
	return true


func start_reward_pick() -> void:
	var old_state := wave_state
	wave_state = Enums.WaveState.REWARD_PICK
	TimeManager.request_pause(TimeManager.REASON_REWARD_PICK)
	wave_fsm_state_changed.emit(wave_state, old_state)
	EventBus.state_changed.emit(&"REWARD_PICK")


func finish_reward_pick() -> void:
	if wave_state != Enums.WaveState.REWARD_PICK:
		return
	TimeManager.release_pause(TimeManager.REASON_REWARD_PICK)
	advance_to_next_wave()


func _on_reward_picked(_card_id: StringName, _slot_kind: StringName, _new_level: int) -> void:
	if wave_state != Enums.WaveState.REWARD_PICK:
		return
	var pending: int = _xp_tracker.pending_picks if _xp_tracker != null else 0
	if pending <= 0:
		finish_reward_pick()


func _cleanup_projectiles() -> void:
	var pool := get_tree().get_first_node_in_group(&"projectile_pool") as ProjectilePool
	if pool != null:
		pool.release_all()
	else:
		for p in get_tree().get_nodes_in_group(&"projectile"):
			if is_instance_valid(p) and p.has_method("release"):
				p.release()


func _spawn_boss() -> void:
	if bulwark_scene == null:
		return
	var boss_inst := bulwark_scene.instantiate() as Enemy
	if boss_inst == null:
		return

	var boss_sp := get_tree().get_first_node_in_group(&"boss_spawn_point") as Node3D
	if boss_sp == null:
		var root := get_tree().current_scene
		if root != null:
			boss_sp = root.find_child("BossSpawnPoint", true, false) as Node3D
	var boss_pos: Vector3 = boss_sp.global_position if boss_sp != null else spawn_point
	boss_pos.y = 0.0

	boss_inst.position = boss_pos
	boss_inst.spawn_grace = true
	boss_inst.is_in_spawn_zone = true

	var cfg: ScaleConfig = scale_config if scale_config != null else ScaleConfig.new()
	var hp_mult: float = cfg.get_hp_mult(current_wave)
	var dmg_mult: float = cfg.get_dmg_mult(current_wave)
	var speed_mult: float = cfg.get_speed_mult(current_wave)
	boss_inst.apply_wave_scale(hp_mult, dmg_mult, speed_mult, current_wave, cfg)

	if enemy_container != null and is_instance_valid(enemy_container):
		enemy_container.add_child(boss_inst)
	else:
		add_child(boss_inst)

	_boss_instance = boss_inst
	_first_enemy_spawned = true
	enemies_alive += 1
	total_wave_enemies += 1
	EventBus.enemy_spawned.emit(boss_inst)
	EventBus.boss_spawned.emit()


func _on_summary_continue_requested() -> void:
	if wave_state == Enums.WaveState.SUMMARY:
		advance_from_summary()


func _on_run_lost() -> void:
	_is_run_lost = true


func advance_to_next_wave() -> void:
	current_wave += 1
	start_prep()


func _get_run_state() -> RunState:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"run_state") as RunState
