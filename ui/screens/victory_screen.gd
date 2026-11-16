class_name VictoryScreen
extends Control
## Shown once after the summary of the victory wave, while the game is paused for it. One button goes
## on to endless; the screen never closes by itself and has no countdown.

var _sent := false

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _waves: SummaryRow = %WavesRow
@onready var _time: SummaryRow = %TimeRow
@onready var _kills: SummaryRow = %KillsRow
@onready var _gold: SummaryRow = %GoldRow
@onready var _prestige: SummaryRow = %PrestigeRow
@onready var _bosses: SummaryRow = %BossesRow
@onready var _level: SummaryRow = %LevelRow
@onready var _weapons: SummaryRow = %WeaponsRow
@onready var _continue: Button = %ContinueButton

func _ready() -> void:
	visible = false
	_title.text = tr(&"victory.title")
	_continue.text = tr(&"victory.continue")
	_continue.pressed.connect(_on_continue_pressed)
	EventBus.run_victory.connect(_on_run_victory)
	EventBus.run_started.connect(hide)

# TODO(Rawisl): send the run stats with run_victory so the screen does not read them through GameState.run_snapshot().
func _on_run_victory(wave_index: int) -> void:
	show_stats(wave_index, GameState.run_snapshot())

## Kept apart from the signal so the test scene can draw it without a run.
func show_stats(wave_index: int, stats: Dictionary) -> void:
	_sent = false
	_continue.disabled = false
	_subtitle.text = UiFormat.tr_fmt(&"victory.subtitle", {"wave": wave_index})
	_set_row(_waves, stats.get("waves_cleared"), &"run_end.row.waves", _plain)
	_set_row(_time, stats.get("run_elapsed"), &"run_end.row.time", UiFormat.time_mmss)
	_set_row(_kills, stats.get("run_kills"), &"run_end.row.kills", _plain)
	_set_row(_gold, stats.get("run_gold_earned"), &"run_end.row.gold", func(v: int) -> String:
		return UiFormat.tr_fmt(&"run_end.value.gold", {"value": v}))
	_set_row(_prestige, stats.get("prestige_pending"), &"victory.row.prestige", _plain)
	_set_row(_bosses, stats.get("run_bosses_defeated"), &"run_end.row.bosses", _plain)
	_set_row(_level, stats.get("commander_level"), &"run_end.row.level", func(v: int) -> String:
		return UiFormat.tr_fmt(&"panel.tower.level", {"level": v}))
	_set_row(_weapons, stats.get("owned_weapons"), &"victory.row.weapons", _weapons_text)
	visible = true
	_continue.grab_focus()

## One press only: the wave side leaves the victory pause and goes on to rewards or the next PREP.
func _on_continue_pressed() -> void:
	if _sent:
		return
	_sent = true
	_continue.disabled = true
	visible = false
	EventBus.victory_continue_requested.emit()

func _plain(value: Variant) -> String:
	return str(value)

func _set_row(row: SummaryRow, value: Variant, name_key: StringName, format: Callable) -> void:
	row.visible = value != null
	if row.visible:
		row.set_row(tr(name_key), format.call(value))

func _weapons_text(weapons: Array) -> String:
	var names: PackedStringArray = []
	for id: Variant in weapons:
		names.append(tr(StringName("weapon.%s.name" % id)))
	return ", ".join(names)
