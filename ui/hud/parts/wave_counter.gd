extends VBoxContainer

const STATE_KEYS := {
	&"PREP": &"hud.state.prep",
	&"COMBAT": &"hud.state.combat",
	&"BOSS_INTRO": &"hud.state.boss_intro",
	&"BOSS_COMBAT": &"hud.state.boss_combat",
	&"SUMMARY": &"hud.state.summary",
	&"REWARD_PICK": &"hud.state.reward_pick",
	&"HAZARD_TRIAL": &"hud.state.hazard_trial",
}

@onready var _wave: Label = %Wave
@onready var _endless: Label = %EndlessTag
@onready var _state: Label = %State
@onready var _enemies_title: Label = %EnemiesTitle
@onready var _enemies: Label = %Enemies
@onready var _enemies_row: HBoxContainer = %EnemiesRow

func _ready() -> void:
	_enemies_title.text = tr(&"hud.enemies")
	_endless.text = tr(&"hud.endless")
	_set_enemies_visible(false)
	EventBus.run_started.connect(_on_run_started)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.enemy_count_changed.connect(_on_enemy_count_changed)

func _on_state_changed(new_state: StringName) -> void:
	_state.text = tr(STATE_KEYS.get(new_state, &""))
	# TODO(WhoKeng): show the clear time in COMBAT.
	_set_enemies_visible(new_state == &"COMBAT" or new_state == &"BOSS_COMBAT")

func _set_enemies_visible(value: bool) -> void:
	_enemies_row.visible = value

# TODO(Ender-Via): send wave_preview_ready in PREP so the counter can show the upcoming wave.
## "Wave N / 30" up to the victory wave, then "Wave N" with the Endless tag.
func _on_wave_started(wave_index: int) -> void:
	var victory := _victory_wave()
	var endless := victory > 0 and wave_index > victory
	_endless.visible = endless
	if victory > 0 and not endless:
		_wave.text = UiFormat.tr_fmt(&"hud.wave_of", {"wave": wave_index, "max": victory})
	else:
		_wave.text = UiFormat.tr_fmt(&"hud.wave_value", {"wave": wave_index})

## 0 while GameConfig has no victory_wave: the counter then shows the wave number alone.
func _victory_wave() -> int:
	return GameConfig.victory_wave

func _on_enemy_count_changed(alive: int, queued: int, total: int) -> void:
	_enemies.text = UiFormat.tr_fmt(&"hud.ratio", {"value": alive + queued, "max": total})

func _on_run_started() -> void:
	_endless.visible = false
