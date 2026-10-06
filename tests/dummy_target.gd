extends CharacterBody3D

var hp: int = 40
var max_hp: int = 40


func take_damage(amount: int, damage_type: Enums.DamageType = Enums.DamageType.SLASH) -> void:
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
