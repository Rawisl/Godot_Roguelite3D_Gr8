class_name FortressMeleeSlots
extends Node3D

## Distance from the wall face to where units stand.
@export var stand_off: float = 0.8
## Margin at both ends of the wall so units do not stand against the corridor walls.
@export var edge_margin: float = 1.0

## slot index -> unit holding it (null when free).
var _owners: Array = []
## Slot positions in the Fortress's local coordinates.
var _local_points: Array[Vector3] = []
var _audit_timer: Timer
## Units already connected to tree_exiting, so re-claiming does not connect twice.
var _watched: Dictionary = {}


func setup(count: int) -> void:
	_owners.resize(maxi(0, count))
	_owners.fill(null)
	_build_points(count)
	if _audit_timer == null:
		_audit_timer = Timer.new()
		_audit_timer.wait_time = GameConfig.crowd_slot_audit_interval
		_audit_timer.timeout.connect(_audit)
		add_child(_audit_timer)
		_audit_timer.start()


## Spreads slots evenly on the +X face of the CollisionShape3D (spawn side; section 2.1: the Fortress is at the far left).
func _build_points(count: int) -> void:
	_local_points.clear()
	var half := Vector3(2.0, 1.5, 3.0)
	var center := Vector3.ZERO
	var col := get_parent().get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if col != null and col.shape is BoxShape3D:
		half = (col.shape as BoxShape3D).size * 0.5
		center = col.position
	var x := center.x + half.x + stand_off
	var y := center.y - half.y
	var span := maxf(0.0, half.z - edge_margin)
	for i in count:
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		_local_points.append(Vector3(x, y, center.z + lerpf(-span, span, t)))


func claim(attacker: Node3D) -> bool:
	if attacker == null:
		return false
	if has(attacker):
		return true
	var best := -1
	var best_dist := INF
	for i in _owners.size():
		if _owners[i] != null:
			continue
		var d := attacker.global_position.distance_squared_to(_world_point(i))
		if d < best_dist:
			best_dist = d
			best = i
	if best < 0:
		return false
	_owners[best] = attacker
	var id := attacker.get_instance_id()
	if not _watched.has(id):
		_watched[id] = true
		attacker.tree_exiting.connect(_on_attacker_exiting.bind(attacker, id), CONNECT_ONE_SHOT)
	return true


func _on_attacker_exiting(attacker: Node3D, id: int) -> void:
	_watched.erase(id)
	release(attacker)


func release(attacker: Node3D) -> void:
	var i := _owners.find(attacker)
	if i >= 0:
		_owners[i] = null


func release_all() -> void:
	for a in _owners.duplicate():
		if a != null:
			release(a)


func has(attacker: Node3D) -> bool:
	return attacker != null and _owners.has(attacker)


func free_count() -> int:
	return _owners.count(null)


func position_for(attacker: Node3D) -> Vector3:
	var i := _owners.find(attacker)
	if i >= 0:
		return _world_point(i)
	return get_parent().to_global(Vector3(_gate_x(), 0.0, 0.0))


func _world_point(i: int) -> Vector3:
	return get_parent().to_global(_local_points[i])


func _gate_x() -> float:
	return _local_points[0].x if not _local_points.is_empty() else 0.0


## CRD-04: free slots whose owner was freed from memory or is dead.
func _audit() -> void:
	for i in _owners.size():
		var a = _owners[i]
		if a == null:
			continue
		if not is_instance_valid(a) or not a.is_inside_tree() or ("is_dead" in a and a.is_dead):
			_owners[i] = null
