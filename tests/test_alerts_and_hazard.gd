extends Node
## Alert toasts and the Hazard Trial UI with fake EventBus signals. A fake wave side answers the
## enter and leave requests the way the real one will. Press F6: the checks run first and print a
## summary, then the keys replay each step by hand.
## 1: four T2 toasts at once (one waits). 2: a T1 banner. 3: a T3 toast. 4: a weapon from a boss.
## 5: a heal station runs low, then is drained. M: Frontline / Commander. P: pause / resume.
## E: enter the room (or click the Hazard Trial marker). K: one enemy done in the room.
## W: win the room. D: die in the room. Leave: the button in the room. N: next wave's PREP.

const ROOM_TYPES: Array = [&"grunt", &"grunt", &"archer", &"brute", &"grunt"]

var _passed := 0
var _failed := 0
var _commander := false
var _paused := false
var _wave := 3
var _in_room := false
var _remaining := 0
var _gold := 0
var _xp := 0.0
var _enter_requests := 0
var _leave_requests := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.hazard_enter_requested.connect(_on_enter_requested)
	EventBus.hazard_leave_requested.connect(_on_leave_requested)
	await get_tree().process_frame
	await _run_checks()
	_new_run()

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			for i in 4:
				EventBus.alert_requested.emit(int(Enums.AlertTier.T2), &"alert.weapon_gained", {"name": "Toast %d" % (i + 1), "repeat": true})
		KEY_2:
			EventBus.alert_requested.emit(int(Enums.AlertTier.T1), &"alert.fortress_low", {})
		KEY_3:
			EventBus.alert_requested.emit(int(Enums.AlertTier.T3), &"alert.level_up", {"level": 2, "repeat": true})
		KEY_4:
			EventBus.weapon_gained.emit(&"frost")
		KEY_5:
			EventBus.heal_tower_hp_changed.emit(&"G_1_4", 40, 300)
			EventBus.heal_state_changed.emit(&"DEPLETED", &"G_1_4", 0.0)
		KEY_M:
			_commander = not _commander
			EventBus.mode_changed.emit(&"COMMANDER" if _commander else &"FRONTLINE")
		KEY_P:
			_paused = not _paused
			EventBus.pause_changed.emit(_paused)
		KEY_K:
			_enemy_done()
		KEY_W:
			while _in_room and _remaining > 0:
				_enemy_done()
			_exit_room(&"WON")
		KEY_D:
			_exit_room(&"DIED")
		KEY_N:
			_next_wave()

func _new_run() -> void:
	_commander = false
	_paused = false
	_in_room = false
	_wave = 3
	EventBus.run_started.emit()
	EventBus.mode_changed.emit(&"FRONTLINE")
	EventBus.pause_changed.emit(false)
	_enter_prep()

func _enter_prep() -> void:
	EventBus.state_changed.emit(&"PREP")
	EventBus.hazard_trial_offered.emit(_wave, ROOM_TYPES, 1)

func _next_wave() -> void:
	EventBus.state_changed.emit(&"COMBAT")
	EventBus.state_changed.emit(&"SUMMARY")
	_wave += 1
	_enter_prep()

## Fake wave side: enter on request, as the real Hazard Trial will after its own checks.
func _on_enter_requested() -> void:
	_enter_requests += 1
	_in_room = true
	_remaining = ROOM_TYPES.size()
	_gold = 0
	_xp = 0.0
	EventBus.state_changed.emit(&"HAZARD_TRIAL")
	EventBus.hazard_trial_entered.emit(_wave, ROOM_TYPES)

func _on_leave_requested() -> void:
	_leave_requests += 1
	_exit_room(&"LEFT")

func _enemy_done() -> void:
	if not _in_room or _remaining <= 0:
		return
	_remaining -= 1
	_gold += 7
	_xp += 1.5
	EventBus.hazard_trial_progress.emit(_remaining, ROOM_TYPES.size(), _gold, _xp)

func _exit_room(result: StringName) -> void:
	if not _in_room:
		return
	_in_room = false
	var mithril := 1 if result == &"WON" else 0
	EventBus.hazard_trial_exited.emit(result, ROOM_TYPES.size() - _remaining, _gold, _xp, mithril)
	EventBus.state_changed.emit(&"PREP")

func _find(node_name: String) -> Node:
	return get_tree().root.find_child(node_name, true, false)


func _run_checks() -> void:
	_new_run()
	var layer := _find("AlertLayer") as AlertLayer
	layer.clear()
	layer.t2_time = 0.2
	layer.t3_time = 0.2
	layer.banner_time = 0.2

	# Toast rules.
	for i in 4:
		EventBus.alert_requested.emit(int(Enums.AlertTier.T2), StringName("alert.test_%d" % i), {})
	_check(layer.visible_toast_count() == 3 and layer.waiting_count() == 1, "four toasts: three shown, one waits")
	EventBus.alert_requested.emit(int(Enums.AlertTier.T1), &"alert.fortress_low", {})
	_check(layer.is_banner_visible(), "a T1 banner shows at once even with three toasts up")
	EventBus.alert_requested.emit(int(Enums.AlertTier.T2), &"alert.test_0", {})
	_check(layer.waiting_count() == 1, "the same alert within 5 s is dropped")
	EventBus.alert_requested.emit(int(Enums.AlertTier.T2), &"alert.test_0", {"repeat": true})
	_check(layer.waiting_count() == 2, "a repeat alert (countdown) is not dropped")
	get_tree().paused = true
	await _wait_real_time(0.3)
	_check(not layer.is_banner_visible() and layer.shown_keys().has(&"alert.test_3"), "lifetimes run in real time, also on Pause; the waiting toast shows next")
	get_tree().paused = false
	layer.clear()

	EventBus.alert_requested.emit(int(Enums.AlertTier.T3), &"alert.level_up", {"level": 2})
	var bottom := _find("ToastBottom") as Control
	_check(bottom.get_child(bottom.get_child_count() - 1).visible, "T3 goes to the bottom right column")
	layer.clear()

	# Alerts sent by the HUD parts.
	EventBus.weapon_gained.emit(&"frost")
	_check(layer.shown_keys().has(&"alert.weapon_gained"), "a weapon from a boss shows its toast")
	EventBus.heal_tower_hp_changed.emit(&"G_1_4", 50, 300)
	_check(layer.shown_keys().has(&"alert.heal_low"), "a heal station under 20% warns")
	layer.clear()
	EventBus.heal_tower_hp_changed.emit(&"G_1_4", 30, 300)
	_check(not layer.shown_keys().has(&"alert.heal_low"), "the same station warns only once per build")
	EventBus.heal_state_changed.emit(&"DEPLETED", &"G_1_4", 0.0)
	await get_tree().process_frame
	_check(layer.shown_keys().has(&"alert.heal_drained_plain") or layer.shown_keys().has(&"alert.heal_drained"), "a drained station shows its toast")
	layer.clear()

	# The Hazard Trial marker.
	var gate := _find("HazardGate") as HazardGate
	var start := _find("StartWaveButton") as Control
	var hint := start.get_node("%HazardHint") as Control
	_check(gate.visible and gate.lock_reason() == &"" and not gate.disabled, "PREP, Frontline: the marker is ready")
	_check(gate.tooltip_text.contains(tr(&"enemy.archer")) and gate.tooltip_text.contains("Mithril"), "the tooltip lists the group and the Mithril")
	_check(start.visible and hint.visible, "the Start wave button reminds that the room is not used yet")
	EventBus.mode_changed.emit(&"COMMANDER")
	_check(gate.lock_reason() == &"hud.hazard.frontline" and gate.disabled, "Commander mode: grey with the reason")
	EventBus.mode_changed.emit(&"FRONTLINE")
	EventBus.pause_changed.emit(true)
	_check(gate.lock_reason() == &"hud.hazard.paused", "Pause: grey with the reason")
	EventBus.pause_changed.emit(false)

	# Entering and the room HUD.
	var panel_host := _find("PanelHost") as PanelHost
	panel_host.call(&"_show_fortress")
	var fortress_panel := _find("FortressPanel") as Control
	_check(fortress_panel.visible, "a panel is open before entering")
	var key := InputEventAction.new()
	key.action = &"hazard_enter"
	key.pressed = true
	gate._unhandled_input(key)
	_check(_enter_requests == 1, "E asks to enter the room")
	_check(not fortress_panel.visible, "entering closes the open panel")
	var room := _find("HazardHud") as HazardHud
	_check(room.visible and not gate.visible and not start.visible, "in the room: room HUD shown, marker and Start wave hidden")
	_check((room.get_node("%Enemies") as Label).text == UiFormat.tr_fmt(&"hud.hazard.enemies", {"value": 5, "max": 5}), "enemies left 5/5")
	_check((room.get_node("%Reward") as Label).visible, "the Mithril for a win shows")
	_check(_find("FortressBar").modulate.a < 1.0, "the Fortress bar fades in the room")
	_check((_find("CommanderStatus").get_node("%Title") as Label).text == tr(&"hud.commander_room"), "the commander HP is the room copy's")
	var speed := _find("SpeedButtons")
	var x3 := speed.find_children("*", "Button", true, false).back() as Button
	_check(not x3.disabled, "x2 and x3 work in the room")
	_enemy_done()
	_enemy_done()
	_check((room.get_node("%Enemies") as Label).text == UiFormat.tr_fmt(&"hud.hazard.enemies", {"value": 3, "max": 5}), "two done: 3/5 left")
	_check((room.get_node("%Loot") as Label).text.contains("14"), "gold earned so far shows")
	EventBus.pause_changed.emit(true)
	var leave := room.get_node("%LeaveButton") as Button
	_check(leave.disabled, "Leave is grey while paused")
	EventBus.pause_changed.emit(false)
	leave.pressed.emit()
	leave.pressed.emit()
	_check(_leave_requests == 1, "Leave sends one request, no confirmation")
	_check(layer.shown_keys().has(&"alert.hazard.left"), "leaving shows the result toast")
	_check(not room.visible and gate.visible and gate.lock_reason() == &"hud.hazard.used", "back in PREP: the marker says used")
	_check(not hint.visible, "the reminder on the Start wave button goes")
	gate._unhandled_input(key)
	_check(_enter_requests == 1, "a second try in the same PREP is not sent")
	layer.clear()

	# A new wave unlocks the room again; winning shows the Mithril.
	_next_wave()
	_check(gate.lock_reason() == &"" and hint.visible, "the next wave's PREP unlocks the room")
	gate.pressed.emit()
	while _remaining > 0:
		_enemy_done()
	_exit_room(&"WON")
	_check(layer.shown_keys().has(&"alert.hazard.won"), "winning shows the result toast with the rewards")
	layer.clear()
	_next_wave()
	gate.pressed.emit()
	_exit_room(&"DIED")
	_check(layer.shown_keys().has(&"alert.hazard.died"), "dying in the room shows its toast")
	layer.clear()
	layer.t2_time = 2.5
	layer.t3_time = 2.0
	layer.banner_time = 3.0
	print("test_alerts_and_hazard: %d passed, %d failed" % [_passed, _failed])

## Waits on the clock AlertLayer reads, so a headless run with odd frame timing still checks it right.
func _wait_real_time(seconds: float) -> void:
	var until := TimeManager.real_time + seconds
	while TimeManager.real_time < until:
		await get_tree().process_frame

func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		print("  [FAIL] ", label)
