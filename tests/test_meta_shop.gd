extends Node
## Meta shop with a fake shop service. Press F6: the checks run first and print a summary (the save
## is only changed in memory and put back after), then click the window once and use the keys:
## 1: +100 prestige. 2: 30 prestige (not enough for most items). 3: all items back to level 0.
## 4: max out Commander HP. F: the next purchase fails / succeeds again. Number row or numpad;
## each key prints what it did in Output.

var _passed := 0
var _failed := 0
var _saved_profile: Dictionary
var _saved_meta: Dictionary

@onready var _fake: Node = $"../FakeServices"
@onready var _shop: Control = $"../MetaShop"

func _ready() -> void:
	_saved_profile = SaveManager.get_section(&"profile").duplicate(true)
	_saved_meta = SaveManager.get_section(&"meta").duplicate(true)
	await get_tree().process_frame
	await _run_checks()
	_reset_levels()
	_set_prestige(100)

func _exit_tree() -> void:
	_restore_save()

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match _key_of(key):
		KEY_1:
			_set_prestige(_shop.get_balance() + 100)
			print("[key 1] +100 prestige, now ", _shop.get_balance())
		KEY_2:
			_set_prestige(30)
			print("[key 2] prestige set to 30")
		KEY_3:
			_reset_levels()
			print("[key 3] every item back to level 0")
		KEY_4:
			_set_level("CMD_HP", 3)
			print("[key 4] Commander HP at max level")
		KEY_F:
			_fake.purchase_ok = not _fake.purchase_ok
			print("[key F] next purchase ", "succeeds" if _fake.purchase_ok else "fails")

## Numpad digits count as the number row ones.
func _key_of(key: InputEventKey) -> Key:
	if key.keycode >= KEY_KP_0 and key.keycode <= KEY_KP_9:
		return (KEY_0 + (key.keycode - KEY_KP_0)) as Key
	return key.keycode

func _set_prestige(value: int) -> void:
	SaveManager.get_section(&"profile")["prestige_balance"] = value
	_shop.refresh()

func _set_level(id: String, level: int) -> void:
	SaveManager.get_section(&"meta")["levels"][id] = level
	_shop.refresh()

func _reset_levels() -> void:
	for id in ["FORT_HP", "GOLD_PCT", "CMD_HP", "EMG_REPAIR"]:
		SaveManager.get_section(&"meta")["levels"][id] = 0
	_shop.refresh()

## Puts back what the save held before the test, so nothing leaks into a later save.
func _restore_save() -> void:
	var profile := SaveManager.get_section(&"profile")
	var meta := SaveManager.get_section(&"meta")
	profile.clear()
	profile.merge(_saved_profile.duplicate(true))
	meta.clear()
	meta.merge(_saved_meta.duplicate(true))

func _row(index: int) -> ShopRow:
	return _shop.get_node("%Rows").get_child(index) as ShopRow

func _buy_button(index: int) -> Button:
	return _row(index).get_node("%BuyButton") as Button


func _run_checks() -> void:
	_reset_levels()
	_set_prestige(100)
	var rows := _shop.get_node("%Rows").get_children()
	_check(rows.size() == 4 and rows.all(func(r: Control) -> bool: return r.visible), "the shop shows exactly the four items")
	_check((_shop.get_node("%Balance") as Label).text.contains("100"), "the balance shows")
	_check(not _buy_button(0).disabled and _buy_button(0).text == tr(&"shop.buy"), "100 prestige: the first level of Fortress HP can be bought")
	_check((_row(0).get_node("%CostLabel") as Label).text.contains("60"), "the cost line gives the balance left after buying")
	_check((_row(0).get_node("%NextLabel") as Label).text.contains("5%"), "the next level effect shows")
	_check((_row(3).get_node("%NoteLabel") as Label).visible, "Emergency repair notes the 3 charge limit")
	_check((_row(3).get_node("%EffectLabel") as Label).text.contains("20%"), "Emergency repair starts at 20%")
	_set_prestige(30)
	_check(_buy_button(0).disabled and (_row(0).get_node("%CostLabel") as Label).text == UiFormat.tr_fmt(&"shop.cost_short", {"cost": 40, "value": 10}),
		"30 prestige: Buy grey, the cost line names the 10 missing")
	_set_level("CMD_HP", 3)
	_check(_buy_button(2).disabled and _buy_button(2).text == tr(&"shop.max"), "max level reads MAX")
	_set_level("CMD_HP", 0)

	_set_prestige(100)
	_buy_button(0).pressed.emit()
	_buy_button(1).pressed.emit()
	_check(_fake.purchases == 1 and _buy_button(1).disabled, "while one purchase runs, the other Buy buttons wait")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_shop.get_level(&"FORT_HP") == 1 and _shop.get_balance() == 60, "the purchase raises the level and takes the cost")
	_check((_row(0).get_node("%LevelLabel") as Label).text == UiFormat.tr_fmt(&"shop.level", {"level": 1, "max": 5}), "the row shows the new level")
	_fake.purchase_ok = false
	_buy_button(0).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check((_shop.get_node("%ErrorLabel") as Label).visible and _shop.get_balance() == 60, "a failed purchase shows the error and keeps the balance")
	_fake.purchase_ok = true
	_set_prestige(100)
	_buy_button(0).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not (_shop.get_node("%ErrorLabel") as Label).visible and _shop.get_level(&"FORT_HP") == 2, "the next good purchase clears the error")
	print("test_meta_shop: %d passed, %d failed" % [_passed, _failed])

func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		print("  [FAIL] ", label)
