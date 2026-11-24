class_name TowerPanel
extends PanelContainer
## Info and actions for the selected tower. Tower HP has no EventBus signal, so the
## panel polls the service on real time while it is open.

signal closed

const CONFIRM_DIALOG := preload("res://ui/screens/confirm_dialog.tscn")
const BUTTON_LOCK_TIME := 0.15
const REFRESH_INTERVAL := 0.2
const SMALL_FONT_SIZE := 21
## Fixed so the panel never changes height between "enough gold", "missing gold" and MAX.
const UPGRADE_HEIGHT := 110

var slot_id: StringName = &""
var _locked := false
var _next_refresh := 0.0
var _transaction_dialog: Control = null

var _level: Label
var _hp: Label
var _hp_bar: ProgressBar
var _metrics: HBoxContainer
var _damage_icon := preload("res://ui/hud/parts/damage_type_icon.gd").new()
var _damage: Label
var _range_metric: Label
var _rate: Label
var _upgrade: PanelButton
var _sell: PanelButton

@onready var _title: Label = %Title
@onready var _body: VBoxContainer = %Body
@onready var _close: Button = %CloseButton
@onready var _priority: PriorityPanel = %PriorityPanel

func _ready() -> void:

	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(closed.emit)
	_build_body()
	_priority.changed.connect(refresh)
	EventBus.state_changed.connect(_on_any_change)
	EventBus.gold_changed.connect(_on_any_change)
	EventBus.pause_changed.connect(_on_any_change)
	EventBus.mode_changed.connect(_on_any_change)

## A transaction dialog never outlives the panel or the tower it was opened for.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_cancel_transaction_dialog()

func open(id: StringName) -> void:
	if id != slot_id:
		_cancel_transaction_dialog()
	slot_id = id
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
	_level.text = UiFormat.tr_fmt(&"panel.tower.level_tier", {"level": info.level, "tier": UiFormat.model_tier(info.level)})
	_hp.text = UiFormat.tr_fmt(&"panel.tower.hp", {"value": info.hp, "max": info.max_hp})
	%TitleIcon.texture = BuildPanel.TOWER_ICONS.get(data.id)
	%TitleIcon.visible = %TitleIcon.texture != null
	_hp_bar.max_value = maxi(1, info.max_hp)
	_hp_bar.value = info.hp
	_metrics.visible = lv.attack_range > 0
	_damage_icon.damage_type = data.damage_type
	_damage_icon.tooltip_text = tr("damage." + str(Enums.DamageType.keys()[data.damage_type]).to_lower())
	_damage.tooltip_text = UiFormat.tr_fmt(&"tower.stat.damage_type", {"type": _damage_icon.tooltip_text})
	_damage_icon.tooltip_text = _damage.tooltip_text
	_damage.text = str(lv.damage)
	_range_metric.text = UiFormat.tr_fmt(&"tower.range_m", {"value": UiFormat.decimal(lv.attack_range)})
	_rate.text = UiFormat.tr_fmt(&"tower.rate_s", {"value": UiFormat.decimal(lv.fire_rate)})

	# Upgrade and sell exist only in PREP.
	var in_prep := service.is_prep()
	_upgrade.visible = in_prep
	_sell.visible = in_prep
	_upgrade.tooltip_text = ""
	if info.is_max:
		_upgrade.disabled = true
		_upgrade.set_lines(tr(&"panel.max"))
	elif info.upgrade_locked:
		# Grey until the Commander reaches the level the next model tier asks for.
		var need := UiFormat.tr_fmt(&"panel.need_commander_level", {"level": info.upgrade_required_level})
		_upgrade.disabled = true
		_upgrade.tooltip_text = need
		_upgrade.set_lines(need)
	else:
		var short: bool = info.upgrade_shortfall > 0
		_upgrade.disabled = short
		_upgrade.set_lines(
			UiFormat.tr_fmt(&"panel.tower.upgrade", {"gold": info.upgrade_cost}),
			UiFormat.tr_fmt(&"panel.need_gold", {"gold": info.upgrade_shortfall}) if short else "")
	var details := _stats_text(lv, next)
	_upgrade.tooltip_text = details if _upgrade.tooltip_text.is_empty() else _upgrade.tooltip_text + "\n" + details
	var sell_locked := _sell_locked_until(service, slot_id)
	_sell.disabled = sell_locked > 0
	if sell_locked > 0:
		_sell.set_lines(UiFormat.tr_fmt(&"panel.tower.sell_locked", {"wave": sell_locked}))
	else:
		_sell.set_lines(UiFormat.tr_fmt(&"panel.tower.sell", {"gold": info.sell_value}))
	_priority.refresh(slot_id, info, service)

## Wave until which the starter tower on this slot cannot be sold, 0 when it can.
func _sell_locked_until(service: BuildService, id: StringName) -> int:
	return service.get_sell_locked_until_wave(id)

## The "next level" line is kept at MAX so the buttons below never move up.
func _stats_text(cur: TowerLevelData, next: TowerLevelData) -> String:
	var lines := PackedStringArray([UiFormat.tr_fmt(&"panel.stats", {"damage": cur.damage,
		"range": UiFormat.decimal(cur.attack_range), "rate": UiFormat.decimal(cur.fire_rate),
		"hp": cur.max_hp})])
	if next != null:
		lines.append(UiFormat.tr_fmt(&"panel.tower.next", {"damage": next.damage,
			"range": UiFormat.decimal(next.attack_range), "rate": UiFormat.decimal(next.fire_rate),
			"hp": next.max_hp}))
	else:
		lines.append(tr(&"panel.tower.next_max"))
	return "\n".join(lines)

func _build_body() -> void:
	_body.add_theme_constant_override(&"separation", 8)
	var line := HBoxContainer.new()
	_body.add_child(line)
	_level = _add_label(line)
	_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp = _add_label(line)
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size.y = 8
	_body.add_child(_hp_bar)
	_metrics = HBoxContainer.new()
	_body.add_child(_metrics)
	_damage = _metric_value(_damage_icon, &"tower.stat.damage")
	_range_metric = _metric_value(_metric_icon(preload("res://ui/panels/stat_range.svg")), &"tower.stat.range")
	_rate = _metric_value(_metric_icon(preload("res://ui/panels/stat_rate.svg")), &"tower.stat.rate")
	_upgrade = PanelButton.new()
	_upgrade.height = UPGRADE_HEIGHT
	_upgrade.tall_height = UPGRADE_HEIGHT
	_upgrade.pressed.connect(_on_upgrade_pressed)
	_body.add_child(_upgrade)
	_sell = PanelButton.new()
	_sell.danger = true
	_sell.pressed.connect(_on_sell_pressed)
	_body.add_child(_sell)

func _metric_icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon

func _metric_value(icon: Control, key: StringName) -> Label:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_metrics.add_child(cell)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	icon.tooltip_text = tr(key)
	cell.add_child(icon)
	var label := _add_label(cell)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.tooltip_text = tr(key)
	return label

func _add_label(parent: Container) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override(&"font_size", SMALL_FONT_SIZE)
	parent.add_child(label)
	return label

func _on_upgrade_pressed() -> void:
	if _upgrade.disabled or ScreenManager.has_dialog():
		return
	var service := _service()
	if service != null:
		service.upgrade(slot_id)
	refresh()

## Selling always asks first. The dialog re-checks PREP and the tower when confirmed,
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

func _on_any_change(_value: Variant) -> void:
	if is_visible_in_tree():
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
