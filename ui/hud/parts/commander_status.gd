extends VBoxContainer

signal details_requested

var _pulse: Tween

@onready var _title: Label = %Title
@onready var _bar: ProgressBar = %Bar
@onready var _value: Label = %Value
@onready var _shield: HBoxContainer = %Shield
@onready var _shield_label: Label = %ShieldLabel
@onready var _aura: TextureRect = %AuraIcon

func _ready() -> void:
	_title.text = tr(&"hud.commander")
	_shield_label.text = tr(&"hud.invulnerable")
	_shield.visible = false
	_aura.visible = false
	_aura.tooltip_text = UiFormat.tr_fmt(&"hud.aura.tip", {
		"pct": roundi(GameConfig.frontline_aura_dmg_bonus * 100.0),
		"radius": String.num(GameConfig.frontline_aura_radius, 1)})
	EventBus.commander_low_hp_changed.connect(_set_low)
	EventBus.commander_hp_changed.connect(_on_hp_changed)
	EventBus.mode_changed.connect(_on_mode_changed)
	EventBus.run_started.connect(_on_run_started)
	EventBus.aura_changed.connect(_on_aura_changed)
	EventBus.state_changed.connect(_on_state_changed)

func _on_hp_changed(hp: int, max_hp: int) -> void:
	_bar.max_value = max_hp
	_bar.value = hp
	_value.text = UiFormat.tr_fmt(&"hud.ratio", {"value": hp, "max": max_hp})

func _on_mode_changed(mode: StringName) -> void:
	_shield.visible = mode == &"COMMANDER"

func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"select"):
		details_requested.emit()
		accept_event()

func _set_low(low: bool) -> void:
	%LowTag.visible = low
	%LowBorder.visible = low
	if _pulse != null:
		_pulse.kill()
	%LowBorder.modulate.a = 1.0
	if low and not GameState.get_setting(&"reduce_flash", false):
		_pulse = create_tween().set_ignore_time_scale()
		_pulse.tween_property(%LowBorder, "modulate:a", 0.35, 0.2)
		_pulse.tween_property(%LowBorder, "modulate:a", 1.0, 0.2)

func _on_run_started() -> void:
	_set_low(false)
	_shield.visible = false
	_aura.visible = false

func _on_aura_changed(active: bool) -> void:
	_aura.visible = active

## In the Hazard Trial room the bar shows the room copy's HP, so the title says so.
func _on_state_changed(new_state: StringName) -> void:
	_title.text = tr(&"hud.commander_room") if new_state == &"HAZARD_TRIAL" else tr(&"hud.commander")
