extends MarginContainer
## Sign in (the default view) or register, or keep playing as a guest. The form checks
## what it can locally and turns error codes into text; the network calls arrive with
## the auth service.

const MODE_SIGN_IN := &"SIGN_IN"
const MODE_REGISTER := &"REGISTER"
## Palette: ui_alert_t2 for errors, ui_text_dim for the busy line.
const ERROR_COLOR := Color("FF9A2E")
const DIM_COLOR := Color("A9A79F")
## Placeholder icons until the shared icon set has an eye.
const EYE_OPEN: Texture2D = preload("res://ui/icons/eye.svg")
const EYE_CLOSED: Texture2D = preload("res://ui/icons/eye_off.svg")

## Local check results and the auth service error codes, mapped to what the player reads.
const ERROR_KEYS := {
	&"EMPTY": &"login.error.empty",
	&"BAD_EMAIL": &"login.error.bad_email",
	&"NO_NAME": &"login.error.no_name",
	&"MISMATCH": &"login.error.mismatch",
	&"INVALID_CREDENTIALS": &"login.error.invalid_credentials",
	&"EMAIL_TAKEN": &"login.error.email_taken",
	&"WEAK_PASSWORD": &"login.error.weak_password",
	&"EMAIL_NOT_CONFIRMED": &"login.error.email_not_confirmed",
	&"INVALID_DISPLAY_NAME": &"login.error.invalid_display_name",
	&"RATE_LIMITED": &"login.error.rate_limited",
	&"OFFLINE": &"login.error.offline",
	&"SERVER": &"login.error.server",
	&"DISABLED": &"login.error.disabled",
}

var _mode: StringName = MODE_SIGN_IN
var _busy := false

@onready var _back: Button = %Back
@onready var _no_account: Label = %NoAccount
@onready var _open_register: Button = %OpenRegister
@onready var _title: Label = %Title
@onready var _name_row: Control = %NameRow
@onready var _confirm_row: Control = %ConfirmRow
@onready var _name_edit: LineEdit = %NameEdit
@onready var _email_edit: LineEdit = %EmailEdit
@onready var _password_edit: LineEdit = %PasswordEdit
@onready var _confirm_edit: LineEdit = %ConfirmEdit
@onready var _password_eye: Button = %PasswordEye
@onready var _confirm_eye: Button = %ConfirmEye
@onready var _message: Label = %Message
@onready var _submit: Button = %Submit
@onready var _guest: Button = %Guest
@onready var _guest_hint: Label = %GuestHint
@onready var _panel: Control = %Panel

func _ready() -> void:
	_back.text = tr(&"login.back")
	_no_account.text = tr(&"login.no_account")
	_open_register.text = tr(&"login.title.register")
	%NameCaption.text = tr(&"login.field.display_name")
	%EmailCaption.text = tr(&"login.field.email")
	%PasswordCaption.text = tr(&"login.field.password")
	%ConfirmCaption.text = tr(&"login.field.confirm_password")
	_guest.text = tr(&"login.guest")
	_guest_hint.text = tr(&"login.guest_hint")
	_back.pressed.connect(_set_mode.bind(MODE_SIGN_IN))
	_open_register.pressed.connect(_set_mode.bind(MODE_REGISTER))
	for edit in _all_fields():
		edit.text_submitted.connect(_on_field_submitted.bind(edit))
	for pair: Array in [[_password_eye, _password_edit], [_confirm_eye, _confirm_edit]]:
		pair[0].toggled.connect(_on_eye_toggled.bind(pair[0], pair[1]))
		_on_eye_toggled(false, pair[0], pair[1])
	_submit.pressed.connect(_on_submit_pressed)
	_guest.pressed.connect(_play_as_guest)
	_match_view_heights()

## Esc: Register goes back to Sign in, Sign in goes back to MainMenu.
func go_back() -> void:
	if _busy:
		return
	if _mode == MODE_REGISTER:
		_set_mode(MODE_SIGN_IN)
	else:
		_play_as_guest()

func show_error(code: StringName) -> void:
	var key: StringName = ERROR_KEYS.get(code, &"login.error.unknown")
	_show_message(UiFormat.tr_fmt(&"login.error_line", {"message": tr(key)}), ERROR_COLOR)

## While a request runs the form is locked, so a second press cannot send it twice.
func set_busy(busy: bool) -> void:
	_busy = busy
	for edit in _all_fields():
		edit.editable = not busy
	for button: Button in [_back, _open_register, _submit, _guest, _password_eye, _confirm_eye]:
		button.disabled = busy
	if busy:
		_show_message(tr(&"login.busy"), DIM_COLOR)
	else:
		_message.text = ""

## Guests play everything; they only skip cloud save and the leaderboard.
func _play_as_guest() -> void:
	GameState.change_state(GameState.AppState.MAIN_MENU)

func _set_mode(mode: StringName) -> void:
	_mode = mode
	var register := mode == MODE_REGISTER
	_title.text = tr(&"login.title.register" if register else &"login.title.sign_in")
	_back.visible = register
	_no_account.visible = not register
	_open_register.visible = not register
	_name_row.visible = register
	_confirm_row.visible = register
	_guest.visible = not register
	_guest_hint.visible = not register
	_submit.text = tr(&"login.submit.register" if register else &"login.submit.sign_in")
	# Passwords never carry over between the two forms.
	_password_eye.button_pressed = false
	_confirm_eye.button_pressed = false
	_password_edit.clear()
	_confirm_edit.clear()
	_message.text = ""
	_focus_field(_visible_fields()[0])

func _on_submit_pressed() -> void:
	if _busy:
		return
	var problem := _check_fields()
	if not problem.is_empty():
		show_error(problem)
		return
	# TODO: send sign in or sign up through the auth service and show its result.
	show_error(&"DISABLED")

## Only checks that need no server; the server still has the last word.
func _check_fields() -> StringName:
	var mail := _email_edit.text.strip_edges()
	if mail.is_empty() or _password_edit.text.is_empty():
		return &"EMPTY"
	if not _looks_like_email(mail):
		return &"BAD_EMAIL"
	if _mode == MODE_REGISTER:
		# TODO: check the display name length against GameConfig once it has the limits.
		if _name_edit.text.strip_edges().is_empty():
			return &"NO_NAME"
		if _confirm_edit.text != _password_edit.text:
			return &"MISMATCH"
	return &""

func _looks_like_email(text: String) -> bool:
	var at := text.find("@")
	return at > 0 and text.find(".", at) > at + 1 and not text.ends_with(".")

## Enter moves to the next field, and sends the form from the last one.
func _on_field_submitted(_text: String, edit: LineEdit) -> void:
	var fields := _visible_fields()
	var i := fields.find(edit)
	if i < fields.size() - 1:
		_focus_field(fields[i + 1])
	else:
		_on_submit_pressed()

func _all_fields() -> Array[LineEdit]:
	return [_name_edit, _email_edit, _password_edit, _confirm_edit]

func _visible_fields() -> Array[LineEdit]:
	return _all_fields().filter(func(edit: LineEdit) -> bool: return edit.is_visible_in_tree())

func _focus_field(edit: LineEdit) -> void:
	edit.grab_focus()
	edit.edit()

func _show_message(text: String, color: Color) -> void:
	_message.text = text
	_message.add_theme_color_override(&"font_color", color)

func _match_view_heights() -> void:
	_set_mode(MODE_REGISTER)
	await get_tree().process_frame
	var register_height := _panel.size.y
	_set_mode(MODE_SIGN_IN)
	await get_tree().process_frame
	_panel.custom_minimum_size.y = maxf(register_height, _panel.size.y)

func _on_eye_toggled(shown: bool, eye: Button, edit: LineEdit) -> void:
	edit.secret = not shown
	eye.icon = EYE_CLOSED if shown else EYE_OPEN
	eye.tooltip_text = tr(&"login.password.hide" if shown else &"login.password.show")
