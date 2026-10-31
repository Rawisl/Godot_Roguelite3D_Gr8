@abstract
class_name LogSink
extends RefCounted
## Where Log lines end up. Add one with Log.add_sink; subclasses decide what writing means.

## Receives one line that passed the Log filters. line is "[Tag] message". Do not add or
## remove sinks from inside write.
@abstract func write(level: Log.Level, tag: String, line: String) -> void
