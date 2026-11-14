class_name MetaShopService
extends Node
## Buys meta shop levels for the shop screen it sits in. A purchase checks the balance, takes
## the cost, raises the level by one and saves in one call; a failed save puts both back.

const GROUP := &"meta_shop_service"

## True from taking the cost until the signals are out, so a listener cannot buy again mid-purchase.
var _busy := false

func _enter_tree() -> void:
	add_to_group(GROUP)

## Returns true when one level was bought and saved.
func purchase(item_id: StringName) -> bool:
	if _busy:
		return false
	var item := MetaUpgrades.find_item(item_id)
	if item == null:
		push_warning("MetaShopService: unknown item %s" % item_id)
		return false
	var key := String(item_id)
	var profile := SaveManager.get_section(SaveManager.PROFILE)
	var levels: Dictionary = SaveManager.get_section(SaveManager.META)["levels"]
	var level := int(levels.get(key, 0))
	var cost := item.get_next_cost(level)
	if cost < 0:
		return false
	var balance := int(profile["prestige_balance"])
	if balance < cost:
		return false
	_busy = true
	profile["prestige_balance"] = balance - cost
	levels[key] = level + 1
	if SaveManager.save() != OK:
		profile["prestige_balance"] = balance
		levels[key] = level
		_busy = false
		return false
	EventBus.meta_item_purchased.emit(item_id, level + 1)
	EventBus.prestige_balance_changed.emit(balance - cost)
	_busy = false
	return true
