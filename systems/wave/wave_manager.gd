class_name WaveManager
extends Node

## Wave FSM (PREP - COMBAT - SUMMARY) and Spawner.
## Supports queue-based spawning, spawn_zone placement, spawn_grace, group scheduling and queue
## throttling. Waves 1 to victory_wave take their units and scale from the WaveScript, the same for
## every run; later waves draw their units from the WaveTable with an RNG of the run seed and scale
## by the ScaleConfig. Every schedule is stretched so the last unit spawns no sooner than the
## wave's spawn duration.
# TODO(Ender-Via): when the spawner reads the WaveScript, spawn the boss its boss row names (bulwark on waves 5, 15, 25, skeletal_centipede on 10, 20, 30) with that boss's scene and BossData instead of always the Bulwark, and use the same id for the boss intro and get_wave_plan().

signal wave_fsm_state_changed(new_state: Enums.WaveState, old_state: Enums.WaveState)

## The run seed of RunState, so the waves of a run follow its seed. The export is only used
## when there is no RunState (test scenes).
@export var run_seed: int = 0:
	get:
		var rs := _get_run_state()
		return rs.run_seed if rs != null else _fallback_run_seed
	set(value):
		_fallback_run_seed = value
		var rs := _get_run_state()
		if rs != null:
			rs.run_seed = value
var _fallback_run_seed: int = 0
## Every unit type the spawner can send, by EnemyData id. The boss is spawned on its own.
@export var enemy_scenes: Dictionary[StringName, PackedScene] = {
	&"grunt": preload("res://entities/enemy/grunt.tscn"),
	&"archer": preload("res://entities/enemy/archer.tscn"),
	&"brute": preload("res://entities/enemy/brute.tscn"),
	&"sniper": preload("res://entities/enemy/sniper.tscn"),
	&"rider": preload("res://entities/enemy/rider.tscn"),
	&"assassin": preload("res://entities/enemy/assassin.tscn"),
	&"suicide_squad": preload("res://entities/enemy/suicide_squad.tscn"),
	&"captain": preload("res://entities/enemy/captain.tscn"),
	&"knight": preload("res://entities/enemy/knight.tscn"),
	&"undead": preload("res://entities/enemy/undead.tscn"),
}
@export var bulwark_scene: PackedScene = preload("res://entities/enemy/bulwark.tscn")
@export var boss_data: BossData = preload("res://data/bosses/bulwark_boss.tres")
@export var scale_config: ScaleConfig = preload("res://data/config/scale_config.tres")
@export var wave_table: WaveTable = preload("res://data/waves/wave_table.tres")
## Units, spawn duration and scale of waves 1 to victory_wave.
@export var wave_script: WaveScript = preload("res://data/waves/wave_script.tres")

const FALLBACK_ENEMY_ID := &"grunt"

@export var spawn_interval: float = 0.6
@export var default_wave_1_count: int = 8
@export var auto_advance_summary: bool = true
@export var enable_reward_pick: bool = true
@export var enable_victory_screen: bool = true

var _intro_timer: float = 0.0
var _intro_elapsed: float = 0.0
var _victory_handled: bool = false
var _waiting_victory_continue: bool = false
var _wave_clear_pending: bool = false

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
var _fallback_prestige_pending: int = 0
var _prestige_pending: int:
	get:
		var rs := _get_run_state()
		return rs.prestige_pending if rs != null else _fallback_prestige_pending
	set(value):
		_fallback_prestige_pending = value
		var rs := _get_run_state()
		if rs != null:
			rs.prestige_pending = value
var _kills_by_type: Dictionary = {}
## Enemy id -> count of the spawn queue built for the coming wave.
var _queue_plan: Dictionary = {}
## EnemyData by id for types the WaveTable does not list.
var _enemy_data_cache: Dictionary = {}

const XP_TRACKER_SCRIPT := preload("res://systems/xp/xp_tracker.gd")
const BOSS_TIMER_SCRIPT := preload("res://systems/wave/boss_timer.gd")

# Clear time tracking
var _combat_timer: float = 0.0
var _clear_time: float = 0.0
var _first_enemy_spawned: bool = false
## Game seconds since the wave's last enemy spawned. Negative while enemies are still queued.
var _since_last_spawn: float = -1.0
var _stragglers_marked: bool = false
var _frenzy_sent: bool = false
var _hard_cap_reached: bool = false
var _is_run_lost: bool = false
var _boss_defeated_this_wave: bool = false
var _boss_enraged_this_wave: bool = false
var _boss_instance: Enemy = null

var _xp_tracker: Node = null
## The Hazard Trial of each PREP: picks the group, runs the room and pays it out.
var hazard_trial: HazardTrial = null
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
	_setup_hazard_trial()
	EventBus.reward_picked.connect(_on_reward_picked)
	EventBus.victory_continue_requested.connect(_on_victory_continue_requested)
	_setup_container.call_deferred()
	start_prep()
	# The HUD is not ready yet on the first PREP; tell it again once it is.
	_send_wave_preview.call_deferred()


func _exit_tree() -> void:
	if _waiting_victory_continue:
		TimeManager.release_pause(TimeManager.REASON_VICTORY)
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
	# A boss in the Hazard Trial room is not the wave's boss: no flag, no number, no summary reward.
	if wave_state == Enums.WaveState.HAZARD_TRIAL:
		return
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


## Gold bonus percent applied to wave gold and boss gold: the meta shop upgrade of this run.
func _gold_pct_total() -> float:
	var rs := _get_run_state()
	return rs.gold_pct_meta if rs != null else 0.0


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


func _setup_hazard_trial() -> void:
	hazard_trial = HazardTrial.new()
	hazard_trial.name = "HazardTrial"
	hazard_trial.wave_manager = self
	add_child(hazard_trial)


func get_xp_tracker() -> Node:
	return _xp_tracker


## PREP to HAZARD_TRIAL for the room. Nothing of the wave is reset: the same PREP goes on after.
func enter_hazard_state() -> void:
	var old_state := wave_state
	wave_state = Enums.WaveState.HAZARD_TRIAL
	wave_fsm_state_changed.emit(wave_state, old_state)
	EventBus.state_changed.emit(&"HAZARD_TRIAL")


## Back to the same PREP after the room, without anything a new PREP does again (spawn queue,
## per-wave tallies, the room being used, the group offer).
func leave_hazard_state() -> void:
	if wave_state != Enums.WaveState.HAZARD_TRIAL:
		return
	var old_state := wave_state
	wave_state = Enums.WaveState.PREP
	wave_fsm_state_changed.emit(wave_state, old_state)
	EventBus.state_changed.emit(&"PREP")


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


func get_enemy_scene(enemy_id: StringName) -> PackedScene:
	return enemy_scenes.get(enemy_id) as PackedScene


## The EnemyData of a unit type: from the WaveTable when it lists the type, else from data/enemies.
func get_enemy_data(enemy_id: StringName) -> EnemyData:
	if wave_table != null:
		for g in wave_table.groups:
			if g != null and g.enemy != null and g.enemy.id == enemy_id:
				return g.enemy
	if _enemy_data_cache.has(enemy_id):
		return _enemy_data_cache[enemy_id]
	var path := "res://data/enemies/%s.tres" % enemy_id
	var data: EnemyData = load(path) as EnemyData if ResourceLoader.exists(path) else null
	_enemy_data_cache[enemy_id] = data
	return data


## Waves 1 to victory_wave follow the WaveScript; later waves are generated.
func is_scripted_wave(wave_num: int) -> bool:
	return wave_script != null and wave_num >= 1 and wave_num <= GameConfig.victory_wave


## The wave's spawn duration in game seconds: the WaveScript for scripted waves (the ScaleConfig
## formula with a warning when the script lacks it), the ScaleConfig from victory_wave + 1.
func get_spawn_duration(wave_num: int) -> float:
	if is_scripted_wave(wave_num):
		if wave_script.has_spawn_duration(wave_num):
			return wave_script.get_spawn_duration(wave_num)
		push_warning("WaveScript has no spawn duration for wave %d; using the ScaleConfig formula." % wave_num)
	return _scale_config().get_spawn_duration(wave_num)


## hp, dmg and speed multipliers of a wave as (x, y, z): the WaveScript for scripted waves (the
## ScaleConfig formula with a warning when the script lacks them), the ScaleConfig after.
func get_wave_mults(wave_num: int) -> Vector3:
	if is_scripted_wave(wave_num):
		if wave_script.has_mults(wave_num):
			return Vector3(wave_script.get_hp_mult(wave_num), wave_script.get_dmg_mult(wave_num), wave_script.get_speed_mult(wave_num))
		push_warning("WaveScript has no multipliers for wave %d; using the ScaleConfig formula." % wave_num)
	var cfg := _scale_config()
	return Vector3(cfg.get_hp_mult(wave_num), cfg.get_dmg_mult(wave_num), cfg.get_speed_mult(wave_num))


## Applies the scale of a wave to a unit about to spawn. Immutable while it lives.
func apply_wave_scale_to(enemy: Enemy, wave_num: int) -> void:
	var mults := get_wave_mults(wave_num)
	enemy.apply_wave_scale(mults.x, mults.y, mults.z, wave_num, _scale_config())


func _scale_config() -> ScaleConfig:
	return scale_config if scale_config != null else ScaleConfig.new()


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
	# Before PREP is announced, so the PREP alerts already know whether a boss is coming.
	_send_wave_preview()
	EventBus.state_changed.emit(&"PREP")
	if hazard_trial != null:
		# Deferred: on the first PREP the HUD gate is not ready yet when the wave manager is.
		hazard_trial.offer.call_deferred(current_wave)


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
	_reset_straggler_clock()

	if is_boss:
		_spawn_boss()

	if not _spawn_delays.is_empty():
		_next_spawn_delay = _spawn_delays.pop_front()
	else:
		_next_spawn_delay = wave_table.group_spawn_delay_min if wave_table != null else spawn_interval

	EventBus.enemy_count_changed.emit(enemies_alive, spawn_queue.size(), total_wave_enemies)


## The wave's spawn schedule: one entry per unit ({id, scene, is_ranged, group_index, delay}),
## delay being the game seconds after the previous spawn. Waves 1 to victory_wave take their units
## from the WaveScript and do not depend on the run seed; later waves are drawn with an RNG of the
## run seed and the wave. The boss is not in the list: it spawns on its own at second 0.
func generate_wave_composition(wave_num: int, p_run_seed: int = 0) -> Array[Dictionary]:
	var units: Array[Dictionary] = []
	if is_scripted_wave(wave_num):
		units = _scripted_units(wave_num)
	else:
		units = _generated_units(wave_num, p_run_seed)
	if units.is_empty():
		push_warning("Wave %d has 0 enemies. Forced minimum 1 Grunt." % wave_num)
		var fallback := _unit_entry(FALLBACK_ENEMY_ID)
		if not fallback.is_empty():
			units.append(fallback)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([p_run_seed, wave_num, "schedule"])
	return _schedule_units(units, wave_num, rng)


## {id, scene, is_ranged} of a unit type, or {} when the spawner has no scene for it.
func _unit_entry(enemy_id: StringName) -> Dictionary:
	var scene := get_enemy_scene(enemy_id)
	if scene == null:
		return {}
	var data := get_enemy_data(enemy_id)
	return {"id": enemy_id, "scene": scene, "is_ranged": data != null and data.is_ranged}


func _boss_id() -> StringName:
	return boss_data.id if boss_data != null else &"bulwark"


## The units the WaveScript lists for a wave, escorts included and the boss left out. A type the
## spawner cannot send is skipped with an error.
func _scripted_units(wave_num: int) -> Array[Dictionary]:
	var units: Array[Dictionary] = []
	var entries := wave_script.get_wave(wave_num)
	if entries.is_empty():
		push_error("WaveScript has no units for wave %d." % wave_num)
		return units
	for entry in entries:
		var id: StringName = entry.get("enemy_type", &"")
		if id == _boss_id():
			continue
		var unit := _unit_entry(id)
		if unit.is_empty():
			push_error("WaveScript wave %d lists '%s', which the spawner has no scene for." % [wave_num, id])
			continue
		for i in range(int(entry.get("count", 0))):
			units.append(unit)
	return units


## Units of a generated wave: the budget of the ScaleConfig (escort_budget_ratio of it on a boss
## wave), a set of at most wave_max_enemy_types types (the boss counts as one) drawn by weight, the
## intro counts of types new on this wave first, then units drawn by weight within the set.
func _generated_units(wave_num: int, p_run_seed: int) -> Array[Dictionary]:
	var units: Array[Dictionary] = []
	if wave_num <= 0:
		return units
	var table: WaveTable = wave_table if wave_table != null else WaveTable.new()
	var budget: int = _scale_config().get_budget(wave_num)
	var is_boss: bool = is_boss_wave(wave_num)
	if is_boss:
		budget = maxi(1, int(floor(float(budget) * table.escort_budget_ratio)))

	var rng := RandomNumberGenerator.new()
	rng.seed = hash([p_run_seed, wave_num])

	var eligible: Array[WaveGroup] = []
	for g in table.groups:
		if g == null or g.enemy == null or get_enemy_scene(g.enemy.id) == null:
			continue
		if wave_num < g.min_wave:
			continue
		# Waves 1 and 2 only have Grunts.
		if wave_num <= 2 and g.enemy.id != FALLBACK_ENEMY_ID:
			continue
		eligible.append(g)
	if eligible.is_empty():
		return units

	# The type set: types new on this wave first, then drawn by weight without repeats.
	var max_types: int = maxi(1, GameConfig.wave_max_enemy_types - (1 if is_boss else 0))
	var type_set: Array[WaveGroup] = []
	for g in eligible:
		if _is_intro_wave(g, wave_num) and type_set.size() < max_types:
			type_set.append(g)
	var pool: Array[WaveGroup] = []
	for g in eligible:
		if not type_set.has(g):
			pool.append(g)
	while type_set.size() < max_types and not pool.is_empty():
		var picked := _pick_by_weight(pool, rng)
		type_set.append(picked)
		pool.erase(picked)

	var counts: Dictionary = {}  # id -> count
	for g in type_set:
		if not _is_intro_wave(g, wave_num):
			continue
		for i in range(g.intro_count):
			if budget < g.enemy.spawn_cost:
				break
			budget -= g.enemy.spawn_cost
			counts[g.enemy.id] = int(counts.get(g.enemy.id, 0)) + 1
			units.append(_unit_entry(g.enemy.id))

	while true:
		var candidates: Array[WaveGroup] = []
		for g in type_set:
			var id: StringName = g.enemy.id
			# On its intro wave a new type keeps exactly its intro count.
			if _is_intro_wave(g, wave_num):
				continue
			if g.enemy.spawn_cost > budget:
				continue
			if int(counts.get(id, 0)) >= g.get_max_allowed(wave_num):
				continue
			if id == &"archer":
				var projected_ratio: float = float(int(counts.get(id, 0)) + 1) / float(units.size() + 1)
				if projected_ratio > table.archer_max_ratio:
					continue
			candidates.append(g)
		if candidates.is_empty():
			break
		var selected := _pick_by_weight(candidates, rng)
		budget -= selected.enemy.spawn_cost
		counts[selected.enemy.id] = int(counts.get(selected.enemy.id, 0)) + 1
		units.append(_unit_entry(selected.enemy.id))
	return units


func _is_intro_wave(g: WaveGroup, wave_num: int) -> bool:
	return g.intro_count > 0 and g.min_wave == wave_num


func _pick_by_weight(groups: Array[WaveGroup], rng: RandomNumberGenerator) -> WaveGroup:
	var total_weight: float = 0.0
	for g in groups:
		total_weight += maxf(g.weight, 0.0)
	var roll: float = rng.randf_range(0.0, total_weight)
	var accum: float = 0.0
	for g in groups:
		accum += maxf(g.weight, 0.0)
		if roll <= accum:
			return g
	return groups[groups.size() - 1]


## Splits the units into clamp(2 + floor(w/5), 2, 6) groups, melee before ranged in each group,
## 0.4-0.8 s between units and group_pause between groups. When the last unit would spawn before
## the wave's spawn duration, the pauses between groups grow evenly so it spawns right at it; a
## single group moves only its last unit. A longer schedule is kept.
func _schedule_units(units: Array[Dictionary], wave_num: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if units.is_empty():
		return result
	var table: WaveTable = wave_table if wave_table != null else WaveTable.new()
	var group_count: int = clampi(2 + int(floor(float(maxi(wave_num, 0)) / 5.0)), 2, 6)
	group_count = mini(group_count, units.size())

	var groups: Array[Array] = []
	for g in range(group_count):
		groups.append([])
	var melee_index := 0
	var ranged_index := 0
	for unit in units:
		if not unit.is_ranged:
			groups[melee_index % group_count].append(unit)
			melee_index += 1
	for unit in units:
		if unit.is_ranged:
			groups[ranged_index % group_count].append(unit)
			ranged_index += 1

	var total: float = 0.0
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
			total += delay
			result.append({
				"id": unit.id,
				"scene": unit.scene,
				"is_ranged": unit.is_ranged,
				"group_index": g_idx,
				"delay": delay
			})

	var missing: float = get_spawn_duration(wave_num) - total
	if missing > 0.0:
		if group_count > 1:
			var extra: float = missing / float(group_count - 1)
			for i in range(1, result.size()):
				if result[i].group_index != result[i - 1].group_index:
					result[i].delay += extra
		else:
			result[result.size() - 1].delay += missing
	return result


func _build_spawn_queue_for_wave(wave_num: int) -> void:
	spawn_queue.clear()
	_spawn_delays.clear()

	_wave_rng = RandomNumberGenerator.new()
	_wave_rng.seed = hash([run_seed, wave_num])

	var composition := generate_wave_composition(wave_num, run_seed)
	_queue_plan.clear()
	for item in composition:
		var scene := item.scene as PackedScene
		if scene != null:
			spawn_queue.append(scene)
			_spawn_delays.append(float(item.delay))
			var id: StringName = item.get("id", &"")
			_queue_plan[id] = int(_queue_plan.get(id, 0)) + 1


func _send_wave_preview() -> void:
	EventBus.wave_preview_ready.emit(current_wave, get_wave_plan(), is_boss_wave(current_wave))


## What the wave brings, by enemy id: the queue just built, plus the boss on a boss wave. The
## preview shows exactly what will spawn.
func get_wave_plan() -> Dictionary:
	var plan := {}
	if is_boss_wave(current_wave):
		plan[_boss_id()] = 1
	plan.merge(_queue_plan)
	return plan


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
			_update_straggler_clock(delta)

		Enums.WaveState.SUMMARY:
			if auto_advance_summary:
				summary_timer -= delta
				if summary_timer <= 0.0:
					advance_from_summary()

		Enums.WaveState.REWARD_PICK:
			pass


func _reset_straggler_clock() -> void:
	_since_last_spawn = -1.0
	_stragglers_marked = false
	_frenzy_sent = false
	_hard_cap_reached = false


## Once the last enemy of the wave has spawned: a marker on the stragglers, then FRENZY, then the
## hard cap, which removes every unit left that is not a boss so the wave always ends. The clock
## runs from the last spawn and is not reset when a unit is sent back to the spawn zone.
func _update_straggler_clock(delta: float) -> void:
	if not _first_enemy_spawned or not spawn_queue.is_empty():
		return
	_since_last_spawn = maxf(_since_last_spawn, 0.0) + delta
	if not _stragglers_marked and _since_last_spawn >= GameConfig.straggler_marker_time:
		_stragglers_marked = true
		for enemy in _wave_enemies():
			enemy.mark_straggler()
	if not _frenzy_sent and _since_last_spawn >= GameConfig.frenzy_time:
		_frenzy_sent = true
		for enemy in _wave_enemies():
			enemy.enter_frenzy()
	if not _hard_cap_reached and _since_last_spawn >= GameConfig.wave_hard_cap:
		_hard_cap_reached = true
		for enemy in _wave_enemies():
			enemy.cull(&"HARD_CAP")


## Living units of the wave, the boss included; each unit decides what applies to it.
func _wave_enemies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Enemy
		if enemy != null and is_instance_valid(enemy) and not enemy.is_dead:
			result.append(enemy)
	return result


## A random point in the spawn zone, for a unit sent back to walk the lane again.
func random_spawn_zone_point() -> Vector3:
	var rng: RandomNumberGenerator = _wave_rng if _wave_rng != null else RandomNumberGenerator.new()
	var offset_x: float = rng.randf_range(-spawn_zone_half_extents.x + 0.5, spawn_zone_half_extents.x - 0.5)
	var offset_z: float = rng.randf_range(-spawn_zone_half_extents.z + 0.5, spawn_zone_half_extents.z - 0.5)
	return spawn_point + Vector3(offset_x, 0.0, offset_z)


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
	apply_wave_scale_to(enemy, current_wave)

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
		if spawn_queue.is_empty() and enemies_alive == 0 and not _wave_clear_pending:
			_clear_time = _combat_timer
			# A lethal hit in the same frame invalidates the clear and its rewards.
			_wave_clear_pending = true
			_finish_wave_clear.call_deferred(current_wave)


func _finish_wave_clear(wave: int) -> void:
	_wave_clear_pending = false
	if current_wave != wave or _is_run_lost or not spawn_queue.is_empty() or enemies_alive != 0:
		return
	if wave_state == Enums.WaveState.COMBAT or wave_state == Enums.WaveState.BOSS_COMBAT:
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
	var spawn_dur: float = get_spawn_duration(current_wave)
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

	# Clearing the wave pays prestige too; the wave's part moves into the run total
	var wave_prestige_total: int = _wave_prestige + PrestigeCalc.wave_clear_prestige(current_wave)
	_prestige_pending += wave_prestige_total
	_wave_prestige = 0
	EventBus.prestige_pending_changed.emit(_prestige_pending)

	var rs := _get_run_state()
	if rs != null:
		rs.waves_cleared = current_wave
		if current_wave == GameConfig.victory_wave:
			rs.victory_reached = true
	var weapon_gained: StringName = _grant_boss_weapon(rs)

	# Save progress before the summary shows; a failed write does not hold the summary back
	var start_wave: int = rs.start_wave if rs != null else 1
	var start_mult: float = rs.start_mult if rs != null else 1.0
	SaveManager.record_wave_summary(current_wave, _prestige_pending, start_wave, start_mult)

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
		"prestige_gain_wave": wave_prestige_total,
		"fortress_hp": fortress_hp,
		"fortress_max_hp": fortress_max_hp,
		"ruined_towers": ruined_towers,
		"emg_repair_gained": 1 if _boss_defeated_this_wave else 0,
		"weapon_gained": weapon_gained,
		"xp_from_commander": xp_cmd,
		"xp_from_towers": xp_tow,
		"commander_level": cmd_lv,
		"pending_picks": pend_picks,
	}

	wave_fsm_state_changed.emit(wave_state, old_state)
	EventBus.state_changed.emit(&"SUMMARY")
	# After the state change, so a panel that clears its data on entering SUMMARY keeps this summary.
	EventBus.wave_summary_ready.emit(summary)
	EventBus.wave_cleared.emit(current_wave)


## The boss weapon of this wave, granted to the run; &"" when nothing drops.
func _grant_boss_weapon(rs: RunState) -> StringName:
	if rs == null:
		return &""
	if not _boss_defeated_this_wave:
		return &""
	if not GameConfig.weapon_drop_waves.has(current_wave):
		return &""
	var id := WeaponDrop.pick(rs.run_seed, current_wave, rs.owned_weapons, GameConfig.boss_drop_weapons)
	if not rs.grant_weapon(id):
		return &""
	return id


func advance_from_summary() -> void:
	if wave_state != Enums.WaveState.SUMMARY or _waiting_victory_continue or _is_run_lost:
		return

	_cleanup_projectiles()

	var rs := _get_run_state()
	if current_wave == GameConfig.victory_wave and not _victory_handled and (rs == null or rs.victory_reached):
		_victory_handled = true
		if enable_victory_screen:
			_waiting_victory_continue = true
			TimeManager.request_pause(TimeManager.REASON_VICTORY)
		EventBus.run_victory.emit(current_wave, GameState.run_snapshot())
		if enable_victory_screen:
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

	apply_wave_scale_to(boss_inst, current_wave)

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
