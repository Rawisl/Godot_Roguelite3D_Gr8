extends Node3D
## Accessibility checks: nothing in the shipped effects and HUD blinks faster than 3 times a second,
## Reduce flashing removes the white core of the cannon blast, and every enemy trait has an icon
## that is drawn next to its name. Not shipped. Run with F6 or headless, prints OK/FAIL then quits.

const MAX_RATE := 3.0
const BLAST := preload("res://art/vfx/cannon_blast.tscn")
const FORTRESS_BAR := preload("res://ui/hud/parts/fortress_bar.gd")

var _pass := 0
var _fail := 0


func _ready() -> void:
	_test_rates()
	await _test_cannon_flash()
	_test_trait_icons()
	EventBus.settings_changed.emit(&"reduce_flash", false)
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


## Blinks and pulses per second of every repeating effect, from its shipped values.
func _test_rates() -> void:
	var bar = FORTRESS_BAR.new()
	_check("Fortress low HP border: %.2f blinks a second" % (1.0 / bar.blink_period), 1.0 / bar.blink_period <= MAX_RATE)
	bar.free()
	var boss := BossFxManager.new()
	_check("boss core pulse: %.1f and %.1f a second" % [boss.pulse_rate, boss.enraged_pulse_rate],
		boss.pulse_rate <= MAX_RATE and boss.enraged_pulse_rate <= MAX_RATE)
	boss.free()
	for path in ["res://art/materials/aura_ring.tres", "res://art/materials/heal_ring.tres", "res://art/materials/slot_ring.tres"]:
		var speed := float((load(path) as ShaderMaterial).get_shader_parameter(&"pulse_speed"))
		_check("%s pulse: %.2f a second" % [path.get_file(), speed / TAU], speed / TAU <= MAX_RATE)
	var beam := float((load("res://art/materials/heal_beam.tres") as ShaderMaterial).get_shader_parameter(&"band_speed"))
	_check("heal beam bands: %.1f a second" % beam, beam <= MAX_RATE)
	var fire_value: Variant = (load("res://art/materials/skill_fire_zone.tres") as ShaderMaterial).get_shader_parameter(&"flicker_hz")
	if fire_value == null:
		# Not set on the material: the shader's own default.
		var code := (load("res://art/shaders/skill_fire_zone.gdshader") as Shader).code
		var found := RegEx.create_from_string("uniform float flicker_hz = ([0-9.]+)").search(code)
		fire_value = found.get_string(1).to_float() if found != null else INF
	var hz := float(fire_value)
	_check("fire zone flicker: %.1f a second" % hz, hz <= MAX_RATE)


func _test_cannon_flash() -> void:
	var blast: CannonBlast = BLAST.instantiate()
	add_child(blast)
	EventBus.settings_changed.emit(&"reduce_flash", false)
	blast.play(Vector3.ZERO, Vector3.DOWN, 2.0)
	_check("normal: the cannon core starts white", blast._core_mat.albedo_color.is_equal_approx(blast.core_color_hot))
	await get_tree().create_timer(0.6).timeout
	EventBus.settings_changed.emit(&"reduce_flash", true)
	blast.play(Vector3.ZERO, Vector3.DOWN, 2.0)
	_check("Reduce flashing: the cannon core starts at the fire colour",
		blast._core_mat.albedo_color.is_equal_approx(blast.core_color_fire))
	blast.queue_free()


func _test_trait_icons() -> void:
	var all_icons := true
	for id in EnemyTraits.ALL:
		var icon: Texture2D = TraitGlyph.ICONS.get(id)
		all_icons = all_icons and icon != null and icon.get_width() >= 26
	_check("every trait has an icon at least 26 px", all_icons)
	var distinct := {}
	for id in EnemyTraits.ALL:
		distinct[TraitGlyph.ICONS[id]] = true
	_check("each trait has its own icon", distinct.size() == EnemyTraits.ALL.size())
	var badge: TraitBadge = load("res://ui/hud/parts/trait_badge.tscn").instantiate() if ResourceLoader.exists("res://ui/hud/parts/trait_badge.tscn") else null
	if badge != null:
		add_child(badge)
		badge.show_trait(EnemyTraits.STEALTH)
		_check("a badge shows the trait name next to the icon", badge._name.text != "" and badge._glyph.trait_id == EnemyTraits.STEALTH)
		badge.free()


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("OK   ", label)
	else:
		_fail += 1
		print("FAIL ", label)
