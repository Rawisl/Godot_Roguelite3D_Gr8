extends Node3D

## Automated test for the speed lines behind the rolling boss (RollSpeedLines):
## - the mesh has one quad per line, and follows line_count
## - every line starts on or outside radius - overlap and stays on the back side (z <= 0)
## - every line runs along the roll direction (only z changes along a line)
## - every line length is inside [length_min, length_max]
## - the same seed builds the same mesh
## Run with F6.

@export var quit_when_done := true

var passes: int = 0
var fails: int = 0


func _ready() -> void:
	print("\n[roll speed lines] start")
	test_line_count()
	test_anchor_outside_body()
	test_lines_parallel_to_motion()
	test_length_range()
	test_deterministic()
	print("[roll speed lines] done: %d passed, %d failed" % [passes, fails])
	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


#region Helpers
func _make_lines() -> RollSpeedLines:
	var lines := RollSpeedLines.new()
	add_child(lines)
	return lines


func _vertices(lines: RollSpeedLines) -> PackedVector3Array:
	var arrays := lines.build_mesh().surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX]


# Each line is 4 vertices: two at its front end, two at its tail.
func _line_ends(lines: RollSpeedLines) -> Array:
	var verts := _vertices(lines)
	var ends: Array = []
	for i in range(0, verts.size(), 4):
		ends.append([verts[i], verts[i + 2]])
	return ends
#endregion


func test_line_count() -> void:
	var lines := _make_lines()
	assert_true(_vertices(lines).size() == lines.line_count * 4, "default mesh has 4 vertices per line")
	lines.line_count = 36
	assert_true(_vertices(lines).size() == 144, "36 lines give 144 vertices")
	lines.queue_free()


func test_anchor_outside_body() -> void:
	var lines := _make_lines()
	var min_r := lines.radius - lines.overlap - 1e-4
	var outside := true
	var behind := true
	for verts in [_vertices(lines)]:
		for v in verts:
			if v.z > 1e-4:
				behind = false
	for e in _line_ends(lines):
		var front: Vector3 = e[0]
		if Vector2(front.y, front.z).length() < min_r:
			outside = false
	assert_true(outside, "every line starts at radius - overlap or further out")
	assert_true(behind, "every vertex is on the back side (z <= 0)")
	lines.queue_free()


func test_lines_parallel_to_motion() -> void:
	var lines := _make_lines()
	var parallel := true
	for e in _line_ends(lines):
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		if absf(a.x - b.x) > 1e-5 or absf(a.y - b.y) > 1e-5 or b.z >= a.z:
			parallel = false
	assert_true(parallel, "every line runs straight back along -z")
	lines.queue_free()


func test_length_range() -> void:
	var lines := _make_lines()
	var in_range := true
	for e in _line_ends(lines):
		var length: float = (e[0] as Vector3).distance_to(e[1])
		if length < lines.length_min - 1e-4 or length > lines.length_max + 1e-4:
			in_range = false
	assert_true(in_range, "every line length is inside [length_min, length_max]")
	lines.queue_free()


func test_deterministic() -> void:
	var lines := _make_lines()
	lines.random_seed = 7
	var first := _vertices(lines)
	var second := _vertices(lines)
	lines.random_seed = 8
	var other := _vertices(lines)
	assert_true(first == second, "same seed builds the same mesh")
	assert_true(first != other, "a different seed builds a different mesh")
	lines.queue_free()
