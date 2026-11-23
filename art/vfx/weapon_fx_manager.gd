class_name WeaponFxManager
extends Node
## Effects the weapon effects leave on the units they hit:
## - Frost: icy grey mist rising off every slowed unit and a light blue tint on its body, while the
##   slow lasts. Only the Frost weapon slows units, so slow_timer > 0 means Frost.
## - Burn: small flames on every burning unit, while the burn lasts.
## - Chain Lightning: a jagged violet bolt with thinner white and yellow strands around it, from the
##   commander to the first target and then from each target to the next, drawn once per chain
##   (the chain has a 5 s cooldown, so it never flashes fast). The strands hug the main bolt. Every
##   unit it hits shows a white orb with a few small arcs at its body for a moment.
## Reads the Enemy state each frame and the HealthComponent damaged signal; nothing is added to the
## enemy scenes. Mist and flames are extras of the particle budget: a unit that starts burning or
## freezing while the budget is full gets no particles (the Frost tint still shows).
## The tint uses material_overlay only while it is free or already the tint, so the hit flash and
## the glows some enemy models draw there keep priority. "Reduce flashing" draws the bolt as the
## violet strand only, dimmer and without the white and yellow strands, and the orbs dimmer
## and without arcs.

@export_group("Frost")
@export var frost_amount := 12
@export var frost_height := 0.6
@export var frost_color_start := Color(0.85, 0.92, 1.0, 0.9)
@export var frost_color_end := Color(0.55, 0.62, 0.7, 0.0)
@export var frost_tint := Color(0.45, 0.75, 1.0, 0.35)

@export_group("Burn")
@export var fire_amount := 14
@export var fire_height := 0.7
@export var fire_color_start := Color(1.0, 0.75, 0.2)
@export var fire_color_end := Color(0.9, 0.15, 0.05, 0.0)

@export_group("Chain Lightning")
@export var bolt_color := Color(0.75, 0.6, 1.0)
## Thinner strands drawn around the main bolt, each with its own jags.
@export var bolt_strand_colors: Array[Color] = [Color(1, 1, 1), Color(1.0, 0.9, 0.3), Color(1, 1, 1)]
@export var bolt_width := 0.12
@export var bolt_strand_width := 0.05
@export var bolt_time := 0.3
@export var bolt_height := 1.0
## Jag points per metre of bolt.
@export var bolt_jags_per_m := 3.0
@export var bolt_jag := 0.25
## How far the white and yellow strands stray from the main bolt.
@export var bolt_strand_offset := 0.05
## White orb with small arcs at the body of every unit the chain hits.
@export var orb_radius := 0.22
@export var orb_color := Color(1, 1, 1, 0.75)
@export var orb_arc_color := Color(0.85, 0.8, 1.0, 0.8)
@export var orb_arcs := 4
@export var orb_time := 0.4

var _frost: Dictionary = {}  # Enemy -> GPUParticles3D
var _fire: Dictionary = {}  # Enemy -> GPUParticles3D
var _tinted: Dictionary = {}  # Enemy -> Array[GeometryInstance3D]
var _bolts: Array[MeshInstance3D] = []
var _orbs: Array[MeshInstance3D] = []
var _chain_frame := -1
var _chain_last := Vector3.ZERO
var _reduce_flash := false
var _frost_process: ParticleProcessMaterial
var _frost_mesh: QuadMesh
var _fire_process: ParticleProcessMaterial
var _fire_mesh: QuadMesh
var _tint_material: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(ParticleBudget.GROUP)
	_reduce_flash = GameState.get_setting(&"reduce_flash", false) == true
	EventBus.settings_changed.connect(_on_settings_changed)
	_build_resources()
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "HealthComponent", true, false):
		_on_node_added(node)


func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"reduce_flash":
		_reduce_flash = value == true


func _on_node_added(node: Node) -> void:
	if node is HealthComponent:
		var health := node as HealthComponent
		var owner_node := health.get_parent() as Node3D
		if owner_node != null and not health.damaged.is_connected(_on_damaged):
			health.damaged.connect(_on_damaged.bind(owner_node))


func _process(delta: float) -> void:
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var alive := not enemy.is_dead and enemy.is_inside_tree()
		var frozen := alive and enemy.slow_timer > 0.0
		_update_emitter(_frost, enemy, frozen, frost_amount, frost_height, _frost_process, _frost_mesh, 0.9)
		_update_tint(enemy, frozen)
		_update_emitter(_fire, enemy, alive and enemy.burn_timer > 0.0, fire_amount, fire_height, _fire_process, _fire_mesh, 0.6)
	_drop_gone(_frost)
	_drop_gone(_fire)
	for enemy in _tinted.keys():
		if not is_instance_valid(enemy):
			_tinted.erase(enemy)
	_update_bolts(delta)


# --- Frost mist and Burn flames ---

func _update_emitter(map: Dictionary, enemy: Enemy, on: bool, amount: int, height: float,
		process: ParticleProcessMaterial, mesh: QuadMesh, lifetime: float) -> void:
	var emitter: GPUParticles3D = map.get(enemy)
	if emitter == null:
		if not on or not ParticleBudget.has_room(get_tree(), amount, true):
			return
		emitter = GPUParticles3D.new()
		emitter.amount = amount
		emitter.lifetime = lifetime
		emitter.local_coords = false
		emitter.process_material = process
		emitter.draw_pass_1 = mesh
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		emitter.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 3, 2))
		add_child(emitter)
		map[enemy] = emitter
	emitter.emitting = on
	emitter.global_position = enemy.global_position + Vector3.UP * height


# --- Frost tint ---

func _update_tint(enemy: Enemy, on: bool) -> void:
	if on:
		var meshes: Array = _tinted.get(enemy, [])
		if meshes.is_empty():
			for node in enemy.find_children("*", "GeometryInstance3D", true, false):
				if node is MeshInstance3D:
					meshes.append(node)
			_tinted[enemy] = meshes
		for mesh in meshes:
			if is_instance_valid(mesh) and (mesh as GeometryInstance3D).material_overlay == null:
				(mesh as GeometryInstance3D).material_overlay = _tint_material
	elif _tinted.has(enemy):
		for mesh in _tinted[enemy]:
			if is_instance_valid(mesh) and (mesh as GeometryInstance3D).material_overlay == _tint_material:
				(mesh as GeometryInstance3D).material_overlay = null
		# Kept in the map: the hit flash can hand the tint back after the slow ended, and the next
		# frame clears it again.
		var any_left := false
		for mesh in _tinted[enemy]:
			if is_instance_valid(mesh) and (mesh as GeometryInstance3D).material_overlay == _tint_material:
				any_left = true
		if not any_left and enemy.slow_timer <= 0.0 and not _flash_pending(enemy):
			_tinted.erase(enemy)


## True while any mesh of the unit holds an overlay that is not the tint (a hit flash), which may
## hand the tint back when it ends.
func _flash_pending(enemy: Enemy) -> bool:
	for mesh in _tinted.get(enemy, []):
		if is_instance_valid(mesh) and (mesh as GeometryInstance3D).material_overlay != null:
			return true
	return false


# --- Chain Lightning ---

func _on_damaged(_amount: int, info: DamageInfo, target: Node3D) -> void:
	if info == null or not info.is_weapon_effect or info.is_dot or not is_instance_valid(target):
		return
	if info.source == null or not info.source.is_in_group(&"commander") or not target.is_in_group(&"enemy"):
		return
	# The bolts of one chain all land in the same frame, in chain order.
	var frame := Engine.get_physics_frames()
	var to := target.global_position + Vector3.UP * bolt_height
	var from := _chain_last
	if frame != _chain_frame:
		from = (info.source as Node3D).global_position + Vector3.UP * bolt_height
	_chain_frame = frame
	_chain_last = to
	_spawn_bolt(from, to)
	_spawn_orb(to)


func _spawn_bolt(from: Vector3, to: Vector3) -> void:
	var bolt := MeshInstance3D.new()
	bolt.name = "ChainBolt"
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := ImmediateMesh.new()
	var main := _jag_points(from, to, bolt_jag)
	_add_ribbon(mesh, main, bolt_width, bolt_color)
	if not _reduce_flash:
		# The strands follow the main bolt's path closely, so the three colours read as one bolt.
		for color in bolt_strand_colors:
			var strand := main.duplicate()
			for i in range(1, strand.size() - 1):
				strand[i] += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * bolt_strand_offset
			_add_ribbon(mesh, strand, bolt_strand_width, color)
	bolt.mesh = mesh
	var mat := _line_material()
	if _reduce_flash:
		mat.albedo_color = Color(0.8, 0.8, 0.8, 0.8)
	bolt.material_override = mat
	bolt.set_meta(&"life", bolt_time)
	add_child(bolt)
	_bolts.append(bolt)


## Both ends stay exact so the strands meet the main bolt at each target.
func _jag_points(from: Vector3, to: Vector3, jag: float) -> PackedVector3Array:
	var points := PackedVector3Array([from])
	var steps := maxi(int(from.distance_to(to) * bolt_jags_per_m), 2)
	for i in range(1, steps):
		var p := from.lerp(to, float(i) / float(steps))
		p += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * jag
		points.append(p)
	points.append(to)
	return points


## A flat ribbon facing up and toward the default camera tilt, wide enough to read from above.
func _add_ribbon(mesh: ImmediateMesh, points: PackedVector3Array, width: float, color: Color) -> void:
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in points.size():
		var dir := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var side := dir.cross(Vector3(0.0, 0.7, 0.7).normalized()).normalized() * width * 0.5
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(points[i] + side)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(points[i] - side)
	mesh.surface_end()


## A white orb at the struck unit's body, with a few short arcs crackling out of it.
func _spawn_orb(center: Vector3) -> void:
	var orb := MeshInstance3D.new()
	orb.name = "ChainOrb"
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sphere := SphereMesh.new()
	sphere.radius = orb_radius
	sphere.height = orb_radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_color = orb_color * Color(1, 1, 1, 0.6 if _reduce_flash else 1.0)
	sphere.material = mat
	orb.mesh = sphere
	orb.position = center
	if not _reduce_flash:
		var arcs := MeshInstance3D.new()
		var mesh := ImmediateMesh.new()
		for i in orb_arcs:
			var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.5, 1), _rng.randf_range(-1, 1)).normalized()
			_add_ribbon(mesh, _jag_points(dir * orb_radius * 0.8, dir * orb_radius * 2.2, orb_radius * 0.25), bolt_strand_width, orb_arc_color)
		arcs.mesh = mesh
		arcs.material_override = _line_material()
		orb.add_child(arcs)
	orb.set_meta(&"life", orb_time)
	add_child(orb)
	_orbs.append(orb)


func _line_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	return mat


func _update_bolts(delta: float) -> void:
	_fade(_bolts, bolt_time, delta)
	_fade(_orbs, orb_time, delta)


func _fade(list: Array[MeshInstance3D], time: float, delta: float) -> void:
	for node in list.duplicate():
		var life := float(node.get_meta(&"life")) - delta
		if life <= 0.0:
			list.erase(node)
			node.queue_free()
			continue
		node.set_meta(&"life", life)
		var fade := 1.0 - life / time
		node.transparency = fade
		for child in node.get_children():
			(child as GeometryInstance3D).transparency = fade


# --- Shared ---

func active_particles() -> int:
	var total := 0
	for emitter in _frost.values():
		if is_instance_valid(emitter) and (emitter as GPUParticles3D).emitting:
			total += frost_amount
	for emitter in _fire.values():
		if is_instance_valid(emitter) and (emitter as GPUParticles3D).emitting:
			total += fire_amount
	return total


func _drop_gone(map: Dictionary) -> void:
	for enemy in map.keys():
		if not is_instance_valid(enemy) or not (enemy as Node).is_inside_tree() or (enemy as Enemy).is_dead:
			var node: Node = map[enemy]
			if is_instance_valid(node):
				node.queue_free()
			map.erase(enemy)


func _build_resources() -> void:
	# Frost: slow grey-blue mist drifting up, wider and softer than the flames.
	_frost_process = _rising_process(0.3, 0.25, 0.6, 0.6, frost_color_start, frost_color_end)
	_frost_mesh = _particle_quad(Vector2(0.3, 0.3), false)
	_fire_process = _rising_process(0.25, 0.6, 1.2, 1.5, fire_color_start, fire_color_end)
	_fire_mesh = _particle_quad(Vector2(0.22, 0.3), true)
	_tint_material = StandardMaterial3D.new()
	_tint_material.albedo_color = frost_tint
	_tint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tint_material.render_priority = 1


func _rising_process(radius: float, speed_min: float, speed_max: float, lift: float,
		start: Color, end: Color) -> ParticleProcessMaterial:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = radius
	process.direction = Vector3.UP
	process.spread = 15.0
	process.initial_velocity_min = speed_min
	process.initial_velocity_max = speed_max
	process.gravity = Vector3(0, lift, 0)
	process.scale_min = 0.7
	process.scale_max = 1.2
	var curve := CurveTexture.new()
	curve.curve = Curve.new()
	curve.curve.add_point(Vector2(0, 1))
	curve.curve.add_point(Vector2(1, 0.2))
	process.scale_curve = curve
	var ramp := GradientTexture1D.new()
	ramp.gradient = Gradient.new()
	ramp.gradient.set_color(0, start)
	ramp.gradient.set_color(1, end)
	process.color_ramp = ramp
	return process


func _particle_quad(size: Vector2, additive: bool) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mat
	return quad


## For tests.
func has_frost(enemy: Enemy) -> bool:
	return _frost.has(enemy) and (_frost[enemy] as GPUParticles3D).emitting


## True while the unit wears the Frost tint. For tests.
func has_tint(enemy: Enemy) -> bool:
	for mesh in _tinted.get(enemy, []):
		if is_instance_valid(mesh) and (mesh as GeometryInstance3D).material_overlay == _tint_material:
			return true
	return false


## For tests.
func has_fire(enemy: Enemy) -> bool:
	return _fire.has(enemy) and (_fire[enemy] as GPUParticles3D).emitting


## For tests.
func orb_count() -> int:
	return _orbs.size()


## For tests.
func bolt_count() -> int:
	return _bolts.size()
