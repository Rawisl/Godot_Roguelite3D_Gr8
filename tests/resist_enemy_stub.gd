extends "res://entities/enemy/enemy.gd"
## Test stub: an Enemy with a resistance table, until boss resistances (DMG-01) exist.

var resist_table: Dictionary = {}

func get_resist(damage_type: Enums.DamageType) -> float:
	return resist_table.get(damage_type, 1.0)
