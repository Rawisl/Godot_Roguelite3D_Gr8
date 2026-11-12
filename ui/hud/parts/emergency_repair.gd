extends PanelContainer
## Emergency repair slot: charges as dots with a number, a ring for the cooldown with the
## seconds left, and the reason in the tooltip when it cannot be used. Locked shows grey and
## spent charges are hollow dots, so nothing relies on colour alone.
## The lock reason is worked out here from mode, pause, Fortress HP, charges and cooldown,
## so it is right even before the commander sends a refusal.
# TODO(kimvux): swap Sweep/Icon to an emergency repair icon once the icon set has one.

const COMMANDER := &"COMMANDER"
const SKILL_ID := &"emg_repair"

## Filled dot for a charge left, hollow dot for a spent one.
@export var dot_full: StyleBox
@export var dot_empty: StyleBox
@export var locked_modulate := Color(1, 1, 1, 0.45)
## Glow when a charge is granted or R is refused, in real seconds.
@export var glow_time := 0.3
## Missing HP share under which the tooltip warns that the repair heals more than needed.
@export var overheal_hint_pct := 0.1
## Shortest gap between two refusal glows, in real seconds.
@export var denied_glow_gap := 0.5

var _charges := 0
var _cd_end := 0.0
var _cd_total := 0.0
var _hp := 0
var _max_hp := 0
var _commander_mode := false
var _paused := false
var _next_denied_glow := 0.0
var _glow_tween: Tween

@onready var _row: HBoxContainer = %Row
@onready var _key_label: Label = %KeyLabel
@onready var _sweep: CooldownSweep = %Sweep
@onready var _cooldown: Label = %CooldownLabel
@onready var _title: Label = %Title
@onready var _dots: HBoxContainer = %Dots
@onready var _count: Label = %Count
@onready var _glow: Panel = %Glow

func _ready() -> void:
	_key_label.text = tr(&"hud.emg.key")
	_title.text = tr(&"hud.emg.title")
	_glow.modulate.a = 0.0
	_reset()
	EventBus.run_started.connect(_reset)
	EventBus.emergency_repair_state_changed.connect(_on_state_changed)
	EventBus.skill_cooldown_changed.connect(_on_cooldown_changed)
	EventBus.emergency_repair_denied.connect(_on_denied)
	EventBus.emergency_repair_charge_granted.connect(_on_charge_granted)
	EventBus.fortress_hp_changed.connect(_on_fortress_hp_changed)
	EventBus.mode_changed.connect(_on_mode_changed)
	EventBus.pause_changed.connect(_on_pause_changed)

func _process(_delta: float) -> void:
	var left := _cooldown_left()
	_cooldown.visible = left > 0.0
	_cooldown.text = str(ceili(left))
	_sweep.ratio = left / _cd_total if _cd_total > 0.0 else 0.0
	var reason := _lock_reason(left)
	_row.modulate = locked_modulate if reason != &"" else Color.WHITE
	tooltip_text = _tooltip(reason, left)

## Game time, so the seconds hold on Pause and follow x2 and x3.
func _cooldown_left() -> float:
	return maxf(_cd_end - TimeManager.game_time, 0.0)

## Same order as EmergencyRepair.get_denial_reason(), so the HUD names the reason the commander refuses with.
func _lock_reason(left: float) -> StringName:
	if _paused:
		return &"hud.emg.paused"
	if not _commander_mode:
		return &"hud.emg.commander_only"
	if _charges <= 0:
		return &"hud.emg.no_charges"
	if left > 0.0:
		return &"hud.emg.cooldown"
	if _max_hp > 0 and _hp >= _max_hp:
		return &"hud.emg.full_hp"
	return &""

func _tooltip(reason: StringName, left: float) -> String:
	if reason != &"":
		return UiFormat.tr_fmt(reason, {"sec": ceili(left)})
	if _max_hp > 0 and float(_max_hp - _hp) / _max_hp < overheal_hint_pct:
		return tr(&"hud.emg.overheal")
	return tr(&"hud.emg.ready")

func _reset() -> void:
	_charges = GameConfig.emg_repair_charges_start
	_cd_end = 0.0
	_cd_total = GameConfig.emergency_repair_cooldown
	_commander_mode = false
	_show_charges()

func _show_charges() -> void:
	for i in _dots.get_child_count():
		var dot := _dots.get_child(i) as Panel
		dot.add_theme_stylebox_override(&"panel", dot_full if i < _charges else dot_empty)
	_count.text = UiFormat.tr_fmt(&"hud.ratio", {"value": _charges, "max": GameConfig.emg_repair_charges_max})

func _start_cooldown(remaining: float, total: float) -> void:
	_cd_end = TimeManager.game_time + remaining
	_cd_total = maxf(total, remaining)

func _flash_glow() -> void:
	if _glow_tween != null:
		_glow_tween.kill()
	_glow.modulate.a = 1.0
	_glow_tween = create_tween().set_ignore_time_scale()
	_glow_tween.tween_property(_glow, "modulate:a", 0.0, glow_time)

## The cooldown is read as the time left, the same way the Fortress panel reads it.
func _on_state_changed(charges: int, cooldown: float, _heal_pct: float) -> void:
	_charges = charges
	if cooldown > 0.0:
		_start_cooldown(cooldown, GameConfig.emergency_repair_cooldown)
	_show_charges()

func _on_cooldown_changed(skill_id: StringName, remaining: float, total: float) -> void:
	if skill_id == SKILL_ID:
		_start_cooldown(remaining, total)

func _on_charge_granted(charges: int) -> void:
	_charges = charges
	_show_charges()
	_flash_glow()
	EventBus.alert_requested.emit(int(Enums.AlertTier.T3), &"alert.emg_charge",
		{"value": charges, "max": GameConfig.emg_repair_charges_max})

func _on_denied(_reason: StringName) -> void:
	if TimeManager.real_time < _next_denied_glow:
		return
	_next_denied_glow = TimeManager.real_time + denied_glow_gap
	_flash_glow()

func _on_fortress_hp_changed(hp: int, max_hp: int, _delta: int) -> void:
	_hp = hp
	_max_hp = max_hp

func _on_mode_changed(mode: StringName) -> void:
	_commander_mode = mode == COMMANDER

func _on_pause_changed(paused: bool) -> void:
	_paused = paused
