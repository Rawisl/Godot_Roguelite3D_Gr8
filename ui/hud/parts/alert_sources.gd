class_name AlertSources
extends Node
## Turns game events into alerts for the AlertLayer next to it: the commander at low HP (T1),
## the boss enrage warning and the enrage itself (T2, T1) and a boss in the
## next wave (T2). Each alert is a short main line and a second line, without sentence punctuation.
# TODO(kimvux): play a heartbeat sound with the commander low HP banner; AudioManager has no such cue yet.

var _last_wave := 0
var _boss_next_known := false
var _boss_next := false
## Leaving the Hazard Trial goes back to PREP; the boss warning is still told once per wave.
var _boss_told_for := 0

func _ready() -> void:
	# The commander decides when it is low (exact HP, its own threshold), so the banner follows it.
	EventBus.commander_low_hp_changed.connect(func(is_low: bool) -> void:
		if is_low:
			_alert(Enums.AlertTier.T1, &"alert.commander_low", {"sub_key": &"alert.commander_low_sub"}))
	EventBus.boss_timer_milestone.connect(_on_boss_timer_milestone)
	EventBus.boss_enraged.connect(func() -> void:
		_alert(Enums.AlertTier.T1, &"alert.boss_enraged", {"sub_key": &"alert.boss_enraged_sub"}))
	EventBus.wave_started.connect(func(index: int) -> void:
		_last_wave = index
		_boss_next_known = false)
	EventBus.wave_preview_ready.connect(_on_wave_preview_ready)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.run_started.connect(_on_run_started)

func _on_run_started() -> void:
	_last_wave = 0
	_boss_next_known = false
	_boss_told_for = 0

func _on_boss_timer_milestone(t_mark: int) -> void:
	if t_mark == int(GameConfig.enrage_warn_time):
		_alert(Enums.AlertTier.T2, &"alert.boss_enrage_soon", {"seconds": t_mark, "sub_key": &"alert.boss_enrage_soon_sub"})

func _on_wave_preview_ready(wave_index: int, _composition: Dictionary, is_boss: bool) -> void:
	if wave_index == _last_wave + 1:
		_boss_next_known = true
		_boss_next = is_boss

## Told once when the PREP before a boss wave starts.
func _on_state_changed(new_state: StringName) -> void:
	if new_state != &"PREP":
		return
	var next := _last_wave + 1
	var is_boss := _boss_next if _boss_next_known else next % GameConfig.boss_wave_interval == 0
	if is_boss and _boss_told_for != next:
		_boss_told_for = next
		_alert(Enums.AlertTier.T2, &"alert.boss_next", {"wave": next, "sub_key": &"alert.boss_next_sub"})

func _alert(tier: Enums.AlertTier, key: StringName, params: Dictionary = {}) -> void:
	EventBus.alert_requested.emit(int(tier), key, params)
