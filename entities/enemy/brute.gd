class_name Brute
extends Enemy

## Brute enemy archetype with high health, high damage, and knockback/stun immunity.
## Marches directly toward Fortress, ignoring Barricades and ground towers unless provoked.

func _ready() -> void:
	super._ready()
