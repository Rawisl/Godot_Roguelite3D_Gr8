extends Node
## Drives the HUD with fake EventBus signals. Press F6 on this scene.

func _ready() -> void:
	await get_tree().process_frame
	EventBus.fortress_hp_changed.emit(1000, 1000, 0)
	EventBus.commander_hp_changed.emit(200, 200)
	EventBus.gold_changed.emit(150)
	EventBus.state_changed.emit(&"PREP")
	for t in range(5, -1, -1):
		EventBus.prep_timer_changed.emit(float(t))
		await get_tree().create_timer(1.0).timeout
	EventBus.state_changed.emit(&"COMBAT")
	EventBus.wave_started.emit(1)
	EventBus.enemy_count_changed.emit(0, 8, 8)
	EventBus.commander_hp_changed.emit(150, 200)
	for killed in range(1, 9):
		await get_tree().create_timer(0.5).timeout
		var left := 8 - killed
		var alive := mini(3, left)
		EventBus.enemy_count_changed.emit(alive, left - alive, 8)
		EventBus.fortress_hp_changed.emit(1000 - killed * 40, 1000, -40)
		EventBus.gold_changed.emit(150 + killed * 5)
		EventBus.gold_delta.emit(5)
	EventBus.state_changed.emit(&"SUMMARY")
	print("[test_hud] done, press F1 to toggle the HUD")
