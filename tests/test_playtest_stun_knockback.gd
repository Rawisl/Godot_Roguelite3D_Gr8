extends Node3D

const COMMANDER_SCENE := preload("res://entities/commander/commander.tscn")
const BRUTE_SCENE := preload("res://entities/enemy/brute.tscn")
const BULWARK_SCENE := preload("res://entities/enemy/bulwark.tscn")
const GRUNT_SCENE := preload("res://entities/enemy/grunt.tscn")

@export_group("Overhead 3D Label Settings")
@export var label_font_size: int = 38
@export var label_outline_size: int = 8
@export var label_pixel_size: float = 0.012

var _commander: CharacterBody3D
var _commander_label: Label3D
var _bulwark: Bulwark
var _bulwark_label: Label3D
var _brute: Enemy
var _brute_label: Label3D
var _grunt: Enemy
var _grunt_label: Label3D
var _dummy_tower: Node3D
var _dummy_tower_label: Label3D

var _ai_enabled: bool = true
var _bulwark_stomp_ring: MeshInstance3D

@onready var _ui_label: Label = %InfoLabel
@onready var _log_label: Label = %LogLabel


func _ready() -> void:
	_setup_arena()


func _setup_arena() -> void:
	# Clean up previous instances if resetting
	if _commander != null and is_instance_valid(_commander):
		_commander.queue_free()
	if _bulwark != null and is_instance_valid(_bulwark):
		_bulwark.queue_free()
	if _brute != null and is_instance_valid(_brute):
		_brute.queue_free()
	if _grunt != null and is_instance_valid(_grunt):
		_grunt.queue_free()
	if _dummy_tower != null and is_instance_valid(_dummy_tower):
		_dummy_tower.queue_free()
	if _bulwark_stomp_ring != null and is_instance_valid(_bulwark_stomp_ring):
		_bulwark_stomp_ring.queue_free()

	_spawn_commander()
	_spawn_bulwark()
	_spawn_brute()
	_spawn_grunt()
	_spawn_dummy_tower()

	_log("[READY] Playtest arena ready. Test stun, knockback, stomp AoE, and dodge feel.")


func _spawn_commander() -> void:
	_commander = COMMANDER_SCENE.instantiate() as CharacterBody3D
	_commander.position = Vector3(0.0, 0.0, 1.0)
	add_child(_commander)
	_commander.health.hp = 100

	_commander_label = _create_overhead_label(Vector3(0.0, 2.2, 0.0), Color(0.4, 0.9, 1.0))
	_commander.add_child(_commander_label)

	_commander.health.damaged.connect(func(amount: int, info: DamageInfo):
		var type_name := "DAMAGE"
		if info != null and info.damage_type < Enums.DamageType.size():
			type_name = Enums.DamageType.keys()[info.damage_type]
		var kb_text := " (Knockback: %.1fm)" % info.knockback_force if info != null and info.knockback_force > 0.0 else ""
		_log("[HIT] Commander took %d %s damage%s. HP: %d/%d" % [
			amount, type_name, kb_text, _commander.health.hp, _commander.health.max_hp
		])
	)


func _spawn_bulwark() -> void:
	_bulwark = BULWARK_SCENE.instantiate() as Bulwark
	_bulwark.position = Vector3(0.0, 0.0, -3.5)
	add_child(_bulwark)
	_bulwark.spawn_grace = false
	_bulwark.is_in_spawn_zone = false
	_bulwark.speed_multiplier = 0.5 if _ai_enabled else 0.0
	_bulwark.add_to_group(&"boss")

	if _bulwark.health != null:
		_bulwark.health.max_hp = 99999
		_bulwark.health.hp = 99999

	_bulwark_label = _create_overhead_label(Vector3(0.0, 3.2, 0.0), Color(1.0, 0.5, 0.3))
	_bulwark.add_child(_bulwark_label)

	# Visual indicator for 3.0m stomp radius centered on Bulwark
	_bulwark_stomp_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = Bulwark.STOMP_RADIUS - 0.08
	torus.outer_radius = Bulwark.STOMP_RADIUS + 0.08
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.2, 0.6)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bulwark_stomp_ring.mesh = torus
	_bulwark_stomp_ring.material_override = mat
	_bulwark_stomp_ring.position = Vector3(0.0, 0.05, 0.0)
	_bulwark.add_child(_bulwark_stomp_ring)


func _spawn_brute() -> void:
	_brute = BRUTE_SCENE.instantiate() as Enemy
	_brute.position = Vector3(4.0, 0.0, 1.0)
	add_child(_brute)
	_brute.spawn_grace = false
	_brute.is_in_spawn_zone = false
	_brute.speed_multiplier = 0.6 if _ai_enabled else 0.0

	if _brute.health != null:
		_brute.health.max_hp = 99999
		_brute.health.hp = 99999

	_brute_label = _create_overhead_label(Vector3(0.0, 2.6, 0.0), Color(1.0, 0.8, 0.3))
	_brute.add_child(_brute_label)


func _spawn_grunt() -> void:
	_grunt = GRUNT_SCENE.instantiate() as Enemy
	_grunt.position = Vector3(-4.0, 0.0, 1.0)
	add_child(_grunt)
	_grunt.spawn_grace = false
	_grunt.is_in_spawn_zone = false
	_grunt.speed_multiplier = 0.5 if _ai_enabled else 0.0

	if _grunt.health != null:
		_grunt.health.max_hp = 99999
		_grunt.health.hp = 99999

	_grunt_label = _create_overhead_label(Vector3(0.0, 2.0, 0.0), Color(0.8, 0.8, 0.8))
	_grunt.add_child(_grunt_label)


func _spawn_dummy_tower() -> void:
	var tower_body := CharacterBody3D.new()
	tower_body.name = "DummyTower"
	tower_body.set_script(load("res://tests/dummy_target.gd"))
	tower_body.set("hp", 300)
	tower_body.set("max_hp", 300)
	tower_body.add_to_group(&"tower")
	tower_body.position = Vector3(2.0, 0.0, -3.5)

	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.8
	cyl.height = 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.7, 0.9)
	mesh_inst.mesh = cyl
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(0.0, 1.0, 0.0)
	tower_body.add_child(mesh_inst)

	_dummy_tower_label = _create_overhead_label(Vector3(0.0, 2.4, 0.0), Color(0.4, 0.8, 1.0))
	tower_body.add_child(_dummy_tower_label)

	_dummy_tower = tower_body
	add_child(_dummy_tower)


func _create_overhead_label(offset: Vector3, color: Color) -> Label3D:
	var label := Label3D.new()
	label.position = offset
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = label_font_size
	label.outline_size = label_outline_size
	label.pixel_size = label_pixel_size
	label.modulate = color
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	return label


func _process(_delta: float) -> void:
	_update_ui()
	_update_overhead_labels()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return

	match event.physical_keycode:
		KEY_1:
			_trigger_bulwark_stomp()
		KEY_2:
			_trigger_brute_strike()
		KEY_3:
			_trigger_direct_stun()
		KEY_4:
			_toggle_ai()
		KEY_H:
			_heal_commander()
		KEY_R:
			_log("[RESET] Resetting arena...")
			_setup_arena()


func _trigger_bulwark_stomp() -> void:
	if _bulwark == null or not is_instance_valid(_bulwark):
		_log("[WARN] Bulwark not available.")
		return
	_log("[ACTION] Bulwark executing Stomp AoE (3.0m radius, 45 BLAST dmg, 3.0m knockback, 1.5s stun)...")
	_bulwark.execute_stomp()


func _trigger_brute_strike() -> void:
	if _brute == null or not is_instance_valid(_brute) or _commander == null or not is_instance_valid(_commander):
		_log("[WARN] Brute or Commander not available.")
		return
	var diff := (_commander.global_position - _brute.global_position)
	diff.y = 0.0
	var strike_dir := diff.normalized() if diff.length_squared() > 0.001 else Vector3.FORWARD
	var info := DamageInfo.new(25, Enums.DamageType.SLASH, _brute, 2.0, strike_dir)
	_log("[ACTION] Brute executing melee strike (25 SLASH dmg, 2.0m knockback)...")
	_commander.take_damage(info)


func _trigger_direct_stun() -> void:
	if _commander == null or not is_instance_valid(_commander):
		return
	var ok: bool = _commander.apply_stun(1.5)
	if ok:
		_log("[ACTION] Applied 1.5s stun to Commander.")
	else:
		_log("[BLOCKED] Stun failed (immune, dodging, deploying, or already stunned).")


func _toggle_ai() -> void:
	_ai_enabled = not _ai_enabled
	if _bulwark != null and is_instance_valid(_bulwark):
		_bulwark.speed_multiplier = 0.5 if _ai_enabled else 0.0
		if _ai_enabled:
			_bulwark.set_target(_commander)
	if _brute != null and is_instance_valid(_brute):
		_brute.speed_multiplier = 0.6 if _ai_enabled else 0.0
		if _ai_enabled:
			_brute.set_target(_commander)
	if _grunt != null and is_instance_valid(_grunt):
		_grunt.speed_multiplier = 0.5 if _ai_enabled else 0.0
		if _ai_enabled:
			_grunt.set_target(_commander)
	_log("[AI] Enemy AI %s" % ("ENABLED (Chasing Commander)" if _ai_enabled else "DISABLED (Hold position)"))


func _heal_commander() -> void:
	if _commander != null and is_instance_valid(_commander):
		_commander.health.hp = _commander.health.max_hp
		_log("[HEAL] Commander HP restored to full (%d/%d)." % [_commander.health.hp, _commander.health.max_hp])


func _update_ui() -> void:
	if _ui_label == null:
		return

	var hp_str := "N/A"
	var stun_status := "NORMAL"
	var kb_speed := 0.0

	if _commander != null and is_instance_valid(_commander):
		hp_str = "%d / %d" % [_commander.health.hp, _commander.health.max_hp]
		kb_speed = _commander._knockback_velocity.length()

		if _commander.health.hp <= 0:
			stun_status = "DEAD"
		elif _commander.is_dodging:
			stun_status = "DODGING (i-frame)"
		elif _commander.is_stunned:
			stun_status = "STUNNED (%.2fs left)" % _commander._stun_timer
		elif _commander._stun_immunity_timer > 0.0:
			stun_status = "STUN IMMUNITY (%.2fs left)" % _commander._stun_immunity_timer
		else:
			stun_status = "READY"

	_ui_label.text = """[STUN & KNOCKBACK PLAYTEST ARENA]
--------------------------------------------------
Commander HP: %s
State: %s
Knockback Velocity: %.2f m/s
AI Movement: %s

CONTROLS:
  [W, A, S, D] : Move Commander
  [Space]      : Dodge (i-frame: avoids damage, stun, knockback)
  [Left Click] : 3-hit Attack (hit 3 pushes Grunt, Boss/Brute immune)
  [Q]          : Battle Cry (-30%% damage, taunt)
  [Key 1]      : Trigger Bulwark Boss Stomp (3m AoE BLAST + Stun + 3m KB)
  [Key 2]      : Trigger Brute Melee Strike (25 SLASH + 2m KB)
  [Key 3]      : Apply direct 1.5s Stun test
  [Key 4]      : Toggle Enemy AI chase on/off
  [Key H]      : Heal Commander to full HP
  [Key R]      : Reset arena
--------------------------------------------------""" % [
		hp_str, stun_status, kb_speed, "ON" if _ai_enabled else "OFF"
	]


func _update_overhead_labels() -> void:
	if _commander != null and is_instance_valid(_commander) and _commander_label != null:
		var state_line := "State: Normal"
		var label_color := Color(0.4, 0.9, 1.0)

		if _commander.health.hp <= 0:
			state_line = "DEAD"
			label_color = Color(0.5, 0.5, 0.5)
		elif _commander.is_dodging:
			state_line = "DODGING (i-frame)"
			label_color = Color(0.3, 1.0, 0.4)
		elif _commander.is_stunned:
			state_line = "STUNNED (%.1fs)" % _commander._stun_timer
			label_color = Color(1.0, 0.2, 0.2)
		elif _commander._stun_immunity_timer > 0.0:
			state_line = "IMMUNE TO STUN (%.1fs)" % _commander._stun_immunity_timer
			label_color = Color(1.0, 0.9, 0.2)

		var kb_line := "KB: %.1fm/s" % _commander._knockback_velocity.length() if _commander._knockback_velocity.length() > 0.01 else ""
		_commander_label.text = "Commander\nHP: %d/%d\n%s %s" % [
			_commander.health.hp, _commander.health.max_hp, state_line, kb_line
		]
		_commander_label.modulate = label_color

	if _bulwark != null and is_instance_valid(_bulwark) and _bulwark_label != null:
		var dist_to_cmd := _commander.global_position.distance_to(_bulwark.global_position) if _commander and is_instance_valid(_commander) else 0.0
		_bulwark_label.text = "Bulwark Boss (Immune to KB/Stun)\nDist to Commander: %.1fm\nStomp Radius: 3.0m (Red Ring)" % dist_to_cmd

	if _brute != null and is_instance_valid(_brute) and _brute_label != null:
		var dist := _commander.global_position.distance_to(_brute.global_position) if _commander and is_instance_valid(_commander) else 0.0
		_brute_label.text = "Brute (Immune to KB/Stun)\nDist: %.1fm | Melee KB: 2.0m" % dist

	if _grunt != null and is_instance_valid(_grunt) and _grunt_label != null:
		var dist_g := _commander.global_position.distance_to(_grunt.global_position) if _commander and is_instance_valid(_commander) else 0.0
		_grunt_label.text = "Grunt (Can be knocked back by Hit 3)\nDist: %.1fm" % dist_g

	if _dummy_tower != null and is_instance_valid(_dummy_tower) and _dummy_tower_label != null:
		var hp_val: int = _dummy_tower.get("hp") if _dummy_tower.get("hp") != null else 0
		_dummy_tower_label.text = "Dummy Tower (AoE Target)\nHP: %d/300" % hp_val


func _log(msg: String) -> void:
	print(msg)
	if _log_label != null:
		var lines := _log_label.text.split("\n")
		var arr := Array(lines)
		if arr.size() > 6:
			arr.remove_at(0)
		arr.append(msg)
		_log_label.text = "\n".join(arr)
