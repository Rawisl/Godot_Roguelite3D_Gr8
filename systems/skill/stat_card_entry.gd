class_name StatCardEntry
extends Resource
## Maps a card's balance value to an additive or multiplicative stat modifier.

enum Kind { ADD, MUL }

@export var card: SkillData
@export var stat_key: StringName
@export var kind: Kind = Kind.ADD
