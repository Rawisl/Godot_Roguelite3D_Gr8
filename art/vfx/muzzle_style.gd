class_name MuzzleStyle
extends Resource
## One look for MuzzleFlash: a quick flash at the muzzle plus puffs blown forward.
## Arrow and Cannon each have a .tres of this.

@export_group("Flash")
@export var flash_color := Color("#FFF2C4")
## Flash diameter in metres at the start and at the end.
@export var flash_size_start := 0.15
@export var flash_size_end := 0.4
@export var flash_time := 0.08

@export_group("Puffs")
@export_range(0, 32) var puff_count := 0
@export var puff_color := Color("#9E9E9E")
@export var puff_size_start := 0.6
@export var puff_size_end := 1.2
@export var puff_time := 0.5
@export_range(0.0, 180.0) var puff_spread := 25.0
@export var puff_speed := 2.0
