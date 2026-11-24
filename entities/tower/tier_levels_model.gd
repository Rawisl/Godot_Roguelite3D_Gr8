class_name TierLevelsModel
extends Node3D

## Shows the Level1..Level3 mesh group matching the tower's model tier.
var _tower: Tower

func _ready() -> void:
	_tower = get_parent() as Tower
	if _tower == null:
		push_warning("TierLevelsModel: %s is not under a Tower" % name)
		return
	_tower.model_tier_changed.connect(_show_tier)
	if _tower.model_tier > 0:
		_show_tier(_tower.model_tier)

func _show_tier(tier: int) -> void:
	for i in range(1, 4):
		var n := find_child("Level%d" % i, true, false) as Node3D
		if n != null:
			n.visible = i == tier
