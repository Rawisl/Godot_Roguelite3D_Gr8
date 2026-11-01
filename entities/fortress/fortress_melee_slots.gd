class_name FortressMeleeSlots
extends MeleeSlotSet

## Distance from the wall face to where units stand.
@export var stand_off: float = 0.8
## Margin at both ends of the wall so units do not stand against the corridor walls.
@export var edge_margin: float = 1.0


func setup(count: int) -> void:
	_reset_owners(count)
	_build_points(count)
	_start_audit()


## Spreads slots evenly on the +X face of the CollisionShape3D (spawn side).
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


func position_for(attacker: Node3D) -> Vector3:
	var i := _owners.find(attacker)
	if i >= 0:
		return _world_point(i)
	return get_parent().to_global(Vector3(_gate_x(), 0.0, 0.0))


func _gate_x() -> float:
	return _local_points[0].x if not _local_points.is_empty() else 0.0
