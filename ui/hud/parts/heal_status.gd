extends HBoxContainer
## Heal station status next to the commander HP: the E key, what holding E does right
## now, and how many stations still have HP. Draws only from EventBus signals.

const IDLE := &"IDLE"
const HOLD := &"HOLD"
const HEALING := &"HEALING"
const CANCELLED := &"CANCELLED"
const DEPLETED := &"DEPLETED"
## How long a one-off message (cancelled, depleted, hit) stays, in real time.
const FLASH_TIME := 1.5

var _state: StringName = IDLE
var _progress := 0.0
var _block_reason: StringName = &""
var _hold_remaining := 0.0
var _heal_rate := 0.0
var _last_hp := -1
var _flash_key: StringName = &""
var _flash_until := 0.0
var _station_counts := Vector2i(-1, -1)
var _rendered_key: StringName = &""
var _rendered_value := -INF
## Stations that already warned about a low store since they were built, by slot.
var _low_warned: Dictionary = {}

@onready var _key_label: Label = %KeyLabel
@onready var _status: Label = %Status
@onready var _hold_bar: ProgressBar = %HoldBar
@onready var _stations: Label = %Stations

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_key_label.text = tr(&"hud.heal.key")
	EventBus.heal_state_changed.connect(show_heal_state)
	EventBus.heal_status_updated.connect(_on_status_updated)
	EventBus.commander_hp_changed.connect(_on_commander_hp_changed)
	EventBus.heal_tower_hp_changed.connect(_on_station_store_changed)
	EventBus.tower_built.connect(_on_tower_built)
	EventBus.run_started.connect(_reset)
	set_stations(0, 0)

func _process(_delta: float) -> void:
	if _flash_until > 0.0 and TimeManager.real_time >= _flash_until:
		_flash_until = 0.0
		_refresh()

## Shown only while at least one station exists.
func set_stations(alive: int, total: int) -> void:
	var counts := Vector2i(alive, total)
	if counts != _station_counts:
		_station_counts = counts
		visible = total > 0
		_stations.text = UiFormat.tr_fmt(&"hud.heal.stations", {"alive": alive, "total": total})
	_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_rendered_key = &""
		var counts := _station_counts
		_station_counts = Vector2i(-1, -1)
		_key_label.text = tr(&"hud.heal.key")
		set_stations(counts.x, counts.y)

func show_heal_state(state: StringName, source_slot: StringName, hold_progress: float) -> void:
	_state = state
	_progress = hold_progress
	match state:
		HOLD, HEALING:
			_flash_until = 0.0
		DEPLETED:
			_flash(&"hud.heal.depleted")
			_alert_drained.call_deferred(source_slot)
		CANCELLED:
			# A hit explains the cancel better than "release E", so it is kept.
			if not _is_flashing(&"hud.heal.under_attack") and not _is_flashing(&"hud.heal.depleted"):
				_flash(&"hud.heal.release")
	_refresh()

func _on_status_updated(state: StringName, reason: StringName, progress: float,
		remaining: float, rate: float, alive: int, total: int) -> void:
	_state = state
	_block_reason = reason
	_progress = progress
	_hold_remaining = remaining
	_heal_rate = rate
	if total == 0 or state == HOLD or state == HEALING:
		_flash_until = 0.0
	if reason in [&"COMMANDER_MODE", &"WAVE_STATE", &"PAUSED", &"FULL_HP",
			&"NO_STATION_IN_RANGE", &"DEPLETED", &"DEAD"]:
		_flash_until = 0.0
	if total == 0:
		_last_hp = -1
	set_stations(alive, total)

func _reset() -> void:
	_low_warned.clear()
	_last_hp = -1
	_flash_until = 0.0
	_state = IDLE
	_block_reason = &""
	set_stations(0, 0)

func _on_commander_hp_changed(hp: int, _max_hp: int) -> void:
	if _last_hp >= 0 and hp < _last_hp:
		_flash(&"hud.heal.under_attack")
	_last_hp = hp
	_refresh()

func _flash(key: StringName) -> void:
	_flash_key = key
	_flash_until = TimeManager.real_time + FLASH_TIME

func _is_flashing(key: StringName) -> bool:
	return _flash_key == key and TimeManager.real_time < _flash_until

func _refresh() -> void:
	if _hold_bar.visible != (_state == HOLD):
		_hold_bar.visible = _state == HOLD
	var progress := snappedf(_progress, _hold_bar.step) if _hold_bar.step > 0.0 else _progress
	if not is_equal_approx(_hold_bar.value, progress):
		_hold_bar.value = progress
	var key := _status_key()
	var value := _hold_remaining if key == &"hud.heal.hold" else _heal_rate if key == &"hud.heal.healing" else 0.0
	if key == _rendered_key and value == _rendered_value:
		return
	_rendered_key = key
	_rendered_value = value
	if key == &"hud.heal.hold":
		_status.text = UiFormat.tr_fmt(key, {"seconds": UiFormat.decimal(_hold_remaining)})
	elif key == &"hud.heal.healing":
		_status.text = UiFormat.tr_fmt(key, {"rate": UiFormat.num(_heal_rate)})
	else:
		_status.text = tr(key)

## Hard gates win; recent damage or depletion explains a busy state more precisely.
func _status_key() -> StringName:
	if _state == HOLD:
		return &"hud.heal.hold"
	if _state == HEALING:
		return &"hud.heal.healing"
	match _block_reason:
		&"COMMANDER_MODE": return &"hud.heal.frontline_only"
		&"WAVE_STATE": return &"hud.heal.combat_only"
		&"PAUSED": return &"hud.heal.paused"
		&"FULL_HP": return &"hud.heal.full_hp"
		&"NO_STATION_IN_RANGE": return &"hud.heal.too_far"
		&"DEPLETED": return &"hud.heal.depleted"
		&"DEAD": return &"hud.heal.dead"
	if _is_flashing(&"hud.heal.under_attack") or _is_flashing(&"hud.heal.depleted"):
		return _flash_key
	if _block_reason == &"NOT_IDLE":
		return &"hud.heal.busy"
	if _block_reason == &"RELEASE_AND_PRESS_E":
		return &"hud.heal.release"
	if TimeManager.real_time < _flash_until:
		return _flash_key
	return &"hud.heal.ready"

## Drained by healing: the station is rubble now. Deferred so the slot already shows the rebuild cost.
func _alert_drained(slot_id: StringName) -> void:
	var service := get_tree().get_first_node_in_group(&"build_service") as BuildService
	var slot := service.find_slot(slot_id) if service != null and slot_id != &"" else null
	var cost := slot.get_rebuild_cost() if slot != null else 0
	if cost > 0:
		EventBus.alert_requested.emit(int(Enums.AlertTier.T2), &"alert.heal_drained", {"slot": slot_id, "cost": cost})
	else:
		EventBus.alert_requested.emit(int(Enums.AlertTier.T2), &"alert.heal_drained_plain", {"slot": slot_id})

## Once per station per build, when its store first drops under the low share.
func _on_station_store_changed(slot_id: StringName, new_hp: int, max_hp: int) -> void:
	if max_hp <= 0 or new_hp <= 0 or _low_warned.has(slot_id):
		return
	if float(new_hp) / max_hp < GameConfig.heal_store_low_pct:
		_low_warned[slot_id] = true
		EventBus.alert_requested.emit(int(Enums.AlertTier.T3), &"alert.heal_low", {"slot": slot_id})

func _on_tower_built(slot_id: StringName, _type: StringName) -> void:
	_low_warned.erase(slot_id)
