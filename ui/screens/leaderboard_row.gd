class_name LeaderboardRow
extends PanelContainer
## One leaderboard line: rank, display name, waves cleared and run time as mm:ss. The player's
## own line uses its own frame and a "You" tag, so it does not rely on colour alone.

@export var normal_style: StyleBox
@export var own_style: StyleBox

@onready var _rank: Label = %Rank
@onready var _name: Label = %PlayerName
@onready var _you: Label = %YouTag
@onready var _waves: Label = %Waves
@onready var _time: Label = %Time

func _ready() -> void:
	_you.text = tr(&"lbd.you")

## entry: rank, display_name, waves_cleared, run_elapsed (seconds).
func show_entry(entry: Dictionary, is_own: bool) -> void:
	_rank.text = str(int(entry.get("rank", 0)))
	_name.text = str(entry.get("display_name", ""))
	_waves.text = str(int(entry.get("waves_cleared", 0)))
	_time.text = UiFormat.time_mmss(float(entry.get("run_elapsed", 0.0)))
	_you.visible = is_own
	add_theme_stylebox_override(&"panel", own_style if is_own else normal_style)
