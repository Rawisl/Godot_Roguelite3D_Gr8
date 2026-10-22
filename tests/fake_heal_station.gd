class_name FakeHealStation
extends Node3D
## Stand-in for the real heal tower, used until slots can host one. Same surface the
## heal channel needs: position, slot_id, a draining HP pool, a depleted signal.

signal depleted

@export var slot_id: StringName = &"fake_station"
@export var max_hp: float = 300.0

var hp: float


func _ready() -> void:
	hp = max_hp
	add_to_group(&"heal_station")


func is_alive() -> bool:
	return hp > 0.0


func drain(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		depleted.emit()
