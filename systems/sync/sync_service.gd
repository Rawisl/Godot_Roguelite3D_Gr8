extends Node
## Keeps profile, meta and flags (tutorial_done too) in step with the account. It pulls and
## compares after a sign in, and pushes after a run end and after a shop purchase. The local save
## is always written first and nothing here blocks the UI: a failure only shows OFFLINE or ERROR,
## and the next run end or purchase tries again with the latest data. Never runs during a run, so
## the run being played keeps the profile and meta it started with; a sync asked for then goes out
## when the run ends.
# TODO(Rawisl): when the cloud save carries a save_version, refuse to apply or push over a copy newer than SaveManager.SAVE_VERSION in _resolve(), so a newer game's progress is never replaced from this machine.

## A sync started or finished, for the Account tab's Sync now button.
signal busy_changed(busy: bool)

const GUEST := &"GUEST"
const SYNCED := &"SYNCED"
const SYNCING := &"SYNCING"
const OFFLINE := &"OFFLINE"
const ERROR := &"ERROR"
const NOTICE_SCENE := preload("res://ui/screens/notice_dialog.tscn")

var state: StringName = GUEST
## Swapped by tests for a fake with the same pull_save() and push_save().
var api: Variant
## Asks "upload the local profile?" and returns true, false, or null when it could not ask.
## Tests replace it so no dialog opens.
var upload_prompt: Callable

var _busy := false
var _again := false
## A sync asked for during a run, sent when the run ends.
var _held := false
## The account whose empty cloud save the player chose not to fill this session.
var _declined_user := ""

func _ready() -> void:
	api = AccountApi.new()
	upload_prompt = _ask_upload
	AuthService.session_changed.connect(_on_session_changed)
	# Deferred: SaveManager writes the run and the purchase in the same frame, before this reads them.
	EventBus.run_ended.connect(func(_end_type: StringName, _summary: Dictionary) -> void: request_sync.call_deferred())
	EventBus.meta_item_purchased.connect(func(_id: StringName, _level: int) -> void: request_sync.call_deferred())
	GameState.app_state_changed.connect(_on_app_state_changed)

## The Account tab's Sync now.
func sync_now() -> void:
	request_sync()

func request_sync() -> void:
	if not AuthService.is_signed_in():
		_set_state(GUEST)
		return
	if _in_run():
		_held = true
		return
	if _busy:
		_again = true
		return
	_busy = true
	busy_changed.emit(true)
	await _run()
	_busy = false
	busy_changed.emit(false)
	if _again:
		_again = false
		request_sync()

func is_busy() -> bool:
	return _busy

func _run() -> void:
	_set_state(SYNCING)
	var pull: Dictionary = await api.pull_save()
	if not pull.get("ok", false):
		_fail(pull)
		return
	await _resolve(pull)

func _resolve(pull: Dictionary) -> void:
	var local_revision := SaveManager.get_revision()
	var device := SaveManager.get_device_id()
	var cloud_revision := int(pull.get("revision", 0))
	var cloud_device := String(pull.get("device_id", ""))
	var cloud_data: Dictionary = pull.get("data", {})
	var other_device := not cloud_device.is_empty() and cloud_device != device
	var tied_conflict := cloud_revision == local_revision and other_device and SaveManager.has_sync_changes(cloud_data)
	if cloud_revision == 0:
		await _fill_empty_account()
	elif cloud_revision > local_revision or tied_conflict:
		var preserve_local := local_revision > 0 and other_device
		if preserve_local and not _keep_conflict_copy(SaveManager.data, local_revision, device):
			return
		if SaveManager.apply_synced(cloud_data, cloud_revision) == OK:
			_set_state(SYNCED)
			if preserve_local:
				show_other_device_notice()
		else:
			_set_state(ERROR, tr(&"sync.detail.local_write"))
	elif local_revision > cloud_revision:
		if other_device and not _keep_conflict_copy(cloud_data, cloud_revision, cloud_device):
			return
		await _push()
	else:
		_set_state(SYNCED)

func _keep_conflict_copy(data: Dictionary, revision: int, device: String) -> bool:
	if SaveManager.keep_conflict_copy(data, revision, device) == OK:
		return true
	_set_state(ERROR, tr(&"sync.detail.local_write"))
	return false

## An account with no save yet: a machine with progress asks before uploading it.
func _fill_empty_account() -> void:
	if not _has_local_progress():
		_set_state(SYNCED)
		return
	if _declined_user == AuthService.user_id:
		_set_state(OFFLINE, tr(&"sync.detail.not_uploaded"))
		return
	var answer: Variant = await upload_prompt.call()
	if typeof(answer) != TYPE_BOOL:
		_set_state(OFFLINE, tr(&"sync.detail.not_uploaded"))
	elif not answer:
		_declined_user = AuthService.user_id
		_set_state(OFFLINE, tr(&"sync.detail.not_uploaded"))
	else:
		await _push()

func _push() -> void:
	var result: Dictionary = await api.push_save(SaveManager.get_revision(), SaveManager.get_device_id(), SaveManager.data)
	if result.get("ok", false):
		_set_state(SYNCED)
	elif result.get("conflict", false):
		# Another machine wrote in between: pull again once and compare.
		_again = true
	else:
		_fail(result)

func _fail(result: Dictionary) -> void:
	match StringName(result.get("error", &"")):
		AuthService.ERR_NOT_SIGNED_IN:
			_set_state(GUEST)
		AuthService.ERR_OFFLINE:
			_set_state(OFFLINE)
		_:
			_set_state(ERROR)

func _has_local_progress() -> bool:
	var profile := SaveManager.get_section(SaveManager.PROFILE)
	var levels: Dictionary = SaveManager.get_section(SaveManager.META).get("levels", {})
	return int(profile.get("stats", {}).get("total_runs", 0)) > 0 or int(profile.get("prestige_balance", 0)) > 0 \
			or levels.values().any(func(level: Variant) -> bool: return int(level) > 0) \
			or bool(SaveManager.get_section(SaveManager.FLAGS).get("tutorial_done", false))

## The cloud copy replaced this machine's: says so, and where this machine's copy went.
func show_other_device_notice() -> void:
	var dialog := NOTICE_SCENE.instantiate() as NoticeDialog
	dialog.setup(NoticeDialog.INFO, &"dialog.sync_other_device.title", [tr(&"dialog.sync_other_device.line")], [],
		tr(&"dialog.sync_other_device.note"))
	dialog.set_buttons(&"dialog.ok")
	ScreenManager.show_notice_dialog(dialog)

## The account is empty: one line says so, one asks, and each part of the progress is its own row.
func make_upload_dialog() -> NoticeDialog:
	var profile := SaveManager.get_section(SaveManager.PROFILE)
	var dialog := NOTICE_SCENE.instantiate() as NoticeDialog
	dialog.setup(NoticeDialog.INFO, &"dialog.sync_upload.title",
		[tr(&"dialog.sync_upload.line_empty"), tr(&"dialog.sync_upload.line_take")], [
		[tr(&"dialog.sync_upload.row_balance"), str(int(profile.get("prestige_balance", 0)))],
		[tr(&"dialog.sync_upload.row_wave"), str(int(profile.get("max_wave_cleared", 0)))],
		[tr(&"dialog.sync_upload.row_runs"), str(int(profile.get("stats", {}).get("total_runs", 0)))]])
	dialog.set_buttons(&"dialog.sync_upload.confirm", &"dialog.sync_upload.cancel")
	return dialog

## null when there was no answer: another dialog was open, or a screen change closed it. Only a
## press on "Để sau" counts as no for this session.
func _ask_upload() -> Variant:
	var dialog := make_upload_dialog()
	var answer: Array = [null]
	dialog.confirmed.connect(func() -> void: answer[0] = true)
	dialog.cancelled.connect(func() -> void: answer[0] = false)
	if not ScreenManager.open_dialog(dialog):
		return null
	await dialog.tree_exited
	return answer[0]

func _in_run() -> bool:
	return GameState.current == GameState.AppState.RUN

func _set_state(new_state: StringName, detail: String = "") -> void:
	state = new_state
	EventBus.sync_state_changed.emit(new_state, detail)

func _on_session_changed(signed_in: bool) -> void:
	if signed_in:
		request_sync()
	else:
		_set_state(GUEST)

func _on_app_state_changed(new_state: GameState.AppState, _old_state: GameState.AppState) -> void:
	if _held and new_state != GameState.AppState.RUN:
		_held = false
		request_sync()
