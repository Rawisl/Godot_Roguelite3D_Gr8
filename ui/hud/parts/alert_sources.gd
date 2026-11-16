class_name AlertSources
extends Node
## Turns game events into alerts for the AlertLayer next to it: the commander at low HP (T1),
## the boss enrage warning and the enrage itself (T2, T1), towers destroyed (T2, several in one
## frame become one toast) and a boss in the next wave (T2). The AlertLayer keeps the same alert
## from showing again within its repeat gap, so nothing here throttles on its own.

## Same threshold as the commander's own low HP warning.
@export var commander_stats: CharacterStats = preload("res://data/config/commander_stats.tres")

## Set while the commander is at or under the threshold, so the banner shows once per drop.
var _commander_low := false
var _destroyed: Array[StringName] = []
var _last_wave := 0
var _boss_next_known := false
var _boss_next := false
## Leaving the Hazard Trial goes back to PREP; the boss warning is still told once per wave.
var _boss_told_for := 0

func _ready() -> void:
	EventBus.commander_hp_changed.connect(_on_commander_hp_changed)
	EventBus.boss_timer_milestone.connect(_on_boss_timer_milestone)
	EventBus.boss_enraged.connect(func() -> void: _alert(Enums.AlertTier.T1, &"alert.boss_enraged"))
	EventBus.tower_destroyed.connect(_on_tower_destroyed)
	EventBus.wave_started.connect(func(index: int) -> void:
		_last_wave = index
		_boss_next_known = false)
	EventBus.wave_preview_ready.connect(_on_wave_preview_ready)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.run_started.connect(_on_run_started)

func _on_run_started() -> void:
	_commander_low = false
	_destroyed.clear()
	_last_wave = 0
	_boss_next_known = false
	_boss_told_for = 0

func _on_commander_hp_changed(hp: int, max_hp: int) -> void:
	var low := max_hp > 0 and hp > 0 and float(hp) / max_hp <= commander_stats.commander_low_hp_warning_pct
	if low and not _commander_low:
		_alert(Enums.AlertTier.T1, &"alert.commander_low")
	_commander_low = low

func _on_boss_timer_milestone(t_mark: int) -> void:
	if t_mark == int(GameConfig.enrage_warn_time):
		_alert(Enums.AlertTier.T2, &"alert.boss_enrage_soon", {"seconds": t_mark})

## Several towers can fall in the same frame (a blast, Overload); they become one toast.
func _on_tower_destroyed(slot_id: StringName) -> void:
	if _destroyed.is_empty():
		_flush_destroyed.call_deferred()
	_destroyed.append(slot_id)

func _flush_destroyed() -> void:
	var slots := _destroyed.duplicate()
	_destroyed.clear()
	if slots.size() > 1:
		_alert(Enums.AlertTier.T2, &"alert.towers_ruined", {"count": slots.size()})
		return
	var service := get_tree().get_first_node_in_group(&"build_service")
	var slot: Slot = service.call(&"find_slot", slots[0]) if service != null and service.has_method(&"find_slot") else null
	if slot == null or slot.last_data == null:
		_alert(Enums.AlertTier.T2, &"alert.tower_ruined_plain", {"slot": slots[0]})
		return
	_alert(Enums.AlertTier.T2, &"alert.tower_ruined", {"name": tr(StringName("tower.%s" % slot.last_data.id)),
		"level": slot.last_level, "slot": slots[0], "cost": slot.get_rebuild_cost()})

func _on_wave_preview_ready(wave_index: int, _composition: Dictionary, is_boss: bool) -> void:
	if wave_index == _last_wave + 1:
		_boss_next_known = true
		_boss_next = is_boss

## Told once when the PREP before a boss wave starts.
# TODO(Ender-Via): send wave_preview_ready at the start of PREP; until then the boss wave comes from boss_wave_interval.
func _on_state_changed(new_state: StringName) -> void:
	if new_state != &"PREP":
		return
	var next := _last_wave + 1
	var is_boss := _boss_next if _boss_next_known else next % GameConfig.boss_wave_interval == 0
	if is_boss and _boss_told_for != next:
		_boss_told_for = next
		_alert(Enums.AlertTier.T2, &"alert.boss_next", {"wave": next})

func _alert(tier: Enums.AlertTier, key: StringName, params: Dictionary = {}) -> void:
	EventBus.alert_requested.emit(int(tier), key, params)
