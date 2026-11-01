extends HBoxContainer
## The Tab key with the current mode and the switch cooldown. Pressing Tab during the
## cooldown only flashes the seconds left.

const FRONTLINE := &"FRONTLINE"
const COMMANDER := &"COMMANDER"
const DENIED_COOLDOWN := &"COOLDOWN"

@export var frontline_icon: Texture2D
@export var commander_icon: Texture2D
## One flash of the seconds when Tab is pressed too early, in real seconds.
@export var denied_flash_time := 0.4
## How many times the seconds flash when Tab is pressed too early.
@export var denied_flash_count := 2

var _cooldown_end := 0.0
var _wave_state: StringName = &""
var _reduce_flash := false
var _flash: Tween

@onready var _key_label: Label = %KeyLabel
@onready var _mode_icon: TextureRect = %ModeIcon
@onready var _mode_label: Label = %ModeLabel
@onready var _cooldown: Label = %Cooldown

func _ready() -> void:
	_key_label.text = tr(&"hud.mode.key")
	_reset()
	EventBus.run_started.connect(_reset)
	EventBus.mode_changed.connect(_show_mode)
	EventBus.mode_switch_cooldown_started.connect(_on_cooldown_started)
	EventBus.mode_switch_denied.connect(_on_denied)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.settings_changed.connect(_on_settings_changed)

func _process(_delta: float) -> void:
	var left := _cooldown_left()
	_cooldown.visible = left > 0.0
	if left > 0.0:
		_cooldown.text = UiFormat.tr_fmt(&"hud.mode.cooldown", {"sec": ceili(left)})

## Game time, so the seconds hold on Pause and run faster at x2 and x3 like the cooldown.
## Switching in PREP is free, so no cooldown is shown there.
func _cooldown_left() -> float:
	if _wave_state == &"PREP":
		return 0.0
	return maxf(_cooldown_end - TimeManager.game_time, 0.0)

func _reset() -> void:
	_cooldown_end = 0.0
	_show_mode(FRONTLINE)

func _show_mode(mode: StringName) -> void:
	var commander := mode == COMMANDER
	_mode_icon.texture = commander_icon if commander else frontline_icon
	_mode_label.text = tr(&"hud.mode.commander" if commander else &"hud.mode.frontline")

func _on_cooldown_started(duration: float) -> void:
	_cooldown_end = TimeManager.game_time + duration

func _on_denied(reason: StringName, remaining: float) -> void:
	if reason != DENIED_COOLDOWN:
		return
	_cooldown_end = TimeManager.game_time + remaining
	if _reduce_flash:
		return
	if _flash != null:
		_flash.kill()
	_cooldown.modulate.a = 1.0
	_flash = create_tween().set_loops(denied_flash_count).set_ignore_time_scale()
	_flash.tween_property(_cooldown, "modulate:a", 0.0, denied_flash_time * 0.5)
	_flash.tween_property(_cooldown, "modulate:a", 1.0, denied_flash_time * 0.5)

func _on_state_changed(new_state: StringName) -> void:
	_wave_state = new_state

func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"reduce_flash":
		_reduce_flash = bool(value)
