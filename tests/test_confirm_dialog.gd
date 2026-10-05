extends Control

## Manual test for ConfirmDialog (SCR-14). Not shipped.
## S: system dialog   X: transaction dialog   E: simulate PREP end (state -> COMBAT)
## V: toggle validate result   Esc: cancel top dialog (via ScreenManager)
## Fake PREP clock logs every second and ends PREP at 0 (rule 1, rule 4).

const DIALOG_SCENE := preload("res://ui/screens/confirm_dialog.tscn")

var _validate_ok: bool = true

## Fake PREP clock (no real wave FSM yet): checks a dialog never pauses
## or slows time (SCR-14 rule 4), and ends PREP at 0 like the real clock (rule 1).
var _fake_prep_left: float = 30.0
var _log_timer: float = 0.0

func _ready() -> void:
	EventBus.alert_requested.connect(_on_alert)
	get_viewport().gui_focus_changed.connect(func(control: Control) -> void:
		print("[test] focus changed -> %s" % control.name))

func _process(delta: float) -> void:
	_fake_prep_left -= delta
	_log_timer += delta
	if _log_timer >= 1.0:
		_log_timer = 0.0
		print("[test] prep_left=%.1f paused=%s time_scale=%s" % [_fake_prep_left, get_tree().paused, Engine.time_scale])
	if _fake_prep_left <= 0.0:
		print("[test] fake PREP ended")
		EventBus.state_changed.emit(&"COMBAT")
		_fake_prep_left = 30.0 

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	print("[test] key=%s" % OS.get_keycode_string(event.keycode))
	var focus := get_viewport().gui_get_focus_owner()
	print("[test] focus now=%s" % (focus.name if focus else "none"))
	match event.keycode:
		KEY_S:
			_open(false)
		KEY_X:
			_open(true)
		KEY_E:
			print("[test] state -> COMBAT")
			EventBus.state_changed.emit(&"COMBAT")
		KEY_V:
			_validate_ok = not _validate_ok
			print("[test] validate_ok=%s" % _validate_ok)

func _open(is_transaction: bool) -> void:
	var dialog := DIALOG_SCENE.instantiate()
	dialog.setup(&"dialog.test.title", &"dialog.test.body", {"gold": 60},
			is_transaction, func() -> bool: return _validate_ok)
	dialog.confirmed.connect(func() -> void: print("[test] confirmed"))
	dialog.cancelled.connect(func() -> void: print("[test] cancelled"))
	if not ScreenManager.open_dialog(dialog):
		print("[test] refused: a dialog is already open")
		return
	var focus := get_viewport().gui_get_focus_owner()
	print("[test] opened transaction=%s, focus=%s" % [is_transaction, focus.name if focus else "none"])

func _on_alert(tier: int, key: StringName, _params: Dictionary) -> void:
	print("[test] alert tier=%d key=%s -> %s" % [tier, key, tr(key)])
