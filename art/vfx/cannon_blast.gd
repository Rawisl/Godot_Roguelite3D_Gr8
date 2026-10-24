class_name CannonBlast
extends Node3D
## Cannon shell impact. A white core swells and turns orange, then gray puffs spread and fade
## on the side the shell came from, while a pale gray ring widens and drifts out the far side
## before shrinking away. Tweens are bound to this node, so they follow time_scale and pause.

## Blast radius the effect was tuned for; play() scales everything by radius / this.
const BASE_RADIUS := 2.0

@export var core_color_hot := Color("#FFFFFF")
@export var core_color_fire := Color("#FF9A2E")
@export var core_color_smoke := Color("#8A8A8A")
@export var ring_color := Color("#D6D6D6")
## Overall size of the core and puffs.
@export var blast_size := 0.75
## The pale ring that drifts out the back; off by default.
@export var ring_enabled := false
## Widest size of the ring and how opaque it gets.
@export var ring_size := 0.7
@export var ring_alpha := 0.4
## How wide the smoke fans out from the impact side, in degrees (0 = a straight jet, 180 = all round).
@export_range(0.0, 180.0) var smoke_spread := 60.0
## How far the smoke travels: multiplies the puffs' launch speed.
@export_range(0.0, 3.0) var smoke_distance := 1.0
@export var flash_time := 0.08
@export var fire_time := 0.14
@export var cool_time := 0.18
@export var ring_grow_time := 0.35
@export var ring_shrink_time := 0.2
## How far the ring travels out the back, as a share of the blast radius.
@export var ring_travel := 0.6

@onready var core: MeshInstance3D = $Core
@onready var ring: MeshInstance3D = $Ring
@onready var puffs: CPUParticles3D = $Puffs

var _core_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _tween: Tween
var _puff_speed_min := 0.0
var _puff_speed_max := 0.0
var _ring_tween: Tween


func _ready() -> void:
	_core_mat = (core.material_override as StandardMaterial3D).duplicate()
	core.material_override = _core_mat
	_ring_mat = (ring.material_override as StandardMaterial3D).duplicate()
	ring.material_override = _ring_mat
	_puff_speed_min = puffs.initial_velocity_min
	_puff_speed_max = puffs.initial_velocity_max
	visible = false


func is_playing() -> bool:
	return _tween != null and _tween.is_running()


## Plays the blast at center. dir is the shell's travel direction at impact.
func play(center: Vector3, dir: Vector3, radius: float) -> void:
	if _tween:
		_tween.kill()
	var s := maxf(radius, 0.1) / BASE_RADIUS
	var back := dir.normalized() if dir.length_squared() > 0.0001 else Vector3.DOWN
	# The ring travels level with the ground, along the shell's heading.
	var flat := Vector3(dir.x, 0.0, dir.z)
	var ring_dir := flat.normalized() if flat.length_squared() > 0.0001 else Vector3.RIGHT
	global_position = center
	visible = true

	# Ring faces along the travel direction and sits just behind the impact point.
	var up := Vector3.UP if absf(back.y) < 0.99 else Vector3.FORWARD
	ring.global_basis = Basis.looking_at(ring_dir, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	ring.global_position = center
	ring.scale = Vector3.ONE * 0.3 * ring_size * s
	_ring_mat.albedo_color = Color(ring_color, 0.0)

	# Puffs leave from the impact side, back toward where the shell came from.
	puffs.global_basis = Basis.looking_at(-back, up)
	puffs.scale = Vector3.ONE * blast_size * s
	puffs.spread = smoke_spread
	puffs.initial_velocity_min = _puff_speed_min * smoke_distance
	puffs.initial_velocity_max = _puff_speed_max * smoke_distance

	core.scale = Vector3.ONE * 0.8 * blast_size * s
	_core_mat.albedo_color = core_color_hot

	_tween = create_tween().set_parallel()
	# Core: white flash that swells, turns orange, then gray and fades.
	_tween.tween_property(core, "scale", Vector3.ONE * 1.6 * blast_size * s, flash_time).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_property(core, "scale", Vector3.ONE * 2.0 * blast_size * s, fire_time)
	_tween.tween_property(_core_mat, "albedo_color", core_color_fire, fire_time)
	# Gray puffs start as the core cools.
	_tween.chain().tween_callback(puffs.restart)
	_tween.tween_property(_core_mat, "albedo_color", Color(core_color_smoke, 0.0), cool_time)
	_tween.tween_property(core, "scale", Vector3.ONE * 1.4 * blast_size * s, cool_time)

	# Ring: widens and drifts out the back, then shrinks away while still drifting.
	if _ring_tween:
		_ring_tween.kill()
	ring.visible = ring_enabled
	if not ring_enabled:
		_tween.chain().tween_interval(maxf(0.0, puffs.lifetime - cool_time))
		_tween.chain().tween_callback(func() -> void: visible = false)
		return
	var mid := center + ring_dir * ring_travel * radius * 0.7
	_ring_tween = create_tween()
	_ring_tween.tween_property(_ring_mat, "albedo_color", Color(ring_color, ring_alpha), ring_grow_time * 0.3)
	_ring_tween.parallel().tween_property(ring, "scale", Vector3.ONE * ring_size * s, ring_grow_time) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_ring_tween.parallel().tween_property(ring, "global_position", mid, ring_grow_time).set_ease(Tween.EASE_OUT)
	_ring_tween.tween_property(ring, "scale", Vector3.ONE * 0.05 * ring_size * s, ring_shrink_time).set_ease(Tween.EASE_IN)
	_ring_tween.parallel().tween_property(_ring_mat, "albedo_color", Color(ring_color, 0.0), ring_shrink_time)
	_ring_tween.parallel().tween_property(ring, "global_position", center + ring_dir * ring_travel * radius, ring_shrink_time)

	_tween.chain().tween_interval(maxf(0.0, puffs.lifetime - cool_time))
	_tween.chain().tween_callback(func() -> void: visible = false)
