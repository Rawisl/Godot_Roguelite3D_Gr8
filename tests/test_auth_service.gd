extends Node
## Manual test for AuthService against the dev backend: sign up, sign in, sign out, session
## restore, and row level security with two throwaway accounts. Needs network and the backend
## SQL applied. Not shipped. Run with F6, prints OK/FAIL per case then quits. The two test
## accounts delete themselves at the end.

# Some projects reject example.com addresses; use another domain here if sign-up is refused.
const TEST_EMAIL_DOMAIN := "example.com"

# Network calls time out on their own, this only catches a test that stops making progress.
const STALL_SECONDS := 30.0

var _pass := 0
var _fail := 0
var _last_step := "start"
var _last_progress_ms := 0
var _finished := false

func _ready() -> void:
	_last_progress_ms = Time.get_ticks_msec()
	await _run()
	_finished = true
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	# Output is sent in per-frame batches, quitting at once can drop the last lines.
	await get_tree().create_timer(0.5, true, false, true).timeout
	get_tree().quit(1 if _fail > 0 else 0)

func _process(_delta: float) -> void:
	if _finished or Time.get_ticks_msec() - _last_progress_ms < int(STALL_SECONDS * 1000.0):
		return
	_finished = true
	print("[test] STUCK, no progress after: %s" % _last_step)
	print("[test] done: %d passed, %d failed (unfinished)" % [_pass, _fail + 1])
	await get_tree().create_timer(0.5, true, false, true).timeout
	get_tree().quit(1)

func _run() -> void:
	_check("online config is usable", AuthService.is_available())
	_check("config holds only a publishable key", GameConfig.backend_public_key.begins_with("sb_publishable_"))
	_check("backend url is https", GameConfig.backend_url.begins_with("https://"))
	if not AuthService.is_available():
		return

	DirAccess.remove_absolute(ProjectSettings.globalize_path(AuthService.AUTH_FILE))
	var restored := await AuthService.restore_session()
	_check("no saved session means guest", restored["ok"] and not restored["signed_in"])

	var stamp := str(int(Time.get_unix_time_from_system())).right(6) + str(randi() % 100)
	var password := "Tmp-%d-pass!" % randi()
	var email_a := "ew-a-%s@%s" % [stamp, TEST_EMAIL_DOMAIN]
	var email_b := "ew-b-%s@%s" % [stamp, TEST_EMAIL_DOMAIN]
	var name_a := "tester_a_" + stamp.right(4)
	var name_b := "tester_b_" + stamp.right(4)

	# Client side checks before any request leaves the machine.
	var bad_name := await AuthService.sign_up(email_a, password, "ab")
	_check("display name shorter than 3 is refused", not bad_name["ok"] and bad_name["error"] == AuthService.ERR_INVALID_DISPLAY_NAME)
	var long_name := await AuthService.sign_up(email_a, password, "x".repeat(17))
	_check("display name longer than 16 is refused", not long_name["ok"] and long_name["error"] == AuthService.ERR_INVALID_DISPLAY_NAME)
	var blank_name := await AuthService.sign_up(email_a, password, "      ")
	_check("display name of spaces is refused", not blank_name["ok"] and blank_name["error"] == AuthService.ERR_INVALID_DISPLAY_NAME)

	# Online features switched off: nothing leaves the machine.
	GameConfig.online_enabled = false
	_check("online switch off makes the service unavailable", not AuthService.is_available())
	var off_in := await AuthService.sign_in(email_a, password)
	_check("sign in is refused while online is off", not off_in["ok"] and off_in["error"] == AuthService.ERR_DISABLED)
	var off_rest := await AuthService.rest(HTTPClient.METHOD_GET, "/rest/v1/leaderboard?select=user_id", null, false)
	_check("REST calls are refused while online is off", not off_rest["ok"] and off_rest["error"] == AuthService.ERR_DISABLED)
	GameConfig.online_enabled = true

	# Account A.
	var up_a := await AuthService.sign_up(email_a, password, name_a)
	_check("sign up A", up_a["ok"])
	if not up_a["ok"]:
		print("[test] sign up error: %s" % up_a["error"])
		return
	if up_a.get("confirm_email", false):
		print("[test] the project asks for email confirmation: turn off Confirm email for the dev project")
		_check("sign up gives a session (confirm email is off)", false)
		return
	_check("signed in after sign up", AuthService.is_signed_in() and AuthService.email == email_a)
	var id_a := AuthService.user_id
	_check("saved session file exists", FileAccess.file_exists(AuthService.AUTH_FILE))

	var profiles := await AuthService.rest(HTTPClient.METHOD_GET, "/rest/v1/profiles?select=user_id,display_name")
	_check("A sees exactly one profile, its own", profiles["ok"] and profiles["data"].size() == 1 and profiles["data"][0]["user_id"] == id_a)
	_check("profile carries the display name", profiles["ok"] and profiles["data"][0]["display_name"] == name_a)

	var blank_rename := await AuthService.rest(HTTPClient.METHOD_PATCH, "/rest/v1/profiles?user_id=eq.%s" % id_a,
			{"display_name": "      "}, true, "return=representation")
	_check("server refuses a display name of spaces (needs 002_display_name_trim.sql)", not blank_rename["ok"])

	var put_a := await _submit(4, 100.0, "test")
	_check("A can write its leaderboard row", put_a["ok"] and put_a["data"].size() == 1 and put_a["data"][0]["user_id"] == id_a)
	_check("server fills the display name", put_a["ok"] and put_a["data"][0]["display_name"] == name_a)

	# Sign out and back in.
	await AuthService.sign_out()
	var taken := await AuthService.sign_up(email_a, password, name_a)
	_check("an email that already exists is refused", not taken["ok"] and taken["error"] == AuthService.ERR_EMAIL_TAKEN)
	_check("signed out", not AuthService.is_signed_in())
	_check("session file is removed", not FileAccess.file_exists(AuthService.AUTH_FILE))
	var wrong := await AuthService.sign_in(email_a, password + "x")
	_check("wrong password is refused", not wrong["ok"] and wrong["error"] == AuthService.ERR_INVALID_CREDENTIALS)
	var in_a := await AuthService.sign_in(email_a, password)
	_check("sign in A again", in_a["ok"] and AuthService.user_id == id_a)
	await AuthService.sign_out()

	# Anonymous visitor.
	var anon_read := await AuthService.rest(HTTPClient.METHOD_GET, "/rest/v1/leaderboard?select=display_name,waves_cleared", null, false)
	_check("guest can read the ranking", anon_read["ok"])
	var anon_profiles := await AuthService.rest(HTTPClient.METHOD_GET, "/rest/v1/profiles?select=user_id", null, false)
	_check("guest cannot read profiles", not anon_profiles["ok"] or anon_profiles["data"].is_empty())
	var anon_write := await AuthService.rest(HTTPClient.METHOD_POST, "/rest/v1/leaderboard",
			{"waves_cleared": 1, "run_elapsed": 100.0, "run_seed": 1, "game_version": "test"}, false)
	_check("guest cannot write the ranking", not anon_write["ok"])

	# Account B must not reach A's data.
	var up_b := await AuthService.sign_up(email_b, password, name_b)
	_check("sign up B", up_b["ok"])
	if not up_b["ok"]:
		return
	var id_b := AuthService.user_id
	var b_profiles := await AuthService.rest(HTTPClient.METHOD_GET, "/rest/v1/profiles?select=user_id")
	_check("B sees only its own profile", b_profiles["ok"] and b_profiles["data"].size() == 1 and b_profiles["data"][0]["user_id"] == id_b)
	var b_reads_a := await AuthService.rest(HTTPClient.METHOD_GET, "/rest/v1/profiles?user_id=eq.%s&select=user_id" % id_a)
	_check("B cannot read A's profile", b_reads_a["ok"] and b_reads_a["data"].is_empty())
	var b_edits_a := await AuthService.rest(HTTPClient.METHOD_PATCH, "/rest/v1/profiles?user_id=eq.%s" % id_a,
			{"display_name": "hacked_name"}, true, "return=representation")
	_check("B cannot rename A", b_edits_a["ok"] and b_edits_a["data"].is_empty())
	var b_posts_as_a := await AuthService.rest(HTTPClient.METHOD_POST, "/rest/v1/leaderboard",
			{"user_id": id_a, "waves_cleared": 1, "run_elapsed": 100.0, "run_seed": 1, "game_version": "test"}, true, "return=representation")
	_check("B cannot insert a row as A", not b_posts_as_a["ok"])
	var b_edits_a_row := await AuthService.rest(HTTPClient.METHOD_PATCH, "/rest/v1/leaderboard?user_id=eq.%s" % id_a,
			{"waves_cleared": 99, "run_elapsed": 99999.0}, true, "return=representation")
	_check("B cannot change A's score", b_edits_a_row["ok"] and b_edits_a_row["data"].is_empty())
	var b_renames := await AuthService.rest(HTTPClient.METHOD_PATCH, "/rest/v1/leaderboard?user_id=eq.%s" % id_b,
			{"display_name": "someone else"}, true, "return=representation")
	_check("display name on the ranking cannot be set by the client", not b_renames["ok"])

	# Score rules.
	var too_fast := await _submit(10, 10.0, "test")
	_check("a run faster than 15 s per wave is refused", not too_fast["ok"])
	var too_many := await _submit(1000, 999999.0, "test")
	_check("waves above the server ceiling are refused", not too_many["ok"])
	var first := await _submit(5, 120.0, "test")
	_check("B first score", first["ok"] and first["data"][0]["waves_cleared"] == 5)
	await _submit(3, 60.0, "test")
	_check("a worse run does not replace the best", await _best_waves(id_b) == 5)
	await _submit(5, 200.0, "test")
	_check("same waves but slower does not replace it", await _best_waves(id_b) == 5)
	await _submit(7, 300.0, "test")
	_check("a better run replaces it", await _best_waves(id_b) == 7)
	await _submit(2, 60.0, "test_v2")
	_check("a new game version starts the row again", await _best_waves(id_b) == 2)

	# Session restore: from file, and with an expired access token.
	var token_before := AuthService._access_token
	AuthService._forget_memory()
	var announced: Array[bool] = []
	var listener := func(signed_in: bool) -> void: announced.append(signed_in)
	AuthService.session_changed.connect(listener)
	var back := await AuthService.restore_session()
	_check("restore brings the session back", back["ok"] and AuthService.user_id == id_b)
	_check("restore announces the session once", announced == [true])
	AuthService.session_changed.disconnect(listener)
	var file := ConfigFile.new()
	file.load(AuthService.AUTH_FILE)
	file.set_value("session", "expires_at", 0)
	file.save(AuthService.AUTH_FILE)
	AuthService._forget_memory()
	var refreshed := await AuthService.restore_session()
	_check("an expired token is refreshed on restore", refreshed["ok"] and AuthService.is_signed_in() and AuthService._access_token != token_before)

	# Clean up both accounts.
	var del_b := await AuthService.delete_account()
	_check("B deletes its account", del_b["ok"] and not AuthService.is_signed_in())
	var gone := await AuthService.sign_in(email_b, password)
	_check("a deleted account cannot sign in", not gone["ok"])
	_last_step = "signing in A to delete it"
	var again := await AuthService.sign_in(email_a, password)
	_check("sign in A for clean up", again["ok"])
	_last_step = "deleting A"
	var del_a := await AuthService.delete_account()
	_check("A deletes its account", del_a["ok"])

func _submit(waves: int, elapsed: float, version: String) -> Dictionary:
	var path := "/rest/v1/leaderboard"
	var method := HTTPClient.METHOD_POST
	var row := {"waves_cleared": waves, "run_elapsed": elapsed, "run_seed": 42, "game_version": version}
	# A second run for the same account updates the existing row.
	var existing := await AuthService.rest(HTTPClient.METHOD_GET, "/rest/v1/leaderboard?user_id=eq.%s&select=user_id" % AuthService.user_id)
	if existing["ok"] and not existing["data"].is_empty():
		method = HTTPClient.METHOD_PATCH
		path += "?user_id=eq.%s" % AuthService.user_id
	return await AuthService.rest(method, path, row, true, "return=representation")

func _best_waves(id: String) -> int:
	var response := await AuthService.rest(HTTPClient.METHOD_GET, "/rest/v1/leaderboard?user_id=eq.%s&select=waves_cleared" % id)
	if not response["ok"] or response["data"].is_empty():
		return -1
	return int(response["data"][0]["waves_cleared"])

func _check(label: String, ok: bool) -> void:
	_last_step = label
	_last_progress_ms = Time.get_ticks_msec()
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("[test] %s %s" % [label, "OK" if ok else "FAIL"])
