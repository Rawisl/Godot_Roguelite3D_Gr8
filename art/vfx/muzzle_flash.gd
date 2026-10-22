class_name MuzzleFlash
extends Node3D
## Tower firing: a flash swells and fades at the muzzle while puffs blow out along the shot.
## Everything comes from a MuzzleStyle. Tweens and particles are bound to this node, so they
## follow time_scale and pause.

@export var style: MuzzleStyle

@onready var flash: MeshInstance3D = $Flash
@onready var puffs: CPUParticles3D = $Puffs

var _flash_mat: StandardMaterial3D
var _tween: Tween


func _ready() -> void:
	_flash_mat = (flash.material_override as StandardMaterial3D).duplicate()
	flash.material_override = _flash_mat
	visible = false


func is_playing() -> bool:
	return _tween != null and _tween.is_running()


## Plays at the muzzle. dir is the shot direction.
func play(point: Vector3, dir: Vector3, muzzle_style: MuzzleStyle = null) -> void:
	var st := muzzle_style if muzzle_style != null else style
	if st == null:
		return
	if _tween:
		_tween.kill()
	var fwd := dir.normalized() if dir.length_squared() > 0.0001 else Vector3.RIGHT
	var up := Vector3.UP if absf(fwd.y) < 0.99 else Vector3.FORWARD
	global_position = point
	visible = true

	flash.scale = Vector3.ONE * st.flash_size_start
	_flash_mat.albedo_color = st.flash_color

	if st.puff_count > 0:
		puffs.global_basis = Basis.looking_at(fwd, up)
		puffs.amount = st.puff_count
		puffs.lifetime = st.puff_time
		puffs.spread = st.puff_spread
		puffs.initial_velocity_min = st.puff_speed * 0.6
		puffs.initial_velocity_max = st.puff_speed
		var g := Gradient.new()
		g.set_color(0, st.puff_color)
		g.set_color(1, Color(st.puff_color, 0.0))
		puffs.color_ramp = g
		var c := Curve.new()
		c.max_value = maxf(maxf(st.puff_size_start, st.puff_size_end), 1.0)
		c.add_point(Vector2(0.0, st.puff_size_start))
		c.add_point(Vector2(1.0, st.puff_size_end))
		puffs.scale_amount_curve = c
		puffs.restart()

	_tween = create_tween().set_parallel()
	_tween.tween_property(flash, "scale", Vector3.ONE * st.flash_size_end, st.flash_time).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_flash_mat, "albedo_color", Color(st.flash_color, 0.0), st.flash_time).set_ease(Tween.EASE_IN)
	_tween.chain().tween_interval(maxf(0.0, (st.puff_time if st.puff_count > 0 else 0.0) - st.flash_time))
	_tween.chain().tween_callback(func() -> void: visible = false)
