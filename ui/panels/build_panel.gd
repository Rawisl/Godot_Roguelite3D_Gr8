class_name BuildPanel
extends PanelContainer

signal closed
signal preview_requested(slot_id: StringName, type: StringName, radius: float, blocked: bool)
signal preview_cleared

const BUTTON_LOCK_TIME := 0.15
const TOWER_ICONS := {
	&"arrow": preload("res://art/icons/arrow_icon.png"),
	&"cannon": preload("res://art/icons/cannon_icon.png"),
	&"barricade": preload("res://art/icons/barricade_icon.png"),
	&"heal_station": preload("res://art/icons/heal_station_icon.png"),
}
const LOCK_ICON := preload("res://art/icons/lock_icon.png")
const GOLD_ICON := preload("res://art/icons/gold_icon.png")
const BLOCKS_PATH := &"BLOCKS_PATH"

var slot_id: StringName = &""
var _locked := false

@onready var _title: Label = %Title
@onready var _options: VBoxContainer = %Options
@onready var _close: Button = %CloseButton
@onready var _clear: PanelButton = %ClearRubble

func _ready() -> void:
	_title.text = tr(&"panel.build.title")
	_close.text = tr(&"panel.close")
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(closed.emit)
	_clear.pressed.connect(_on_clear_pressed)
	EventBus.gold_changed.connect(_on_gold_changed)
	_options.add_theme_constant_override(&"separation", 6)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.add_theme_font_size_override(&"font_size", 30)

func open(id: StringName) -> void:
	slot_id = id
	refresh()

## Offer the old tower first on ruined ground.
func refresh() -> void:
	preview_cleared.emit()
	for child in _options.get_children():
		child.queue_free()
	_clear.visible = false
	var service := _service()
	if service == null or slot_id == &"":
		return
	var fresh: Array[Dictionary] = []
	var rebuild: Array[Dictionary] = []
	for opt in service.get_build_options(slot_id):
		if opt.rebuild:
			rebuild.append(opt)
		else:
			fresh.append(opt)
	for opt in rebuild + fresh:
		_options.add_child(_make_button(opt))
	# Clearing the rubble of a destroyed tower is free and sits at the end of the menu.
	_clear.visible = _is_ruined(service)
	if _clear.visible:
		_clear.set_lines(tr(&"panel.build.clear_rubble"))

func _is_ruined(service: BuildService) -> bool:
	var slot := service.find_slot(slot_id)
	return slot != null and slot.state == Enums.SlotState.RUINED

func _on_clear_pressed() -> void:
	if _locked:
		return
	_lock()
	var service := _service()
	if service != null:
		service.clear_rubble(slot_id)
	refresh()

func _make_button(opt: Dictionary) -> Button:
	var data: TowerData = opt.data
	var lv: TowerLevelData = data.levels[opt.level - 1]

	var reason: StringName = opt.locked_reason
	var short: bool = opt.shortfall > 0
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 52
	b.disabled = short or reason != &""
	var warning := ""
	if reason != &"":
		warning = _reason_text(reason)
	elif short:
		warning = UiFormat.tr_fmt(&"panel.need_gold", {"gold": opt.shortfall})
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 10)
	b.add_child(row)
	_add_icon(row, TOWER_ICONS.get(data.id), 38)
	var name_label := Label.new()
	name_label.text = UiFormat.tr_fmt(&"panel.build.rebuild_name", {"name": tr(data.display_name), "level": opt.level}) if opt.rebuild else tr(data.display_name)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	if b.disabled:
		_add_icon(row, LOCK_ICON, 20)
	_add_icon(row, GOLD_ICON, 24)
	var price := Label.new()
	price.text = str(opt.cost)
	row.add_child(price)
	for label: Label in [name_label, price]:
		label.add_theme_font_size_override(&"font_size", 22)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override(&"font_color", Color("#e2dfd8") if b.disabled else b.get_theme_color(&"font_color", &"Button"))
	b.tooltip_text = warning if not warning.is_empty() else UiFormat.tr_fmt(&"panel.stats", {
		"damage": lv.damage, "range": UiFormat.decimal(lv.attack_range),
		"rate": UiFormat.decimal(lv.fire_rate), "hp": lv.max_hp})
	b.pressed.connect(_on_build_pressed.bind(data.id, opt.level))
	b.mouse_entered.connect(func(): preview_requested.emit(slot_id, data.id, lv.attack_range, reason == BLOCKS_PATH))
	b.mouse_exited.connect(preview_cleared.emit)
	return b

func _add_icon(row: HBoxContainer, texture: Texture2D, width: int) -> void:
	var image := TextureRect.new()
	image.texture = texture
	image.custom_minimum_size.x = width
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(image)

## Text for each reason from BuildService.get_build_options(). Unknown reasons give no text.
func _reason_text(reason: StringName) -> String:
	match reason:
		&"GROUND_FULL":
			return UiFormat.tr_fmt(&"panel.build.ground_full", {"max": GameConfig.max_ground_buildings})
		&"HEAL_LIMIT":
			return UiFormat.tr_fmt(&"panel.build.heal_limit", {"max": GameConfig.heal_tower_max_count})
		&"BLOCKS_PATH":
			return tr(&"panel.build.blocks_path")
		&"TUTORIAL":
			return tr(&"panel.build.tutorial")
	return ""

func _on_build_pressed(type: StringName, level: int) -> void:
	if _locked:
		return
	_lock()
	var service := _service()
	if service != null:
		service.build(slot_id, type, level)

func _lock() -> void:
	_locked = true
	await TimeManager.wait_real(BUTTON_LOCK_TIME)
	_locked = false

func _on_gold_changed(_gold: int) -> void:
	if visible:
		refresh()

func _service() -> BuildService:
	return get_tree().get_first_node_in_group(&"build_service") as BuildService
