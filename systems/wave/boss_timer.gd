class_name BossTimer
extends Node

## Boss wave countdown. Created by WaveManager as a child.
## Counts game time (stops while the tree is paused) from the start of BOSS_COMBAT, holds the full
## value during BOSS_INTRO, and announces Enrage once if the boss is still alive when it hits zero.

var time_left: float = 0.0
var running: bool = false
var enraged: bool = false

var _wave_ready: bool = false
var _last_state: StringName = &""
var _expired: bool = false
var _boss_defeated: bool = false
var _run_lost: bool = false
var _fired_marks: Dictionary = {}


func _ready() -> void:
	add_to_group(&"boss_timer")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.fortress_destroyed.connect(_on_run_lost)
	EventBus.commander_died.connect(_on_run_lost)


func _exit_tree() -> void:
	if EventBus.wave_started.is_connected(_on_wave_started):
		EventBus.wave_started.disconnect(_on_wave_started)
	if EventBus.state_changed.is_connected(_on_state_changed):
		EventBus.state_changed.disconnect(_on_state_changed)
	if EventBus.boss_defeated.is_connected(_on_boss_defeated):
		EventBus.boss_defeated.disconnect(_on_boss_defeated)
	if EventBus.fortress_destroyed.is_connected(_on_run_lost):
		EventBus.fortress_destroyed.disconnect(_on_run_lost)
	if EventBus.commander_died.is_connected(_on_run_lost):
		EventBus.commander_died.disconnect(_on_run_lost)


func _physics_process(delta: float) -> void:
	tick(delta)


## Sets up a fresh countdown for a boss wave. Does not start it: BOSS_COMBAT does.
func start_for_wave(wave_index: int) -> void:
	var boss_n: int = wave_index / GameConfig.boss_wave_interval
	time_left = GameConfig.get_boss_timer(boss_n)
	running = false
	enraged = false
	_expired = false
	_boss_defeated = false
	_run_lost = false
	_fired_marks.clear()
	_write_run_state()
	_write_run_state_enraged()


func tick(delta: float) -> void:
	if not running or _expired:
		return
	time_left = maxf(0.0, time_left - delta)
	_write_run_state()
	EventBus.boss_timer_changed.emit(time_left)
	_check_milestones()
	if time_left <= 0.0:
		_expired = true
		_resolve_enrage.call_deferred()


# Runs deferred so every damage and death handled in the frame the timer hit zero is already settled.
func _resolve_enrage() -> void:
	var can_enrage: bool = running and not enraged and not _boss_defeated and not _run_lost and _boss_alive()
	running = false
	if not can_enrage:
		return
	enraged = true
	_write_run_state_enraged()
	EventBus.boss_enraged.emit()


func _boss_alive() -> bool:
	for node in get_tree().get_nodes_in_group(&"boss"):
		var boss := node as Enemy
		if boss != null and is_instance_valid(boss) and not boss.is_dead:
			return true
	return false


func _check_milestones() -> void:
	var warn_mark: int = int(GameConfig.enrage_warn_time)
	if time_left <= GameConfig.enrage_warn_time:
		_fire_mark(warn_mark)
	for s in range(int(GameConfig.enrage_countdown_time), 0, -1):
		if time_left <= float(s):
			_fire_mark(s)


func _fire_mark(mark: int) -> void:
	if _fired_marks.has(mark):
		return
	_fired_marks[mark] = true
	EventBus.boss_timer_milestone.emit(mark)


func _on_wave_started(wave_index: int) -> void:
	if wave_index % GameConfig.boss_wave_interval != 0:
		_stop_and_clear()
		return
	start_for_wave(wave_index)
	_wave_ready = true
	# state_changed can arrive before wave_started when the wave manager enters combat.
	if _last_state == &"BOSS_COMBAT":
		_begin_combat()
	else:
		EventBus.boss_timer_changed.emit(time_left)


func _on_state_changed(new_state: StringName) -> void:
	_last_state = new_state
	match new_state:
		&"BOSS_COMBAT":
			if _wave_ready:
				_begin_combat()
		&"BOSS_INTRO":
			pass
		&"SUMMARY", &"REWARD_PICK":
			# Keep the enraged flag readable for the boss reward step; PREP or the next wave clears it.
			running = false
			_wave_ready = false
		_:
			_stop_and_clear()


func _begin_combat() -> void:
	if running or _expired:
		return
	running = not _boss_defeated and not _run_lost
	EventBus.boss_timer_changed.emit(time_left)


func _stop_and_clear() -> void:
	running = false
	enraged = false
	_expired = false
	_wave_ready = false
	_boss_defeated = false
	_run_lost = false
	_fired_marks.clear()
	# Normal waves must not show the seconds left over from the last boss wave.
	time_left = 0.0
	_write_run_state()
	_write_run_state_enraged()


func _on_boss_defeated() -> void:
	_boss_defeated = true
	running = false


func _on_run_lost() -> void:
	_run_lost = true
	running = false


func _write_run_state() -> void:
	var rs := get_tree().get_first_node_in_group(&"run_state") as RunState
	if rs != null:
		rs.boss_timer = time_left


func _write_run_state_enraged() -> void:
	var rs := get_tree().get_first_node_in_group(&"run_state") as RunState
	if rs != null:
		rs.boss_enraged = enraged
