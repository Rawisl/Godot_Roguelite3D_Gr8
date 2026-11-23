class_name Barricade
extends Tower

var aggro_weight: float:
	get:
		return _lv.aggro_weight if _lv != null else 1.0

func _ready() -> void:
	super._ready()
	# Never scans for or shoots at anything (can_attack() is false: no projectile, fire_rate 0).
	range_area.monitoring = false
	set_physics_process(false)
