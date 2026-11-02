extends MarginContainer

const LOGIN_SCENE := preload("res://ui/screens/login.tscn")
const CONFIRM_DIALOG := preload("res://ui/screens/confirm_dialog.tscn")
const DRAWER_SLIDE_TIME := 0.2

var _drawer_open := false
var _drawer_tween: Tween

@onready var _title: Label = %Title
@onready var _play: Button = %Play
@onready var _meta_shop: Button = %MetaShop
@onready var _settings: Button = %Settings
@onready var _account: Button = %Account
@onready var _account_hint: Label = %AccountHint
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
	_account.text = tr(&"menu.account")
	_quit.text = tr(&"menu.quit")
	_play.pressed.connect(GameState.change_state.bind(GameState.AppState.RUN_LOADING))
	_meta_shop.pressed.connect(GameState.change_state.bind(GameState.AppState.META_SHOP))
	_settings.pressed.connect(GameState.change_state.bind(GameState.AppState.SETTINGS))
	_account.pressed.connect(_on_account_pressed)
	AuthService.session_changed.connect(_on_session_changed)
	GameState.session_restore_failed.connect(_show_restore_problem)
	_refresh_account()
	_show_restore_problem(GameState.session_restore_error)
	_quit.pressed.connect(get_tree().quit)
	_drawer_toggle.tooltip_text = tr(&"menu.stats_toggle")
	_drawer_toggle.pressed.connect(_toggle_drawer)
	for button: Button in [_play, _meta_shop, _settings, _account, _quit, _drawer_toggle]:
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

## Opens over the menu on the dialog layer, so Esc and the dimmed backdrop work like a dialog.
func _open_login() -> void:
	var login := LOGIN_SCENE.instantiate()
	if ScreenManager.open_dialog(login):
		login.tree_exited.connect(_on_login_closed)

## Keyboard focus comes back to the button that opened the form.
func _on_login_closed() -> void:
	if _account.is_inside_tree():
		_account.grab_focus()

## Hidden when online features are off. Signed in, the button names the account.
func _refresh_account() -> void:
	_account.visible = AuthService.is_available()
	if AuthService.is_signed_in():
		_account.text = UiFormat.tr_fmt(&"menu.account_signed_in", {"name": _account_name()})
	else:
		_account.text = tr(&"menu.account")

func _account_name() -> String:
	return AuthService.email if AuthService.display_name.is_empty() else AuthService.display_name

func _on_account_pressed() -> void:
	if AuthService.is_signed_in():
		_confirm_sign_out()
	else:
		_open_login()

# TODO(WhoKeng): move sign out to the Account tab in Settings once it exists.
func _confirm_sign_out() -> void:
	var dialog := CONFIRM_DIALOG.instantiate()
	dialog.setup(&"dialog.sign_out.title", &"dialog.sign_out.body", {"name": _account_name()})
	dialog.set_buttons(&"dialog.sign_out.confirm")
	dialog.confirmed.connect(_sign_out)
	if ScreenManager.open_dialog(dialog):
		dialog.tree_exited.connect(_on_login_closed)

## The session is dropped locally first, so the menu updates without waiting for the network.
func _sign_out() -> void:
	AuthService.sign_out()

func _on_session_changed(_signed_in: bool) -> void:
	_account_hint.visible = false
	_refresh_account()

## Offline with a saved session keeps the player signed in; any other failure means guest.
func _show_restore_problem(error: StringName) -> void:
	_account_hint.visible = error != &""
	if error == &"":
		return
	var offline := error == AuthService.ERR_OFFLINE and AuthService.is_signed_in()
	_account_hint.text = tr(&"menu.account_offline" if offline else &"menu.account_expired")
	_refresh_account()
