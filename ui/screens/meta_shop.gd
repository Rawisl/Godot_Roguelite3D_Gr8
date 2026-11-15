extends MarginContainer
## Meta shop: the prestige balance and the four permanent upgrades. Levels and the balance are
## read from the save; buying is left to the shop service, which checks the balance, raises the
## level and saves in one step. One purchase at a time: every Buy button waits for the answer.

const PROFILE := &"profile"
const META := &"meta"

## The items the shop shows, in order. Items not built yet stay out of this list.
@export var items: Array[ShopItem] = []

var _busy := false
var _failed := false

@onready var _title: Label = %Title
@onready var _balance: Label = %Balance
@onready var _rows: VBoxContainer = %Rows
@onready var _error: Label = %ErrorLabel
@onready var _back: Button = %Back

func _ready() -> void:
	_title.text = tr(&"menu.meta_shop")
	_back.text = tr(&"menu.back")
	_error.text = tr(&"shop.error")
	_back.pressed.connect(go_back)
	var rows := _rows.get_children()
	for i in rows.size():
		(rows[i] as ShopRow).buy_pressed.connect(_buy.bind(i))
	EventBus.prestige_balance_changed.connect(_on_balance_changed)
	EventBus.meta_item_purchased.connect(_on_item_purchased)
	SaveManager.save_loaded.connect(refresh)
	refresh()
	_back.grab_focus()

func go_back() -> void:
	GameState.change_state(GameState.AppState.MAIN_MENU)

func refresh() -> void:
	var balance := get_balance()
	_balance.text = UiFormat.tr_fmt(&"shop.balance", {"value": balance})
	_error.visible = _failed
	var rows := _rows.get_children()
	for i in rows.size():
		var row := rows[i] as ShopRow
		row.visible = i < items.size()
		if row.visible:
			row.show_item(items[i], get_level(items[i].id), balance, _busy)

func get_balance() -> int:
	return int(SaveManager.get_section(PROFILE).get("prestige_balance", 0))

func get_level(id: StringName) -> int:
	var levels: Dictionary = SaveManager.get_section(META).get("levels", {})
	return int(levels.get(String(id), 0))

func _service() -> Node:
	return get_tree().get_first_node_in_group(&"meta_shop_service")

## The row only enables Buy when it can be bought; the service checks again when it runs.
func _buy(index: int) -> void:
	if _busy or index >= items.size():
		return
	var service := _service()
	if service == null or not service.has_method(&"purchase"):
		_failed = true
		refresh()
		return
	_busy = true
	_failed = false
	refresh()
	var ok: bool = await service.call(&"purchase", items[index].id)
	_busy = false
	_failed = not ok
	refresh()

func _on_balance_changed(_value: int) -> void:
	refresh()

func _on_item_purchased(_item_id: StringName, _new_level: int) -> void:
	refresh()
