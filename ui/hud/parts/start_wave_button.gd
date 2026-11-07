class_name StartWaveButton
extends Button
## Ends PREP: PREP has no countdown, the player starts the next wave here. Shown only in PREP,
## mouse only (no shortcut, no keyboard focus). Grey with the reason while paused or while a
## transaction dialog is open.

var _in_prep := false
var _paused := false
var _sent := false
var _next_wave := 1
var _next_is_boss := false

## True while the tutorial waits for the first two towers.
var tutorial_lock := false:
	set(value):
		tutorial_lock = value
		_refresh()

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_request)
	EventBus.run_started.connect(_on_run_started)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.wave_started.connect(_on_wave_started)
	# TODO(Ender-Via): send wave_preview_ready in PREP, so the boss label follows the wave script.
	EventBus.wave_preview_ready.connect(_on_wave_preview_ready)
	EventBus.pause_changed.connect(_on_pause_changed)
	_in_prep = GameState.wave_state == &"PREP"
	_set_next_wave(1)
	_refresh()

## A transaction dialog sends no signal, so the lock is checked every frame while the button shows.
func _process(_delta: float) -> void:
	if visible:
		_refresh()

## The signal is handled right away even while the tree is paused, so the lock is checked here too.
func _request() -> void:
	if _sent or _lock_reason() != &"":
		return
	_sent = true
	_refresh()
	EventBus.wave_start_requested.emit()

func _lock_reason() -> StringName:
	if _paused:
		return &"hud.start_wave.paused"
	if ScreenManager.has_transaction_dialog():
		return &"hud.start_wave.dialog"
		# TODO(WhoKeng): the tutorial sets tutorial_lock until both starter towers are built.
	if tutorial_lock:
		return &"hud.start_wave.tutorial"
	return &""

func _set_next_wave(wave: int) -> void:
	_next_wave = wave
	_next_is_boss = wave % GameConfig.boss_wave_interval == 0
	_refresh_text()

func _refresh_text() -> void:
	text = tr(&"hud.start_wave.boss" if _next_is_boss else &"hud.start_wave")

# TODO(WhoKeng): add the small "not in Hazard Trial yet" line once the run tracks it.
func _refresh() -> void:
	visible = _in_prep
	var reason := _lock_reason()
	disabled = _sent or reason != &""
	tooltip_text = tr(reason) if reason != &"" else ""

func _on_run_started() -> void:
	_sent = false
	_set_next_wave(1)

func _on_state_changed(new_state: StringName) -> void:
	_in_prep = new_state == &"PREP"
	_sent = false
	_refresh()

## The wave that just started is done by the next PREP, so the button names the one after it.
func _on_wave_started(wave_index: int) -> void:
	_set_next_wave(wave_index + 1)

func _on_wave_preview_ready(wave_index: int, _composition: Dictionary, is_boss: bool) -> void:
	_next_wave = wave_index
	_next_is_boss = is_boss
	_refresh_text()

func _on_pause_changed(is_paused: bool) -> void:
	_paused = is_paused
	_refresh()
