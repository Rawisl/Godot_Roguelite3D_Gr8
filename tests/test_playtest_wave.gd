extends Node3D

## Interactive Wave Playtest scene (F6 to run).
## Allows inputting any wave number and run_seed to test wave composition,
## group scheduling, timing, and enemy behaviors in the corridor arena.

const GRUNT_DATA: EnemyData = preload("res://data/enemies/grunt.tres")
const ARCHER_DATA: EnemyData = preload("res://data/enemies/archer.tres")
const BRUTE_DATA: EnemyData = preload("res://data/enemies/brute.tres")

@onready var level: Node3D = %Level
@onready var wave_manager: WaveManager = %WaveManager
@onready var enemy_container: Node3D = %Enemy

@onready var wave_spin: SpinBox = %WaveSpin
@onready var seed_spin: SpinBox = %SeedSpin
@onready var start_btn: Button = %StartBtn
@onready var prep_btn: Button = %PrepBtn
@onready var call_btn: Button = %CallBtn
@onready var kill_all_btn: Button = %KillAllBtn
@onready var auto_next_check: CheckBox = %AutoNextCheck

@onready var speed_1_btn: Button = %Speed1Btn
@onready var speed_2_btn: Button = %Speed2Btn
@onready var speed_3_btn: Button = %Speed3Btn

@onready var status_label: Label = %StatusLabel
@onready var composition_label: Label = %CompositionLabel
@onready var schedule_label: Label = %ScheduleLabel

var _overhead_labels: Dictionary = {}  # Enemy -> Label3D
var _current_preview_wave: int = -1
var _current_preview_seed: int = -1


func _ready() -> void:
	# Connect UI controls
	start_btn.pressed.connect(_on_start_pressed)
	prep_btn.pressed.connect(_on_prep_pressed)
	call_btn.pressed.connect(_on_call_early_pressed)
	kill_all_btn.pressed.connect(kill_all_enemies)

	wave_spin.value_changed.connect(func(_v): _update_preview())
	seed_spin.value_changed.connect(func(_v): _update_preview())
	auto_next_check.toggled.connect(func(toggled): wave_manager.auto_advance_summary = toggled)

	speed_1_btn.pressed.connect(func(): Engine.time_scale = 1.0)
	speed_2_btn.pressed.connect(func(): Engine.time_scale = 2.0)
	speed_3_btn.pressed.connect(func(): Engine.time_scale = 3.0)

	EventBus.enemy_spawned.connect(_on_enemy_spawned)
	EventBus.wave_fsm_state_changed.connect(_on_wave_state_changed) if EventBus.has_signal(&"wave_fsm_state_changed") else null

	# Initial setup
	wave_manager.auto_advance_summary = auto_next_check.button_pressed
	_update_preview()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				_on_start_pressed()
			KEY_G:
				_on_call_early_pressed()
			KEY_K:
				kill_all_enemies()
			KEY_1:
				Engine.time_scale = 1.0
			KEY_2:
				Engine.time_scale = 2.0
			KEY_3:
				Engine.time_scale = 3.0
			KEY_SPACE:
				Engine.time_scale = 0.0 if Engine.time_scale > 0.0 else 1.0


func _process(_delta: float) -> void:
	_update_status_display()
	_update_overhead_labels()


func _on_start_pressed() -> void:
	var target_wave := int(wave_spin.value)
	var target_seed := int(seed_spin.value)

	kill_all_enemies()

	wave_manager.current_wave = target_wave
	wave_manager.run_seed = target_seed
	wave_manager.start_combat()
	_update_preview()


func _on_prep_pressed() -> void:
	var target_wave := int(wave_spin.value)
	var target_seed := int(seed_spin.value)

	kill_all_enemies()

	wave_manager.current_wave = target_wave
	wave_manager.run_seed = target_seed
	wave_manager.start_prep()
	_update_preview()


func _on_call_early_pressed() -> void:
	if wave_manager.wave_state == Enums.WaveState.PREP:
		wave_manager.call_early()


func kill_all_enemies() -> void:
	var enemies := get_tree().get_nodes_in_group(&"enemy")
	for e in enemies:
		var enemy := e as Enemy
		if enemy != null and is_instance_valid(enemy) and not enemy.is_dead:
			enemy.spawn_grace = false
			enemy.take_damage(DamageInfo.new(9999, Enums.DamageType.TRUE))


func _on_enemy_spawned(node: Node) -> void:
	var enemy := node as Enemy
	if enemy == null:
		return

	var label := Label3D.new()
	var height: float = 2.6 if (enemy.data != null and enemy.data.id == &"brute") else 2.0
	label.position = Vector3(0.0, height, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 32
	label.outline_size = 6
	label.pixel_size = 0.012

	if enemy.data != null:
		match enemy.data.id:
			&"grunt": label.modulate = Color(1.0, 1.0, 1.0)
			&"archer": label.modulate = Color(0.3, 1.0, 0.4)
			&"brute": label.modulate = Color(1.0, 0.4, 0.2)
			_: label.modulate = Color(1.0, 0.9, 0.4)

	enemy.add_child(label)
	_overhead_labels[enemy] = label

	enemy.tree_exiting.connect(func():
		_overhead_labels.erase(enemy)
	)


func _update_overhead_labels() -> void:
	var to_remove: Array[Enemy] = []
	for e in _overhead_labels.keys():
		var enemy: Enemy = e
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			to_remove.append(enemy)
			continue

		var lbl: Label3D = _overhead_labels[enemy]
		if is_instance_valid(lbl):
			var state_name: String = Enums.EnemyState.keys()[enemy.current_state]
			var enemy_id: String = String(enemy.data.id) if enemy.data != null else "Enemy"
			var hp_text := "%d/%d" % [enemy.health.hp, enemy.health.max_hp] if enemy.health != null else ""
			var dmg_val: int = enemy.scaled_damage if enemy.scaled_damage > 0 else (enemy.data.base_damage if enemy.data else 0)
			lbl.text = "[%s] %s\nHP: %s | DMG: %d" % [enemy_id.capitalize(), state_name, hp_text, dmg_val]

	for r in to_remove:
		_overhead_labels.erase(r)


func _update_status_display() -> void:
	var state_name: String = Enums.WaveState.keys()[wave_manager.wave_state]
	var timer_text := ""
	if wave_manager.wave_state == Enums.WaveState.PREP:
		timer_text = " (%.1fs remaining)" % maxf(0.0, wave_manager.prep_timer)
	elif wave_manager.wave_state == Enums.WaveState.SUMMARY:
		timer_text = " (Next in %.1fs)" % maxf(0.0, wave_manager.summary_timer)

	status_label.text = "Wave %d | State: %s%s\nAlive in arena: %d | Queued: %d | Total: %d\nTime scale: %.1fx" % [
		wave_manager.current_wave,
		state_name,
		timer_text,
		wave_manager.enemies_alive,
		wave_manager.spawn_queue.size(),
		wave_manager.total_wave_enemies,
		Engine.time_scale
	]

	call_btn.disabled = (wave_manager.wave_state != Enums.WaveState.PREP)


func _update_preview() -> void:
	var w := int(wave_spin.value)
	var s := int(seed_spin.value)
	if w == _current_preview_wave and s == _current_preview_seed:
		return
	_current_preview_wave = w
	_current_preview_seed = s

	var cfg := wave_manager.scale_config if wave_manager.scale_config != null else ScaleConfig.new()
	var budget: int = cfg.get_budget(w)
	var duration: float = cfg.get_spawn_duration(w)
	var group_count: int = clampi(2 + int(floor(float(w) / 5.0)), 2, 6)

	var comp := wave_manager.generate_wave_composition(w, s)
	var grunts := 0
	var archers := 0
	var brutes := 0

	for item in comp:
		match item.id:
			&"grunt": grunts += 1
			&"archer": archers += 1
			&"brute": brutes += 1

	var total := comp.size()
	var archer_pct: float = (float(archers) / float(total) * 100.0) if total > 0 else 0.0

	var hp_m: float = cfg.get_hp_mult(w)
	var dmg_m: float = cfg.get_dmg_mult(w)
	var spd_m: float = cfg.get_speed_mult(w)

	var grunt_hp: int = int(round(float(GRUNT_DATA.base_hp) * hp_m)) if GRUNT_DATA != null else 0
	var grunt_dmg: int = int(round(float(GRUNT_DATA.base_damage) * dmg_m)) if GRUNT_DATA != null else 0
	var archer_hp: int = int(round(float(ARCHER_DATA.base_hp) * hp_m)) if ARCHER_DATA != null else 0
	var archer_dmg: int = int(round(float(ARCHER_DATA.base_damage) * dmg_m)) if ARCHER_DATA != null else 0
	var brute_hp: int = int(round(float(BRUTE_DATA.base_hp) * hp_m)) if BRUTE_DATA != null else 0
	var brute_dmg: int = int(round(float(BRUTE_DATA.base_damage) * dmg_m)) if BRUTE_DATA != null else 0

	composition_label.text = "Wave %d Preview (Seed %d):\nBudget: %d | Duration: %.1fs | Groups: %d\nScale: HP x%.2f | DMG x%.2f | Spd x%.3f\nTotal Enemies: %d\n • Grunt: %d (HP %d, DMG %d)\n • Archer: %d (HP %d, DMG %d - %.1f%%)\n • Brute: %d (HP %d, DMG %d - max %d)" % [
		w, s,
		budget, duration, group_count,
		hp_m, dmg_m, spd_m,
		total,
		grunts, grunt_hp, grunt_dmg,
		archers, archer_hp, archer_dmg, archer_pct,
		brutes, brute_hp, brute_dmg, int(floor(float(w) / 4.0))
	]

	# Build group breakdown text
	var group_map: Dictionary = {}
	for item in comp:
		var g_idx: int = item.group_index
		if not group_map.has(g_idx):
			group_map[g_idx] = []
		group_map[g_idx].append(item.id)

	var schedule_text := "Planned Groups:"
	for g_idx in group_map.keys():
		var list: Array = group_map[g_idx]
		schedule_text += "\n Group %d (%d units): %s" % [g_idx + 1, list.size(), ", ".join(list)]
	schedule_label.text = schedule_text


func _on_wave_state_changed(_new_state: Enums.WaveState, _old_state: Enums.WaveState) -> void:
	if wave_spin != null:
		wave_spin.set_value_no_signal(wave_manager.current_wave)
		_update_preview()
