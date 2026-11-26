extends Node
## Credits: every folder that ships a licence file is credited, Kevin MacLeod's CC BY tracks keep
## their exact attribution, CREDITS.md names the same assets as the screen, every text key of the
## screen exists, and the dialog opens from the menu, scrolls on its own (not with Reduced
## motion), pauses when scrolled by hand, lets the wheel through its gaps and closes with Close,
## Back and Esc. Headless: checks and quits.

const CREDITS_SCENE := preload("res://ui/screens/credits.tscn")
## Licence file names, compared lower case.
const LICENCE_FILES := ["license.txt", "license.md", "license", "ofl.txt", "copying.txt"]

var _pass := 0
var _fail := 0


func _ready() -> void:
	# Every folder with a licence file is covered by an entry.
	var credited := GameCredits.credited_sources()
	var missing := PackedStringArray()
	for folder in _licence_folders("res://"):
		if not credited.has(folder):
			missing.append(folder)
	_check("every folder with a licence file is credited %s" % [missing], missing.is_empty())
	var stale := PackedStringArray()
	for folder in credited:
		if not DirAccess.dir_exists_absolute("res://" + folder):
			stale.append(folder)
	_check("every credited folder exists %s" % [stale], stale.is_empty())

	# The screen shows each CC BY track with its exact attribution.
	var dialog := CREDITS_SCENE.instantiate()
	add_child(dialog)
	await get_tree().process_frame
	dialog._reduced_motion = false
	var text: String = dialog.get_text()
	var tracks := _cc_by_tracks()
	_check("the music licence file lists the CC BY tracks", tracks.size() >= 5)
	var all_tracks := true
	for track in tracks:
		all_tracks = all_tracks and text.contains("\"%s\"" % track)
	_check("every CC BY track is on the screen", all_tracks)
	_check("the CC BY attribution is written in full", text.contains("Kevin MacLeod (incompetech.com)")
		and text.contains(GameCredits.CC_BY_4) and text.contains(GameCredits.CC_BY_4_URL))
	_check("the Godot licence is shown", text.contains(Engine.get_license_text().strip_edges().get_slice("\n", 0)))

	# Every key the screen uses has a text, and every outside asset is also in CREDITS.md.
	var keys_ok := true
	var doc := FileAccess.get_file_as_string("res://CREDITS.md")
	var doc_ok := not doc.is_empty()
	for section in GameCredits.SECTIONS:
		keys_ok = keys_ok and tr(section.title) != String(section.title)
		for entry: Dictionary in section.entries:
			for field in ["name", "by"]:
				var value := String(entry.get(field, ""))
				if value.begins_with("credits."):
					keys_ok = keys_ok and tr(StringName(value)) != value
				elif not value.is_empty() and not doc.contains(value.replace("\"", "")):
					doc_ok = false
					print("    not in CREDITS.md: ", value)
	for key in [&"credits.title", &"credits.subtitle", &"credits.section.engine", &"credits.thanks", &"menu.credits"]:
		keys_ok = keys_ok and tr(key) != String(key)
	_check("every text key of the credits has a text", keys_ok)
	_check("CREDITS.md names every entry and author of the screen", doc_ok)

	# It scrolls on its own after the start delay, and not with Reduced motion.
	var scroll: ScrollContainer = dialog.get_node("%Scroll")
	dialog._process(dialog.START_DELAY * 0.5)
	_check("it waits before it starts to scroll", scroll.scroll_vertical == 0)
	dialog._process(dialog.START_DELAY)
	dialog._process(1.0)
	_check("the list scrolls on its own", scroll.scroll_vertical > 0)
	var gaps_ok := true
	for child in dialog.get_node("%List").get_children():
		if not child is Label:
			gaps_ok = gaps_ok and (child as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE
	_check("the gaps let the wheel through to the list", gaps_ok)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	scroll.gui_input.emit(wheel)
	var held: int = scroll.scroll_vertical
	dialog._process(dialog.RESUME_DELAY * 0.5)
	_check("the wheel pauses auto scroll", scroll.scroll_vertical == held)
	dialog._process(dialog.RESUME_DELAY)
	dialog._process(1.0)
	_check("auto scroll resumes after the pause", scroll.scroll_vertical > held)
	scroll.get_v_scroll_bar().scrolling.emit()
	held = scroll.scroll_vertical
	dialog._process(1.0)
	_check("dragging the scroll bar pauses auto scroll", scroll.scroll_vertical == held)
	var down := InputEventAction.new()
	down.action = &"ui_down"
	down.pressed = true
	dialog._unhandled_input(down)
	_check("the Down key scrolls the list", scroll.scroll_vertical > held)
	var up := InputEventAction.new()
	up.action = &"ui_page_up"
	up.pressed = true
	dialog._unhandled_input(up)
	_check("Page Up scrolls back up", scroll.scroll_vertical < held)
	var thanks: int = dialog.get_text().find(tr(&"credits.thanks"))
	var engine: int = dialog.get_text().find(tr(&"credits.section.engine"))
	_check("the thanks line comes before the long engine licence", thanks >= 0 and thanks < engine)
	var close_button: Button = dialog.get_node("%Close")
	close_button.mouse_entered.emit()
	_check("hovering a button focuses it", close_button.has_focus())
	close_button.pressed.emit()
	_check("Close closes it", dialog.is_queued_for_deletion())
	await get_tree().process_frame
	dialog = CREDITS_SCENE.instantiate()
	add_child(dialog)
	await get_tree().process_frame
	(dialog.get_node("%Back") as Button).pressed.emit()
	_check("Back closes it", dialog.is_queued_for_deletion())
	await get_tree().process_frame
	dialog = CREDITS_SCENE.instantiate()
	add_child(dialog)
	await get_tree().process_frame
	dialog._reduced_motion = true
	dialog._hold = 0.0
	dialog._process(1.0)
	_check("Reduced motion: the list does not scroll on its own", dialog.get_node("%Scroll").scroll_vertical == 0)
	dialog.free()

	# The menu opens it on the dialog layer, Esc closes it and focus returns to the button.
	var menu: Control = load("res://ui/screens/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	var button: Button = menu.get_node("%Credits")
	_check("the menu has a Credits button", button != null and button.text == tr(&"menu.credits"))
	button.pressed.emit()
	await get_tree().process_frame
	_check("Credits opens on the dialog layer", ScreenManager.has_dialog())
	ScreenManager.close_top_dialog()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("Esc closes Credits and focus returns to its button", not ScreenManager.has_dialog() and button.has_focus())
	menu.free()

	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


## Repo folders (without res://) that hold a licence file.
func _licence_folders(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	for file in dir.get_files():
		if file.to_lower() in LICENCE_FILES:
			out.append(path.trim_prefix("res://").trim_suffix("/"))
			break
	for sub in dir.get_directories():
		if sub.begins_with("."):
			continue
		out.append_array(_licence_folders(path.path_join(sub) + "/"))
	return out


## Titles of the CC BY tracks named in the music licence file.
func _cc_by_tracks() -> PackedStringArray:
	var out := PackedStringArray()
	var regex := RegEx.create_from_string("^\"(.+)\" Kevin MacLeod")
	for line in FileAccess.get_file_as_string("res://audio/music/License.txt").split("\n"):
		var found := regex.search(line.strip_edges())
		if found != null:
			out.append(found.get_string(1))
	return out


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("OK   ", label)
	else:
		_fail += 1
		print("FAIL ", label)
