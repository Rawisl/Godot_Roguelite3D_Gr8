@tool
class_name TraitGlyph
extends Control
## The icon of one enemy trait, drawn in color and fitted in the control (26 px in the HUD).
## Each icon has its own shape, so the traits read apart even in black and white; the badge
## always shows the name next to it.

const ICONS := {
	EnemyTraits.STEALTH: preload("res://art/icons/traits/trait_stealth.png"),
	EnemyTraits.EXPLODE: preload("res://art/icons/traits/trait_explode.png"),
	EnemyTraits.UNDYING: preload("res://art/icons/traits/trait_undying.png"),
	EnemyTraits.REVIVE: preload("res://art/icons/traits/trait_revive.png"),
	EnemyTraits.CHARGE: preload("res://art/icons/traits/trait_charge.png"),
}

@export var trait_id: StringName = EnemyTraits.STEALTH:
	set(value):
		trait_id = value
		queue_redraw()
## Tint over the light icon; white keeps it as drawn.
@export var color := Color(1, 1, 1, 1)

func _draw() -> void:
	var icon: Texture2D = ICONS.get(trait_id)
	if icon == null:
		return
	var side := minf(size.x, size.y)
	draw_texture_rect(icon, Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side)), false, color)
