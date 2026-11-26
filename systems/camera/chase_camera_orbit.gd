class_name ChaseCameraOrbit
extends RefCounted
## Reusable third-person orbit. CameraRig owns context, cursor and frame signals; this class
## owns the perspective camera's pose and zoom, independent of any particular level. The camera is
## kept out of walls: a sphere sweeps from the pivot through the shoulder point to the wanted
## position and stops at the first thing on collision_mask. Being blocked pulls the camera in at
## once; once the way has stayed clear for release_delay it eases back out over return_time, so a
## camera next to a wall edge does not flicker in and out.

var camera: Camera3D
var yaw: float = 0.0
var pitch_deg: float = 0.0
var pitch_min: float = 0.0
var pitch_max: float = 0.0
var far_pitch: float = 0.0
var distance: float = 0.0
var distance_near: float = 0.0
var distance_up: float = 0.0
var pivot_height: float = 0.0
var min_height: float = 0.0
var shoulder: float = 0.0
var aim_tilt_deg: float = 0.0
var follow_smoothing: float = 0.0
var zoom_min: float = 1.0
var zoom_step: float = 0.0
var zoom_smoothing: float = 0.0
var zoom: float = 1.0
var zoom_target: float = 1.0
## Physics layers the camera cannot pass through, and the radius of the sphere that sweeps them.
var collision_mask: int = 9
var probe_radius: float = 0.3
## The camera never comes nearer to the pivot than this, even when a wall is right behind it.
var min_distance: float = 1.0
## Real seconds the camera takes to ease back out once nothing blocks it.
var return_time: float = 0.25
## Real seconds the way has to stay clear before the camera starts to ease back out.
var release_delay: float = 0.15
## The way has to get clearer than this share of the way before it counts as the wall having let
## go; smaller changes leave the camera where it is.
var release_margin: float = 0.01
## How far the commander may stand from the middle of the screen toward the left edge, as a share
## of that half width. A camera pulled in by a wall narrows its shoulder offset to stay inside it.
var max_screen_offset: float = 0.6
## Replaces the ease back out with a cut.
var reduced_motion: bool = false
## Bodies the sweep ignores, such as the commander being followed.
var exclude: Array[RID] = []
## Share of the free distance the camera stands at, 1 when nothing blocks it.
var _clearance: float = 1.0
## Real seconds the way has been clearer than the camera stands.
var _clear_time: float = 0.0
## True once the delay is over and the camera is easing out.
var _releasing: bool = false
var _probe := SphereShape3D.new()
var _pivot_gap: float = 0.0
## Where the sweep put the start of the way back, the pivot moved sideways by the shoulder.
var _path_start: Vector3 = Vector3.ZERO
## Where the commander really is minus where the smoothed focus is, for the framing.
var _frame_offset: Vector3 = Vector3.ZERO

## Set when the push out to min_distance was dropped to keep the commander framed; a test reads it.
var push_rejected_by_frame: bool = false

## Metres of play in the framing check, for rounding.
const FRAME_SLACK := 0.0005
## Where the commander really is on the ground, for the framing. INF means the focus itself.
var actual_focus: Vector3 = Vector3.INF

## Most times the way back is swept again with a narrower shoulder; a variable so a test can
## force the final check below to do the work.
var max_resweeps: int = 6


## The caller supplies a profile; the orbit does not know which scene provided it.
func configure(view: Camera3D, settings: Dictionary, initial_yaw: float) -> void:
	camera = view
	yaw = initial_yaw
	pitch_min = minf(settings.pitch_min, settings.pitch_max)
	pitch_max = maxf(settings.pitch_min, settings.pitch_max)
	pitch_deg = clampf(settings.pitch, pitch_min, pitch_max)
	far_pitch = clampf(settings.far_pitch, pitch_min, pitch_max)
	distance = settings.distance
	distance_near = settings.distance_near
	distance_up = settings.distance_up
	pivot_height = settings.pivot_height
	min_height = settings.min_height
	shoulder = settings.shoulder
	aim_tilt_deg = settings.aim_tilt
	follow_smoothing = settings.follow_smoothing
	zoom_min = clampf(settings.zoom_min, 0.05, 1.0)
	zoom_step = settings.zoom_step
	zoom_smoothing = settings.zoom_smoothing
	zoom = 1.0
	zoom_target = 1.0
	camera.fov = settings.fov
	camera.far = settings.far
	collision_mask = settings.get("collision_mask", 9)
	probe_radius = settings.get("probe_radius", 0.3)
	min_distance = settings.get("min_distance", 1.0)
	return_time = settings.get("return_time", 0.25)
	release_delay = settings.get("release_delay", 0.15)
	release_margin = settings.get("release_margin", 0.01)
	max_screen_offset = settings.get("max_screen_offset", 0.6)
	_clearance = 1.0
	_clear_time = 0.0
	_releasing = false


func follow(current: Vector3, target: Vector3, real_delta: float) -> Vector3:
	var weight := 1.0 - exp(-real_delta / maxf(follow_smoothing, 0.001))
	return current.lerp(target, weight)


func advance(real_delta: float, focus: Vector3) -> void:
	var weight := 1.0 - exp(-real_delta / maxf(zoom_smoothing, 0.001))
	zoom = lerpf(zoom, zoom_target, weight)
	place(focus, real_delta)


func turn(screen_motion: Vector2, sensitivity: float, focus: Vector3) -> void:
	yaw = wrapf(yaw - deg_to_rad(screen_motion.x * sensitivity), -PI, PI)
	pitch_deg = clampf(pitch_deg - screen_motion.y * sensitivity, pitch_min, pitch_max)
	place(focus)


func change_zoom(notches: float, reduced_motion: bool, focus: Vector3) -> void:
	zoom_target = clampf(zoom_target + notches * zoom_step, zoom_min, 1.0)
	if reduced_motion:
		zoom = zoom_target
		place(focus)


## Places the camera at once with nothing to ease from, for a cut onto the commander.
func snap(focus: Vector3) -> void:
	_clearance = 1.0
	_clear_time = 0.0
	_releasing = false
	place(focus)


## Distance from the camera to the pivot as of the last placement, walls included.
func get_pivot_gap() -> float:
	return _pivot_gap


## real_delta is the real time since the last call; it only drives the ease back out, so a call
## without it (a mouse turn) pulls in when blocked but does not move out.
func place(focus: Vector3, real_delta: float = 0.0) -> void:
	if camera == null:
		return
	var pivot := focus + Vector3.UP * pivot_height
	var orbit := Basis.from_euler(Vector3(deg_to_rad(pitch_deg), yaw, 0.0))
	var view := Basis.from_euler(Vector3(deg_to_rad(pitch_deg + aim_tilt_deg), yaw, 0.0))
	var actual := (actual_focus if actual_focus.is_finite() else focus) + Vector3.UP * pivot_height
	_frame_offset = actual - pivot
	var standing := _clear_position(pivot, orbit.x, orbit.z * orbit_distance(), -view.z, real_delta)
	camera.global_transform = Transform3D(view, standing)
	_pivot_gap = standing.distance_to(actual)


## The camera position: from the pivot sideways by the shoulder (side_axis), then back by back,
## pulled in front of whatever blocks that way. The way back sets the clearance. The commander
## has to stay on screen between the middle and max_screen_offset of the half width to the left
## (see _shoulder_for), which a short way back or a commander ahead of the smoothed pivot would
## break with the full shoulder, so the shoulder is set for the clearance and the way is swept
## again. Each pass can only lower the clearance and narrow the shoulder, so it settles in a few
## passes. A final check then makes sure the commander is framed where the camera ended up: if not,
## the shoulder is narrowed for that depth and swept once more, and if that does not frame it
## either the last safe position stays. The camera is never put inside a wall.
func _clear_position(pivot: Vector3, side_axis: Vector3, back: Vector3, forward: Vector3,
		real_delta: float) -> Vector3:
	var space := _space()
	if space == null:
		return pivot + side_axis * shoulder + back
	var side := shoulder
	var path_free := _sweep_path(space, pivot, side_axis * side, back)
	_clearance = _next_clearance(path_free, real_delta)
	for attempt in max_resweeps:
		var limited := _shoulder_for(_clearance, side_axis, forward)
		if is_equal_approx(limited, side):
			break
		side = limited
		path_free = _sweep_path(space, pivot, side_axis * side, back)
		if path_free < _clearance:
			_clearance = path_free
			_clear_time = 0.0
			_releasing = false
	var standing := _path_start + back * _clearance
	if not _is_framed(standing, pivot, side_axis, forward):
		standing = _frame_by_narrowing(space, standing, pivot, side_axis, back, forward, side)
	return _keep_min_distance(space, pivot, standing, _path_start + back, side_axis, forward)


## The last attempt at framing: the shoulder that suits the depth the camera ended at, swept once
## more. Returns that position when it is clear and frames the commander, else the position given.
func _frame_by_narrowing(space: PhysicsDirectSpaceState3D, safe: Vector3, pivot: Vector3,
		side_axis: Vector3, back: Vector3, forward: Vector3, side: float) -> Vector3:
	var rel := pivot + _frame_offset - safe
	var sideways := _frame_offset.dot(side_axis)
	var widest := sideways + maxf(rel.dot(forward), 0.0) * _screen_slope()
	var narrowed := clampf(side, sideways, maxf(sideways, widest))
	var clearance := _clearance
	var path_free := _sweep_path(space, pivot, side_axis * narrowed, back)
	var candidate := _path_start + back * minf(clearance, path_free)
	if not _is_framed(candidate, pivot, side_axis, forward):
		return safe
	if path_free < clearance:
		_clear_time = 0.0
		_releasing = false
	_clearance = minf(clearance, path_free)
	return candidate


## True when the commander's actual point seen from the camera position is not right of the middle
## of the screen and not left of max_screen_offset of the half width.
func _is_framed(camera_position: Vector3, pivot: Vector3, side_axis: Vector3,
		forward: Vector3) -> bool:
	var rel := pivot + _frame_offset - camera_position
	var depth := rel.dot(forward)
	if depth <= 0.0:
		return false
	var left := -rel.dot(side_axis)
	return left >= -FRAME_SLACK and left <= depth * _screen_slope() + FRAME_SLACK


## Sideways distance per metre of depth at the left limit of the frame.
func _screen_slope() -> float:
	return max_screen_offset * tan(deg_to_rad(camera.fov) * 0.5) * _aspect()


## Sweeps from the pivot out to the shoulder and from there back. Leaves the start of the way back
## in _path_start and returns how much of the way back is free, from 0 to 1.
func _sweep_path(space: PhysicsDirectSpaceState3D, pivot: Vector3, side_vector: Vector3,
		back: Vector3) -> float:
	var shoulder_point := pivot + side_vector
	_path_start = pivot.lerp(shoulder_point, _free_fraction(space, pivot, shoulder_point))
	return _free_fraction(space, _path_start, _path_start + back)


## The shoulder for a camera standing clearance of the way back behind the pivot, so that the
## commander's actual point (the pivot plus _frame_offset) is not right of the screen's middle and
## not further left than max_screen_offset of the half width. The full shoulder where it fits.
func _shoulder_for(clearance: float, side_axis: Vector3, forward: Vector3) -> float:
	var sideways := _frame_offset.dot(side_axis)
	var depth := orbit_distance() * clearance * cos(deg_to_rad(aim_tilt_deg)) \
			+ _frame_offset.dot(forward)
	var half_width := tan(deg_to_rad(camera.fov) * 0.5) * _aspect()
	var widest := sideways + maxf(depth, 0.0) * max_screen_offset * half_width
	return clampf(shoulder, sideways, maxf(sideways, widest))


## Width over height of the screen the camera renders to; 16:9 without a viewport.
func _aspect() -> float:
	var viewport := camera.get_viewport()
	if viewport == null:
		return 16.0 / 9.0
	var screen := viewport.get_visible_rect().size
	return screen.x / screen.y if screen.y > 0.0 else 16.0 / 9.0


func _space() -> PhysicsDirectSpaceState3D:
	if not camera.is_inside_tree():
		return null
	var world := camera.get_world_3d()
	return world.direct_space_state if world != null else null


## How far along from to the sphere can go before touching something, from 0 to 1.
func _free_fraction(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> float:
	if from.is_equal_approx(to):
		return 1.0
	var query := _probe_at(from)
	# A sweep does not report a start that already overlaps something, so that is checked first.
	if not space.intersect_shape(query, 1).is_empty():
		return 0.0
	query.motion = to - from
	var result := space.cast_motion(query)
	if result.size() < 2:
		return 1.0
	return result[0]


## The sphere the camera is checked with, standing at a point.
func _probe_at(point: Vector3) -> PhysicsShapeQueryParameters3D:
	_probe.radius = probe_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _probe
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = collision_mask
	query.exclude = exclude
	return query


## Blocked pulls in at once. A way that is only a little clearer changes nothing. A clearly clearer
## way waits for release_delay, then the camera eases out until it gets there.
func _next_clearance(free: float, real_delta: float) -> float:
	if free <= _clearance or reduced_motion or return_time <= 0.0:
		_clear_time = 0.0
		_releasing = false
		return free
	if not _releasing and free - _clearance <= release_margin:
		_clear_time = 0.0
		return _clearance
	if not _releasing:
		_clear_time += real_delta
		if _clear_time < release_delay:
			return _clearance
		_releasing = true
	return lerpf(_clearance, free, 1.0 - exp(-real_delta / return_time))


## Pushes the camera out to min_distance from the pivot, along the way it sits or, right on the
## pivot, toward the wanted position. A wall wins: the camera stays where the sweep put it unless
## the sphere can move freely out to min_distance.
func _keep_min_distance(space: PhysicsDirectSpaceState3D, pivot: Vector3, position: Vector3,
		wanted: Vector3, side_axis: Vector3, forward: Vector3) -> Vector3:
	var gap := position.distance_to(pivot)
	if gap >= min_distance:
		return position
	var away := position - pivot if gap > 0.0001 else wanted - pivot
	var pushed := pivot + away.normalized() * min_distance
	if _free_fraction(space, position, pushed) < 1.0:
		return position
	# Moving the camera must not take the commander out of the frame it was solved for.
	if not _is_framed(pushed, pivot, side_axis, forward):
		push_rejected_by_frame = true
		return position
	return pushed


func orbit_distance() -> float:
	var value := distance
	if pitch_deg < far_pitch:
		value = lerpf(distance, distance_near, _span_ratio(far_pitch, pitch_min))
	elif pitch_deg > far_pitch:
		value = lerpf(distance, distance_up, _span_ratio(far_pitch, pitch_max))
	value *= zoom
	var drop := sin(deg_to_rad(pitch_deg))
	if drop > 0.0:
		value = minf(value, maxf(pivot_height - min_height, 0.0) / drop)
	return value


func _span_ratio(start: float, end: float) -> float:
	if is_equal_approx(start, end):
		return 0.0
	return clampf(inverse_lerp(start, end, pitch_deg), 0.0, 1.0)
