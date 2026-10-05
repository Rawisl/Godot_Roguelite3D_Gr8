extends Control

signal confirmed
signal cancelled

var _title_key: StringName
var _body_key: StringName
var _params: Dictionary = {}
var _is_transaction: bool = false
var _validate: Callable = Callable()
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

func _ready() -> void:
	_title.text = tr(_title_key)
	_body.text = tr(_body_key).format(_params)
	_cancel_button.text = tr(&"dialog.cancel")
	_confirm_button.text = tr(&"dialog.confirm")
	_cancel_button.pressed.connect(cancel)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	if _is_transaction:
		EventBus.state_changed.connect(_on_wave_state_changed)
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
	if _is_transaction and _validate.is_valid() and not _validate.call():
		cancel()
		return
	_closed = true
	confirmed.emit()
	queue_free()

func _on_wave_state_changed(new_state: StringName, _old_state: StringName = &"") -> void:
	if new_state == &"PREP":
		return
	# PREP ended: close as cancel and show the toast (SCR-14 rule 1).
	EventBus.alert_requested.emit(Enums.AlertTier.T2, &"toast.prep_over", {})
	cancel()
