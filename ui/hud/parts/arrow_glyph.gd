class_name ArrowGlyph
extends Control
## A chevron pointing down or up, centred in the box. Drawn, so it needs no texture or font glyph.

@export var color := Color(0.949, 0.9373, 0.902)
@export var line_width := 3.0
## Chevron size as a share of the box side.
@export var scale_share := 0.5
@export var pointing_up := false:
	set(value):
		pointing_up = value
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var side := minf(size.x, size.y) * scale_share
	if side <= 0.0:
		return
	var center := size * 0.5
	var half_w := side * 0.5
	var half_h := side * 0.25
	var tip_y := -half_h if pointing_up else half_h
	var wing_y := half_h if pointing_up else -half_h
	draw_polyline(PackedVector2Array([
		center + Vector2(-half_w, wing_y),
		center + Vector2(0.0, tip_y),
		center + Vector2(half_w, wing_y)]), color, line_width, true)
