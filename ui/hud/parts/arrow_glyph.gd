class_name ArrowGlyph
extends Control
## A chevron pointing down or up (or, with sideways, right or left), centred in the box. Drawn, so
## it needs no texture or font glyph.

@export var color := Color(0.949, 0.9373, 0.902)
@export var line_width := 3.0
## Chevron size as a share of the box side.
@export var scale_share := 0.5
@export var pointing_up := false:
	set(value):
		pointing_up = value
		queue_redraw()
## Draws > or < instead of a down or up chevron.
@export var sideways := false:
	set(value):
		sideways = value
		queue_redraw()
## With sideways: < when true, > when false.
@export var pointing_left := false:
	set(value):
		pointing_left = value
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
	if sideways:
		# Same chevron turned a quarter: the tip points left or right.
		var tip_x := -half_h if pointing_left else half_h
		var wing_x := half_h if pointing_left else -half_h
		draw_polyline(PackedVector2Array([
			center + Vector2(wing_x, -half_w),
			center + Vector2(tip_x, 0.0),
			center + Vector2(wing_x, half_w)]), color, line_width, true)
		return
	var tip_y := -half_h if pointing_up else half_h
	var wing_y := half_h if pointing_up else -half_h
	draw_polyline(PackedVector2Array([
		center + Vector2(-half_w, wing_y),
		center + Vector2(0.0, tip_y),
		center + Vector2(half_w, wing_y)]), color, line_width, true)
