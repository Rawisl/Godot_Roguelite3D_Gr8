extends HBoxContainer

const STATE_KEYS := {
	&"PREP": &"hud.state.prep",
	&"COMBAT": &"hud.state.combat",
	&"BOSS_INTRO": &"hud.state.boss_intro",
	&"BOSS_COMBAT": &"hud.state.boss_combat",
	&"SUMMARY": &"hud.state.summary",
}

@onready var _wave: Label = %Wave
@onready var _state: Label = %State
@onready var _countdown: Label = %Countdown
@onready var _enemies_title: Label = %EnemiesTitle
@onready var _enemies: Label = %Enemies

func _ready() -> void:
	_enemies_title.text = tr(&"hud.enemies")
	_countdown.visible = false
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.prep_timer_changed.connect(_on_prep_timer_changed)
	EventBus.enemy_count_changed.connect(_on_enemy_count_changed)

func _on_state_changed(new_state: StringName) -> void:
	_state.text = tr(STATE_KEYS.get(new_state, &""))
	# TODO: clear time in COMBAT and the boss timer.
	_countdown.visible = new_state == &"PREP"

# TODO: show the upcoming wave during PREP once wave_preview_ready is emitted.
func _on_wave_started(wave_index: int) -> void:
	_wave.text = UiFormat.tr_fmt(&"hud.wave_value", {"wave": wave_index})

func _on_prep_timer_changed(remaining: float) -> void:
	_countdown.text = UiFormat.time_mmss(remaining)

func _on_enemy_count_changed(alive: int, queued: int, total: int) -> void:
	_enemies.text = UiFormat.tr_fmt(&"hud.ratio", {"value": alive + queued, "max": total})
