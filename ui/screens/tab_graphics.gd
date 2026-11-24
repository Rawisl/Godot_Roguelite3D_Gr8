extends Control
## Graphics tab: window mode, resolution, VSync and the FPS limit, applied at once. A new window
## mode or resolution must be kept within GameConfig.settings_keep_seconds of real time, or it
## goes back to the old one, so a size the screen cannot show never sticks.
## Below them the quality rows (QualitySettings): a preset sets shadows and the particle limit,
## changing one of those by hand turns the preset to Custom. See-through is its own choice.

const MODE_KEYS: Array[StringName] = [&"settings.gfx.windowed", &"settings.gfx.fullscreen"]
const PRESET_KEYS: Array[StringName] = [&"settings.gfx.preset_low", &"settings.gfx.preset_medium",
		&"settings.gfx.preset_high", &"settings.gfx.preset_custom"]
const SHADOW_KEYS: Array[StringName] = [&"settings.gfx.shadow_off", &"settings.gfx.shadow_low", &"settings.gfx.shadow_high"]
const SEE_THROUGH_KEYS: Array[StringName] = [&"settings.gfx.see_through_dither", &"settings.gfx.see_through_off"]

## Window settings changed since the last Keep, with the value to go back to.
var _revert: Dictionary = {}
var _keep_until := 0.0
var _preset: OptionButton
var _shadow: OptionButton
var _particles: OptionButton
var _see_through: OptionButton

@onready var _mode_label: Label = %WindowModeLabel
@onready var _mode: OptionButton = %WindowMode
@onready var _resolution_label: Label = %ResolutionLabel
@onready var _resolution: OptionButton = %Resolution
@onready var _vsync: CheckButton = %VSync
@onready var _fps_label: Label = %MaxFpsLabel
@onready var _fps: OptionButton = %MaxFps
@onready var _keep_panel: PanelContainer = %KeepPanel
@onready var _countdown: Label = %Countdown
@onready var _time_left: ProgressBar = %TimeLeft
@onready var _keep: Button = %KeepButton
@onready var _undo: Button = %RevertButton

func _ready() -> void:
	# GameState asks this group to go back before it saves on closing the window.
	add_to_group(&"pending_window_change")
	_mode_label.text = tr(&"settings.gfx.window_mode")
	_resolution_label.text = tr(&"settings.gfx.resolution")
	_vsync.text = tr(&"settings.gfx.vsync")
	_fps_label.text = tr(&"settings.gfx.max_fps")
	_keep.text = tr(&"settings.gfx.keep")
	_undo.text = tr(&"settings.gfx.revert")
	for key in MODE_KEYS:
		_mode.add_item(tr(key))
	for size in DisplaySettings.RESOLUTIONS:
		_resolution.add_item(UiFormat.tr_fmt(&"settings.gfx.size", {"w": size.x, "h": size.y}))
	for limit in DisplaySettings.FPS_LIMITS:
		_fps.add_item(tr(&"settings.gfx.fps_none") if limit == 0 else UiFormat.tr_fmt(&"settings.gfx.fps", {"value": limit}))
	_show_current()
	_mode.item_selected.connect(func(i: int) -> void: _change_window(&"window_mode", i))
	_resolution.item_selected.connect(func(i: int) -> void: _change_window(&"resolution", DisplaySettings.RESOLUTIONS[i]))
	_vsync.toggled.connect(func(on: bool) -> void: EventBus.settings_changed.emit(&"vsync", on))
	_fps.item_selected.connect(func(i: int) -> void: EventBus.settings_changed.emit(&"max_fps", DisplaySettings.FPS_LIMITS[i]))
	_add_quality_rows()
	_keep.pressed.connect(keep_changes)
	_undo.pressed.connect(revert_pending)
	_keep_panel.visible = false
	set_process(false)

func _process(_delta: float) -> void:
	var left := _keep_until - TimeManager.real_time
	if left <= 0.0:
		revert_pending()
		return
	_time_left.value = left
	_countdown.text = UiFormat.tr_fmt(&"settings.gfx.revert_countdown", {"seconds": ceili(left)})

## Leaving Settings without Keep counts as no answer.
func revert_pending() -> void:
	for key: StringName in _revert:
		EventBus.settings_changed.emit(key, _revert[key])
	_end_keep()

func keep_changes() -> void:
	_end_keep()

func has_pending() -> bool:
	return not _revert.is_empty()

func _change_window(key: StringName, value: Variant) -> void:
	var old: Variant = DisplaySettings.current(key)
	if old == value:
		return
	if not _revert.has(key):
		_revert[key] = old
	EventBus.settings_changed.emit(key, value)
	_keep_until = TimeManager.real_time + GameConfig.settings_keep_seconds
	_time_left.max_value = GameConfig.settings_keep_seconds
	_keep_panel.visible = true
	set_process(true)
	_process(0.0)

func _end_keep() -> void:
	_revert.clear()
	_keep_panel.visible = false
	set_process(false)
	_show_current()

func _add_quality_rows() -> void:
	var rows := _keep_panel.get_parent()
	_preset = _add_row(rows, &"settings.gfx.preset", PRESET_KEYS.map(func(k: StringName) -> String: return tr(k)))
	_shadow = _add_row(rows, &"settings.gfx.shadows", SHADOW_KEYS.map(func(k: StringName) -> String: return tr(k)))
	_particles = _add_row(rows, &"settings.gfx.particles",
		QualitySettings.PARTICLE_LIMITS.map(func(n: int) -> String: return UiFormat.tr_fmt(&"settings.gfx.particles_value", {"value": n})))
	_see_through = _add_row(rows, &"settings.gfx.see_through", SEE_THROUGH_KEYS.map(func(k: StringName) -> String: return tr(k)))
	# The Keep panel stays last, under every row.
	rows.move_child(_keep_panel, -1)
	_show_quality()
	_preset.item_selected.connect(_on_preset_selected)
	_shadow.item_selected.connect(func(i: int) -> void: _change_quality(&"shadow_quality", QualitySettings.SHADOW_LEVELS[i]))
	_particles.item_selected.connect(func(i: int) -> void: _change_quality(&"particle_limit", QualitySettings.PARTICLE_LIMITS[i]))
	_see_through.item_selected.connect(func(i: int) -> void:
		EventBus.settings_changed.emit(&"see_through", QualitySettings.SEE_THROUGH_STYLES[i]))

## A row like the window rows above: label on the left, a 260 px list on the right.
func _add_row(rows: Node, label_key: StringName, items: Array) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	var label := Label.new()
	label.text = tr(label_key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var list := OptionButton.new()
	list.custom_minimum_size = Vector2(260, 0)
	for item in items:
		list.add_item(item)
	row.add_child(list)
	rows.add_child(row)
	return list

## Custom is only shown, never picked: it keeps the rows as they are.
func _on_preset_selected(index: int) -> void:
	var id: StringName = QualitySettings.PRESET_IDS[index]
	if id == QualitySettings.CUSTOM:
		_show_quality()
		return
	EventBus.settings_changed.emit(&"graphics_preset", id)
	for key: StringName in QualitySettings.PRESETS[id]:
		EventBus.settings_changed.emit(key, QualitySettings.PRESETS[id][key])
	_show_quality()

func _change_quality(key: StringName, value: int) -> void:
	EventBus.settings_changed.emit(key, value)
	var shadow := int(QualitySettings.current(&"shadow_quality"))
	var particles := int(QualitySettings.current(&"particle_limit"))
	EventBus.settings_changed.emit(&"graphics_preset", QualitySettings.preset_for(shadow, particles))
	_show_quality()

func _show_quality() -> void:
	if _preset == null:
		return
	_preset.select(QualitySettings.PRESET_IDS.find(StringName(QualitySettings.current(&"graphics_preset"))))
	_shadow.select(QualitySettings.SHADOW_LEVELS.find(int(QualitySettings.current(&"shadow_quality"))))
	_particles.select(QualitySettings.PARTICLE_LIMITS.find(int(QualitySettings.current(&"particle_limit"))))
	_see_through.select(QualitySettings.SEE_THROUGH_STYLES.find(int(QualitySettings.current(&"see_through"))))

func _show_current() -> void:
	_mode.select(int(DisplaySettings.current(&"window_mode")))
	_resolution.select(maxi(DisplaySettings.RESOLUTIONS.find(DisplaySettings.current(&"resolution")), 0))
	_vsync.set_pressed_no_signal(bool(DisplaySettings.current(&"vsync")))
	_fps.select(maxi(DisplaySettings.FPS_LIMITS.find(int(DisplaySettings.current(&"max_fps"))), 0))
