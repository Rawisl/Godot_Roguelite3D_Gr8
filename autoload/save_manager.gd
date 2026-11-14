extends Node
## The only entry point for player progress. Other systems read and change
## get_section() dictionaries, then call save(); nobody else touches save files.
## Wave SUMMARY, run start, run end and the tutorial go through record_* / mark_tutorial_done().
##
## Missing fields fall back to DEFAULT_DATA, unknown fields are kept and written back.
## The main file, then a leftover .tmp, then the .bak are tried in turn. A save from a newer
## game version, or one where every copy is unreadable, is never overwritten: the game runs
## on defaults in memory and save() refuses until the file is fixed (an unreadable save can
## be replaced with start_new_save()).
# TODO(Rawisl): when account sync lands, write revision (+1 on every successful save), updated_at (UTC) and device_id (generated once per machine) into the envelope in _write(); a missing one means revision 0 and a new device_id.
# TODO(kiezroth): when the save loads with run_flag.run_in_progress true, settle the run as ABANDONED before MainMenu (prestige from prestige_pending), clear the flag, save and tell the player.
# TODO(kiezroth): when meta upgrade data defines a max level per upgrade, clamp meta.levels above that max in _clamp_values() on load.
# TODO(WhoKeng): when the tutorial lands, call SaveManager.mark_tutorial_done() as soon as both starter towers are built or Skip is pressed; it saves the flag and emits tutorial_completed.

signal save_loaded

const SAVE_VERSION := 1

const PROFILE := &"profile"
const META := &"meta"
const RUN_FLAG := &"run_flag"
const FLAGS := &"flags"

const REASON_VERSION_TOO_NEW := &"VERSION_TOO_NEW"
const REASON_CORRUPT := &"CORRUPT"
const REASON_WRITE_BLOCKED := &"WRITE_BLOCKED"
const REASON_WRITE_ERROR := &"WRITE_ERROR"

const SOURCE_DEFAULTS := &"DEFAULTS"
## States during which save() is held back so a write never costs a combat frame.
const COMBAT_STATES: Array[StringName] = [&"COMBAT", &"BOSS_COMBAT"]
const SOURCE_NAMES := {
	SaveRepository.Source.MAIN: &"MAIN",
	SaveRepository.Source.TEMP: &"TEMP",
	SaveRepository.Source.BACKUP: &"BACKUP",
}

## Shape of "data" in endlesswar_save.json. unlocked_starts is not stored, it comes from max_wave_cleared.
const DEFAULT_DATA := {
	"profile": {
		"prestige_balance": 0,
		"max_wave_cleared": 0,
		"best_by_start": {},
		"stats": {"total_runs": 0, "total_kills": 0, "bosses_defeated": 0},
	},
	"meta": {
		"levels": {"FORT_HP": 0, "GOLD_PCT": 0, "CMD_HP": 0, "EMG_REPAIR": 0},
		"unlocks": {},
		"buff_stock": {},
	},
	"run_flag": {
		"run_in_progress": false,
		"start_wave": 1,
		"start_mult": 1.0,
		"waves_cleared": 0,
		"prestige_pending": 0,
	},
	"flags": {"tutorial_done": false},
}

## Copy the current data came from: &"MAIN", &"TEMP", &"BACKUP" or SOURCE_DEFAULTS.
var loaded_from: StringName = SOURCE_DEFAULTS
## Why the last load_save() refused the stored copies: &"" when it did not,
## REASON_CORRUPT or REASON_VERSION_TOO_NEW.
var load_failure: StringName = &""

var repository: SaveRepository
var data: Dictionary = {}
## False after a newer-version or unreadable save was found, so it is not overwritten.
var can_write: bool = true

## Fields outside "data" (revision, device_id, ...) read from the file, written back unchanged.
var _envelope_extras: Dictionary = {}
## True between state_changed(COMBAT / BOSS_COMBAT) and the next state outside combat.
var _in_combat: bool = false
## A save() was held back during combat and still has to be written.
var _save_pending: bool = false
var _request_queued: bool = false
## True after this run's run end was written; cleared when a new run starts, so a repeated run_ended counts once.
var _run_recorded: bool = false

func _ready() -> void:
	set_repository(LocalSaveRepository.new())
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.run_ended.connect(_on_run_ended)
	# abandon_run() can end a run without run_ended, so leaving RUN also ends combat.
	GameState.app_state_changed.connect(_on_app_state_changed)
	load_save()

## A save held back during combat would be lost when the game closes, so write it now.
## The window close request comes first (all listeners still alive); _exit_tree covers
## get_tree().quit(). Clearing _save_pending makes the second call a no-op.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_flush_on_quit()

func _exit_tree() -> void:
	_flush_on_quit()

## Swaps the storage (cloud, test double). Call load_save() afterwards to read from it.
func set_repository(new_repository: SaveRepository) -> void:
	repository = new_repository

## Reads the repository into data. Returns OK also when there is no save yet.
func load_save() -> Error:
	data = DEFAULT_DATA.duplicate(true)
	_envelope_extras = {}
	can_write = true
	loaded_from = SOURCE_DEFAULTS
	load_failure = &""
	_save_pending = false
	var found_any := false
	for source: SaveRepository.Source in [SaveRepository.Source.MAIN,
			SaveRepository.Source.TEMP, SaveRepository.Source.BACKUP]:
		var envelope := repository.load_source(source)
		var source_name: StringName = SOURCE_NAMES[source]
		if repository.last_error == ERR_FILE_NOT_FOUND:
			continue
		found_any = true
		if repository.last_error != OK:
			push_warning("SaveManager: %s copy cannot be read (error %d)" % [source_name, repository.last_error])
			continue
		var version: Variant = envelope.get("save_version")
		if not (version is int or version is float) or int(version) < 1:
			push_warning("SaveManager: %s copy has a missing or invalid save_version" % source_name)
			continue
		if int(version) > SAVE_VERSION:
			# A newer game wrote it: do not fall back to an older copy that would hide it.
			return _refuse_save(REASON_VERSION_TOO_NEW,
					"save_version %d is newer than supported %d" % [int(version), SAVE_VERSION])
		if not envelope.has("checksum"):
			push_warning("SaveManager: %s copy has no checksum, accepted" % source_name)
		elif not SaveChecksum.matches(envelope):
			push_warning("SaveManager: %s copy checksum does not match, skipped" % source_name)
			continue

		var stored: Variant = envelope.get("data", {})
		if stored is Dictionary:
			data = _merge_defaults(stored, DEFAULT_DATA)
		else:
			push_warning("SaveManager: 'data' is not an object, using defaults")
		_clamp_values(data)
		_envelope_extras = envelope.duplicate(true)
		_envelope_extras.erase("save_version")
		_envelope_extras.erase("data")
		# A copied old checksum would no longer match once data changes; _write() computes a new one.
		_envelope_extras.erase("checksum")
		loaded_from = source_name
		# A temp that could not be promoted may be the only good copy: keep it.
		if source == SaveRepository.Source.TEMP and repository.promote_temp() != OK:
			push_warning("SaveManager: could not promote the temp copy to the main file")
		else:
			repository.discard_temp()
		save_loaded.emit()
		return OK
	if not found_any:
		save_loaded.emit()
		return OK
	return _refuse_save(REASON_CORRUPT, "no readable save copy")

## Writes data through the repository. On failure data stays in memory so the caller can retry.
## During combat the write is held back until combat ends and this returns ERR_BUSY.
func save() -> Error:
	if not can_write:
		EventBus.save_failed.emit(REASON_WRITE_BLOCKED)
		return ERR_UNAVAILABLE
	if _in_combat:
		_save_pending = true
		return ERR_BUSY
	return _write()

## Writes immediately, even during combat, for moments where a held-back write is not acceptable.
func save_now() -> Error:
	if not can_write:
		EventBus.save_failed.emit(REASON_WRITE_BLOCKED)
		return ERR_UNAVAILABLE
	var error := _write()
	if error == OK:
		_save_pending = false
	return error

## Run flag at the start of a run. Called by RunLoading.
func record_run_start(start_wave: int, start_mult: float) -> Error:
	_mark_run_in_progress(start_wave, start_mult, start_wave - 1, 0)
	_run_recorded = false
	return save()

## Wave SUMMARY: writes the run flag right away, before the summary is shown, even though combat has not ended yet.
func record_wave_summary(waves_cleared: int, prestige_pending: int, start_wave: int, start_mult: float) -> Error:
	_mark_run_in_progress(start_wave, start_mult, waves_cleared, prestige_pending)
	if not can_write:
		# The data stays in memory; a blocked save is not reported again on every wave.
		return ERR_UNAVAILABLE
	return save_now()

## Run end: adds the run to the profile once and writes right away, also during combat.
func record_run_end(summary: Dictionary) -> Error:
	if summary.is_empty():
		push_warning("SaveManager: run end without a summary, profile unchanged")
		return ERR_INVALID_PARAMETER
	if _run_recorded:
		return ERR_ALREADY_EXISTS
	var waves_cleared := int(summary.get("waves_cleared", 0))
	var start_key := str(int(summary.get("start_wave", 1)))
	var profile := get_section(PROFILE)
	var stats: Dictionary = profile["stats"]
	var best_by_start: Dictionary = profile["best_by_start"]
	profile["prestige_balance"] = int(profile["prestige_balance"]) + maxi(0, int(summary.get("prestige_gain", 0)))
	stats["total_runs"] = int(stats["total_runs"]) + 1
	stats["total_kills"] = int(stats["total_kills"]) + int(summary.get("run_kills", 0))
	stats["bosses_defeated"] = int(stats["bosses_defeated"]) + int(summary.get("run_bosses_defeated", 0))
	profile["max_wave_cleared"] = maxi(int(profile["max_wave_cleared"]), waves_cleared)
	best_by_start[start_key] = maxi(int(best_by_start.get(start_key, 0)), waves_cleared)
	get_section(RUN_FLAG)["run_in_progress"] = false
	_run_recorded = true
	var error := save_now()
	EventBus.prestige_balance_changed.emit(int(profile["prestige_balance"]))
	return error

## Tutorial finished or skipped. Emits tutorial_completed only when the flag changes.
func mark_tutorial_done() -> Error:
	var flags := get_section(FLAGS)
	if flags["tutorial_done"]:
		return OK
	flags["tutorial_done"] = true
	var error := save()
	EventBus.tutorial_completed.emit()
	return error

## Asks for a save without blocking: requests made in the same frame become one write of the latest data.
func request_save() -> void:
	if _request_queued:
		return
	_request_queued = true
	_flush_request.call_deferred()

## Replaces an unreadable save with defaults and keeps the broken copies aside (.corrupt, .corrupt.tmp, .corrupt.bak).
## Refused unless the last load_save() found every copy unreadable.
func start_new_save() -> Error:
	if load_failure != REASON_CORRUPT:
		push_warning("SaveManager: start_new_save() only applies to an unreadable save")
		return ERR_UNAVAILABLE
	repository.quarantine()
	data = DEFAULT_DATA.duplicate(true)
	_envelope_extras = {}
	can_write = true
	load_failure = &""
	loaded_from = SOURCE_DEFAULTS
	_save_pending = false
	var error := _write()
	# data was replaced, so listeners have to read get_section() again.
	save_loaded.emit()
	return error

## Live dictionary of one section (PROFILE, META, RUN_FLAG, FLAGS). Change it, then call save().
## load_save() replaces data, so call this again after save_loaded instead of keeping the dictionary.
func get_section(section: StringName) -> Dictionary:
	# Keys come from JSON, so they are String, not StringName.
	var key := String(section)
	if not data.has(key):
		push_error("SaveManager: unknown section '%s'" % section)
		return {}
	return data[key]

func _refuse_save(reason: StringName, message: String) -> Error:
	push_warning("SaveManager: %s, running on defaults without saving" % message)
	can_write = false
	load_failure = reason
	EventBus.save_failed.emit(reason)
	# The game still runs on defaults, so listeners waiting to build the menu must hear about it.
	save_loaded.emit()
	return ERR_INVALID_DATA

func _mark_run_in_progress(start_wave: int, start_mult: float, waves_cleared: int, prestige_pending: int) -> void:
	var run_flag := get_section(RUN_FLAG)
	run_flag["run_in_progress"] = true
	run_flag["start_wave"] = start_wave
	run_flag["start_mult"] = start_mult
	run_flag["waves_cleared"] = waves_cleared
	run_flag["prestige_pending"] = prestige_pending

func _flush_request() -> void:
	_request_queued = false
	save()

func _write() -> Error:
	var envelope := _envelope_extras.duplicate(true)
	envelope["save_version"] = SAVE_VERSION
	envelope["checksum"] = SaveChecksum.compute(data)
	envelope["data"] = data
	var error := repository.save_data(envelope)
	if error != OK:
		push_error("SaveManager: write failed (error %d)" % error)
		EventBus.save_failed.emit(REASON_WRITE_ERROR)
		return error
	EventBus.save_completed.emit()
	return OK

func _on_state_changed(new_state: StringName) -> void:
	if new_state in COMBAT_STATES:
		_in_combat = true
		return
	_in_combat = false
	_flush_pending()

func _on_run_ended(_end_type: StringName, summary: Dictionary) -> void:
	_in_combat = false
	record_run_end(summary)
	# A duplicate or empty run_ended still writes a save held back in combat.
	_flush_pending()

func _on_app_state_changed(new_state: GameState.AppState, old_state: GameState.AppState) -> void:
	if new_state == GameState.AppState.RUN:
		_run_recorded = false
	if old_state != GameState.AppState.RUN:
		return
	_in_combat = false
	_flush_pending()

## Writes a save still held back by combat when the game closes. Skipped when nothing is pending.
func _flush_on_quit() -> void:
	if not _save_pending or not can_write:
		return
	_save_pending = false
	_write()

## Writes a save held back during combat, once. A failed flush is not retried.
func _flush_pending() -> void:
	if not _save_pending:
		return
	_save_pending = false
	save()

## Fixes impossible values in place and returns the paths of the fields it changed.
func _clamp_values(d: Dictionary) -> PackedStringArray:
	var changed := PackedStringArray()
	_clamp_negative_ints(d, DEFAULT_DATA, "", changed)
	var run_flag: Variant = d.get("run_flag")
	if run_flag is Dictionary:
		if run_flag.get("start_wave", 1) < 1:
			_log_clamp(changed, "run_flag.start_wave", run_flag["start_wave"], 1)
			run_flag["start_wave"] = 1
		if run_flag.get("start_mult", 1.0) <= 0.0:
			_log_clamp(changed, "run_flag.start_mult", run_flag["start_mult"], 1.0)
			run_flag["start_mult"] = 1.0
	# Keys outside the defaults (starting waves, extra meta levels) are still counts.
	var profile: Variant = d.get("profile")
	if profile is Dictionary:
		_clamp_negative_numbers(profile.get("best_by_start"), "profile.best_by_start", changed)
	var meta: Variant = d.get("meta")
	if meta is Dictionary:
		_clamp_negative_numbers(meta.get("levels"), "meta.levels", changed)
	return changed

func _clamp_negative_ints(values: Dictionary, defaults: Dictionary, prefix: String, changed: PackedStringArray) -> void:
	for key in defaults:
		if not values.has(key):
			continue
		var default_value: Variant = defaults[key]
		var field_path := prefix + String(key)
		if default_value is Dictionary:
			if values[key] is Dictionary:
				_clamp_negative_ints(values[key], default_value, field_path + ".", changed)
		elif default_value is int and values[key] is int and values[key] < 0:
			_log_clamp(changed, field_path, values[key], 0)
			values[key] = 0

func _clamp_negative_numbers(values: Variant, field_path: String, changed: PackedStringArray) -> void:
	if not values is Dictionary:
		return
	for key in values:
		var value: Variant = values[key]
		if (value is int or value is float) and value < 0:
			_log_clamp(changed, "%s.%s" % [field_path, key], value, 0)
			values[key] = 0

func _log_clamp(changed: PackedStringArray, field_path: String, from: Variant, to: Variant) -> void:
	changed.append(field_path)
	push_warning("SaveManager: clamped %s from %s to %s" % [field_path, from, to])

## Fills keys missing from stored with defaults and keeps extra keys. JSON reads every
## number as float, so values whose default is an int are turned back into int.
func _merge_defaults(stored: Dictionary, defaults: Dictionary) -> Dictionary:
	var result := stored.duplicate(true)
	for key in defaults:
		var default_value: Variant = defaults[key]
		if not result.has(key):
			result[key] = default_value.duplicate(true) if default_value is Dictionary else default_value
			continue
		var value: Variant = result[key]
		if default_value is Dictionary:
			if value is Dictionary:
				result[key] = _merge_defaults(value, default_value)
			else:
				push_warning("SaveManager: '%s' has the wrong type, using default" % key)
				result[key] = default_value.duplicate(true)
		elif default_value is int and value is float:
			result[key] = int(value)
		elif typeof(value) != typeof(default_value) and not (default_value is float and value is int):
			push_warning("SaveManager: '%s' has the wrong type, using default" % key)
			result[key] = default_value
	return result
