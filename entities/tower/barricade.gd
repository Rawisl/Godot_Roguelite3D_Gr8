class_name Barricade
extends Tower
# TODO(kiezroth): when TowerData holds the three tier models, drop _show_level_model and let the shared tier swap show every tower

var aggro_weight: float:
	get:
		return _lv.aggro_weight if _lv != null else 1.0

func _ready() -> void:
	super._ready()
	# Never scans for or shoots at anything (can_attack() is false: no projectile, fire_rate 0).
	range_area.monitoring = false
	set_physics_process(false)


func apply_level(new_level: int) -> void:
	super.apply_level(new_level)
	_show_level_model()


## The model holds one mesh group per model tier (Level1..Level3).
func _show_level_model() -> void:
	var model := get_node_or_null(^"Model")
	if model == null:
		return
	var tier := _model_tier()
	for i in range(1, 4):
		var n := model.find_child("Level%d" % i, true, false) as Node3D
		if n != null:
			n.visible = i == tier


## Model tier of the current level; the rule lives in TowerData.model_tier.
func _model_tier() -> int:
	return TowerData.model_tier(level)
