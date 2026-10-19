class_name PanelButton
extends Button
## Button whose text sits in labels, so the warning line (missing gold) can be red
## while the main line keeps the button colour.

const PADDING := 16
const WARNING_COLOR := Color(1.0, 0.1765, 0.1765)
## Darker than WARNING_COLOR so it stays readable on the light button background.
const DANGER_COLOR := Color(0.69, 0.12, 0.12)

@export var font_size := 30
@export var height := 72
@export var tall_height := 110
## Main line in red, for actions that lose something (selling).
@export var danger := false

var _main: Label
var _warning: Label

func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	var lines := VBoxContainer.new()
	lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lines.offset_left = PADDING
	lines.offset_right = -PADDING
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lines)
	_main = _make_label()
	_warning = _make_label()
	lines.add_child(_main)
	lines.add_child(_warning)
	set_lines("")

## Set disabled first: the main line takes the normal or disabled button colour.
## An empty warning hides the second line.
func set_lines(main_text: String, warning_text: String = "") -> void:
	var has_warning := warning_text != ""
	_main.text = main_text
	_warning.text = warning_text
	_warning.visible = has_warning
	custom_minimum_size.y = tall_height if has_warning else height
	var main_color := DANGER_COLOR if danger and not disabled \
		else _button_color(&"font_disabled_color" if disabled else &"font_color")
	_main.add_theme_color_override(&"font_color", main_color)
	_main.add_theme_font_size_override(&"font_size", font_size)
	_warning.add_theme_font_size_override(&"font_size", font_size)
	_warning.add_theme_color_override(&"font_color", WARNING_COLOR)

func _make_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Labels default to the light Label colour, so they borrow the Button colours from the theme.
func _button_color(color_name: StringName) -> Color:
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.has_color(color_name, &"Button"):
		return theme.get_color(color_name, &"Button")
	return Color.WHITE
