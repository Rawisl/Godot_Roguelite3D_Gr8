class_name PoisonPool
extends Node3D

## Poison left on the floor by the centipede's spit: a flat disc that spreads out, hurts the commander
## and structures standing in it every tick, and fades away. It lives in the world, not under the
## boss, so it stays when the boss dies; it then fades at once and stops hurting.
## The disc's radius is in metres and does not follow the boss's model scale; the node stays at
## scale 1, so the mesh and the hit test are one shape.

const GROUPS: Array[StringName] = [&"commander", &"tower", &"barricade", &"fortress"]

var _data: CentipedeBossData
var _source: Node3D
var _tick_damage: int = 0
var _age: float = 0.0
var _life_left: float = 0.0
var _tick_clock: float = 0.0
var _dying: bool = false

@onready var _mesh: PoisonPoolMesh = $Mesh


## Call before the pool is added to the tree.
func setup(source: Node3D, tick_damage: int, data: CentipedeBossData) -> void:
	_source = source
	_tick_damage = tick_damage
	_data = data
	_life_left = data.pool_lifetime


func _ready() -> void:
	if _data == null:
		return
	_mesh.disc = true
	_mesh.length = _data.pool_radius
	_update_look()


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	_age += delta
	_life_left -= delta
	if not _dying and not _source_alive():
		_dying = true
		_life_left = minf(_life_left, _data.pool_fade_time)
	if _life_left <= 0.0:
		queue_free()
		return
	_update_look()
	if _dying:
		return
	_tick_clock += delta
	while _tick_clock >= _data.pool_tick_interval:
		_tick_clock -= _data.pool_tick_interval
		_hurt_targets()


## True when a body of radius pad centred at world_pos touches the disc.
func contains_point(world_pos: Vector3, pad: float = 0.0) -> bool:
	if _data == null:
		return false
	var local := to_local(world_pos)
	return Vector2(local.x, local.z).length() <= _data.pool_radius + pad


func _source_alive() -> bool:
	if not is_instance_valid(_source):
		return false
	return _source.get(&"is_dead") != true


func _update_look() -> void:
	var spread := 1.0
	if _data.pool_spread_time > 0.0:
		spread = ease(clampf(_age / _data.pool_spread_time, 0.0, 1.0), -2.0)
	var opacity := 1.0
	if _data.pool_fade_time > 0.0:
		opacity = clampf(_life_left / _data.pool_fade_time, 0.0, 1.0)
	_mesh.set_instance_shader_parameter(&"spread", spread)
	_mesh.set_instance_shader_parameter(&"opacity", opacity)


func _hurt_targets() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var hit: Array[Node3D] = []
	for group in GROUPS:
		for node in tree.get_nodes_in_group(group):
			var target := node as Node3D
			if target == null or hit.has(target) or not target.has_method(&"take_damage"):
				continue
			if target.is_in_group(&"tower_wall") or not _can_hurt(target):
				continue
			if contains_point(target.global_position, _body_pad(target)):
				hit.append(target)
	for target in hit:
		_damage(target)


func _can_hurt(target: Node3D) -> bool:
	if not target.is_in_group(&"commander"):
		return true
	return target.get(&"is_dodging") != true and target.get(&"is_dead") != true


func _damage(target: Node3D) -> void:
	var from: Node = _source if is_instance_valid(_source) else null
	var away := target.global_position - global_position
	away.y = 0.0
	var info := DamageInfo.outgoing(float(_tick_damage), 1.0, Enums.DamageType.MAGIC, from, 0.0, away.normalized(), true)
	target.take_damage(info)


## Radius to add to a target's position so a body standing at the edge still counts.
func _body_pad(target: Node3D) -> float:
	var shape := target.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape == null or shape.shape == null:
		return 0.0
	if shape.shape is CapsuleShape3D:
		return (shape.shape as CapsuleShape3D).radius
	if shape.shape is BoxShape3D:
		var size := (shape.shape as BoxShape3D).size
		return maxf(size.x, size.z) * 0.5
	return 0.0
