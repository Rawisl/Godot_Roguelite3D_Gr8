extends Node
## Plays the sound effects requested through EventBus.sfx_requested and the music for each
## part of the game, and applies the audio settings to the buses.
##
## - Pitch and speed never follow the game speed. Engine.time_scale does not touch audio,
##   and nothing here changes pitch_scale.
## - At most max_voices sounds and max_instances of the same sound. When full, a new
##   sound replaces the lowest priority one playing. T1 is never dropped.
## - The same sound plays at most once per repeat_window (repeat_window_x3 at x3).
## - On Pause, gameplay SFX stop, UI SFX keep playing and the music drops to half.
## - A new track crossfades with the old one over crossfade_time real seconds, so it runs
##   the same while paused and at x3.
## - Losing window focus mutes Master (setting mute_on_focus_loss, on by default);
##   getting it back fades Master in over focus_fade_time real seconds.
## - Positional sound is optional, so the request position is ignored and sounds play in stereo.
##
## Settings keys on EventBus.settings_changed: volume_master, volume_music, volume_sfx and
## volume_ui (0 to 1), mute_on_focus_loss (bool).

const PRIORITY_UNIT := SfxEntry.Priority.UNIT
const PRIORITY_TOWER := SfxEntry.Priority.TOWER
const PRIORITY_BOSS := SfxEntry.Priority.BOSS
const PRIORITY_COMMANDER := SfxEntry.Priority.COMMANDER
const PRIORITY_T1 := SfxEntry.Priority.T1

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"

## Used until settings.cfg is loaded: Master 80%, Music 60%, SFX 80%, UI 70%.
const DEFAULT_SETTINGS := {
	&"volume_master": 0.8,
	&"volume_music": 0.6,
	&"volume_sfx": 0.8,
	&"volume_ui": 0.7,
	&"mute_on_focus_loss": true,
}
const VOLUME_BUSES := {
	&"volume_music": BUS_MUSIC,
	&"volume_sfx": BUS_SFX,
	&"volume_ui": BUS_UI,
}

@export var library: SfxLibrary
@export var max_voices: int = 32
@export var max_instances: int = 4
## Real-time seconds.
@export var repeat_window: float = 0.05
@export var repeat_window_x3: float = 0.08
## -6 dB is half the volume.
@export var pause_music_db: float = -6.0

@export_group("Music")
@export var music: MusicLibrary
## Real-time seconds for one track to replace another.
@export var crossfade_time: float = 1.5
## Real-time seconds for Master to come back after the window gets focus again.
@export var focus_fade_time: float = 0.5

class Voice:
	var player: AudioStreamPlayer
	var id: StringName
	var priority: int
	var started: float
	var overflow: bool

var _entries: Dictionary = {}  # StringName -> SfxEntry
var _voices: Array[Voice] = []
var _last_played: Dictionary = {}  # StringName -> real time
var _warned: Dictionary = {}  # unknown ids already reported
var _music_db: float = 0.0
## The two music players take turns: one fades in while the other fades out.
var _decks: Array[AudioStreamPlayer] = []
var _deck_gain: Array[float] = [0.0, 0.0]
var _deck_target: Array[float] = [0.0, 0.0]
var _front := 0
var _sting: AudioStreamPlayer
## Track to start once the sting playing now ends.
var _after_sting: AudioStream
var _settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var _focus_gain := 1.0
var _focus_target := 1.0
var _last_real := 0.0

@onready var _music: AudioStreamPlayer = $MusicPlayer
@onready var _pool: Node = $SfxPool

func _ready() -> void:
	# UI sounds and the music must keep running while paused. Gameplay voices opt back in to pausing.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_db = _music.volume_db
	var second := AudioStreamPlayer.new()
	second.name = "MusicPlayerB"
	add_child(second)
	_sting = AudioStreamPlayer.new()
	_sting.name = "StingPlayer"
	add_child(_sting)
	_sting.finished.connect(_on_sting_finished)
	_decks = [_music, second]
	for player in [_music, second, _sting]:
		player.bus = BUS_MUSIC
	_update_music_volume()
	set_library(library)
	for i in max_voices:
		_voices.append(_new_voice(false))
	_last_real = TimeManager.real_time
	_apply_buses()
	EventBus.sfx_requested.connect(_on_sfx_requested)
	EventBus.pause_changed.connect(_on_pause_changed)
	EventBus.state_changed.connect(_on_wave_state_changed)
	EventBus.settings_changed.connect(_on_settings_changed)
	GameState.app_state_changed.connect(_on_app_state_changed)

func set_library(value: SfxLibrary) -> void:
	library = value
	_entries.clear()
	if library == null:
		return
	for entry in library.entries:
		if entry != null and entry.id != &"":
			_entries[entry.id] = entry

## Returns true when the sound started. A negative priority uses the entry's priority.
func play(id: StringName, priority: int = -1) -> bool:
	var entry: SfxEntry = _entries.get(id)
	if entry == null or entry.stream == null:
		if not _warned.has(id):
			_warned[id] = true
			push_warning("AudioManager: no sound for id '%s'" % id)
		return false
	if priority < 0:
		priority = entry.priority
	var gameplay := entry.bus != BUS_UI
	if gameplay and get_tree().paused:
		return false
	var now: float = TimeManager.real_time
	var window := repeat_window_x3 if TimeManager.get_time_scale() >= 3 else repeat_window
	if _last_played.has(id):
		# A clock set back (TimeManager.reset) must not silence the sound until it catches up.
		var elapsed: float = now - float(_last_played[id])
		if elapsed >= 0.0 and elapsed < window:
			return false
	var voice := _pick_voice(id, priority)
	if voice == null:
		return false
	_last_played[id] = now
	_start(voice, entry, priority, gameplay, now)
	return true

func playing_count(id: StringName = &"") -> int:
	var count := 0
	for voice in _voices:
		if _busy(voice) and (id == &"" or voice.id == id):
			count += 1
	return count

func set_music_volume_db(value: float) -> void:
	_music_db = value
	_update_music_volume()

func _process(_delta: float) -> void:
	# Real time, so fades run the same while paused and at x2/x3.
	var now: float = TimeManager.real_time
	var real_delta := maxf(now - _last_real, 0.0)
	_last_real = now
	var step := real_delta / maxf(crossfade_time, 0.001)
	for i in _decks.size():
		_deck_gain[i] = move_toward(_deck_gain[i], _deck_target[i], step)
		if _deck_gain[i] <= 0.0 and _deck_target[i] <= 0.0 and _decks[i].playing:
			_decks[i].stop()
	_update_music_volume()
	if _focus_gain != _focus_target:
		_focus_gain = move_toward(_focus_gain, _focus_target, real_delta / maxf(focus_fade_time, 0.001))
		_apply_master()

#region Music
## Crossfades to stream, or fades out when it is null. The track already playing keeps going.
func play_music(stream: AudioStream) -> void:
	_after_sting = null
	_sting.stop()
	_crossfade(stream)

## Fades the music out, plays sting once, then crossfades into next.
func play_sting(sting: AudioStream, next: AudioStream) -> void:
	if sting == null:
		play_music(next)
		return
	_crossfade(null)
	_after_sting = next
	_sting.stream = sting
	_sting.play()

## Track playing or fading in, null for silence.
func current_music() -> AudioStream:
	return _decks[_front].stream if _deck_target[_front] > 0.0 else null

## Volume of each music player from 0 to 1, before Pause and the bus volumes. For tests.
func music_gains() -> Array[float]:
	return _deck_gain.duplicate()

func _crossfade(stream: AudioStream) -> void:
	if stream != null and stream == current_music():
		return
	_deck_target[_front] = 0.0
	if stream == null:
		return
	_front = 1 - _front
	var deck := _decks[_front]
	if deck.stream != stream or not deck.playing:
		deck.stream = stream
		_deck_gain[_front] = 0.0
		deck.play()
	_deck_target[_front] = 1.0

func _on_sting_finished() -> void:
	if _after_sting != null:
		var next := _after_sting
		_after_sting = null
		_crossfade(next)

## Track for each wave state. SUMMARY plays the win sting, then the PREP music.
func _on_wave_state_changed(new_state: StringName) -> void:
	if music == null:
		return
	match new_state:
		&"PREP":
			play_music(music.prep)
		&"COMBAT":
			play_music(music.combat)
		&"BOSS_INTRO", &"BOSS_COMBAT":
			play_music(music.boss)
		&"SUMMARY":
			play_sting(music.win_sting, music.prep)

func _on_app_state_changed(new_state: int, _old_state: int) -> void:
	if music == null:
		return
	match new_state:
		GameState.AppState.MAIN_MENU, GameState.AppState.META_SHOP, GameState.AppState.SETTINGS:
			play_music(music.menu)
		GameState.AppState.RUN_LOADING:
			play_music(null)
		GameState.AppState.RUN_END:
			play_sting(music.lose_sting, music.run_end)

func _update_music_volume() -> void:
	var offset := _music_db + (pause_music_db if get_tree().paused else 0.0)
	for i in _decks.size():
		_decks[i].volume_db = linear_to_db(maxf(_deck_gain[i], 0.0001)) + offset
	_sting.volume_db = offset
#endregion

#region Settings and focus
func get_setting(key: StringName) -> Variant:
	return _settings.get(key)

func _on_settings_changed(key: StringName, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		return
	_settings[key] = value
	if key == &"mute_on_focus_loss" and not value:
		_focus_target = 1.0
	_apply_buses()

func _apply_buses() -> void:
	for key in VOLUME_BUSES:
		_set_bus(VOLUME_BUSES[key], float(_settings[key]))
	_apply_master()

func _apply_master() -> void:
	_set_bus(BUS_MASTER, float(_settings[&"volume_master"]) * _focus_gain)

func _set_bus(bus_name: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.0)

## Losing focus mutes at once, getting it back fades in.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _settings[&"mute_on_focus_loss"]:
		_focus_target = 0.0
		_focus_gain = 0.0
		_apply_master()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focus_target = 1.0
#endregion

func _on_sfx_requested(sound_id: StringName, _position: Vector3, priority: int) -> void:
	play(sound_id, priority)

func _on_pause_changed(_is_paused: bool) -> void:
	_update_music_volume()

func _pick_voice(id: StringName, priority: int) -> Voice:
	var same: Array[Voice] = []
	for voice in _voices:
		if _busy(voice) and voice.id == id:
			same.append(voice)
	if same.size() >= max_instances:
		# A repeated T1 restarts its oldest copy instead of being dropped.
		return _oldest(same) if priority >= PRIORITY_T1 else null
	for voice in _voices:
		if not _busy(voice) and not voice.overflow:
			return voice
	var victim: Voice = null
	for voice in _voices:
		if voice.priority >= priority:
			continue
		if victim == null or voice.priority < victim.priority \
				or (voice.priority == victim.priority and voice.started < victim.started):
			victim = voice
	if victim != null:
		return victim
	if priority >= PRIORITY_T1:
		# Every voice is a T1 already: play above the limit rather than lose an alert.
		var extra := _new_voice(true)
		_voices.append(extra)
		return extra
	return null

func _start(voice: Voice, entry: SfxEntry, priority: int, gameplay: bool, now: float) -> void:
	var player := voice.player
	player.stop()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE if gameplay else Node.PROCESS_MODE_ALWAYS
	player.bus = entry.bus
	player.stream = entry.stream
	player.volume_db = entry.volume_db
	voice.id = entry.id
	voice.priority = priority
	voice.started = now
	player.play()

func _new_voice(overflow: bool) -> Voice:
	var voice := Voice.new()
	voice.player = AudioStreamPlayer.new()
	voice.overflow = overflow
	voice.priority = -1
	_pool.add_child(voice.player)
	if overflow:
		voice.player.finished.connect(_free_overflow.bind(voice))
	return voice

func _free_overflow(voice: Voice) -> void:
	_voices.erase(voice)
	voice.player.queue_free()

func _busy(voice: Voice) -> bool:
	return voice.player.playing or voice.player.stream_paused

func _oldest(voices: Array[Voice]) -> Voice:
	var result := voices[0]
	for voice in voices:
		if voice.started < result.started:
			result = voice
	return result
