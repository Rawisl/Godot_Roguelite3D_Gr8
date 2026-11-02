class_name EnergyOrb
extends Node3D
## Energy orb floating over the heal station's pool: a swirling core, a soft halo, a few
## sparks drifting up and a small light on the crystals. It bobs slowly on game time.
## HealFxManager sets the "store" shader parameter on the orb's meshes from the station's HP
## store; the sparks and the light follow that value, so the orb fades to grey when empty.
## The heal beam starts at the BeamOrigin child, so it follows the bob.

@export var radius := 0.27
@export var glow_radius := 0.3
## Metres up and down, and seconds for one bob.
@export var bob_height := 0.1
@export var bob_period := 3.0
@export var spin_speed := 0.4
@export var orb_color := Color(0.56, 0.93, 0.62)
@export var empty_color := Color(0.46, 0.49, 0.52)
@export var light_energy := 0.45
@export var light_range := 2.2

var _core: MeshInstance3D
var _sparks: CPUParticles3D
var _light: OmniLight3D
var _base_y := 0.0
var _time := 0.0


func _ready() -> void:
	_base_y = position.y
	_core = _sphere("Core", radius, preload("res://art/shaders/energy_orb.gdshader"))
	_sphere("Glow", glow_radius, preload("res://art/shaders/energy_orb_glow.gdshader"))
	_sparks = _make_sparks()
	_light = OmniLight3D.new()
	_light.name = "Light"
	_light.light_color = orb_color
	_light.omni_range = light_range
	_light.shadow_enabled = false
	add_child(_light)


func get_store() -> float:
	var value = _core.get_instance_shader_parameter(&"store")
	return 1.0 if value == null else clampf(float(value), 0.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time / bob_period * TAU) * bob_height
	rotate_y(spin_speed * delta)
	var store := get_store()
	var color := empty_color.lerp(orb_color, store)
	_light.light_color = color
	_light.light_energy = light_energy * store
	_sparks.color = color
	_sparks.emitting = store > 0.0


func _sphere(mesh_name: String, r: float, shader: Shader) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = mesh_name
	var sphere := SphereMesh.new()
	sphere.radius = r
	sphere.height = r * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	mesh.mesh = sphere
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh


func _make_sparks() -> CPUParticles3D:
	var sparks := CPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.amount = 10
	sparks.lifetime = 1.4
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = radius * 1.2
	sparks.direction = Vector3.UP
	sparks.spread = 30.0
	sparks.gravity = Vector3(0, 0.25, 0)
	sparks.initial_velocity_min = 0.05
	sparks.initial_velocity_max = 0.15
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	sparks.scale_amount_curve = curve
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.08
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	# Soft round dot instead of a square.
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.gradient = Gradient.new()
	dot.gradient.set_color(0, Color.WHITE)
	dot.gradient.set_color(1, Color(1, 1, 1, 0))
	mat.albedo_texture = dot
	quad.material = mat
	sparks.mesh = quad
	sparks.local_coords = false
	add_child(sparks)
	return sparks
