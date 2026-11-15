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
var _saved_auth: PackedByteArray = PackedByteArray()
var _had_auth := false

func _ready() -> void:
	if "--demo" in OS.get_cmdline_user_args():
		GameConfig.backend_url = "https://bbftrwumsajxiwgshnje.supabase.co"
		GameConfig.backend_public_key = "sb_publishable_OuqURJWJg373n3vjoHg7OA_rgtNo1dk"
	_last_progress_ms = Time.get_ticks_msec()
	_backup_auth()
	await _run()
	_restore_auth()
	_finished = true
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	# Output is sent in per-frame batches, quitting at once can drop the last lines.
	await get_tree().create_timer(0.5, true, false, true).timeout
	get_tree().quit(1 if _fail > 0 else 0)

func _process(_delta: float) -> void:
	if _finished or Time.get_ticks_msec() - _last_progress_ms < int(STALL_SECONDS * 1000.0):
		return
	_finished = true
	_restore_auth()
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
	var probe := await AuthService.rest(HTTPClient.METHOD_GET, "/rest/v1/leaderboard?select=user_id&limit=1", null, false)
	if not probe["ok"] and probe["error"] == AuthService.ERR_OFFLINE:
		print("[test] skipped: the backend is unreachable")
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
	var name_c := "tester_c_" + stamp.right(4)

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
	await _test_saves()

	# Sign out and back in.
	await AuthService.sign_out()
	# A fresh name, so the case reaches the email check instead of the name check.
	var taken := await AuthService.sign_up(email_a, password, name_c)
	_check("an email that already exists is refused", not taken["ok"] and taken["error"] == AuthService.ERR_EMAIL_TAKEN)
	# Name checks that create no account.
	var name_used := await AuthService.rest(HTTPClient.METHOD_POST, AuthService.PATH_NAME_AVAILABLE, {"wanted_name": name_a}, false)
	_check("a taken display name is reported (needs 004_unique_display_name.sql)", name_used["ok"] and name_used["data"] == false)
	var name_case := await AuthService.rest(HTTPClient.METHOD_POST, AuthService.PATH_NAME_AVAILABLE, {"wanted_name": name_a.to_upper()}, false)
	_check("display names are case sensitive", name_case["ok"] and name_case["data"] == true)
	var name_taken := await AuthService.sign_up("ew-c-%s@%s" % [stamp, TEST_EMAIL_DOMAIN], password, name_a)
	_check("sign up with a taken name is refused before any account exists", not name_taken["ok"] and name_taken["error"] == AuthService.ERR_DISPLAY_NAME_TAKEN)
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
	var anon_saves := await AuthService.rest(HTTPClient.METHOD_GET, "/rest/v1/saves?select=user_id", null, false)
	_check("guest cannot read saves", not anon_saves["ok"])
	var anon_save_write := await AuthService.rest(HTTPClient.METHOD_POST, "/rest/v1/saves",
			{"user_id": id_a, "revision": 99, "data": {}}, false)
	_check("guest cannot write saves", not anon_save_write["ok"])
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
	var b_reads_save := await AuthService.rest(HTTPClient.METHOD_GET, "/rest/v1/saves?user_id=eq.%s&select=user_id,data" % id_a)
	_check("B cannot read A's save", b_reads_save["ok"] and b_reads_save["data"].is_empty())
	var b_writes_save := await AuthService.rest(HTTPClient.METHOD_PATCH, "/rest/v1/saves?user_id=eq.%s" % id_a,
			{"revision": 999, "data": {}}, true, "return=representation")
	_check("B cannot update A's save", b_writes_save["ok"] and b_writes_save["data"].is_empty())
	var b_inserts_save := await AuthService.rest(HTTPClient.METHOD_POST, "/rest/v1/saves",
			{"user_id": id_a, "revision": 99, "data": {}}, true, "return=representation")
	_check("B cannot insert A's save", not b_inserts_save["ok"])
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
	var impossible := await _submit(40, 100.0, "test")
	_check("40 waves in 100 seconds is refused", not impossible["ok"])
	var below_tolerance := await _submit(10, 148.9, "test")
	_check("10 waves in 148.9 seconds is refused", not below_tolerance["ok"])
	var negative_elapsed := await _submit(0, -0.5, "test")
	_check("wave zero cannot have negative elapsed time", not negative_elapsed["ok"])
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
	await _test_ranking(email_a, email_b, password, name_a, name_b, stamp)

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

# The test signs throwaway accounts in and out, which rewrites the developer's own session file.
func _backup_auth() -> void:
	_had_auth = FileAccess.file_exists(AuthService.AUTH_FILE)
	if _had_auth:
		_saved_auth = FileAccess.get_file_as_bytes(AuthService.AUTH_FILE)

func _restore_auth() -> void:
	if _had_auth:
		var file := FileAccess.open(AuthService.AUTH_FILE, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_saved_auth)
	elif FileAccess.file_exists(AuthService.AUTH_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AuthService.AUTH_FILE))

func _submit(waves: int, elapsed: float, version: String) -> Dictionary:
	var row := {"waves_cleared": waves, "run_elapsed": elapsed, "run_seed": 42, "game_version": version}
	# Eligibility and local-save ordering are covered by the offline runner.
	AuthService._pending_scores.append({"user_id": AuthService.user_id, "saved": true, "summary": {}, "row": row})
	return await AuthService.submit_score()

func _best_waves(id: String) -> int:
	var response := await AuthService.rest(HTTPClient.METHOD_GET, "/rest/v1/leaderboard?user_id=eq.%s&select=waves_cleared" % id)
	if not response["ok"] or response["data"].is_empty():
		return -1
	return int(response["data"][0]["waves_cleared"])


func _test_saves() -> void:
	var api := AccountApi.new()
	var empty := await api.pull_save()
	_check("new account has no cloud save", empty["ok"] and empty["revision"] == 0 and empty["data"].is_empty())
	await _test_invalid_saves()
	var local := {"profile": {"prestige_balance": 42}, "meta": {"levels": {"FORT_HP": 1}},
		"flags": {"tutorial_done": true}, "run_flag": {"run_in_progress": true}}
	# JSON decodes numbers as floats, so compare both sides in the wire format.
	var expected: Dictionary = JSON.parse_string(JSON.stringify(AccountApi.data_for_sync(local)))
	var first := await api.push_save(1, "test-device-a", local)
	_check("save revision 1 is written", first["ok"] and first["revision"] == 1)
	var pulled := await api.pull_save()
	_check("profile, meta and tutorial flag survive round trip", pulled["ok"] and pulled["data"] == expected)
	_check("device and server timestamp survive round trip", pulled["ok"] and pulled["device_id"] == "test-device-a" and not str(pulled["updated_at"]).is_empty())
	var second := await api.push_save(2, "test-device-b", local)
	_check("next write increases revision by one", second["ok"] and second["revision"] == 2)
	var stale := await api.push_save(1, "test-device-a", {})
	var equal := await api.push_save(2, "test-device-a", {})
	_check("older and equal revisions conflict", not stale["ok"] and stale["conflict"] and not equal["ok"] and equal["conflict"])
	pulled = await api.pull_save()
	_check("conflicts preserve data and revision", pulled["ok"] and pulled["revision"] == 2 and pulled["data"] == expected)
	var nullable_device := await AuthService.rest(HTTPClient.METHOD_PATCH,
			"/rest/v1/saves?user_id=eq.%s" % AuthService.user_id, {"revision": 3, "device_id": null})
	pulled = await api.pull_save()
	_check("nullable device_id is normalized to an empty string", nullable_device["ok"] and pulled["ok"] and pulled["device_id"] == "")
	await _test_profile_rename()


func _test_profile_rename() -> void:
	var owner := AuthService.user_id
	var original := AuthService.display_name
	var renamed := original + "x"
	var path := "/rest/v1/leaderboard?user_id=eq.%s&select=display_name,submitted_at" % owner
	var before := await AuthService.rest(HTTPClient.METHOD_GET, path)
	var profile := await AuthService.rest(HTTPClient.METHOD_PATCH,
			"/rest/v1/profiles?user_id=eq.%s" % owner,
			{"display_name": "  " + renamed + "  "}, true, "return=representation")
	_check("profile names are trimmed on write", profile["ok"] and profile["data"][0]["display_name"] == renamed)
	var after := await AuthService.rest(HTTPClient.METHOD_GET, path)
	_check("profile rename updates leaderboard name", after["ok"] and after["data"][0]["display_name"] == renamed)
	_check("profile rename preserves ranking timestamp", before["ok"] and after["ok"] and before["data"][0]["submitted_at"] == after["data"][0]["submitted_at"])
	await AuthService.rest(HTTPClient.METHOD_PATCH,
			"/rest/v1/profiles?user_id=eq.%s" % owner, {"display_name": original})


func _test_invalid_saves() -> void:
	var cases: Array[Dictionary] = [
		{"name": "negative revision", "revision": -1, "data": {}},
		{"name": "non-object save", "data": []},
		{"name": "null save", "data": null},
		{"name": "negative prestige", "data": {"profile": {"prestige_balance": -1}}},
		{"name": "negative max wave", "data": {"profile": {"max_wave_cleared": -1}}},
		{"name": "overflowing prestige", "data": {"profile": {"prestige_balance": 1.0e20}}},
		{"name": "fractional count", "data": {"profile": {"max_wave_cleared": 1.5}}},
		{"name": "wrong count type", "data": {"profile": {"prestige_balance": "100"}}},
		{"name": "negative meta level", "data": {"meta": {"levels": {"FORT_HP": -1}}}},
		{"name": "oversized payload", "data": {"profile": {"extra": "x".repeat(1048577)}}},
	]
	for id in MetaUpgrades.get_max_levels():
		cases.append({"name": "excessive level " + id,
			"data": {"meta": {"levels": {id: MetaUpgrades.get_max_levels()[id] + 1}}}})
	for invalid in cases:
		var response := await AuthService.rest(HTTPClient.METHOD_POST, "/rest/v1/saves",
				{"user_id": AuthService.user_id, "revision": invalid.get("revision", 1), "data": invalid["data"]})
		_check("server rejects " + invalid["name"], not response["ok"] and int(response.get("status", 0)) in [400, 413])


func _test_ranking(email_a: String, email_b: String, password: String, name_a: String, name_b: String, stamp: String) -> void:
	var previous_version := GameConfig.game_version
	GameConfig.game_version = "rank_" + stamp
	await AuthService.sign_in(email_a, password)
	await _submit(10, 150.0, GameConfig.game_version)
	await AuthService.sign_in(email_b, password)
	await _submit(10, 150.0, GameConfig.game_version)
	var board := await AuthService.fetch_leaderboard(50)
	_check("earlier server submission wins equal waves and time", board["ok"] and board["rows"].size() == 2 and board["rows"][0]["display_name"] == name_a and board["own"].get("rank") == 2)
	var fastest := await _submit(10, 149.0, GameConfig.game_version)
	_check("10 waves in 149 seconds is accepted with tolerance", fastest["ok"])
	board = await AuthService.fetch_leaderboard(1)
	_check("faster time wins equal waves", board["ok"] and board["rows"].size() == 1 and board["rows"][0]["display_name"] == name_b and board["own"].get("rank") == 1)
	await _submit(11, 200.0, GameConfig.game_version)
	board = await AuthService.fetch_leaderboard(50)
	_check("more waves beats faster time", board["ok"] and board["rows"][0]["waves_cleared"] == 11)
	await AuthService.sign_in(email_a, password)
	board = await AuthService.fetch_leaderboard(1)
	_check("own rank is returned outside requested top", board["ok"] and board["rows"].size() == 1 and board["own"].get("rank") == 2)
	GameConfig.game_version += "_other"
	board = await AuthService.fetch_leaderboard(50)
	_check("version filter excludes other runs", board["ok"] and board["rows"].is_empty() and board["own"].is_empty())
	GameConfig.game_version = previous_version
	await AuthService.sign_in(email_b, password)
	var duplicate := await AuthService.rest(HTTPClient.METHOD_PATCH,
			"/rest/v1/profiles?user_id=eq.%s" % AuthService.user_id,
			{"display_name": name_a}, true, "return=representation")
	var detail: Dictionary = duplicate["data"] if duplicate.get("data") is Dictionary else {}
	_check("unique index rejects duplicate display names", not duplicate["ok"] and detail.get("code") == "23505")
	if duplicate["ok"]:
		await AuthService.rest(HTTPClient.METHOD_PATCH,
				"/rest/v1/profiles?user_id=eq.%s" % AuthService.user_id, {"display_name": name_b})

func _check(label: String, ok: bool) -> void:
	_last_step = label
	_last_progress_ms = Time.get_ticks_msec()
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("[test] %s %s" % [label, "OK" if ok else "FAIL"])
