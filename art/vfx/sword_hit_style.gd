class_name SwordHitStyle
extends Resource
## One look for SwordHit: a straight diagonal slash with sparks, and optionally a ring and dust.

@export_group("Slash")
## Length and widest thickness of the slash line, in metres. It tapers to a point at both ends.
@export var slash_length := 1.4
@export var slash_width := 0.12
## Angle of the line on screen, in degrees (0 = level, 90 = upright). Negative leans the other way.
@export var slash_angle_deg := -35.0
@export var slash_color := Color("#FFFFFF")
## Seconds for the line to draw across.
@export var sweep_time := 0.06
## Seconds for it to thin out and vanish after that.
@export var fade_time := 0.12

@export_group("Sparks")
@export_range(0, 32) var spark_count := 4
@export var spark_color_start := Color("#FFFFFF")
@export var spark_color_end := Color("#FFFFFF")
@export var spark_size_start := 1.0
@export var spark_size_end := 0.2
@export var spark_time := 0.25
@export_range(0.0, 180.0) var spark_spread := 50.0
@export var spark_speed := 3.5

@export_group("Ring")
@export var ring_enabled := false
@export var ring_color := Color("#FFFFFF")
@export_range(0.0, 1.0) var ring_alpha := 0.6
@export var ring_size_start := 0.2
@export var ring_size_end := 1.0
@export var ring_time := 0.25

@export_group("Dust")
## Dust kicked up at the feet, along the hit direction.
@export var dust_enabled := false
@export_range(0, 32) var dust_count := 8
@export var dust_color := Color("#FFFFFF")
@export var dust_time := 0.45
@export var dust_speed := 2.5
