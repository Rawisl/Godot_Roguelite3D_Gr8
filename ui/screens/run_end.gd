extends MarginContainer
## Run end for both results: a defeat, or survived after the victory wave (endless). Each row
## hides while the summary does not carry its key, like the wave summary.

const SURVIVED := &"SURVIVED"
## Barricade only blocks, so it never counts as the tower that dealt the most damage.
const NOT_A_DAMAGE_TOWER := &"barricade"

@onready var _result: Label = %Result
@onready var _cause: Label = %Cause
@onready var _victory_badge: Label = %VictoryBadge
@onready var _record_badge: Label = %RecordBadge
@onready var _run_heading: Label = %RunHeading
@onready var _prestige_heading: Label = %PrestigeHeading
@onready var _waves: RunEndRow = %WavesRow
@onready var _time: RunEndRow = %TimeRow
@onready var _kills: RunEndRow = %KillsRow
@onready var _commander_kills: RunEndRow = %CommanderKillsRow
@onready var _gold: RunEndRow = %GoldRow
@onready var _bosses: RunEndRow = %BossesRow
@onready var _level: RunEndRow = %LevelRow
@onready var _top_tower: RunEndRow = %TopTowerRow
@onready var _collected: RunEndRow = %CollectedRow
@onready var _rate: RunEndRow = %RateRow
@onready var _start_mult: RunEndRow = %StartMultRow
@onready var _gain: RunEndRow = %GainRow
@onready var _balance: RunEndRow = %BalanceRow
@onready var _unlocks: RunEndRow = %UnlocksRow
@onready var _play_again: Button = %PlayAgain
@onready var _meta_shop: Button = %MetaShop
@onready var _main_menu: Button = %MainMenu

func _ready() -> void:
	_run_heading.text = tr(&"run_end.section.run")
	_prestige_heading.text = tr(&"run_end.section.prestige")
	_record_badge.text = tr(&"run_end.badge.record")
	_play_again.text = tr(&"run_end.play_again")
	_meta_shop.text = tr(&"menu.meta_shop")
	_main_menu.text = tr(&"run_end.main_menu")
	_play_again.pressed.connect(_go.bind(GameState.AppState.RUN_LOADING))
	_meta_shop.pressed.connect(_go.bind(GameState.AppState.META_SHOP))
	_main_menu.pressed.connect(_go.bind(GameState.AppState.MAIN_MENU))
	# The save has already added this run when the screen opens, so the balance is the new one.
	var profile := SaveManager.get_section(&"profile")
	show_summary(GameState.last_run_end_type, GameState.last_run_summary, int(profile.get("prestige_balance", -1)))
	_play_again.grab_focus()

## Kept apart from _ready so the test scene can draw any summary. A balance below 0 hides its row.
func show_summary(end_type: StringName, summary: Dictionary, balance: int) -> void:
	var survived: bool = StringName(summary.get("run_result", &"")) == SURVIVED
	var wave := int(summary.get("wave_index", summary.get("waves_cleared", 0)))
	_result.text = UiFormat.tr_fmt(&"run_end.result.survived" if survived else &"run_end.result.defeat", {"wave": wave})
	_cause.visible = end_type != &""
	if _cause.visible:
		_cause.text = UiFormat.tr_fmt(&"run_end.cause_survived" if survived else &"run_end.cause",
			{"cause": tr(StringName("run_end.type." + String(end_type).to_lower()))})
	_victory_badge.visible = survived
	_victory_badge.text = UiFormat.tr_fmt(&"run_end.badge.victory", {"wave": GameConfig.victory_wave})
	# TODO(Ender-Via): add new_record (bool) to the run end summary, true when waves_cleared beats the saved best for this start wave.
	_record_badge.visible = bool(summary.get("new_record", false))

	_set_row(_waves, summary.get("waves_cleared"), &"run_end.row.waves", _plain)
	_set_row(_time, summary.get("run_elapsed"), &"run_end.row.time", UiFormat.time_mmss)
	_set_row(_kills, summary.get("run_kills"), &"run_end.row.kills", _plain)
	_set_row(_commander_kills, summary.get("run_commander_kills"), &"run_end.row.commander_kills", _plain)
	_set_row(_gold, summary.get("run_gold_earned"), &"run_end.row.gold", func(v: int) -> String:
		return UiFormat.tr_fmt(&"run_end.value.gold", {"value": v}))
	_set_row(_bosses, summary.get("run_bosses_defeated"), &"run_end.row.bosses", _plain)
	_set_row(_level, summary.get("commander_level"), &"run_end.row.level", func(v: int) -> String:
		return UiFormat.tr_fmt(&"panel.tower.level", {"level": v}))
	# TODO(Ender-Via): add damage_by_tower_type ({tower_id: damage}) to the run end summary; the row stays hidden until then.
	_set_row(_top_tower, _top_tower_of(summary.get("damage_by_tower_type", {})), &"run_end.row.top_tower", func(top: Array) -> String:
		return UiFormat.tr_fmt(&"run_end.value.top_tower", {"name": tr(StringName("tower." + String(top[0]))), "damage": top[1]}))

	_set_row(_collected, summary.get("prestige_pending"), &"run_end.row.collected", func(v: int) -> String:
		return _collected_text(v, int(summary.get("wave_prestige_buffer", 0))))
	_set_row(_rate, GameConfig.conversion_rate, &"run_end.row.rate", func(v: float) -> String:
		return UiFormat.tr_fmt(&"run_end.value.percent", {"value": UiFormat.num(v * 100.0)}))
	_set_row(_start_mult, summary.get("start_mult"), &"run_end.row.start_mult", func(v: float) -> String:
		return UiFormat.tr_fmt(&"run_end.value.mult", {"value": UiFormat.num(v, 2)}))
	_set_row(_gain, summary.get("prestige_gain"), &"run_end.row.gain", func(v: int) -> String:
		return UiFormat.tr_fmt(&"summary.value.plus", {"value": v}))
	_set_row(_balance, balance if balance >= 0 else null, &"run_end.row.balance", _plain)
	# TODO(Ender-Via): add unlocked_starts (start waves opened by this run) to the run end summary; the row stays hidden until then.
	var unlocked: Array = summary.get("unlocked_starts", [])
	_set_row(_unlocks, null if unlocked.is_empty() else unlocked, &"run_end.row.unlocks", func(v: Array) -> String:
		return UiFormat.tr_fmt(&"run_end.value.unlocks", {"waves": ", ".join(v.map(func(w: Variant) -> String: return str(w)))}))

## Esc goes to MainMenu.
func go_back() -> void:
	_go(GameState.AppState.MAIN_MENU)

## Accepts one press only and locks the buttons until the screen changes.
func _go(state: GameState.AppState) -> void:
	if GameState.change_state(state):
		for button in [_play_again, _meta_shop, _main_menu]:
			button.disabled = true

func _plain(value: Variant) -> String:
	return str(value)

func _set_row(row: RunEndRow, value: Variant, name_key: StringName, format: Callable) -> void:
	row.visible = value != null
	if row.visible:
		row.set_row(tr(name_key), format.call(value))

## [tower_id, damage] of the tower type that dealt the most damage, or null when none did.
func _top_tower_of(damage_by_type: Dictionary) -> Variant:
	var best: Variant = null
	for type: Variant in damage_by_type:
		var damage := int(damage_by_type[type])
		if StringName(type) == NOT_A_DAMAGE_TOWER or damage <= 0:
			continue
		if best == null or damage > int(best[1]):
			best = [StringName(type), damage]
	return best

## The prestige of the waves already summed up, plus the share of the unfinished wave.
func _collected_text(pending: int, buffer: int) -> String:
	if buffer <= 0:
		return str(pending)
	return UiFormat.tr_fmt(&"run_end.value.collected", {"pending": pending, "buffer": buffer,
		"ratio": UiFormat.num(GameConfig.prestige_buffer_ratio * 100.0)})
