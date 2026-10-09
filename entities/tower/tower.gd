class_name Tower
extends StaticBody3D

signal destroyed(tower: Tower)
signal shot_started(target: Node3D)

@export var data: TowerData
var level: int = 1
var priority: Enums.TargetPriority = Enums.TargetPriority.FIRST
var scan_phase: float = 0.0
var target: Enemy = null

var _lv: TowerLevelData
var _scan_t: float = 0.0
var _cooldown: float = 0.0
## time left before shot leave; negative when no shot pending.
var _release_t: float = -1.0
var _shot_target: Enemy = null
var _priority_t: float = -1.0
var _pending_priority: Enums.TargetPriority = Enums.TargetPriority.FIRST
var _pool: ProjectilePool = null
var _aim_node: Node3D = null
var _muzzle_node: Node3D = null

@onready var health: HealthComponent = %Health
@onready var range_area: Area3D = %RangeArea
@onready var range_shape: CollisionShape3D = %RangeArea.get_node("CollisionShape3D")
@onready var muzzle: Marker3D = %Muzzle

func _ready() -> void:
	add_to_group(&"tower")
	if data == null:
		push_warning("Tower is missing TowerData")
		set_physics_process(false)
		return
	priority = data.default_priority
	apply_level(level)
	health.died.connect(func(): destroyed.emit(self))
	_scan_t = scan_phase * GameConfig.scan_interval

func apply_level(new_level: int) -> void:
	level = new_level
	_lv = data.levels[level - 1]
	health.max_hp = _lv.max_hp
	health.hp = _lv.max_hp
	(range_shape.shape as CylinderShape3D).radius = _lv.attack_range

func set_visuals(aim: Node3D, muzzle_node: Node3D) -> void:
	_aim_node = aim
	_muzzle_node = muzzle_node

## TGT-03, CMD-01: a new priority applies after retarget_delay.
func set_priority(new_priority: Enums.TargetPriority) -> void:
	_pending_priority = new_priority
	_priority_t = GameConfig.retarget_delay

func can_attack() -> bool:
	return data != null and data.projectile_scene != null and _lv != null and _lv.fire_rate > 0.0

func _physics_process(delta: float) -> void:
	if not can_attack():
		return
	_update_priority(delta)
	_update_aim()

	# TWR-15: scan every scan_interval of game time
	_scan_t += delta
	if _scan_t >= GameConfig.scan_interval:
		_scan_t = fmod(_scan_t, GameConfig.scan_interval)
		_scan()

	if _cooldown > 0.0:
		_cooldown -= delta

	if _release_t >= 0.0:
		_release_t -= delta
		if _release_t <= 0.0:
			_release_shot()
		return

	if _cooldown <= 0.0 and _is_valid_target(target):
		_start_shot()

func _update_priority(delta: float) -> void:
	if _priority_t < 0.0:
		return
	_priority_t -= delta
	if _priority_t <= 0.0:
		_priority_t = -1.0
		priority = _pending_priority
		target = _pick_target()

func _scan() -> void:
	#keep the target until it dies or leaves range
	if _is_valid_target(target):
		return
	target = _pick_target()

func _pick_target() -> Enemy:
	var best: Enemy = null
	for body in range_area.get_overlapping_bodies():
		var e := body as Enemy
		if not _is_valid_target(e):
			continue
		if best == null or _is_better(e, best):
			best = e
	return best  # TGT-02: null means idle

## Valid target (3.6.5): alive, in range, a kind this tower can hit.
func _is_valid_target(obj) -> bool:
	if ( obj == null 
		or not is_instance_valid(obj) 
		or not obj is Enemy):
			return false
	var e := obj as Enemy
	if e.is_dead:
		return false
	# EN-04: TV2 can add is_targetable for spawn_grace; until then every enemy counts.
	if "is_targetable" in e and not e.get(&"is_targetable"):
		return false
	var flying := e.data != null and e.data.is_flying
	if flying and not data.targets_air:
		return false
	if not flying and not data.targets_ground:
		return false
	var d2 := _flat_distance_sq(e)
	if d2 > _lv.attack_range * _lv.attack_range:
		return false
	# TGT-05
	return d2 >= data.min_range * data.min_range

## TGT-01: higher score wins, then closer to the tower, then smaller entity id.
func _is_better(a: Enemy, b: Enemy) -> bool:
	var sa := _score(a)
	var sb := _score(b)
	if not is_equal_approx(sa, sb):
		return sa > sb
	var da := _flat_distance_sq(a)
	var db := _flat_distance_sq(b)
	if not is_equal_approx(da, db):
		return da < db
	return a.get_instance_id() < b.get_instance_id()

func _score(e: Enemy) -> float:
	match priority:
		Enums.TargetPriority.FIRST:
			return _progress_of(e)
		Enums.TargetPriority.NEAREST:
			return -_flat_distance_sq(e)
		Enums.TargetPriority.HIGHEST_HP:
			return float(e.health.hp)
		Enums.TargetPriority.LOWEST_HP:
			return -float(e.health.hp)
	return 0.0

## Distance along the lane toward the Fortress; larger is closer to the gate.
## TWR-15 fallback: projection on x (the Fortress is on the -x side).
## TODO: read e.nav_progress once Enemy implements TWR-16 (it holds the remaining nav distance now).
func _progress_of(e: Enemy) -> float:
	return -e.global_position.x

func _flat_distance_sq(e: Node3D) -> float:
	var d := e.global_position - global_position
	d.y = 0.0
	return d.length_squared()

func _get_pool() -> ProjectilePool:
	if _pool == null or not is_instance_valid(_pool):
		_pool = get_tree().get_first_node_in_group(&"projectile_pool") as ProjectilePool
	return _pool

func _start_shot() -> void:
	var pool := _get_pool()
	if pool == null:
		push_warning("Tower: no ProjectilePool in the scene")
		_cooldown = 1.0 / _lv.fire_rate
		return
	# PRJ-04: pool full, wait for the next frame without losing the shot
	if not pool.can_acquire():
		return
	_cooldown = 1.0 / _lv.fire_rate
	_shot_target = target
	_release_t = minf(data.release_delay, _cooldown)
	shot_started.emit(target)

## The projectile leaves the muzzle. A shot still waiting here is dropped if the tower
## is destroyed first, because this node is freed with it (TWR-02).
func _release_shot() -> void:
	if not _is_valid_target(_shot_target):
		_shot_target = _pick_target()
		if _shot_target == null:
			_release_t = -1.0
			_cooldown = 0.0  # nothing left to hit; the shot is not spent
			return
	var pool := _get_pool()
	var p: Projectile = pool.acquire(data.projectile_scene) if pool != null else null
	if p == null:
		_release_t = 0.0  # PRJ-04: retry next frame
		return
	_release_t = -1.0
	var from := (_muzzle_node if _muzzle_node != null else muzzle).global_position
	p.launch(from, _shot_target, _lv.damage, data.damage_type, data.projectile_speed)
	_shot_target = null

func _update_aim() -> void:
	if (_aim_node == null 
		or not is_instance_valid(_aim_node) 
		or not _is_valid_target(target)):
		return
	# Measured in the aim node's parent frame so model or slot rotations do not offset it.
	var parent := _aim_node.get_parent() as Node3D
	var local := parent.to_local(target.global_position) - _aim_node.position
	# The aim node's local -Z points at the target; its rest yaw is only the idle pose.
	_aim_node.rotation.y = atan2(-local.x, -local.z)
