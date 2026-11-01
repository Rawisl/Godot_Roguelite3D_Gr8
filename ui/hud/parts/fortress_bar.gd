extends MarginContainer
## Fortress HP. At or under the low HP threshold the bar gets a blinking red border and a tag,
## so the warning does not rely on colour alone.

## Same threshold the Fortress uses for its low HP alert.
@export var stats: FortressStats = preload("res://data/config/fortress_stats.tres")
## One full blink (fade out and back), in real seconds.
@export var blink_period := 0.6

var _low := false
var _reduce_flash := false
var _blink: Tween

@onready var _title: Label = %Title
@onready var _bar: ProgressBar = %Bar
@onready var _value: Label = %Value
@onready var _low_tag: Label = %LowTag
@onready var _low_border: Panel = %LowBorder

func _ready() -> void:
	_title.text = tr(&"hud.fortress")
	_low_tag.text = tr(&"hud.fortress_low")
	_reduce_flash = bool(GameState.get_setting(&"reduce_flash", false))
	_refresh_low()
	EventBus.fortress_hp_changed.connect(_on_hp_changed)
	EventBus.settings_changed.connect(_on_settings_changed)

func _on_hp_changed(hp: int, max_hp: int, _delta: int) -> void:
	_bar.max_value = max_hp
	_bar.value = hp
	_value.text = UiFormat.tr_fmt(&"hud.ratio", {"value": hp, "max": max_hp})
	var low := max_hp > 0 and float(hp) / max_hp <= stats.low_hp_warning_pct
	if low != _low:
		_low = low
		_refresh_low()

## Real time, so it keeps blinking on Pause. With reduced flashing the border stays solid.
func _refresh_low() -> void:
	_low_tag.visible = _low
	_low_border.visible = _low
	if _blink != null:
		_blink.kill()
		_blink = null
	_low_border.modulate.a = 1.0
	if _low and not _reduce_flash:
		_blink = create_tween().set_loops().set_ignore_time_scale()
		_blink.tween_property(_low_border, "modulate:a", 0.2, blink_period * 0.5)
		_blink.tween_property(_low_border, "modulate:a", 1.0, blink_period * 0.5)

func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"reduce_flash":
		_reduce_flash = bool(value)
		_refresh_low()
