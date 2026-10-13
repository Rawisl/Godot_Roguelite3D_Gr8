class_name WaveTable
extends Resource

## Table containing enemy spawn rules and boss intervals

@export var groups: Array[WaveGroup] = []
@export var boss_every: int = 5


func is_boss_wave(wave: int) -> bool:
	return (wave > 0) and (wave % boss_every == 0)

func get_boss_index(wave: int) -> int:
	return (wave / boss_every) if is_boss_wave(wave) else 0

func get_available_groups(wave: int) -> Array[WaveGroup]:
	var result: Array[WaveGroup] = []
	for g in groups:
		if g != null and g.is_available_at(wave):
			result.append(g)
	return result

func get_intro_spawns(wave: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for g in groups:
		if g != null and g.enemy != null and g.min_wave == wave and g.intro_count > 0:
			result.append({
				"enemy": g.enemy,
				"count": g.intro_count
			})
	return result
