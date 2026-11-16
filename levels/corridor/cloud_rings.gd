class_name CloudRings
extends Node3D
## Faint cloud rings turning clockwise around the Hazard Trial island (seen from above, -Z at the
## top of the screen), far slower than the floating rocks. Every child Node3D is one ring, centred
## on this node; each next ring turns a little slower than the one inside it.
## Decoration only: it follows the game clock (stops on pause, faster at x2 and x3).

## Degrees per second for the innermost ring.
@export var turn_speed_deg := 0.8
## Each ring further out turns this much slower than the one before (0.3 = 30%).
@export_range(0.0, 0.9) var slow_down_outward := 0.3


func _process(delta: float) -> void:
	var speed := deg_to_rad(turn_speed_deg) * delta
	for child in get_children():
		var ring := child as Node3D
		if ring == null:
			continue
		# A negative turn about +Y takes +X towards +Z: clockwise from above.
		ring.rotate_y(-speed)
		speed *= 1.0 - slow_down_outward
