class_name ShopRow
extends PanelContainer
## One meta shop item: name and level, what it gives now and at the next level, the cost and the
## balance left after buying. Short of prestige, the cost line names what is missing in the error
## colour and Buy is grey; at max level Buy reads MAX.

signal buy_pressed

## Cost line colour when prestige is short, dark enough to read on the light shop panel.
@export var short_color := Color(0.6902, 0.251, 0.1804)

@onready var _name: Label = %NameLabel
@onready var _level: Label = %LevelLabel
@onready var _effect: Label = %EffectLabel
@onready var _next: Label = %NextLabel
@onready var _note: Label = %NoteLabel
@onready var _cost: Label = %CostLabel
@onready var _buy: Button = %BuyButton

func _ready() -> void:
	_buy.pressed.connect(buy_pressed.emit)

## busy is true while a purchase is being processed: every Buy button waits for it.
func show_item(item: ShopItem, level: int, balance: int, busy: bool) -> void:
	var max_level := item.get_max_level()
	var cost := item.get_next_cost(level)
	_name.text = tr(item.name_key)
	_level.text = UiFormat.tr_fmt(&"shop.level", {"level": level, "max": max_level})
	_effect.text = UiFormat.tr_fmt(&"shop.now", {"effect": _effect_text(item, level)})
	_note.visible = item.note_key != &""
	_note.text = tr(item.note_key) if _note.visible else ""
	_cost.remove_theme_color_override(&"font_color")
	if cost < 0:
		_next.visible = false
		_cost.text = ""
		_buy.text = tr(&"shop.max")
		_buy.disabled = true
		return
	_next.visible = true
	_next.text = UiFormat.tr_fmt(&"shop.next", {"effect": _effect_text(item, level + 1)})
	var shortfall := cost - balance
	_buy.text = tr(&"shop.buy")
	if shortfall > 0:
		_cost.text = UiFormat.tr_fmt(&"shop.cost_short", {"cost": cost, "value": shortfall})
		_cost.add_theme_color_override(&"font_color", short_color)
		_buy.disabled = true
		_buy.tooltip_text = UiFormat.tr_fmt(&"shop.need", {"value": shortfall})
	else:
		_cost.text = UiFormat.tr_fmt(&"shop.cost_after", {"cost": cost, "after": balance - cost})
		_buy.disabled = busy
		_buy.tooltip_text = ""

func _effect_text(item: ShopItem, level: int) -> String:
	return UiFormat.tr_fmt(item.effect_key, {"value": UiFormat.num(item.get_effect(level))})
