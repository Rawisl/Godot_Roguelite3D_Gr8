extends Node3D
## Manual playtest for the shared damage formula. Not shipped. Run with F6.
## Swing at the dummies to feel sword damage, cast Whirlwind (same call SkillRunner makes), stack
## Sharpness, switch the per-hit cap and the fire patch on and off, and fire non-sword hits at
## the Bulwark to see RESIST and IMMUNE, and put Slow and Burn on the dummies. Floating damage
## numbers are on, so a sword swing at the armoured Bulwark shows RESIST and a PIERCE hit shows
## IMMUNE. Keys here are test-only, game input is untouched.

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
const SLOW_PCT := 0.20
const SLOW_TIME := 3.0
const BURN_PCT := 0.50
const BURN_TIME := 5.0
const WALK_LIMIT := 9.0

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
var _walking: bool = false
var _walk_dir: Vector3 = Vector3.RIGHT
var _burn_ticks: int = 0
var _burn_total: int = 0
var _titles: Dictionary = {}  # Enemy -> title shown on its label
var _log_lines: Array[String] = []

@onready var _info: Label = %InfoLabel
@onready var _log_label: Label = %LogLabel
@onready var _rig: Node3D = %CameraRig


func _ready() -> void:
	_commander = COMMANDER_SCENE.instantiate() as CharacterBody3D
	add_child(_commander)
	_grunts.append(_spawn_dummy(GRUNT_SCENE, Vector3(3.0, 0.0, 0.0), "Grunt A"))
	_grunts.append(_spawn_dummy(GRUNT_SCENE, Vector3(3.0, 0.0, 3.0), "Grunt B"))
	_grunts.append(_spawn_dummy(GRUNT_SCENE, Vector3(-4.0, 0.0, 0.0), "Grunt C"))
	_bulwark = _spawn_dummy(BULWARK_SCENE, Vector3(0.0, 0.0, -5.0), "Bulwark")
	var numbers := CanvasLayer.new()
	numbers.add_child(DamageNumberLayer.new())
	add_child(numbers)
	EventBus.mode_changed.emit(&"FRONTLINE")
	EventBus.state_changed.emit(&"COMBAT")
	_log("Ready. Swing with left click, keys 1-9 run the tests.")


func _physics_process(delta: float) -> void:
	# The dummies have their own physics off, so their status clocks are run from here.
	for e in _all_dummies():
		e._tick_status(delta)
	if not _walking:
		return
	var walker := _grunts[2]
	if walker.global_position.x > WALK_LIMIT:
		_walk_dir = Vector3.LEFT
	elif walker.global_position.x < -WALK_LIMIT:
		_walk_dir = Vector3.RIGHT
	walker._move_towards_direction(_walk_dir)
	walker.velocity.y = 0.0
	walker.move_and_slide()


func _process(delta: float) -> void:
	if is_instance_valid(_commander):
		_rig.global_position = _rig.global_position.lerp(_commander.global_position, clampf(delta * 6.0, 0.0, 1.0))
	if _dot_on:
		_dot_timer += delta
		while _dot_timer >= DOT_INTERVAL:
			_dot_timer -= DOT_INTERVAL
			_grunts[0].take_damage(DamageInfo.outgoing(DOT_RAW, DOT_DEALT, Enums.DamageType.BLAST, _commander, 0.0, Vector3.ZERO, true))
	for e: Enemy in _titles:
		var status := _status_text(e)
		(e.get_node("TitleLabel") as Label3D).text = _titles[e] if status.is_empty() else "%s
%s" % [_titles[e], status]
	_update_info()


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
		KEY_7:
			_apply_slow()
		KEY_8:
			_apply_burn()
		KEY_9:
			_walking = not _walking
			_grunts[2].velocity = Vector3.ZERO
			_log("Grunt C walking %s" % ("ON (press 7 to see it slow down)" if _walking else "OFF"))
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


func _all_dummies() -> Array[Enemy]:
	var all: Array[Enemy] = []
	all.append_array(_grunts)
	all.append(_bulwark)
	return all


func _apply_slow() -> void:
	_log("Slow %d%% for %.0f s on every dummy (a second press only resets the time)" % [SLOW_PCT * 100.0, SLOW_TIME])
	for e in _all_dummies():
		if not e.apply_slow(SLOW_PCT, SLOW_TIME, Enums.DamageType.SLASH):
			_log("  %s: refused" % e.name)


func _apply_burn() -> void:
	var block: StatBlock = _commander.stat_block
	var base: float = block.get_base(&"sword_damage") + block.get_add_total(&"sword_damage")
	var total := base * BURN_PCT
	_burn_ticks = 0
	_burn_total = 0
	_log("Burn %.1f over %.0f s (%d%% of sword raw %.1f, x dealt %.2f) on every dummy" % [
		total, BURN_TIME, BURN_PCT * 100.0, base, _commander.get_sword_dealt_mult()])
	for e in _all_dummies():
		if not e.apply_burn(total, BURN_TIME, Enums.DamageType.BLAST, _commander, _commander.get_sword_dealt_mult()):
			_log("  %s: refused" % e.name)


func _status_text(e: Enemy) -> String:
	var parts := PackedStringArray()
	if e.slow_timer > 0.0:
		parts.append("SLOW x%.2f %.1fs" % [e.get_slow_factor(), e.slow_timer])
	if e.burn_timer > 0.0:
		parts.append("BURN %.1f/tick %.1fs" % [e.burn_per_tick, e.burn_timer])
	return "
".join(parts)


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
		if info != null and info.is_dot and enemy.burn_per_tick > 0.0 and is_equal_approx(info.raw, enemy.burn_per_tick):
			_burn_ticks += 1
			_burn_total += amount
			return
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
	label.name = "TitleLabel"
	enemy.add_child(label)
	_titles[enemy] = title
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
BURN  ticks %d, total dealt %d, all dummies   (5 ticks each of 50%% sword raw, dot_remainder keeps the fractions)
BULWARK HP  %d / %d

[1] Whirlwind (3 m radius, walk next to a dummy)   [2] Sharpness +1 (max 3)
[3] Toggle cap   [4] Toggle fire patch on Grunt A
[5] PIERCE %d on all (Bulwark must be IMMUNE, no damage)
[6] BLAST %d on all (Bulwark armour takes full damage)
[7] Slow 20%% 3 s on all   [8] Burn 50%% sword raw over 5 s on all   [9] Grunt C walks (watch Slow)
Sword on the armoured Bulwark: grey RESIST number.  [5] on the Bulwark: IMMUNE number.
[R] Reset     [WASD] move     [Left click] sword""" % [
		raw, dealt, sword_hit, DamageCalc.hit(raw * base.combo_hit3_mult, dealt, 1.0, 1.0, false),
		dealt, _sharpness,
		int(ww_raw), ww_dealt, DamageCalc.hit(ww_raw, ww_dealt, 1.0, 1.0, false),
		_last_hit,
		"ON" if _cap_on else "OFF", CAP_VALUE,
		"ON" if _dot_on else "OFF", _dot_ticks, _dot_total, _grunts[0].health.dot_remainder,
		_burn_ticks, _burn_total,
		_bulwark.health.hp, _bulwark.health.max_hp,
		int(TEST_HIT_RAW), int(TEST_HIT_RAW),
	]


func _log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > 10:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)
