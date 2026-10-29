extends Node
## Plays the sound effects requested through EventBus.sfx_requested.
##
## AUD-01: pitch and speed never follow the game speed. Engine.time_scale does not touch audio,
##         and nothing here changes pitch_scale.
## AUD-02: at most max_voices sounds and max_instances of the same sound. When full, a new
##         sound replaces the lowest priority one playing. T1 is never dropped.
## AUD-03: the same sound plays at most once per repeat_window (repeat_window_x3 at x3).
## AUD-06: on Pause, gameplay SFX stop, UI SFX keep playing and the music drops to half.
## AUD-04 positioning is [Should], so the request position is ignored and sounds play in stereo.

const PRIORITY_UNIT := SfxEntry.Priority.UNIT
const PRIORITY_TOWER := SfxEntry.Priority.TOWER
const PRIORITY_BOSS := SfxEntry.Priority.BOSS
const PRIORITY_COMMANDER := SfxEntry.Priority.COMMANDER
const PRIORITY_T1 := SfxEntry.Priority.T1

const BUS_SFX := &"SFX"
const BUS_UI := &"UI"

@export var library: SfxLibrary
@export var max_voices: int = 32
@export var max_instances: int = 4
## Real-time seconds.
@export var repeat_window: float = 0.05
@export var repeat_window_x3: float = 0.08
## -6 dB is half the volume.
@export var pause_music_db: float = -6.0

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

@onready var _music: AudioStreamPlayer = $MusicPlayer
@onready var _pool: Node = $SfxPool

func _ready() -> void:
	# UI sounds and the music must keep running while paused. Gameplay voices opt back in to pausing.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music.bus = &"Music"
	_music_db = _music.volume_db
	set_library(library)
	for i in max_voices:
		_voices.append(_new_voice(false))
	EventBus.sfx_requested.connect(_on_sfx_requested)
	EventBus.pause_changed.connect(_on_pause_changed)

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
	_music.volume_db = value + (pause_music_db if get_tree().paused else 0.0)

func _on_sfx_requested(sound_id: StringName, _position: Vector3, priority: int) -> void:
	play(sound_id, priority)

func _on_pause_changed(is_paused: bool) -> void:
	_music.volume_db = _music_db + (pause_music_db if is_paused else 0.0)

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
