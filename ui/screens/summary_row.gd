class_name SummaryRow
extends PanelContainer
## One line of the wave summary: name on the left, value on the right.

## Set per instance in the editor to make important rows stand out.
@export var value_color := Color.WHITE
@export var value_font_size := 28

@onready var _name: Label = %Name
@onready var _value: Label = %Value

func _ready() -> void:
	_value.add_theme_color_override(&"font_color", value_color)
	_value.add_theme_font_size_override(&"font_size", value_font_size)

func set_row(name_text: String, value_text: String) -> void:
	_name.text = name_text
	_value.text = value_text
