class_name SyncGlyph
extends Control
## Sync state icon, drawn so it needs no texture. Each state has its own shape, not only its own
## colour: GUEST a person, SYNCED a tick, SYNCING a turning arc, OFFLINE a slashed circle,
## ERROR a triangle with "!".

@export var guest_color := Color(0.6627, 0.6549, 0.6235)
@export var synced_color := Color(0.6118, 1.0, 0.4157)
@export var syncing_color := Color(0.949, 0.9373, 0.902)
@export var offline_color := Color(0.6627, 0.6549, 0.6235)
@export var error_color := Color(1.0, 0.6039, 0.1804)
@export var line_width := 3.0
## Turns per second of the SYNCING arc, in real time.
@export var spin_speed := 1.0

var state: StringName = &"GUEST":
	set(value):
		state = value
		set_process(value == &"SYNCING")
		queue_redraw()

var _angle := 0.0

func _ready() -> void:
	set_process(state == &"SYNCING")

func _process(delta: float) -> void:
	_angle = fmod(_angle + TAU * spin_speed * delta, TAU)
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - line_width
	if r <= 0.0:
		return
	match state:
		&"SYNCED":
			draw_arc(c, r, 0.0, TAU, 32, synced_color, line_width, true)
			draw_polyline(PackedVector2Array([c + Vector2(-0.45, 0.0) * r, c + Vector2(-0.1, 0.35) * r,
				c + Vector2(0.5, -0.35) * r]), synced_color, line_width, true)
		&"SYNCING":
			draw_arc(c, r, _angle, _angle + TAU * 0.75, 32, syncing_color, line_width, true)
			var tip := c + Vector2.from_angle(_angle + TAU * 0.75) * r
			draw_circle(tip, line_width * 1.2, syncing_color, true, -1.0, true)
		&"OFFLINE":
			draw_arc(c, r, 0.0, TAU, 32, offline_color, line_width, true)
			draw_line(c + Vector2(-0.7, -0.7) * r, c + Vector2(0.7, 0.7) * r, offline_color, line_width, true)
		&"ERROR":
			var top := c + Vector2(0.0, -r)
			var left := c + Vector2(-r, r * 0.8)
			var right := c + Vector2(r, r * 0.8)
			draw_polyline(PackedVector2Array([top, right, left, top]), error_color, line_width, true)
			draw_line(c + Vector2(0.0, -0.35) * r, c + Vector2(0.0, 0.25) * r, error_color, line_width, true)
			draw_circle(c + Vector2(0.0, 0.52) * r, line_width * 0.7, error_color, true, -1.0, true)
		_:
			draw_circle(c + Vector2(0.0, -0.35) * r, r * 0.32, guest_color, true, -1.0, true)
			draw_arc(c + Vector2(0.0, r * 0.75), r * 0.65, PI, TAU, 24, guest_color, line_width, true)
