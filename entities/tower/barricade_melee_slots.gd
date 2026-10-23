class_name BarricadeMeleeSlots
extends TowerMeleeSlots
## TWR-06: at most max_attackers_per_barricade melee units attack one Barricade at a time.
## Same positions logic as every tower; only the count differs (markers P0..P4 in barricade.tscn).


func _expected_count() -> int:
	return GameConfig.max_attackers_per_barricade


## The Barricade sits next to the corridor walls with its positions spread along its face; a walk
## round outside them could leave the navmesh there. Units keep walking straight in, as before.
func _route_point(_attacker: Node3D, i: int) -> Vector3:
	return _world_point(i)
