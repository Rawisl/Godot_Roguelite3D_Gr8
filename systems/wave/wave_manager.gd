class_name WaveManager
extends Node

## Wave FSM (PREP - COMBAT - SUMMARY) and Spawner (SPN-01, SPN-02, SPN-03, SPN-04, SPN-05..08, EN-04).
## Supports queue-based spawning, spawn_zone placement, spawn_grace,
## deterministic wave composition generation by run_seed, group scheduling, and queue throttling.

signal wave_fsm_state_changed(new_state: Enums.WaveState, old_state: Enums.WaveState)

@export var run_seed: int = 0
@export var grunt_scene: PackedScene = preload("res://entities/enemy/grunt.tscn")
@export var archer_scene: PackedScene = preload("res://entities/enemy/archer.tscn")
@export var brute_scene: PackedScene = preload("res://entities/enemy/brute.tscn")
@export var scale_config: ScaleConfig = preload("res://data/config/scale_config.tres")
@export var wave_table: WaveTable = preload("res://data/waves/wave_table.tres")

@export var spawn_interval: float = 0.6
@export var default_wave_1_count: int = 8
@export var auto_advance_summary: bool = true

var current_wave: int = 1
var wave_state: Enums.WaveState = Enums.WaveState.PREP

var spawn_queue: Array[PackedScene] = []
var _spawn_delays: Array[float] = []
var _next_spawn_delay: float = 0.6

var enemies_alive: int = 0
var total_wave_enemies: int = 0

var prep_timer: float = 0.0
var spawn_timer: float = 0.0
var summary_timer: float = 0.0

var spawn_point: Vector3 = Vector3(14.0, 0.0, 0.0)
var spawn_zone_half_extents: Vector3 = Vector3(6.0, 2.0, 8.0)
var enemy_container: Node3D = null

var _wave_rng: RandomNumberGenerator = null
var _retry_elapsed: float = 0.0
var _last_candidate_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group(&"wave_manager")
	EventBus.early_call_requested.connect(_on_early_call_requested)
	EventBus.enemy_died.connect(_on_enemy_died)
	_setup_container.call_deferred()
	start_prep()


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
	prep_timer = GameConfig.prep_time_early if current_wave <= GameConfig.prep_early_until_wave else GameConfig.prep_time_late
	_build_spawn_queue_for_wave(current_wave)
	wave_fsm_state_changed.emit(wave_state, old_state)
	EventBus.state_changed.emit(&"PREP")
	EventBus.prep_timer_changed.emit(prep_timer)


func call_early() -> void:
	if wave_state == Enums.WaveState.PREP:
		var bonus_gold := mini(GameConfig.early_call_cap, int(floor(prep_timer * float(GameConfig.early_call_gold_per_sec))))
		if bonus_gold > 0:
			EventBus.gold_delta.emit(bonus_gold)
		start_combat()


func _on_early_call_requested() -> void:
	call_early()


func start_combat() -> void:
	var old_state := wave_state
	wave_state = Enums.WaveState.COMBAT
	wave_fsm_state_changed.emit(wave_state, old_state)
	EventBus.state_changed.emit(&"COMBAT")
	EventBus.wave_started.emit(current_wave)

	if spawn_queue.is_empty():
		_build_spawn_queue_for_wave(current_wave)
	total_wave_enemies = spawn_queue.size()
	enemies_alive = 0
	_retry_elapsed = 0.0
	spawn_timer = 0.0

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
		push_warning("WAVE-08: Wave %d has 0 enemies. Forced minimum 1 Grunt." % wave_num)
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
		push_warning("WAVE-08: Wave %d generated 0 enemies. Forced minimum 1 Grunt." % wave_num)
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
			prep_timer -= delta
			EventBus.prep_timer_changed.emit(maxf(0.0, prep_timer))
			if prep_timer <= 0.0:
				start_combat()

		Enums.WaveState.COMBAT:
			spawn_timer += delta
			if spawn_timer >= _next_spawn_delay and not spawn_queue.is_empty():
				# Queue holds surplus enemies while enemies_alive >= max_alive
				if enemies_alive < GameConfig.max_alive:
					_try_spawn_next_enemy()

		Enums.WaveState.SUMMARY:
			if auto_advance_summary:
				summary_timer -= delta
				if summary_timer <= 0.0:
					advance_to_next_wave()


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

	enemies_alive += 1
	EventBus.enemy_spawned.emit(enemy)
	EventBus.enemy_count_changed.emit(enemies_alive, spawn_queue.size(), total_wave_enemies)


func _on_enemy_died(_enemy_type: StringName, _pos: Vector3, _gold: int, _prestige: int, _is_cull: bool, _hit_by_commander: bool = false) -> void:
	if wave_state == Enums.WaveState.COMBAT:
		enemies_alive = maxi(0, enemies_alive - 1)
		EventBus.enemy_count_changed.emit(enemies_alive, spawn_queue.size(), total_wave_enemies)
		if spawn_queue.is_empty() and enemies_alive == 0:
			_end_combat_to_summary()


func _end_combat_to_summary() -> void:
	var old_state := wave_state
	wave_state = Enums.WaveState.SUMMARY
	summary_timer = GameConfig.summary_auto_advance
	wave_fsm_state_changed.emit(wave_state, old_state)
	EventBus.state_changed.emit(&"SUMMARY")
	EventBus.wave_cleared.emit(current_wave)


func advance_to_next_wave() -> void:
	current_wave += 1
	start_prep()
