class_name GoldManager
extends Node
## Gold of the current run. The check and the subtraction happen in one call,
## so a transaction either finishes or changes nothing.

var gold: int = 0

func _ready() -> void:
	add_to_group(&"gold_manager")
	EventBus.run_started.connect(reset)
	# Deferred so the HUD, which is ready after Gameplay, gets the first value.
	reset.call_deferred()

func reset() -> void:
	_set_gold(GameConfig.starting_gold, false)

func can_afford(cost: int) -> bool:
	return cost >= 0 and gold >= cost

func shortfall(cost: int) -> int:
	return maxi(0, cost - gold)

## Returns false and changes nothing when gold < cost.
func try_spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	_set_gold(gold - cost)
	return true

func add(amount: int, show_delta: bool = true) -> void:
	if amount <= 0:
		return
	_set_gold(gold + amount, show_delta)

func _set_gold(value: int, show_delta: bool = true) -> void:
	var delta := value - gold
	gold = maxi(0, value)
	EventBus.gold_changed.emit(gold)
	if show_delta and delta != 0:
		EventBus.gold_delta.emit(delta)
