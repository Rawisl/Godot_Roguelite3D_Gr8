class_name WeaponBladeFx
extends Node3D
## Root of a weapon model scene: the sword mesh plus the effect along its blade.
## - Frost: snow drifting off the blade. Chain Lightning: small violet sparks. Burn: embers.
## - Swift: particles left in world space, so a swing draws a fast streak behind the blade.
## - Rampage: dark red embers rise off the blade at all times; the blade glows and the embers thicken
##   as the commander's HP drops through the three Rampage
##   bands of the weapon data, and a mark with one, two or three chevrons over the commander's head
##   shows the band, so the band never reads from colour alone.
## The particles count toward the shared particle budget. "Reduce flashing" thins the sparks and
## keeps the Rampage glow steady at a lower level.

enum Kind { FROST, CHAIN, BURN, RAMPAGE, SWIFT }

const RAMPAGE_DATA := "res://data/weapons/rampage.tres"

@export var kind := Kind.FROST
## Blade span in the mesh's own units, from the guard to the tip.
@export var blade_from := 0.35
@export var blade_to := 1.35
@export var color_start := Color.WHITE
@export var color_end := Color(1, 1, 1, 0)
@export var amount := 10
@export var lifetime := 0.7
@export var particle_size := 0.06
## Rampage: emission energy of the blade for no band, then bands 1, 2 and 3.
@export var rampage_glow: PackedFloat32Array = [0.4, 1.0, 2.0, 3.2]
@export var rampage_mark_color := Color(1.0, 0.25, 0.15)
@export var rampage_mark_height := 2.3

var _particles: GPUParticles3D
var _blade_material: StandardMaterial3D
var _commander: Node3D
var _rampage: WeaponData
var _band := -1
var _mark: Label3D
var _reduce_flash := false


func _ready() -> void:
	add_to_group(ParticleBudget.GROUP)
	_reduce_flash = GameState.get_setting(&"reduce_flash", false) == true
	EventBus.settings_changed.connect(_on_settings_changed)
	_particles = _make_particles()
	add_child(_particles)
	if kind == Kind.RAMPAGE:
		_blade_material = _find_blade_material()
		_rampage = load(RAMPAGE_DATA) as WeaponData
	_apply_flash_setting()


func _exit_tree() -> void:
	if is_instance_valid(_mark):
		_mark.queue_free()


func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"reduce_flash":
		_reduce_flash = value == true
		_apply_flash_setting()


func _apply_flash_setting() -> void:
	if _particles == null:
		return
	var base := amount
	if kind == Kind.RAMPAGE:
		base = amount * (maxi(_band, 0) + 1)
	_particles.amount = maxi(base / 2 if _reduce_flash and kind == Kind.CHAIN else base, 1)
	_particles.emitting = base > 0
	_band = _band if kind == Kind.RAMPAGE else 0
	if kind == Kind.RAMPAGE and _band >= 0:
		_set_band(_band, true)


func _process(_delta: float) -> void:
	if kind != Kind.RAMPAGE:
		return
	var ratio := _commander_hp_ratio()
	_set_band(rampage_band(ratio, _rampage), false)
	if is_instance_valid(_mark) and is_instance_valid(_commander):
		_mark.global_position = _commander.global_position + Vector3.UP * rampage_mark_height


## 0 above the top band, then 1, 2, 3 as HP drops, from the Rampage thresholds of the weapon data.
static func rampage_band(ratio: float, data: WeaponData) -> int:
	if data == null:
		return 0
	if ratio <= data.get_param(&"rampage_hp_lo"):
		return 3
	if ratio <= data.get_param(&"rampage_hp_mid"):
		return 2
	if ratio <= data.get_param(&"rampage_hp_hi"):
		return 1
	return 0


func _set_band(band: int, force: bool) -> void:
	if band == _band and not force:
		return
	_band = band
	if _blade_material != null:
		var glow := rampage_glow[clampi(band, 0, rampage_glow.size() - 1)]
		_blade_material.emission_energy_multiplier = glow * (0.5 if _reduce_flash else 1.0)
	if _particles != null:
		# Embers always rise off the blade; each lower band adds more.
		_particles.amount = maxi(amount * (band + 1), 1)
		_particles.emitting = true
	_update_mark(band)


func _update_mark(band: int) -> void:
	if band <= 0 or not is_inside_tree():
		if is_instance_valid(_mark):
			_mark.visible = false
		return
	if not is_instance_valid(_mark):
		_mark = Label3D.new()
		_mark.name = "RampageMark"
		_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_mark.no_depth_test = true
		_mark.fixed_size = false
		_mark.pixel_size = 0.01
		_mark.font_size = 48
		_mark.outline_size = 10
		_mark.modulate = rampage_mark_color
		# Outside the hand bone so the mark stays upright over the head.
		var holder: Node = get_tree().current_scene
		if holder == null:
			holder = get_tree().root
		holder.add_child(_mark)
	_mark.text = "^".repeat(band)
	_mark.visible = true


func _commander_hp_ratio() -> float:
	if not is_instance_valid(_commander):
		var node: Node = self
		while node != null and not node.is_in_group(&"commander"):
			node = node.get_parent()
		_commander = node as Node3D
	if _commander == null or not ("health" in _commander):
		return 1.0
	var health: Variant = _commander.get("health")
	return health.get_health_ratio() if health != null else 1.0


func _find_blade_material() -> StandardMaterial3D:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(i) as StandardMaterial3D
			if mat != null and String(mat.resource_name).ends_with("_blade"):
				var own := mat.duplicate() as StandardMaterial3D
				own.emission_enabled = true
				mesh.set_surface_override_material(i, own)
				return own
	return null


func _make_particles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "BladeParticles"
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	p.local_coords = kind != Kind.SWIFT and kind != Kind.BURN
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.08, (blade_to - blade_from) * 0.5, 0.02)
	p.position = Vector3(0, (blade_from + blade_to) * 0.5, 0)
	match kind:
		Kind.FROST:
			process.gravity = Vector3(0, -0.6, 0)
			process.initial_velocity_max = 0.15
		Kind.CHAIN:
			process.gravity = Vector3.ZERO
			process.spread = 180.0
			process.initial_velocity_min = 0.6
			process.initial_velocity_max = 1.4
		Kind.BURN, Kind.RAMPAGE:
			process.direction = Vector3.UP
			process.gravity = Vector3(0, 1.2, 0)
			process.initial_velocity_min = 0.2
			process.initial_velocity_max = 0.5
		Kind.SWIFT:
			process.gravity = Vector3.ZERO
	var curve := CurveTexture.new()
	curve.curve = Curve.new()
	curve.curve.add_point(Vector2(0, 1))
	curve.curve.add_point(Vector2(1, 0))
	process.scale_curve = curve
	var ramp := GradientTexture1D.new()
	ramp.gradient = Gradient.new()
	ramp.gradient.set_color(0, color_start)
	ramp.gradient.set_color(1, color_end)
	process.color_ramp = ramp
	p.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * particle_size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mat
	p.draw_pass_1 = quad
	return p


func active_particles() -> int:
	return _particles.amount if _particles != null and _particles.emitting else 0


## Current Rampage band, -1 before the first update. For tests.
func get_band() -> int:
	return _band


## The Rampage mark node, or null. For tests.
func get_mark() -> Label3D:
	return _mark
