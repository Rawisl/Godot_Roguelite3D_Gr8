class_name ChaseCameraOrbit
extends RefCounted
## Reusable third-person orbit. CameraRig owns context, cursor and frame signals; this class
## owns the perspective camera's pose and zoom, independent of any particular level.

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


func follow(current: Vector3, target: Vector3, real_delta: float) -> Vector3:
	var weight := 1.0 - exp(-real_delta / maxf(follow_smoothing, 0.001))
	return current.lerp(target, weight)


func advance(real_delta: float, focus: Vector3) -> void:
	var weight := 1.0 - exp(-real_delta / maxf(zoom_smoothing, 0.001))
	zoom = lerpf(zoom, zoom_target, weight)
	place(focus)


func turn(screen_motion: Vector2, sensitivity: float, focus: Vector3) -> void:
	yaw = wrapf(yaw - deg_to_rad(screen_motion.x * sensitivity), -PI, PI)
	pitch_deg = clampf(pitch_deg - screen_motion.y * sensitivity, pitch_min, pitch_max)
	place(focus)


func change_zoom(notches: float, reduced_motion: bool, focus: Vector3) -> void:
	zoom_target = clampf(zoom_target + notches * zoom_step, zoom_min, 1.0)
	if reduced_motion:
		zoom = zoom_target
		place(focus)


func place(focus: Vector3) -> void:
	if camera == null:
		return
	var pivot := focus + Vector3.UP * pivot_height
	var orbit := Basis.from_euler(Vector3(deg_to_rad(pitch_deg), yaw, 0.0))
	var view := Basis.from_euler(Vector3(deg_to_rad(pitch_deg + aim_tilt_deg), yaw, 0.0))
	camera.global_transform = Transform3D(view,
			pivot + orbit.z * orbit_distance() + orbit.x * shoulder)


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
