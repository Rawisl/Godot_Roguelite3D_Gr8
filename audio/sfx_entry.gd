class_name SfxEntry
extends Resource
## One sound effect that AudioManager plays by id.

@export var id: StringName
@export var stream: AudioStream
## &"SFX" for gameplay sounds, which stop on Pause. &"UI" for buttons and alerts, which keep playing (AUD-06).
@export var bus: StringName = &"SFX"
@export var volume_db: float = 0.0
## Used when a request passes a negative priority. One of AudioManager.PRIORITY_*.
@export_range(0, 4) var priority: int = 0
