class_name WavePreviewRow
extends HBoxContainer
## One enemy type of the next wave: name, count and its traits.

@onready var _name: Label = %Name
@onready var _count: Label = %Count
@onready var _badges: HBoxContainer = %Badges

## count 0 hides the count, for the boss row.
func show_enemy(enemy_id: StringName, count: int) -> void:
	_name.text = EnemyTraits.display_name(enemy_id)
	_count.visible = count > 0
	_count.text = UiFormat.tr_fmt(&"hud.preview.count", {"value": count})
	var traits := EnemyTraits.of(enemy_id)
	var badges := _badges.get_children()
	for i in badges.size():
		var badge := badges[i] as TraitBadge
		if i < traits.size():
			badge.show_trait(traits[i])
		else:
			badge.visible = false
	_badges.visible = not traits.is_empty()
	visible = true

func trait_count() -> int:
	return _badges.get_children().filter(func(b: Node) -> bool: return (b as Control).visible).size()
