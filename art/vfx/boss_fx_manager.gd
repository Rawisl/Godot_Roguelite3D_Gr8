class_name BossFxManager
extends Node
## Boss phase and Enrage effects on the Bulwark.
## - Armor break (boss_phase_changed TRANSITION): a burst of steam and armor plates flying off,
##   the core on the chest lights up orange, and the "Lộ lõi" banner. It stays lit while EXPOSED.
## - Enrage (boss_enraged): the core turns red and brighter, steam vents from the shoulders for
##   the rest of the fight, and the screen shakes once (scaled by the Accessibility setting).
## The core pulses slowly (well under 3 times a second) and holds steady with Reduced flashing.
## Steam is dithered (alpha hash), not alpha blended, so it never washes over the boss or
## fights the see-through shader. Particles run on game time: they follow x2 / x3 and stop
## while paused. The boss's music dips are in AudioManager.

const CORE_BONE := &"chest"
## Core position in front of the chest, in skeleton space (before the model's 0.75 scale).
const CORE_OFFSET := Vector3(0.0, 0.05, 0.85)
const SHOULDER_BONES: Array[StringName] = [&"upperarm.l", &"upperarm.r"]

@export_group("Core")
@export var core_radius: float = 0.3
@export var exposed_color: Color = Color("#FF9A2E")
@export var enraged_color: Color = Color("#FF2D2D")
## Glow of the core sphere itself.
@export var exposed_energy: float = 2.5
@export var enraged_energy: float = 5.0
## Light the core throws on the boss and the ground around it, kept low so it stays local.
@export var exposed_light: float = 0.8
@export var enraged_light: float = 1.4
## Pulses per second of the core glow. ACC-06 caps any blinking at 3 per second.
@export_range(0.0, 3.0) var pulse_rate: float = 1.0
@export_range(0.0, 3.0) var enraged_pulse_rate: float = 1.6
## Share of the glow the pulse takes away at its low point.
@export_range(0.0, 1.0) var pulse_depth: float = 0.35
@export var light_range: float = 3.0

@export_group("Armor break")
@export var plate_count: int = 14
@export var plate_speed := Vector2(4.0, 7.0)
@export var break_steam_count: int = 28
@export var break_shake: float = 0.0

@export_group("Enrage")
@export var vent_steam_count: int = 10
@export var enrage_shake: float = 0.6

var _boss: Node3D
var _rig: Dictionary = {}
var _phase := &""
var _enraged := false
var _reduce_flash := false


func _ready() -> void:
	_reduce_flash = GameState.get_setting(&"reduce_flash", false) == true
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	EventBus.boss_enraged.connect(_on_boss_enraged)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.settings_changed.connect(_on_settings_changed)


## The rig built on the current boss: core, light, burst emitters and vents. Empty until a boss exists.
func get_rig() -> Dictionary:
	_ensure_rig()
	return _rig


func is_core_lit() -> bool:
	return not _rig.is_empty() and is_instance_valid(_rig.core) and (_rig.core as Node3D).visible


func is_enraged() -> bool:
	return _enraged


## Current glow of the core, 0 when it is dark.
func get_core_energy() -> float:
	if not is_core_lit():
		return 0.0
	return (_rig.core_material as StandardMaterial3D).emission_energy_multiplier


## Light the core throws around it, 0 when it is dark.
func get_core_light() -> float:
	if not is_core_lit():
		return 0.0
	return (_rig.light as OmniLight3D).light_energy


func _process(_delta: float) -> void:
	if not is_core_lit():
		return
	var base := enraged_energy if _enraged else exposed_energy
	var rate := enraged_pulse_rate if _enraged else pulse_rate
	var energy := base
	if not _reduce_flash and rate > 0.0:
		# Game time, so the pulse holds while paused.
		var wave := 0.5 + 0.5 * cos(TimeManager.game_time * TAU * rate)
		energy = base * (1.0 - pulse_depth * wave)
	_set_core_energy(energy)


func _on_boss_spawned() -> void:
	_boss = null
	_rig = {}
	_phase = &""
	_enraged = false
	_ensure_rig()
	_apply_core()


func _on_boss_phase_changed(phase: StringName) -> void:
	var before := _phase
	_phase = phase
	if not _ensure_rig():
		return
	if phase == &"TRANSITION" and before != &"TRANSITION":
		_restart(_rig.plates)
		_restart(_rig.break_steam)
		EventBus.alert_requested.emit(int(Enums.AlertTier.T2), &"alert.boss_core_exposed", {})
		if break_shake > 0.0:
			EventBus.screen_shake_requested.emit(break_shake, &"boss_phase")
	_apply_core()


func _on_boss_enraged() -> void:
	if _enraged:
		return
	_enraged = true
	if _ensure_rig():
		for vent: CPUParticles3D in _rig.vents:
			vent.emitting = true
	EventBus.screen_shake_requested.emit(enrage_shake, &"enrage")
	_apply_core()


func _on_boss_defeated() -> void:
	if _rig.is_empty():
		return
	for vent: CPUParticles3D in _rig.vents:
		if is_instance_valid(vent):
			vent.emitting = false
	if is_instance_valid(_rig.core):
		(_rig.core as Node3D).visible = false


func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"reduce_flash":
		_reduce_flash = value == true


## The core shows from the armor break on; red once enraged, even if the armor still holds.
func _apply_core() -> void:
	if _rig.is_empty() or not is_instance_valid(_rig.core):
		return
	var lit := _enraged or _phase == &"TRANSITION" or _phase == &"EXPOSED"
	(_rig.core as Node3D).visible = lit
	var color := enraged_color if _enraged else exposed_color
	var mat := _rig.core_material as StandardMaterial3D
	mat.albedo_color = color
	mat.emission = color
	(_rig.light as OmniLight3D).light_color = color
	_set_core_energy(enraged_energy if _enraged else exposed_energy)


## The core's glow; the light follows the same pulse, scaled down to its own level.
func _set_core_energy(energy: float) -> void:
	(_rig.core_material as StandardMaterial3D).emission_energy_multiplier = energy
	var base := enraged_energy if _enraged else exposed_energy
	var light := enraged_light if _enraged else exposed_light
	(_rig.light as OmniLight3D).light_energy = light * energy / maxf(base, 0.001)


func _restart(p: CPUParticles3D) -> void:
	p.emitting = false
	p.restart()
	p.emitting = true


## Builds the rig on the first boss in group "boss". False when there is no boss.
func _ensure_rig() -> bool:
	if not _rig.is_empty() and is_instance_valid(_boss) and is_instance_valid(_rig.core):
		return true
	_rig = {}
	_boss = get_tree().get_first_node_in_group(&"boss") as Node3D if is_inside_tree() else null
	if _boss == null:
		return false
	var skeleton := _boss.find_children("*", "Skeleton3D", true, false)
	var sk := skeleton[0] as Skeleton3D if not skeleton.is_empty() else null

	var core_root := _attach(sk, CORE_BONE, CORE_OFFSET, Vector3(0, 2.1, 0.55))
	core_root.name = "BossCoreFx"
	var core := MeshInstance3D.new()
	core.name = "Core"
	var sphere := SphereMesh.new()
	sphere.radius = core_radius
	sphere.height = core_radius * 2.0
	core.mesh = sphere
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.emission_enabled = true
	core.material_override = core_mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core_root.add_child(core)
	var light := OmniLight3D.new()
	light.omni_range = light_range
	light.shadow_enabled = false
	core.add_child(light)
	core.visible = false

	var plates := _make_plates()
	core_root.add_child(plates)
	var break_steam := _make_steam(break_steam_count, true)
	core_root.add_child(break_steam)

	var vents: Array[CPUParticles3D] = []
	for bone in SHOULDER_BONES:
		var at := _attach(sk, bone, Vector3(0, 0.25, -0.2), Vector3(0, 2.6, -0.2))
		at.name = "BossVentFx_%s" % bone.replace(".", "_")
		var vent := _make_steam(vent_steam_count, false)
		at.add_child(vent)
		vents.append(vent)

	_rig = {
		"core": core, "core_material": core_mat, "light": light,
		"plates": plates, "break_steam": break_steam, "vents": vents,
	}
	return true


## A node that follows the bone, offset in skeleton space; without a skeleton, a fixed
## point on the boss.
func _attach(sk: Skeleton3D, bone: StringName, offset: Vector3, fallback: Vector3) -> Node3D:
	var idx := sk.find_bone(bone) if sk != null else -1
	if idx < 0:
		var fixed := Node3D.new()
		_boss.add_child(fixed)
		fixed.position = fallback
		return fixed
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone
	sk.add_child(attachment)
	var holder := Node3D.new()
	attachment.add_child(holder)
	# Offset given in skeleton space, turned into the bone's own frame.
	holder.position = sk.get_bone_global_pose(idx).basis.inverse() * offset
	return holder


func _make_plates() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "ArmorPlates"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = plate_count
	p.lifetime = 1.6
	p.local_coords = false
	var box := BoxMesh.new()
	box.size = Vector3(0.38, 0.38, 0.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#6E6A64")
	mat.metallic = 0.6
	mat.roughness = 0.5
	box.material = mat
	p.mesh = box
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.direction = Vector3(0, 1, 0.6)
	p.spread = 70.0
	p.initial_velocity_min = plate_speed.x
	p.initial_velocity_max = plate_speed.y
	p.gravity = Vector3(0, -12, 0)
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.particle_flag_rotate_y = true
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.75, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	return p


## A burst of steam (one shot) or a vent that keeps puffing while emitting.
func _make_steam(count: int, burst: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "SteamBurst" if burst else "SteamVent"
	p.emitting = false
	p.one_shot = burst
	p.explosiveness = 0.8 if burst else 0.0
	p.amount = count
	p.lifetime = 1.4 if burst else 1.0
	p.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Dithered cut-out instead of a blend: no sorting against the boss or the see-through shader.
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _puff_texture()
	quad.material = mat
	p.mesh = quad
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.7 if burst else 0.15
	p.direction = Vector3(0, 1, 0)
	p.spread = 60.0 if burst else 20.0
	p.initial_velocity_min = 1.5 if burst else 1.8
	p.initial_velocity_max = 3.0 if burst else 2.6
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.gravity = Vector3(0, 0.6, 0)
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.8))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.92, 0.92, 0.9, 0.9))
	fade.set_color(1, Color(0.8, 0.8, 0.8, 0.0))
	p.color_ramp = fade
	return p


## Soft round puff: alpha falls off from the centre, so the dither reads as a cloud.
func _puff_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex
