class_name HealthComponent
extends Node

signal hp_changed(hp: int, max_hp: int)
signal damaged(amount: int, info: DamageInfo)
signal died

@export var max_hp: int = 100
var hp: int


func _ready() -> void:
	hp = max_hp


## Accepts either an int amount or a DamageInfo instance for backward compatibility.
func take_damage(damage_input: Variant) -> int:
	if hp <= 0:
		return 0

	var amount: int = 0
	var info: DamageInfo = null

	if damage_input is DamageInfo:
		info = damage_input
		amount = info.amount
	elif damage_input is int:
		amount = damage_input
		info = DamageInfo.new(amount)
	else:
		push_warning("HealthComponent.take_damage received invalid argument type")
		return 0

	if amount <= 0:
		return 0

	var previous_hp := hp
	hp = maxi(0, hp - amount)
	var damage_taken := previous_hp - hp

	hp_changed.emit(hp, max_hp)
	damaged.emit(damage_taken, info)

	if hp == 0:
		died.emit()

	return damage_taken


## Restores health, capped at max_hp.
func heal(amount: int) -> int:
	if hp <= 0 or amount <= 0:
		return 0

	var previous_hp := hp
	hp = mini(max_hp, hp + amount)
	var healed_amount := hp - previous_hp

	if healed_amount > 0:
		hp_changed.emit(hp, max_hp)

	return healed_amount


func is_alive() -> bool:
	return hp > 0


func get_health_ratio() -> float:
	return float(hp) / float(max_hp) if max_hp > 0 else 0.0
