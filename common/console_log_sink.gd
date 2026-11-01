class_name ConsoleLogSink
extends LogSink
## Writes to the Godot output: DEBUG and INFO print, WARN and ERROR go to the debugger with a stack.

func write(level: Log.Level, _tag: String, line: String) -> void:
	match level:
		Log.Level.WARN:
			push_warning(line)
		Log.Level.ERROR:
			push_error(line)
		_:
			print(line)
