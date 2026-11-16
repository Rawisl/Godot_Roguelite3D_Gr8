class_name HazardPortal
extends Node3D
## Hazard Trial tower next to the Fortress: the player clicks it (ClickArea on layer 7,
## group hazard_portal) or presses E to enter the room. The ring on top turns slowly round the
## energy orb, and the rune shards drift around it (FloatingRocks). Decoration only: it follows the
## game clock, so it stops on pause and speeds up at x2 and x3.
## The meshes come from contents/assets/towers/hazard_portal.glb (each part saved to its own .res
## on import), with the game's toon materials mapped in the import settings.

## Degrees per second the ring turns about the vertical axis.
@export var ring_speed_deg := 40.0

@onready var _ring: Node3D = %Ring


func _process(delta: float) -> void:
	_ring.rotate_y(deg_to_rad(ring_speed_deg) * delta)
