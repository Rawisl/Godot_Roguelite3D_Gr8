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
var _wave_state: StringName = &""
var _commander_mode := false
var _full_hp := false
var _last_hp := -1
var _flash_key: StringName = &""
var _flash_until := 0.0
var _alive := 0

@onready var _key_label: Label = %KeyLabel
@onready var _status: Label = %Status
@onready var _hold_bar: ProgressBar = %HoldBar
@onready var _stations: Label = %Stations

func _ready() -> void:
	_key_label.text = tr(&"hud.heal.key")
	# Sent by the heal channel; connected by name until that signal is on main.
	if EventBus.has_signal(&"heal_state_changed"):
		EventBus.connect(&"heal_state_changed", show_heal_state)
	# TODO: call set_stations from heal_tower_hp_changed once the heal tower sends it.
	EventBus.state_changed.connect(_on_wave_state_changed)
	EventBus.mode_changed.connect(_on_mode_changed)
	EventBus.commander_hp_changed.connect(_on_commander_hp_changed)
	set_stations(0, 0)

func _process(_delta: float) -> void:
	if _flash_until > 0.0 and TimeManager.real_time >= _flash_until:
		_flash_until = 0.0
		_refresh()

## Shown only while at least one station exists.
func set_stations(alive: int, total: int) -> void:
	_alive = alive
	visible = total > 0
	_stations.text = UiFormat.tr_fmt(&"hud.heal.stations", {"alive": alive, "total": total})
	_refresh()

func show_heal_state(state: StringName, _source_slot: StringName, hold_progress: float) -> void:
	_state = state
	_progress = hold_progress
	match state:
		HOLD, HEALING:
			_flash_until = 0.0
		DEPLETED:
			_flash(&"hud.heal.depleted")
		CANCELLED:
			# A hit explains the cancel better than "release E", so it is kept.
			if not _is_flashing(&"hud.heal.under_attack"):
				_flash(&"hud.heal.release")
	_refresh()

func _on_wave_state_changed(new_state: StringName) -> void:
	_wave_state = new_state
	_refresh()

func _on_mode_changed(mode: StringName) -> void:
	_commander_mode = mode == &"COMMANDER"
	_refresh()

func _on_commander_hp_changed(hp: int, max_hp: int) -> void:
	if _last_hp >= 0 and hp < _last_hp:
		_flash(&"hud.heal.under_attack")
	_last_hp = hp
	_full_hp = hp >= max_hp
	_refresh()

func _flash(key: StringName) -> void:
	_flash_key = key
	_flash_until = TimeManager.real_time + FLASH_TIME

func _is_flashing(key: StringName) -> bool:
	return _flash_key == key and TimeManager.real_time < _flash_until

# TODO: show seconds left and the heal rate once the heal channel sends them.
func _refresh() -> void:
	_hold_bar.visible = _state == HOLD
	_hold_bar.value = _progress
	_status.text = tr(_status_key())

## Active phase first, then a one-off message, then why E would do nothing right now.
func _status_key() -> StringName:
	if _state == HOLD:
		return &"hud.heal.hold"
	if _state == HEALING:
		return &"hud.heal.healing"
	if TimeManager.real_time < _flash_until:
		return _flash_key
	if _commander_mode:
		return &"hud.heal.frontline_only"
	if _wave_state != &"COMBAT" and _wave_state != &"BOSS_COMBAT":
		return &"hud.heal.combat_only"
	if _full_hp:
		return &"hud.heal.full_hp"
	if _alive == 0:
		return &"hud.heal.depleted"
	return &"hud.heal.ready"
