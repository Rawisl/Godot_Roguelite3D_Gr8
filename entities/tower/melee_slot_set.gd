class_name MeleeSlotSet
extends Node3D
## Melee attack positions around a structure: one unit per position, freed when the unit leaves the tree or dies.
## Shared by TowerMeleeSlots (towers, barricades) and FortressMeleeSlots in entities/fortress/.

## slot index -> unit holding it (null when free).
var _owners: Array = []
## Slot positions in the parent's local coordinates.
var _local_points: Array[Vector3] = []
var _audit_timer: Timer
## Units already connected to tree_exiting, so re-claiming does not connect twice.
var _watched: Dictionary = {}


func _reset_owners(count: int) -> void:
	_owners.resize(maxi(0, count))
	_owners.fill(null)


func _start_audit() -> void:
	if _audit_timer == null:
		_audit_timer = Timer.new()
		_audit_timer.wait_time = GameConfig.crowd_slot_audit_interval
		_audit_timer.timeout.connect(_audit)
		add_child(_audit_timer)
		_audit_timer.start()


## Called before a claim; subclasses build their points lazily here.
func _ensure_points() -> void:
	pass


func claim(attacker: Node3D) -> bool:
	if attacker == null:
		return false
	if has(attacker):
		return true
	_ensure_points()
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


## The structure is destroyed, every attacker loses its slot.
func release_all() -> void:
	_owners.fill(null)


func has(attacker: Node3D) -> bool:
	return attacker != null and _owners.has(attacker)


func free_count() -> int:
	return _owners.count(null)


func _world_point(i: int) -> Vector3:
	return get_parent().to_global(_local_points[i])


## Free slots whose owner was freed from memory or is dead.
func _audit() -> void:
	for i in _owners.size():
		var a = _owners[i]
		if a == null:
			continue
		if not is_instance_valid(a) or not a.is_inside_tree() or ("is_dead" in a and a.is_dead):
			_owners[i] = null
