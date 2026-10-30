extends Node
## Game clock: speed x1/x2/x3 and Pause.
##
## Game time is Engine.time_scale plus SceneTree.paused, so _process/_physics_process
## deltas, Tween, Timer and particles follow it automatically. Gameplay timers must use
## game time, never wall-clock tick counters.
##
## Three clocks:
##   game time           scaled by time_scale, stops on Pause
##   pausable real time  not scaled, stops on Pause
##   real time           not scaled, never stops (UI, camera)
##
## Speed is changed only through this API, there is no hotkey.

const SCALE_MIN := 1
const SCALE_MAX := 3

const REASON_USER := &"USER"
const REASON_REWARD_PICK := &"REWARD_PICK"
const REASONS: Array[StringName] = [REASON_USER, REASON_REWARD_PICK]

var game_time: float = 0.0
var pausable_real_time: float = 0.0
var real_time: float = 0.0

var _time_scale: int = SCALE_MIN
var _pause_requests: Dictionary = {}  # used as a set

var is_paused: bool:
	get:
		return not _pause_requests.is_empty()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: StringName) -> void:
	if new_state == &"BOSS_INTRO" or new_state == &"SUMMARY" or new_state == &"REWARD_PICK":
		reset_time_scale()

func _process(delta: float) -> void:
	# delta is already multiplied by Engine.time_scale.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	real_time += real_delta
	# Checks the tree, not is_paused, so a pause set outside TimeManager also stops the clocks.
	if not get_tree().paused:
		pausable_real_time += real_delta
		game_time += delta

func get_time_scale() -> int:
	return _time_scale

## Returns false and changes nothing when paused or when level is not 1..3.
func set_time_scale(level: int) -> bool:
	if is_paused or level < SCALE_MIN or level > SCALE_MAX:
		return false
	_apply_time_scale(level)
	return true

## HUD button behaviour: an inactive level turns on, the active level turns off (x1).
func toggle_time_scale(level: int) -> bool:
	if level == SCALE_MIN or level == _time_scale:
		return set_time_scale(SCALE_MIN)
	return set_time_scale(level)

## Back to x1 even while paused, for automatic resets on state changes.
func reset_time_scale() -> void:
	_apply_time_scale(SCALE_MIN)

func request_pause(reason: StringName) -> void:
	if not REASONS.has(reason):
		push_warning("TimeManager: unknown pause reason '%s'" % reason)
		return
	var was_paused := is_paused
	_pause_requests[reason] = true
	if not was_paused:
		_apply_pause(true)

## The game resumes only when no reason is left.
func release_pause(reason: StringName) -> void:
	if not _pause_requests.erase(reason):
		return
	if not is_paused:
		_apply_pause(false)

func has_pause_reason(reason: StringName) -> bool:
	return _pause_requests.has(reason)

func reset_clocks() -> void:
	game_time = 0.0
	pausable_real_time = 0.0

## Used when leaving a run: drops every pause reason, back to x1, zeroes the clocks.
func reset() -> void:
	_pause_requests.clear()
	_apply_pause(false)
	_apply_time_scale(SCALE_MIN)
	reset_clocks()

## Scaled by time_scale, frozen by Pause.
func wait_game(seconds: float) -> Signal:
	return get_tree().create_timer(seconds, false).timeout

## Ignores time_scale, frozen by Pause.
func wait_pausable_real(seconds: float) -> Signal:
	return get_tree().create_timer(seconds, false, false, true).timeout

## Ignores both time_scale and Pause.
func wait_real(seconds: float) -> Signal:
	return get_tree().create_timer(seconds, true, false, true).timeout

func _apply_time_scale(level: int) -> void:
	if level == _time_scale:
		return
	_time_scale = level
	Engine.time_scale = float(level)
	EventBus.time_scale_changed.emit(level)

func _apply_pause(paused: bool) -> void:
	if get_tree().paused == paused:
		return
	get_tree().paused = paused
	EventBus.pause_changed.emit(paused)
