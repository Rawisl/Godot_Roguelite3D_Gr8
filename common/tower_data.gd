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
@export var splash_falloff_edge: float = 1.0
@export var levels: Array[TowerLevelData] = []
## Model scene per tier (1..3). Entries may repeat when one scene holds every tier.
@export var model_tier_scenes: Array[PackedScene] = []

## Missing entries use the nearest lower tier, or null when none is available.
func get_model_scene(tier: int) -> PackedScene:
	for i in range(mini(tier, model_tier_scenes.size()) - 1, -1, -1):
		if model_tier_scenes[i] != null:
			return model_tier_scenes[i]
	return null

## Total gold to reach `level` from nothing: build + every upgrade up to it.
func get_total_cost(level: int) -> int:
	var total := 0
	for i in clampi(level, 0, levels.size()):
		total += levels[i].build_cost
	return total


## Model tier (1..3) shown at `level`: 1 below tower_tier2_level, 2 below tower_tier3_level, else 3.
static func model_tier(level: int) -> int:
	if level < GameConfig.tower_tier2_level:
		return 1
	if level < GameConfig.tower_tier3_level:
		return 2
	return 3
