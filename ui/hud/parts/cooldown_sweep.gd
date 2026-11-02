class_name CooldownSweep
extends Control
## A ring that empties clockwise from the top as a cooldown runs out. Drawn, so it needs
## no texture.

@export var ring_color := Color(0.9098, 0.7608, 0.3529)
@export var track_color := Color(0.1647, 0.1843, 0.2275)
@export var ring_width := 4.0
@export var point_count := 48

## Share of the cooldown still left, 0..1.
var ratio := 0.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if is_equal_approx(value, ratio):
			return
		ratio = value
		queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - ring_width * 0.5
	draw_arc(center, radius, 0.0, TAU, point_count, track_color, ring_width, true)
	if ratio > 0.0:
		var start := -PI * 0.5
		draw_arc(center, radius, start, start + TAU * ratio, point_count, ring_color, ring_width, true)
