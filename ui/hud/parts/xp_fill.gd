class_name XpFill
extends Control
## Fill of the XP bar: commander XP solid from the left, tower XP striped right after it, so the
## two parts differ by pattern as well as colour. Drawn, so it needs no texture.

@export var track_color := Color(0.1647, 0.1843, 0.2275)
@export var commander_color := Color(0.9098, 0.7608, 0.3529)
@export var tower_color := Color(0.2471, 0.498, 0.8157)
@export var stripe_color := Color(0.1098, 0.1216, 0.149, 0.55)
@export var stripe_gap := 9.0
@export var stripe_width := 3.0

## Shares of the bar, 0..1. The tower part never runs past the end of the bar.
var commander_ratio := 0.0
var tower_ratio := 0.0

func set_parts(commander: float, tower: float) -> void:
	commander_ratio = clampf(commander, 0.0, 1.0)
	tower_ratio = clampf(tower, 0.0, 1.0 - commander_ratio)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), track_color)
	var commander_w := size.x * commander_ratio
	if commander_w > 0.0:
		draw_rect(Rect2(0.0, 0.0, commander_w, size.y), commander_color)
	var tower_w := size.x * tower_ratio
	if tower_w <= 0.0:
		return
	var left := commander_w
	var right := commander_w + tower_w
	draw_rect(Rect2(left, 0.0, tower_w, size.y), tower_color)
	_draw_stripes(left, right)

## Diagonal lines from bottom left to top right, cut to the tower part.
func _draw_stripes(left: float, right: float) -> void:
	var h := size.y
	if h <= 0.0:
		return
	var x := left - h
	while x < right:
		var t0 := clampf((left - x) / h, 0.0, 1.0)
		var t1 := clampf((right - x) / h, 0.0, 1.0)
		if t1 > t0:
			var a := Vector2(x + h * t0, h * (1.0 - t0))
			var b := Vector2(x + h * t1, h * (1.0 - t1))
			draw_line(a, b, stripe_color, stripe_width, true)
		x += stripe_gap
