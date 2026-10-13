class_name TowerData
extends Resource

@export var id: StringName
@export var display_name: String
@export var allowed_zones: Array[Enums.SlotZone] = []
@export var damage_type: Enums.DamageType = Enums.DamageType.PIERCE
@export var targets_ground: bool = true
@export var targets_air: bool = false
@export var default_priority: Enums.TargetPriority = Enums.TargetPriority.FIRST
@export var min_range: float = 0.0
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 20.0
@export var release_delay: float = 0.0
@export var levels: Array[TowerLevelData] = []

## Total gold to reach `level` from nothing: build + every upgrade up to it.
func get_total_cost(level: int) -> int:
	var total := 0
	for i in clampi(level, 0, levels.size()):
		total += levels[i].build_cost
	return total
