extends Node
## Manual test for CommanderInput priority, buffer and held-key blocking. Not shipped.
## Run with F6, prints OK/FAIL per case then quits.

var _pass := 0
var _fail := 0
var _input: CommanderInput
var _busy := 0.0

func _ready() -> void:
	_run()
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func _run() -> void:
	_input = CommanderInput.new()
	add_child(_input)

	# Same-tick priority.
	_press([&"mode_switch", &"attack", &"battle_cry", &"dodge"])
	_check("dodge beats skill, attack and mode switch", _next() == &"dodge")
	_check("losers are dropped", _next() == &"")

	_press([&"attack", &"mode_switch"])
	_check("attack beats mode switch", _next() == &"attack")

	_press([&"skill_3", &"skill_2", &"attack"])
	_check("lower skill slot wins, skill beats attack", _next() == &"skill_2")

	# Buffer window.
	_busy = 0.40
	_press([&"attack"])
	_check("press 0.40 s before ready is not buffered", _next() == &"")
	_busy = 0.0
	_check("and does not fire later", _next() == &"")

	_busy = 0.10
	_press([&"attack"])
	_check("press 0.10 s before ready waits", _next() == &"")
	_check("buffered command is remembered", _input.get_buffered() == &"attack")
	_busy = 0.0
	_check("buffered command fires once ready", _next() == &"attack")
	_check("and only once", _next() == &"")

	# Buffer overwrite.
	_busy = 0.10
	_press([&"attack"])
	_next()
	_press([&"dodge"])
	_next()
	_check("higher priority replaces the buffered command", _input.get_buffered() == &"dodge")
	_press([&"attack"])
	_next()
	_check("lower priority does not replace it", _input.get_buffered() == &"dodge")
	_busy = 0.0
	_check("dodge fires when ready", _next() == &"dodge")

	_busy = 0.10
	_press([&"battle_cry"])
	_next()
	_press([&"battle_cry"])
	_next()
	_check("same priority keeps a single slot", _input.get_buffered() == &"battle_cry")
	_busy = 0.0
	_next()

	# Mode switch is never queued.
	_busy = 0.10
	_press([&"mode_switch"])
	_check("mode switch while busy is ignored", _next() == &"" and _input.get_buffered() == &"")
	_busy = 0.0
	_check("and does not fire later", _next() == &"")

	# Discard.
	_busy = 0.10
	_press([&"attack"])
	_next()
	_input.discard()
	_busy = 0.0
	_check("discard clears the buffer", _next() == &"")

	# Held keys must be released and pressed again after a context change.
	Input.action_press(&"move_up")
	_check("held key moves", _input.get_move_vector().y < 0.0)
	_input.clear_held()
	_check("held key is ignored after clear", _input.get_move_vector() == Vector2.ZERO)
	Input.action_release(&"move_up")
	_next()
	Input.action_press(&"move_up")
	_check("pressing again works", _input.get_move_vector().y < 0.0)
	Input.action_release(&"move_up")

	Input.action_press(&"move_up")
	Input.action_press(&"move_right")
	var diagonal := _input.get_move_vector()
	_check("diagonal is normalised", is_equal_approx(diagonal.length(), 1.0))
	Input.action_release(&"move_up")
	Input.action_release(&"move_right")

	_press([&"attack"])
	EventBus.mode_changed.emit(&"COMMANDER")
	_check("mode change clears pending presses", _next() == &"")

func _press(actions: Array[StringName]) -> void:
	for action in actions:
		_input.register_press(action)

func _next() -> StringName:
	return _input.next_command(func(_command: StringName) -> float: return _busy)

func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("[test] %s %s" % [label, "OK" if ok else "FAIL"])
