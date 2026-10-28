class_name FortressPanel
extends PanelContainer
## Fortress HP, gold repairs and the Emergency repair status, drawn from EventBus values.

signal closed

const STATS: FortressStats = preload("res://data/config/fortress_stats.tres")
const BUTTON_LOCK_TIME := 0.15

var _hp := 0
var _max_hp := 0
var _gold := 0
var _charges := 0
var _cd_until := 0.0  # game time when the emergency cooldown ends
var _locked := false

@onready var _title: Label = %Title
@onready var _close: Button = %CloseButton
@onready var _hp_label: Label = %HpLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _small: PanelButton = %RepairSmall
@onready var _large: PanelButton = %RepairLarge
@onready var _full: PanelButton = %RepairFull
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
	_small.pressed.connect(_on_repair_pressed.bind(STATS.repair_step_small_pct))
	_large.pressed.connect(_on_repair_pressed.bind(STATS.repair_step_large_pct))
	_full.pressed.connect(_on_repair_pressed.bind(0.0))
	EventBus.fortress_hp_changed.connect(_on_hp_changed)
	EventBus.gold_changed.connect(_on_gold_changed)
	# TODO(Rawisl): emit emergency_repair_state_changed and skill_cooldown_changed(&"emg_repair") from the commander.
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
	_set_repair(_small, STATS.repair_step_small_pct)
	_set_repair(_large, STATS.repair_step_large_pct)
	_set_repair(_full, 0.0)
	_refresh_emergency()

## step_ratio <= 0 means "to full HP". Disabled first, so the label takes the right colour.
func _set_repair(button: PanelButton, step_ratio: float) -> void:
	var per_pct := STATS.repair_gold_per_pct
	var quote := Fortress.quote_repair(step_ratio * 100.0, _hp, _max_hp, _gold, per_pct)
	var price := Fortress.quote_repair(step_ratio * 100.0, _hp, _max_hp, 1 << 30, per_pct)
	var is_full := _hp >= _max_hp
	button.disabled = quote.heal <= 0
	var main := tr(&"panel.fortress.repair_full") if step_ratio <= 0.0 \
		else UiFormat.tr_fmt(&"panel.fortress.repair_step", {"pct": roundi(step_ratio * 100.0)})
	if not is_full:
		main += " · " + UiFormat.tr_fmt(&"panel.fortress.gold", {"gold": price.cost})
	var warning := ""
	if is_full:
		warning = tr(&"panel.fortress.full")
	elif quote.heal <= 0:
		warning = UiFormat.tr_fmt(&"panel.need_gold", {"gold": _min_cost() - _gold})
	button.set_lines(main, warning)
	button.tooltip_text = "" if quote.heal <= 0 else UiFormat.tr_fmt(&"panel.fortress.repair_tip",
		{"pct": UiFormat.decimal(quote.pct), "gold": quote.cost})

## The buttons stay usable while the gold covers at least 1% (or the whole gap when it is smaller).
func _min_cost() -> int:
	if _max_hp <= 0:
		return 0
	var missing_pct := float(_max_hp - _hp) / float(_max_hp) * 100.0
	return ceili(minf(1.0, missing_pct) * STATS.repair_gold_per_pct - Fortress.PCT_EPSILON)

func _refresh_emergency() -> void:
	var max_charges := GameConfig.emg_repair_charges_max
	_emg_label.text = UiFormat.tr_fmt(&"panel.fortress.emg", {"value": _charges, "max": max_charges})
	var left := _cd_until - TimeManager.game_time
	_emg_cd.visible = left > 0.0
	_emg_cd.text = UiFormat.tr_fmt(&"panel.fortress.emg_cd", {"sec": ceili(left)})
	_emg_hint.visible = _charges < max_charges

func _on_repair_pressed(step_ratio: float) -> void:
	if not _try_lock():
		return
	var service := get_tree().get_first_node_in_group(&"build_service") as BuildService
	# TODO(kiezroth): add BuildService.repair_fortress(step_ratio) that spends the gold and repairs in one call.
	if service == null or not service.has_method(&"repair_fortress"):
		push_warning("FortressPanel: BuildService.repair_fortress() is missing")
		return
	service.call(&"repair_fortress", step_ratio)
	refresh()

func _on_hp_changed(hp: int, max_hp: int, _delta: int) -> void:
	_hp = hp
	_max_hp = max_hp
	if visible:
		refresh()

func _on_gold_changed(gold: int) -> void:
	_gold = gold
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
