class_name Log
## Tagged, levelled output for every system. Static only, no autoload and no GameConfig, so any
## runner can use it. Pass values in args instead of formatting first: the text is only built
## when the level is on for that tag. args must match the placeholders in msg, otherwise the
## call is a script error. Lines that pass the filters go to every sink in sinks.

enum Level { DEBUG, INFO, WARN, ERROR }

## Lowest level written. Release builds keep WARN and ERROR only.
static var min_level: Level = Level.INFO if OS.is_debug_build() else Level.WARN
## Tags that write nothing at any level (tag -> true).
static var muted_tags: Dictionary[String, bool] = {}
## Tags that write from DEBUG up whatever min_level is (tag -> true).
static var debug_tags: Dictionary[String, bool] = {}
# TODO(week 12): add a FileLogSink, or write recent_sink entries to a file from the Settings data tab (export log).
## The last WARN and ERROR lines, kept for the export log.
static var recent_sink: MemoryLogSink = MemoryLogSink.new(MemoryLogSink.DEFAULT_CAPACITY, Level.WARN)
## Every line that passes the filters goes to each sink here, in order. Empty means silent.
## Declared after recent_sink: static vars are set in this order when the script loads.
static var sinks: Array[LogSink] = [ConsoleLogSink.new(), recent_sink]

static func debug(tag: String, msg: String, args: Array = []) -> void:
	_write(Level.DEBUG, tag, msg, args)

static func info(tag: String, msg: String, args: Array = []) -> void:
	_write(Level.INFO, tag, msg, args)

static func warn(tag: String, msg: String, args: Array = []) -> void:
	_write(Level.WARN, tag, msg, args)

static func error(tag: String, msg: String, args: Array = []) -> void:
	_write(Level.ERROR, tag, msg, args)

## True when a message of this level for this tag would be written.
static func enabled(level: Level, tag: String) -> bool:
	if muted_tags.has(tag):
		return false
	return level >= (Level.DEBUG if debug_tags.has(tag) else min_level)

## Sends lines to sink as well. null, or a sink already added, is ignored.
static func add_sink(sink: LogSink) -> void:
	if sink != null and not sinks.has(sink):
		sinks.append(sink)

## Stops sending lines to sink. Nothing happens when it was not added.
static func remove_sink(sink: LogSink) -> void:
	sinks.erase(sink)

static func _write(level: Level, tag: String, msg: String, args: Array) -> void:
	if not enabled(level, tag):
		return
	# No format when args is empty, so a literal % in msg is safe.
	var text: String = msg if args.is_empty() else msg % args
	var line := "[%s] %s" % [tag, text]
	for sink in sinks:
		sink.write(level, tag, line)
