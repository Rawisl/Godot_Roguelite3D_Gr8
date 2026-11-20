extends Control
## Draw at a fixed design size so the boss and tower panels share the same symbols.
@export var damage_type: Enums.DamageType = Enums.DamageType.PIERCE:
	set(value):
		if damage_type == value:
			return
		damage_type = value
		queue_redraw()
@export var immunity := false

func _draw() -> void:
	var scale_factor := minf(size.x, size.y) / 24.0
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE * scale_factor)
	match damage_type:
		Enums.DamageType.PIERCE:
			draw_line(Vector2(-7, 7), Vector2(6, -6), Color.WHEAT, 2.5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(8,-8), Vector2(6,0), Vector2(0,-6)]), Color.WHEAT)
		Enums.DamageType.MAGIC:
			draw_colored_polygon(PackedVector2Array([Vector2(-9,8), Vector2(2,-6), Vector2(7,-1)]), Color.SKY_BLUE)
			draw_colored_polygon(PackedVector2Array([Vector2(4,-10),Vector2(6,-6),Vector2(10,-5),Vector2(6,-3),Vector2(4,1),Vector2(2,-3),Vector2(-2,-5),Vector2(2,-6)]), Color.LIGHT_CYAN)
		Enums.DamageType.BLAST:
			var burst := PackedVector2Array()
			for i in 16:
				burst.append(Vector2.UP.rotated(i * TAU / 16) * (9 if i % 2 == 0 else 4))
			draw_colored_polygon(burst, Color.ORANGE)
	if immunity:
		var rim := Color.LIGHT_CORAL
		draw_arc(Vector2.ZERO, 10.5, 0, TAU, 40, rim, 1.6, true)
		draw_line(Vector2(-7.4,-7.4), Vector2(7.4,7.4), rim, 2.0, true)
