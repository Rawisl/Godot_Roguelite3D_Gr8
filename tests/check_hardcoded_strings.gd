@tool
extends EditorScript
## Lists display text that bypasses tr(). Open this file and press Ctrl+Shift+X.

const SCAN_DIRS := ["res://ui", "res://entities", "res://systems", "res://levels", "res://autoload"]
const TEXT_PROPS := "(text|tooltip_text|placeholder_text|title)"
const SETTERS := "(set_text|set_tooltip_text|add_text|append_text|add_item|add_check_item|add_radio_check_item|add_tab|set_tab_title|set_item_text)"

var _key_re := RegEx.create_from_string("^[a-z0-9_]+(\\.[a-z0-9_]+)+$")
var _letter_re := RegEx.create_from_string("[A-Za-zÀ-ỹ]")
var _scene_re := RegEx.create_from_string("^(\\S+/)?" + TEXT_PROPS + " = \"(.*)\"$")
var _assign_re := RegEx.create_from_string("\\b" + TEXT_PROPS + "\\s*=\\s*\"[^\"]*[A-Za-zÀ-ỹ]")
var _setter_re := RegEx.create_from_string("\\b" + SETTERS + "\\([^)]*\"[^\"]*[A-Za-zÀ-ỹ]")
var _concat_re := RegEx.create_from_string("\\btr\\([^)]*\\)\\s*[+%]|\\+\\s*tr\\(")
var _tr_arg_re := RegEx.create_from_string("\\b(tr|tr_fmt)\\(\\s*&?\"[^\"]*\"")
var _log_re := RegEx.create_from_string("\\b(push_warning|push_error|print\\w*|assert)\\(")
var _vi_re := RegEx.create_from_string("[À-ỹ]")
var _issues := 0

func _run() -> void:
	_issues = 0
	for dir in SCAN_DIRS:
		_scan_dir(dir)
	print("Hardcoded strings found: %d" % _issues)

func _scan_dir(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_scan_dir(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".tscn") or file.ends_with(".gd"):
			_scan_file(path.path_join(file), file.ends_with(".tscn"))

func _scan_file(path: String, is_scene: bool) -> void:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		var line := lines[i] if is_scene else _strip_comment(lines[i])
		line = line.strip_edges()
		# Debug output never reaches the player, so it is not display text.
		if line.is_empty() or _log_re.search(line):
			continue
		if _is_hardcoded(line, is_scene):
			_report(path, i, lines[i].strip_edges())

func _is_hardcoded(line: String, is_scene: bool) -> bool:
	if is_scene:
		var m := _scene_re.search(line)
		if m:
			# A locale key left in a scene is fine; real words are not.
			var value := m.get_string(3)
			return _letter_re.search(value) != null and _key_re.search(value) == null
		return _vi_re.search(line) != null
	if _concat_re.search(line) or _vi_re.search(line):
		return true
	var rest := _tr_arg_re.sub(line, "tr(", true)
	return _assign_re.search(rest) != null or _setter_re.search(rest) != null

func _strip_comment(line: String) -> String:
	var in_string := false
	for i in line.length():
		if line[i] == "\"":
			in_string = not in_string
		elif line[i] == "#" and not in_string:
			return line.left(i)
	return line

func _report(path: String, index: int, line: String) -> void:
	_issues += 1
	print("%s:%d  %s" % [path, index + 1, line])
