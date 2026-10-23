class_name SwordHit
extends Node3D
## Melee hit: a straight white slash line draws diagonally across the hit point as seen by
## the camera, then thins out; sparks fly out the far side, and optionally a ring widens and
## dust kicks up at the feet. Everything comes from a SwordHitStyle. Tweens and particles are bound to
## this node, so they follow time_scale and pause.

const SEGMENTS := 24

@export var style: SwordHitStyle

@onready var arc: MeshInstance3D = $Arc
@onready var ring: MeshInstance3D = $Ring
@onready var sparks: CPUParticles3D = $Sparks
@onready var dust: CPUParticles3D = $Dust

var _mesh := ImmediateMesh.new()
var _ring_mat: StandardMaterial3D
var _tween: Tween
var _play_style: SwordHitStyle
var _along := Vector3.RIGHT
var _across := Vector3.UP
## How much of the line is drawn, 0..1, then how thick it still is, 1..0.
var _drawn := 0.0:
	set(v):
		_drawn = v
		_build_slash()
var _thick := 1.0:
	set(v):
		_thick = v
		_build_slash()


func _ready() -> void:
	arc.mesh = _mesh
	_ring_mat = (ring.material_override as StandardMaterial3D).duplicate()
	ring.material_override = _ring_mat
	visible = false


func is_playing() -> bool:
	return _tween != null and _tween.is_running()


## Plays the hit at point. dir points from the attacker to the target. ground_y is the floor
## height for the dust. Uses the given style, or the exported one.
func play(point: Vector3, dir: Vector3, hit_style: SwordHitStyle = null, ground_y := 0.0) -> void:
	_play_style = hit_style if hit_style != null else style
	if _play_style == null:
		return
	var st := _play_style
	if _tween:
		_tween.kill()
	var fwd := dir.normalized() if dir.length_squared() > 0.0001 else Vector3.RIGHT
	var up := Vector3.UP if absf(fwd.y) < 0.99 else Vector3.FORWARD
	global_position = point
	global_basis = Basis.IDENTITY
	visible = true

	var face := Basis.looking_at(fwd, up)
	# The line lies on the screen plane, so it reads the same from any side.
	var cam := get_viewport().get_camera_3d()
	var screen := cam.global_basis if cam != null else Basis.IDENTITY
	var ang := deg_to_rad(st.slash_angle_deg)
	_along = screen.x * cos(ang) + screen.y * sin(ang)
	_across = screen.x * -sin(ang) + screen.y * cos(ang)
	_thick = 1.0
	_drawn = 0.0

	sparks.global_basis = face
	sparks.amount = maxi(st.spark_count, 1)
	sparks.lifetime = st.spark_time
	sparks.spread = st.spark_spread
	sparks.initial_velocity_min = st.spark_speed * 0.6
	sparks.initial_velocity_max = st.spark_speed
	sparks.color_ramp = _gradient(st.spark_color_start, Color(st.spark_color_end, 0.0))
	sparks.scale_amount_curve = _curve(st.spark_size_start, st.spark_size_end)
	if st.spark_count > 0:
		sparks.restart()

	ring.visible = st.ring_enabled
	if st.ring_enabled:
		ring.global_basis = face * Basis(Vector3.RIGHT, PI * 0.5)
		ring.scale = Vector3.ONE * st.ring_size_start * 0.5
		_ring_mat.albedo_color = Color(st.ring_color, st.ring_alpha)

	if st.dust_enabled and st.dust_count > 0:
		var flat := Vector3(fwd.x, 0.0, fwd.z)
		var dust_dir := flat.normalized() if flat.length_squared() > 0.0001 else Vector3.RIGHT
		dust.global_position = Vector3(point.x, ground_y + 0.05, point.z)
		dust.global_basis = Basis.looking_at(dust_dir, Vector3.UP)
		dust.amount = st.dust_count
		dust.lifetime = st.dust_time
		dust.initial_velocity_min = st.dust_speed * 0.5
		dust.initial_velocity_max = st.dust_speed
		dust.color_ramp = _gradient(st.dust_color, Color(st.dust_color, 0.0))
		dust.restart()

	var total := st.sweep_time + st.fade_time
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "_drawn", 1.0, st.sweep_time).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_property(self, "_thick", 0.0, st.fade_time).set_ease(Tween.EASE_IN)
	_tween.chain()
	if st.ring_enabled:
		var ring_tw := create_tween().set_parallel()
		ring_tw.tween_property(ring, "scale", Vector3.ONE * st.ring_size_end * 0.5, st.ring_time) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		ring_tw.tween_property(_ring_mat, "albedo_color", Color(st.ring_color, 0.0), st.ring_time).set_ease(Tween.EASE_IN)
	var longest := maxf(total, maxf(st.spark_time, st.ring_time if st.ring_enabled else 0.0))
	if st.dust_enabled:
		longest = maxf(longest, st.dust_time)
	_tween.tween_interval(maxf(0.0, longest - total))
	_tween.chain().tween_callback(func() -> void: visible = false)


## Draws the line from its start up to how far it has been drawn, tapered at both ends.
func _build_slash() -> void:
	_mesh.clear_surfaces()
	var st := _play_style
	if st == null or _drawn <= 0.001 or _thick <= 0.001:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in SEGMENTS + 1:
		var t := _drawn * float(i) / SEGMENTS
		var center := _along * (t - 0.5) * st.slash_length
		var half := st.slash_width * 0.5 * sin(PI * t) * _thick
		_mesh.surface_set_color(st.slash_color)
		_mesh.surface_add_vertex(center + _across * half)
		_mesh.surface_set_color(st.slash_color)
		_mesh.surface_add_vertex(center - _across * half)
	_mesh.surface_end()


func _gradient(from: Color, to: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, from)
	g.set_color(1, to)
	return g


func _curve(from: float, to: float) -> Curve:
	var c := Curve.new()
	c.max_value = maxf(maxf(from, to), 1.0)
	c.add_point(Vector2(0.0, from))
	c.add_point(Vector2(1.0, to))
	return c
