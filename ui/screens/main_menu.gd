extends MarginContainer
## TODO: prestige balance and record labels once SaveManager exists.

@onready var _play: Button = %Play
@onready var _meta_shop: Button = %MetaShop
@onready var _settings: Button = %Settings
@onready var _quit: Button = %Quit

func _ready() -> void:
	_play.text = tr(&"menu.play")
	_meta_shop.text = tr(&"menu.meta_shop")
	_settings.text = tr(&"menu.settings")
	_quit.text = tr(&"menu.quit")
	_play.pressed.connect(GameState.change_state.bind(GameState.AppState.RUN_LOADING))
	_meta_shop.pressed.connect(GameState.change_state.bind(GameState.AppState.META_SHOP))
	_settings.pressed.connect(GameState.change_state.bind(GameState.AppState.SETTINGS))
	_quit.pressed.connect(get_tree().quit)
	_play.grab_focus()
