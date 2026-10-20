class_name BuildPanel
extends PanelContainer

signal closed
signal preview_requested(slot_id: StringName, radius: float)
signal preview_cleared

const BUTTON_LOCK_TIME := 0.15
const SECTION_FONT_SIZE := 24

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

## New builds first, then the rebuild of a ruined slot under its own heading.
func refresh() -> void:
	preview_cleared.emit()
	for child in _options.get_children():
		child.queue_free()
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
	_add_section(&"panel.build.section_new", fresh)
	_add_section(&"panel.build.section_rebuild", rebuild)

func _add_section(heading_key: StringName, options: Array[Dictionary]) -> void:
	if options.is_empty():
		return
	if _options.get_child_count() > 0:
		_options.add_child(HSeparator.new())
	var heading := Label.new()
	heading.text = tr(heading_key)
	heading.theme_type_variation = &"DimLabel"
	heading.add_theme_font_size_override(&"font_size", SECTION_FONT_SIZE)
	_options.add_child(heading)
	for opt in options:
		_options.add_child(_make_button(opt))

func _make_button(opt: Dictionary) -> Button:
	var data: TowerData = opt.data
	var lv: TowerLevelData = data.levels[opt.level - 1]
	var key := &"panel.build.rebuild" if opt.rebuild else &"panel.build.item"
	var short: bool = opt.shortfall > 0
	var b := PanelButton.new()
	b.disabled = short
	b.set_lines(
		UiFormat.tr_fmt(key, {"name": tr(data.display_name), "level": opt.level, "gold": opt.cost}),
		UiFormat.tr_fmt(&"panel.need_gold", {"gold": opt.shortfall}) if short else "")
	b.tooltip_text = UiFormat.tr_fmt(&"panel.stats", {
		"damage": lv.damage, "range": UiFormat.decimal(lv.attack_range),
		"rate": UiFormat.decimal(lv.fire_rate), "hp": lv.max_hp})
	b.pressed.connect(_on_build_pressed.bind(data.id, opt.level))
	b.mouse_entered.connect(func(): preview_requested.emit(slot_id, lv.attack_range))
	b.mouse_exited.connect(preview_cleared.emit)
	return b

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
