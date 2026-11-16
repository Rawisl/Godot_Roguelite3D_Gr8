extends Control
## Account tab in Settings: who is signed in (or "Guest"), the sync state, and Sign in, Sign out
## and Sync now. Sign out asks first; the session is dropped locally, so the tab updates at once.

const LOGIN_SCENE := preload("res://ui/screens/login.tscn")
const CONFIRM_DIALOG := preload("res://ui/screens/confirm_dialog.tscn")

@onready var _account_title: Label = %AccountTitle
@onready var _account: Label = %AccountValue
@onready var _email: Label = %EmailValue
@onready var _sync_title: Label = %SyncTitle
@onready var _sync_status: SyncStatus = %SyncStatus
@onready var _sign_in: Button = %SignIn
@onready var _sign_out: Button = %SignOut
@onready var _sync_now: Button = %SyncNow
@onready var _offline_note: Label = %OfflineNote

func _ready() -> void:
	_account_title.text = tr(&"account.title")
	_sync_title.text = tr(&"account.sync")
	_sign_in.text = tr(&"menu.account")
	_sign_out.text = tr(&"dialog.sign_out.confirm")
	_sync_now.text = tr(&"account.sync_now")
	_offline_note.text = tr(&"account.offline")
	_sign_in.pressed.connect(_open_login)
	_sign_out.pressed.connect(_confirm_sign_out)
	_sync_now.pressed.connect(_sync)
	AuthService.session_changed.connect(_on_session_changed)
	EventBus.sync_state_changed.connect(func(_state: StringName, _detail: String) -> void: refresh())
	# The last state of a sync arrives while it is still busy, so the end of the sync refreshes too.
	SyncService.busy_changed.connect(func(_busy: bool) -> void: refresh())
	refresh()

func refresh() -> void:
	var available := AuthService.is_available()
	var signed_in := AuthService.is_signed_in()
	_offline_note.visible = not available
	_account.text = _account_name() if signed_in else tr(&"account.guest")
	_email.visible = signed_in and AuthService.email != ""
	_email.text = AuthService.email
	_sign_in.visible = available and not signed_in
	_sign_out.visible = signed_in
	_sync_now.visible = signed_in
	# One sync at a time; the state badge says when it is done.
	_sync_now.disabled = SyncService.is_busy()

func _account_name() -> String:
	return AuthService.email if AuthService.display_name.is_empty() else AuthService.display_name

func _open_login() -> void:
	var login := LOGIN_SCENE.instantiate()
	ScreenManager.open_dialog(login)

func _confirm_sign_out() -> void:
	var dialog := CONFIRM_DIALOG.instantiate()
	dialog.setup(&"dialog.sign_out.title", &"dialog.sign_out.body", {"name": _account_name()})
	dialog.set_buttons(&"dialog.sign_out.confirm")
	dialog.confirmed.connect(AuthService.sign_out)
	ScreenManager.open_dialog(dialog)

func _sync() -> void:
	SyncService.sync_now()

func _on_session_changed(_signed_in: bool) -> void:
	refresh()
