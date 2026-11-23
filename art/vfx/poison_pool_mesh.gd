@tool
class_name PoisonPoolMesh
extends MeshInstance3D

## Flat fan for the poison pool left on the floor by the boss's spit. The fan lies on the XZ
## plane with its (cut away) tip at the node origin and opens along +Z: the part nearer than
## cut_fraction * length is left out and the far end is an arc at length from the tip.
## Place the node on the floor right under the mouth. The shader (boss_poison_pool.gdshader)
## breaks the fan up into puddles; drive its "spread" and "opacity" instance uniforms.
##
## UV.x is 0 on the cut edge and 1 on the far arc; UV.y runs 0..1 across the fan.
##
## With disc on the mesh is a full circle of radius length around the node origin instead:
## UV.x = 0.5 + 0.5 * r / length (0.5 at the centre, 1 on the rim) and UV.y = 0.5 everywhere,
## so the shader's edge fade (min of the UV distances to 0 and 1) only softens the rim.

## Full circle instead of the fan; cut_fraction and half_angle_deg are ignored.
@export var disc := false:
	set(value):
		disc = value
		_rebuild()
## Distance from the tip to the far arc, in metres.
@export var length := 3.9:
	set(value):
		length = value
		_rebuild()
## Share of the length cut away at the tip.
@export_range(0.0, 0.95) var cut_fraction := 0.25:
	set(value):
		cut_fraction = value
		_rebuild()
## Half of the opening angle, in degrees.
@export_range(1.0, 89.0) var half_angle_deg := 16.5:
	set(value):
		half_angle_deg = value
		_rebuild()
@export_range(1, 64) var radial_segments := 16:
	set(value):
		radial_segments = value
		_rebuild()
@export_range(1, 64) var angle_segments := 16:
	set(value):
		angle_segments = value
		_rebuild()


func _ready() -> void:
	_rebuild()


func build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var r0 := 0.0 if disc else length * cut_fraction
	var half := PI if disc else deg_to_rad(half_angle_deg)
	for i in radial_segments + 1:
		var u := float(i) / radial_segments
		var r := lerpf(r0, length, u)
		for j in angle_segments + 1:
			var v := float(j) / angle_segments
			var a := lerpf(-half, half, v)
			verts.append(Vector3(sin(a) * r, 0.0, cos(a) * r))
			uvs.append(Vector2(0.5 + 0.5 * u, 0.5) if disc else Vector2(u, v))
			normals.append(Vector3.UP)
	var row := angle_segments + 1
	for i in radial_segments:
		for j in angle_segments:
			var k := i * row + j
			indices.append_array([k, k + 1, k + row, k + 1, k + row + 1, k + row])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var material := material_override
	mesh = build_mesh()
	material_override = material
