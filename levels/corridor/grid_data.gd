class_name GridData
extends Resource
## Ground grid layout of one map. GroundGrid spawns one slot per valid cell at level load.

## World position of cell G_0_0's column, on the lane centre line. Column 0 is nearest the gate.
@export var origin: Vector3 = Vector3.ZERO
## Direction columns advance in, from the gate towards spawn.
@export var column_dir: Vector3 = Vector3.RIGHT
@export var columns: int = 0
## Lateral offset of each row's cell centre from the lane, along column_dir rotated 90 degrees.
@export var row_offsets: PackedFloat32Array = []
## Cells left out of the layout, as (column, row).
@export var holes: Array[Vector2i] = []
## Inner width of the corridor, wall to wall.
@export var corridor_width: float = 16.0
## Width of the strip along the lane kept free of cells.
@export var no_build_lane_width: float = 6.0

const EPS := 0.001


static func cell_id(c: int, r: int) -> StringName:
	return StringName("G_%d_%d" % [c, r])


func row_dir() -> Vector3:
	return column_dir.normalized().cross(Vector3.UP)


## Every declared cell, as (column, row), before validation.
func get_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in columns:
		for r in row_offsets.size():
			var cell := Vector2i(c, r)
			if not holes.has(cell):
				out.append(cell)
	return out


func cell_position(cell: Vector2i) -> Vector3:
	if cell.y < 0 or cell.y >= row_offsets.size():
		push_error("GridData: row %d is out of range (0..%d)" % [cell.y, row_offsets.size() - 1])
		return origin
	var size: float = GameConfig.grid_cell_size
	return origin + column_dir.normalized() * (cell.x * size) + row_dir() * row_offsets[cell.y]


## Cells that pass the placement rules; each rejected cell is logged with its reason.
## spawn_zone and return_zone are Area3D with one box / cylinder shape; lane is the level's Path3D.
func get_valid_cells(lane: Path3D, spawn_zone: Area3D, return_zone: Area3D, command_post: Node3D) -> Array[Vector2i]:
	var min_lane: float = maxf(GameConfig.no_build_lane_min_width, GameConfig.no_build_lane_min_ratio * corridor_width)
	if no_build_lane_width + EPS < min_lane:
		push_error("GridData: no_build_lane %.1f m is narrower than %.1f m" % [no_build_lane_width, min_lane])

	var out: Array[Vector2i] = []
	for cell in get_cells():
		var reason := _check_cell(cell, lane, spawn_zone, return_zone, command_post)
		if reason == "":
			out.append(cell)
		else:
			push_error("GridData: dropped %s (%s)" % [cell_id(cell.x, cell.y), reason])
	return out


func _check_cell(cell: Vector2i, lane: Path3D, spawn_zone: Area3D, return_zone: Area3D, command_post: Node3D) -> String:
	var corners := _corners(cell)
	var centre := cell_position(cell)

	if lane and lane.curve:
		var half := no_build_lane_width * 0.5
		for p in corners + [centre]:
			if _lane_distance(lane, p) + EPS < half:
				return "inside no_build_lane"

	if spawn_zone and _overlaps_box(corners, spawn_zone):
		return "inside spawn_zone"

	if return_zone and _overlaps_cylinder(centre, return_zone):
		return "inside return_zone"

	if command_post:
		var gap := _square_distance(centre, command_post.global_position)
		if gap + EPS < GameConfig.grid_min_gap_to_command_post:
			return "%.1f m from command_post" % gap

	return ""


func _corners(cell: Vector2i) -> Array:
	var h: float = GameConfig.grid_cell_size * 0.5
	var c := cell_position(cell)
	var a := column_dir.normalized() * h
	var b := row_dir() * h
	return [c + a + b, c + a - b, c - a + b, c - a - b, c + a, c - a, c + b, c - b]


func _lane_distance(lane: Path3D, p: Vector3) -> float:
	var local := lane.global_transform.affine_inverse() * p
	var q := lane.global_transform * lane.curve.get_closest_point(local)
	return Vector2(p.x - q.x, p.z - q.z).length()


func _overlaps_box(corners: Array, area: Area3D) -> bool:
	var shape := _shape_of(area)
	if not shape is BoxShape3D:
		return false
	var ext: Vector3 = shape.size * 0.5
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in corners:
		var local: Vector3 = area.global_transform.affine_inverse() * p
		lo = Vector2(minf(lo.x, local.x), minf(lo.y, local.z))
		hi = Vector2(maxf(hi.x, local.x), maxf(hi.y, local.z))
	return lo.x < ext.x - EPS and hi.x > -ext.x + EPS and lo.y < ext.z - EPS and hi.y > -ext.z + EPS


func _overlaps_cylinder(centre: Vector3, area: Area3D) -> bool:
	var shape := _shape_of(area)
	if not shape is CylinderShape3D:
		return false
	return _square_distance(centre, area.global_position) + EPS < shape.radius


## Horizontal distance from point p to the cell square centred at centre.
func _square_distance(centre: Vector3, p: Vector3) -> float:
	var h: float = GameConfig.grid_cell_size * 0.5
	var d := p - centre
	var along := absf(d.dot(column_dir.normalized())) - h
	var across := absf(d.dot(row_dir())) - h
	return Vector2(maxf(along, 0.0), maxf(across, 0.0)).length()


func _shape_of(area: Area3D) -> Shape3D:
	for child in area.find_children("*", "CollisionShape3D", true, false):
		if child.shape:
			return child.shape
	push_error("GridData: %s has no CollisionShape3D with a shape" % area.name)
	return null
