extends MarginContainer

@onready var _title: Label = %Title
@onready var _back: Button = %Back

func _ready() -> void:
	_title.text = tr(&"menu.meta_shop")
	_back.text = tr(&"menu.back")
	_back.pressed.connect(go_back)
	_back.grab_focus()

func go_back() -> void:
	GameState.change_state(GameState.AppState.MAIN_MENU)
