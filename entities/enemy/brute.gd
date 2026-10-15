class_name Brute
extends Enemy

## Brute enemy archetype with high health, high damage, and knockback/stun immunity (AI-05).
## Marches directly toward Fortress, ignoring Barricades and ground towers unless provoked (SRS 3.7.3).

func _ready() -> void:
	super._ready()
