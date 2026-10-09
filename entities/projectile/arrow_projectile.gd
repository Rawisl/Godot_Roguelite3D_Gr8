class_name ArrowProjectile
extends Projectile

@export var aim_height: float = 0.9
@export var max_flight_time: float = 5.0

var _homing: bool = false
var _dest: Vector3 = Vector3.ZERO
var _life: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func launch(from: Vector3, to: Node3D, dmg: int, dmg_type: Enums.DamageType, spd: float) -> void:
	super.launch(from, to, dmg, dmg_type, spd)
	_homing = true
	_life = 0.0
	_dest = _aim_point(to)
	_face(_dest - from)

func _physics_process(delta: float) -> void:
	if not in_use:
		return
	_life += delta
	if _life > max_flight_time:
		release()
		return

	if _homing:
		if _is_alive(target):
			_dest = _aim_point(target)
		else:
			_lose_target()
			if not in_use:
				return

	var to_dest := _dest - global_position
	var step := speed * delta
	if to_dest.length() <= step:
		global_position = _dest
		if _homing:
			_hit(target as Enemy)
		else:
			release()
		return
	var dir := to_dest.normalized()
	global_position += dir * step
	_face(dir)

## PRJ-01: target died in flight, keep flying to its last position.
func _lose_target() -> void:
	_homing = false
	target = null
	for body in get_overlapping_bodies():
		if _is_alive(body):
			_hit(body as Enemy)
			return

func _on_body_entered(body: Node3D) -> void:
	if not in_use or _homing:
		return
	if _is_alive(body):
		_hit(body as Enemy)

func _hit(e: Enemy) -> void:
	if _is_alive(e):
		# TODO: switch to the shared damage API.
		e.take_damage(damage, damage_type)
		EventBus.projectile_hit.emit(e, damage,
				StringName(Enums.DamageType.keys()[damage_type]), 1.0)
	release()

func _aim_point(n: Node3D) -> Vector3:
	return n.global_position + Vector3.UP * aim_height

func _is_alive(obj) -> bool:
	return (obj != null 
		and is_instance_valid(obj) 
		and obj is Enemy 
		and not obj.is_dead)

## rotation direction of arrow tracking to the dest obj
func _face(dir: Vector3) -> void:
	if dir.length_squared() < 0.0001:
		return
	var up := Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.FORWARD
	look_at(global_position + dir, up)
