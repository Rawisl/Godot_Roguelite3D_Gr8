class_name LocalSaveRepository
extends SaveRepository
## Stores the envelope as JSON in a single file, user://endlesswar_save.json by default.
## A write goes to a .tmp file first, is read back and checked, the old file is copied to
## .bak, then the .tmp replaces the main file. If that last step fails, the .tmp is kept.

const DEFAULT_PATH := "user://endlesswar_save.json"
const TEMP_EXTENSION := "tmp"
const BACKUP_EXTENSION := "bak"
const CORRUPT_EXTENSION := "corrupt"

var path: String

var _read_error: Error = OK

func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path

## File of one copy: the main path, or the same name with another extension.
func path_of(source: Source) -> String:
	match source:
		Source.TEMP:
			return path.get_basename() + "." + TEMP_EXTENSION
		Source.BACKUP:
			return path.get_basename() + "." + BACKUP_EXTENSION
	return path

## Where a broken copy is kept: <base>.corrupt for the main file, <base>.corrupt.tmp and
## <base>.corrupt.bak for the other two.
func corrupt_path(source: Source = Source.MAIN) -> String:
	var corrupt := path.get_basename() + "." + CORRUPT_EXTENSION
	match source:
		Source.TEMP:
			return corrupt + "." + TEMP_EXTENSION
		Source.BACKUP:
			return corrupt + "." + BACKUP_EXTENSION
	return corrupt

func has_data() -> bool:
	return FileAccess.file_exists(path)

func has_source(source: Source) -> bool:
	return FileAccess.file_exists(path_of(source))

func load_data() -> Dictionary:
	return load_source(Source.MAIN)

func load_source(source: Source) -> Dictionary:
	var envelope := _read_envelope(path_of(source))
	last_error = _read_error
	return envelope

## Writes in four steps so a crash never leaves the main file half written: write .tmp,
## read it back and verify, copy a valid main file to .bak, replace the main file. When the
## replace fails the .tmp stays on disk: it is the newest good copy and load_save() picks it
## up on the next start.
func save_data(envelope: Dictionary) -> Error:
	var dir_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if dir_error != OK:
		return dir_error

	var temp_path := path_of(Source.TEMP)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(envelope, "\t"))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		discard_temp()
		return write_error

	var written := _read_envelope(temp_path)
	if _read_error != OK or not SaveChecksum.matches(written):
		push_warning("LocalSaveRepository: %s did not read back correctly, keeping the old save" % temp_path)
		discard_temp()
		return ERR_FILE_CORRUPT

	# A damaged main file must not replace the backup, which may be the only good copy.
	if has_data():
		var current := _read_envelope(path)
		if _read_error == OK and SaveChecksum.matches(current):
			var copy_error := DirAccess.copy_absolute(path, path_of(Source.BACKUP))
			if copy_error != OK:
				discard_temp()
				return copy_error

	var rename_error := _rename(temp_path, path)
	if rename_error != OK:
		DirAccess.remove_absolute(path)
		rename_error = _rename(temp_path, path)
	return rename_error

func promote_temp() -> Error:
	return _rename(path_of(Source.TEMP), path)

func discard_temp() -> void:
	var temp_path := path_of(Source.TEMP)
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)

## Keeps every broken copy aside: the main file as .corrupt, the .tmp as .corrupt.tmp and
## the .bak as .corrupt.bak, each replacing an older one of the same name. A copy that does
## not exist leaves nothing behind.
func quarantine() -> void:
	for source: Source in [Source.MAIN, Source.TEMP, Source.BACKUP]:
		_keep_aside(path_of(source), corrupt_path(source))

## Reads and parses one file. Sets _read_error; returns {} unless it holds a JSON object.
func _read_envelope(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		_read_error = ERR_FILE_NOT_FOUND
		return {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		_read_error = FileAccess.get_open_error()
		return {}
	# A JSON instance reports parse errors to us instead of printing an engine error.
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("LocalSaveRepository: %s line %d: %s"
				% [file_path, json.get_error_line(), json.get_error_message()])
		_read_error = ERR_PARSE_ERROR
		return {}
	if not json.data is Dictionary:
		_read_error = ERR_PARSE_ERROR
		return {}
	_read_error = OK
	return json.data

func _keep_aside(file_path: String, aside_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		return
	if FileAccess.file_exists(aside_path):
		DirAccess.remove_absolute(aside_path)
	DirAccess.rename_absolute(file_path, aside_path)

## Single place for the final rename so a test can make it fail.
func _rename(from_path: String, to_path: String) -> Error:
	return DirAccess.rename_absolute(from_path, to_path)
