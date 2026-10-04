class_name WaveGroup
extends Resource

## Wave enemy spawn group definition (SRS 3.7.5).

@export var enemy: EnemyData
@export var weight: float = 10.0
@export var min_wave: int = 1
@export var max_per_wave: int = -1
@export var intro_count: int = 0


func is_available_at(wave: int) -> bool:
	return wave >= min_wave

func get_max_allowed(wave: int) -> int:
	if enemy != null and enemy.id == &"brute":
		return maxi(1, int(floor(float(wave) / 4.0)))
	if max_per_wave > 0:
		return max_per_wave
	return 999999
