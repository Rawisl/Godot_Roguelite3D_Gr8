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
@onready var _clear_row: HBoxContainer = %ClearRow
@onready var _clear_title: Label = %ClearTitle
@onready var _clear_time: Label = %ClearTime

## Fight time of this wave in game time, counted like the wave summary: in combat, from the first
## enemy on. Game time, so x2 and x3 run it faster and Pause stops it.
var _wave_index := 1
var _trial := false
var _clear_seconds := 0.0
var _fighting := false
var _first_spawned := false
var _last_game_time := 0.0

func _ready() -> void:
	_enemies_title.text = tr(&"hud.enemies")
	_clear_title.text = tr(&"hud.clear_time")
	_clear_time.text = UiFormat.time_mmss(0.0)
	_endless.text = tr(&"hud.endless")
	_set_enemies_visible(false)
	EventBus.run_started.connect(_on_run_started)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.hazard_trial_entered.connect(_on_trial_entered)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.enemy_count_changed.connect(_on_enemy_count_changed)
	EventBus.enemy_spawned.connect(func(_enemy: Node) -> void: _first_spawned = true)

func _process(_delta: float) -> void:
	var now := TimeManager.game_time
	if _fighting and _first_spawned:
		_clear_seconds += now - _last_game_time
		_clear_time.text = UiFormat.time_mmss(_clear_seconds)
	_last_game_time = now

func _on_state_changed(new_state: StringName) -> void:
	_trial = new_state == &"HAZARD_TRIAL"
	_write_wave(_wave_index)
	_state.text = tr(STATE_KEYS.get(new_state, &""))
	_fighting = new_state == &"COMBAT" or new_state == &"BOSS_COMBAT"
	_last_game_time = TimeManager.game_time
	_set_enemies_visible(_fighting)

## Enemies left and the fight time sit on two rows of their own, shown together in combat.
func _set_enemies_visible(value: bool) -> void:
	_enemies_row.visible = value
	_clear_row.visible = value

## "Wave N / 30" up to the victory wave, then "Wave N" with the Endless tag.
func _on_wave_started(wave_index: int) -> void:
	_clear_seconds = 0.0
	_first_spawned = false
	_clear_time.text = UiFormat.time_mmss(0.0)
	_wave_index = wave_index
	_write_wave(wave_index)

func _on_trial_entered(wave_index: int, _enemies: Array) -> void:
	_wave_index = wave_index
	_write_wave(wave_index)

func _write_wave(wave_index: int) -> void:
	%TrialHeader.visible = _trial
	%WaveRow.visible = not _trial
	%StatusRow.visible = not _trial
	%TrialWave.text = UiFormat.tr_fmt(&"hud.wave_value", {"wave": wave_index})
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
