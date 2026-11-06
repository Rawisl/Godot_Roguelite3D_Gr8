extends Node
## Plays the wave manager and the XP tracker around the REWARD_PICK screen; RewardService is the real one.
## 1: enter REWARD_PICK with 2 picks, paused like a run. 2: fill some skill slots.
## 3: empty offer (pool used up). 4: leave REWARD_PICK (PREP). 5: build a heal station (unlocks its card).
## Esc: closes the Skip dialog first, otherwise opens Pause over the screen.

var _pending := 0

func _ready() -> void:
	# Keys must still arrive while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Lets Esc open Pause as it does in a run.
	GameState.current = GameState.AppState.RUN
	EventBus.reward_pick_requested.connect(func(id: StringName, kind: StringName, level: int) -> void:
		print("reward_pick_requested ", id, " ", kind, " ", level))
	EventBus.reward_skip_requested.connect(func() -> void: print("reward_skip_requested"))
	EventBus.reward_picked.connect(_on_reward_picked)
	EventBus.run_started.emit()

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_enter(2)
		KEY_2:
			EventBus.skill_slots_changed.emit([&"whirlwind", &"", &""], [&"sharpness", &"vitality", &""])
		KEY_3:
			EventBus.reward_offered.emit([], 0)
		KEY_4:
			_leave()
		KEY_5:
			EventBus.tower_built.emit(&"W1", &"heal_station")
			print("heal station built")

func _enter(picks: int) -> void:
	_pending = picks
	EventBus.xp_changed.emit(0.0, 2, 10.0, _pending)
	TimeManager.request_pause(TimeManager.REASON_REWARD_PICK)
	EventBus.state_changed.emit(&"REWARD_PICK")

## Same order as the real run: one pick used, the slots updated, PREP once no pick is left.
func _on_reward_picked(card_id: StringName, slot_kind: StringName, new_level: int) -> void:
	print("reward_picked ", card_id, " ", slot_kind, " ", new_level)
	var service := get_tree().get_first_node_in_group(&"reward_service") as RewardService
	if service != null:
		EventBus.skill_slots_changed.emit(service.state.active, service.state.passive)
	_pending -= 1
	EventBus.xp_changed.emit(0.0, 2, 10.0, _pending)
	if _pending <= 0:
		_leave()

func _leave() -> void:
	_pending = 0
	TimeManager.release_pause(TimeManager.REASON_REWARD_PICK)
	EventBus.state_changed.emit(&"PREP")
