extends Node
## Account session against the backend: sign up, sign in, sign out, restore the session on
## start and make authenticated REST calls. The password is never stored; only the session
## tokens are, in user://auth.cfg (not in the save file). Methods are coroutines, use await.
##
## Every method returns a Dictionary with "ok" and, on failure, "error" (a code below).
## No user-facing text lives here, the UI maps the codes to strings.

signal session_changed(signed_in: bool)

const AUTH_FILE := "user://auth.cfg"
## Refresh the access token when it has less than this many seconds left.
const REFRESH_MARGIN := 60

const PATH_SIGN_UP := "/auth/v1/signup"
const PATH_SIGN_IN := "/auth/v1/token?grant_type=password"
const PATH_REFRESH := "/auth/v1/token?grant_type=refresh_token"
const PATH_SIGN_OUT := "/auth/v1/logout"
const PATH_DELETE_ACCOUNT := "/rest/v1/rpc/delete_my_account"

const ERR_DISABLED := &"DISABLED"
const ERR_OFFLINE := &"OFFLINE"
const ERR_INVALID_CREDENTIALS := &"INVALID_CREDENTIALS"
const ERR_INVALID_DISPLAY_NAME := &"INVALID_DISPLAY_NAME"
const ERR_EMAIL_TAKEN := &"EMAIL_TAKEN"
const ERR_WEAK_PASSWORD := &"WEAK_PASSWORD"
const ERR_EMAIL_NOT_CONFIRMED := &"EMAIL_NOT_CONFIRMED"
const ERR_RATE_LIMITED := &"RATE_LIMITED"
const ERR_NOT_SIGNED_IN := &"NOT_SIGNED_IN"
const ERR_SERVER := &"SERVER"

var user_id: String = ""
var email: String = ""
var display_name: String = ""

var _access_token: String = ""
var _refresh_token: String = ""
var _expires_at: int = 0
var _refreshing: bool = false
# What the refresh in flight ended with, so callers waiting on it get the same answer.
var _last_refresh: Dictionary = {"ok": true}


func _ready() -> void:
	# Requests must keep running while the game is paused (settings menu, focus loss).
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_signed_in() -> bool:
	return not _access_token.is_empty()


## False when online features are switched off or the config is unusable.
func is_available() -> bool:
	return GameConfig.online_enabled \
			and GameConfig.backend_url.begins_with("https://") \
			and not GameConfig.backend_public_key.is_empty()


func sign_up(new_email: String, password: String, new_display_name: String) -> Dictionary:
	if not is_available():
		return _fail(ERR_DISABLED)
	var trimmed := new_display_name.strip_edges()
	if trimmed.length() < GameConfig.display_name_min_len or trimmed.length() > GameConfig.display_name_max_len:
		return _fail(ERR_INVALID_DISPLAY_NAME)
	var response := await _send(HTTPClient.METHOD_POST, PATH_SIGN_UP, {
		"email": new_email,
		"password": password,
		"data": {"display_name": trimmed},
	})
	if not response["ok"]:
		return _fail(_error_code(response))
	var data: Dictionary = response["data"] if response["data"] is Dictionary else {}
	if data.has("access_token"):
		_store_session(data)
		return {"ok": true, "confirm_email": false}
	# The project asks for email confirmation: an account exists but has no session yet.
	return {"ok": true, "confirm_email": true}


func sign_in(sign_in_email: String, password: String) -> Dictionary:
	if not is_available():
		return _fail(ERR_DISABLED)
	var response := await _send(HTTPClient.METHOD_POST, PATH_SIGN_IN, {
		"email": sign_in_email,
		"password": password,
	})
	if not response["ok"]:
		return _fail(_error_code(response))
	_store_session(response["data"])
	return {"ok": true}


## Local sign-out never waits for the network: the session is dropped first.
func sign_out() -> void:
	var token := _access_token
	_clear_session()
	if token.is_empty() or not is_available():
		return
	await _send(HTTPClient.METHOD_POST, PATH_SIGN_OUT, {}, token)


## Loads the saved session and refreshes it when it is about to expire. Without a usable
## session the player stays a guest. A network failure keeps the saved session for later.
func restore_session() -> Dictionary:
	var file := ConfigFile.new()
	if file.load(AUTH_FILE) != OK or not is_available():
		_forget_memory()
		return {"ok": true, "signed_in": false}
	_access_token = str(file.get_value("session", "access_token", ""))
	_refresh_token = str(file.get_value("session", "refresh_token", ""))
	_expires_at = int(file.get_value("session", "expires_at", 0))
	user_id = str(file.get_value("session", "user_id", ""))
	email = str(file.get_value("session", "email", ""))
	display_name = str(file.get_value("session", "display_name", ""))
	if _access_token.is_empty() or _refresh_token.is_empty():
		_clear_session()
		return {"ok": true, "signed_in": false}
	var result := await _ensure_fresh()
	# Announced once here: tokens were set before the refresh, so it does not announce itself.
	if is_signed_in():
		session_changed.emit(true)
	if not result["ok"]:
		return {"ok": false, "error": result["error"], "signed_in": is_signed_in()}
	return {"ok": true, "signed_in": is_signed_in()}


## Calls the database REST API. path starts with /rest/v1/. With signed_in false the call
## goes out as an anonymous visitor. prefer is the optional Prefer header, for example
## "return=representation" to get the written rows back.
func rest(method: int, path: String, body: Variant = null, signed_in: bool = true, prefer: String = "") -> Dictionary:
	if not is_available():
		return _fail(ERR_DISABLED)
	var token := ""
	if signed_in:
		var fresh := await _ensure_fresh()
		if not fresh["ok"]:
			return fresh
		token = _access_token
		if token.is_empty():
			return _fail(ERR_NOT_SIGNED_IN)
	var response := await _send(method, path, body, token, prefer)
	response["error"] = &"" if response["ok"] else _error_code(response)
	return response


## Deletes the account and everything that belongs to it, then drops the session.
func delete_account() -> Dictionary:
	var response := await rest(HTTPClient.METHOD_POST, PATH_DELETE_ACCOUNT, {})
	if response["ok"]:
		_clear_session()
	return response


func _ensure_fresh() -> Dictionary:
	if not is_signed_in():
		return {"ok": true}
	if Time.get_unix_time_from_system() < _expires_at - REFRESH_MARGIN:
		return {"ok": true}
	if _refreshing:
		while _refreshing:
			await get_tree().process_frame
		return _last_refresh
	_refreshing = true
	var response := await _send(HTTPClient.METHOD_POST, PATH_REFRESH, {
		"refresh_token": _refresh_token,
	})
	if response["ok"]:
		_store_session(response["data"])
		_last_refresh = {"ok": true}
	else:
		var code := _error_code(response)
		# Only a refresh token the server rejects ends the session. Network errors, rate
		# limits and other failures keep it so the player is not signed out for a passing problem.
		if code == ERR_INVALID_CREDENTIALS:
			_clear_session()
		_last_refresh = _fail(code)
	_refreshing = false
	return _last_refresh


func _store_session(data: Dictionary) -> void:
	var was_signed_in := is_signed_in()
	_access_token = str(data.get("access_token", ""))
	_refresh_token = str(data.get("refresh_token", ""))
	_expires_at = int(data.get("expires_at", int(Time.get_unix_time_from_system()) + int(data.get("expires_in", 3600))))
	var user: Dictionary = data["user"] if data.get("user") is Dictionary else {}
	user_id = str(user.get("id", ""))
	email = str(user.get("email", ""))
	var metadata: Dictionary = user["user_metadata"] if user.get("user_metadata") is Dictionary else {}
	display_name = str(metadata.get("display_name", ""))
	var file := ConfigFile.new()
	file.set_value("session", "access_token", _access_token)
	file.set_value("session", "refresh_token", _refresh_token)
	file.set_value("session", "expires_at", _expires_at)
	file.set_value("session", "user_id", user_id)
	file.set_value("session", "email", email)
	file.set_value("session", "display_name", display_name)
	file.save(AUTH_FILE)
	# A token refresh keeps the same session, only a new sign-in is news.
	if not was_signed_in:
		session_changed.emit(true)


func _clear_session() -> void:
	var was_signed_in := is_signed_in()
	_forget_memory()
	if FileAccess.file_exists(AUTH_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTH_FILE))
	if was_signed_in:
		session_changed.emit(false)


func _forget_memory() -> void:
	_access_token = ""
	_refresh_token = ""
	_expires_at = 0
	user_id = ""
	email = ""
	display_name = ""


## One HTTPS request. Returns ok, status (0 when the network failed) and the parsed data.
## Tokens and passwords are never printed.
func _send(method: int, path: String, body: Variant, token: String = "", prefer: String = "") -> Dictionary:
	var headers := PackedStringArray([
		"apikey: %s" % GameConfig.backend_public_key,
		"Content-Type: application/json",
	])
	if not token.is_empty():
		headers.append("Authorization: Bearer %s" % token)
	if not prefer.is_empty():
		headers.append("Prefer: %s" % prefer)
	var request := HTTPRequest.new()
	request.timeout = GameConfig.sync_timeout
	add_child(request)
	var payload := "" if body == null else JSON.stringify(body)
	if request.request(GameConfig.backend_url + path, headers, method, payload) != OK:
		request.queue_free()
		return {"ok": false, "status": 0, "data": null}
	var result: Array = await request.request_completed
	request.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "data": null}
	var status := int(result[1])
	var text := (result[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(text) if not text.is_empty() else null
	return {"ok": status >= 200 and status < 300, "status": status, "data": data}


func _error_code(response: Dictionary) -> StringName:
	var status := int(response.get("status", 0))
	if status == 0:
		return ERR_OFFLINE
	var detail := ""
	if response.get("data") is Dictionary:
		var data: Dictionary = response["data"]
		detail = str(data.get("error_code", data.get("code", "")))
	match detail:
		"invalid_credentials":
			return ERR_INVALID_CREDENTIALS
		"user_already_exists", "email_exists":
			return ERR_EMAIL_TAKEN
		"weak_password":
			return ERR_WEAK_PASSWORD
		"email_not_confirmed":
			return ERR_EMAIL_NOT_CONFIRMED
		"over_request_rate_limit", "over_email_send_rate_limit":
			return ERR_RATE_LIMITED
	if status >= 500:
		return ERR_SERVER
	# A refresh token the server refuses comes back as a plain 400 or 401.
	return ERR_INVALID_CREDENTIALS if status == 400 or status == 401 else StringName("HTTP_%d" % status)


func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "error": code}
