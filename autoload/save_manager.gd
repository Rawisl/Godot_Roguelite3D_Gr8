extends Node
## The only entry point for player progress. Other systems read and change
## get_section() dictionaries, then call save(); nobody else touches save files.
##
## Missing fields fall back to DEFAULT_DATA, unknown fields are kept and written back.
## A save from a newer game version or an unreadable file is never overwritten:
## the game runs on defaults in memory and save() refuses until the file is fixed.

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

var repository: SaveRepository
var data: Dictionary = {}
## False after a newer-version or unreadable save was found, so it is not overwritten.
var can_write: bool = true

## Fields outside "data" (revision, device_id, ...) read from the file, written back unchanged.
# TODO(week 10): write revision (+1 on every successful save), updated_at (UTC) and device_id
# (generated once per machine) here; a missing one means revision 0 and a new device_id.
var _envelope_extras: Dictionary = {}

func _ready() -> void:
	set_repository(LocalSaveRepository.new())
	load_save()
	# TODO(week 11): when run_flag.run_in_progress is true, settle the run as ABANDONED
	# before MainMenu (prestige from prestige_pending), clear the flag, save and tell the player.

## Swaps the storage (cloud, test double). Call load_save() afterwards to read from it.
func set_repository(new_repository: SaveRepository) -> void:
	repository = new_repository

## Reads the repository into data. Returns OK also when there is no save yet.
func load_save() -> Error:
	data = DEFAULT_DATA.duplicate(true)
	_envelope_extras = {}
	can_write = true
	var envelope := repository.load_data()
	match repository.last_error:
		OK:
			pass
		ERR_FILE_NOT_FOUND:
			save_loaded.emit()
			return OK
		_:
			# TODO(week 10): try save.tmp then save.bak first; if all fail, keep the broken
			# file as .corrupt and offer "New save" instead of only running on defaults.
			return _refuse_save(REASON_CORRUPT, "cannot read save (error %d)" % repository.last_error)

	var version: Variant = envelope.get("save_version")
	if not (version is int or version is float) or int(version) < 1:
		return _refuse_save(REASON_CORRUPT, "save_version is missing or invalid")
	if int(version) > SAVE_VERSION:
		return _refuse_save(REASON_VERSION_TOO_NEW,
				"save_version %d is newer than supported %d" % [int(version), SAVE_VERSION])

	var stored: Variant = envelope.get("data", {})
	if stored is Dictionary:
		# TODO(week 10): clamp impossible values (negative numbers, levels above max) and log them.
		data = _merge_defaults(stored, DEFAULT_DATA)
	else:
		push_warning("SaveManager: 'data' is not an object, using defaults")
	_envelope_extras = envelope.duplicate(true)
	_envelope_extras.erase("save_version")
	_envelope_extras.erase("data")
	# Not computed yet, a copied old checksum would no longer match the data.
	# TODO(week 10): verify the checksum on load and write a fresh one on save.
	_envelope_extras.erase("checksum")
	save_loaded.emit()
	return OK

## Writes data through the repository. On failure data stays in memory so the caller can retry.
## TODO(week 10): call from wave SUMMARY (before the summary shows), RunEnd and shop purchases,
## never during COMBAT; queue writes so requests close together become one write of the latest data.
func save() -> Error:
	if not can_write:
		EventBus.save_failed.emit(REASON_WRITE_BLOCKED)
		return ERR_UNAVAILABLE
	var envelope := _envelope_extras.duplicate(true)
	envelope["save_version"] = SAVE_VERSION
	envelope["data"] = data
	var error := repository.save_data(envelope)
	if error != OK:
		push_error("SaveManager: write failed (error %d)" % error)
		EventBus.save_failed.emit(REASON_WRITE_ERROR)
		return error
	EventBus.save_completed.emit()
	return OK

## Live dictionary of one section (PROFILE, META, RUN_FLAG, FLAGS). Change it, then call save().
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
	EventBus.save_failed.emit(reason)
	return ERR_INVALID_DATA

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
