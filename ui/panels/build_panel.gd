class_name BuildPanel
extends PanelContainer

signal closed
signal preview_requested(slot_id: StringName, radius: float)
signal preview_cleared

const BUTTON_LOCK_TIME := 0.15
const FONT_SIZE := 30
const ROW_HEIGHT := 72
const ROW_HEIGHT_SHORT := 110
const ROW_PADDING := 16
const SHORTFALL_COLOR := Color(1.0, 0.1765, 0.1765)

var slot_id: StringName = &""
var _locked := false

@onready var _title: Label = %Title
@onready var _options: VBoxContainer = %Options
@onready var _close: Button = %CloseButton

func _ready() -> void:
	_title.text = tr(&"panel.build.title")
	_close.text = tr(&"panel.close")
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(closed.emit)
	EventBus.gold_changed.connect(_on_gold_changed)
	_options.add_theme_constant_override(&"separation", 10)

func open(id: StringName) -> void:
	slot_id = id
	refresh()

func refresh() -> void:
	preview_cleared.emit()
	for child in _options.get_children():
		child.queue_free()
	var service := _service()
	if service == null or slot_id == &"":
		return
	for opt in service.get_build_options(slot_id):
		_options.add_child(_make_button(opt))

## The text sits in labels inside the button so only the shortfall line can be red.
func _make_button(opt: Dictionary) -> Button:
	var data: TowerData = opt.data
	var lv: TowerLevelData = data.levels[opt.level - 1]
	var key := &"panel.build.rebuild" if opt.rebuild else &"panel.build.item"
	var short: bool = opt.shortfall > 0

	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = short
	b.custom_minimum_size = Vector2(0, ROW_HEIGHT_SHORT if short else ROW_HEIGHT)
	b.tooltip_text = UiFormat.tr_fmt(&"panel.stats", {
		"damage": lv.damage, "range": UiFormat.decimal(lv.attack_range),
		"rate": UiFormat.decimal(lv.fire_rate), "hp": lv.max_hp})

	var lines := VBoxContainer.new()
	lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lines.offset_left = ROW_PADDING
	lines.offset_right = -ROW_PADDING
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lines)

	var name_color := _button_color(&"font_disabled_color" if short else &"font_color")
	lines.add_child(_make_label(UiFormat.tr_fmt(key,
		{"name": tr(data.display_name), "level": opt.level, "gold": opt.cost}), name_color))
	if short:
		lines.add_child(_make_label(UiFormat.tr_fmt(&"panel.need_gold",
			{"gold": opt.shortfall}), SHORTFALL_COLOR))

	b.pressed.connect(_on_build_pressed.bind(data.id, opt.level))
	b.mouse_entered.connect(func(): preview_requested.emit(slot_id, lv.attack_range))
	b.mouse_exited.connect(preview_cleared.emit)
	return b

func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	label.add_theme_color_override(&"font_color", color)
	return label

## Labels default to the light Label colour, so they borrow the Button colours from the theme.
func _button_color(color_name: StringName) -> Color:
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.has_color(color_name, &"Button"):
		return theme.get_color(color_name, &"Button")
	return Color.WHITE

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
