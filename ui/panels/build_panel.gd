class_name BuildPanel
extends PanelContainer

signal closed
signal preview_requested(slot_id: StringName, radius: float)
signal preview_cleared

const BUTTON_LOCK_TIME := 0.15

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

func _make_button(opt: Dictionary) -> Button:
	var data: TowerData = opt.data
	var lv: TowerLevelData = data.levels[opt.level - 1]
	var key := &"panel.build.rebuild" if opt.rebuild else &"panel.build.item"
	var b := Button.new()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override(&"font_size", 30)
	b.custom_minimum_size = Vector2(0, 72)
	b.text = UiFormat.tr_fmt(key, {"name": tr(data.display_name), "level": opt.level, "gold": opt.cost})
	if opt.shortfall > 0:
		b.disabled = true
		b.text += "\n" + UiFormat.tr_fmt(&"panel.need_gold", {"gold": opt.shortfall})
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
