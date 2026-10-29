class_name XpTracker
extends Node

## Tracks Commander XP, leveling, pending skill picks, and commander-vs-tower XP contributions.
## SRS: 3.5.11 (XP-01..05, BOSS-42), W7-KT3.

var commander_level: int = 0
var xp: float = 0.0
var pending_picks: int = 0

## Cached XP values by enemy/boss id (dynamically populated from EnemyData/BossData)
var _xp_value_cache: Dictionary = {}

## Cumulative XP across the entire run
var total_xp_from_commander: float = 0.0
var total_xp_from_towers: float = 0.0

## Per-wave XP tracking for wave summary
var wave_xp_commander: float = 0.0
var wave_xp_towers: float = 0.0


func _init() -> void:
	_seed_xp_cache()


func _ready() -> void:
	add_to_group(&"xp_tracker")
	EventBus.enemy_spawned.connect(_on_enemy_spawned)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.run_started.connect(reset)
	EventBus.reward_picked.connect(_on_reward_picked)
	EventBus.wave_started.connect(_on_wave_started)
	# Emit initial state deferred so HUD gets it
	_emit_xp_changed.call_deferred()


func _exit_tree() -> void:
	if EventBus.enemy_spawned.is_connected(_on_enemy_spawned):
		EventBus.enemy_spawned.disconnect(_on_enemy_spawned)
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)
	if EventBus.run_started.is_connected(reset):
		EventBus.run_started.disconnect(reset)
	if EventBus.reward_picked.is_connected(_on_reward_picked):
		EventBus.reward_picked.disconnect(_on_reward_picked)
	if EventBus.wave_started.is_connected(_on_wave_started):
		EventBus.wave_started.disconnect(_on_wave_started)


func _seed_xp_cache() -> void:
	# Explicit map of known IDs to ensure no ID collision if a tres has default values
	var default_paths := {
		&"grunt": "res://data/enemies/grunt.tres",
		&"archer": "res://data/enemies/archer.tres",
		&"brute": "res://data/enemies/brute.tres",
		&"bulwark": "res://data/enemies/bulwark.tres",
	}
	for target_id in default_paths:
		var p: String = default_paths[target_id]
		if ResourceLoader.exists(p):
			var res = load(p)
			if res != null and "xp_value" in res:
				_xp_value_cache[target_id] = res.xp_value
	var boss_path := "res://data/bosses/bulwark_boss.tres"
	if ResourceLoader.exists(boss_path):
		var b_res = load(boss_path)
		if b_res != null and "id" in b_res and "xp_value" in b_res:
			_xp_value_cache[b_res.id] = b_res.xp_value


func _on_enemy_spawned(enemy: Node) -> void:
	if enemy != null and "data" in enemy and enemy.data != null:
		var edata = enemy.data
		if "id" in edata and "xp_value" in edata:
			_xp_value_cache[edata.id] = edata.xp_value


func reset() -> void:
	commander_level = 0
	xp = 0.0
	pending_picks = 0
	total_xp_from_commander = 0.0
	total_xp_from_towers = 0.0
	wave_xp_commander = 0.0
	wave_xp_towers = 0.0
	_emit_xp_changed()


func _on_wave_started(_wave_index: int) -> void:
	wave_xp_commander = 0.0
	wave_xp_towers = 0.0


func _on_reward_picked(_card_id: StringName, _slot_kind: StringName, _new_level: int) -> void:
	pending_picks = maxi(0, pending_picks - 1)
	_emit_xp_changed()


func get_xp_value_for_enemy(enemy_type: StringName) -> int:
	if _xp_value_cache.has(enemy_type):
		return int(_xp_value_cache[enemy_type])
	# Dynamic fallback if not yet spawned or cached
	var p := "res://data/enemies/%s.tres" % String(enemy_type)
	if ResourceLoader.exists(p):
		var res = load(p)
		if res != null and "id" in res and "xp_value" in res:
			_xp_value_cache[res.id] = res.xp_value
			return res.xp_value
	return 1


func _on_enemy_died(enemy_type: StringName, _pos: Vector3, _gold_base: int, _prestige: int, is_cull: bool, hit_by_commander: bool) -> void:
	# Cull kills grant 0 XP (RWD-03, XP-01)
	if is_cull:
		return

	var base_xp: int = get_xp_value_for_enemy(enemy_type)
	var mult: float = GameConfig.xp_commander_pct if hit_by_commander else GameConfig.xp_tower_only_pct
	var gained: float = float(base_xp) * mult

	if hit_by_commander:
		total_xp_from_commander += gained
		wave_xp_commander += gained
	else:
		total_xp_from_towers += gained
		wave_xp_towers += gained

	add_xp(gained)


func add_xp(amount: float) -> void:
	if amount <= 0.0:
		return
	xp += amount

	var to_next := float(GameConfig.get_xp_to_level(commander_level + 1))
	while xp >= to_next:
		xp -= to_next
		commander_level += 1
		pending_picks += 1
		EventBus.level_up.emit(commander_level, pending_picks)
		to_next = float(GameConfig.get_xp_to_level(commander_level + 1))

	_emit_xp_changed()


func _emit_xp_changed() -> void:
	var to_next := float(GameConfig.get_xp_to_level(commander_level + 1))
	EventBus.xp_changed.emit(xp, commander_level, to_next, pending_picks)
