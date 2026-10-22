class_name Tower
extends StaticBody3D

signal destroyed(tower: Tower)
signal shot_started(target: Node3D)

## Melee attackers walk this close to their attack position before swinging (read by Enemy),
## so a unit does not stop short and block the way to the positions next to it.
const MELEE_ARRIVE_DISTANCE := 0.6

@export var data: TowerData
var level: int = 1
var priority: Enums.TargetPriority = Enums.TargetPriority.FIRST
var scan_phase: float = 0.0
## Set by the Slot that holds this tower; used for slot-keyed EventBus signals.
var slot_id: StringName = &""
var target: Enemy = null
## True while the tower idles because every target in range is immune.
var is_immune_blocked: bool = false

var _lv: TowerLevelData
var _scan_t: float = 0.0
var _cooldown: float = 0.0
## time left before shot leave; negative when no shot pending.
var _release_t: float = -1.0
var _shot_target: Enemy = null
## TimeManager.real_time when the pending priority applies; negative when none is pending.
var _priority_due: float = -1.0
var _pending_priority: Enums.TargetPriority = Enums.TargetPriority.FIRST
var _pool: ProjectilePool = null
var _aim_node: Node3D = null
var _muzzle_node: Node3D = null

## _target_distance_sq result for an enemy that is valid except for immunity.
const IMMUNE := -2.0

@onready var health: HealthComponent = %Health
@onready var range_area: Area3D = %RangeArea
@onready var range_shape: CollisionShape3D = %RangeArea.get_node("CollisionShape3D")
@onready var muzzle: Marker3D = %Muzzle
## Melee attack positions (3 markers here, 5 on the Barricade).
@onready var melee_slots: TowerMeleeSlots = %MeleeSlots

func _ready() -> void:
	add_to_group(&"tower")
	if data == null:
		push_warning("Tower is missing TowerData")
		set_physics_process(false)
		return
	if data.id == &"barricade":
		add_to_group(&"barricade")
	priority = data.default_priority
	apply_level(level)
	# A destroyed tower frees every attacker's slot before the Slot turns RUINED.
	health.died.connect(melee_slots.release_all)
	health.died.connect(func(): destroyed.emit(self))
	_scan_t = scan_phase * GameConfig.scan_interval

func _exit_tree() -> void:
	_set_immune_blocked(false)

func apply_level(new_level: int) -> void:
	level = new_level
	_lv = data.levels[level - 1]
	health.max_hp = _lv.max_hp
	health.hp = _lv.max_hp
	(range_shape.shape as CylinderShape3D).radius = _lv.attack_range

## TWR-02: enemy melee and projectiles call take_damage on the body they hit.
## HP = 0 emits destroyed, and the Slot turns RUINED (SLOT-02).
func take_damage(damage_input: Variant, p_damage_type: Enums.DamageType = Enums.DamageType.SLASH) -> int:
	return health.take_damage(damage_input, p_damage_type)

func set_visuals(aim: Node3D, muzzle_node: Node3D) -> void:
	_aim_node = aim
	_muzzle_node = muzzle_node

#region Melee slots (same API as Fortress)
## Melee units cannot reach a tower on a WALL slot (Slot adds the tower_wall group).
func accepts_melee() -> bool:
	return health.hp > 0 and not is_in_group(&"tower_wall")

## False when full, destroyed or on a WALL slot: the unit must WAIT or choose another target.
func claim_melee_slot(attacker: Node3D) -> bool:
	if not accepts_melee():
		return false
	return melee_slots.claim(attacker)

func release_melee_slot(attacker: Node3D) -> void:
	melee_slots.release(attacker)

func has_melee_slot(attacker: Node3D) -> bool:
	return melee_slots.has(attacker)

## The claimed attack position, or the middle one for a unit still on its way.
func get_melee_slot_position(attacker: Node3D) -> Vector3:
	return melee_slots.position_for(attacker)

func get_free_melee_slots() -> int:
	return melee_slots.free_count()

func get_melee_arrive_distance() -> float:
	return MELEE_ARRIVE_DISTANCE
#endregion

## TGT-03, CMD-01: a new priority applies after retarget_delay, counted in real time
## (TIME-10), so it is 0.3 s at x1, x2 and x3.
func set_priority(new_priority: Enums.TargetPriority) -> void:
	_pending_priority = new_priority
	_priority_due = TimeManager.real_time + GameConfig.retarget_delay

func can_attack() -> bool:
	return data != null and data.projectile_scene != null and _lv != null and _lv.fire_rate > 0.0

func _physics_process(delta: float) -> void:
	if not can_attack():
		return
	_update_priority()
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

func _update_priority() -> void:
	if _priority_due < 0.0 or TimeManager.real_time < _priority_due:
		return
	_priority_due = -1.0
	priority = _pending_priority
	target = _pick_target()

## TWR-15: pick again on every scan by the current priority, so a unit that overtakes becomes
## the First target within one scan_interval (test 7.1 item 6). A shot already started keeps its _shot_target.
func _scan() -> void:
	target = _pick_target()

## One pass over the area query: each candidate is checked and scored once (TWR-15).
func _pick_target() -> Enemy:
	var best: Enemy = null
	var best_score := 0.0
	var best_d2 := 0.0
	var saw_immune := false
	for body in range_area.get_overlapping_bodies():
		var e := body as Enemy
		var d2 := _target_distance_sq(e)
		if d2 == IMMUNE:
			saw_immune = true
		if d2 < 0.0:
			continue
		var s := _score(e, d2)
		if best == null or _is_better(s, d2, e, best_score, best_d2, best):
			best = e
			best_score = s
			best_d2 = d2
	# Idle with only immune enemies in range shows the immune icon.
	_set_immune_blocked(best == null and saw_immune)
	return best  # TGT-02: null means idle

## Emits EventBus.tower_immunity_changed only when the state changes.
func _set_immune_blocked(value: bool) -> void:
	if value == is_immune_blocked:
		return
	is_immune_blocked = value
	if slot_id != &"":
		EventBus.tower_immunity_changed.emit(slot_id, value)

## Valid target (3.6.5): alive and targetable, in range, a kind this tower can hit.
func _is_valid_target(obj) -> bool:
	return _target_distance_sq(obj) >= 0.0

## Flat distance squared to obj when it is a valid target, IMMUNE when only its
## resistance rules it out, -1 when it is not valid for any other reason.
func _target_distance_sq(obj) -> float:
	if ( obj == null 
		or not is_instance_valid(obj) 
		or not obj is Enemy):
			return -1.0
	var e := obj as Enemy
	# EN-04: dead, in spawn_grace or still inside the spawn zone.
	if not e.can_be_targeted():
		return -1.0
	var flying := e.data != null and e.data.is_flying
	if flying and not data.targets_air:
		return -1.0
	if not flying and not data.targets_ground:
		return -1.0
	var d2 := _flat_distance_sq(e)
	if d2 > _lv.attack_range * _lv.attack_range:
		return -1.0
	# TGT-05
	if d2 < data.min_range * data.min_range:
		return -1.0
	# TODO: the immune icon itself; UI listens to EventBus.tower_immunity_changed.
	if e.has_method(&"get_resist") and e.get_resist(data.damage_type) <= 0.0:
		return IMMUNE
	return d2

## TGT-01: higher score wins, then closer to the tower, then smaller entity id.
func _is_better(sa: float, da: float, a: Enemy, sb: float, db: float, b: Enemy) -> bool:
	if not is_equal_approx(sa, sb):
		return sa > sb
	if not is_equal_approx(da, db):
		return da < db
	return a.get_instance_id() < b.get_instance_id()

func _score(e: Enemy, d2: float) -> float:
	match priority:
		Enums.TargetPriority.FIRST:
			# TWR-16: metres along lane_curve toward the Fortress, kept up to date by the enemy.
			return e.nav_progress
		Enums.TargetPriority.NEAREST:
			return -d2
		Enums.TargetPriority.HIGHEST_HP:
			return float(e.health.hp)
		Enums.TargetPriority.LOWEST_HP:
			return -float(e.health.hp)
	return 0.0

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
	p.fire(from, _shot_target, _lv.damage, data.damage_type, data.projectile_speed, self)
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
