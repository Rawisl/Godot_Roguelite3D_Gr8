extends Node
## Manual test for the login screen errors and busy state. Not shipped.
## Function keys so typing in the fields is not affected:
## F2: next server error code   F3: busy on/off   F4: unknown code

const CODES: Array[StringName] = [&"INVALID_CREDENTIALS", &"EMAIL_TAKEN", &"WEAK_PASSWORD",
	&"EMAIL_NOT_CONFIRMED", &"INVALID_DISPLAY_NAME", &"RATE_LIMITED", &"OFFLINE", &"SERVER",
	&"DISABLED"]

var _next := 0
var _busy := false

@onready var _login: Node = $Login

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
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
