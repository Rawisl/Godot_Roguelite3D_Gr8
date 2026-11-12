extends Node
## Leaderboard, the Account tab and the sync state, with a fake leaderboard source. Press F6: the
## checks run first and print a summary, then click the window once and use the keys:
## 1: the player outside the top 50. 2: the player inside the top. 3: a network error.
## 4: the next sync state (switches to the Account tab to show it). Tab: board / Account tab.
## Number row or numpad; each key prints what it did in Output.

const SYNC_STATES: Array[StringName] = [&"GUEST", &"SYNCED", &"SYNCING", &"OFFLINE", &"ERROR"]

var _passed := 0
var _failed := 0
var _sync_index := 0

@onready var _fake: Node = $"../FakeServices"
@onready var _board: Control = $"../Leaderboard"
@onready var _account: Control = $"../AccountPanel/TabAccount"
@onready var _account_panel: Control = $"../AccountPanel"

func _ready() -> void:
	await get_tree().process_frame
	await _run_checks()
	_show_board(true)
	_fake.board_mode = "outside"
	_board.refresh()

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code := _key_of(key)
	match code:
		KEY_1, KEY_2, KEY_3:
			_fake.board_mode = {KEY_1: "outside", KEY_2: "inside", KEY_3: "error"}[code]
			_show_board(true)
			_board.refresh()
			print("[key %s] board: player %s" % [OS.get_keycode_string(code), _fake.board_mode])
		KEY_4:
			_show_board(false)
			_sync_index = (_sync_index + 1) % SYNC_STATES.size()
			EventBus.sync_state_changed.emit(SYNC_STATES[_sync_index], "")
			print("[key 4] sync state ", SYNC_STATES[_sync_index])
		KEY_TAB:
			_show_board(not _board.visible)
			print("[key Tab] showing ", "the board" if _board.visible else "the Account tab")

## Numpad digits count as the number row ones.
func _key_of(key: InputEventKey) -> Key:
	if key.keycode >= KEY_KP_0 and key.keycode <= KEY_KP_9:
		return (KEY_0 + (key.keycode - KEY_KP_0)) as Key
	return key.keycode

func _show_board(on: bool) -> void:
	_board.visible = on
	_account_panel.visible = not on


func _run_checks() -> void:
	_show_board(true)
	_fake.board_mode = "outside"
	await _wait_board()
	var board_rows := _board.get_node("%Rows").get_children()
	var shown := board_rows.filter(func(r: Control) -> bool: return r.visible).size()
	_check(shown == GameConfig.lbd_top_n, "the board shows the top %d" % GameConfig.lbd_top_n)
	_check(((board_rows[0] as Control).get_node("%PlayerName") as Label).text == "Player01", "rows show the display name")
	_check((_board.get_node("%OwnBox") as Control).visible, "outside the top: the player's own line shows below")
	_check(((_board.get_node("%OwnRow") as Control).get_node("%Rank") as Label).text == "72", "the own line has the player's rank")
	_check(((board_rows[0] as Control).get_node("%Time") as Label).text == "15:00", "run time shows as mm:ss")
	_fake.board_mode = "inside"
	await _wait_board()
	_check(not (_board.get_node("%OwnBox") as Control).visible, "inside the top: no extra line")
	_check(((board_rows[2] as Control).get_node("%YouTag") as Control).visible, "inside the top: the player's line is tagged")
	_fake.board_mode = "tie"
	await _wait_board()
	_check((_board.get_node("%OwnBox") as Control).visible, "same rank as another player: the own line still shows below")
	_check(not ((board_rows[2] as Control).get_node("%YouTag") as Control).visible, "same rank as another player: that row is not tagged")
	_fake.board_mode = "error"
	await _wait_board()
	_check((_board.get_node("%Retry") as Control).visible and (_board.get_node("%Status") as Label).text == tr(&"lbd.error"), "a network error shows the message and Retry")
	_fake.board_mode = "outside"
	(_board.get_node("%Retry") as Button).pressed.emit()
	await _wait_board(false)
	_check((_board.get_node("%Table") as Control).visible, "Retry loads the board again")
	_check((_board.get_node("%SignIn") as Control).visible == (not AuthService.is_signed_in()), "guests get the sign in button")

	_show_board(false)
	var status := _account.get_node("%SyncStatus") as SyncStatus
	var all_ok := true
	for state in SYNC_STATES:
		EventBus.sync_state_changed.emit(state, "")
		var label := (status.get_node("%StateLabel") as Label).text
		all_ok = all_ok and status.state == state and label == tr(StringName("sync.state.%s" % String(state).to_lower())) \
			and (status.get_node("%Glyph") as SyncGlyph).state == state
	_check(all_ok, "the five sync states each show their icon and name")
	EventBus.sync_state_changed.emit(&"UNKNOWN", "")
	_check(status.state == &"ERROR", "an unknown state shows as an error")
	var signed_in := AuthService.is_signed_in()
	_check((_account.get_node("%SignIn") as Control).visible == (not signed_in) and (_account.get_node("%SignOut") as Control).visible == signed_in,
		"the Account tab offers sign in or sign out")
	_check((_account.get_node("%AccountValue") as Label).text != "", "the Account tab names the account or Guest")

	GameState.settings_tab = &"account"
	var settings := (load("res://ui/screens/settings.tscn") as PackedScene).instantiate()
	add_child(settings)
	_check((settings.get_node("%Tabs") as TabContainer).current_tab == 6 and GameState.settings_tab == &"", "Settings opens on the Account tab once")
	settings.queue_free()
	EventBus.sync_state_changed.emit(&"GUEST", "")
	print("test_leaderboard_account: %d passed, %d failed" % [_passed, _failed])

func _wait_board(start := true) -> void:
	if start:
		_board.refresh()
	while _board.is_loading():
		await get_tree().process_frame

func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		print("  [FAIL] ", label)
