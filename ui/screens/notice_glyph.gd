@tool
class_name NoticeGlyph
extends Control
## The mark next to a notice title: a circle with "i" for information, a triangle with "!" for a
## warning or a danger. Shape and colour both change, so the tone never relies on colour alone.

@export var warning := false:
	set(value):
		warning = value
		queue_redraw()
@export var color := Color(0.9098039, 0.7607843, 0.3529412, 1):
	set(value):
		color = value
		queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.45
	if warning:
		var top := c + Vector2(0, -r)
		var left := c + Vector2(-r * 1.05, r * 0.8)
		var right := c + Vector2(r * 1.05, r * 0.8)
		draw_polyline(PackedVector2Array([top, right, left, top]), color, 3.0, true)
		draw_line(c + Vector2(0, -r * 0.4), c + Vector2(0, r * 0.25), color, 3.0, true)
		draw_circle(c + Vector2(0, r * 0.52), 2.0, color)
	else:
		draw_arc(c, r, 0.0, TAU, 32, color, 3.0, true)
		draw_circle(c + Vector2(0, -r * 0.45), 2.0, color)
		draw_line(c + Vector2(0, -r * 0.15), c + Vector2(0, r * 0.5), color, 3.0, true)
