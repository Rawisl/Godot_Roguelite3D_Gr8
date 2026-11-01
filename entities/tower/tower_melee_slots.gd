class_name TowerMeleeSlots
extends MeleeSlotSet
## Melee attack positions around a tower, one Marker3D child per position.
## A tower on a GROUND cell has max_attackers_per_tower (3, the Heal Station included);
## the Barricade overrides the count.

## A marker farther than this from the navmesh counts as off it (next to a corridor wall).
@export var nav_snap_distance: float = 0.3
## A unit closer than this to its position has arrived and is no longer swapped.
@export var settled_distance: float = 0.8
## A holder farther round the tower than this from its position walks round outside the others.
@export_range(0.0, 90.0) var approach_angle_deg: float = 30.0
## How far outside the positions that walk round goes (other attackers stand on the positions).
@export var approach_distance: float = 1.2

var _built := false


func _ready() -> void:
	var count := _markers().size()
	if count != _expected_count():
		push_warning("%s: %d markers, GameConfig expects %d"
				% [get_script().get_global_name(), count, _expected_count()])
	_reset_owners(count)
	_start_audit()


## Number of markers the scene should have; only checked, the markers decide.
func _expected_count() -> int:
	return GameConfig.max_attackers_per_tower


func _markers() -> Array[Marker3D]:
	var out: Array[Marker3D] = []
	for c in get_children():
		if c is Marker3D:
			out.append(c)
	return out


## Points are read on first use: by then the Slot has placed the tower and the navigation
## map has synced.
func rebuild() -> void:
	_built = true
	_local_points.clear()
	var body := get_parent() as Node3D
	var markers := _markers()
	if markers.is_empty():
		return
	var mid := body.to_local(markers[_mid_index(markers.size())].global_position)
	for m in markers:
		var p := body.to_local(m.global_position)
		var t := 0.0
		while t < 1.0 and not _on_nav(p.lerp(mid, t)):
			t += 0.1
		_local_points.append(p.lerp(mid, minf(t, 1.0)))


## True when a local point is on the navmesh, or when there is no navmesh to check against.
func _on_nav(local_p: Vector3) -> bool:
	var body := get_parent() as Node3D
	var map := body.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0 or NavigationServer3D.map_get_regions(map).is_empty():
		return true
	var world := body.to_global(local_p)
	var d := NavigationServer3D.map_get_closest_point(map, world) - world
	d.y = 0.0
	return d.length() <= nav_snap_distance


func _ensure_points() -> void:
	if not _built:
		rebuild()


## The held attack position, or the middle marker for a unit still on its way.
func position_for(attacker: Node3D) -> Vector3:
	if not _built:
		rebuild()
	if _local_points.is_empty():
		return get_parent().global_position
	var i := _owners.find(attacker)
	if i >= 0:
		i = _improve(i)
		return _route_point(attacker, i)
	return _world_point(_mid_index(_local_points.size()))


## Towers do not cut the navmesh, so a unit that waited on one side and was given a freed
## position on the other side walks straight at the body and the attackers in between, and
## avoidance boxes it in there. Send it round instead: on a circle approach_distance outside the
## positions, at most 45 degrees at a time, then straight in once it is in front of its position.
func _route_point(attacker: Node3D, i: int) -> Vector3:
	var p := _world_point(i)
	if _flat_dist(attacker.global_position, p) <= approach_distance:
		return p
	var centre := (get_parent() as Node3D).global_position
	var to_p := Vector2(p.x - centre.x, p.z - centre.z)
	var to_a := Vector2(attacker.global_position.x - centre.x, attacker.global_position.z - centre.z)
	if to_p.length_squared() < 0.0001 or to_a.length_squared() < 0.0001:
		return p
	var diff := to_a.angle_to(to_p)
	if absf(diff) <= deg_to_rad(approach_angle_deg):
		return p
	var w := to_a.normalized().rotated(signf(diff) * minf(absf(diff), PI / 4.0)) * (to_p.length() + approach_distance)
	return Vector3(centre.x + w.x, p.y, centre.z + w.y)


## Units claim from up to crowd_claim_distance away, in whatever order they arrive, so two of
## them can end up walking to each other's side and cross in front of the tower. While neither has
## arrived, swap their positions (or move to a nearer free one) when that shortens both walks.
## Returns the attacker's slot index after the change.
func _improve(i: int) -> int:
	var a: Node3D = _owners[i]
	var pa := _world_point(i)
	var da := _flat_dist(a.global_position, pa)
	if da < settled_distance:
		return i
	for j in _owners.size():
		if j == i:
			continue
		var pb := _world_point(j)
		var b = _owners[j]
		if b == null:
			if _flat_dist(a.global_position, pb) + 0.3 < da:
				_owners[j] = a
				_owners[i] = null
				return j
			continue
		if not is_instance_valid(b):
			continue
		var db := _flat_dist((b as Node3D).global_position, pb)
		if db < settled_distance:
			continue
		if _flat_dist(a.global_position, pb) + _flat_dist((b as Node3D).global_position, pa) + 0.3 < da + db:
			_owners[i] = b
			_owners[j] = a
			return j
	return i


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func get_world_points() -> Array[Vector3]:
	if not _built:
		rebuild()
	var out: Array[Vector3] = []
	for i in _local_points.size():
		out.append(_world_point(i))
	return out


## Index of the middle position (P1 of P0..P2, P2 of P0..P4).
func _mid_index(count: int) -> int:
	return floori(count / 2.0)
