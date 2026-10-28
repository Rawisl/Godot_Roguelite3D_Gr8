extends Node
## Manual test for AudioManager voice limits, priorities, repeat window, Pause, pitch, music
## crossfade and tracks per state, audio settings and focus mute. Not shipped.
## Run with F6, prints OK/FAIL per case then quits.

const AM_SCENE := preload("res://autoload/audio_manager.tscn")

var _pass := 0
var _fail := 0
var _am: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()
	TimeManager.reset()
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func _new_manager() -> void:
	if _am != null:
		_am.free()
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
	# AUD-09: every state has a track; loops loop, stings play once.
	var tracks: MusicLibrary = shipped.music
	for key in [&"menu", &"prep", &"combat", &"boss", &"run_end"]:
		var t: AudioStream = tracks.get(key)
		_check("shipped %s track loops" % key, t is AudioStreamOggVorbis and t.loop)
	for key in [&"win_sting", &"lose_sting"]:
		var t: AudioStream = tracks.get(key)
		_check("shipped %s plays once" % key, t is AudioStreamOggVorbis and not t.loop)
	_check("combat and boss tracks differ", tracks.combat != tracks.boss)
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
	_am.play_music(_track(1.0))
	_tick(2.0)
	music = _am._decks[_am._front]
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

	_run_music()
	_run_settings()

func _run_music() -> void:
	# AUD-06: 1.5 s crossfade in real time, the same while paused and at x3.
	_new_manager()
	var a := _track(1.0)
	var b := _track(1.0)
	_am.play_music(a)
	_tick(0.75)
	_check("a new track is half in after 0.75 s", is_equal_approx(_am.music_gains().max(), 0.5))
	_tick(0.75)
	_check("a new track is fully in after 1.5 s", is_equal_approx(_am.music_gains().max(), 1.0))
	_am.play_music(a)
	_check("asking for the track already playing changes nothing", _am.current_music() == a and is_equal_approx(_am.music_gains().max(), 1.0))
	TimeManager.set_time_scale(3)
	TimeManager.request_pause(TimeManager.REASON_USER)
	_am.play_music(b)
	_tick(0.75)
	var g: Array = _am.music_gains()
	_check("paused at x3, the crossfade is halfway after 0.75 real s", is_equal_approx(g[0], 0.5) and is_equal_approx(g[1], 0.5))
	_check("both tracks play during the crossfade", _am._decks[0].playing and _am._decks[1].playing)
	_tick(0.75)
	_check("the old track stops when the crossfade ends", _am.current_music() == b and _playing_decks() == 1)
	_check("music pitch stays 1", _am._decks[0].pitch_scale == 1.0 and _am._decks[1].pitch_scale == 1.0)
	TimeManager.release_pause(TimeManager.REASON_USER)
	TimeManager.set_time_scale(1)

	# Tracks per state (SRS 4.5).
	_new_manager()
	var lib := MusicLibrary.new()
	for key in [&"menu", &"prep", &"combat", &"boss", &"run_end"]:
		lib.set(key, _track(1.0))
	lib.win_sting = _track(0.2, false)
	lib.lose_sting = _track(0.2, false)
	_am.music = lib
	for pair in [[&"PREP", lib.prep], [&"COMBAT", lib.combat], [&"BOSS_INTRO", lib.boss], [&"BOSS_COMBAT", lib.boss]]:
		_am._on_wave_state_changed(pair[0])
		_check("%s plays its track" % pair[0], _am.current_music() == pair[1])
	_am._on_app_state_changed(GameState.AppState.MAIN_MENU, GameState.AppState.BOOT)
	_check("MainMenu plays the menu track", _am.current_music() == lib.menu)
	_am._on_app_state_changed(GameState.AppState.META_SHOP, GameState.AppState.MAIN_MENU)
	_check("MetaShop keeps the menu track", _am.current_music() == lib.menu)
	_am._on_wave_state_changed(&"SUMMARY")
	_check("SUMMARY fades the music out and plays the win sting", _am.current_music() == null and _am._sting.stream == lib.win_sting)
	_am._on_sting_finished()
	_check("after the win sting, the PREP track comes in", _am.current_music() == lib.prep)
	_am._on_app_state_changed(GameState.AppState.RUN_END, GameState.AppState.RUN)
	_check("RunEnd plays the lose sting", _am.current_music() == null and _am._sting.stream == lib.lose_sting)
	_am._on_wave_state_changed(&"PREP")
	_check("a new state cancels the track waiting for the sting", _am._after_sting == null and _am.current_music() == lib.prep)
	_am.music = MusicLibrary.new()
	_am._on_wave_state_changed(&"COMBAT")
	_check("a missing track fades to silence", _am.current_music() == null)

func _run_settings() -> void:
	_new_manager()
	var buses := {&"Master": 0.8, &"Music": 0.6, &"SFX": 0.8, &"UI": 0.7}
	var ok := true
	for bus in buses:
		ok = ok and is_equal_approx(_bus_linear(bus), buses[bus])
	_check("bus defaults are Master 80%, Music 60%, SFX 80%, UI 70%", ok)
	EventBus.settings_changed.emit(&"volume_music", 0.3)
	_check("volume_music sets the Music bus", is_equal_approx(_bus_linear(&"Music"), 0.3))
	EventBus.settings_changed.emit(&"volume_sfx", 0.0)
	_check("volume 0 mutes the bus", AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")))
	EventBus.settings_changed.emit(&"volume_sfx", 0.8)
	_check("raising it again unmutes", not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")))

	# AUD-08: focus out mutes Master at once, focus in fades back over 0.5 s.
	_am._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check("losing focus mutes Master", AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")))
	_am._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	_tick(0.25)
	_check("halfway back after 0.25 s", is_equal_approx(_bus_linear(&"Master"), 0.4))
	_tick(0.25)
	_check("back to the Master volume after 0.5 s", is_equal_approx(_bus_linear(&"Master"), 0.8))
	EventBus.settings_changed.emit(&"mute_on_focus_loss", false)
	_am._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check("with the option off, losing focus keeps the sound", is_equal_approx(_bus_linear(&"Master"), 0.8))
	EventBus.settings_changed.emit(&"mute_on_focus_loss", true)
	EventBus.settings_changed.emit(&"volume_music", 0.6)

	# Audio tab sends the same keys.
	var tab: Control = load("res://ui/screens/tab_audio.tscn").instantiate()
	add_child(tab)
	var slider: HSlider = tab.get_node("%Rows/volume_ui/Slider")
	_check("audio tab starts at the current UI volume", is_equal_approx(slider.value, 70.0))
	slider.value = 40
	_check("moving the UI slider sets the UI bus", is_equal_approx(_bus_linear(&"UI"), 0.4))
	var mute: CheckButton = tab.get_node("%MuteOnFocusLoss")
	mute.button_pressed = false
	_check("the focus checkbox sets mute_on_focus_loss", AudioManager.get_setting(&"mute_on_focus_loss") == false)
	mute.button_pressed = true
	slider.value = 70
	tab.free()

## Silent stream; looped ones stand in for music, the others for stings.
func _track(seconds: float, looped := true) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(int(22050 * seconds) * 2)
	wav.data = data
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = int(22050 * seconds)
	return wav

## Advances real time and runs one AudioManager frame.
func _tick(seconds: float) -> void:
	_am._last_real = TimeManager.real_time
	TimeManager.real_time += seconds
	_am._process(0.0)

func _playing_decks() -> int:
	var count := 0
	for deck in _am._decks:
		if deck.playing:
			count += 1
	return count

func _bus_linear(bus: StringName) -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus)))

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
