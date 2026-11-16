extends SceneTree
## Builds the Hazard Trial room: its meshes in contents/assets/environment/hazard_room/ and the
## scene levels/corridor/hazard_room.tscn. Run from the project folder:
##   Godot --headless --path . --script res://levels/corridor/hazard_room_builder.gd
## Then rebake the level navmesh, since the room floor and walls are part of its source.
## Room space: -Z is the far side (top of the screen once the level turns the room by the camera
## yaw), +X is right. Sizes in metres.

const MESH_DIR := "res://contents/assets/environment/hazard_room/"
const SCENE_PATH := "res://levels/corridor/hazard_room.tscn"
const ROOM_SCRIPT := "res://levels/corridor/hazard_room.gd"
const ROCKS_SCRIPT := "res://levels/corridor/floating_rocks.gd"
const CLOUDS_SCRIPT := "res://levels/corridor/cloud_rings.gd"
const MAT_CLOUDS := "res://art/materials/hazard_cloud_ring.tres"

const MAT_GRASS := "res://art/materials/env_grass.tres"
const MAT_STONE := "res://art/materials/struct_stone.tres"
const MAT_ROCK := "res://art/materials/env_rock.tres"
const MAT_DIRT := "res://art/materials/env_dirt.tres"
const MAT_PAD := "res://art/materials/hazard_pad.tres"
const MAT_GLOW := "res://art/materials/hazard_glow.tres"
const MAT_BACKDROP := "res://art/materials/hazard_backdrop.tres"

## Walkable floor radius: 30 m across inside the rim wall.
const ARENA_RADIUS := 15.0
const WALL_THICK := 0.6
## Spawn pads: inner radius and distance of their centre from the room centre.
const PAD_RADIUS := 2.8
const PAD_DIST := 15.5
const BOSS_PAD_RADIUS := 3.5
const BOSS_PAD_DIST := 16.2
## Pad angles from -Z towards +X, in degrees. The middle one is the boss pad.
const PAD_ANGLES: Array[float] = [-72.0, -36.0, 0.0, 36.0, 72.0]
const BOSS_PAD := 2

const SLAB := 0.6
## Stretches the rocky underside of the island downwards (1 = the first version, tip at 8.5 m).
## The camera looks down at 45 degrees, so the floor hides most of it; it has to go deep and lean
## towards the camera (+Z) to show under the front edge.
const UNDERSIDE_DEPTH := 2.2
## How far the tip of the underside leans towards the camera, in metres; the rings above follow.
const UNDERSIDE_LEAN := 4.0
## Rim wall height at the front (camera side) and at the back; low at the front so it hides less.
const RIM_HEIGHT_FRONT := 0.5
const RIM_HEIGHT_BACK := 1.0
const PAD_WALL_HEIGHT := 1.3
## Walls block movement up to this height, whatever their look.
const COLLISION_HEIGHT := 3.0
## Fixed camera: focus a little towards the pads so the whole room is centred on screen.
const CAMERA_FOCUS := Vector3(0, 0, -2.3)
const CAMERA_SIZE := 31.0

## Painted sky on a flat quad behind the island, facing the fixed camera (pitch -45, and the level
## turns the room by the camera yaw). With an orthographic camera its distance does not change its
## size; it only has to sit behind everything. 2:1 like the image; 70 m still covers a 21:9 screen
## (about 69 m wide at camera size 31).
const BACKDROP_DISTANCE := 60.0
const BACKDROP_SIZE := Vector2(70.0, 35.0)
const CAMERA_BACK := Vector3(0.0, 0.70710678, 0.70710678)

## Faint cloud rings below the island: inner radius, outer radius, height. Small enough that their
## sides and back stay on screen in the fixed room frame; the fronts fall below the screen.
const CLOUD_RINGS: Array[Vector3] = [
	Vector3(20.5, 25.0, -2.5),
	Vector3(23.5, 29.0, -6.0),
	Vector3(26.5, 33.0, -10.0),
]
const CLOUD_SEGMENTS := 128

const ARENA_SEGMENTS := 144
const PAD_SEGMENTS := 48
const SEGMENTS_PER_BLOCK := 3

var _rng := RandomNumberGenerator.new()
## uid of the scene before this run, kept so references to it stay valid.
var _old_uid := ""


func _init() -> void:
	_rng.seed = 20261116
	_old_uid = _scene_uid()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MESH_DIR))
	var floor_mesh := _build_floor()
	var walls_mesh := _build_walls(false)
	var walls_col := _build_walls(true)
	var marks_mesh := _build_marks()
	var rock_meshes := _build_floating_rocks()
	_save(floor_mesh, "hazard_room_floor.res")
	_save(walls_mesh, "hazard_room_walls.res")
	_save(marks_mesh, "hazard_room_marks.res")
	for i in rock_meshes.size():
		_save(rock_meshes[i], "hazard_room_rock_%d.res" % (i + 1))
	for i in CLOUD_RINGS.size():
		_save(_cloud_ring(CLOUD_RINGS[i].x, CLOUD_RINGS[i].y, (i + 1) * 0.29), "hazard_room_clouds_%d.res" % (i + 1))
	var floor_shape := _top_shape()
	var walls_shape := walls_col.create_trimesh_shape()
	_save(floor_shape, "hazard_room_floor_shape.res")
	_save(walls_shape, "hazard_room_walls_shape.res")
	_build_scene()
	print("hazard_room: done")
	quit()


func _save(res: Resource, file: String) -> void:
	var path := MESH_DIR + file
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("hazard_room: cannot save %s (%d)" % [path, err])
		return
	res.take_over_path(path)


## uid of the scene file before this run, so references to it stay valid.
func _scene_uid() -> String:
	if not FileAccess.file_exists(SCENE_PATH):
		return ""
	var header := FileAccess.get_file_as_string(SCENE_PATH).get_slice("\n", 0)
	var at := header.find('uid="')
	if at < 0:
		return ""
	return header.substr(at + 5, header.find('"', at + 5) - at - 5)


## uid of the room script from its .uid file; --script runs have no uid cache to ask.
func _script_uid() -> String:
	var uid_path := ROOM_SCRIPT + ".uid"
	if not FileAccess.file_exists(uid_path):
		return ""
	return FileAccess.get_file_as_string(uid_path).strip_edges()


#region Layout
func _pad_center(i: int) -> Vector2:
	var a := deg_to_rad(PAD_ANGLES[i])
	var d := BOSS_PAD_DIST if i == BOSS_PAD else PAD_DIST
	return Vector2(sin(a), -cos(a)) * d


func _pad_radius(i: int) -> float:
	return BOSS_PAD_RADIUS if i == BOSS_PAD else PAD_RADIUS


func _circle(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for s in segments:
		var a := TAU * s / segments
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	return points


## Outer edge of the floor: the arena and every pad, out to the outside of their walls.
func _outline() -> PackedVector2Array:
	var shape := _circle(Vector2.ZERO, ARENA_RADIUS + WALL_THICK, ARENA_SEGMENTS)
	for i in PAD_ANGLES.size():
		var pad := _circle(_pad_center(i), _pad_radius(i) + WALL_THICK, PAD_SEGMENTS)
		var merged := Geometry2D.merge_polygons(shape, pad)
		for poly in merged:
			if not Geometry2D.is_polygon_clockwise(poly):
				shape = poly
				break
	return shape
#endregion


#region Triangles
## Adds a triangle facing out_dir (Godot draws clockwise triangles as front faces).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out_dir: Vector3) -> void:
	if (b - a).cross(c - a).dot(out_dir) > 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out_dir: Vector3) -> void:
	_tri(st, a, b, c, out_dir)
	_tri(st, a, c, d, out_dir)


func _begin(material_path: String) -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(load(material_path))
	return st


func _commit(surfaces: Array[SurfaceTool]) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for st in surfaces:
		st.generate_normals()
		st.commit(mesh)
	return mesh
#endregion


#region Floor and island
## Grass top over the whole outline, then a rock slab edge and a jagged island underneath.
func _build_floor() -> ArrayMesh:
	var outline := _outline()
	print("hazard_room: outline %d points, %d top triangles" % [outline.size(), Geometry2D.triangulate_polygon(outline).size() / 3])
	var top := _begin(MAT_GRASS)
	_add_flat(top, outline, 0.0)
	var rock := _begin(MAT_ROCK)
	# Rings from the floor edge down to the tip of the island, each a jittered copy of the outline.
	var rings: Array[PackedVector3Array] = []
	var d := UNDERSIDE_DEPTH
	var steps := [[1.0, 0.0, 0.0], [1.0, -SLAB, 0.0], [0.82, -2.4 * d, 0.06], [0.55, -4.6 * d, 0.1], [0.25, -6.8 * d, 0.12]]
	for step in steps:
		var ring := PackedVector3Array()
		for p in outline:
			var k: float = step[0] * (1.0 + _rng.randf_range(-step[2], step[2]))
			var y: float = step[1] + (_rng.randf_range(-0.3, 0.3) if step[2] > 0.0 else 0.0)
			var lean := UNDERSIDE_LEAN * clampf(-y / (8.5 * UNDERSIDE_DEPTH), 0.0, 1.0)
			ring.append(Vector3(p.x * k, y, p.y * k + lean))
		rings.append(ring)
	var n := outline.size()
	for r in rings.size() - 1:
		var a := rings[r]
		var b := rings[r + 1]
		for i in n:
			var j := (i + 1) % n
			var mid := (a[i] + a[j] + b[i] + b[j]) * 0.25
			_quad(rock, a[i], a[j], b[j], b[i], Vector3(mid.x, 0.0, mid.z).normalized() + Vector3.DOWN * 0.5)
	var tip := Vector3(0, -8.5 * d, UNDERSIDE_LEAN - 1.0)
	var last := rings[rings.size() - 1]
	for i in n:
		_tri(rock, last[i], last[(i + 1) % n], tip, Vector3(last[i].x, -2.0, last[i].z))
	return _commit([top, rock])


## Flat upward polygon at height y.
func _add_flat(st: SurfaceTool, poly: PackedVector2Array, y: float) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	for t in range(0, idx.size(), 3):
		var a := poly[idx[t]]
		var b := poly[idx[t + 1]]
		var c := poly[idx[t + 2]]
		_tri(st, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), Vector3.UP)


## Collision for the floor: just the walkable top, the shape the navmesh is baked from.
func _top_shape() -> ConcavePolygonShape3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_flat(st, _outline(), 0.0)
	return st.commit().create_trimesh_shape()
#endregion


#region Walls
## Rim wall around the arena, broken where the pads open onto it, and a wall around the outer
## part of every pad. collision: one tall unbroken wall; otherwise stone blocks of varied height.
func _build_walls(collision: bool) -> ArrayMesh:
	var st := _begin(MAT_STONE)
	_wall_ring(st, Vector2.ZERO, ARENA_RADIUS, ARENA_SEGMENTS, collision, _keep_rim, _rim_height)
	for i in PAD_ANGLES.size():
		_wall_ring(st, _pad_center(i), _pad_radius(i), PAD_SEGMENTS, collision, _keep_pad, _pad_height)
	return _commit([st])


## The rim wall stops where a pad opens onto the arena.
func _keep_rim(p: Vector2) -> bool:
	for i in PAD_ANGLES.size():
		if p.distance_to(_pad_center(i)) < _pad_radius(i) + WALL_THICK * 0.5:
			return false
	return true


func _rim_height(p: Vector2) -> float:
	var back := clampf(-p.y / ARENA_RADIUS * 0.5 + 0.5, 0.0, 1.0)
	return lerpf(RIM_HEIGHT_FRONT, RIM_HEIGHT_BACK, back)


## A pad wall only runs outside the arena, so the side facing the middle stays open.
func _keep_pad(p: Vector2) -> bool:
	return p.length() > ARENA_RADIUS - 0.1


func _pad_height(_p: Vector2) -> float:
	return PAD_WALL_HEIGHT


## Wall from radius r_in to r_in + WALL_THICK around center, on the segments where keep() holds.
func _wall_ring(st: SurfaceTool, center: Vector2, r_in: float, segments: int, collision: bool,
		keep: Callable, height_at: Callable) -> void:
	var r_mid := r_in + WALL_THICK * 0.5
	var runs: Array[Array] = []
	var run: Array[int] = []
	for s in segments:
		var a := TAU * s / segments
		if keep.call(center + Vector2(cos(a), sin(a)) * r_mid):
			run.append(s)
		elif not run.is_empty():
			runs.append(run)
			run = []
	if not run.is_empty():
		# The kept run that crosses angle 0 joins the first one.
		if not runs.is_empty() and runs[0][0] == 0:
			run.append_array(runs[0])
			runs[0] = run
		else:
			runs.append(run)
	var step := TAU / segments
	for kept in runs:
		var first: int = kept[0]
		var count := kept.size()
		if collision:
			_wall_piece(st, center, r_in, first * step, (first + count) * step, COLLISION_HEIGHT, 0.0)
			continue
		var s := 0
		while s < count:
			var span := mini(SEGMENTS_PER_BLOCK, count - s)
			var a0 := (first + s) * step
			var a1 := (first + s + span) * step
			var mid := center + Vector2(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5)) * r_mid
			var h: float = height_at.call(mid) * _rng.randf_range(0.8, 1.05)
			_wall_piece(st, center, r_in + _rng.randf_range(-0.05, 0.05), a0, a1, h, step * 0.06)
			s += span


## One closed curved block from angle a0 to a1, with a small gap at each end.
func _wall_piece(st: SurfaceTool, center: Vector2, r_in: float, a0: float, a1: float, height: float, gap: float) -> void:
	a0 += gap
	a1 -= gap
	var r_out := r_in + WALL_THICK
	var c3 := Vector3(center.x, 0.0, center.y)
	var sub := maxi(1, ceili((a1 - a0) / deg_to_rad(4.0)))
	for k in sub:
		var b0 := lerpf(a0, a1, float(k) / sub)
		var b1 := lerpf(a0, a1, float(k + 1) / sub)
		var d0 := Vector3(cos(b0), 0.0, sin(b0))
		var d1 := Vector3(cos(b1), 0.0, sin(b1))
		var dm := (d0 + d1).normalized()
		var i0 := c3 + d0 * r_in
		var i1 := c3 + d1 * r_in
		var o0 := c3 + d0 * r_out
		var o1 := c3 + d1 * r_out
		var up := Vector3.UP * height
		_quad(st, i0, i1, i1 + up, i0 + up, -dm)
		_quad(st, o0, o1, o1 + up, o0 + up, dm)
		_quad(st, i0 + up, i1 + up, o1 + up, o0 + up, Vector3.UP)
	# End caps.
	for cap in [[a0, -1.0], [a1, 1.0]]:
		var d := Vector3(cos(cap[0]), 0.0, sin(cap[0]))
		var tangent := Vector3(-d.z, 0.0, d.x) * float(cap[1])
		var i := c3 + d * r_in
		var o := c3 + d * r_out
		var up := Vector3.UP * height
		_quad(st, i, o, o + up, i + up, tangent)
#endregion


#region Marks on the floor
## Dirt ring where the commander appears, and on every pad a slate disc with a glowing ring.
func _build_marks() -> ArrayMesh:
	var dirt := _begin(MAT_DIRT)
	var pad := _begin(MAT_PAD)
	var glow := _begin(MAT_GLOW)
	_ring(dirt, Vector2.ZERO, 1.4, 1.9, 0.02, 40)
	for i in PAD_ANGLES.size():
		var c := _pad_center(i)
		var r := _pad_radius(i)
		_ring(pad, c, 0.0, r, 0.015, PAD_SEGMENTS)
		var width := 0.28 if i == BOSS_PAD else 0.2
		_ring(glow, c, r - 0.55 - width, r - 0.55, 0.03, PAD_SEGMENTS)
	return _commit([dirt, pad, glow])


## Flat ring (or disc when r0 is 0) at height y.
func _ring(st: SurfaceTool, center: Vector2, r0: float, r1: float, y: float, segments: int) -> void:
	for s in segments:
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		var p0 := center + d0 * r1
		var p1 := center + d1 * r1
		var q0 := center + d0 * r0
		var q1 := center + d1 * r0
		var a := Vector3(p0.x, y, p0.y)
		var b := Vector3(p1.x, y, p1.y)
		if r0 <= 0.0:
			_tri(st, Vector3(center.x, y, center.y), a, b, Vector3.UP)
		else:
			_quad(st, Vector3(q0.x, y, q0.y), Vector3(q1.x, y, q1.y), b, a, Vector3.UP)
#endregion


#region Cloud rings
## Flat ring for hazard_cloud_ring.gdshader: UV.x once around, UV.y from inside to outside,
## vertex colour red = seed.
func _cloud_ring(r_in: float, r_out: float, seed: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(load(MAT_CLOUDS))
	var color := Color(seed, 0.0, 0.0)
	for s in CLOUD_SEGMENTS:
		var u0 := float(s) / CLOUD_SEGMENTS
		var u1 := float(s + 1) / CLOUD_SEGMENTS
		var d0 := Vector3(cos(u0 * TAU), 0.0, sin(u0 * TAU))
		var d1 := Vector3(cos(u1 * TAU), 0.0, sin(u1 * TAU))
		var quad := [
			[d0 * r_in, Vector2(u0, 0.0)], [d1 * r_in, Vector2(u1, 0.0)],
			[d1 * r_out, Vector2(u1, 1.0)], [d0 * r_out, Vector2(u0, 1.0)],
		]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(color)
			st.set_uv(quad[k][1])
			st.set_normal(Vector3.UP)
			st.add_vertex(quad[k][0])
	return st.commit()
#endregion


#region Floating rocks
## Where the rocks start around the island, below the floor so they never hide the fight.
## floating_rocks.gd moves them round from there.
const ROCK_SPOTS: Array[Vector3] = [
	Vector3(-21.0, -3.5, -9.0), Vector3(22.5, -5.0, -6.0), Vector3(-19.0, -7.0, 8.0),
	Vector3(20.0, -8.0, 9.5), Vector3(-6.0, -9.5, -24.0), Vector3(9.0, -6.0, -25.0),
]


## One mesh per rock, centred on its own origin so it can turn in place.
func _build_floating_rocks() -> Array[ArrayMesh]:
	var meshes: Array[ArrayMesh] = []
	for spot in ROCK_SPOTS:
		var st := _begin(MAT_ROCK)
		_rock(st, Vector3.ZERO, _rng.randf_range(0.9, 1.8))
		meshes.append(_commit([st]))
	return meshes


func _rock(st: SurfaceTool, at: Vector3, size: float) -> void:
	var arrays := SphereMesh.new()
	arrays.radial_segments = 7
	arrays.rings = 4
	arrays.radius = size
	arrays.height = size * 1.6
	var data := arrays.get_mesh_arrays()
	var verts: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	# Same jitter for vertices on the same spot, so the rock stays closed.
	var moved := {}
	for v in verts:
		var key := v.snapped(Vector3.ONE * 0.001)
		if not moved.has(key):
			moved[key] = v * _rng.randf_range(0.8, 1.15) + at
	for t in range(0, index.size(), 3):
		var a: Vector3 = moved[verts[index[t]].snapped(Vector3.ONE * 0.001)]
		var b: Vector3 = moved[verts[index[t + 1]].snapped(Vector3.ONE * 0.001)]
		var c: Vector3 = moved[verts[index[t + 2]].snapped(Vector3.ONE * 0.001)]
		_tri(st, a, b, c, (a + b + c) / 3.0 - at)
#endregion


#region Scene
func _build_scene() -> void:
	var root := Node3D.new()
	root.name = "HazardRoom"

	var geometry := _add(root, root, Node3D.new(), "Geometry")
	geometry.add_to_group(&"nav_source", true)
	var floor_body := _add(root, geometry, StaticBody3D.new(), "Floor") as StaticBody3D
	var floor_mesh := _add(root, floor_body, MeshInstance3D.new(), "Mesh") as MeshInstance3D
	floor_mesh.mesh = load(MESH_DIR + "hazard_room_floor.res")
	var floor_shape := _add(root, floor_body, CollisionShape3D.new(), "Shape") as CollisionShape3D
	floor_shape.shape = load(MESH_DIR + "hazard_room_floor_shape.res")
	var walls_body := _add(root, geometry, StaticBody3D.new(), "Walls") as StaticBody3D
	var walls_mesh := _add(root, walls_body, MeshInstance3D.new(), "Mesh") as MeshInstance3D
	walls_mesh.mesh = load(MESH_DIR + "hazard_room_walls.res")
	var walls_shape := _add(root, walls_body, CollisionShape3D.new(), "Shape") as CollisionShape3D
	walls_shape.shape = load(MESH_DIR + "hazard_room_walls_shape.res")

	var marks := _add(root, root, MeshInstance3D.new(), "FloorMarks") as MeshInstance3D
	marks.mesh = load(MESH_DIR + "hazard_room_marks.res")
	marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rocks := _add(root, root, Node3D.new(), "FloatingRocks") as Node3D
	rocks.set_script(load(ROCKS_SCRIPT))
	for i in ROCK_SPOTS.size():
		var rock := _add(root, rocks, MeshInstance3D.new(), "Rock%d" % (i + 1)) as MeshInstance3D
		rock.mesh = load(MESH_DIR + "hazard_room_rock_%d.res" % (i + 1))
		rock.position = ROCK_SPOTS[i]

	var clouds := _add(root, root, Node3D.new(), "CloudRings") as Node3D
	clouds.set_script(load(CLOUDS_SCRIPT))
	for i in CLOUD_RINGS.size():
		var ring := _add(root, clouds, MeshInstance3D.new(), "Ring%d" % (i + 1)) as MeshInstance3D
		ring.mesh = load(MESH_DIR + "hazard_room_clouds_%d.res" % (i + 1))
		ring.position.y = CLOUD_RINGS[i].z
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var backdrop := _add(root, root, MeshInstance3D.new(), "Backdrop") as MeshInstance3D
	var quad := QuadMesh.new()
	quad.size = BACKDROP_SIZE
	quad.material = load(MAT_BACKDROP)
	backdrop.mesh = quad
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.position = CAMERA_FOCUS - CAMERA_BACK * BACKDROP_DISTANCE
	backdrop.rotation_degrees.x = -45.0

	var commander := _add(root, root, Marker3D.new(), "CommanderSpawn") as Marker3D
	commander.unique_name_in_owner = true
	# Faces the pads.
	commander.basis = Basis.looking_at(Vector3.FORWARD)
	var spawns := _add(root, root, Node3D.new(), "EnemySpawns")
	spawns.unique_name_in_owner = true
	for i in PAD_ANGLES.size():
		var marker := _add(root, spawns, Marker3D.new(), "S%d" % (i + 1)) as Marker3D
		var c := _pad_center(i)
		marker.position = Vector3(c.x, 0.0, c.y)
		marker.basis = Basis.looking_at(-marker.position.normalized())
		if i == BOSS_PAD:
			marker.add_to_group(&"hazard_boss_spawn", true)
	var frame := _add(root, root, Marker3D.new(), "CameraFrame") as Marker3D
	frame.unique_name_in_owner = true
	frame.position = CAMERA_FOCUS

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, SCENE_PATH)
	if err != OK:
		push_error("hazard_room: cannot save scene (%d)" % err)
	root.free()
	_attach_script()


## The room script uses autoloads, which a --script run does not load, so it is written into the
## saved scene as text instead of being attached while building.
func _attach_script() -> void:
	# Line ends are normalised, so a checkout with CRLF still finds every line.
	var text := FileAccess.get_file_as_string(SCENE_PATH).replace("\r\n", "\n")
	var header := "[gd_scene format=3]"
	if not _old_uid.is_empty() and text.begins_with(header):
		text = text.replace(header, '[gd_scene format=3 uid="%s"]' % _old_uid)
	var uid := _script_uid()
	var uid_attr := (' uid="%s"' % uid) if uid.begins_with("uid://") else ""
	var ext := '[ext_resource type="Script"%s path="%s" id="0_room"]\n' % [uid_attr, ROOM_SCRIPT]
	var first_ext := text.find("[ext_resource")
	var root_at := text.find('[node name="HazardRoom"')
	if first_ext < 0 or root_at < 0:
		push_error("hazard_room: unexpected scene layout, the room script was not attached")
		return
	text = text.insert(first_ext, ext)
	var root_line := text.find("\n", text.find('[node name="HazardRoom"'))
	if root_line < 0:
		push_error("hazard_room: unexpected scene layout, the room script was not attached")
		return
	text = text.insert(root_line + 1, 'script = ExtResource("0_room")\ncamera_size = %s\nboss_spawn_index = %d\n' % [CAMERA_SIZE, BOSS_PAD])
	var file := FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("hazard_room: cannot write %s (%d)" % [SCENE_PATH, FileAccess.get_open_error()])
		return
	file.store_string(text)


func _add(root: Node, parent: Node, node: Node, node_name: String) -> Node:
	node.name = node_name
	parent.add_child(node)
	node.owner = root
	return node
#endregion
