class_name LocalSaveRepository
extends SaveRepository
## Stores the envelope as JSON in a single file, user://endlesswar_save.json by default.

const DEFAULT_PATH := "user://endlesswar_save.json"

var path: String

func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path

func has_data() -> bool:
	return FileAccess.file_exists(path)

func load_data() -> Dictionary:
	if not has_data():
		last_error = ERR_FILE_NOT_FOUND
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = FileAccess.get_open_error()
		return {}
	# A JSON instance reports parse errors to us instead of printing an engine error.
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("LocalSaveRepository: %s line %d: %s"
				% [path, json.get_error_line(), json.get_error_message()])
		last_error = ERR_PARSE_ERROR
		return {}
	if not json.data is Dictionary:
		last_error = ERR_PARSE_ERROR
		return {}
	last_error = OK
	return json.data

## TODO(week 10): write endlesswar_save.tmp with a checksum, read it back to verify,
## copy endlesswar_save.json to endlesswar_save.bak, then replace endlesswar_save.json;
## delete a leftover endlesswar_save.tmp on startup.
func save_data(envelope: Dictionary) -> Error:
	var dir_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if dir_error != OK:
		return dir_error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(envelope, "\t"))
	var error := file.get_error()
	file.close()
	return error
