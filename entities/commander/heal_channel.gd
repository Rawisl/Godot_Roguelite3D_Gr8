class_name HealChannel
extends Node
## Heal-at-station channel (key E). Hold E for heal_hold_time of game time next to a
## station that still has HP, then HP flows from the station into the commander until
## full, until the station runs dry, or until any cancelling action. After a cancel the
## key has to be released and pressed again.
##
## A station is any Node3D in the "heal_station" group with: slot_id (StringName),
## hp (float), is_alive() and drain(amount: float). The station may be freed at any time.

const IDLE := &"IDLE"
const HOLD := &"HOLD"
const HEALING := &"HEALING"
const CANCELLED := &"CANCELLED"
const DEPLETED := &"DEPLETED"

const PROGRESS_INTERVAL := 0.1
const EPSILON := 0.000001

## Extra HP/s per level of the heal station skill.
const SKILL_RATE_PER_LEVEL := 5.0

var skill_level: int = 0
var phase: StringName = IDLE
var hold_time: float = 0.0

var _commander: Node
var _source: Node3D
var _source_slot: StringName = &""
# Healing is fractional, HP is an int: the remainder carries over between ticks.
var _carry: float = 0.0
var _needs_release: bool = false
var _progress_timer: float = 0.0


func _ready() -> void:
	_commander = get_parent()
	_commander.health.damaged.connect(func(_amount: int, _info: DamageInfo) -> void: cancel())
	_commander.health.died.connect(cancel)
	EventBus.mode_changed.connect(func(_mode: StringName) -> void: cancel())
	EventBus.state_changed.connect(func(_state: StringName) -> void: cancel())
	EventBus.pause_changed.connect(func(_paused: bool) -> void: cancel())


func get_source() -> Node3D:
	return _source if is_instance_valid(_source) else null


func get_heal_rate() -> float:
	return _stat(&"heal_rate_base", 10.0) + SKILL_RATE_PER_LEVEL * skill_level


## Stops the channel. If E is still down it must be released before a new hold can start.
func cancel() -> void:
	if Input.is_action_pressed(&"heal_channel"):
		_needs_release = true
	if phase == IDLE:
		return
	_finish(CANCELLED)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel()


func _physics_process(delta: float) -> void:
	# Cancelling actions are checked first, so they win over a hold that completes this tick.
	if _commander.is_dead or not _commander.is_idle() or _commander.is_trying_to_move():
		cancel()
		return

	var held := Input.is_action_pressed(&"heal_channel")
	if not held:
		_needs_release = false

	match phase:
		IDLE:
			if held and _can_start_hold():
				_source = _find_source()
				if _source != null:
					_source_slot = _source.slot_id
					_set_phase(HOLD)
		HOLD:
			_tick_hold(held, delta)
		HEALING:
			_tick_healing(delta)


func _tick_hold(held: bool, delta: float) -> void:
	if not held:
		_finish(IDLE)
		return
	if not _source_alive() or not _in_range(_source):
		cancel()
		return
	if _commander.is_commander_mode or get_block_reason() == &"FULL_HP":
		return
	hold_time += delta
	_progress_timer += delta
	if hold_time >= _stat(&"heal_hold_time", 1.0) - EPSILON:
		_set_phase(HEALING)
		return
	if _progress_timer >= PROGRESS_INTERVAL:
		_progress_timer = 0.0
		_emit_state(HOLD)


func _tick_healing(delta: float) -> void:
	if not _source_alive():
		_finish(DEPLETED)
		return
	if not _in_range(_source):
		cancel()
		return

	var health: HealthComponent = _commander.health
	var missing := float(health.max_hp - health.hp) - _carry
	if missing <= EPSILON:
		_finish(IDLE)
		return

	var rate := get_heal_rate()
	var k := rate / _stat(&"heal_drain_rate", 20.0)
	# Only the part the commander can actually use is taken from the station.
	var amount := minf(minf(rate * delta, missing), _source.hp * k)
	_source.drain(amount / k)

	var total := _carry + amount
	var whole := floori(total + EPSILON)
	if whole > 0:
		health.heal(whole)
	_carry = maxf(total - float(whole), 0.0)

	if not _source_alive():
		_finish(DEPLETED)
	elif float(health.max_hp - health.hp) - _carry <= EPSILON:
		_finish(IDLE)


## False once the station is freed (sold, destroyed) or out of HP.
func _source_alive() -> bool:
	return is_instance_valid(_source) and _source.is_alive()


func _can_start_hold() -> bool:
	return get_block_reason().is_empty()


## First reason a hold cannot progress right now, or an empty name when it can.
func get_block_reason() -> StringName:
	if _commander.is_commander_mode:
		return &"COMMANDER_MODE"
	if not _commander.is_idle() or _commander.is_trying_to_move():
		return &"NOT_IDLE"
	var wave_state: StringName = _commander.get_wave_state()
	if wave_state != &"COMBAT" and wave_state != &"BOSS_COMBAT":
		return &"WAVE_STATE"
	if get_tree().paused:
		return &"PAUSED"
	var health: HealthComponent = _commander.health
	if health.hp >= health.max_hp:
		return &"FULL_HP"
	if _find_source() == null:
		return &"NO_STATION_IN_RANGE"
	if _needs_release:
		return &"RELEASE_AND_PRESS_E"
	return &""


## Nearest living station in range, the lower slot_id on a tie.
func _find_source() -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"heal_station"):
		var station := node as Node3D
		if station == null or not station.is_alive() or not _in_range(station):
			continue
		var distance := _flat_distance(station)
		var closer := distance < best_distance - EPSILON
		var tied := absf(distance - best_distance) <= EPSILON
		if closer or (tied and best != null and String(station.slot_id) < String(best.slot_id)):
			best = station
			best_distance = distance
	return best


func _in_range(station: Node3D) -> bool:
	return _flat_distance(station) <= _stat(&"heal_range", 3.0)


func _flat_distance(station: Node3D) -> float:
	var from: Vector3 = _commander.global_position
	var to := station.global_position
	return Vector2(from.x - to.x, from.z - to.z).length()


func _set_phase(new_phase: StringName) -> void:
	phase = new_phase
	_progress_timer = 0.0
	if new_phase == HOLD:
		hold_time = 0.0
		_carry = 0.0
	_emit_state(new_phase)


## Back to IDLE; result is what subscribers are told (IDLE, CANCELLED or DEPLETED).
func _finish(result: StringName) -> void:
	var source_id := _source_slot
	phase = IDLE
	hold_time = 0.0
	_progress_timer = 0.0
	_source = null
	_source_slot = &""
	EventBus.heal_state_changed.emit(result, source_id, 0.0)


func _emit_state(state: StringName) -> void:
	var progress := clampf(hold_time / _stat(&"heal_hold_time", 1.0), 0.0, 1.0)
	EventBus.heal_state_changed.emit(state, _source_id(), progress)


func _source_id() -> StringName:
	return _source_slot


func _stat(stat_name: StringName, fallback: float) -> float:
	var stats: CharacterStats = _commander.stats
	if stats == null:
		return fallback
	return float(stats.get(stat_name))
