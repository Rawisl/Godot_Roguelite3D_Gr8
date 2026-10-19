class_name TowerPanel
extends PanelContainer
## Info and actions for the selected tower. Tower HP has no EventBus signal, so the
## panel polls the service on real time while it is open.

signal closed

const CONFIRM_DIALOG := preload("res://ui/screens/confirm_dialog.tscn")
const BUTTON_LOCK_TIME := 0.15
const REFRESH_INTERVAL := 0.2
const FONT_SIZE := 30
const SMALL_FONT_SIZE := 24
## Fixed so the panel never changes height between "enough gold", "missing gold" and MAX.
const UPGRADE_HEIGHT := 96

var slot_id: StringName = &""
var _locked := false
var _shown_priority: int = -1
var _next_refresh := 0.0
var _sell_dialog: Control = null

var _level: Label
var _hp: Label
var _stats: Label
var _upgrade: PanelButton
var _sell: PanelButton
var _priority_box: VBoxContainer
var _first: Button
var _nearest: Button

@onready var _title: Label = %Title
@onready var _body: VBoxContainer = %Body
@onready var _close: Button = %CloseButton

func _ready() -> void:
	_close.text = tr(&"panel.close")
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(closed.emit)
	_build_body()
	EventBus.state_changed.connect(_on_any_change)
	EventBus.gold_changed.connect(_on_any_change)
	EventBus.pause_changed.connect(_on_any_change)
	EventBus.mode_changed.connect(_on_any_change)
	EventBus.tower_priority_changed.connect(_on_priority_changed)

## A sell dialog never outlives the panel or the tower it was opened for.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_cancel_sell_dialog()

func open(id: StringName) -> void:
	if id != slot_id:
		_cancel_sell_dialog()
	slot_id = id
	_shown_priority = -1
	refresh()

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
	var data: TowerData = info.data
	var lv: TowerLevelData = data.levels[info.level - 1]
	var next: TowerLevelData = null if info.is_max else data.levels[info.level]
	_title.text = tr(data.display_name)
	_level.text = UiFormat.tr_fmt(&"panel.tower.level", {"level": info.level})
	_hp.text = UiFormat.tr_fmt(&"panel.tower.hp", {"value": info.hp, "max": info.max_hp})
	_stats.text = _stats_text(lv, next)

	# Upgrade and sell exist only in PREP.
	var in_prep := service.is_prep()
	_upgrade.visible = in_prep
	_sell.visible = in_prep
	if info.is_max:
		_upgrade.disabled = true
		_upgrade.set_lines(tr(&"panel.max"))
	else:
		var short: bool = info.upgrade_shortfall > 0
		_upgrade.disabled = short
		_upgrade.set_lines(
			UiFormat.tr_fmt(&"panel.tower.upgrade", {"gold": info.upgrade_cost}),
			UiFormat.tr_fmt(&"panel.need_gold", {"gold": info.upgrade_shortfall}) if short else "")
	_sell.disabled = false
	_sell.set_lines(UiFormat.tr_fmt(&"panel.tower.sell", {"gold": info.sell_value}))
	_refresh_priority(service, info)

## Hidden for towers that never shoot, and in combat outside Commander mode.
func _refresh_priority(service: BuildService, info: Dictionary) -> void:
	_priority_box.visible = info.can_target and (service.is_prep() or service.is_commander_mode())
	var can_change := service.can_change_priority()
	for b: Button in [_first, _nearest]:
		b.disabled = not can_change
		b.tooltip_text = "" if can_change else tr(&"panel.priority.paused")
	var current: int = _shown_priority if _shown_priority >= 0 else info.priority
	_first.set_pressed_no_signal(current == Enums.TargetPriority.FIRST)
	_nearest.set_pressed_no_signal(current == Enums.TargetPriority.NEAREST)

## The "next level" line is kept at MAX so the buttons below never move up.
func _stats_text(cur: TowerLevelData, next: TowerLevelData) -> String:
	var text := UiFormat.tr_fmt(&"panel.stats", {"damage": cur.damage,
		"range": UiFormat.decimal(cur.attack_range), "rate": UiFormat.decimal(cur.fire_rate),
		"hp": cur.max_hp})
	if next != null:
		text += "\n" + UiFormat.tr_fmt(&"panel.tower.next", {"damage": next.damage,
			"range": UiFormat.decimal(next.attack_range), "rate": UiFormat.decimal(next.fire_rate),
			"hp": next.max_hp})
	else:
		text += "\n" + tr(&"panel.tower.next_max")
	return text

func _build_body() -> void:
	_body.add_theme_constant_override(&"separation", 8)
	_level = _add_label(FONT_SIZE)
	_hp = _add_label(FONT_SIZE)
	_stats = _add_label(SMALL_FONT_SIZE)
	_upgrade = PanelButton.new()
	_upgrade.height = UPGRADE_HEIGHT
	_upgrade.tall_height = UPGRADE_HEIGHT
	_upgrade.pressed.connect(_on_upgrade_pressed)
	_body.add_child(_upgrade)
	_sell = PanelButton.new()
	_sell.danger = true
	_sell.pressed.connect(_on_sell_pressed)
	_body.add_child(_sell)

	_priority_box = VBoxContainer.new()
	_body.add_child(_priority_box)
	var heading := Label.new()
	heading.text = tr(&"panel.tower.priority")
	heading.add_theme_font_size_override(&"font_size", SMALL_FONT_SIZE)
	_priority_box.add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	_priority_box.add_child(row)
	_first = _make_priority_button(&"panel.priority.first", Enums.TargetPriority.FIRST)
	_nearest = _make_priority_button(&"panel.priority.nearest", Enums.TargetPriority.NEAREST)
	row.add_child(_first)
	row.add_child(_nearest)

func _add_label(font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", font_size)
	_body.add_child(label)
	return label

func _make_priority_button(key: StringName, priority: Enums.TargetPriority) -> Button:
	var b := Button.new()
	b.text = tr(key)
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override(&"font_size", 26)
	b.pressed.connect(_on_priority_pressed.bind(priority))
	return b

func _on_upgrade_pressed() -> void:
	if _try_lock():
		_service().upgrade(slot_id)
		refresh()

## Selling always asks first. The dialog re-checks PREP and the tower when confirmed,
## and closes by itself as a cancel when PREP ends.
func _on_sell_pressed() -> void:
	if not _try_lock() or is_instance_valid(_sell_dialog):
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
		_sell_dialog = dialog
	else:
		dialog.queue_free()

func _cancel_sell_dialog() -> void:
	if is_instance_valid(_sell_dialog):
		_sell_dialog.cancel()
	_sell_dialog = null

func _on_priority_pressed(priority: Enums.TargetPriority) -> void:
	if _try_lock():
		_service().set_priority(slot_id, priority)
	refresh()

func _on_priority_changed(id: StringName, priority: StringName) -> void:
	if id == slot_id:
		_shown_priority = Enums.TargetPriority.get(String(priority), -1)
		refresh()

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
	return get_tree().get_first_node_in_group(&"build_service") as BuildService
