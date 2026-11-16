class_name RunEndRow
extends PanelContainer
## One line of the run end table: the name with its colon on the left, the value in a rounded pill
## on the right. The pill takes the column colour; a thin line under the row separates it from the next.

@export var accent_color := Color(0.24705882, 0.49803922, 0.8156863, 1)
@export var value_color := Color(0.9490196, 0.9372549, 0.9019608, 1)
@export var value_font_size := 28

@onready var _name: Label = %Name
@onready var _pill: PanelContainer = %Pill
@onready var _value: Label = %Value

func _ready() -> void:
	# Each row keeps its own copy of the pill so one column's colour never changes another.
	var pill := _pill.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	pill.border_color = accent_color
	pill.bg_color = Color(accent_color, 0.18)
	_pill.add_theme_stylebox_override(&"panel", pill)
	_value.add_theme_color_override(&"font_color", value_color)
	_value.add_theme_font_size_override(&"font_size", value_font_size)

func set_row(name_text: String, value_text: String) -> void:
	_name.text = name_text
	_value.text = value_text
