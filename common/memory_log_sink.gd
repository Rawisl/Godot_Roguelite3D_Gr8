class_name MemoryLogSink
extends LogSink
## Keeps the last lines in memory, oldest first. Used for the export log and by runners to check output.

const DEFAULT_CAPACITY := 200

## Most entries kept; the oldest is dropped past this.
var capacity: int
## Lines below this level are not kept.
var min_level: Log.Level
## Each entry: {"level": Log.Level, "tag": String, "line": String, "time": float}.
## time is wall-clock Unix seconds, a log timestamp only, never used for gameplay timing.
var entries: Array[Dictionary] = []

func _init(p_capacity: int = DEFAULT_CAPACITY, p_min_level: Log.Level = Log.Level.DEBUG) -> void:
	capacity = maxi(1, p_capacity)
	min_level = p_min_level

func write(level: Log.Level, tag: String, line: String) -> void:
	if level < min_level:
		return
	entries.append({"level": level, "tag": tag, "line": line, "time": Time.get_unix_time_from_system()})
	if entries.size() > capacity:
		entries.remove_at(0)

func clear() -> void:
	entries.clear()
