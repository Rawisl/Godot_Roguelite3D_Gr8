class_name SkillGeometry
extends RefCounted
## Shape helpers shared by the active skills.


## First box shape among the children of an area, whatever the node is called. Null when there is none.
static func find_box_shape(area: Area3D) -> CollisionShape3D:
	if area == null:
		return null
	for child in area.get_children():
		var shape_node := child as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			return shape_node
	return null
