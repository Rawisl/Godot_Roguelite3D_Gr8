class_name RewardSlot
extends VBoxContainer
## One skill slot under the REWARD_PICK cards: a round icon with the skill name under it, or "Empty".
## Hovering the circle shows the skill's current level.

@export var filled_style: StyleBox
@export var empty_style: StyleBox

@onready var _circle: PanelContainer = %Circle
@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name

func set_skill(data: SkillData, level: int = 0) -> void:
	var filled := data != null
	_circle.add_theme_stylebox_override(&"panel", filled_style if filled else empty_style)
	_icon.visible = filled
	_icon.texture = data.icon if filled else null
	_name.text = tr(data.name_key) if filled else tr(&"reward.slot.empty")
	_name.theme_type_variation = &"" if filled else &"DimLabel"
	if not filled:
		_circle.tooltip_text = ""
	elif level > 0:
		_circle.tooltip_text = UiFormat.tr_fmt(&"reward.slot.tip",
			{"name": _name.text, "level": level, "max": data.get_max_level()})
	else:
		_circle.tooltip_text = _name.text
