extends Node3D

const COMMANDER_SCENE := preload("res://entities/commander/commander.tscn")
const GRUNT_SCENE := preload("res://entities/enemy/grunt.tscn")
const ARCHER_SCENE := preload("res://entities/enemy/archer.tscn")
const BRUTE_SCENE := preload("res://entities/enemy/brute.tscn")

@export_group("Overhead 3D Label Settings")
## Font texture size in pixels (recommended: 32 - 44).
@export var label_font_size: int = 38
## Text outline thickness (recommended: 6 - 10).
@export var label_outline_size: int = 8
## World scale factor in 3D space (e.g. 0.0085 for medium, 0.012 for large).
@export var label_pixel_size: float = 0.012

var _commander: CharacterBody3D
var _commander_label: Label3D
var _spawned_enemies: Array[Dictionary] = []

var _battle_cry_cooldown_left: float = 0.0
var _battle_cry_active_left: float = 0.0

@onready var _ui_label: Label = %InfoLabel
@onready var _log_label: Label = %LogLabel
@onready var _range_ring: MeshInstance3D = %RangeRing


func _ready() -> void:
	EventBus.skill_cooldown_changed.connect(_on_skill_cooldown_changed)
	_setup_arena()


func _setup_arena() -> void:
	# Clear previous instances
	if _commander != null and is_instance_valid(_commander):
		_commander.queue_free()
	for item in _spawned_enemies:
		if item.node != null and is_instance_valid(item.node):
			item.node.queue_free()
	_spawned_enemies.clear()

	# Spawn Commander at origin
	_commander = COMMANDER_SCENE.instantiate() as CharacterBody3D
	_commander.position = Vector3.ZERO
	add_child(_commander)
	_commander.health.hp = 100

	# Overhead status label for Commander
	_commander_label = Label3D.new()
	_commander_label.position = Vector3(0.0, 2.2, 0.0)
	_commander_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_commander_label.no_depth_test = true
	_commander_label.font_size = label_font_size
	_commander_label.outline_size = label_outline_size
	_commander_label.pixel_size = label_pixel_size
	_commander_label.modulate = Color(0.4, 0.9, 1.0)
	_commander_label.outline_modulate = Color(0.0, 0.2, 0.4)
	_commander.add_child(_commander_label)

	_commander.health.damaged.connect(func(amount: int, info: DamageInfo):
		var type_str := "SLASH"
		if info != null:
			match info.damage_type:
				Enums.DamageType.PIERCE: type_str = "PIERCE"
				Enums.DamageType.BLAST: type_str = "BLAST"
				Enums.DamageType.SLASH: type_str = "SLASH"
				Enums.DamageType.TRUE: type_str = "TRUE"
		_log("[DAMAGE] Commander took %d %s damage. HP: %d/%d" % [
			amount, type_str, _commander.health.hp, _commander.health.max_hp
		])
	)

	# Setup Range Ring (radius 6m)
	_setup_range_indicator(6.0)

	# Spawn Test Dummies
	_spawn_dummy(GRUNT_SCENE, Vector3(3.0, 0.0, 0.0), "Grunt (3m - In Range)", false)
	_spawn_dummy(ARCHER_SCENE, Vector3(-4.5, 0.0, 0.0), "Archer (4.5m - In Range)", false)
	_spawn_dummy(BRUTE_SCENE, Vector3(0.0, 0.0, 5.0), "Brute (5m - In Range)", false)
	_spawn_dummy(GRUNT_SCENE, Vector3(0.0, 0.0, -8.5), "Grunt (8.5m - Out of Range)", false)
	_spawn_dummy(GRUNT_SCENE, Vector3(2.0, 0.0, 2.0), "Boss Dummy (2.8m - Boss Immune)", true)

	_log("[READY] Test arena ready. Press Q for Battle Cry, 1 for 20 Slash damage, 2 for 10 True damage, R to reset.")


func _setup_range_indicator(radius: float) -> void:
	if _range_ring != null:
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.08
		torus.outer_radius = radius + 0.08
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.8, 0.2, 0.7)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_range_ring.mesh = torus
		_range_ring.material_override = mat
		_range_ring.position = Vector3(0.0, 0.05, 0.0)


func _spawn_dummy(scene: PackedScene, pos: Vector3, title: String, is_boss: bool) -> void:
	var enemy: Enemy = scene.instantiate() as Enemy
	add_child(enemy)
	enemy.position = pos
	enemy.spawn_grace = false
	enemy.is_in_spawn_zone = false
	enemy.speed_multiplier = 0.6

	if is_boss:
		enemy.add_to_group(&"boss")

	# Dummy enemies have 99999 HP so player can continuously test attacks and aggro
	if enemy.health != null:
		enemy.health.max_hp = 99999
		enemy.health.hp = 99999
		enemy.health.damaged.connect(func(amount: int, info: DamageInfo):
			var dmg_type_str := "SLASH"
			if info != null and info.damage_type < Enums.DamageType.size():
				dmg_type_str = Enums.DamageType.keys()[info.damage_type]
			_log("[HIT] %s received %d %s damage" % [title, amount, dmg_type_str])
		)

	# Overhead status label for Enemy
	var label := Label3D.new()
	var height_offset := 2.6 if title.begins_with("Brute") else 2.0
	label.position = Vector3(0.0, height_offset, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = label_font_size
	label.outline_size = label_outline_size
	label.pixel_size = label_pixel_size
	label.text = title
	enemy.add_child(label)

	_spawned_enemies.append({
		"node": enemy,
		"label": label,
		"title": title,
		"init_pos": pos,
		"is_boss": is_boss
	})


func _process(_delta: float) -> void:
	_update_ui()
	_update_overhead_labels()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return

	match event.physical_keycode:
		KEY_1:
			# Test 20 Slash damage to Commander
			if _commander != null and is_instance_valid(_commander):
				var info := DamageInfo.new(20, Enums.DamageType.SLASH)
				_log("[TEST] Applying 20 Raw Slash Damage to Commander...")
				_commander.take_damage(info)
		KEY_2:
			# Test 10 True damage to Commander
			if _commander != null and is_instance_valid(_commander):
				var info := DamageInfo.new(10, Enums.DamageType.TRUE)
				_log("[TEST] Applying 10 True Damage to Commander...")
				_commander.take_damage(info)
		KEY_R:
			_log("[RESET] Resetting arena...")
			_setup_arena()


func _update_ui() -> void:
	if _ui_label == null:
		return

	var hp_str := "N/A"
	if _commander != null and is_instance_valid(_commander):
		hp_str = "%d / %d" % [_commander.health.hp, _commander.health.max_hp]
		_battle_cry_active_left = _commander._battle_cry_active_timer

	var cd_str := "READY (Press Q)" if _battle_cry_cooldown_left <= 0.05 else "%.1f s" % _battle_cry_cooldown_left
	var buff_str := "INACTIVE (100% damage)"
	if _battle_cry_active_left > 0.0:
		buff_str = "ACTIVE (-30%% damage: %.1fs remaining)" % _battle_cry_active_left

	_ui_label.text = """[BATTLE CRY PLAYTEST SUITE]
--------------------------------------------------
Commander HP: %s
Battle Cry Cooldown (Q): %s
Buff Status: %s

CONTROLS:
  [W, A, S, D] : Move Commander
  [Q]          : Activate Battle Cry (6m radius indicator)
  [Space]      : Dodge
  [Left Click] : 3-hit combo basic attack
  [Key 1]      : Deal 20 Slash damage to Commander (-30%% check)
  [Key 2]      : Deal 10 True damage to Commander (True damage check)
  [Key R]      : Reset arena
--------------------------------------------------""" % [hp_str, cd_str, buff_str]


func _update_overhead_labels() -> void:
	if _commander == null or not is_instance_valid(_commander):
		return

	# Update Commander's own overhead label
	if _commander_label != null:
		var buff_text := "Buff: -30%% (%.1fs)" % _battle_cry_active_left if _battle_cry_active_left > 0.0 else "Buff: None"
		_commander_label.text = "Commander\nHP: %d/%d\n%s" % [
			_commander.health.hp, _commander.health.max_hp, buff_text
		]
		if _battle_cry_active_left > 0.0:
			_commander_label.modulate = Color(1.0, 0.9, 0.3)
		else:
			_commander_label.modulate = Color(0.4, 0.9, 1.0)

	# Update Enemy overhead labels safely
	for item in _spawned_enemies:
		var raw_node = item.get("node")
		if raw_node == null or not is_instance_valid(raw_node):
			continue
		var enemy := raw_node as Enemy
		if enemy == null or enemy.is_queued_for_deletion() or enemy.is_dead:
			continue

		var raw_label = item.get("label")
		if raw_label == null or not is_instance_valid(raw_label):
			continue
		var label := raw_label as Label3D
		if label == null or label.is_queued_for_deletion():
			continue

		var dist := _commander.global_position.distance_to(enemy.global_position)
		var is_targeting_cmd := (enemy.current_target == _commander)
		var target_str := "COMMANDER" if is_targeting_cmd else "None / Fortress"

		var prov_str := "YES (%.1fs)" % enemy.provoked_timer if enemy.provoked_by_player else "NO"
		var state_names: Array[String] = ["SPAWN", "ADVANCE", "CHASE", "ATTACK", "STAGGER", "WAIT", "FRENZY", "DEAD"]
		var state_str: String = "STATE"
		if enemy.current_state >= 0 and enemy.current_state < state_names.size():
			state_str = state_names[enemy.current_state]

		var hp_str := "HP: %d" % enemy.health.hp if enemy.health != null else "HP: N/A"
		label.text = "%s [%s] (%s)\nDist: %.1fm | Target: %s\nProvoked: %s" % [
			item.title, state_str, hp_str, dist, target_str, prov_str
		]

		if is_targeting_cmd:
			label.modulate = Color(1.0, 0.3, 0.3)
			label.outline_modulate = Color(0.4, 0.0, 0.0)
		else:
			label.modulate = Color(1.0, 1.0, 1.0)
			label.outline_modulate = Color(0.1, 0.1, 0.1)


func _on_skill_cooldown_changed(skill_id: StringName, remaining: float, _total: float) -> void:
	if skill_id == &"battle_cry":
		_battle_cry_cooldown_left = remaining


func _log(msg: String) -> void:
	print(msg)
	if _log_label != null:
		var lines := _log_label.text.split("\n")
		var arr := Array(lines)
		if arr.size() > 6:
			arr.remove_at(0)
		arr.append(msg)
		_log_label.text = "\n".join(arr)
