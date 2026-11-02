extends Node
## Drives the HUD with fake EventBus signals. Press F6 on this scene.

func _ready() -> void:
	await get_tree().process_frame
	EventBus.run_started.emit()
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
	await _fortress_low()
	await _mode_switch()
	await _emergency()
	await _boss()
	EventBus.state_changed.emit(&"SUMMARY")
	print("[test_hud] done, press F1 to toggle the HUD")

func _fortress_low() -> void:
	print("[test_hud] Fortress at 25%: border blinks, tag shown")
	EventBus.fortress_hp_changed.emit(250, 1000, -430)
	await get_tree().create_timer(2.0).timeout
	print("[test_hud] reduced flashing: border stays solid")
	EventBus.settings_changed.emit(&"reduce_flash", true)
	await get_tree().create_timer(1.5).timeout
	EventBus.settings_changed.emit(&"reduce_flash", false)
	print("[test_hud] Fortress back to 60%: warning gone")
	EventBus.fortress_hp_changed.emit(600, 1000, 350)
	await get_tree().create_timer(1.0).timeout

func _mode_switch() -> void:
	print("[test_hud] Commander mode: blue border, shield, 5 s cooldown")
	EventBus.mode_changed.emit(&"COMMANDER")
	EventBus.mode_switch_cooldown_started.emit(5.0)
	await get_tree().create_timer(1.0).timeout
	print("[test_hud] Tab pressed too early: the seconds flash")
	EventBus.mode_switch_denied.emit(&"COOLDOWN", 4.0)
	await get_tree().create_timer(4.5).timeout
	print("[test_hud] back to Frontline")
	EventBus.mode_changed.emit(&"FRONTLINE")
	EventBus.mode_switch_cooldown_started.emit(5.0)
	await get_tree().create_timer(2.0).timeout

func _boss() -> void:
	print("[test_hud] boss row shown, then hidden when the boss dies")
	EventBus.state_changed.emit(&"BOSS_COMBAT")
	EventBus.boss_spawned.emit()
	await get_tree().create_timer(2.0).timeout
	EventBus.boss_defeated.emit()
	await get_tree().create_timer(1.0).timeout

func _emergency() -> void:
	print("[test_hud] emergency repair in Frontline: grey, hover shows the commander only reason")
	EventBus.mode_changed.emit(&"FRONTLINE")
	EventBus.emergency_repair_state_changed.emit(3, 0.0, 0.2)
	await get_tree().create_timer(2.0).timeout
	print("[test_hud] Commander mode: ready")
	EventBus.mode_changed.emit(&"COMMANDER")
	await get_tree().create_timer(2.0).timeout
	print("[test_hud] Fortress full: grey, full HP reason")
	EventBus.fortress_hp_changed.emit(1000, 1000, 400)
	await get_tree().create_timer(2.0).timeout
	print("[test_hud] Fortress at 95%: ready, hover warns about overheal")
	EventBus.fortress_hp_changed.emit(950, 1000, -50)
	await get_tree().create_timer(2.0).timeout
	print("[test_hud] used: 2/3, ring and seconds count down from 10")
	EventBus.fortress_hp_changed.emit(600, 1000, -350)
	EventBus.emergency_repair_state_changed.emit(2, 10.0, 0.2)
	EventBus.skill_cooldown_changed.emit(&"emg_repair", 10.0, 10.0)
	await get_tree().create_timer(3.0).timeout
	print("[test_hud] R refused twice during the cooldown: only one glow")
	EventBus.emergency_repair_denied.emit(&"COOLDOWN")
	EventBus.emergency_repair_denied.emit(&"COOLDOWN")
	await get_tree().create_timer(2.0).timeout
	print("[test_hud] out of charges: hollow dots, no charges reason")
	EventBus.emergency_repair_state_changed.emit(0, 0.0, 0.2)
	await get_tree().create_timer(2.0).timeout
	print("[test_hud] boss killed: +1 charge and a glow")
	EventBus.emergency_repair_charge_granted.emit(1)
	await get_tree().create_timer(2.0).timeout
	EventBus.mode_changed.emit(&"FRONTLINE")
