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
@export var levels: Array[TowerLevelData] = []
