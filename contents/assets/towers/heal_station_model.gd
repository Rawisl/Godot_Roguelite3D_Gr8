class_name HealStationModel
extends Node3D
## Heal station model with its three tiers (HealStationL1..L3 in heal_station_tiers.glb).
## - Shows the tier reported by the Tower's model_tier_changed signal.
## - Moves and scales the energy orb with the tier: each tier's pool sits at its own height, so
##   the orb floats over that pool at the same distance and size the full model has, scaled
##   by how much smaller the tier is.
## Without a Tower above it (a preview or a test) it shows preview_tier.

## Orb height over the ground per tier (1, 2, 3), in metres.
@export var orb_heights: PackedFloat32Array = PackedFloat32Array([0.72, 0.88, 1.3])
## Orb scale per tier (1, 2, 3); 1 is the size set on the EnergyOrb itself.
@export var orb_scales: PackedFloat32Array = PackedFloat32Array([0.71, 0.79, 1.0])
@export_range(1, 3) var preview_tier := 1

var _tower: Tower
var _levels: Array[Node3D] = []
var _shown := -1

@onready var _orb: EnergyOrb = %EnergyOrb


func _ready() -> void:
	for i in 3:
		var level := find_child("HealStationL%d" % (i + 1), true, false) as Node3D
		if level != null:
			_levels.append(level)
	_tower = _find_tower()
	if _tower != null:
		_tower.model_tier_changed.connect(_show_tier)
	_show_tier(_tier())


## Tier shown now, 1 to 3.
func get_tier() -> int:
	return _shown + 1


func _tier() -> int:
	if _tower == null:
		return preview_tier
	if _tower.model_tier > 0:
		return _tower.model_tier
	return TowerData.model_tier(_tower.level)


func _show_tier(tier: int) -> void:
	_shown = clampi(tier - 1, 0, maxi(_levels.size() - 1, 0))
	for i in _levels.size():
		_levels[i].visible = i == _shown
	if _orb != null:
		var s := orb_scales[_shown] if _shown < orb_scales.size() else 1.0
		_orb.scale = Vector3.ONE * s
		_orb.set_base_height(orb_heights[_shown] if _shown < orb_heights.size() else _orb.position.y)


func _find_tower() -> Tower:
	var n := get_parent()
	while n != null and not n is Tower:
		n = n.get_parent()
	return n as Tower
