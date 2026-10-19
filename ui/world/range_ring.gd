class_name RangeRing
extends MeshInstance3D
## Flat ring at a tower's attack range, drawn over walls.

@export var color: Color = Color(1, 1, 1, 0.6)
@export var width: float = 0.12

func _ready() -> void:
	visible = false
	mesh = TorusMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_color = color
	material_override = mat

func show_at(pos: Vector3, radius: float) -> void:
	var torus := mesh as TorusMesh
	torus.outer_radius = radius
	torus.inner_radius = maxf(radius - width, 0.01)
	global_position = pos + Vector3.UP * 0.05
	scale = Vector3(1.0, 0.05, 1.0)
	visible = true

func hide_ring() -> void:
	visible = false
