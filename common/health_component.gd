class_name HealthComponent
extends Node

signal hp_changed(hp: int, max_hp: int)
signal died

@export var max_hp: int = 100
var hp: int

func _ready() -> void:
	hp = max_hp

func take_damage(amount: int) -> void:
	hp = max(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	if hp == 0:
		died.emit()
