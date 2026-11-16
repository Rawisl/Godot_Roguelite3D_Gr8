class_name NoticeDialog
extends Control
## A system notice laid out for reading at a glance: a coloured mark and title for the tone, short
## lines without trailing punctuation, the numbers in name and value rows, and a small note for
## the detail. Same signals and Esc handling as the shared confirm dialog, so ScreenManager queues
## it the same way. Every line and row is placed in the scene; unused ones stay hidden.

signal confirmed
signal cancelled

const INFO := &"info"
const WARNING := &"warning"
const DANGER := &"danger"
const TONE_COLORS := {
	INFO: Color(0.9098039, 0.7607843, 0.3529412, 1),
	WARNING: Color(1, 0.6039216, 0.18039216, 1),
	DANGER: Color(1, 0.1764706, 0.1764706, 1),
}

var _tone: StringName = INFO
var _title_text := ""
var _lines: Array[String] = []
var _rows: Array = []
var _note_text := ""
var _confirm_key: StringName = &"dialog.ok"
var _cancel_key: StringName = &""
var _closed := false

@onready var _frame: PanelContainer = %Frame
@onready var _glyph: NoticeGlyph = %Glyph
@onready var _title: Label = %Title
@onready var _line_box: VBoxContainer = %Lines
@onready var _row_box: VBoxContainer = %Rows
@onready var _note: Label = %Note
@onready var _cancel_button: Button = %Cancel
@onready var _confirm_button: Button = %Confirm

## rows: [name, value] pairs, names with their colon. Call before the dialog enters the tree.
func setup(tone: StringName, title_key: StringName, lines: Array[String], rows: Array = [], note: String = "") -> void:
	_tone = tone if TONE_COLORS.has(tone) else INFO
	_title_text = tr(title_key)
	_lines = lines
	_rows = rows
	_note_text = note

## An empty cancel_key leaves only the confirm button, as a notice.
func set_buttons(confirm_key: StringName, cancel_key: StringName = &"") -> void:
	_confirm_key = confirm_key
	_cancel_key = cancel_key

func is_notice() -> bool:
	return _cancel_key == &""

func _ready() -> void:
	var color: Color = TONE_COLORS[_tone]
	var box := (_frame.get_theme_stylebox(&"panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	box.border_color = color
	_frame.add_theme_stylebox_override(&"panel", box)
	_glyph.color = color
	_glyph.warning = _tone != INFO
	_title.text = _title_text
	_title.add_theme_color_override(&"font_color", color)
	var labels := _line_box.get_children()
	for i in labels.size():
		(labels[i] as Label).visible = i < _lines.size()
		if i < _lines.size():
			(labels[i] as Label).text = _lines[i]
	var rows := _row_box.get_children()
	_row_box.visible = not _rows.is_empty()
	for i in rows.size():
		var row := rows[i] as Control
		row.visible = i < _rows.size()
		if row.visible:
			# Each row is a panel holding the name and the value labels, in that order.
			var labels_in_row := row.get_child(0).get_children()
			(labels_in_row[0] as Label).text = String(_rows[i][0])
			(labels_in_row[1] as Label).text = String(_rows[i][1])
	_note.visible = _note_text != ""
	_note.text = _note_text
	_confirm_button.text = tr(_confirm_key)
	_cancel_button.text = tr(_cancel_key)
	_cancel_button.visible = not is_notice()
	_cancel_button.pressed.connect(cancel)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	for button: Button in [_cancel_button, _confirm_button]:
		# Hovering moves keyboard focus too, so only one button is ever highlighted.
		button.mouse_entered.connect(button.grab_focus)
	if is_notice():
		_confirm_button.grab_focus()
	else:
		_cancel_button.grab_focus()

func cancel() -> void:
	if _closed:
		return
	_closed = true
	cancelled.emit()
	queue_free()

func _on_confirm_pressed() -> void:
	if _closed:
		return
	_closed = true
	confirmed.emit()
	queue_free()
