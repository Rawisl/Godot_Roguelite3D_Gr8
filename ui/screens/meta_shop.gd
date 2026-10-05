extends MarginContainer
## MetaShop (SCR-04). Items come in week 10; Back returns to MainMenu (3.1).

@onready var _title: Label = %Title
@onready var _back: Button = %Back

func _ready() -> void:
	_title.text = tr(&"menu.meta_shop")
	_back.text = tr(&"menu.back")
	_back.pressed.connect(go_back)
	_back.grab_focus()

## Back and Esc do the same (SCR-13).
func go_back() -> void:
	GameState.change_state(GameState.AppState.MAIN_MENU)
