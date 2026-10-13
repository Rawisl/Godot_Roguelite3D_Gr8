extends CharacterBody3D

var hp: int = 40
var max_hp: int = 40


func take_damage(damage_input: Variant, p_damage_type: Enums.DamageType = Enums.DamageType.SLASH) -> void:
	var amount: int = 0
	var damage_type: Enums.DamageType = p_damage_type
	if damage_input is DamageInfo:
		amount = damage_input.amount
		damage_type = damage_input.damage_type
	elif damage_input is int:
		amount = damage_input

	var prev_hp := hp
	hp = maxi(0, hp - amount)

	var type_str := "SLASH"
	match damage_type:
		Enums.DamageType.PIERCE: type_str = "PIERCE"
		Enums.DamageType.BLAST: type_str = "BLAST"
		Enums.DamageType.SLASH: type_str = "SLASH"
		Enums.DamageType.TRUE: type_str = "TRUE"

	print("[HIT] %s trúng đòn! Sát thương: %d | Loại: %s | HP: %d/%d" % [
		name, amount, type_str, hp, max_hp
	])
