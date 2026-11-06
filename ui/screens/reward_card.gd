class_name RewardCard
extends Button
## One REWARD_PICK card, drawn from the card dictionary that RewardOfferGenerator builds.

signal chosen(card: Dictionary)

const KIND_KEYS := {
	&"ACTIVE": &"reward.kind.active",
	&"PASSIVE": &"reward.kind.passive",
	&"STAT": &"reward.kind.stat",
}

var _card: Dictionary = {}

@onready var _kind: Label = %Kind
@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _level: Label = %Level
@onready var _desc: Label = %Desc

func _ready() -> void:
	pressed.connect(func() -> void: chosen.emit(_card))

func show_card(card: Dictionary) -> void:
	_card = card
	var data := card.get("data") as SkillData
	_kind.text = tr(KIND_KEYS.get(card.get("kind"), &""))
	_icon.texture = data.icon if data != null else null
	_name.text = tr(data.name_key) if data != null else String(card.get("id", ""))
	if card.get("is_new", false):
		_level.text = tr(&"reward.level.new")
	else:
		_level.text = UiFormat.tr_fmt(&"reward.level.up",
			{"from": card.get("level", 0), "to": card.get("next_level", 1)})
	_desc.text = tr(data.description_key) if data != null else ""
	var max_level := data.get_max_level() if data != null else 0
	tooltip_text = UiFormat.tr_fmt(&"reward.card.tip", {"desc": _desc.text, "max": max_level})
	visible = true
