class_name WaveManager
extends Node

## Minimal Wave FSM (PREP - COMBAT - SUMMARY) and Spawner (SPN-01, SPN-02, SPN-04, EN-04).
## Supports queue-based spawning, spawn_zone placement, spawn_grace,
## and wave state transitions according to SRS-EW-1.6 (Sections 3.3.1, 3.7.5).

signal wave_fsm_state_changed(new_state: Enums.WaveState, old_state: Enums.WaveState)

@export var grunt_scene: PackedScene = preload("res://entities/enemy/grunt.tscn")
@export var spawn_interval: float = 0.6
@export var default_wave_1_count: int = 8
@export var auto_advance_summary: bool = true

var current_wave: int = 1
var wave_state: Enums.WaveState = Enums.WaveState.PREP

var spawn_queue: Array[PackedScene] = []
var enemies_alive: int = 0
var total_wave_enemies: int = 0

var prep_timer: float = 0.0
var spawn_timer: float = 0.0
var summary_timer: float = 0.0

var spawn_point: Vector3 = Vector3(15.0, 0.0, 0.0)
var enemy_container: Node3D = null

func _ready() -> void:
	add_to_group("wave_manager")
	EventBus.early_call_requested.connect(_on_early_call_requested)
	EventBus.enemy_died.connect(_on_enemy_died)
	_setup_container.call_deferred()

func _setup_container() -> void:
	if enemy_container == null:
		var gameplay_enemy := get_tree().get_first_node_in_group("enemy_container") as Node3D
		if gameplay_enemy != null:
			enemy_container = gameplay_enemy
		else:
			var root := get_tree().current_scene
			if root != null:
				var candidate := root.find_child("Enemy", true, false) as Node3D
				if candidate != null:
					enemy_container = candidate

	var sz := get_tree().get_first_node_in_group("spawn_zone") as Area3D
	if sz == null:
		var root := get_tree().current_scene
		if root != null:
			sz = root.find_child("SpawnZone", true, false) as Area3D
	if sz != null:
		spawn_point = sz.global_position
		spawn_point.y = 0.0

func start_prep() -> void:
	var old_state := wave_state
	wave_state = Enums.WaveState.PREP
	prep_timer = GameConfig.prep_time_early if current_wave <= GameConfig.prep_early_until_wave else GameConfig.prep_time_late
	wave_fsm_state_changed.emit(wave_state, old_state)
	EventBus.state_changed.emit(&"PREP")
	EventBus.prep_timer_changed.emit(prep_timer)

func call_early() -> void:
	if wave_state == Enums.WaveState.PREP:
		start_combat()

func _on_early_call_requested() -> void:
	call_early()

func start_combat() -> void:
	var old_state := wave_state
	wave_state = Enums.WaveState.COMBAT
	wave_fsm_state_changed.emit(wave_state, old_state)
	EventBus.state_changed.emit(&"COMBAT")
	EventBus.wave_started.emit(current_wave)

	_build_spawn_queue_for_wave(current_wave)
	total_wave_enemies = spawn_queue.size()
	enemies_alive = 0
	spawn_timer = spawn_interval

	EventBus.enemy_count_changed.emit(enemies_alive, spawn_queue.size(), total_wave_enemies)

func _build_spawn_queue_for_wave(wave_num: int) -> void:
	spawn_queue.clear()
	var count := default_wave_1_count if wave_num == 1 else default_wave_1_count + (wave_num - 1) * 2
	for i in range(count):
		spawn_queue.append(grunt_scene)

func _physics_process(delta: float) -> void:
	match wave_state:
		Enums.WaveState.PREP:
			prep_timer -= delta
			EventBus.prep_timer_changed.emit(maxf(0.0, prep_timer))
			if prep_timer <= 0.0:
				start_combat()

		Enums.WaveState.COMBAT:
			spawn_timer += delta
			if spawn_timer >= spawn_interval and not spawn_queue.is_empty():
				if enemies_alive < GameConfig.max_alive:
					spawn_timer = 0.0
					_spawn_next_enemy()

		Enums.WaveState.SUMMARY:
			if auto_advance_summary:
				summary_timer -= delta
				if summary_timer <= 0.0:
					advance_to_next_wave()

func _spawn_next_enemy() -> void:
	if spawn_queue.is_empty():
		return

	var scene := spawn_queue.pop_front() as PackedScene
	if scene == null:
		return

	var enemy := scene.instantiate() as Enemy
	if enemy == null:
		return

	var spawn_pos := spawn_point + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-4.0, 4.0))
	enemy.position = spawn_pos
	enemy.spawn_grace = true
	enemy.is_in_spawn_zone = true

	if enemy_container != null and is_instance_valid(enemy_container):
		enemy_container.add_child(enemy)
	else:
		add_child(enemy)

	enemies_alive += 1
	EventBus.enemy_spawned.emit(enemy)
	EventBus.enemy_count_changed.emit(enemies_alive, spawn_queue.size(), total_wave_enemies)

func _on_enemy_died(_enemy_type: StringName, _pos: Vector3, _gold: int, _prestige: int, _is_cull: bool) -> void:
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
