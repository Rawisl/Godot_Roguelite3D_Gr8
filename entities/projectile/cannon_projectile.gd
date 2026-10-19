class_name CannonProjectile
extends Projectile


signal exploded(center: Vector3, radius: float, hits: int)

@export var max_flight_time: float = 5.0


var _from: Vector3 = Vector3.ZERO
var _dest: Vector3 = Vector3.ZERO
var _flight_time: float = 0.0
var _t: float = 0.0
var _radius: float = 0.0
var _edge_mult: float = 1.0


func _ready() -> void:
	# No contact damage on the way (TGT-07): the base class hit handlers stay disconnected.
	pass


func fire(from: Vector3, to: Node3D, dmg: int, dmg_type: Enums.DamageType, spd: float, src: Node = null) -> void:
	super.fire(from, to, dmg, dmg_type, spd, src)
	_radius = 0.0
	_edge_mult = 1.0
	var tower := src as Tower
	if tower != null and tower.data != null:
		var lv: TowerLevelData = tower.data.levels[tower.level - 1]
		_radius = lv.splash_radius
		_edge_mult = tower.data.splash_falloff_edge
	launch_at(from, predict_landing(from, to, spd))


func launch_at(from: Vector3, dest: Vector3) -> void:
	_from = from
	_dest = dest
	_t = 0.0
	var flat := Vector2(dest.x - from.x, dest.z - from.z).length()
	_flight_time = maxf(0.1, flat / maxf(1.0, speed))
	global_position = from


## PRJ-02: lead the target by its current velocity over the flight time.
static func predict_landing(from: Vector3, to: Node3D, spd: float) -> Vector3:
	if to == null or not is_instance_valid(to):
		return from
	var pos := to.global_position
	var vel := Vector3.ZERO
	if to is CharacterBody3D:
		vel = (to as CharacterBody3D).velocity
		vel.y = 0.0
	var dest := pos
	for i in 2:
		var flat := Vector2(dest.x - from.x, dest.z - from.z).length()
		dest = pos + vel * (flat / maxf(1.0, spd))
	return dest


func _physics_process(delta: float) -> void:
	if not in_use:
		return
	_t += delta
	if _t >= _flight_time or _t >= max_flight_time:
		global_position = _dest
		explode(_dest)
		release()
		return
	var k := _t / _flight_time
	var pos := _from.lerp(_dest, k)
	pos.y += 4.0 * arc_height * k * (1.0 - k)
	var dir := pos - global_position
	global_position = pos
	if dir.length_squared() > 0.0001:
		var up := Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.FORWARD
		look_at(pos + dir, up)


## Applies blast damage around center.
func explode(center: Vector3) -> int:
	if _radius <= 0.0 or damage <= 0:
		return 0
	var valid_src: Node = source if is_instance_valid(source) else null
	var hits := 0
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var e := node as Enemy
		if e == null or not is_instance_valid(e) or e.is_dead:
			continue
		var d := e.global_position.distance_to(center)
		if d > _radius:
			continue
		var amount := blast_damage(damage, d, _radius, _edge_mult)
		if amount <= 0:
			continue
		var dir := e.global_position - center
		dir.y = 0.0
		var info := DamageInfo.new(amount, damage_type, valid_src, 0.0, dir.normalized())
		e.take_damage(info)
		EventBus.projectile_hit.emit(e, amount,
				StringName(Enums.DamageType.keys()[damage_type]), 1.0)
		hits += 1
	exploded.emit(center, _radius, hits)
	return hits


## PRJ-02: 100% at the centre, edge_mult at the radius, linear in between.
static func blast_damage(base: int, dist: float, radius: float, edge_mult: float) -> int:
	if radius <= 0.0 or dist > radius:
		return 0
	return roundi(base * lerpf(1.0, edge_mult, dist / radius))


## Test hook: set the blast numbers without a Tower.
func setup_blast(dmg: int, radius: float, edge_mult: float, src: Node = null) -> void:
	damage = dmg
	damage_type = Enums.DamageType.BLAST
	_radius = radius
	_edge_mult = edge_mult
	source = src
