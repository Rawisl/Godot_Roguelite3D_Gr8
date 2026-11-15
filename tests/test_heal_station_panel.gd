extends Control
## Verifies panel state and EventBus updates without a BuildService.
## 1: full store in PREP. 2: half store in PREP. 3: empty store in COMBAT (Sell greyed out as broken).
## The sell values follow the HP left in the store, like get_tower_info() for heal stations.

const DATA: TowerData = preload("res://data/towers/heal_station.tres")
const COMMANDER: PackedScene = preload("res://entities/commander/commander.tscn")

@export var quit_when_done := false
var passes := 0
var fails := 0

@onready var _panel: HealStationPanel = %HealStationPanel

func _ready() -> void:
	_show(300, 300, 48, true)
	var bar := _panel.get_node("%StoreBar") as ProgressBar
	var sell := _panel.get_node("%Sell") as PanelButton
	var upgrade := _panel.get_node("%Upgrade") as PanelButton
	_check(bar.value == 300 and bar.max_value == 300, "HT12 full store")
	_check(sell.visible and not sell.disabled and upgrade.visible, "HT12 PREP actions")
	_panel.slot_id = &"G1"
	EventBus.heal_tower_hp_changed.emit(&"G2", 12, 300)
	_check(bar.value == 300, "HT12 ignores other stations")
	EventBus.heal_tower_hp_changed.emit(&"G1", 150, 300)
	_check(bar.value == 150, "HT12 store signal updates immediately")
	_panel.hide()
	EventBus.heal_tower_hp_changed.emit(&"G1", 100, 300)
	_check(bar.value == 150, "HT12 hidden panel ignores store updates")
	_panel.show()
	_show(0, 300, 0, false)
	_check(bar.value == 0 and sell.visible and sell.disabled and not upgrade.visible,
		"HT12 depleted store disables sell in combat")
	var commander := COMMANDER.instantiate()
	add_child(commander)
	commander.set_physics_process(false)
	commander.stat_block.set_add(&"heal_rate_add", &"test", 15.0)
	commander.get_node("HealChannel/HealStatusReporter")._process(0.0)
	_show(150, 300, 24, true)
	var rate := _panel.get_node("%RateRow").get_node("%Value") as Label
	var channel := commander.get_node("HealChannel") as HealChannel
	_check(is_equal_approx(channel.get_heal_rate(), 25.0), "HT12 skill modifies actual heal rate")
	_check(rate.text == UiFormat.tr_fmt(&"panel.heal.rate_value",
		{"rate": UiFormat.decimal(channel.get_heal_rate(), 0)}), "HT12 panel displays actual heal rate")
	_panel.hide()
	EventBus.heal_status_updated.emit(&"IDLE", &"", 0.0, 0.0, 20.0, 1, 1)
	_panel.show()
	_show(150, 300, 24, true)
	_check(rate.text == UiFormat.tr_fmt(&"panel.heal.rate_value", {"rate": UiFormat.decimal(20.0, 0)}),
		"HT12 hidden panel caches heal rate events")
	commander.free()
	_check(rate.text == UiFormat.tr_fmt(&"panel.heal.rate_value",
		{"rate": UiFormat.decimal(_panel.commander_stats.heal_rate_base, 0)}), "HT12 teardown resets heal rate")
	remove_child(_panel)
	_panel.refresh()
	EventBus.heal_tower_hp_changed.emit(&"G1", 10, 300)
	_check(bar.value == 150, "HT12 detached panel ignores updates safely")
	add_child(_panel)
	_check(not quit_when_done, "HT12 manual preview stays open by default")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	if quit_when_done or "--run-tests" in OS.get_cmdline_user_args():
		get_tree().quit(0 if fails == 0 else 1)

func _check(condition: bool, test_name: String) -> void:
	if condition:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_show(300, 300, 48, true)
		KEY_2:
			_show(150, 300, 24, true)
		KEY_3:
			_show(0, 300, 0, false)

func _show(hp: int, max_hp: int, sell_value: int, in_prep: bool) -> void:
	_panel.show_info({"data": DATA, "level": 1, "hp": hp, "max_hp": max_hp, "sell_value": sell_value,
		"is_max": false, "upgrade_cost": 40, "upgrade_shortfall": 0,
		"upgrade_locked": false, "upgrade_required_level": 0}, in_prep)
