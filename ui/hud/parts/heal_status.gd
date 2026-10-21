extends HBoxContainer
## Heal station status next to the commander HP: the E key, what holding E does right
## now, and how many stations still have HP. Draws only from EventBus signals.

const IDLE := &"IDLE"
const HOLD := &"HOLD"
const HEALING := &"HEALING"
const CANCELLED := &"CANCELLED"
const DEPLETED := &"DEPLETED"
## How long a one-off message (cancelled, depleted, hit) stays, in real time.
const FLASH_TIME := 1.5
## Same width as the commander HP bar above.
const ROW_WIDTH := 280
const FONT_SIZE := 20
const SMALL_FONT_SIZE := 16
const KEYCAP_SIZE := Vector2(36, 36)

var _state: StringName = IDLE
var _progress := 0.0
var _wave_state: StringName = &""
var _commander_mode := false
var _full_hp := false
var _last_hp := -1
var _flash_key: StringName = &""
var _flash_until := 0.0
var _alive := 0

var _status: Label
var _hold_bar: ProgressBar
var _stations: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = ROW_WIDTH
	add_theme_constant_override(&"separation", 10)
	_build()
	# Sent by the heal channel; connected by name until that signal is on main.
	if EventBus.has_signal(&"heal_state_changed"):
		EventBus.connect(&"heal_state_changed", show_heal_state)
	# TODO: call set_stations from heal_tower_hp_changed once the heal tower sends it.
	EventBus.state_changed.connect(_on_wave_state_changed)
	EventBus.mode_changed.connect(_on_mode_changed)
	EventBus.commander_hp_changed.connect(_on_commander_hp_changed)
	set_stations(0, 0)

func _process(_delta: float) -> void:
	if _flash_until > 0.0 and TimeManager.real_time >= _flash_until:
		_flash_until = 0.0
		_refresh()

## Shown only while at least one station exists.
func set_stations(alive: int, total: int) -> void:
	_alive = alive
	visible = total > 0
	_stations.text = UiFormat.tr_fmt(&"hud.heal.stations", {"alive": alive, "total": total})
	_refresh()

func show_heal_state(state: StringName, _source_slot: StringName, hold_progress: float) -> void:
	_state = state
	_progress = hold_progress
	match state:
		HOLD, HEALING:
			_flash_until = 0.0
		DEPLETED:
			_flash(&"hud.heal.depleted")
		CANCELLED:
			# A hit explains the cancel better than "release E", so it is kept.
			if not _is_flashing(&"hud.heal.under_attack"):
				_flash(&"hud.heal.release")
	_refresh()

func _on_wave_state_changed(new_state: StringName) -> void:
	_wave_state = new_state
	_refresh()

func _on_mode_changed(mode: StringName) -> void:
	_commander_mode = mode == &"COMMANDER"
	_refresh()

func _on_commander_hp_changed(hp: int, max_hp: int) -> void:
	if _last_hp >= 0 and hp < _last_hp:
		_flash(&"hud.heal.under_attack")
	_last_hp = hp
	_full_hp = hp >= max_hp
	_refresh()

func _flash(key: StringName) -> void:
	_flash_key = key
	_flash_until = TimeManager.real_time + FLASH_TIME

func _is_flashing(key: StringName) -> bool:
	return _flash_key == key and TimeManager.real_time < _flash_until

# TODO: show seconds left and the heal rate once the heal channel sends them.
func _refresh() -> void:
	if _status == null:
		return
	_hold_bar.visible = _state == HOLD
	_hold_bar.value = _progress
	_status.text = tr(_status_key())

## Active phase first, then a one-off message, then why E would do nothing right now.
func _status_key() -> StringName:
	if _state == HOLD:
		return &"hud.heal.hold"
	if _state == HEALING:
		return &"hud.heal.healing"
	if TimeManager.real_time < _flash_until:
		return _flash_key
	if _commander_mode:
		return &"hud.heal.frontline_only"
	if _wave_state != &"COMBAT" and _wave_state != &"BOSS_COMBAT":
		return &"hud.heal.combat_only"
	if _full_hp:
		return &"hud.heal.full_hp"
	if _alive == 0:
		return &"hud.heal.depleted"
	return &"hud.heal.ready"

func _build() -> void:
	var key := PanelContainer.new()
	key.custom_minimum_size = KEYCAP_SIZE
	# Pinned to the first text line, so a wrapped reason does not push it down.
	key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_theme_stylebox_override(&"panel", _keycap_style())
	var key_label := Label.new()
	key_label.text = tr(&"hud.heal.key")
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	key.add_child(key_label)
	add_child(key)

	# Status, hold bar and station count stack in one column so they always line up.
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 2)
	add_child(column)
	_status = _add_label(column, FONT_SIZE)
	# Long reasons wrap instead of pushing the HUD wider.
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hold_bar = ProgressBar.new()
	_hold_bar.max_value = 1.0
	_hold_bar.show_percentage = false
	_hold_bar.custom_minimum_size = Vector2(0, 8)
	_hold_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_hold_bar)
	_stations = _add_label(column, SMALL_FONT_SIZE)
	# ui_text_dim: secondary info under the status.
	_stations.add_theme_color_override(&"font_color", Color("A9A79F"))

func _add_label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override(&"font_size", font_size)
	parent.add_child(label)
	return label

## Keycap colors from the palette: ui_bg_alt fill, ui_text border.
func _keycap_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2A2F3A")
	style.border_color = Color("F2EFE6")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style
