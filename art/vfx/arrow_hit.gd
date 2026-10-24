class_name ArrowHit
extends Node3D
## Arrow impact. A thin ring widens and fades on the side the arrow came from, while a few
## small sparks spray back toward the shooter. Tweens and particles are
## bound to this node, so they follow time_scale and pause.

@export_group("Ring")
@export var ring_color := Color("#FFFFFF")
## Ring alpha when it appears; it fades to 0 by the end.
@export_range(0.0, 1.0) var ring_alpha := 0.8
## Ring diameter in metres at the start and at the end.
@export var ring_size_start := 0.15
@export var ring_size_end := 0.7
@export var ring_time := 0.25
## How far in front of the hit point the ring sits, toward the archer.
@export var ring_offset := 0.05

@export_group("Sparks")
@export_range(0, 32) var spark_count := 6
@export var spark_color_start := Color("#FFFFFF")
@export var spark_color_end := Color("#FFFFFF")
## Spark size multiplier at the start and at the end of its life.
@export var spark_size_start := 1.0
@export var spark_size_end := 0.2
@export var spark_time := 0.3
## How wide the sparks fan out, in degrees.
@export_range(0.0, 180.0) var spark_spread := 35.0
## Launch speed in m/s; sets how far the sparks fly.
@export var spark_speed := 4.0

@onready var ring: MeshInstance3D = $Ring
@onready var sparks: CPUParticles3D = $Sparks

var _ring_mat: StandardMaterial3D
var _tween: Tween


func _ready() -> void:
	_ring_mat = (ring.material_override as StandardMaterial3D).duplicate()
	ring.material_override = _ring_mat
	visible = false


func is_playing() -> bool:
	return _tween != null and _tween.is_running()


## Plays the hit at point. dir is the arrow's flight direction.
func play(point: Vector3, dir: Vector3) -> void:
	if _tween:
		_tween.kill()
	var fwd := dir.normalized() if dir.length_squared() > 0.0001 else Vector3.RIGHT
	var up := Vector3.UP if absf(fwd.y) < 0.99 else Vector3.FORWARD
	global_position = point
	visible = true

	# Ring faces the archer, so its plane is across the flight line.
	ring.global_basis = Basis.looking_at(fwd, up) * Basis(Vector3.RIGHT, PI * 0.5)
	ring.global_position = point - fwd * ring_offset
	ring.scale = Vector3.ONE * ring_size_start * 0.5
	_ring_mat.albedo_color = Color(ring_color, ring_alpha)

	# Sparks spray back toward the shooter.
	sparks.global_basis = Basis.looking_at(-fwd, up)
	sparks.amount = maxi(spark_count, 1)
	sparks.lifetime = spark_time
	sparks.spread = spark_spread
	sparks.initial_velocity_min = spark_speed * 0.6
	sparks.initial_velocity_max = spark_speed
	sparks.color_ramp = _gradient(spark_color_start, Color(spark_color_end, 0.0))
	sparks.scale_amount_curve = _curve(spark_size_start, spark_size_end)
	if spark_count > 0:
		sparks.restart()

	_tween = create_tween().set_parallel()
	_tween.tween_property(ring, "scale", Vector3.ONE * ring_size_end * 0.5, ring_time) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_ring_mat, "albedo_color", Color(ring_color, 0.0), ring_time).set_ease(Tween.EASE_IN)
	_tween.chain().tween_interval(maxf(0.0, spark_time - ring_time))
	_tween.chain().tween_callback(func() -> void: visible = false)


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
