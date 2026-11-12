class_name GridData
extends Resource
## Ground grid layout of one map. GroundGrid spawns one slot per valid cell at level load.

## World position of cell G_0_0's column, on the lane centre line. Column 0 is nearest the gate.
@export var origin: Vector3 = Vector3.ZERO
## Direction columns advance in, from the gate towards spawn.
@export var column_dir: Vector3 = Vector3.RIGHT
@export var columns: int = 0
# The default must be a typed PackedFloat32Array: with a plain [] the editor reads the saved
# offsets back as empty and drops them on the next resave.
## Lateral offset of each row's cell centre from the lane, along column_dir rotated 90 degrees.
## Row 0 is on one wall side, the last row on the other; the middle row sits on the lane.
@export var row_offsets: PackedFloat32Array = PackedFloat32Array()
## Cells left out of the layout, as (column, row).
@export var holes: Array[Vector2i] = []
## Inner width of the corridor, wall to wall. Every cell must fit inside it.
@export var corridor_width: float = 23.5

const EPS := 0.001
## Clearance slack for the path check: a sample exactly min_width / 2 from an obstacle stays open.
const PATH_EPS := 0.0001

var _path_align_warned := false


static func cell_id(c: int, r: int) -> StringName:
	return StringName("G_%d_%d" % [c, r])


func row_dir() -> Vector3:
	return column_dir.normalized().cross(Vector3.UP)


## Index of the row on the lane centre line (the row starter_arrow_slot sits in).
func middle_row() -> int:
	return row_offsets.size() / 2


## Every declared cell, as (column, row), before validation.
func get_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in columns:
		for r in row_offsets.size():
			var cell := Vector2i(c, r)
			if not holes.has(cell):
				out.append(cell)
	return out


## Columns are one cell plus GameConfig.grid_cell_gap apart; rows sit at row_offsets.
func cell_position(cell: Vector2i) -> Vector3:
	if cell.y < 0 or cell.y >= row_offsets.size():
		push_error("GridData: row %d is out of range (0..%d)" % [cell.y, row_offsets.size() - 1])
		return origin
	var step: float = GameConfig.grid_cell_size + GameConfig.grid_cell_gap
	return origin + column_dir.normalized() * (cell.x * step) + row_dir() * row_offsets[cell.y]


## Cells that pass the placement rules; each rejected cell is logged with its reason.
## spawn_zone and return_zone are Area3D with one box / cylinder shape. boss_point is where
## the Bulwark stands at the Fortress (the marker, or its fallback when the level has none).
func get_valid_cells(spawn_zone: Area3D, return_zone: Area3D, command_post: Node3D, boss_point: Vector3) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in get_cells():
		var reason := check_cell(cell, spawn_zone, return_zone, command_post, boss_point)
		if reason == "":
			out.append(cell)
		else:
			push_error("GridData: dropped %s (%s)" % [cell_id(cell.x, cell.y), reason])
	return out


## Why a cell may not be built on, or "" when it is valid.
func check_cell(cell: Vector2i, spawn_zone: Area3D, return_zone: Area3D, command_post: Node3D, boss_point: Vector3) -> String:
	var corners := _corners(cell)
	var centre := cell_position(cell)

	var half_w := corridor_width * 0.5
	for p in corners:
		if absf((p - origin).dot(row_dir())) > half_w + EPS:
			return "outside the %.1f m corridor" % corridor_width

	if spawn_zone and _overlaps_box(corners, spawn_zone):
		return "inside spawn_zone"

	if return_zone and _overlaps_cylinder(centre, return_zone):
		return "inside return_zone"

	if command_post:
		var gap := _square_distance(centre, command_post.global_position)
		if gap + EPS < GameConfig.grid_min_gap_to_command_post:
			return "%.1f m from command_post" % gap

	# The Bulwark needs room to walk in, stop and turn at its standing point.
	var boss_gap := _square_distance(centre, boss_point)
	if boss_gap + EPS < GameConfig.boss_point_clear_radius:
		return "%.1f m from boss_melee_point" % boss_gap

	return ""


func _corners(cell: Vector2i) -> Array:
	var h: float = GameConfig.grid_cell_size * 0.5
	var c := cell_position(cell)
	var a := column_dir.normalized() * h
	var b := row_dir() * h
	return [c + a + b, c + a - b, c - a + b, c - a - b, c + a, c - a, c + b, c - b]


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


## Spacing of the path check samples: a quarter of the cell gap, so every cell edge and wall
## of an aligned layout falls on a sample.
static func path_sample_step() -> float:
	return GameConfig.grid_cell_gap / 4.0


## "G_c_r" -> (c, r); (-1, -1) for any other id.
static func cell_of(slot_id: StringName) -> Vector2i:
	var parts := String(slot_id).split("_")
	if parts.size() != 3 or parts[0] != "G":
		return Vector2i(-1, -1)
	if not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return Vector2i(-1, -1)
	var cell := Vector2i(parts[1].to_int(), parts[2].to_int())
	if cell.x < 0 or cell.y < 0:
		return Vector2i(-1, -1)
	return cell


## Where the boss-sized agent stands when it reaches the gate: min_width / 2 in front of it.
func gate_goal(gate: Vector3, min_width: float) -> Vector3:
	return gate + column_dir.normalized() * (min_width * 0.5)


## True when the half cell, the column step, the half corridor and every row offset are
## whole multiples of path_sample_step(), so the path check measures gaps exactly.
func is_path_aligned() -> bool:
	var step := path_sample_step()
	var h: float = GameConfig.grid_cell_size * 0.5
	var col_step: float = GameConfig.grid_cell_size + GameConfig.grid_cell_gap
	if not _is_step_multiple(h, step):
		return false
	if not _is_step_multiple(col_step, step):
		return false
	if not _is_step_multiple(corridor_width * 0.5, step):
		return false
	for offset in row_offsets:
		if not _is_step_multiple(offset, step):
			return false
	return true


## Indices into goals that cannot be reached from spawn_point by an agent min_width wide;
## empty means every goal is reachable. obstacles are (column, row) cells; gate is the Fortress
## gate, whose face closes the corridor at the gate end.
func unreachable_goals(obstacles: Array[Vector2i], spawn_point: Vector3, gate: Vector3,
		goals: Array[Vector3], min_width: float) -> PackedInt32Array:
	if goals.is_empty():
		return PackedInt32Array()
	var step := path_sample_step()
	var r := min_width * 0.5
	var h: float = GameConfig.grid_cell_size * 0.5
	var col_step: float = GameConfig.grid_cell_size + GameConfig.grid_cell_gap
	var j_max := floori((corridor_width * 0.5 - r + PATH_EPS) / step)
	if j_max < 0:
		return _all_goals(goals.size())
	var i_lo := ceili((_to_uv(gate).x + r - PATH_EPS) / step)
	var spawn_uv := _to_uv(spawn_point)
	var i_s := roundi(spawn_uv.x / step)
	if i_s < i_lo:
		push_error("GridData: spawn_point is behind the gate")
		return _all_goals(goals.size())
	_warn_if_misaligned()
	var i_reach := ceili(((columns - 1) * col_step + h + r) / step) + 1
	var i_hi := maxi(i_s, i_reach)
	var astar := _path_astar(i_lo, i_hi, j_max)
	for cell in obstacles:
		_mark_cell_solid(astar, cell, r)
	var seed_sample := _spawn_sample(astar, spawn_uv, i_s)
	if not astar.is_in_boundsv(seed_sample):
		return _all_goals(goals.size())
	var out := PackedInt32Array()
	for k in goals.size():
		var g := _goal_sample(astar, _to_uv(goals[k]))
		if astar.is_point_solid(g):
			out.append(k)
			continue
		if astar.get_id_path(seed_sample, g).is_empty():
			out.append(k)
	return out


func is_path_open(obstacles: Array[Vector2i], spawn_point: Vector3, gate: Vector3,
		goals: Array[Vector3], min_width: float) -> bool:
	return unreachable_goals(obstacles, spawn_point, gate, goals, min_width).is_empty()


## Position in (along the columns, along the rows) metres from origin.
func _to_uv(p: Vector3) -> Vector2:
	var d := p - origin
	return Vector2(d.dot(column_dir.normalized()), d.dot(row_dir()))


## Sample grid covering the corridor: samples outside the region are closer than min_width / 2
## to a wall or to the Fortress face, so they are simply not walkable.
func _path_astar(i_lo: int, i_hi: int, j_max: int) -> AStarGrid2D:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(i_lo, -j_max, i_hi - i_lo + 1, 2 * j_max + 1)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	# update() must come after region and cell_size and before any set_point_solid.
	astar.update()
	return astar


## Marks every sample closer than r to the cell square as solid.
func _mark_cell_solid(astar: AStarGrid2D, cell: Vector2i, r: float) -> void:
	if cell.y < 0 or cell.y >= row_offsets.size():
		push_error("GridData: row %d is out of range (0..%d)" % [cell.y, row_offsets.size() - 1])
		return
	var step := path_sample_step()
	var h: float = GameConfig.grid_cell_size * 0.5
	var col_step: float = GameConfig.grid_cell_size + GameConfig.grid_cell_gap
	var uc := cell.x * col_step
	var vc: float = row_offsets[cell.y]
	var reach := h + r
	var limit := (r - PATH_EPS) * (r - PATH_EPS)
	var reg := astar.region
	var i_from := maxi(reg.position.x, floori((uc - reach) / step))
	var i_to := mini(reg.end.x - 1, ceili((uc + reach) / step))
	var j_from := maxi(reg.position.y, floori((vc - reach) / step))
	var j_to := mini(reg.end.y - 1, ceili((vc + reach) / step))
	for i in range(i_from, i_to + 1):
		var du := maxf(absf(i * step - uc) - h, 0.0)
		for j in range(j_from, j_to + 1):
			var dv := maxf(absf(j * step - vc) - h, 0.0)
			if du * du + dv * dv < limit:
				astar.set_point_solid(Vector2i(i, j))


## Free sample in the spawn column nearest the spawn point's row; outside the region when the
## whole column is blocked.
func _spawn_sample(astar: AStarGrid2D, spawn_uv: Vector2, i_s: int) -> Vector2i:
	var reg := astar.region
	var j_min := reg.position.y
	var j_max := reg.end.y - 1
	var j0 := clampi(roundi(spawn_uv.y / path_sample_step()), j_min, j_max)
	for k in range(0, j_max - j_min + 1):
		var below := Vector2i(i_s, j0 - k)
		if below.y >= j_min and not astar.is_point_solid(below):
			return below
		var above := Vector2i(i_s, j0 + k)
		if above.y <= j_max and not astar.is_point_solid(above):
			return above
	return Vector2i(reg.position.x - 1, 0)


## Sample nearest the goal, clamped into the region so the search never runs out of bounds.
func _goal_sample(astar: AStarGrid2D, goal_uv: Vector2) -> Vector2i:
	var step := path_sample_step()
	var reg := astar.region
	return Vector2i(
		clampi(roundi(goal_uv.x / step), reg.position.x, reg.end.x - 1),
		clampi(roundi(goal_uv.y / step), reg.position.y, reg.end.y - 1))


func _all_goals(count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in count:
		out.append(k)
	return out


func _is_step_multiple(x: float, step: float) -> bool:
	return absf(x / step - roundf(x / step)) < 0.001


func _warn_if_misaligned() -> void:
	if _path_align_warned or is_path_aligned():
		return
	_path_align_warned = true
	push_warning("GridData: cell edges, rows or walls are not multiples of %.3f m, the path check may be off by one sample near the %.1f m limit" % [path_sample_step(), GameConfig.path_check_min_width])
