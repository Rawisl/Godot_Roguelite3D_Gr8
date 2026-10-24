class_name WaveTable
extends Resource

## Table containing enemy spawn rules and boss intervals

@export var groups: Array[WaveGroup] = []
@export var boss_every: int = 5

@export_group("Spawn Timing")
@export var group_spawn_delay_min: float = 0.4
@export var group_spawn_delay_max: float = 0.8
@export var group_pause: float = 3.0
@export var spawn_overlap_radius: float = 1.0
@export var spawn_retry_delay: float = 0.2
@export var spawn_retry_timeout: float = 3.0

@export_group("Composition Constraints")
@export var archer_max_ratio: float = 0.40
@export var support_max_ratio: float = 0.20
@export var support_min_combat: int = 3
@export var escort_budget_ratio: float = 0.5


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
