extends Node
## 1: open the panel. 2: 40% missing. 3: 1.6% missing. 4: gold 3. 5: gold 10.
## 6: one emergency charge with a 42 s cooldown.

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			var sel := get_tree().root.find_child("SelectionController", true, false) as SelectionController
			sel.fortress_selected.emit()
		KEY_2:
			EventBus.fortress_hp_changed.emit(600, 1000, -400)
		KEY_3:
			EventBus.fortress_hp_changed.emit(984, 1000, -16)
		KEY_4:
			EventBus.gold_changed.emit(3)
		KEY_5:
			EventBus.gold_changed.emit(10)
		KEY_6:
			EventBus.emergency_repair_state_changed.emit(1, 60.0, 0.2)
			EventBus.skill_cooldown_changed.emit(&"emg_repair", 42.0, 60.0)
