class_name Projectile
extends Area3D

var speed: float = 20.0
var damage: int = 0
var damage_type: Enums.DamageType = Enums.DamageType.PIERCE
var target: Node3D = null
