class_name Projectile
extends Area3D

signal released(projectile: Projectile)

var speed: float = 20.0
var damage: int = 0
var damage_type: Enums.DamageType = Enums.DamageType.PIERCE
var target: Node3D = null
var in_use: bool = false
var pool_key: String = ""

## Starts a flight from `from` toward `to`. Subclasses set up their movement here.
func launch(from: Vector3, to: Node3D, dmg: int, dmg_type: Enums.DamageType, spd: float) -> void:
	global_position = from
	target = to
	damage = dmg
	damage_type = dmg_type
	speed = spd

func release() -> void:
	if not in_use:
		return
	released.emit(self)
