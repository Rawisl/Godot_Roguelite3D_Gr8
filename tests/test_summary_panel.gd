extends Node
## 1: enter SUMMARY with full data. 2: enter SUMMARY with no data (like the real game today).
## 3: summary with no ruined towers and no picks. 4: leave SUMMARY (PREP).

func _ready() -> void:
	EventBus.summary_continue_requested.connect(func() -> void: print("summary_continue_requested"))

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			EventBus.wave_cleared.emit(4)
			EventBus.state_changed.emit(&"SUMMARY")
			EventBus.wave_summary_ready.emit(_full())
		KEY_2:
			EventBus.wave_cleared.emit(2)
			EventBus.state_changed.emit(&"SUMMARY")
		KEY_3:
			var s := _full()
			s.ruined_towers = []
			s.pending_picks = 0
			s.emg_repair_gained = 0
			EventBus.state_changed.emit(&"SUMMARY")
			EventBus.wave_summary_ready.emit(s)
		KEY_4:
			EventBus.state_changed.emit(&"PREP")

func _full() -> Dictionary:
	return {
		"wave_index": 4, "clear_time": 47.3, "clear_tier": "FAST",
		"kills_by_type": {"grunt": 12, "archer": 3},
		"gold_base": 66, "gold_mult": 1.25, "early_call_bonus": 20, "gold_total": 102,
		"prestige_gain_wave": 18, "fortress_hp": 820, "fortress_max_hp": 1000,
		"ruined_towers": [{"type": "arrow", "level": 2, "rebuild_cost": 90}],
		"emg_repair_gained": 1,
		"xp_from_commander": 9, "xp_from_towers": 4, "commander_level": 3, "pending_picks": 1,
	}
