class_name Barricade
extends Tower

var aggro_weight: float:
	get:
		return _lv.aggro_weight if _lv != null else 1.0

## Melee attackers walk this close to their attack position before swinging (read by Enemy),
## so a unit does not stop short and block the way to the positions next to it.
const MELEE_ARRIVE_DISTANCE := 0.6

@onready var melee_slots: BarricadeMeleeSlots = %MeleeSlots


func _ready() -> void:
	super._ready()
	# Never scans for or shoots at anything (can_attack() is false: no projectile, fire_rate 0).
	range_area.monitoring = false
	set_physics_process(false)
	health.died.connect(melee_slots.release_all)


func apply_level(new_level: int) -> void:
	super.apply_level(new_level)
	_show_level_model()


## The model holds one mesh group per level (Level1..Level3).
func _show_level_model() -> void:
	var model := get_node_or_null(^"Model")
	if model == null:
		return
	for i in range(1, 4):
		var n := model.find_child("Level%d" % i, true, false) as Node3D
		if n != null:
			n.visible = i == level


#region Melee slots (same as Fortress)
func claim_melee_slot(attacker: Node3D) -> bool:
	if health.hp <= 0:
		return false
	return melee_slots.claim(attacker)


func release_melee_slot(attacker: Node3D) -> void:
	melee_slots.release(attacker)


func has_melee_slot(attacker: Node3D) -> bool:
	return melee_slots.has(attacker)


func get_melee_slot_position(attacker: Node3D) -> Vector3:
	return melee_slots.position_for(attacker)


func get_free_melee_slots() -> int:
	return melee_slots.free_count()


func get_melee_arrive_distance() -> float:
	return MELEE_ARRIVE_DISTANCE
#endregion
