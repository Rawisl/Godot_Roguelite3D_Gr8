extends Control
## Credits dialog over the main menu: the team, every outside asset with its licence (from
## GameCredits), the thanks line and the Godot Engine licence. The list scrolls up slowly on its
## own; scrolling it by hand (wheel, drag, scroll bar, arrow or page keys) pauses that for a
## moment. With Reduced motion it never scrolls on its own. Close, Back and Esc close it.

const SCROLL_SPEED := 40.0  # px per second
## How long auto scroll waits after the player scrolled by hand.
const RESUME_DELAY := 2.5
const START_DELAY := 1.5
## One arrow key press scrolls this far; page keys scroll one view height.
const KEY_STEP := 60
const HEADING_SIZE := 30
const NAME_SIZE := 24
const NOTE_SIZE := 18

@onready var _title: Label = %Title
@onready var _scroll: ScrollContainer = %Scroll
@onready var _list: VBoxContainer = %List
@onready var _close: Button = %Close
@onready var _back: Button = %Back

var _scroll_pos := 0.0
var _hold := START_DELAY
var _reduced_motion := false


func _ready() -> void:
	_title.text = tr(&"credits.title")
	_back.text = tr(&"menu.back")
	_close.tooltip_text = tr(&"menu.back")
	_close.pressed.connect(close)
	_back.pressed.connect(close)
	for button: Button in [_close, _back]:
		button.mouse_entered.connect(button.grab_focus)
	_reduced_motion = GameState.get_setting(&"reduced_motion", false) == true
	_scroll.get_v_scroll_bar().scrolling.connect(_pause_auto_scroll)
	_scroll.gui_input.connect(_on_scroll_input)
	_build_list()
	_back.grab_focus()


## Esc on the dialog layer calls this through ScreenManager.close_top_dialog.
func cancel() -> void:
	close()


func close() -> void:
	queue_free()


func _process(delta: float) -> void:
	if _reduced_motion:
		return
	if _hold > 0.0:
		_hold = maxf(0.0, _hold - delta)
		_scroll_pos = _scroll.scroll_vertical
		return
	var max_scroll := _max_scroll()
	if _scroll_pos >= max_scroll:
		return
	_scroll_pos = minf(max_scroll, _scroll_pos + SCROLL_SPEED * delta)
	_scroll.scroll_vertical = int(_scroll_pos)


## Arrow and page keys scroll the list; Up and Down never move focus off Back.
func _unhandled_input(event: InputEvent) -> void:
	var step := 0
	if event.is_action_pressed(&"ui_up", true):
		step = -KEY_STEP
	elif event.is_action_pressed(&"ui_down", true):
		step = KEY_STEP
	elif event.is_action_pressed(&"ui_page_up", true):
		step = -int(_scroll.size.y)
	elif event.is_action_pressed(&"ui_page_down", true):
		step = int(_scroll.size.y)
	if step == 0:
		return
	scroll_by(step)
	get_viewport().set_input_as_handled()


## Scrolls the list by hand and pauses auto scroll.
func scroll_by(pixels: int) -> void:
	_scroll.scroll_vertical = clampi(_scroll.scroll_vertical + pixels, 0, int(_max_scroll()))
	_pause_auto_scroll()


func _max_scroll() -> float:
	return maxf(0.0, _list.size.y - _scroll.size.y)


func _on_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventPanGesture or event is InputEventScreenDrag:
		_pause_auto_scroll()


func _pause_auto_scroll() -> void:
	_hold = RESUME_DELAY


func _build_list() -> void:
	_add_label(tr(&"menu.title"), HEADING_SIZE + 10, &"CreditsHeading")
	_add_label(tr(&"credits.subtitle"), NOTE_SIZE, &"DimLabel")
	for section in GameCredits.SECTIONS:
		_add_gap(28)
		_add_label(tr(section.title), HEADING_SIZE, &"CreditsHeading")
		for entry: Dictionary in section.entries:
			_add_gap(8)
			_add_label(_text(entry.name), NAME_SIZE)
			if entry.has("by"):
				_add_label(_text(entry.by), NOTE_SIZE, &"DimLabel")
			var licence := String(entry.get("licence", ""))
			if not licence.is_empty():
				var line := licence if not entry.has("url") else "%s\n%s" % [licence, entry.url]
				_add_label(line, NOTE_SIZE, &"DimLabel")
	_add_gap(40)
	_add_label(tr(&"credits.thanks"), HEADING_SIZE, &"CreditsHeading")
	# The full Godot licence text is long, so it comes after the thanks.
	_add_gap(40)
	_add_label(tr(&"credits.section.engine"), HEADING_SIZE, &"CreditsHeading")
	_add_label(Engine.get_license_text(), NOTE_SIZE - 2, &"DimLabel")
	_add_gap(int(_scroll.custom_minimum_size.y * 0.5))


## Locale keys of the data start with "credits."; names and licences are shown as written.
func _text(value: Variant) -> String:
	var text := String(value)
	return tr(StringName(text)) if text.begins_with("credits.") else text


func _add_label(text: String, font_size: int, variation := &"") -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", font_size)
	if variation != &"":
		label.theme_type_variation = variation
	_list.add_child(label)
	return label


## Spacer that lets the wheel and drags through to the ScrollContainer.
func _add_gap(height: int) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(gap)


## For tests: every line of text the list shows.
func get_text() -> String:
	var lines := PackedStringArray()
	for child in _list.get_children():
		if child is Label:
			lines.append((child as Label).text)
	return "\n".join(lines)
