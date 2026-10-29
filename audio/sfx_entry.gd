class_name SfxEntry
extends Resource
## One sound effect that AudioManager plays by id.

## AUD-02 order: a full pool drops the lowest first; T1 is never dropped.
enum Priority {
	UNIT = 0,
	TOWER = 1,
	BOSS = 2,
	COMMANDER = 3,
	T1 = 4,
}

@export var id: StringName
@export var stream: AudioStream
## &"SFX" for gameplay sounds, which stop on Pause. &"UI" for buttons and alerts, which keep playing (AUD-06).
@export var bus: StringName = &"SFX"
@export var volume_db: float = 0.0
## Used when a request passes a negative priority.
@export var priority: Priority = Priority.UNIT
