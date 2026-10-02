class_name TowerData
extends Resource

@export var id: StringName
@export var display_name: String
@export var allowed_zones: Array[SlotZone.Zone] = []
@export var targets_ground: bool = true
@export var min_range: float = 0.0
@export var levels: Array[TowerLevelData] = []
