extends Control
## Audio tab: Master, Music, SFX and UI volume, and muting when the window loses focus.
## Each change is broadcast on EventBus.settings_changed right away and AudioManager applies it
## to the buses; saving to settings.cfg happens when the Settings screen closes.
##   volume_master, volume_music, volume_sfx, volume_ui: 0 to 1
##   mute_on_focus_loss: bool

const ROWS: Array[Array] = [
	[&"volume_master", &"settings.audio.master"],
	[&"volume_music", &"settings.audio.music"],
	[&"volume_sfx", &"settings.audio.sfx"],
	[&"volume_ui", &"settings.audio.ui"],
]

@onready var _rows: VBoxContainer = %Rows
@onready var _mute: CheckButton = %MuteOnFocusLoss

func _ready() -> void:
	for row in ROWS:
		_add_slider(row[0], row[1])
	_rows.move_child(_mute, -1)
	_mute.text = tr(&"settings.audio.mute_on_focus_loss")
	_mute.button_pressed = bool(AudioManager.get_setting(&"mute_on_focus_loss"))
	_mute.toggled.connect(func(on: bool) -> void: EventBus.settings_changed.emit(&"mute_on_focus_loss", on))

func _add_slider(key: StringName, label_key: StringName) -> void:
	var row := HBoxContainer.new()
	row.name = String(key)
	row.add_theme_constant_override(&"separation", 24)
	var label := Label.new()
	label.text = tr(label_key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slider := HSlider.new()
	slider.name = "Slider"
	slider.custom_minimum_size = Vector2(260, 0)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = roundf(float(AudioManager.get_setting(key)) * 100.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value := Label.new()
	value.custom_minimum_size = Vector2(56, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.text = "%d%%" % slider.value
	slider.value_changed.connect(func(v: float) -> void:
		value.text = "%d%%" % v
		EventBus.settings_changed.emit(key, v / 100.0))
	row.add_child(label)
	row.add_child(slider)
	row.add_child(value)
	_rows.add_child(row)
