extends Node
## Fake meta shop service and leaderboard source for test_meta_screens. Purchases change the save
## data in memory only (nothing is written to disk) and answer after one frame, like a network call.

var purchase_ok := true
## "outside": top 50 and the player at rank 72. "inside": the player at rank 3. "error": a network error.
var board_mode := "outside"
var purchases := 0

func _enter_tree() -> void:
	add_to_group(&"meta_shop_service")
	add_to_group(&"leaderboard_source")

func purchase(item_id: StringName) -> bool:
	purchases += 1
	await get_tree().process_frame
	if not purchase_ok:
		return false
	var item := _find_item(item_id)
	var profile := SaveManager.get_section(&"profile")
	var levels: Dictionary = SaveManager.get_section(&"meta")["levels"]
	var level := int(levels.get(String(item_id), 0))
	var cost := item.get_next_cost(level) if item != null else -1
	if cost < 0 or int(profile["prestige_balance"]) < cost:
		return false
	profile["prestige_balance"] = int(profile["prestige_balance"]) - cost
	levels[String(item_id)] = level + 1
	EventBus.meta_item_purchased.emit(item_id, level + 1)
	EventBus.prestige_balance_changed.emit(int(profile["prestige_balance"]))
	return true

func fetch_leaderboard(top_n: int) -> Dictionary:
	await get_tree().process_frame
	if board_mode == "error":
		return {"ok": false}
	var rows: Array = []
	for i in top_n:
		rows.append({"rank": i + 1, "display_name": "Player%02d" % (i + 1), "waves_cleared": 40 - i / 2, "run_elapsed": 900.0 + i * 37.0})
	var own_rank := 72 if board_mode == "outside" else 3
	var own := {"rank": own_rank, "display_name": "TestPlayer", "waves_cleared": 12, "run_elapsed": 431.0}
	if own_rank <= rows.size():
		rows[own_rank - 1] = own
	return {"ok": true, "rows": rows, "own": own}

func _find_item(item_id: StringName) -> ShopItem:
	for path in ["fort_hp", "gold_pct", "cmd_hp", "emg_repair"]:
		var item := load("res://data/config/meta_shop/%s.tres" % path) as ShopItem
		if item.id == item_id:
			return item
	return null
