class_name TraitBadge
extends PanelContainer
## One enemy trait: its icon and its name, never the icon alone.

@onready var _glyph: TraitGlyph = %Glyph
@onready var _name: Label = %Name

func show_trait(trait_id: StringName) -> void:
	_glyph.trait_id = trait_id
	_name.text = EnemyTraits.label(trait_id)
	visible = true
