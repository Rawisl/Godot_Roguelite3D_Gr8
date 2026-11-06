class_name SkillFxManager
extends Node
## Visuals for the commander's active skills, one effect per EventBus.skill_cast:
## - Whirlwind: a brush slash with streaks sweeps once round the commander at the skill radius,
##   dust kicks up at the edge
## - Sword Wave: a crescent with straight streaks in its tail flies from the commander along its
##   aim, and stops early at a wall
## - Firebomb: a bomb arcs from the commander to the cast point, then the burn area and its
##   embers stay for the burn time
## What skill_cast carries: origin is the commander's position for Whirlwind and Sword Wave and
## the landing point for Firebomb; radius is the Whirlwind radius and the Firebomb burn radius.
## Sword Wave takes its direction from the commander's aim_dir.
## Other sizes come from the skill's SkillData in data/skills/ when it has the value, otherwise
## from the fallbacks here. Runs on game time: follows x2 / x3 and holds while paused.
## Nothing is added to the commander scene.

const SKILL_DIR := "res://data/skills/%s.tres"

@export_group("Whirlwind")
## Colour and blade shape are tuned in this material; radius, progress and fade are set per effect.
@export var whirlwind_material: ShaderMaterial = preload("res://art/materials/skill_whirlwind.tres")
## Seconds for the blade to go once round.
@export var sweep_time := 0.25
@export var dust_color := Color("#D8CBB0")

@export_group("Sword Wave")
@export var wave_material: ShaderMaterial = preload("res://art/materials/skill_sword_wave.tres")
## Used while data/skills/sword_wave.tres has no width, distance, or GameConfig no speed.
@export var fallback_wave_width := 3.0
@export var fallback_wave_distance := 4.0
@export var fallback_wave_speed := 20.0
## The wave appears this far in front of the commander.
@export var wave_start_offset := 0.5
## Height of the wave above the floor.
@export var wave_height := 0.6
## The wave stops where a ray at this height hits something on these layers (1 = world).
@export_flags_3d_physics var wave_stop_mask := 1

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
## Room outside the radius for the soft edge.
@export var ring_margin := 0.3
## Particle cap for the current graphics preset (Low 500, Medium 1500, High 3000).
## Over it, dust and embers are skipped; the effects themselves always play.
@export var particle_budget := 1500

var _effects: Array[Dictionary] = []
var _skill_data: Dictionary = {}  # StringName -> SkillData, or null when there is no file
var _commander: Node3D
var _particle_mesh: SphereMesh
var _flicker := 1.0


func _ready() -> void:
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
	_set_reduce_flash(GameState.get_setting(&"reduce_flash", false) == true)
	EventBus.skill_cast.connect(_on_skill_cast)
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.run_started.connect(clear)


func _on_skill_cast(skill_id: StringName, _slot: int, level: int, origin: Vector3, radius: float) -> void:
	match skill_id:
		&"whirlwind":
			play_whirlwind(origin, radius, _aim_dir())
		&"sword_wave":
			play_sword_wave(origin, _aim_dir(),
				_value(skill_id, &"width", level, fallback_wave_width),
				_value(skill_id, &"distance", level, fallback_wave_distance),
				_wave_speed())
		&"firebomb":
			var c := _get_commander()
			var from := c.global_position if c != null else origin
			play_firebomb(from, origin, radius, _value(skill_id, &"duration", level, fallback_burn_time))


func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"reduce_flash":
		_set_reduce_flash(value == true)


func _set_reduce_flash(on: bool) -> void:
	_flicker = 0.0 if on else 1.0


#region Whirlwind
## start_dir is where the blade starts; it sweeps once round from there.
func play_whirlwind(origin: Vector3, radius: float, start_dir := Vector3.RIGHT) -> void:
	var mesh := _flat_mesh(whirlwind_material, radius + ring_margin)
	mesh.global_position = origin + Vector3.UP * ground_lift
	mesh.rotation.y = atan2(-start_dir.z, start_dir.x)
	mesh.set_instance_shader_parameter(&"radius", radius)
	mesh.set_instance_shader_parameter(&"progress", 0.0)
	var fx := {"kind": &"whirlwind", "mesh": mesh, "elapsed": 0.0}
	var count := roundi(radius * 6.0)
	if _has_room(count):
		var dust := _particles(count, 0.5, dust_color)
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		dust.emission_ring_axis = Vector3.UP
		dust.emission_ring_radius = radius
		dust.emission_ring_inner_radius = radius * 0.85
		dust.emission_ring_height = 0.0
		dust.one_shot = true
		dust.explosiveness = 0.6
		dust.direction = Vector3.UP
		dust.spread = 30.0
		dust.initial_velocity_min = 0.6
		dust.initial_velocity_max = 1.2
		dust.gravity = Vector3.DOWN * 1.5
		dust.global_position = origin + Vector3.UP * ground_lift
		dust.emitting = true
		fx["particles"] = dust
	_effects.append(fx)


func _update_whirlwind(fx: Dictionary) -> bool:
	var mesh: MeshInstance3D = fx.mesh
	var t: float = fx.elapsed
	mesh.set_instance_shader_parameter(&"progress", minf(t / maxf(sweep_time, 0.001), 1.0))
	var fade := _fade_after(t, sweep_time)
	mesh.set_instance_shader_parameter(&"fade", fade)
	return fade > 0.0
#endregion


#region Sword Wave
## Flies from origin along dir for distance metres at speed m/s, stopping early at a wall.
func play_sword_wave(origin: Vector3, dir: Vector3, width: float, distance: float, speed: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
	var start := origin + flat * wave_start_offset
	var travel := _clear_distance(start, flat, maxf(distance - wave_start_offset, 0.0))
	var bulge: float = wave_material.get_shader_parameter(&"bulge")
	var tail: float = wave_material.get_shader_parameter(&"tail_length")
	var plane := PlaneMesh.new()
	plane.size = Vector2(width + ring_margin, bulge + tail + ring_margin * 2.0)
	# Local -Z is forward: the plane reaches bulge ahead of the node and the tail behind it.
	plane.center_offset = Vector3(0.0, 0.0, (tail - bulge) * 0.5)
	var mesh := MeshInstance3D.new()
	mesh.name = "SwordWave"
	mesh.mesh = plane
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = wave_material
	mesh.set_instance_shader_parameter(&"half_width", width * 0.5)
	mesh.set_instance_shader_parameter(&"tail_scale", 0.0)
	mesh.set_instance_shader_parameter(&"fade", 1.0)
	add_child(mesh)
	mesh.global_basis = Basis.looking_at(flat, Vector3.UP)
	mesh.global_position = start + Vector3.UP * wave_height
	_effects.append({"kind": &"sword_wave", "mesh": mesh, "elapsed": 0.0, "tail": tail,
		"start": mesh.global_position, "dir": flat, "fly_time": travel / maxf(speed, 0.001), "speed": speed})


func _update_sword_wave(fx: Dictionary) -> bool:
	var mesh: MeshInstance3D = fx.mesh
	var t: float = minf(fx.elapsed, fx.fly_time)
	var travelled: float = fx.speed * t
	mesh.global_position = fx.start + fx.dir * travelled
	# The tail grows as the wave leaves, so it never reaches back past the commander.
	mesh.set_instance_shader_parameter(&"tail_scale", clampf((travelled + wave_start_offset) / maxf(fx.tail, 0.001), 0.0, 1.0))
	var fade := _fade_after(fx.elapsed, fx.fly_time)
	mesh.set_instance_shader_parameter(&"fade", fade)
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
	return active_particles() + count <= particle_budget


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
