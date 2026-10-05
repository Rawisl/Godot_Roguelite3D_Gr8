extends PanelContainer
## Settings (SCR-05, 4.6). From MainMenu it is a screen; from Pause it is an
## overlay and the run stays frozen (SET-05).

signal closed

const TAB_KEYS := [&"settings.tab.gameplay", &"settings.tab.controls", &"settings.tab.audio",
		&"settings.tab.graphics", &"settings.tab.accessibility", &"settings.tab.data"]

var is_overlay: bool = false

@onready var _tabs: TabContainer = %Tabs
@onready var _back: Button = %Back
@onready var _title: Label = %Title

func _ready() -> void:
	_title.text = tr(&"menu.settings")
	for i in TAB_KEYS.size():
		_tabs.set_tab_title(i, tr(TAB_KEYS[i]))
	_back.text = tr(&"menu.back")
	_back.pressed.connect(go_back)
	_back.grab_focus()

## Back and Esc do the same (SCR-13).
## TODO(SET-06): save settings.cfg when leaving the screen.
func go_back() -> void:
	if is_overlay:
		closed.emit()
	else:
		GameState.change_state(GameState.AppState.MAIN_MENU)
