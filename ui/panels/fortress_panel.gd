class_name FortressPanel
extends PanelContainer
## Fortress HP, the Mithril repair and the Emergency repair status, drawn from EventBus values.
## One Mithril heals a fixed share of max HP. The button stays usable when less is missing
## (the extra is lost), and turns grey with the reason outside PREP, at full HP or without Mithril.

signal closed

const STATS: FortressStats = preload("res://data/config/fortress_stats.tres")
const BUTTON_LOCK_TIME := 0.15

var _hp := 0
var _max_hp := 0
var _mithril := 0
var _charges := 0
var _cd_until := 0.0  # game time when the emergency cooldown ends
var _locked := false

@onready var _title: Label = %Title
@onready var _close: Button = %CloseButton
@onready var _hp_label: Label = %HpLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _mithril_label: Label = %MithrilLabel
@onready var _repair: PanelButton = %RepairMithril
@onready var _emg_label: Label = %EmgLabel
@onready var _emg_cd: Label = %EmgCooldown
@onready var _emg_hint: Label = %EmgHint

func _ready() -> void:
	_charges = GameConfig.emg_repair_charges_start
	_title.text = tr(&"hud.fortress")
	_close.text = tr(&"panel.close")
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(closed.emit)
	_emg_hint.text = tr(&"panel.fortress.emg_hint")
	_emg_label.tooltip_text = tr(&"panel.fortress.emg_tip")
	_emg_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_repair.pressed.connect(_on_repair_pressed)
	EventBus.fortress_hp_changed.connect(_on_hp_changed)
	EventBus.mithril_changed.connect(_on_mithril_changed)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.run_started.connect(_on_run_started)
	EventBus.emergency_repair_state_changed.connect(_on_emg_state_changed)
	EventBus.skill_cooldown_changed.connect(_on_cooldown_changed)

func open() -> void:
	refresh()

func _process(_delta: float) -> void:
	if visible:
		_refresh_emergency()

func refresh() -> void:
	_hp_label.text = UiFormat.tr_fmt(&"panel.tower.hp", {"value": _hp, "max": _max_hp})
	_hp_bar.max_value = maxi(1, _max_hp)
	_hp_bar.value = _hp
	_mithril_label.text = UiFormat.tr_fmt(&"panel.fortress.mithril", {"value": _mithril})
	_refresh_repair()
	_refresh_emergency()

## HP one Mithril gives back at most.
func _heal_per_mithril() -> int:
	return floori(STATS.mithril_repair_pct * _max_hp)

## Empty when the repair can go ahead. Paused PREP still counts as PREP.
func _lock_reason() -> StringName:
	if GameState.wave_state != &"PREP":
		return &"panel.fortress.prep_only"
	if _hp >= _max_hp:
		return &"panel.fortress.full"
	if _mithril <= 0:
		return &"panel.fortress.need_mithril"
	return &""

## Disabled first, so the label takes the right colour.
func _refresh_repair() -> void:
	var reason := _lock_reason()
	_repair.disabled = reason != &""
	var main := UiFormat.tr_fmt(&"panel.fortress.repair_mithril",
		{"pct": roundi(STATS.mithril_repair_pct * 100.0)})
	_repair.set_lines(main, tr(reason) if reason != &"" else "")
	if reason != &"":
		_repair.tooltip_text = tr(reason)
		return
	var missing := _max_hp - _hp
	var heal := mini(_heal_per_mithril(), missing)
	var key := &"panel.fortress.repair_overheal" if missing < _heal_per_mithril() \
		else &"panel.fortress.repair_mithril_tip"
	_repair.tooltip_text = UiFormat.tr_fmt(key, {"hp": heal})

func _refresh_emergency() -> void:
	var max_charges := GameConfig.emg_repair_charges_max
	_emg_label.text = UiFormat.tr_fmt(&"panel.fortress.emg", {"value": _charges, "max": max_charges})
	var left := _cd_until - TimeManager.game_time
	_emg_cd.visible = left > 0.0
	_emg_cd.text = UiFormat.tr_fmt(&"panel.fortress.emg_cd", {"sec": ceili(left)})
	_emg_hint.visible = _charges < max_charges

## The service checks PREP, HP and Mithril again when it runs, so a press on the frame PREP ends is refused.
func _on_repair_pressed() -> void:
	if not _try_lock() or _lock_reason() != &"":
		return
	var service := get_tree().get_first_node_in_group(&"build_service")
	if service != null and service.has_method(&"repair_fortress_mithril"):
		service.call(&"repair_fortress_mithril")
	refresh()

func _on_hp_changed(hp: int, max_hp: int, _delta: int) -> void:
	_hp = hp
	_max_hp = max_hp
	if visible:
		refresh()

func _on_mithril_changed(new_mithril: int, _delta: int) -> void:
	_mithril = new_mithril
	if visible:
		refresh()

func _on_state_changed(_new_state: StringName) -> void:
	if visible:
		refresh()

func _on_run_started() -> void:
	_mithril = 0
	if visible:
		refresh()

func _on_emg_state_changed(charges: int, _cooldown: float, _heal_pct: float) -> void:
	_charges = charges

func _on_cooldown_changed(skill_id: StringName, remaining: float, _total: float) -> void:
	if skill_id == &"emg_repair":
		_cd_until = TimeManager.game_time + remaining

func _try_lock() -> bool:
	if _locked:
		return false
	_locked = true
	_unlock_later()
	return true

func _unlock_later() -> void:
	await TimeManager.wait_real(BUTTON_LOCK_TIME)
	_locked = false
