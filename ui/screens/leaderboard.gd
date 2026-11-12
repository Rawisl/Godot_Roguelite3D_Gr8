extends MarginContainer
## Leaderboard: the top lbd_top_n runs and the player's own rank, with its own line below when it
## is outside the top. Loads when opened and on Refresh; a network error shows a message and
## Retry. Guests see "Sign in to get a rank". With online features off it says it cannot connect.

const LOGIN_SCENE := preload("res://ui/screens/login.tscn")

var _loading := false
var _request := 0

@onready var _title: Label = %Title
@onready var _status: Label = %Status
@onready var _retry: Button = %Retry
@onready var _refresh: Button = %Refresh
@onready var _table: Control = %Table
@onready var _rows: VBoxContainer = %Rows
@onready var _own_box: Control = %OwnBox
@onready var _own_title: Label = %OwnTitle
@onready var _own_row: LeaderboardRow = %OwnRow
@onready var _guest: Button = %SignIn
@onready var _back: Button = %Back
@onready var _header_rank: Label = %HeaderRank
@onready var _header_name: Label = %HeaderName
@onready var _header_waves: Label = %HeaderWaves
@onready var _header_time: Label = %HeaderTime

func _ready() -> void:
	_title.text = tr(&"lbd.title")
	_retry.text = tr(&"lbd.retry")
	_refresh.text = tr(&"lbd.refresh")
	_guest.text = tr(&"lbd.sign_in")
	_own_title.text = tr(&"lbd.own_rank")
	_back.text = tr(&"menu.back")
	_header_rank.text = tr(&"lbd.col.rank")
	_header_name.text = tr(&"lbd.col.name")
	_header_waves.text = tr(&"lbd.col.waves")
	_header_time.text = tr(&"lbd.col.time")
	_back.pressed.connect(go_back)
	_retry.pressed.connect(refresh)
	_refresh.pressed.connect(refresh)
	_guest.pressed.connect(_open_login)
	AuthService.session_changed.connect(_on_session_changed)
	refresh()
	_back.grab_focus()

func go_back() -> void:
	GameState.change_state(GameState.AppState.MAIN_MENU)

## The newest request wins, so a slow answer to an older one never overwrites the table.
func refresh() -> void:
	_request += 1
	var request := _request
	_guest.visible = not AuthService.is_signed_in() and AuthService.is_available()
	if not AuthService.is_available():
		_show_message(&"lbd.offline", false)
		return
	var source := _source()
	if source == null:
		_show_message(&"lbd.error", true)
		return
	_loading = true
	_show_message(&"lbd.loading", false)
	var result: Dictionary = await source.call(&"fetch_leaderboard", GameConfig.lbd_top_n)
	if request != _request:
		return
	_loading = false
	if not result.get("ok", false):
		_show_message(&"lbd.error", true)
		return
	_show_table(result.get("rows", []), result.get("own", {}))

func is_loading() -> bool:
	return _loading

# TODO(Rawisl): add fetch_leaderboard(top_n) to AuthService (or a node in group leaderboard_source) returning {ok, rows, own}: rows are the top runs of this game_version in rank order, own is the signed-in player's line or {} (each line: rank, display_name, waves_cleared, run_elapsed).
func _source() -> Object:
	var node := get_tree().get_first_node_in_group(&"leaderboard_source")
	if node != null and node.has_method(&"fetch_leaderboard"):
		return node
	if AuthService.has_method(&"fetch_leaderboard"):
		return AuthService
	return null

func _show_message(key: StringName, can_retry: bool) -> void:
	_status.visible = true
	_status.text = tr(key)
	_retry.visible = can_retry
	_table.visible = false
	_own_box.visible = false

func _show_table(entries: Array, own: Dictionary) -> void:
	_status.visible = entries.is_empty()
	_status.text = tr(&"lbd.empty")
	_retry.visible = false
	_table.visible = not entries.is_empty()
	var own_rank := int(own.get("rank", 0))
	var rows := _rows.get_children()
	for i in rows.size():
		var row := rows[i] as LeaderboardRow
		row.visible = i < entries.size()
		if row.visible:
			var entry: Dictionary = entries[i]
			row.show_entry(entry, own_rank > 0 and int(entry.get("rank", 0)) == own_rank)
	# Inside the top the player's line is highlighted in the table; outside it gets its own line.
	_own_box.visible = own_rank > entries.size()
	if _own_box.visible:
		_own_row.show_entry(own, true)

func _open_login() -> void:
	var login := LOGIN_SCENE.instantiate()
	ScreenManager.open_dialog(login)

func _on_session_changed(_signed_in: bool) -> void:
	refresh()
