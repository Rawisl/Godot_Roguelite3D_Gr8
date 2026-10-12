extends MarginContainer

const DRAWER_SLIDE_TIME := 0.2

var _drawer_open := false
var _drawer_tween: Tween

@onready var _title: Label = %Title
@onready var _play: Button = %Play
@onready var _meta_shop: Button = %MetaShop
@onready var _settings: Button = %Settings
@onready var _quit: Button = %Quit
@onready var _prestige: Label = %Prestige
@onready var _record: Label = %Record
@onready var _drawer_clip: Control = %DrawerClip
@onready var _meta_panel: PanelContainer = %MetaPanel
@onready var _drawer_toggle: Button = %DrawerToggle

func _ready() -> void:
	_title.text = tr(&"menu.title")
	_play.text = tr(&"menu.play")
	_meta_shop.text = tr(&"menu.meta_shop")
	_settings.text = tr(&"menu.settings")
	_quit.text = tr(&"menu.quit")
	_play.pressed.connect(GameState.change_state.bind(GameState.AppState.RUN_LOADING))
	_meta_shop.pressed.connect(GameState.change_state.bind(GameState.AppState.META_SHOP))
	_settings.pressed.connect(GameState.change_state.bind(GameState.AppState.SETTINGS))
	_quit.pressed.connect(get_tree().quit)
	_drawer_toggle.tooltip_text = tr(&"menu.stats_toggle")
	_drawer_toggle.pressed.connect(_toggle_drawer)
	for button: Button in [_play, _meta_shop, _settings, _quit, _drawer_toggle]:
		# Hovering moves keyboard focus too, so only one button is ever highlighted.
		button.mouse_entered.connect(button.grab_focus)
	# TODO: read prestige_balance and max_wave_cleared from SaveManager once it loads the save.
	_show_meta(0, 0)
	_set_drawer(false, false)
	_play.grab_focus()

func _show_meta(prestige: int, max_wave_cleared: int) -> void:
	_prestige.text = UiFormat.tr_fmt(&"menu.prestige", {"value": prestige})
	if max_wave_cleared > 0:
		_record.text = UiFormat.tr_fmt(&"menu.record", {"wave": max_wave_cleared})
	else:
		_record.text = tr(&"menu.record_none")

func _toggle_drawer() -> void:
	_set_drawer(not _drawer_open, true)
	_drawer_toggle.grab_focus()

func _set_drawer(open: bool, animate: bool) -> void:
	_drawer_open = open
	_drawer_toggle.text = "‹" if open else "›"
	# Measured on each call so the panel fits whatever the labels currently say.
	var panel_size := _meta_panel.get_combined_minimum_size()
	_drawer_clip.custom_minimum_size.y = panel_size.y
	var width := panel_size.x if open else 0.0
	if _drawer_tween:
		_drawer_tween.kill()
	if not animate:
		_drawer_clip.custom_minimum_size.x = width
		return
	_drawer_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_drawer_tween.tween_property(_drawer_clip, "custom_minimum_size:x", width, DRAWER_SLIDE_TIME)
