class_name HealStationPanel
extends PanelContainer
## Heal station: rows for the HP store, the heal rate and the level, then Upgrade and Sell.
## Store changes arrive through EventBus; polling refreshes the other tower actions.

signal closed

const CONFIRM_DIALOG := preload("res://ui/screens/confirm_dialog.tscn")
const BUTTON_LOCK_TIME := 0.15
const REFRESH_INTERVAL := 0.2

## Base heal rate and heal range of the commander at a station.
@export var commander_stats: CharacterStats = preload("res://data/config/commander_stats.tres")

var slot_id: StringName = &""
var _locked := false
var _next_refresh := 0.0
var _transaction_dialog: Control = null
var _heal_rate := 0.0
var _info: Dictionary = {}
var _in_prep := false

@onready var _title: Label = %Title
@onready var _close: Button = %CloseButton
@onready var _store_row: SummaryRow = %StoreRow
@onready var _store_bar: ProgressBar = %StoreBar
@onready var _rate_row: SummaryRow = %RateRow
@onready var _level_row: SummaryRow = %LevelRow
@onready var _upgrade: PanelButton = %Upgrade
@onready var _sell: PanelButton = %Sell

func _ready() -> void:
	_heal_rate = commander_stats.heal_rate_base
	%TitleIcon.texture = preload("res://art/icons/heal_station_icon.png")
	%TitleIcon.show()

	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(closed.emit)
	_upgrade.focus_mode = Control.FOCUS_NONE
	_upgrade.pressed.connect(_on_upgrade_pressed)
	_sell.tooltip_text = tr(&"panel.heal.sell_tip")
	_sell.pressed.connect(_on_sell_pressed)
	EventBus.state_changed.connect(_on_any_change)
	EventBus.gold_changed.connect(_on_any_change)
	EventBus.pause_changed.connect(_on_any_change)
	EventBus.mode_changed.connect(_on_any_change)
	EventBus.heal_tower_hp_changed.connect(_on_store_changed)
	EventBus.heal_status_updated.connect(_on_heal_status_updated)

## A transaction dialog never outlives the panel or the station it was opened for.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_cancel_transaction_dialog()

func open(id: StringName) -> void:
	if id != slot_id:
		_cancel_transaction_dialog()
	slot_id = id
	refresh()

func get_heal_range() -> float:
	return commander_stats.heal_range

func _process(_delta: float) -> void:
	if visible and TimeManager.real_time >= _next_refresh:
		refresh()

func refresh() -> void:
	_next_refresh = TimeManager.real_time + REFRESH_INTERVAL
	var service := _service()
	if service == null or slot_id == &"":
		return
	var info := service.get_tower_info(slot_id)
	if info.is_empty():
		return
	show_info(info, service.is_prep())

## Kept apart from refresh so the test scene can draw it without a BuildService.
## Sell exists only in PREP, like on the Tower panel, except a broken station that shows why.
func show_info(info: Dictionary, in_prep: bool) -> void:
	_info = info
	_in_prep = in_prep
	_title.text = tr((info.data as TowerData).display_name)
	_store_row.set_row(tr(&"panel.heal.store"), UiFormat.tr_fmt(&"hud.ratio", {"value": info.hp, "max": info.max_hp}))
	_store_bar.max_value = maxi(1, info.max_hp)
	_store_bar.value = info.hp
	_show_heal_rate()
	_level_row.set_row(tr(&"panel.heal.level"), UiFormat.tr_fmt(&"panel.heal.level_value",
		{"level": info.level, "max": GameConfig.tower_max_level, "tier": UiFormat.model_tier(info.level)}))
	_upgrade.visible = in_prep
	_show_upgrade(info)
	# An empty store keeps the button in place, greyed out, so the panel never jumps.
	var broken: bool = info.hp <= 0
	_sell.visible = in_prep or broken
	_sell.disabled = broken
	if broken:
		_sell.set_lines(tr(&"panel.heal.broken"))
	else:
		_sell.set_lines(UiFormat.tr_fmt(&"panel.tower.sell", {"gold": info.sell_value}))

## Same rules as the Tower panel: MAX at the top level, grey while the Commander level is too low.
func _show_upgrade(info: Dictionary) -> void:
	if info.is_max:
		_upgrade.disabled = true
		_upgrade.tooltip_text = ""
		_upgrade.set_lines(tr(&"panel.max"))
	elif info.upgrade_locked:
		var need := UiFormat.tr_fmt(&"panel.need_commander_level", {"level": info.upgrade_required_level})
		_upgrade.disabled = true
		_upgrade.tooltip_text = need
		_upgrade.set_lines(need)
	else:
		var short: bool = info.upgrade_shortfall > 0
		_upgrade.disabled = short
		_upgrade.tooltip_text = tr(&"panel.heal.upgrade_tip")
		_upgrade.set_lines(
			UiFormat.tr_fmt(&"panel.tower.upgrade", {"gold": info.upgrade_cost}),
			UiFormat.tr_fmt(&"panel.need_gold", {"gold": info.upgrade_shortfall}) if short else "")

func _on_upgrade_pressed() -> void:
	if not _try_lock() or is_instance_valid(_transaction_dialog):
		return
	var service := _service()
	if service == null or not service.can_upgrade(slot_id):
		return
	var dialog := CONFIRM_DIALOG.instantiate()
	dialog.setup_upgrade(service, slot_id)
	if ScreenManager.open_dialog(dialog):
		_transaction_dialog = dialog

## Selling always asks first. The dialog re-checks PREP and the station when confirmed,
## and closes by itself as a cancel when PREP ends.
func _on_sell_pressed() -> void:
	if not _try_lock() or is_instance_valid(_transaction_dialog):
		return
	var service := _service()
	if service == null:
		return
	var info := service.get_tower_info(slot_id)
	if info.is_empty():
		return
	var id := slot_id
	var dialog := CONFIRM_DIALOG.instantiate()
	dialog.setup(&"dialog.sell.title", &"dialog.sell.body",
		{"name": tr((info.data as TowerData).display_name), "level": info.level, "gold": info.sell_value},
		true, func() -> bool: return service.is_prep() and not service.get_tower_info(id).is_empty())
	dialog.confirmed.connect(func(): service.sell(id))
	if ScreenManager.open_dialog(dialog):
		_transaction_dialog = dialog
	else:
		dialog.queue_free()

func _cancel_transaction_dialog() -> void:
	if is_instance_valid(_transaction_dialog):
		_transaction_dialog.cancel()
	_transaction_dialog = null

func _show_heal_rate() -> void:
	_rate_row.set_row(tr(&"panel.heal.rate"),
		UiFormat.tr_fmt(&"panel.heal.rate_value", {"rate": UiFormat.decimal(_heal_rate, 0)}))

func _on_heal_status_updated(_state: StringName, _reason: StringName, _progress: float,
		_remaining: float, rate: float, _alive: int, _total: int) -> void:
	if not is_inside_tree():
		return
	var next_rate := rate if rate > 0.0 else commander_stats.heal_rate_base
	if is_equal_approx(next_rate, _heal_rate):
		return
	_heal_rate = next_rate
	if visible:
		_show_heal_rate()

func _on_store_changed(id: StringName, new_hp: int, new_max_hp: int) -> void:
	if not is_inside_tree() or not visible or id != slot_id:
		return
	var service := _service()
	var info := service.get_tower_info(slot_id) if service != null else {}
	if info.is_empty():
		if _info.is_empty():
			return
		info = _info.duplicate()
		info["hp"] = new_hp
		info["max_hp"] = new_max_hp
	_next_refresh = TimeManager.real_time + REFRESH_INTERVAL
	show_info(info, service.is_prep() if service != null else _in_prep)

func _on_any_change(_value: Variant) -> void:
	if visible:
		refresh()

func _try_lock() -> bool:
	if _locked:
		return false
	_locked = true
	_unlock_later()
	return true

func _unlock_later() -> void:
	await TimeManager.wait_real(BUTTON_LOCK_TIME)
	_locked = false

func _service() -> BuildService:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"build_service") as BuildService
