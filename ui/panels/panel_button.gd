class_name PanelButton
extends Button
## Shared drawer actions. Text and glyphs distinguish the action even without colour.

const PADDING := 12
const VERTICAL_PADDING := 8
const PRIMARY_TEXT := Color("#08272a")
const SELL_TEXT := Color("#ffcab9")
const MUTED_TEXT := Color("#cad5d7")

@export var font_size := 24
@export var height := 56
@export var tall_height := 80
@export var glyph_key: StringName = &"panel.glyph.upgrade"
## Sales use a secondary surface and a minus sign.
@export var danger := false

var _mark: Label
var _lines: VBoxContainer
var _main: Label
var _warning: Label

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_theme_stylebox_override(&"disabled", preload("res://ui/panels/drawer_action_disabled.tres"))
	focus_mode = Control.FOCUS_NONE
	_lines = VBoxContainer.new()
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.offset_left = 42
	_lines.offset_right = -PADDING
	_lines.alignment = BoxContainer.ALIGNMENT_CENTER
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lines)
	_main = _make_label()
	_warning = _make_label()
	_lines.add_child(_main)
	_lines.add_child(_warning)
	# Wrapped labels report their real height only once they know their width.
	_lines.minimum_size_changed.connect(_fit_height)
	_mark = Label.new()
	_mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_mark.offset_left = PADDING
	_mark.offset_right = 38
	_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.add_theme_font_size_override(&"font_size", 28)
	add_child(_mark)
	set_lines("")

func _ready() -> void:
	var fill := Color("#432e30") if danger else Color("#86d6bf")
	var edge := Color("#db8e78") if danger else Color("#b8ebd9")
	add_theme_stylebox_override(&"normal", _surface(fill, edge))
	add_theme_stylebox_override(&"hover", _surface(fill.lightened(0.12), edge.lightened(0.12)))
	add_theme_stylebox_override(&"pressed", _surface(fill.darkened(0.17), edge))
	set_lines(_main.text, _warning.text)

func _surface(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.border_width_left = 3
	box.set_corner_radius_all(5)
	return box

## Set disabled first: the main line takes the normal or disabled button colour.
## An empty warning hides the second line.
func set_lines(main_text: String, warning_text: String = "") -> void:
	_main.text = main_text
	_warning.text = warning_text
	_warning.visible = warning_text != ""
	var main_color := SELL_TEXT if danger else PRIMARY_TEXT
	if disabled:
		main_color = MUTED_TEXT
	_mark.text = tr(&"panel.glyph.sell" if danger else glyph_key)
	_mark.add_theme_color_override(&"font_color", main_color)
	_main.add_theme_color_override(&"font_color", main_color)
	_main.add_theme_font_size_override(&"font_size", font_size)
	_warning.add_theme_font_size_override(&"font_size", 18)
	_warning.add_theme_color_override(&"font_color", Color("#e6c696"))
	_fit_height()

func _fit_height() -> void:
	var base := tall_height if _warning.visible else height
	custom_minimum_size.y = maxf(base, _lines.get_combined_minimum_size().y + VERTICAL_PADDING * 2)

func _make_label() -> Label:
	var label := Label.new()
	label.add_theme_font_override(&"font", preload("res://ui/theme/fonts/BeVietnamPro-SemiBold.ttf"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
