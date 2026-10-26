class_name SummaryPanel
extends Control
## End-of-wave summary. Shown in SUMMARY, continues after 10 s of pausable real time or on Continue.

## Each row hides until the summary data carries its key.
var _summary: Dictionary = {}
var _wave := 0
var _continue_at := -1.0
var _sent := false

@onready var _title: Label = %Title
@onready var _no_data: Label = %NoData
@onready var _columns: HBoxContainer = %Columns
@onready var _battle_heading: Label = %BattleHeading
@onready var _command_heading: Label = %CommandHeading
@onready var _clear_time: SummaryRow = %ClearTimeRow
@onready var _kills: SummaryRow = %KillsRow
@onready var _gold: SummaryRow = %GoldRow
@onready var _early: SummaryRow = %EarlyRow
@onready var _gold_total: SummaryRow = %GoldTotalRow
@onready var _prestige: SummaryRow = %PrestigeRow
@onready var _fortress: SummaryRow = %FortressRow
@onready var _ruined: SummaryRow = %RuinedRow
@onready var _emg: SummaryRow = %EmgRow
@onready var _xp: SummaryRow = %XpRow
@onready var _level: SummaryRow = %LevelRow
@onready var _picks: SummaryRow = %PicksRow
@onready var _countdown: Label = %Countdown
@onready var _continue: Button = %ContinueButton

func _ready() -> void:
	visible = false
	_battle_heading.text = tr(&"summary.section.battle")
	_command_heading.text = tr(&"summary.section.command")
	_no_data.text = tr(&"summary.no_data")
	_continue.text = tr(&"summary.continue")
	_continue.pressed.connect(_request_continue)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.wave_started.connect(func(index: int) -> void: _wave = index)
	EventBus.wave_cleared.connect(func(index: int) -> void: _wave = index)
	# TODO(Ender-Via): emit wave_summary_ready with the keys read below once the summary is saved.
	EventBus.wave_summary_ready.connect(_on_summary_ready)

func _process(_delta: float) -> void:
	if not visible or _sent:
		return
	var left := _continue_at - TimeManager.pausable_real_time
	_countdown.text = UiFormat.tr_fmt(&"summary.auto_continue", {"sec": maxi(0, ceili(left))})
	if left <= 0.0:
		_request_continue()

func _on_state_changed(new_state: StringName) -> void:
	if new_state != &"SUMMARY":
		visible = false
		return
	_summary = {}
	_sent = false
	_continue_at = TimeManager.pausable_real_time + GameConfig.summary_auto_advance
	_continue.disabled = false
	_refresh()
	visible = true

func _on_summary_ready(summary: Dictionary) -> void:
	_summary = summary
	_wave = summary.get("wave_index", _wave)
	_refresh()

# TODO(Ender-Via): listen to summary_continue_requested and go to REWARD_PICK or PREP, instead of the FSM's own timer.
func _request_continue() -> void:
	if _sent:
		return
	_sent = true
	_continue.disabled = true
	EventBus.summary_continue_requested.emit()

func _refresh() -> void:
	_title.text = UiFormat.tr_fmt(&"summary.title", {"wave": _wave})
	var has_data := not _summary.is_empty()
	_no_data.visible = not has_data
	_columns.visible = has_data
	if not has_data:
		return
	_set_row(_clear_time, "clear_time", &"summary.row.clear_time", _clear_time_text)
	_set_row(_kills, "kills_by_type", &"summary.row.kills", _kills_text)
	_set_row(_gold, "gold_base", &"summary.row.gold", func(v: int) -> String:
		return UiFormat.tr_fmt(&"summary.value.gold", {"base": v,
			"mult": UiFormat.decimal(_summary.get("gold_mult", 1.0), 2)}))
	_set_row(_early, "early_call_bonus", &"summary.row.early", func(v: int) -> String:
		return UiFormat.tr_fmt(&"summary.value.gold_total", {"value": v}))
	_set_row(_gold_total, "gold_total", &"summary.row.gold_total", func(v: int) -> String:
		return UiFormat.tr_fmt(&"summary.value.gold_total", {"value": v}))
	_set_row(_prestige, "prestige_gain_wave", &"summary.row.prestige", func(v: int) -> String:
		return UiFormat.tr_fmt(&"summary.value.plus", {"value": v}))
	_set_row(_fortress, "fortress_hp", &"summary.row.fortress", func(v: int) -> String:
		return UiFormat.tr_fmt(&"hud.ratio", {"value": v, "max": _summary.get("fortress_max_hp", v)}))
	_set_row(_ruined, "ruined_towers", &"summary.row.ruined", _ruined_text)
	_set_row(_emg, "emg_repair_gained", &"summary.row.emg", func(v: int) -> String:
		return UiFormat.tr_fmt(&"summary.value.charges", {"value": v}))
	_set_row(_xp, "xp_from_commander", &"summary.row.xp", func(v: int) -> String:
		return UiFormat.tr_fmt(&"summary.value.xp", {"commander": v, "towers": _summary.get("xp_from_towers", 0)}))
	_set_row(_level, "commander_level", &"summary.row.level", func(v: int) -> String:
		return UiFormat.tr_fmt(&"panel.tower.level", {"level": v}))
	_set_row(_picks, "pending_picks", &"summary.row.picks", func(v: int) -> String:
		return UiFormat.tr_fmt(&"summary.value.picks", {"value": v}))

## Hides the row when its key is missing, or when there is nothing to report (no ruined tower, no charge, no early bonus).
func _set_row(row: SummaryRow, key: String, name_key: StringName, format: Callable) -> void:
	var value: Variant = _summary.get(key)
	var shown := value != null
	if shown and key in ["emg_repair_gained", "early_call_bonus"]:
		shown = int(value) > 0
	elif shown and key == "ruined_towers":
		shown = not (value as Array).is_empty()
	row.visible = shown
	if shown:
		row.set_row(tr(name_key), format.call(value))

func _clear_time_text(seconds: float) -> String:
	var text := UiFormat.time_mmss(seconds)
	var tier: String = _summary.get("clear_tier", "")
	return text if tier == "" else text + " · " + tr(StringName("summary.tier." + tier.to_lower()))

func _kills_text(kills: Dictionary) -> String:
	var parts: PackedStringArray = []
	for type: String in kills:
		parts.append(UiFormat.tr_fmt(&"summary.kill_item",
			{"name": tr(StringName("enemy." + type)), "count": kills[type]}))
	return " · ".join(parts)

func _ruined_text(towers: Array) -> String:
	var parts: PackedStringArray = []
	for t: Dictionary in towers:
		parts.append(UiFormat.tr_fmt(&"summary.ruined_item", {
			"name": tr(StringName("tower." + String(t.get("type", "")))),
			"level": t.get("level", 1), "gold": t.get("rebuild_cost", 0)}))
	return " · ".join(parts)
