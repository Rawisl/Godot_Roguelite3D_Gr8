class_name HealthComponent
extends Node

signal hp_changed(hp: int, max_hp: int)
signal damaged(amount: int, info: DamageInfo)
signal died

@export var max_hp: int = 100
## Integer combat view. A living target with less than one HP still takes a hit.
var hp: int:
	get:
		return ceili(_precise_hp)
	set(value):
		_precise_hp = float(value)
var hit_by_commander: bool = false
## Fractional DoT damage carried between ticks.
var dot_remainder: float = 0.0
var _precise_hp: float = 0.0


func _ready() -> void:
	hp = max_hp


## Accepts either an int amount or a DamageInfo instance for backward compatibility.
func take_damage(damage_input: Variant, damage_type: Enums.DamageType = Enums.DamageType.SLASH) -> int:
	if hp <= 0:
		return 0
	var amount: int = 0
	var info: DamageInfo = null
	if damage_input is DamageInfo:
		info = damage_input
		amount = info.amount
	elif damage_input is int:
		amount = damage_input
		info = DamageInfo.new(amount, damage_type)
	else:
		push_warning("HealthComponent.take_damage received invalid argument type")
		return 0
	if amount <= 0:
		return 0
	var previous_hp := hp
	_precise_hp = maxf(0.0, _precise_hp - amount)
	var damage_taken := previous_hp - hp

	# Flag flips on first damage >= 1 from commander
	if damage_taken >= 1 and not hit_by_commander:
		if info != null and (info.hit_by_commander or info.is_from_commander()):
			hit_by_commander = true

	hp_changed.emit(floori(_precise_hp), max_hp)
	damaged.emit(damage_taken, info)
	if hp == 0:
		died.emit()
	return damage_taken


## Restores health, capped at max_hp.
func heal(amount: int) -> int:
	return floori(heal_fractional(float(amount)))


func heal_fractional(amount: float) -> float:
	if _precise_hp <= 0.0 or amount <= 0.0:
		return 0.0
	var previous_hp := _precise_hp
	var next_hp := minf(max_hp, _precise_hp + amount)
	var whole_hp := ceilf(next_hp)
	_precise_hp = whole_hp if whole_hp - next_hp <= 0.000001 else next_hp
	var healed_amount := _precise_hp - previous_hp
	if healed_amount > 0:
		hp_changed.emit(floori(_precise_hp), max_hp)
	return healed_amount


## Changes max HP. With heal_gain, a living entity is healed by exactly the amount max HP grew.
func set_max_hp(value: int, heal_gain: bool = false) -> void:
	var gained := value - max_hp
	max_hp = value
	if heal_gain and gained > 0 and _precise_hp > 0.0:
		_precise_hp += gained
	_precise_hp = minf(_precise_hp, max_hp)
	hp_changed.emit(floori(_precise_hp), max_hp)


func is_alive() -> bool:
	return hp > 0


func get_health_ratio() -> float:
	return _precise_hp / max_hp if max_hp > 0 else 0.0


func get_precise_hp() -> float:
	return _precise_hp
