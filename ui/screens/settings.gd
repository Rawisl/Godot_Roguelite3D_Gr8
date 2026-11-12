extends PanelContainer
## A screen when opened from MainMenu, an overlay when opened from Pause.

signal closed

const TAB_KEYS := [&"settings.tab.gameplay", &"settings.tab.controls", &"settings.tab.audio",
		&"settings.tab.graphics", &"settings.tab.accessibility", &"settings.tab.data", &"settings.tab.account"]
## Tab names for GameState.settings_tab, in the same order as TAB_KEYS.
const TAB_IDS := [&"gameplay", &"controls", &"audio", &"graphics", &"accessibility", &"data", &"account"]

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
	# Opened for one tab (the menu's account button asks for the Account tab), then back to normal.
	var tab := TAB_IDS.find(GameState.settings_tab)
	if tab != -1 and tab < _tabs.get_tab_count():
		_tabs.current_tab = tab
	GameState.settings_tab = &""
	_back.grab_focus()

## TODO(WhoKeng): save settings.cfg when leaving the screen, with the Settings tabs.
func go_back() -> void:
	if is_overlay:
		closed.emit()
	else:
		GameState.change_state(GameState.AppState.MAIN_MENU)
