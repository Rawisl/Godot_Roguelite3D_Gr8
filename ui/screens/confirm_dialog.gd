extends Control
## Shared dialog template: title, the concrete consequence, Cancel (focused by default)
## and Confirm. A notice keeps only the confirm button.
## Transaction dialogs exist only in PREP: they close as a cancel when PREP ends and
## re-check the action at the moment Confirm is pressed.

signal confirmed
signal cancelled

var _title_key: StringName
var _body_key: StringName
var _params: Dictionary = {}
var _is_transaction: bool = false
var _validate: Callable = Callable()
var _confirm_key: StringName = &"dialog.confirm"
var _cancel_key: StringName = &"dialog.cancel"
var _closed: bool = false

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _cancel_button: Button = %Cancel
@onready var _confirm_button: Button = %Confirm

func setup(title_key: StringName, body_key: StringName, params: Dictionary = {},
		is_transaction: bool = false, validate: Callable = Callable()) -> void:
	_title_key = title_key
	_body_key = body_key
	_params = params
	_is_transaction = is_transaction
	_validate = validate

## Custom labels, e.g. Retry and Close. An empty cancel_key leaves only the confirm button.
func set_buttons(confirm_key: StringName, cancel_key: StringName = &"dialog.cancel") -> void:
	_confirm_key = confirm_key
	_cancel_key = cancel_key

## One-button message. Esc closes it like the button does.
func setup_notice(title_key: StringName, body_key: StringName, params: Dictionary = {}) -> void:
	setup(title_key, body_key, params)
	set_buttons(&"dialog.ok", &"")

func is_notice() -> bool:
	return _cancel_key == &""

func is_transaction() -> bool:
	return _is_transaction

func _ready() -> void:
	_title.text = tr(_title_key)
	_body.text = tr(_body_key).format(_params)
	_confirm_button.text = tr(_confirm_key)
	_cancel_button.text = tr(_cancel_key)
	_cancel_button.visible = not is_notice()
	_cancel_button.pressed.connect(cancel)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	for button: Button in [_cancel_button, _confirm_button]:
		# Hovering moves keyboard focus too, so only one button is ever highlighted.
		button.mouse_entered.connect(button.grab_focus)
	if _is_transaction:
		_dock_transaction()
		EventBus.state_changed.connect(_on_wave_state_changed)
	if is_notice():
		_confirm_button.grab_focus()
	else:
		_cancel_button.grab_focus()

## In PREP the transaction stays next to the selected structure.
func _dock_transaction() -> void:
	$Backdrop.hide()
	var holder: CenterContainer = $Center
	var card: PanelContainer = $Center/Panel
	card.add_theme_stylebox_override(&"panel", preload("res://ui/panels/drawer_surface.tres"))
	card.custom_minimum_size = Vector2(460, 180)
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	holder.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	holder.offset_top = -165
	holder.offset_bottom = 165
	var slide := create_tween().set_ignore_time_scale().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide.tween_method(func(right_edge: float) -> void:
		holder.offset_left = right_edge - 460.0
		holder.offset_right = right_edge, 500.0, 0.0, 0.22)

func cancel() -> void:
	if _closed:
		return
	_closed = true
	cancelled.emit()
	queue_free()

func _on_confirm_pressed() -> void:
	if _closed:
		return
	if _is_transaction and _validate.is_valid() and not _validate.call():
		cancel()
		return
	_closed = true
	confirmed.emit()
	queue_free()

func _on_wave_state_changed(new_state: StringName, _old_state: StringName = &"") -> void:
	if new_state == &"PREP":
		return
	# PREP ended: close as cancel and show the toast.
	EventBus.alert_requested.emit(Enums.AlertTier.T2, &"toast.prep_over", {})
	cancel()
