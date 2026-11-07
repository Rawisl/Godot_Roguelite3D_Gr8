@tool
class_name CameraBounds
extends Node3D
## Hand-placed rectangle on the ground plane that limits the camera focus point, plus the
## camera sizes tuned for this map. Centred on this node; size.x runs along the corridor (X), size.y across (Z).
## Frontline uses the same length but frontline_depth across, so the closer camera can follow the
## commander to the walls while the overview stays centred enough to keep the full width in frame.

@export var size: Vector2 = Vector2(32, 4):
	set(v):
		size = v
		update_gizmos()
## Width of the focus rectangle across the corridor (Z) in Frontline.
@export var frontline_depth: float = 4.0:
	set(v):
		frontline_depth = v
		update_gizmos()
## Orthographic size in Frontline: about 12-14 m visible each side of the commander along the corridor.
@export var camera_size_frontline: float = 14.0
## Orthographic size in Commander and PREP: the full corridor width stays in frame.
@export var camera_size_overview: float = 18.0
## Camera position relative to its focus point on the ground (pitch -45, yaw 20).
@export var camera_offset: Vector3 = Vector3(7.255, 21.213, 19.934)


func get_rect(frontline := false) -> Rect2:
	var c := global_position
	var s := Vector2(size.x, frontline_depth) if frontline else size
	return Rect2(Vector2(c.x, c.z) - s * 0.5, s)


func clamp_focus(p: Vector3, frontline := false) -> Vector3:
	var r := get_rect(frontline)
	return Vector3(clampf(p.x, r.position.x, r.end.x), p.y, clampf(p.z, r.position.y, r.end.y))


## Camera position that looks at the given focus point after clamping.
func camera_position_for(focus: Vector3, frontline := false) -> Vector3:
	var f := clamp_focus(focus, frontline)
	return Vector3(f.x, 0.0, f.z) + camera_offset
