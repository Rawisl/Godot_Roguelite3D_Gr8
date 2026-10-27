class_name StatCardEntry
extends Resource
## One stat change granted by a card. The modifier grows linearly with the card level.

enum Kind { ADD, MUL }

@export var card_id: StringName
@export var stat_key: StringName
@export var kind: Kind = Kind.ADD
## Value added to the modifier for every card level. Percentages are fractions (0.08 = 8%).
@export var per_level: float = 0.0
