extends Control
## Manual playtest for SaveManager. Not shipped. Run with F6.
## Change values, press Save, close the game, run again: the values must come back.
## Writes to user://playtest_save/save.json unless use_real_save is on.

const PLAYTEST_PATH := "user://playtest_save/save.json"

@export var use_real_save := false

var _info: Label
var _events: Label
var _event_log: PackedStringArray = []

func _ready() -> void:
	var path := LocalSaveRepository.DEFAULT_PATH if use_real_save else PLAYTEST_PATH
	SaveManager.set_repository(LocalSaveRepository.new(path))
	SaveManager.save_loaded.connect(func(): _log("save_loaded"))
	EventBus.save_completed.connect(func(): _log("save_completed"))
	EventBus.save_failed.connect(func(reason: StringName): _log("save_failed(%s)" % reason))
	_build_ui()
	SaveManager.load_save()
	_refresh()

func _exit_tree() -> void:
	# Leave the autoload on the real save for whatever runs next.
	SaveManager.set_repository(LocalSaveRepository.new())

func add_prestige(amount: int) -> void:
	var profile := SaveManager.get_section(SaveManager.PROFILE)
	profile["prestige_balance"] += amount
	_refresh()

func add_wave() -> void:
	var profile := SaveManager.get_section(SaveManager.PROFILE)
	profile["max_wave_cleared"] += 1
	_refresh()

func toggle_tutorial() -> void:
	var flags := SaveManager.get_section(SaveManager.FLAGS)
	flags["tutorial_done"] = not flags["tutorial_done"]
	_refresh()

func save_now() -> void:
	var start := Time.get_ticks_usec()
	var error := SaveManager.save()
	_log("save() -> %s in %.2f ms" % [error_string(error), (Time.get_ticks_usec() - start) / 1000.0])
	_refresh()

func reload() -> void:
	SaveManager.load_save()
	_refresh()

func delete_file() -> void:
	if use_real_save:
		_log("delete refused: use_real_save is on")
		return
	DirAccess.remove_absolute(PLAYTEST_PATH)
	_log("deleted %s" % PLAYTEST_PATH)
	_refresh()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.position = Vector2(40, 40)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_info = Label.new()
	box.add_child(_info)
	var row := HBoxContainer.new()
	box.add_child(row)
	for entry in [["+10 prestige", add_prestige.bind(10)], ["+1 max wave", add_wave],
			["Toggle tutorial", toggle_tutorial], ["Save", save_now],
			["Reload from disk", reload], ["Delete file", delete_file]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		row.add_child(button)
	_events = Label.new()
	box.add_child(_events)

func _refresh() -> void:
	var repository := SaveManager.repository as LocalSaveRepository
	var profile := SaveManager.get_section(SaveManager.PROFILE)
	var flags := SaveManager.get_section(SaveManager.FLAGS)
	_info.text = "\n".join([
		"File: %s" % ProjectSettings.globalize_path(repository.path),
		"File exists: %s    can_write: %s" % [repository.has_data(), SaveManager.can_write],
		"prestige_balance: %s" % profile["prestige_balance"],
		"max_wave_cleared: %s" % profile["max_wave_cleared"],
		"tutorial_done: %s" % flags["tutorial_done"],
	])

func _log(line: String) -> void:
	_event_log.append(line)
	if _event_log.size() > 8:
		_event_log.remove_at(0)
	if _events != null:
		_events.text = "\n".join(_event_log)
