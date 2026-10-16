extends Node3D

const COMMANDER_SCENE := preload("res://entities/commander/commander.tscn")
const GRUNT_SCENE := preload("res://entities/enemy/grunt.tscn")
const ARCHER_SCENE := preload("res://entities/enemy/archer.tscn")
const BRUTE_SCENE := preload("res://entities/enemy/brute.tscn")
const BARRICADE_SCENE := preload("res://entities/tower/barricade.tscn")
const ARROW_TOWER_SCENE := preload("res://entities/tower/arrow.tscn")

@export var label_font_size: int = 34
@export var label_outline_size: int = 8
@export var label_pixel_size: float = 0.012

var _commander: CharacterBody3D
var _commander_label: Label3D
var _spawned_enemies: Array[Dictionary] = []
var _logs: Array[String] = []

@onready var _log_label: Label = get_node_or_null("%LogLabel") as Label
@onready var _info_label: Label = get_node_or_null("%InfoLabel") as Label
@onready var _spawn_point: Marker3D = get_node_or_null("%EnemySpawnPoint") as Marker3D

func _ready() -> void:
	_setup_buttons()
	_setup_arena()

func _setup_buttons() -> void:
	var btn_grunt: Button = get_node_or_null("%BtnGrunt") as Button
	if btn_grunt: btn_grunt.pressed.connect(func(): spawn_enemy(GRUNT_SCENE, "Grunt"))
	var btn_archer: Button = get_node_or_null("%BtnArcher") as Button
	if btn_archer: btn_archer.pressed.connect(func(): spawn_enemy(ARCHER_SCENE, "Archer"))
	var btn_brute: Button = get_node_or_null("%BtnBrute") as Button
	if btn_brute: btn_brute.pressed.connect(func(): spawn_enemy(BRUTE_SCENE, "Brute"))
	var btn_wave: Button = get_node_or_null("%BtnWave") as Button
	if btn_wave: btn_wave.pressed.connect(func():
		spawn_enemy(GRUNT_SCENE, "Grunt")
		spawn_enemy(ARCHER_SCENE, "Archer")
		spawn_enemy(BRUTE_SCENE, "Brute")
	)
	var btn_stagger: Button = get_node_or_null("%BtnStagger") as Button
	if btn_stagger: btn_stagger.pressed.connect(trigger_stagger_hit_nearest)
	var btn_clear: Button = get_node_or_null("%BtnClear") as Button
	if btn_clear: btn_clear.pressed.connect(clear_enemies)
	var btn_reset: Button = get_node_or_null("%BtnReset") as Button
	if btn_reset: btn_reset.pressed.connect(_setup_arena)

func _setup_arena() -> void:
	# Clear previous
	if _commander != null and is_instance_valid(_commander):
		_commander.queue_free()
	for item in _spawned_enemies:
		if item.node != null and is_instance_valid(item.node):
			item.node.queue_free()
	_spawned_enemies.clear()

	# Spawn Commander
	_commander = COMMANDER_SCENE.instantiate() as CharacterBody3D
	_commander.position = Vector3(-2.0, 0.0, 0.0)
	add_child(_commander)
	_commander.health.max_hp = 200
	_commander.health.hp = 200

	# 3D label for Commander
	_commander_label = Label3D.new()
	_commander_label.position = Vector3(0.0, 2.2, 0.0)
	_commander_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_commander_label.no_depth_test = true
	_commander_label.font_size = label_font_size
	_commander_label.outline_size = label_outline_size
	_commander_label.pixel_size = label_pixel_size
	_commander_label.modulate = Color(0.4, 0.9, 1.0)
	_commander.add_child(_commander_label)

	_commander.health.damaged.connect(func(amount: int, _info: DamageInfo):
		_log("[COMMANDER HIT] Took %d damage! HP: %d/%d" % [
			amount, _commander.health.hp, _commander.health.max_hp
		])
	)

	_log("[READY] Enemy Playtest Arena initialized.")

func spawn_enemy(scene: PackedScene, enemy_name: String) -> void:
	var enemy: Enemy = scene.instantiate() as Enemy
	add_child(enemy)
	var spawn_pos: Vector3 = _spawn_point.global_position if _spawn_point != null else Vector3(14.0, 0.0, 0.0)
	# Add slight jitter so enemies don't overlap exactly
	spawn_pos.z += randf_range(-1.5, 1.5)
	enemy.position = spawn_pos
	enemy.spawn_grace = false
	enemy.is_in_spawn_zone = false

	# 3D overhead label
	var label := Label3D.new()
	var height_offset := 2.6 if enemy_name.begins_with("Brute") else 2.0
	label.position = Vector3(0.0, height_offset, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = label_font_size
	label.outline_size = label_outline_size
	label.pixel_size = label_pixel_size
	label.text = enemy_name
	enemy.add_child(label)

	enemy.health.damaged.connect(func(amount: int, info: DamageInfo):
		var type_str := "SLASH"
		if info != null and info.damage_type < Enums.DamageType.size():
			type_str = Enums.DamageType.keys()[info.damage_type]
		var src_str := ""
		if info != null and info.source != null and is_instance_valid(info.source):
			src_str = " from %s" % info.source.name
		_log("[ENEMY HIT] %s took %d %s dmg%s (HP: %d/%d)" % [
			enemy_name, amount, type_str, src_str, enemy.health.hp, enemy.health.max_hp
		])
	)

	_spawned_enemies.append({
		"node": enemy,
		"label": label,
		"name": enemy_name
	})

	_log("[SPAWN] %s spawned at %s" % [enemy_name, spawn_pos])

func trigger_stagger_hit_nearest() -> void:
	var nearest_enemy: Enemy = null
	var min_dist: float = 99999.0
	for item in _spawned_enemies:
		var raw_node = item.get("node")
		if raw_node == null or not is_instance_valid(raw_node):
			continue
		var enemy := raw_node as Enemy
		if enemy == null or enemy.is_queued_for_deletion() or enemy.is_dead:
			continue
		var d := _commander.global_position.distance_to(enemy.global_position)
		if d < min_dist:
			min_dist = d
			nearest_enemy = enemy

	if nearest_enemy == null:
		_log("[STAGGER TEST] No enemy found!")
		return

	var info := DamageInfo.new(10, Enums.DamageType.SLASH, _commander)
	nearest_enemy.health.take_damage(info)
	nearest_enemy.apply_knockback((nearest_enemy.global_position - _commander.global_position).normalized() * 5.0)

	if nearest_enemy.knockback_immune:
		_log("[STAGGER TEST] Hit %s: IMMUNE to knockback (Brute/Boss)!" % nearest_enemy.data.id)
	elif nearest_enemy.knockback_immunity_timer > 0.0:
		_log("[STAGGER TEST] Hit %s: Already in Knockback Immunity (%.1fs left)!" % [
			nearest_enemy.data.id, nearest_enemy.knockback_immunity_timer
		])
	else:
		_log("[STAGGER TEST] Hit %s: STAGGER applied! (0.4s interrupt + 2s immunity)" % nearest_enemy.data.id)

func clear_enemies() -> void:
	for item in _spawned_enemies:
		var raw_node = item.get("node")
		if raw_node != null and is_instance_valid(raw_node):
			raw_node.queue_free()
	_spawned_enemies.clear()
	_log("[CLEAR] All enemies cleared.")

func _process(_delta: float) -> void:
	_update_labels()

func _update_labels() -> void:
	if _commander != null and is_instance_valid(_commander):
		var dodge_str := "DODGING (i-frame)" if _commander.is_dodging else "Normal"
		_commander_label.text = "Commander\nHP: %d/%d\nState: %s" % [
			_commander.health.hp, _commander.health.max_hp, dodge_str
		]
		if _commander.is_dodging:
			_commander_label.modulate = Color(1.0, 1.0, 0.2)
		else:
			_commander_label.modulate = Color(0.4, 0.9, 1.0)

	var alive_items: Array[Dictionary] = []
	for item in _spawned_enemies:
		var raw_node = item.get("node")
		if raw_node == null or not is_instance_valid(raw_node):
			continue
		var enemy := raw_node as Enemy
		if enemy == null or enemy.is_queued_for_deletion():
			continue

		alive_items.append(item)

		var raw_label = item.get("label")
		if raw_label == null or not is_instance_valid(raw_label):
			continue
		var label := raw_label as Label3D
		if label == null or label.is_queued_for_deletion():
			continue

		if enemy.is_dead:
			label.text = "[DEAD]"
			continue

		var state_str := "MOVE"
		match enemy.current_state:
			0: state_str = "SPAWN"
			1: state_str = "ADVANCE"
			2: state_str = "CHASE"
			3: state_str = "ATTACK (Wind-up: %.2fs)" % enemy.attack_windup_timer
			4: state_str = "STAGGER (%.2fs)" % enemy.stagger_timer
			5: state_str = "WAIT"

		var target_name := "None"
		if enemy.current_target != null and is_instance_valid(enemy.current_target):
			target_name = enemy.current_target.name

		var immune_str := ""
		if enemy.knockback_immune:
			immune_str = "\n[KNOCKBACK IMMUNE]"
		elif enemy.knockback_immunity_timer > 0.0:
			immune_str = "\n[KB-Immunity: %.1fs]" % enemy.knockback_immunity_timer

		label.text = "%s (HP: %d/%d)\nState: %s\nTarget: %s%s" % [
			item.name, enemy.health.hp, enemy.health.max_hp, state_str, target_name, immune_str
		]
	_spawned_enemies = alive_items

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return

	match event.keycode:
		KEY_1:
			spawn_enemy(GRUNT_SCENE, "Grunt")
		KEY_2:
			spawn_enemy(ARCHER_SCENE, "Archer")
		KEY_3:
			spawn_enemy(BRUTE_SCENE, "Brute")
		KEY_4:
			spawn_enemy(GRUNT_SCENE, "Grunt")
			spawn_enemy(ARCHER_SCENE, "Archer")
			spawn_enemy(BRUTE_SCENE, "Brute")
		KEY_5, KEY_K:
			trigger_stagger_hit_nearest()
		KEY_C:
			clear_enemies()
		KEY_R:
			_setup_arena()

func _log(msg: String) -> void:
	print(msg)
	_logs.append(msg)
	if _logs.size() > 6:
		_logs.pop_front()
	if _log_label != null:
		_log_label.text = "\n".join(_logs)
