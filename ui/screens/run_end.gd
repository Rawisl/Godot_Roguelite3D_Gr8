extends MarginContainer
## RunEnd (SCR-11). Full 3.2.4 fields come in week 11.

@onready var _result: Label = %Result
@onready var _play_again: Button = %PlayAgain
@onready var _meta_shop: Button = %MetaShop
@onready var _main_menu: Button = %MainMenu

func _ready() -> void:
	_result.text = tr(StringName("run_end.type." + String(GameState.last_run_end_type).to_lower()))
	_play_again.text = tr(&"run_end.play_again")
	_meta_shop.text = tr(&"menu.meta_shop")
	_main_menu.text = tr(&"run_end.main_menu")
	_play_again.pressed.connect(_go.bind(GameState.AppState.RUN_LOADING))
	_meta_shop.pressed.connect(_go.bind(GameState.AppState.META_SHOP))
	_main_menu.pressed.connect(_go.bind(GameState.AppState.MAIN_MENU))
	_play_again.grab_focus()

## Esc goes to MainMenu (SCR-13).
func go_back() -> void:
	_go(GameState.AppState.MAIN_MENU)

## Accept one press only and lock the buttons until the screen changes (END-04).
func _go(state: GameState.AppState) -> void:
	if GameState.change_state(state):
		for button in [_play_again, _meta_shop, _main_menu]:
			button.disabled = true
