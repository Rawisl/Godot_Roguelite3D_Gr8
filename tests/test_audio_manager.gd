extends Node
## Manual test for AudioManager voice limits, priorities, repeat window, Pause and pitch. Not shipped.
## Run with F6, prints OK/FAIL per case then quits.

const AM_SCENE := preload("res://autoload/audio_manager.tscn")

var _pass := 0
var _fail := 0
var _am: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The autoload AudioManager would also answer the EventBus signals sent here, with the
	# shipped library, so it is unplugged while the test instances run.
	var autoload := get_node("/root/AudioManager")
	EventBus.sfx_requested.disconnect(autoload._on_sfx_requested)
	EventBus.pause_changed.disconnect(autoload._on_pause_changed)
	_run()
	_free_manager()
	EventBus.sfx_requested.connect(autoload._on_sfx_requested)
	EventBus.pause_changed.connect(autoload._on_pause_changed)
	TimeManager.reset()
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	# The AudioServer lets go of finished playbacks on its next mix; quitting in this frame leaks them.
	for i in 3:
		await get_tree().process_frame
	get_tree().quit(1 if _fail > 0 else 0)

## Stops every voice first, so no playback is left with the AudioServer.
func _free_manager() -> void:
	if _am == null:
		return
	for player in _am.find_children("*", "AudioStreamPlayer", true, false):
		(player as AudioStreamPlayer).stop()
	_am.free()
	_am = null

func _new_manager() -> void:
	_free_manager()
	_am = AM_SCENE.instantiate()
	add_child(_am)
	var lib := SfxLibrary.new()
	for i in 10:
		lib.entries.append(_entry(StringName("unit_%d" % i), &"SFX", AudioManager.PRIORITY_UNIT))
	for i in 10:
		lib.entries.append(_entry(StringName("t1_%d" % i), &"UI", AudioManager.PRIORITY_T1))
	lib.entries.append(_entry(&"tower", &"SFX", AudioManager.PRIORITY_TOWER))
	lib.entries.append(_entry(&"commander", &"SFX", AudioManager.PRIORITY_COMMANDER))
	lib.entries.append(_entry(&"click", &"UI", AudioManager.PRIORITY_COMMANDER))
	_am.set_library(lib)
	TimeManager.real_time = 100.0

func _entry(id: StringName, bus: StringName, priority: int) -> SfxEntry:
	var e := SfxEntry.new()
	e.id = id
	e.bus = bus
	e.priority = priority
	# Two seconds of silence so a voice stays busy for the whole test.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050 * 2 * 2)
	wav.data = data
	e.stream = wav
	return e

func _wait(seconds: float) -> void:
	TimeManager.real_time += seconds

func _run() -> void:
	# Library from the autoload scene loads every placeholder sound.
	var shipped: Node = AM_SCENE.instantiate()
	add_child(shipped)
	for id in [&"ui_click", &"alert_t1", &"commander_hit", &"boss_stomp_windup", &"tower_arrow_shot", &"enemy_hit"]:
		_check("shipped library has %s" % id, shipped._entries.has(id) and shipped._entries[id].stream != null)
	_check("pool has 32 voices", shipped._voices.size() == 32)
	shipped.free()

	_new_manager()
	_check("unknown id is ignored", not _am.play(&"missing"))

	# AUD-03: repeat window, 50 ms at x1 and 80 ms at x3.
	_check("first play starts", _am.play(&"unit_0"))
	_check("same sound inside 50 ms is skipped", not _am.play(&"unit_0"))
	_wait(0.06)
	_check("same sound after 50 ms plays", _am.play(&"unit_0"))
	TimeManager.set_time_scale(3)
	_wait(0.06)
	_check("at x3, 60 ms is still inside the window", not _am.play(&"unit_0"))
	_wait(0.03)
	_check("at x3, 90 ms plays", _am.play(&"unit_0"))
	TimeManager.set_time_scale(1)
	TimeManager.real_time = 50.0
	_check("a clock set back does not silence the sound", _am.play(&"unit_0"))
	TimeManager.real_time = 100.5
	TimeManager.set_time_scale(3)
	# AUD-01: the game speed never reaches the pitch.
	_check("pitch stays 1 at x3", _all_pitch_one() and is_equal_approx(AudioServer.playback_speed_scale, 1.0))
	TimeManager.set_time_scale(1)

	# AUD-02: at most 4 copies of one sound.
	_new_manager()
	for i in 4:
		_am.play(&"unit_1")
		_wait(0.1)
	_check("fifth copy of a unit sound is dropped", not _am.play(&"unit_1") and _am.playing_count(&"unit_1") == 4)
	for i in 4:
		_am.play(&"t1_0")
		_wait(0.1)
	_check("fifth copy of a T1 restarts the oldest", _am.play(&"t1_0") and _am.playing_count(&"t1_0") == 4)

	# AUD-02: 32 voices, lower priority replaced first, equal priority not replaced.
	_new_manager()
	_fill(&"unit_", 8)
	_check("32 unit sounds fill the pool", _am.playing_count() == 32)
	_check("another unit sound is dropped when full", not _am.play(&"unit_8"))
	_check("a tower sound replaces a unit sound", _am.play(&"tower") and _am.playing_count() == 32 and _am.playing_count(&"tower") == 1)
	_check("the oldest unit sound was the one replaced", _am.playing_count(&"unit_0") == 3)
	_check("a commander sound replaces a unit before a tower", _am.play(&"commander") and _am.playing_count(&"tower") == 1)

	# AUD-02: T1 is never dropped, even when every voice is a T1.
	_new_manager()
	_fill(&"t1_", 8)
	_check("T1 still plays when 32 T1 sounds are playing", _am.play(&"t1_8") and _am.playing_count() == 33)
	_check("a commander sound cannot replace a T1", not _am.play(&"commander"))

	# AUD-06: Pause stops gameplay SFX, UI keeps playing, music drops by half.
	_new_manager()
	var music: AudioStreamPlayer = _am.get_node("MusicPlayer")
	_am.play(&"unit_0")
	TimeManager.request_pause(TimeManager.REASON_USER)
	_wait(0.1)
	_check("gameplay sound is not started while paused", not _am.play(&"unit_1"))
	_check("UI sound plays while paused", _am.play(&"click"))
	_check("music is half volume while paused", is_equal_approx(music.volume_db, -6.0))
	TimeManager.release_pause(TimeManager.REASON_USER)
	_check("music is back after Pause", is_equal_approx(music.volume_db, 0.0))
	_check("gameplay sound plays again after Pause", _am.play(&"unit_1"))

	# EventBus path with a negative priority uses the entry's priority.
	_new_manager()
	_fill(&"unit_", 8)
	EventBus.sfx_requested.emit(&"tower", Vector3.ZERO, -1)
	_check("sfx_requested plays through EventBus with the entry priority", _am.playing_count(&"tower") == 1)

func _fill(prefix: String, ids: int) -> void:
	for round in 4:
		for i in ids:
			_am.play(StringName(prefix + str(i)))
		_wait(0.1)

func _all_pitch_one() -> bool:
	for voice in _am._voices:
		if not is_equal_approx(voice.player.pitch_scale, 1.0):
			return false
	return true

func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("[test] OK   ", label)
	else:
		_fail += 1
		print("[test] FAIL ", label)
