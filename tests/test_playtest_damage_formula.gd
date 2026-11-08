extends Node3D
## Manual playtest for the shared damage formula. Not shipped. Run with F6.
## Swing at the dummies to feel sword damage, cast Whirlwind (same call SkillRunner makes), stack
## Sharpness, switch the per-hit cap and the fire patch on and off, and fire non-sword hits at
## the Bulwark to see RESIST and IMMUNE. F1-F3 try the weapon state: grant the next weapon, equip
## the next owned one (PREP only) and flip between PREP and COMBAT; the ring shows the sword range.
## Keys here are test-only, game input is untouched.

const COMMANDER_SCENE := preload("res://entities/commander/commander.tscn")
const GRUNT_SCENE := preload("res://entities/enemy/grunt.tscn")
const BULWARK_SCENE := preload("res://entities/enemy/bulwark.tscn")
const WHIRLWIND_DATA := preload("res://data/skills/whirlwind.tres")

const DUMMY_HP := 99999
const MAX_SHARPNESS := 3
const CAP_VALUE := 10
const DOT_RAW := 6.0
const DOT_DEALT := 1.05
const DOT_INTERVAL := 0.25
const TEST_HIT_RAW := 40.0
const WEAPON_ORDER: Array[StringName] = [&"sword_base", &"frost", &"chain_lightning", &"burn", &"rampage", &"swift"]

var _commander: CharacterBody3D
var _grunts: Array[Enemy] = []
var _bulwark: Enemy
var _sharpness: int = 0
var _whirlwind_level: int = 1
var _cap_on: bool = false
var _dot_on: bool = false
var _dot_timer: float = 0.0
var _dot_total: int = 0
var _dot_ticks: int = 0
var _last_hit: String = "-"
var _run_state: RunState
var _range_ring: MeshInstance3D
var _wave_state: StringName = &"COMBAT"
var _log_lines: Array[String] = []

@onready var _info: Label = %InfoLabel
@onready var _log_label: Label = %LogLabel
@onready var _rig: Node3D = %CameraRig


func _ready() -> void:
	_run_state = RunState.new()
	add_child(_run_state)
	_commander = COMMANDER_SCENE.instantiate() as CharacterBody3D
	add_child(_commander)
	_build_range_ring()
	_grunts.append(_spawn_dummy(GRUNT_SCENE, Vector3(3.0, 0.0, 0.0), "Grunt A"))
	_grunts.append(_spawn_dummy(GRUNT_SCENE, Vector3(3.0, 0.0, 3.0), "Grunt B"))
	_grunts.append(_spawn_dummy(GRUNT_SCENE, Vector3(-4.0, 0.0, 0.0), "Grunt C"))
	_bulwark = _spawn_dummy(BULWARK_SCENE, Vector3(0.0, 0.0, -5.0), "Bulwark")
	_grunts.append(_spawn_dummy(GRUNT_SCENE, Vector3(0.0, 0.0, 2.3), "Grunt D 2.3 m (swift misses)"))
	EventBus.mode_changed.emit(&"FRONTLINE")
	EventBus.state_changed.emit(&"COMBAT")
	_log("Ready. Swing with left click, keys 1-6 run the tests, F1-F3 try weapons.")


func _process(delta: float) -> void:
	if is_instance_valid(_commander):
		_rig.global_position = _rig.global_position.lerp(_commander.global_position, clampf(delta * 6.0, 0.0, 1.0))
	if _dot_on:
		_dot_timer += delta
		while _dot_timer >= DOT_INTERVAL:
			_dot_timer -= DOT_INTERVAL
			_grunts[0].take_damage(DamageInfo.outgoing(DOT_RAW, DOT_DEALT, Enums.DamageType.BLAST, _commander, 0.0, Vector3.ZERO, true))
	_range_ring.global_position = _commander.global_position + Vector3(0.0, 0.05, 0.0)
	_range_ring.scale = Vector3.ONE * _sword_reach()
	_update_info()


## Centre-to-centre distance at which the sword still reaches a target.
func _sword_reach() -> float:
	return _commander.get_stat(&"sword_range", 2.2) + _commander.TARGET_COLLIDER_PADDING


func _build_range_ring() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.98
	torus.outer_radius = 1.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.8, 0.2, 0.6)
	_range_ring = MeshInstance3D.new()
	_range_ring.mesh = torus
	_range_ring.material_override = mat
	add_child(_range_ring)


func _next_weapon(owned: bool) -> StringName:
	var start := WEAPON_ORDER.find(_run_state.equipped_weapon) if owned else -1
	for step in WEAPON_ORDER.size():
		var id := WEAPON_ORDER[(start + 1 + step) % WEAPON_ORDER.size()]
		if _run_state.owned_weapons.has(id) == owned:
			return id
	return &""


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return
	match event.physical_keycode:
		KEY_1:
			_cast_whirlwind()
		KEY_2:
			_sharpness = mini(_sharpness + 1, MAX_SHARPNESS)
			EventBus.reward_picked.emit(&"sharpness", &"PASSIVE", _sharpness)
			_log("Sharpness level %d: sword dealt x%.2f, Whirlwind dealt x%.2f" % [_sharpness, _commander.get_sword_dealt_mult(), _skill_dealt_mult()])
		KEY_3:
			_cap_on = not _cap_on
			if _cap_on:
				DamageCalc.set_cap_hook(func(info: DamageInfo, _t: Node) -> int:
					return CAP_VALUE if info.is_from_commander() else -1)
			else:
				DamageCalc.clear_cap_hook()
			_log("Per-hit cap %s" % ("ON (%d)" % CAP_VALUE if _cap_on else "OFF"))
		KEY_4:
			_dot_on = not _dot_on
			_dot_total = 0
			_dot_ticks = 0
			_log("Fire patch on Grunt A %s" % ("ON" if _dot_on else "OFF"))
		KEY_5:
			_test_hit(Enums.DamageType.PIERCE)
		KEY_6:
			_test_hit(Enums.DamageType.BLAST)
		KEY_F1:
			var id := _next_weapon(false)
			_log("Granted %s" % id if id != &"" and _run_state.grant_weapon(id) else "Every weapon is owned already")
		KEY_F2:
			var id := _next_weapon(true)
			if _run_state.equip_weapon(id):
				_log("Equipped %s: sword range %.2f m (+0.4 padding)" % [id, _commander.get_stat(&"sword_range", 2.2)])
			else:
				_log("Equip %s refused: state is %s, only PREP allows it" % [id, _run_state.get_current_state()])
		KEY_F3:
			_wave_state = &"PREP" if _wave_state == &"COMBAT" else &"COMBAT"
			EventBus.state_changed.emit(_wave_state)
			_log("State %s%s" % [_wave_state, " (weapons can change, the commander cannot fight)" if _wave_state == &"PREP" else " (the commander fights, weapons are locked)"])
		KEY_R:
			DamageCalc.clear_cap_hook()
			get_tree().reload_current_scene()


func _exit_tree() -> void:
	DamageCalc.clear_cap_hook()


func _skill_dealt_mult() -> float:
	return 1.0 + _commander.stat_block.get_mul_total(&"skill_damage")


func _cast_whirlwind() -> void:
	var hits := WhirlwindSkill.cast(_commander, WHIRLWIND_DATA, _whirlwind_level, _skill_dealt_mult())
	_log("Whirlwind lv%d: raw %d x dealt %.2f, radius %.0f m, hit %d dummies" % [
		_whirlwind_level, int(WHIRLWIND_DATA.get_value(&"damage", _whirlwind_level)),
		_skill_dealt_mult(), WHIRLWIND_DATA.get_value(&"radius", _whirlwind_level), hits])


func _test_hit(type: Enums.DamageType) -> void:
	var name_: String = Enums.DamageType.keys()[type]
	_log("Test %s hit, raw %d, on every dummy" % [name_, int(TEST_HIT_RAW)])
	for e in _grunts + [_bulwark]:
		var info := DamageInfo.outgoing(TEST_HIT_RAW, 1.0, type, _commander)
		var dealt: int = e.take_damage(info)
		if info.immune:
			_log("  %s: IMMUNE" % e.name)
		elif info.resist < 1.0:
			_log("  %s: %d (RESIST x%.1f)" % [e.name, dealt, info.resist])


func _spawn_dummy(scene: PackedScene, pos: Vector3, title: String) -> Enemy:
	var enemy := scene.instantiate() as Enemy
	add_child(enemy)
	enemy.position = pos
	enemy.name = title.replace(" ", "")
	enemy.spawn_grace = false
	enemy.is_in_spawn_zone = false
	enemy.set_physics_process(false)
	if scene != BULWARK_SCENE:
		enemy.health.max_hp = DUMMY_HP
		enemy.health.hp = DUMMY_HP
	enemy.health.damaged.connect(func(amount: int, info: DamageInfo) -> void:
		if info != null and info.is_dot:
			_dot_total += amount
			_dot_ticks += 1
			return
		_last_hit = "%d on %s" % [amount, title]
		_log("Hit %s for %d" % [title, amount])
	)
	var label := Label3D.new()
	label.text = title
	label.position = Vector3(0.0, 2.6, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.012
	label.font_size = 38
	label.outline_size = 8
	enemy.add_child(label)
	return enemy


func _update_info() -> void:
	if not is_instance_valid(_commander):
		return
	var block: StatBlock = _commander.stat_block
	var base: CharacterStats = _commander.stats
	var raw: float = block.get_base(&"sword_damage") + block.get_add_total(&"sword_damage")
	var dealt: float = _commander.get_sword_dealt_mult()
	var sword_hit := DamageCalc.hit(raw, dealt, 1.0, 1.0, false)
	var ww_raw: float = WHIRLWIND_DATA.get_value(&"damage", _whirlwind_level)
	var ww_dealt: float = _skill_dealt_mult()
	_info.text = """[DAMAGE FORMULA PLAYTEST]
SWORD   raw %.1f  x  dealt %.2f  =  %d per hit   (hit 3 of combo: %d)
        raw = base damage, dealt = 1 + Sharpness bonus (x%.2f at Sharpness %d)
WHIRLWIND  raw %d  x  dealt %.2f  =  %d on a normal enemy
        on Bulwark armour it is x0.6 (SLASH resist), applied once
LAST HIT  %s
CAP HOOK  %s   (when ON every commander hit is clamped to %d, like Hazard Trial)
FIRE PATCH  %s   ticks %d, total dealt %d
        each tick is 6 x 1.05 = 6.3, the .3 is kept in remainder (now %.2f) and paid later
BULWARK HP  %d / %d

[1] Whirlwind (3 m radius, walk next to a dummy)   [2] Sharpness +1 (max 3)
[3] Toggle cap   [4] Toggle fire patch on Grunt A
[5] PIERCE %d on all (Bulwark must be IMMUNE, no damage)
[6] BLAST %d on all (Bulwark armour takes full damage)
[F1] Grant next weapon   [F2] Equip next owned (PREP only)   [F3] Toggle PREP / COMBAT
WEAPON  %s   sword range %.2f m   ring radius %.2f m   state %s
        owned: %s
[R] Reset     [WASD] move     [Left click] sword""" % [
		raw, dealt, sword_hit, DamageCalc.hit(raw * base.combo_hit3_mult, dealt, 1.0, 1.0, false),
		dealt, _sharpness,
		int(ww_raw), ww_dealt, DamageCalc.hit(ww_raw, ww_dealt, 1.0, 1.0, false),
		_last_hit,
		"ON" if _cap_on else "OFF", CAP_VALUE,
		"ON" if _dot_on else "OFF", _dot_ticks, _dot_total, _grunts[0].health.dot_remainder,
		_bulwark.health.hp, _bulwark.health.max_hp,
		int(TEST_HIT_RAW), int(TEST_HIT_RAW),
		_run_state.equipped_weapon, _commander.get_stat(&"sword_range", 2.2), _sword_reach(), _run_state.get_current_state(),
		", ".join(_run_state.owned_weapons.map(func(w: StringName) -> String: return String(w))),
	]


func _log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > 10:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)
