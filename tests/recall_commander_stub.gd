extends "res://entities/commander/commander.gd"

## Stands in for the Recall state until the commander has one.
var stub_recalling := false


func is_aura_source() -> bool:
	return super() and not stub_recalling
