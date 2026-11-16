@tool
class_name TraitGlyph
extends Control
## A drawn icon for one enemy trait until trait icons exist. Each shape differs, so the traits
## read apart even in black and white; the badge always shows the name next to it.
# TODO(kimvux): swap these drawn shapes for trait icons when they are made (same 26 px slot).

@export var trait_id: StringName = EnemyTraits.STEALTH:
	set(value):
		trait_id = value
		queue_redraw()
@export var color := Color(0.9490196, 0.9372549, 0.9019608, 1)

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42
	match trait_id:
		EnemyTraits.STEALTH:
			# A dashed ring: there, but hard to see.
			for i in 8:
				var a := TAU * i / 8.0
				draw_arc(c, r, a, a + TAU / 16.0, 4, color, 2.0, true)
		EnemyTraits.EXPLODE:
			# A burst of spikes.
			for i in 8:
				var a := TAU * i / 8.0
				var dir := Vector2.from_angle(a)
				draw_line(c + dir * r * 0.35, c + dir * (r if i % 2 == 0 else r * 0.7), color, 2.0, true)
		EnemyTraits.UNDYING:
			# A shield.
			var points := PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.8), c + Vector2(r * 0.8, -r * 0.8),
				c + Vector2(r * 0.8, 0.0), c + Vector2(0.0, r), c + Vector2(-r * 0.8, 0.0), c + Vector2(-r * 0.8, -r * 0.8)])
			draw_polyline(points, color, 2.0, true)
		EnemyTraits.REVIVE:
			# A circular arrow.
			draw_arc(c, r * 0.8, -PI * 0.2, PI * 1.5, 16, color, 2.0, true)
			var tip := c + Vector2.from_angle(-PI * 0.2) * r * 0.8
			draw_line(tip, tip + Vector2(-r * 0.5, -r * 0.1), color, 2.0, true)
			draw_line(tip, tip + Vector2(r * 0.05, -r * 0.5), color, 2.0, true)
		EnemyTraits.CHARGE:
			# Two chevrons pointing ahead.
			for dx in [-r * 0.45, r * 0.25]:
				draw_polyline(PackedVector2Array([c + Vector2(dx - r * 0.3, -r * 0.7), c + Vector2(dx + r * 0.3, 0.0),
					c + Vector2(dx - r * 0.3, r * 0.7)]), color, 2.0, true)
