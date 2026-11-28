class_name SkillFxManager
extends Node
## Visuals for the commander's active skills, one effect per EventBus.skill_cast:
## - Whirlwind: two sweeps of the sword, ring-shaped trails out to the skill radius that follow
##   the commander's sword through the spinning swing and fade when it ends; sparks fly in from
##   the edge
## - Sword Wave: a wide shallow crescent drawn like one Whirlwind sweep, a bright blade with a
##   trail fading behind it and sparks streaming back from the blade; it flies from the commander
##   along its aim, and stops early at a wall
## - Firebomb: a bomb arcs from the commander to the cast point, then the burn area and its
##   embers stay for the burn time
## What skill_cast carries: origin is the commander's position for Whirlwind and Sword Wave and
## the landing point for Firebomb; radius is the Whirlwind radius and the Firebomb burn radius.
## Sword Wave takes its direction from the commander's aim_dir.
## Other sizes come from the skill's SkillData in data/skills/ when it has the value, otherwise
## from the fallbacks here. Runs on game time: follows x2 / x3 and holds while paused.
## Whirlwind and Sword Wave take their colours from the equipped sword (EventBus.weapon_equipped):
## the material of the skill is cloned once per sword and recoloured from that sword's SkillPalette.
## An effect keeps the material it was made with, so changing sword never recolours one in flight.
## Whirlwind and Sword Wave lie flat; when the camera looks at one flatter than min_view_angle it
## tilts up towards the camera, each at most its own max tilt. Sword Wave also rises so no corner
## dips into the floor. Whirlwind sits at the middle of the commander and turns about its centre
## only a few degrees, little enough that its edge never reaches the floor.
## Nothing is added to the commander scene.

const SKILL_DIR := "res://data/skills/%s.tres"
## Points along the crescent where Sword Wave sparks start.
const WAVE_SPARK_POINTS := 12
## How far across the arc the spark points reach, as a part of its half width.
const WAVE_SPARK_SPAN := 0.9
## The sword whose palette is used before any sword is announced and for swords with no palette.
const BASE_WEAPON := &"sword_base"
## skill_cast comes before the commander marks itself as using the skill, so its swing is not
## checked for this long after the cast.
const SWING_GRACE := 0.05
## Rounds of tilt-then-lift; each round works the tilt out again from the last lifted spot.
const TILT_PASSES := 6

@export_group("Palettes")
## Colours of Whirlwind and Sword Wave per sword id; tuned in art/materials/palettes/.
@export var palettes: Dictionary = {
	&"sword_base": preload("res://art/materials/palettes/skill_palette_sword_base.tres"),
	&"frost": preload("res://art/materials/palettes/skill_palette_frost.tres"),
	&"chain_lightning": preload("res://art/materials/palettes/skill_palette_chain_lightning.tres"),
	&"burn": preload("res://art/materials/palettes/skill_palette_burn.tres"),
	&"rampage": preload("res://art/materials/palettes/skill_palette_rampage.tres"),
	&"swift": preload("res://art/materials/palettes/skill_palette_swift.tres"),
}

@export_group("Whirlwind")
## Trail shape is tuned in this material, its colours come from the palette of the equipped
## sword; radius, sweep, fade and flicker are set per sweep.
@export var whirlwind_material: ShaderMaterial = preload("res://art/materials/skill_whirlwind.tres")
## Height of the blades above the floor: the middle of the commander (its capsule centre).
@export var whirlwind_height := 0.9
## The most the blades tilt towards a low camera, in degrees (see min_view_angle). The disc turns
## about its centre, so its edge moves about radius x sin(this) up or down; keep that under
## whirlwind_height so it never cuts into the floor.
@export_range(0.0, 90.0) var whirlwind_max_tilt := 5.0
## Sparks thrown in from the edge, how long they live, and their speed in metres per second.
@export var whirlwind_spark_count := 15
@export var whirlwind_spark_lifetime := 0.18
@export var whirlwind_spark_speed_min := 0.8
@export var whirlwind_spark_speed_max := 1.6
## How much the sparks swirl along the spin instead of flying straight at the commander, 0..1.
@export var whirlwind_spark_swirl := 0.6
## The sweeps, one value per sweep in each list (the shorter list sets how many): seconds after
## the cast it starts, where the sword is at that moment, and its size as a part of the skill
## radius.
@export var whirlwind_sweep_delays := PackedFloat32Array([0.0, 0.3])
@export var whirlwind_sweep_scales := PackedFloat32Array([1.0, 1.1])
## Seconds a new sweep takes to grow to full size, and the size it starts at as a part of it.
@export var whirlwind_form_time := 0.15
@export var whirlwind_start_scale := 0.35
## Seconds the sweeps take to fade once the commander's swing ends.
@export var whirlwind_fade_time := 0.2
## Without a sword to follow (or a commander to say when the swing ends): how long the swing
## lasts and how fast the sweeps turn, clockwise seen from above, in degrees per second. The
## defaults match the commander's spinning swing.
@export var whirlwind_swing_time := 0.5
@export var whirlwind_spin_speed := 1800.0
## Metres along the sword from the hand to the point the sweeps follow.
@export var whirlwind_blade_reach := 1.0

@export_group("Sword Wave")
@export var wave_material: ShaderMaterial = preload("res://art/materials/skill_sword_wave.tres")
## The most the wave tilts towards a low camera, in degrees, even when the camera looks up at it.
@export_range(0.0, 90.0) var wave_max_tilt := 45.0
## Used while data/skills/sword_wave.tres has no width or range, or GameConfig no speed.
@export var fallback_wave_width := 3.0
@export var fallback_wave_distance := 4.0
@export var fallback_wave_speed := 20.0
## The wave appears this far in front of the commander.
@export var wave_start_offset := 0.5
## Height of the wave above the floor.
@export var wave_height := 0.6
## The wave stops where a ray at this height hits something on these layers (1 = world).
@export_flags_3d_physics var wave_stop_mask := 1
## Sparks per metre of wave width, and how long and how fast they fly back from the wave.
@export var wave_spark_density := 6.0
@export var wave_spark_lifetime := 0.25
@export var wave_spark_speed_min := 2.0
@export var wave_spark_speed_max := 4.5

@export_group("Firebomb")
@export var fire_material: ShaderMaterial = preload("res://art/materials/skill_fire_zone.tres")
@export var bomb_material: Material = preload("res://art/materials/skill_firebomb.tres")
## Used while data/skills/firebomb.tres has no duration.
@export var fallback_burn_time := 4.0
## Seconds the bomb is in the air, and how high its arc goes.
@export var throw_time := 0.3
@export var throw_height := 2.0
@export var bomb_radius := 0.18
## Height of the commander's hand, where the bomb starts.
@export var hand_height := 1.2
@export var ember_color := Color("#FFB347")
## Embers per square metre of burn area.
@export var ember_density := 2.5

@export_group("Shared")
## Seconds to fade out at the end of every effect. Fades, never blinks.
@export var fade_time := 0.2
## Height above the floor for flat effects.
@export var ground_lift := 0.05
## Whirlwind and Sword Wave tilt up towards the camera when it looks at them flatter than this
## many degrees, so a low chase camera still sees them. 0 keeps them flat.
@export_range(0.0, 90.0) var min_view_angle := 25.0
## Room outside the radius for the soft edge.
@export var ring_margin := 0.3
## The shared particle limit (ParticleBudget). Over it, dust, embers and sparks are skipped; the
## effects themselves always play.
var particle_budget: int:
	get: return ParticleBudget.limit
	set(value): ParticleBudget.limit = value

var _effects: Array[Dictionary] = []
var _skill_data: Dictionary = {}  # StringName -> SkillData, or null when there is no file
var _commander: Node3D
var _particle_mesh: SphereMesh
var _spark_mesh: SphereMesh
var _flicker := 1.0
var _weapon_id := BASE_WEAPON
var _material_cache: Dictionary = {}  # "<skill>:<weapon id>" -> ShaderMaterial


func _ready() -> void:
	add_to_group(ParticleBudget.GROUP)
	# A small sphere like the SwordHit dust. Billboard particles draw a black square at the
	# emitter on the Compatibility renderer.
	_particle_mesh = SphereMesh.new()
	_particle_mesh.radius = 0.06
	_particle_mesh.height = 0.12
	_particle_mesh.radial_segments = 6
	_particle_mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	_particle_mesh.material = mat
	# A long thin sphere, turned along the flight so each spark leaves a streak.
	_spark_mesh = SphereMesh.new()
	_spark_mesh.radius = 0.03
	_spark_mesh.height = 0.3
	_spark_mesh.radial_segments = 6
	_spark_mesh.rings = 3
	_spark_mesh.material = mat
	_set_reduce_flash(GameState.get_setting(&"reduce_flash", false) == true)
	EventBus.skill_cast.connect(_on_skill_cast)
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.run_started.connect(clear)
	EventBus.weapon_equipped.connect(_on_weapon_equipped)


func _on_weapon_equipped(weapon_id: StringName) -> void:
	_weapon_id = weapon_id


func _on_skill_cast(skill_id: StringName, _slot: int, level: int, origin: Vector3, radius: float) -> void:
	match skill_id:
		&"whirlwind":
			play_whirlwind(origin, radius, _aim_dir())
		&"sword_wave":
			play_sword_wave(origin, _aim_dir(),
				_value(skill_id, &"width", level, fallback_wave_width),
				_value(skill_id, &"range", level, fallback_wave_distance),
				_wave_speed())
		&"firebomb":
			var c := _get_commander()
			var from := c.global_position if c != null else origin
			play_firebomb(from, origin, radius, _value(skill_id, &"duration", level, fallback_burn_time))


func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"reduce_flash":
		_set_reduce_flash(value == true)


## The palette of the equipped sword, the base sword's when that sword has none.
func current_palette() -> SkillPalette:
	var palette := palettes.get(_weapon_id) as SkillPalette
	if palette == null:
		palette = palettes.get(BASE_WEAPON) as SkillPalette
	return palette


## base cloned and coloured for the equipped sword, made once per skill and sword.
func _skill_material(skill_id: StringName, base: ShaderMaterial) -> ShaderMaterial:
	var palette := current_palette()
	if palette == null:
		return base
	var weapon := _weapon_id if palettes.get(_weapon_id) is SkillPalette else BASE_WEAPON
	var key := "%s:%s" % [skill_id, weapon]
	var cached := _material_cache.get(key) as ShaderMaterial
	if cached != null:
		return cached
	var material := base.duplicate() as ShaderMaterial
	palette.apply_to(material)
	_material_cache[key] = material
	return material


func _spark_color() -> Color:
	var palette := current_palette()
	return palette.spark if palette != null else Color.WHITE


func _set_reduce_flash(on: bool) -> void:
	_flicker = 0.0 if on else 1.0


#region Whirlwind
## start_dir is where the sword starts when there is no sword to follow; the sweeps turn
## clockwise from there.
func play_whirlwind(origin: Vector3, radius: float, start_dir := Vector3.RIGHT) -> void:
	var rings: Array[MeshInstance3D] = []
	var start_head := atan2(-start_dir.z, start_dir.x)
	var fx := {"kind": &"whirlwind", "mesh": null, "rings": rings, "elapsed": 0.0, "radius": radius,
		"at": origin + Vector3.UP * whirlwind_height, "start_head": start_head, "head": start_head,
		"sweeps": [], "fade_from": -1.0, "sword": _sword_of_commander()}
	fx.head = _whirlwind_head(fx)
	_spawn_due_sweeps(fx)
	if _has_room(whirlwind_spark_count):
		fx["particles"] = _whirlwind_sparks(whirlwind_spark_count, radius, origin)
	_effects.append(fx)


## Number of sweeps: the shorter of the two sweep lists.
func whirlwind_sweep_count() -> int:
	return mini(whirlwind_sweep_delays.size(), whirlwind_sweep_scales.size())


## Longest a Whirlwind lasts when nothing says the swing ended earlier: the swing plus the fade.
func whirlwind_time() -> float:
	return whirlwind_swing_time + whirlwind_fade_time


## The node holding the commander's sword, null when there is none to follow.
func _sword_of_commander() -> Node3D:
	var c := _get_commander()
	if c == null:
		return null
	for node in get_tree().get_nodes_in_group(&"weapon_mount"):
		if node is Node3D and c.is_ancestor_of(node):
			return node
	return null


## Angle round the centre, counter-clockwise from +X seen from above, of the point on the sword
## the sweeps follow; without a sword, the start angle turned clockwise at whirlwind_spin_speed.
func _whirlwind_head(fx: Dictionary) -> float:
	var sword: Node3D = fx.sword
	if sword != null and is_instance_valid(sword):
		var tip := sword.global_position + sword.global_basis.y.normalized() * whirlwind_blade_reach
		var rel: Vector3 = tip - fx.at
		if Vector2(rel.x, rel.z).length_squared() > 0.0001:
			return atan2(-rel.z, rel.x)
	var spun := deg_to_rad(whirlwind_spin_speed) * minf(fx.elapsed, whirlwind_swing_time)
	return fx.start_head - spun


## True once the commander's swing is over, so the sweeps start to fade.
func _swing_over(fx: Dictionary) -> bool:
	if fx.elapsed >= whirlwind_swing_time * 2.0:
		return true
	var c := _get_commander()
	if c == null or not ("is_using_skill" in c):
		return fx.elapsed >= whirlwind_swing_time
	return fx.elapsed > SWING_GRACE and not c.is_using_skill


## Starts every sweep whose delay has passed, at the sword.
func _spawn_due_sweeps(fx: Dictionary) -> void:
	var sweeps: Array = fx.sweeps
	while sweeps.size() < whirlwind_sweep_count() and fx.elapsed >= whirlwind_sweep_delays[sweeps.size()]:
		var i := sweeps.size()
		var reach: float = whirlwind_material.get_shader_parameter(&"outer_reach")
		var mesh := _flat_mesh(_skill_material(&"whirlwind", whirlwind_material), fx.radius * reach + ring_margin)
		mesh.global_position = fx.at
		mesh.set_instance_shader_parameter(&"radius", fx.radius)
		mesh.set_instance_shader_parameter(&"sweep", 0.0)
		mesh.set_instance_shader_parameter(&"flicker", _flicker)
		sweeps.append({"mesh": mesh, "born": whirlwind_sweep_delays[i], "size": whirlwind_sweep_scales[i], "sweep": 0.0})
		if fx.mesh == null:
			fx.mesh = mesh
		else:
			fx.rings.append(mesh)
		_place_sweep(fx, sweeps[i])


## Sparks start on a ring just inside the radius and fly in towards the commander, swirling the
## way the sword turns.
func _whirlwind_sparks(count: int, radius: float, origin: Vector3) -> CPUParticles3D:
	var sparks := _particles(count, whirlwind_spark_lifetime, _spark_color())
	sparks.mesh = _spark_mesh
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in count:
		var angle := (float(i) + randf_range(-0.3, 0.3)) / float(count) * TAU
		var radial := Vector3(cos(angle), 0.0, -sin(angle))
		# Clockwise seen from above, like the sword.
		var tangent := Vector3(sin(angle), 0.0, cos(angle))
		points.append(radial * radius * randf_range(0.9, 1.0))
		normals.append((-radial + tangent * whirlwind_spark_swirl).normalized())
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_DIRECTED_POINTS
	sparks.emission_points = points
	sparks.emission_normals = normals
	sparks.one_shot = true
	sparks.explosiveness = 0.8
	sparks.direction = Vector3(0.0, 0.0, 1.0)
	sparks.spread = 10.0
	sparks.initial_velocity_min = whirlwind_spark_speed_min
	sparks.initial_velocity_max = whirlwind_spark_speed_max
	sparks.gravity = Vector3.ZERO
	sparks.lifetime_randomness = 0.33
	sparks.particle_flag_align_y = true
	sparks.global_position = origin + Vector3.UP * whirlwind_height
	sparks.emitting = true
	return sparks


## Each sweep follows the sword and draws more of its trail as the sword turns clockwise; all
## fade together once the swing is over.
func _update_whirlwind(fx: Dictionary) -> bool:
	_follow_sword_holder(fx)
	var head := _whirlwind_head(fx)
	var turned := wrapf(fx.head - head, -PI, PI)
	fx.head = head
	for sweep: Dictionary in fx.sweeps:
		sweep.sweep = maxf(sweep.sweep + turned, 0.0)
	_spawn_due_sweeps(fx)
	if fx.fade_from < 0.0 and _swing_over(fx):
		fx.fade_from = fx.elapsed
	for sweep: Dictionary in fx.sweeps:
		_place_sweep(fx, sweep)
	return fx.fade_from < 0.0 or fx.elapsed - fx.fade_from < whirlwind_fade_time


## Keeps the sweeps centred on the commander while it holds the sword they follow. The commander
## can run during the swing; left at the cast point, the sword would only wobble round the centre
## and the trail would stay a short head.
func _follow_sword_holder(fx: Dictionary) -> void:
	var sword: Node3D = fx.sword
	if sword == null or not is_instance_valid(sword):
		return
	var c := _get_commander()
	if c == null or not c.is_ancestor_of(sword):
		return
	fx.at = c.global_position + Vector3.UP * whirlwind_height


## Turns a sweep so its head is on the sword, grows it in, fades it and tilts it to the camera.
func _place_sweep(fx: Dictionary, sweep: Dictionary) -> void:
	var mesh: MeshInstance3D = sweep.mesh
	var grow := clampf((fx.elapsed - sweep.born) / maxf(whirlwind_form_time, 0.001), 0.0, 1.0)
	var size: float = lerpf(whirlwind_start_scale, 1.0, grow) * sweep.size
	var fade := 1.0
	if fx.fade_from >= 0.0:
		fade = 1.0 - clampf((fx.elapsed - fx.fade_from) / maxf(whirlwind_fade_time, 0.001), 0.0, 1.0)
	mesh.set_instance_shader_parameter(&"sweep", sweep.sweep)
	mesh.set_instance_shader_parameter(&"fade", fade)
	mesh.set_instance_shader_parameter(&"flicker", _flicker)
	var flat := Basis(Vector3.UP, fx.head) * Basis.from_scale(Vector3.ONE * size)
	mesh.global_basis = _view_tilt(fx.at, whirlwind_max_tilt) * flat
	mesh.global_position = fx.at
#endregion


#region Sword Wave
## Flies from origin along dir for distance metres at speed m/s, stopping early at a wall.
func play_sword_wave(origin: Vector3, dir: Vector3, width: float, distance: float, speed: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
	var start := origin + flat * wave_start_offset
	var travel := _clear_distance(start, flat, maxf(distance - wave_start_offset, 0.0))
	# The shader works in wave space, where half the arc width is arc_half; s turns it into metres.
	var arc_half: float = wave_material.get_shader_parameter(&"arc_half")
	var scale_m := width * 0.5 / maxf(arc_half, 0.001)
	var side: float = wave_material.get_shader_parameter(&"side_extent") * scale_m
	var front: float = wave_material.get_shader_parameter(&"front_margin") * scale_m
	var tail: float = wave_material.get_shader_parameter(&"tail_extent") * scale_m
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0 * side, front + tail)
	# Local -Z is forward: the node sits on the front edge, the plane reaches front ahead of it
	# and the tail behind it.
	plane.center_offset = Vector3(0.0, 0.0, (tail - front) * 0.5)
	var mesh := MeshInstance3D.new()
	mesh.name = "SwordWave"
	mesh.mesh = plane
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = _skill_material(&"sword_wave", wave_material)
	mesh.set_instance_shader_parameter(&"half_width", width * 0.5)
	mesh.set_instance_shader_parameter(&"tail_scale", 0.0)
	mesh.set_instance_shader_parameter(&"fade", 1.0)
	mesh.set_instance_shader_parameter(&"game_time", 0.0)
	mesh.set_instance_shader_parameter(&"flicker", _flicker)
	add_child(mesh)
	mesh.global_basis = Basis.looking_at(flat, Vector3.UP)
	mesh.global_position = start + Vector3.UP * wave_height
	var fx := {"kind": &"sword_wave", "mesh": mesh, "elapsed": 0.0, "tail": tail,
		"start": mesh.global_position, "dir": flat, "fly_time": travel / maxf(speed, 0.001), "speed": speed,
		"flat": mesh.global_basis, "floor": origin.y}
	_face_camera(mesh, fx.flat, mesh.global_position, fx.floor, wave_max_tilt)
	var count := clampi(roundi(width * wave_spark_density), 8, 28)
	if _has_room(count):
		fx["particles"] = _wave_sparks(count, scale_m, mesh)
	_effects.append(fx)


## Streaks leave the blade of the crescent and fall back through its trail, following the wave.
func _wave_sparks(count: int, scale_m: float, mesh: MeshInstance3D) -> CPUParticles3D:
	var radius: float = wave_material.get_shader_parameter(&"arc_radius")
	var origin_y: float = wave_material.get_shader_parameter(&"arc_origin")
	var half: float = wave_material.get_shader_parameter(&"arc_half")
	var sparks := _particles(count, wave_spark_lifetime, _spark_color())
	# The same front arc as the shader. Points are measured back from the middle of the front
	# edge, which sits at local z = 0.
	var points := PackedVector3Array()
	for i in WAVE_SPARK_POINTS:
		var u := lerpf(-WAVE_SPARK_SPAN, WAVE_SPARK_SPAN, float(i) / float(WAVE_SPARK_POINTS - 1))
		var qx := u * half
		var front_y := origin_y + sqrt(maxf(radius * radius - qx * qx, 0.0))
		points.append(Vector3(qx * scale_m, 0.0, (origin_y + radius - front_y) * scale_m))
	sparks.mesh = _spark_mesh
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	sparks.emission_points = points
	sparks.direction = Vector3(0.0, 0.0, 1.0)
	sparks.spread = 20.0
	sparks.initial_velocity_min = wave_spark_speed_min
	sparks.initial_velocity_max = wave_spark_speed_max
	sparks.gravity = Vector3.ZERO
	sparks.lifetime_randomness = 0.6
	sparks.particle_flag_align_y = true
	sparks.global_basis = mesh.global_basis
	sparks.global_position = mesh.global_position
	sparks.emitting = true
	return sparks


func _update_sword_wave(fx: Dictionary) -> bool:
	var mesh: MeshInstance3D = fx.mesh
	var t: float = minf(fx.elapsed, fx.fly_time)
	var travelled: float = fx.speed * t
	_face_camera(mesh, fx.flat, fx.start + fx.dir * travelled, fx.floor, wave_max_tilt)
	# The tail grows as the wave leaves, so it never reaches back past the commander.
	mesh.set_instance_shader_parameter(&"tail_scale", clampf((travelled + wave_start_offset) / maxf(fx.tail, 0.001), 0.0, 1.0))
	var fade := _fade_after(fx.elapsed, fx.fly_time)
	mesh.set_instance_shader_parameter(&"fade", fade)
	mesh.set_instance_shader_parameter(&"game_time", fx.elapsed)
	mesh.set_instance_shader_parameter(&"flicker", _flicker)
	var sparks: CPUParticles3D = fx.get("particles")
	if sparks != null and sparks.emitting:
		sparks.global_position = mesh.global_position
		sparks.emitting = fx.elapsed < fx.fly_time
	return fade > 0.0


## How far the wave gets before a ray at wave_height hits something on wave_stop_mask.
func _clear_distance(start: Vector3, dir: Vector3, distance: float) -> float:
	var world := get_viewport().find_world_3d() if get_viewport() != null else null
	if world == null or distance <= 0.0:
		return distance
	var from := start + Vector3.UP * wave_height
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * distance, wave_stop_mask)
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return distance
	return from.distance_to(hit.position)
#endregion


#region Firebomb
## The bomb flies from from to target, then the burn area stays burn_time seconds.
func play_firebomb(from: Vector3, target: Vector3, radius: float, burn_time: float) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = bomb_radius
	sphere.height = bomb_radius * 2.0
	var bomb := MeshInstance3D.new()
	bomb.name = "Firebomb"
	bomb.mesh = sphere
	bomb.material_override = bomb_material
	bomb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bomb)
	bomb.global_position = from + Vector3.UP * hand_height
	var zone := _flat_mesh(fire_material, radius + ring_margin)
	zone.global_position = target + Vector3.UP * ground_lift
	zone.set_instance_shader_parameter(&"radius", radius)
	zone.set_instance_shader_parameter(&"fade", 0.0)
	zone.visible = false
	_effects.append({"kind": &"firebomb", "mesh": zone, "bomb": bomb, "elapsed": 0.0,
		"from": bomb.global_position, "target": target, "radius": radius, "burn_time": burn_time})


func _update_firebomb(fx: Dictionary) -> bool:
	var t: float = fx.elapsed
	var bomb: MeshInstance3D = fx.bomb
	if t < throw_time:
		var k := t / maxf(throw_time, 0.001)
		bomb.global_position = (fx.from as Vector3).lerp(fx.target, k) + Vector3.UP * throw_height * 4.0 * k * (1.0 - k)
		return true
	if bomb.visible:
		bomb.visible = false
		_land(fx)
	var zone: MeshInstance3D = fx.mesh
	var burning := t - throw_time
	var fade := minf(burning / maxf(fade_time * 0.5, 0.001), 1.0) * _fade_after(burning, fx.burn_time)
	zone.set_instance_shader_parameter(&"fade", fade)
	zone.set_instance_shader_parameter(&"game_time", burning)
	zone.set_instance_shader_parameter(&"flicker", _flicker)
	var embers: CPUParticles3D = fx.get("particles")
	if embers != null and burning >= fx.burn_time:
		embers.emitting = false
	return fade > 0.0 or burning < fx.burn_time or (embers != null and embers.emitting)


func _land(fx: Dictionary) -> void:
	var zone: MeshInstance3D = fx.mesh
	zone.visible = true
	var radius: float = fx.radius
	var count := clampi(roundi(PI * radius * radius * ember_density), 6, 64)
	if not _has_room(count):
		return
	var embers := _particles(count, 0.9, ember_color)
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	embers.emission_ring_axis = Vector3.UP
	embers.emission_ring_radius = radius * 0.9
	embers.emission_ring_inner_radius = 0.0
	embers.emission_ring_height = 0.0
	embers.direction = Vector3.UP
	embers.spread = 15.0
	embers.initial_velocity_min = 0.4
	embers.initial_velocity_max = 1.0
	embers.gravity = Vector3.UP * 0.8
	embers.global_position = (fx.target as Vector3) + Vector3.UP * ground_lift
	embers.emitting = true
	fx["particles"] = embers
#endregion


func _process(delta: float) -> void:
	# Backwards, so remove_at never skips an effect.
	for i in range(_effects.size() - 1, -1, -1):
		var fx := _effects[i]
		fx.elapsed += delta
		var alive := false
		match fx.kind:
			&"whirlwind":
				alive = _update_whirlwind(fx)
			&"sword_wave":
				alive = _update_sword_wave(fx)
			&"firebomb":
				alive = _update_firebomb(fx)
		var particles: CPUParticles3D = fx.get("particles")
		if particles != null and particles.emitting:
			alive = true
		if not alive:
			_free_effect(fx)
			_effects.remove_at(i)


## Removes every effect at once, at the start of a run.
func clear() -> void:
	for fx in _effects:
		_free_effect(fx)
	_effects.clear()


func _free_effect(fx: Dictionary) -> void:
	for key in [&"mesh", &"bomb", &"particles"]:
		var node: Node = fx.get(key)
		if node != null and is_instance_valid(node):
			node.queue_free()
	for ring: MeshInstance3D in fx.get("rings", []):
		if is_instance_valid(ring):
			ring.queue_free()


## Puts a flat effect mesh at `at`, tilted towards the camera (at most max_tilt degrees) and lifted
## clear of the floor when the view grazes it. flat is its lying-flat basis, floor_y the height of
## the floor under it. The tilt is worked out again from the lifted spot, since lifting changes how
## the camera sees it.
func _face_camera(mesh: MeshInstance3D, flat: Basis, at: Vector3, floor_y: float, max_tilt: float) -> void:
	var lift := 0.0
	var basis := flat
	for _round in TILT_PASSES:
		basis = _view_tilt(at + Vector3.UP * lift, max_tilt) * flat
		lift = _floor_lift(mesh, basis, at, floor_y)
	mesh.global_basis = basis
	mesh.global_position = at + Vector3.UP * lift


## The turn that leans a flat effect at `at` towards the camera until the camera sees it at
## min_view_angle, at most max_tilt degrees; identity when it already does, or with no camera.
func _view_tilt(at: Vector3, max_tilt: float) -> Basis:
	if min_view_angle <= 0.0:
		return Basis.IDENTITY
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null:
		return Basis.IDENTITY
	var to_cam := cam.global_position - at
	if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		to_cam = cam.global_basis.z
	var across := Vector3(to_cam.x, 0.0, to_cam.z)
	if across.length_squared() < 0.000001:
		return Basis.IDENTITY
	var need := minf(deg_to_rad(min_view_angle) - atan2(to_cam.y, across.length()), deg_to_rad(max_tilt))
	if need <= 0.0:
		return Basis.IDENTITY
	# Turning about this axis leans the plane's up towards the camera.
	return Basis(Vector3.UP.cross(across.normalized()), need)


## How far to raise a mesh at `at` with this basis so its lowest corner stays ground_lift above
## floor_y. 0 when it is already clear.
func _floor_lift(mesh: MeshInstance3D, basis: Basis, at: Vector3, floor_y: float) -> float:
	var box := mesh.get_aabb()
	var low := INF
	for i in 8:
		low = minf(low, (basis * box.get_endpoint(i)).y)
	return maxf(floor_y + ground_lift - (at.y + low), 0.0)


## 1 until hold seconds have passed, then down to 0 over fade_time.
func _fade_after(t: float, hold: float) -> float:
	return 1.0 - clampf((t - hold) / maxf(fade_time, 0.001), 0.0, 1.0)


func _flat_mesh(material: Material, half_size: float) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 2.0 * half_size
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = material
	mesh.set_instance_shader_parameter(&"fade", 1.0)
	add_child(mesh)
	return mesh


func _particles(count: int, lifetime: float, color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = count
	p.lifetime = lifetime
	p.mesh = _particle_mesh
	p.local_coords = false
	p.emitting = false
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	add_child(p)
	return p


func _has_room(count: int) -> bool:
	return ParticleBudget.has_room(get_tree(), count, true)


## Particles of the effects still emitting. For the budget and for tests.
func active_particles() -> int:
	var total := 0
	for fx in _effects:
		var p: CPUParticles3D = fx.get("particles")
		if p != null and p.emitting:
			total += p.amount
	return total


func _value(skill_id: StringName, key: StringName, level: int, fallback: float) -> float:
	if not _skill_data.has(skill_id):
		var path := SKILL_DIR % skill_id
		_skill_data[skill_id] = load(path) as SkillData if ResourceLoader.exists(path) else null
	var data: SkillData = _skill_data[skill_id]
	if data == null or not data.values.has(key):
		return fallback
	return data.get_value(key, level)


func _wave_speed() -> float:
	var speed: Variant = GameConfig.get(&"skill_sword_wave_speed")
	return float(speed) if speed != null else fallback_wave_speed


func _aim_dir() -> Vector3:
	var c := _get_commander()
	if c == null:
		return Vector3.FORWARD
	var aim: Variant = c.get(&"aim_dir")
	return aim if aim is Vector3 else -c.global_basis.z


func _get_commander() -> Node3D:
	if _commander == null or not is_instance_valid(_commander):
		_commander = get_tree().get_first_node_in_group(&"commander") as Node3D
	return _commander


## Effects still on screen, fading ones included. For tests.
func get_active_count(kind: StringName = &"") -> int:
	if kind == &"":
		return _effects.size()
	return _effects.filter(func(fx: Dictionary) -> bool: return fx.kind == kind).size()


## The mesh of the newest effect of that kind, null when there is none. For tests.
func get_effect_mesh(kind: StringName) -> MeshInstance3D:
	for i in range(_effects.size() - 1, -1, -1):
		if _effects[i].kind == kind:
			return _effects[i].mesh
	return null


## The sweeps after the first of the newest Whirlwind, empty when there is none. For tests.
func get_whirlwind_sweeps() -> Array[MeshInstance3D]:
	for i in range(_effects.size() - 1, -1, -1):
		if _effects[i].kind == &"whirlwind":
			return _effects[i].rings
	return []


## The particle emitter of the newest effect of that kind, null when there is none. For tests.
func get_effect_particles(kind: StringName) -> CPUParticles3D:
	for i in range(_effects.size() - 1, -1, -1):
		if _effects[i].kind == kind:
			return _effects[i].get("particles")
	return null
