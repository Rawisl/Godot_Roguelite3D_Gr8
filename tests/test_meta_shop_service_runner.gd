extends Node

## Automated test runner verifying:
## - the shop catalog (four items, costs, max levels) and that the shop screen lists the same items
## - a purchase takes the cost, raises the level by one, saves, and is refused or undone otherwise
## - the run modifiers computed from meta levels, and that RunConfig accepts them
## - meta levels above an upgrade's max are clamped on load
## - the shop screen finds the service that sits inside it
## Nothing is written to disk: saves go to an in-memory repository, the real one is put back afterwards.

const SHOP_SCENE := preload("res://ui/screens/meta_shop.tscn")

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []

var _mem: MemorySaveRepository
var _service: MetaShopService
var _purchased: Array = []
var _balances: Array = []
var _order: Array = []
var _failed_reasons: Array = []

## Keeps the envelope in memory; fail_with makes every write fail with that error.
class MemorySaveRepository extends SaveRepository:
	var stored: Dictionary = {}
	var fail_with: Error = OK
	var writes := 0

	func has_data() -> bool:
		return not stored.is_empty()

	func load_data() -> Dictionary:
		last_error = OK if has_data() else ERR_FILE_NOT_FOUND
		return stored.duplicate(true)

	func save_data(envelope: Dictionary) -> Error:
		if fail_with != OK:
			return fail_with
		stored = envelope.duplicate(true)
		writes += 1
		return OK

func _ready() -> void:
	print("\n=======================================================")
	print("          AUTOMATED META SHOP SERVICE RUNNER           ")
	print("=======================================================")

	var real_repository := SaveManager.repository
	var real_data := SaveManager.data.duplicate(true)
	var real_can_write := SaveManager.can_write
	var real_loaded_from := SaveManager.loaded_from
	var real_load_failure := SaveManager.load_failure
	_service = MetaShopService.new()
	add_child(_service)
	EventBus.meta_item_purchased.connect(_on_purchased)
	EventBus.prestige_balance_changed.connect(_on_balance_changed)
	EventBus.save_failed.connect(_on_save_failed)

	test_catalog_four_items()
	test_catalog_matches_shop_screen()
	test_buy_one_level()
	test_not_enough_changes_nothing()
	test_no_level_skip_until_max()
	test_unknown_item_refused()
	test_reentrant_purchase_spends_once()
	test_save_error_rolls_back()
	test_write_blocked_rolls_back()
	test_combat_save_held_rolls_back()
	test_buy_after_run_ended_in_combat()
	test_modifiers_from_levels()
	test_modifiers_defaults_and_cap()
	test_modifiers_feed_run_config()
	test_clamp_levels_above_max_on_load()
	test_clamp_reports_changed_paths()
	# The screens below must find their own service, not this runner's.
	_service.free()
	await test_shop_screen_finds_real_service()
	await test_shop_screen_shows_error_on_failed_save()

	EventBus.meta_item_purchased.disconnect(_on_purchased)
	EventBus.prestige_balance_changed.disconnect(_on_balance_changed)
	EventBus.save_failed.disconnect(_on_save_failed)
	EventBus.state_changed.emit(&"SUMMARY")
	SaveManager.repository = real_repository
	SaveManager.data = real_data
	SaveManager.can_write = real_can_write
	SaveManager.loaded_from = real_loaded_from
	SaveManager.load_failure = real_load_failure

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")

	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)

# ---------------------------------------------------------------------------
# Catalog
# ---------------------------------------------------------------------------

func test_catalog_four_items() -> void:
	print("\n--- Catalog ---")
	var ids: Array = []
	var total_cost := 0
	for item in MetaUpgrades.ITEMS:
		ids.append(item.id)
		for cost in item.costs:
			total_cost += cost
	assert_true(MetaUpgrades.ITEMS.size() == 4, "catalog has four items")
	assert_true(ids == [&"FORT_HP", &"GOLD_PCT", &"CMD_HP", &"EMG_REPAIR"], "catalog ids in shop order")
	assert_true(total_cost == 1720, "all costs add up to 1720")
	assert_true(MetaUpgrades.get_max_levels() == {"FORT_HP": 5, "GOLD_PCT": 4, "CMD_HP": 3, "EMG_REPAIR": 3},
			"max levels follow the cost lists")

func test_catalog_matches_shop_screen() -> void:
	var shop: Node = SHOP_SCENE.instantiate()
	var screen_ids: Array = []
	for item in shop.items:
		screen_ids.append(item.id)
	var catalog_ids: Array = []
	for item in MetaUpgrades.ITEMS:
		catalog_ids.append(item.id)
	shop.free()
	assert_true(screen_ids == catalog_ids, "shop screen lists the catalog items in the same order")

# ---------------------------------------------------------------------------
# Purchase
# ---------------------------------------------------------------------------

func test_buy_one_level() -> void:
	print("\n--- Purchase ---")
	_begin(40)
	var ok := _service.purchase(&"FORT_HP")
	var stored_data: Dictionary = _mem.stored["data"]
	assert_true(ok, "purchase with enough balance succeeds")
	assert_true(_level(&"FORT_HP") == 1 and _balance() == 0, "level raised by one and cost taken")
	assert_true(stored_data["meta"]["levels"]["FORT_HP"] == 1 and stored_data["profile"]["prestige_balance"] == 0,
			"the new level and balance are in the saved copy")
	assert_true(_purchased == [[&"FORT_HP", 1]], "meta_item_purchased sent once with the new level")
	assert_true(_balances == [0], "prestige_balance_changed sent once with the new balance")
	assert_true(_order == [&"purchased", &"balance"], "purchase signal comes before the balance signal")

func test_not_enough_changes_nothing() -> void:
	_begin(39)
	var ok := _service.purchase(&"FORT_HP")
	assert_true(not ok, "purchase below the cost is refused")
	assert_true(_level(&"FORT_HP") == 0 and _balance() == 39, "level and balance unchanged")
	assert_true(_mem.writes == 0, "nothing was written")
	assert_true(_purchased.is_empty() and _balances.is_empty(), "no signal sent")

func test_no_level_skip_until_max() -> void:
	_begin(1000)
	var results: Array = []
	var levels: Array = []
	var balances: Array = []
	for i in 3:
		results.append(_service.purchase(&"CMD_HP"))
		levels.append(_level(&"CMD_HP"))
		balances.append(_balance())
	var writes_at_max := _mem.writes
	var fourth := _service.purchase(&"CMD_HP")
	assert_true(results == [true, true, true], "three purchases up to max succeed")
	assert_true(levels == [1, 2, 3], "level goes up by one each time")
	assert_true(balances == [960, 880, 740], "each level costs its own price")
	assert_true(not fourth, "purchase at max level is refused")
	assert_true(_level(&"CMD_HP") == 3 and _balance() == 740 and _mem.writes == writes_at_max,
			"max level refusal changes and writes nothing")

func test_unknown_item_refused() -> void:
	_begin(1000)
	var ok := _service.purchase(&"STARTER_KIT")
	assert_true(not ok, "an item outside the catalog is refused")
	assert_true(_balance() == 1000 and _mem.writes == 0 and _purchased.is_empty(), "nothing changed or written")

func test_reentrant_purchase_spends_once() -> void:
	_begin(100)
	var nested: Array = []
	var on_purchased := func(_id: StringName, _level_value: int) -> void:
		nested.append(_service.purchase(&"FORT_HP"))
	var on_saved := func() -> void:
		nested.append(_service.purchase(&"FORT_HP"))
	EventBus.meta_item_purchased.connect(on_purchased)
	EventBus.save_completed.connect(on_saved)
	var ok := _service.purchase(&"FORT_HP")
	EventBus.meta_item_purchased.disconnect(on_purchased)
	EventBus.save_completed.disconnect(on_saved)
	assert_true(ok, "the outer purchase succeeds")
	assert_true(nested == [false, false], "purchases started from listeners are refused")
	assert_true(_level(&"FORT_HP") == 1 and _balance() == 60, "the cost is taken only once")

func test_save_error_rolls_back() -> void:
	print("\n--- Failed save ---")
	_begin(100)
	_mem.fail_with = ERR_FILE_CANT_WRITE
	var ok := _service.purchase(&"FORT_HP")
	assert_true(not ok, "purchase fails when the save fails")
	assert_true(_level(&"FORT_HP") == 0 and _balance() == 100, "level and balance are put back")
	assert_true(_failed_reasons == [&"WRITE_ERROR"], "save_failed reported the write error")
	assert_true(_purchased.is_empty(), "no purchase signal after a failed save")
	_mem.fail_with = OK
	assert_true(_service.purchase(&"FORT_HP"), "the next purchase works again")

func test_write_blocked_rolls_back() -> void:
	_begin(100)
	SaveManager.can_write = false
	var ok := _service.purchase(&"FORT_HP")
	SaveManager.can_write = true
	assert_true(not ok, "purchase fails while saving is blocked")
	assert_true(_level(&"FORT_HP") == 0 and _balance() == 100, "level and balance are put back")

func test_combat_save_held_rolls_back() -> void:
	_begin(100)
	EventBus.state_changed.emit(&"COMBAT")
	var ok := _service.purchase(&"FORT_HP")
	var writes_in_combat := _mem.writes
	EventBus.state_changed.emit(&"SUMMARY")
	assert_true(not ok, "purchase fails while the save is held back by combat")
	assert_true(_level(&"FORT_HP") == 0 and _balance() == 100 and writes_in_combat == 0, "nothing changed or written")

func test_buy_after_run_ended_in_combat() -> void:
	_begin(100)
	EventBus.state_changed.emit(&"COMBAT")
	EventBus.run_ended.emit(&"FORTRESS_DESTROYED", {})
	var ok := _service.purchase(&"FORT_HP")
	var stored_data: Dictionary = _mem.stored["data"]
	assert_true(ok, "purchase works right after a run ended in combat")
	assert_true(stored_data["meta"]["levels"]["FORT_HP"] == 1, "the new level is saved at once")

# ---------------------------------------------------------------------------
# Run modifiers
# ---------------------------------------------------------------------------

func test_modifiers_from_levels() -> void:
	print("\n--- Run modifiers ---")
	var mods := MetaUpgrades.get_run_modifiers({"FORT_HP": 2, "GOLD_PCT": 1, "CMD_HP": 3, "EMG_REPAIR": 3})
	var base_fort := MetaUpgrades.FORTRESS_STATS.max_hp
	var base_cmd := MetaUpgrades.COMMANDER_STATS.commander_max_hp
	assert_true(mods.size() == 4, "exactly four values are returned")
	assert_true(mods["fortress_max_hp"] == roundi(base_fort * 1.10), "fortress HP grows by 10 percent at level 2")
	assert_true(is_equal_approx(mods["commander_max_hp"], base_cmd + 30.0), "commander HP grows by 30 at level 3")
	assert_true(is_equal_approx(mods["emg_repair_heal_pct"], GameConfig.emg_repair_base_heal_pct + 0.09)
			and is_equal_approx(mods["emg_repair_heal_pct"], 0.29), "emergency repair heals 29 percent at level 3")
	assert_true(is_equal_approx(mods["gold_pct_meta"], 0.04), "gold bonus is 4 percent at level 1")

func test_modifiers_defaults_and_cap() -> void:
	var base := MetaUpgrades.get_run_modifiers({})
	assert_true(base["fortress_max_hp"] == MetaUpgrades.FORTRESS_STATS.max_hp, "no levels keep the base fortress HP")
	assert_true(is_equal_approx(base["commander_max_hp"], MetaUpgrades.COMMANDER_STATS.commander_max_hp),
			"no levels keep the base commander HP")
	assert_true(is_equal_approx(base["emg_repair_heal_pct"], GameConfig.emg_repair_base_heal_pct),
			"no levels keep the base repair heal")
	assert_true(is_equal_approx(base["gold_pct_meta"], 0.0), "no levels give no gold bonus")
	var capped := MetaUpgrades.get_run_modifiers({"FORT_HP": 9})
	assert_true(capped["fortress_max_hp"] == 1250, "levels above max count as max")

func test_modifiers_feed_run_config() -> void:
	var mods := MetaUpgrades.get_run_modifiers({"FORT_HP": 2, "GOLD_PCT": 1, "CMD_HP": 3, "EMG_REPAIR": 3})
	var cfg := RunConfig.create_default(0, mods)
	assert_true(cfg.fortress_max_hp == mods["fortress_max_hp"], "RunConfig takes the fortress HP")
	assert_true(is_equal_approx(cfg.commander_max_hp, mods["commander_max_hp"]), "RunConfig takes the commander HP")
	assert_true(is_equal_approx(cfg.emg_repair_heal_pct, mods["emg_repair_heal_pct"]), "RunConfig takes the repair heal")
	assert_true(is_equal_approx(cfg.gold_pct_meta, mods["gold_pct_meta"]), "RunConfig takes the gold bonus")

# ---------------------------------------------------------------------------
# Clamp on load
# ---------------------------------------------------------------------------

func test_clamp_levels_above_max_on_load() -> void:
	print("\n--- Clamp on load ---")
	_begin(0)
	var stored_data := SaveManager.DEFAULT_DATA.duplicate(true)
	stored_data["meta"]["levels"] = {"FORT_HP": 9, "GOLD_PCT": -2, "CMD_HP": 3, "EMG_REPAIR": 4, "SLOT_ACTIVE": 7}
	_mem.stored = {"save_version": 1, "checksum": SaveChecksum.compute(stored_data), "data": stored_data}
	SaveManager.load_save()
	var levels: Dictionary = SaveManager.get_section(SaveManager.META)["levels"]
	assert_true(levels["FORT_HP"] == 5 and levels["EMG_REPAIR"] == 3, "levels above max are set to max")
	assert_true(levels["GOLD_PCT"] == 0 and levels["CMD_HP"] == 3, "negative set to 0, level at max kept")
	assert_true(levels["SLOT_ACTIVE"] == 7, "an upgrade outside the catalog is left alone")

func test_clamp_reports_changed_paths() -> void:
	var d := SaveManager.DEFAULT_DATA.duplicate(true)
	d["meta"]["levels"] = {"FORT_HP": 9, "CMD_HP": 3}
	var changed := SaveManager._clamp_values(d)
	assert_true("meta.levels.FORT_HP" in changed, "the clamped level is reported")
	assert_true(not "meta.levels.CMD_HP" in changed, "a level at max is not reported")

# ---------------------------------------------------------------------------
# Shop screen
# ---------------------------------------------------------------------------

func test_shop_screen_finds_real_service() -> void:
	print("\n--- Shop screen ---")
	_begin(40)
	var shop: Node = SHOP_SCENE.instantiate()
	add_child(shop)
	var found := get_tree().get_first_node_in_group(MetaShopService.GROUP)
	assert_true(found is MetaShopService and found.get_parent() == shop, "the screen's own service is found")
	await shop._buy(0)
	var error_label: Label = shop.get_node("%ErrorLabel")
	assert_true(shop.get_level(&"FORT_HP") == 1 and shop.get_balance() == 0, "buying from the screen raises the level")
	assert_true(not error_label.visible, "no error is shown after a good purchase")
	shop.queue_free()
	await get_tree().process_frame
	assert_true(get_tree().get_first_node_in_group(MetaShopService.GROUP) == null, "the service leaves with the screen")

func test_shop_screen_shows_error_on_failed_save() -> void:
	_begin(100)
	_mem.fail_with = ERR_FILE_CANT_WRITE
	var shop: Node = SHOP_SCENE.instantiate()
	add_child(shop)
	await shop._buy(0)
	var error_label: Label = shop.get_node("%ErrorLabel")
	assert_true(shop.get_level(&"FORT_HP") == 0 and shop.get_balance() == 100, "a failed save leaves the screen's values")
	assert_true(error_label.visible, "the error is shown")
	shop.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Fresh in-memory save with the given prestige balance and no signal records.
func _begin(balance: int) -> void:
	EventBus.state_changed.emit(&"SUMMARY")
	_mem = MemorySaveRepository.new()
	SaveManager.set_repository(_mem)
	SaveManager.load_save()
	SaveManager.get_section(SaveManager.PROFILE)["prestige_balance"] = balance
	_purchased.clear()
	_balances.clear()
	_order.clear()
	_failed_reasons.clear()

func _level(item_id: StringName) -> int:
	return int(SaveManager.get_section(SaveManager.META)["levels"].get(String(item_id), 0))

func _balance() -> int:
	return int(SaveManager.get_section(SaveManager.PROFILE)["prestige_balance"])

func _on_purchased(item_id: StringName, new_level: int) -> void:
	_purchased.append([item_id, new_level])
	_order.append(&"purchased")

func _on_balance_changed(value: int) -> void:
	_balances.append(value)
	_order.append(&"balance")

func _on_save_failed(reason: StringName) -> void:
	_failed_reasons.append(reason)

func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		failed_names.append(test_name)
		printerr("  [FAIL] %s" % test_name)
