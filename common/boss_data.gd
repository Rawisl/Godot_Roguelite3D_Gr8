class_name BossData
extends EnemyData

@export var boss_timer: float = 90.0
@export var phase_hp_pct: Array[float] = [0.5]
@export var resist: Dictionary = {}
@export var immune_phase1: Array[StringName] = []
@export var boss_gold: int = 0
