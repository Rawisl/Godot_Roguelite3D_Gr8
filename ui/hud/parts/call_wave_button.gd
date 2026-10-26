class_name CallWaveButton
extends Button
## Shown only in PREP. The bonus uses the same formula as the wave manager.

var _in_prep := false
var _paused := false
var _sent := false

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_request)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.prep_timer_changed.connect(_on_prep_timer_changed)
	EventBus.pause_changed.connect(_on_pause_changed)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"call_wave") and _can_call():
		_request()
		get_viewport().set_input_as_handled()

## The signal is handled right away even while the tree is paused, so pausing must block it here.
func _can_call() -> bool:
	return _in_prep and not _paused and not _sent

func _request() -> void:
	if not _can_call():
		return
	_sent = true
	EventBus.early_call_requested.emit()

func _on_state_changed(new_state: StringName) -> void:
	_in_prep = new_state == &"PREP"
	_sent = false
	_refresh()

## Only sent while PREP runs, so it also catches the first PREP that starts before the HUD is ready.
func _on_prep_timer_changed(remaining: float) -> void:
	_in_prep = true
	var bonus := mini(GameConfig.early_call_cap, floori(remaining * GameConfig.early_call_gold_per_sec))
	text = UiFormat.tr_fmt(&"hud.call_wave", {"gold": bonus})
	_refresh()

func _on_pause_changed(is_paused: bool) -> void:
	_paused = is_paused
	_refresh()

func _refresh() -> void:
	visible = _in_prep
	disabled = _paused or _sent
	tooltip_text = tr(&"hud.call_wave.paused") if _paused else ""
