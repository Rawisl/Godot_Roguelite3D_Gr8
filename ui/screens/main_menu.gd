extends MarginContainer

@onready var _title: Label = %Title
@onready var _play: Button = %Play
@onready var _meta_shop: Button = %MetaShop
@onready var _settings: Button = %Settings
@onready var _quit: Button = %Quit
@onready var _prestige: Label = %Prestige
@onready var _record: Label = %Record

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
	for button: Button in [_play, _meta_shop, _settings, _quit]:
		# Hovering moves keyboard focus too, so only one button is ever highlighted.
		button.mouse_entered.connect(button.grab_focus)
	# TODO: read prestige_balance and max_wave_cleared from SaveManager once it loads the save.
	_show_meta(0, 0)
	_play.grab_focus()

func _show_meta(prestige: int, max_wave_cleared: int) -> void:
	_prestige.text = UiFormat.tr_fmt(&"menu.prestige", {"value": prestige})
	if max_wave_cleared > 0:
		_record.text = UiFormat.tr_fmt(&"menu.record", {"wave": max_wave_cleared})
	else:
		_record.text = tr(&"menu.record_none")
