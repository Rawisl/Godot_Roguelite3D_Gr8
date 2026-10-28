extends Node3D
## Manual playtest for card stat bonuses. Not shipped. Run with F6.
## Number keys fake the reward screen by emitting reward_picked, so every bonus goes
## through the same path as a real pick.

const COMMANDER_SCENE := preload("res://entities/commander/commander.tscn")
const GRUNT_SCENE := preload("res://entities/enemy/grunt.tscn")
const BRUTE_SCENE := preload("res://entities/enemy/brute.tscn")

const MAX_LEVEL := 3
const DUMMY_HP := 99999
const STATION_POS := Vector3(5.0, 0.0, 0.0)

const CARDS := {
	KEY_1: {"id": &"sharpness", "kind": &"PASSIVE", "name": "Sharpness"},
	KEY_2: {"id": &"armored", "kind": &"PASSIVE", "name": "Armored"},
	KEY_3: {"id": &"lifesteal", "kind": &"PASSIVE", "name": "Lifesteal"},
	KEY_4: {"id": &"heal_station", "kind": &"PASSIVE", "name": "Heal station"},
	KEY_5: {"id": &"vitality", "kind": &"STAT", "name": "Vitality"},
}

var _commander: CharacterBody3D
var _levels: Dictionary = {}
var _station: FakeHealStation
var _station_label: Label3D
var _last_hit: String = "-"
var _log_lines: Array[String] = []

@onready var _info: Label = %InfoLabel
@onready var _log_label: Label = %LogLabel
@onready var _rig: Node3D = %CameraRig


func _ready() -> void:
	_commander = COMMANDER_SCENE.instantiate() as CharacterBody3D
	add_child(_commander)
	_commander.health.damaged.connect(func(amount: int, _info_arg: DamageInfo) -> void:
		_log("Commander took %d damage (%d/%d)" % [amount, _commander.health.hp, _commander.health.max_hp])
	)
	_commander.health.hp_changed.connect(func(hp: int, max_hp: int) -> void:
		_log("HP %d/%d" % [hp, max_hp])
	)

	_spawn_dummy(GRUNT_SCENE, Vector3(3.0, 0.0, 0.0), "Dummy A", false)
	_spawn_dummy(GRUNT_SCENE, Vector3(3.0, 0.0, 3.0), "Dummy B", false)
	_spawn_dummy(GRUNT_SCENE, Vector3(-4.0, 0.0, 0.0), "Dummy C", false)
	_spawn_dummy(BRUTE_SCENE, Vector3(0.0, 0.0, -10.0), "Attacker (Brute)", true)
	_spawn_station()
	EventBus.mode_changed.emit(&"FRONTLINE")
	EventBus.state_changed.emit(&"COMBAT")
	_log("Ready. 1-5 pick cards, 6/7 hurt yourself, 8 refill station, R reset.")


func _process(delta: float) -> void:
	if is_instance_valid(_commander):
		_rig.global_position = _rig.global_position.lerp(_commander.global_position, clampf(delta * 6.0, 0.0, 1.0))
	_update_info()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return
	var key: Key = event.physical_keycode
	if CARDS.has(key):
		_pick(CARDS[key])
		return
	match key:
		KEY_6:
			_commander.take_damage(DamageInfo.new(30, Enums.DamageType.SLASH))
		KEY_7:
			_commander.take_damage(DamageInfo.new(10, Enums.DamageType.TRUE))
		KEY_8:
			_station.hp = _station.max_hp
			_log("Station refilled")
		KEY_R:
			get_tree().reload_current_scene()


func _pick(card: Dictionary) -> void:
	var id: StringName = card.id
	var level: int = mini(int(_levels.get(id, 0)) + 1, MAX_LEVEL)
	if level == _levels.get(id, 0):
		_log("%s is already max level" % card.name)
		return
	_levels[id] = level
	EventBus.reward_picked.emit(id, card.kind, level)
	_log("Picked %s -> level %d" % [card.name, level])


func _spawn_dummy(scene: PackedScene, pos: Vector3, title: String, active: bool) -> void:
	var enemy := scene.instantiate() as Enemy
	add_child(enemy)
	enemy.position = pos
	enemy.spawn_grace = false
	enemy.is_in_spawn_zone = false
	if active:
		enemy.speed_multiplier = 0.6
	else:
		enemy.set_physics_process(false)
	if enemy.health != null:
		enemy.health.max_hp = DUMMY_HP
		enemy.health.hp = DUMMY_HP
		enemy.health.damaged.connect(func(amount: int, _info_arg: DamageInfo) -> void:
			_last_hit = "%d on %s" % [amount, title]
			_log("Hit %s for %d" % [title, amount])
		)
	var label := Label3D.new()
	label.text = title
	label.position = Vector3(0.0, 2.2, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.012
	label.font_size = 38
	label.outline_size = 8
	enemy.add_child(label)


func _spawn_station() -> void:
	_station = FakeHealStation.new()
	add_child(_station)
	_station.global_position = STATION_POS
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.6
	cylinder.bottom_radius = 0.8
	cylinder.height = 1.2
	mesh.mesh = cylinder
	mesh.position = Vector3(0.0, 0.6, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.9, 0.5)
	mesh.material_override = mat
	_station.add_child(mesh)
	_station_label = Label3D.new()
	_station_label.position = Vector3(0.0, 2.0, 0.0)
	_station_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_station_label.no_depth_test = true
	_station_label.pixel_size = 0.012
	_station_label.font_size = 38
	_station_label.outline_size = 8
	_station.add_child(_station_label)


func _update_info() -> void:
	if not is_instance_valid(_commander):
		return
	var block: StatBlock = _commander.stat_block
	var channel := _commander.get_node("HealChannel") as HealChannel
	var cap: float = GameConfig.commander_armor_cap
	var base: CharacterStats = _commander.stats
	_info.text = """[STAT BLOCK PLAYTEST]
HP: %d / %d     Heal channel: %s
Sword damage: %.1f (base %d)     Hit 3: %d
Move speed: %.2f (base %.1f)
Armor: %.1f%% (cap %.0f%%)
Heal rate: %.0f HP/s
Lifesteal: %.1f%% (stat only, no kill hook yet)
Last hit dealt: %s

Levels: Sharpness %d | Armored %d | Lifesteal %d | Heal station %d | Vitality %d

[1] Sharpness  [2] Armored  [3] Lifesteal  [4] Heal station  [5] Vitality
[6] Take 30 slash   [7] Take 10 true   [8] Refill station   [R] Reset
[WASD] move  [Left click] attack  [Space] dodge  [Hold E near green station] heal""" % [
		_commander.health.hp, _commander.health.max_hp, channel.phase,
		block.get_value(&"sword_damage"), base.sword_damage,
		roundi(block.get_value(&"sword_damage") * base.combo_hit3_mult),
		block.get_value(&"move_speed"), base.move_speed,
		block.get_capped(&"armor_pct", cap) * 100.0, cap * 100.0,
		channel.get_heal_rate(),
		block.get_value(&"lifesteal_pct") * 100.0,
		_last_hit,
		_levels.get(&"sharpness", 0), _levels.get(&"armored", 0), _levels.get(&"lifesteal", 0),
		_levels.get(&"heal_station", 0), _levels.get(&"vitality", 0),
	]
	if _station_label != null:
		_station_label.text = "Heal station %d/%d" % [roundi(_station.hp), roundi(_station.max_hp)]


func _log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > 8:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)
