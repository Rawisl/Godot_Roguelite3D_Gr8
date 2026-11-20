extends MarginContainer
## Fortress HP. At or under the low HP threshold the bar gets a blinking red border and a tag,
## so the warning does not rely on colour alone. In PREP it also says how to fix it: repair with
## Mithril, or win a Hazard Trial first when there is no Mithril.

## Same threshold the Fortress uses for its low HP alert.
@export var stats: FortressStats = preload("res://data/config/fortress_stats.tres")
## One full blink (fade out and back), in real seconds.
@export var blink_period := 0.6
## In the Hazard Trial room the Fortress does not change, so its bar fades back.
@export var room_modulate := Color(1, 1, 1, 0.45)

var _low := false
var _prep := false
var _mithril := 0
var _reduce_flash := false
var _blink: Tween

@onready var _title: Label = %Title
@onready var _bar: ProgressBar = %Bar
@onready var _value: Label = %Value
@onready var _low_tag: Label = %LowTag
@onready var _low_border: Panel = %LowBorder
@onready var _hint_box: PanelContainer = %RepairHintBox
@onready var _hint: Label = %RepairHint

func _ready() -> void:
	_title.text = tr(&"hud.fortress")
	_low_tag.text = tr(&"hud.fortress_low")
	_reduce_flash = bool(GameState.get_setting(&"reduce_flash", false))
	_refresh_low()
	_prep = GameState.wave_state == &"PREP"
	_refresh_hint()
	EventBus.fortress_hp_changed.connect(_on_hp_changed)
	EventBus.mithril_changed.connect(func(value: int, _delta: int) -> void:
		_mithril = value
		_refresh_hint())
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.state_changed.connect(_on_state_changed)

func _on_hp_changed(hp: int, max_hp: int, _delta: int) -> void:
	_bar.max_value = max_hp
	_bar.value = hp
	_value.text = UiFormat.tr_fmt(&"hud.ratio", {"value": hp, "max": max_hp})
	var low := max_hp > 0 and float(hp) / max_hp <= stats.low_hp_warning_pct
	if low != _low:
		_low = low
		_refresh_low()
		_refresh_hint()

## Real time, so it keeps blinking on Pause. With reduced flashing the border stays solid.
func _refresh_low() -> void:
	_low_tag.visible = _low
	_low_border.visible = _low
	if _blink != null:
		_blink.kill()
		_blink = null
	_low_border.modulate.a = 1.0
	if _low and not _reduce_flash:
		_blink = create_tween().set_ignore_time_scale()
		_blink.tween_property(_low_border, "modulate:a", 0.2, blink_period * 0.5)
		_blink.tween_property(_low_border, "modulate:a", 1.0, blink_period * 0.5)

func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"reduce_flash":
		_reduce_flash = bool(value)
		_refresh_low()

func _on_state_changed(new_state: StringName) -> void:
	modulate = room_modulate if new_state == &"HAZARD_TRIAL" else Color.WHITE
	_prep = new_state == &"PREP"
	_refresh_hint()

func _refresh_hint() -> void:
	_hint_box.visible = _low and _prep
	_hint.text = tr(&"hud.fortress_hint" if _mithril > 0 else &"hud.fortress_hint_hazard")
