extends Control
## Boss intro card: the boss name and what it is immune to in its first phase. Shown while the
## wave is in BOSS_INTRO. It never takes the mouse, so Pause and the camera pan stay usable.

## Bosses the card can show; the first one stands in until the wave says which boss it is.
@export var bosses: Array[BossData] = []

var _boss_id := &""

@onready var _name: Label = %BossName
@onready var _immune_row: HBoxContainer = %ImmuneRow
@onready var _immune: Label = %Immune

func _ready() -> void:
	visible = false
	# TODO(Ender-Via): enter BOSS_INTRO before a boss wave and emit boss_intro_started(boss_id) when it starts.
	EventBus.boss_intro_started.connect(_on_boss_intro_started)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.run_started.connect(func() -> void: _boss_id = &"")

func _on_boss_intro_started(boss_id: StringName) -> void:
	_boss_id = boss_id
	if visible:
		_fill()

func _on_state_changed(new_state: StringName) -> void:
	visible = new_state == &"BOSS_INTRO"
	if visible:
		_fill()

func _fill() -> void:
	var data := BossInfo.find(bosses, _boss_id)
	_name.text = tr(data.display_name_key) if data != null else ""
	var names := BossInfo.immune_text(data, Enums.BossPhase.ARMORED)
	_immune_row.visible = names != ""
	_immune.text = UiFormat.tr_fmt(&"hud.boss.immune", {"types": names})
