@tool
class_name RollSpeedLines
extends MeshInstance3D

## Speed lines behind the rolling boss. Builds one mesh of thin quads, one per line, laid along
## the roll direction on the back half of the rolling ring: each line starts just outside the
## ring (radius - overlap) and trails backwards along -Z, so it never crosses the body.
## Place this node at the centre of the ring, as a child of the boss, with +Z pointing the way
## the boss rolls. The shader (boss_roll_speed_lines.gdshader) turns each quad's width towards
## the camera and animates it; drive its "intensity" instance uniform to show or hide the lines.
##
## Vertex layout per line: 0-1 at the front end, 2-3 at the tail. UV.x is 0 at the front and 1
## at the tail, UV.y is -1 / +1 for the two sides. UV2 is (random value of the line, length).

@export_range(1, 200) var line_count := 40:
	set(value):
		line_count = value
		_rebuild()
## Distance from the ring centre to the outermost part of the body on the back half, in metres.
@export var radius := 0.63:
	set(value):
		radius = value
		_rebuild()
## How far a line may start inside radius, in metres.
@export var overlap := 0.03:
	set(value):
		overlap = value
		_rebuild()
## Range the lines are spread over, in degrees: 0 is straight down from the centre, 90 straight
## back, 180 straight up.
@export_range(0.0, 180.0) var angle_from_deg := 25.0:
	set(value):
		angle_from_deg = value
		_rebuild()
@export_range(0.0, 180.0) var angle_to_deg := 175.0:
	set(value):
		angle_to_deg = value
		_rebuild()
## Lines are scattered across the ring's width within +-x_spread metres.
@export var x_spread := 0.0:
	set(value):
		x_spread = value
		_rebuild()
@export var length_min := 0.25:
	set(value):
		length_min = value
		_rebuild()
@export var length_max := 0.6:
	set(value):
		length_max = value
		_rebuild()
@export var random_seed := 1:
	set(value):
		random_seed = value
		_rebuild()


func _ready() -> void:
	_rebuild()


func build_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	var from := deg_to_rad(minf(angle_from_deg, angle_to_deg))
	var to := deg_to_rad(maxf(angle_from_deg, angle_to_deg))
	var r := radius - overlap
	for i in line_count:
		# Even slots over the range, jittered inside each slot so the lines are staggered.
		var a := lerpf(from, to, (i + rng.randf()) / line_count)
		var x := rng.randf_range(-x_spread, x_spread)
		var length := rng.randf_range(length_min, length_max)
		var front := Vector3(x, -cos(a) * r, -sin(a) * r)
		var tail := front + Vector3(0.0, 0.0, -length)
		var rand := rng.randf()
		var base := verts.size()
		verts.append_array([front, front, tail, tail])
		uvs.append_array([Vector2(0, -1), Vector2(0, 1), Vector2(1, -1), Vector2(1, 1)])
		for k in 4:
			uv2s.append(Vector2(rand, length))
		indices.append_array([base, base + 1, base + 2, base + 2, base + 1, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices
	var array_mesh := ArrayMesh.new()
	if line_count > 0:
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var material := material_override
	mesh = build_mesh()
	material_override = material
	# The shader widens and slides the quads, so the mesh's own box is too tight for culling.
	extra_cull_margin = 1.0
