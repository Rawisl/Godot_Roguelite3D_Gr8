class_name CommanderInput
extends Node
## Commander key handling: resolves same-tick conflicts by priority, keeps a one-slot
## buffer for a command pressed just before the commander can act, and drops held keys
## on context changes so they must be released and pressed again.

## Ordered by priority: Dodge > Skill > Attack > Mode switch. Skills keep slot order.
const COMMANDS: Array[StringName] = [
	&"dodge", &"battle_cry", &"skill_1", &"skill_2", &"skill_3", &"attack", &"mode_switch",
]
const MOVE_ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right"]
## A mode switch is never queued: it is either accepted now or ignored.
const UNBUFFERED: Array[StringName] = [&"mode_switch"]

## How long before the commander can act again a press is still remembered.
var buffer_time: float = 0.15

var _actions: Array[StringName] = []
var _presses: Array[StringName] = []
var _buffered: StringName = &""
# Actions held when the context changed; ignored until released.
var _blocked: Dictionary = {}

func _ready() -> void:
	for action in MOVE_ACTIONS + COMMANDS:
		if InputMap.has_action(action):
			_actions.append(action)
	EventBus.mode_changed.connect(_on_context_changed)
	EventBus.pause_changed.connect(_on_context_changed)

# Using unhandled input means clicks swallowed by UI never reach the commander.
func _unhandled_input(event: InputEvent) -> void:
	for action in _actions:
		if event.is_action_released(action):
			_blocked.erase(action)
		elif event.is_action_pressed(action, false):
			_blocked.erase(action)
			register_press(action)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_held()

func register_press(action: StringName) -> void:
	if COMMANDS.has(action):
		_presses.append(action)

## Movement vector from WASD with the same diagonal normalisation as Input.get_vector.
func get_move_vector() -> Vector2:
	var strength := func(action: StringName) -> float:
		return 0.0 if _blocked.has(action) else Input.get_action_strength(action)
	var vector := Vector2(
			strength.call(&"move_right") - strength.call(&"move_left"),
			strength.call(&"move_down") - strength.call(&"move_up"))
	return vector.limit_length(1.0)

## Returns the command to run this tick, or an empty name. busy_left takes a command and
## returns how many game seconds until the commander can start it (0 when ready).
func next_command(busy_left: Callable) -> StringName:
	_unblock_released()
	var fresh := _highest_priority(_presses)
	_presses.clear()

	var candidate := fresh
	if not _buffered.is_empty() and (fresh.is_empty() or _rank(_buffered) < _rank(fresh)):
		candidate = _buffered
	if candidate.is_empty():
		return &""

	var left: float = busy_left.call(candidate)
	if left <= 0.0:
		_buffered = &""
		return candidate

	# A new press only replaces the buffer when it lands inside the buffer window.
	if candidate == fresh and not UNBUFFERED.has(candidate) and left <= buffer_time:
		_buffered = candidate
	return &""

## Forgets pending presses and the buffered command (stun, death, mode change).
func discard() -> void:
	_presses.clear()
	_buffered = &""

## Ignores every key currently held until it is released.
func clear_held() -> void:
	discard()
	for action in _actions:
		if Input.is_action_pressed(action):
			_blocked[action] = true

func get_buffered() -> StringName:
	return _buffered

func get_blocked() -> Array:
	return _blocked.keys()

func _on_context_changed(_value: Variant) -> void:
	clear_held()

func _unblock_released() -> void:
	for action in _blocked.keys():
		if not Input.is_action_pressed(action):
			_blocked.erase(action)

func _highest_priority(actions: Array[StringName]) -> StringName:
	for command in COMMANDS:
		if actions.has(command):
			return command
	return &""

# Priority class: lower is stronger. Skill slots share a class.
func _rank(command: StringName) -> int:
	match command:
		&"dodge":
			return 0
		&"attack":
			return 2
		&"mode_switch":
			return 3
	return 1
