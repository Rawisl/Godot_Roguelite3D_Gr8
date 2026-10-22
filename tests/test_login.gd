extends Node
## Manual test for the login overlay. Not shipped.
## Function keys so typing in the fields is not affected:
## F2: next server error code   F3: busy on/off   F4: unknown code
## F7: successful sign in (reloads this scene)   F8: open the form again after closing it

const LOGIN_SCENE := preload("res://ui/screens/login.tscn")
const CODES: Array[StringName] = [&"INVALID_CREDENTIALS", &"EMAIL_TAKEN", &"WEAK_PASSWORD",
	&"EMAIL_NOT_CONFIRMED", &"INVALID_DISPLAY_NAME", &"RATE_LIMITED", &"OFFLINE", &"SERVER",
	&"DISABLED"]

var _next := 0
var _busy := false
var _login: Node

func _ready() -> void:
	_open()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F8:
		_open()
		return
	if not is_instance_valid(_login):
		print("[test] the form is closed, press F8")
		return
	match event.keycode:
		KEY_F2:
			print("[test] error %s" % CODES[_next])
			_login.show_error(CODES[_next])
			_next = (_next + 1) % CODES.size()
		KEY_F3:
			_busy = not _busy
			_login.set_busy(_busy)
		KEY_F4:
			_login.show_error(&"HTTP_418")
		KEY_F7:
			print("[test] signed in, reloading")
			_login.complete_sign_in()

func _open() -> void:
	if is_instance_valid(_login):
		return
	_busy = false
	_login = LOGIN_SCENE.instantiate()
	if not ScreenManager.open_dialog(_login):
		print("[test] another dialog is open")
