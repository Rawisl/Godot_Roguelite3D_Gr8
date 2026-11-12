class_name SwordGlyph
extends Control
## Placeholder sword drawn until a weapon has its own icon: pommel and grip in the lower left
## corner, the blade rising to its tip in the upper right. Drawn, so it needs no texture.

## Opaque, so the parts that overlap (guard over grip) do not draw darker.
@export var color := Color(0.6627, 0.6549, 0.6235)
## Gap to the box edge, as a share of the box side.
@export var margin := 0.1
## Blade width at the guard, as a share of the sword length.
@export var blade_width := 0.13
## Crossguard length, as a share of the sword length.
@export var guard_length := 0.42
## Where the guard sits along the sword, 0 = pommel, 1 = tip.
@export var guard_at := 0.26

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 0.0:
		return
	var offset := (size - Vector2(side, side)) * 0.5
	var base := offset + Vector2(margin, 1.0 - margin) * side
	var tip := offset + Vector2(1.0 - margin, margin) * side
	var axis := tip - base
	var length := axis.length()
	var dir := axis / length
	var normal := Vector2(-dir.y, dir.x)

	# Blade: full width from the guard, narrowing to the tip.
	var guard := base + dir * length * guard_at
	var half := blade_width * length * 0.5
	var shoulder := base + dir * length * 0.86
	draw_colored_polygon(PackedVector2Array([
		guard + normal * half, shoulder + normal * half, tip,
		shoulder - normal * half, guard - normal * half]), color)

	# Crossguard across the sword, grip and pommel below it.
	var guard_half := normal * guard_length * length * 0.5
	draw_line(guard - guard_half, guard + guard_half, color, maxf(2.0, length * 0.07), true)
	var pommel := base + dir * length * 0.04
	draw_line(pommel, guard, color, maxf(2.0, length * 0.075), true)
	draw_circle(pommel, maxf(2.0, length * 0.055), color, true, -1.0, true)
