extends Node

## Automated test runner verifying the static Log helper:
## - level filter, enabled(), per-tag debug and mute
## - argument formatting only when the level is on
## - delivery to every sink, add_sink and remove_sink, the memory sink ring
## Log.sinks is swapped for memory sinks while it runs, so the runner prints no warning or error lines itself.

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []

## Every line from DEBUG up.
var _all := MemoryLogSink.new()
## WARN and ERROR only, like Log.recent_sink.
var _warn := MemoryLogSink.new(MemoryLogSink.DEFAULT_CAPACITY, Log.Level.WARN)

## Counts how many times it is turned into text.
class Counter:
	var n: int = 0

	func _to_string() -> String:
		n += 1
		return "counter"

func _ready() -> void:
	print("\n=======================================================")
	print("          AUTOMATED LOG HELPER RUNNER TEST             ")
	print("=======================================================")

	var saved_min_level: Log.Level = Log.min_level
	var saved_muted: Dictionary[String, bool] = Log.muted_tags
	var saved_debug: Dictionary[String, bool] = Log.debug_tags
	var saved_sinks: Array[LogSink] = Log.sinks

	# First, before any _reset(): checks the values Log starts with.
	test_default()
	test_level_filter()
	test_enabled()
	test_debug_tags()
	test_muted_tags()
	test_format()
	test_lazy()
	test_memory_sink_level()
	test_ring()
	test_console_and_no_sinks()
	test_several_sinks()
	test_add_remove()

	Log.min_level = saved_min_level
	Log.muted_tags = saved_muted
	Log.debug_tags = saved_debug
	Log.sinks = saved_sinks

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")

	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)

func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		failed_names.append(test_name)
		printerr("  [FAIL] %s" % test_name)

## Back to a known state before each group: INFO, no tag overrides, both memory sinks empty.
func _reset() -> void:
	Log.min_level = Log.Level.INFO
	Log.muted_tags = {}
	Log.debug_tags = {}
	Log.sinks = [_all, _warn]
	_all.clear()
	_warn.clear()

## Line text of entry i in _all, or "" when there is no such entry (a FAIL, not a crash).
func _line(i: int) -> String:
	if i < _all.entries.size():
		return _all.entries[i].line
	return ""

## Level of entry i in _all, or -1 when there is no such entry.
func _level(i: int) -> int:
	if i < _all.entries.size():
		return _all.entries[i].level
	return -1

func test_default() -> void:
	print("\n--- Group 1: Default ---")
	assert_true(Log.min_level == Log.Level.INFO, "Default min_level is INFO in a debug build")
	assert_true(Log.sinks.size() == 2, "Default sinks has two entries")
	assert_true(Log.sinks[0] is ConsoleLogSink, "First default sink is the console")
	assert_true(is_same(Log.sinks[1], Log.recent_sink), "Second default sink is recent_sink")
	assert_true(Log.recent_sink.min_level == Log.Level.WARN, "recent_sink keeps WARN and above")
	assert_true(Log.recent_sink.capacity == MemoryLogSink.DEFAULT_CAPACITY, "recent_sink uses the default capacity")

func test_level_filter() -> void:
	print("\n--- Group 2: Level filter ---")
	_reset()
	Log.debug("T", "hidden")
	assert_true(_all.entries.is_empty(), "debug does not reach the sink at INFO")
	Log.info("T", "hello")
	assert_true(_all.entries.size() == 1, "info reaches the sink once")
	assert_true(_line(0) == "[T] hello", "info line is tagged")
	assert_true(_level(0) == Log.Level.INFO, "info line has level INFO")
	_all.clear()
	Log.min_level = Log.Level.WARN
	Log.info("T", "hidden")
	assert_true(_all.entries.is_empty(), "info does not reach the sink at WARN")
	Log.warn("T", "shown")
	assert_true(_all.entries.size() == 1, "warn reaches the sink at WARN")

func test_enabled() -> void:
	print("\n--- Group 3: enabled() ---")
	_reset()
	assert_true(not Log.enabled(Log.Level.DEBUG, "T"), "DEBUG off at INFO")
	assert_true(Log.enabled(Log.Level.INFO, "T"), "INFO on at INFO")
	assert_true(Log.enabled(Log.Level.WARN, "T"), "WARN on at INFO")
	assert_true(Log.enabled(Log.Level.ERROR, "T"), "ERROR on at INFO")
	Log.min_level = Log.Level.ERROR
	assert_true(not Log.enabled(Log.Level.WARN, "T"), "WARN off at ERROR")

func test_debug_tags() -> void:
	print("\n--- Group 4: debug_tags ---")
	_reset()
	Log.debug_tags = {"Nav": true}
	Log.debug("Nav", "path")
	assert_true(_all.entries.size() == 1, "debug tag lets DEBUG through")
	_all.clear()
	Log.debug("Wave", "spawn")
	assert_true(_all.entries.is_empty(), "other tags stay filtered")

func test_muted_tags() -> void:
	print("\n--- Group 5: muted_tags ---")
	_reset()
	Log.muted_tags = {"Build": true}
	Log.info("Build", "i")
	Log.warn("Build", "w")
	Log.error("Build", "e")
	assert_true(_all.entries.is_empty(), "muted tag writes nothing at any level")
	assert_true(_warn.entries.is_empty(), "muted tag leaves the WARN sink untouched")
	Log.info("Gold", "still on")
	assert_true(_all.entries.size() == 1, "unmuted tag still writes")

func test_format() -> void:
	print("\n--- Group 6: Format ---")
	_reset()
	Log.info("Build", "built %s L%d", ["arrow", 2])
	assert_true(_line(0) == "[Build] built arrow L2", "args are formatted into the message")
	_all.clear()
	Log.info("T", "100%")
	assert_true(_line(0) == "[T] 100%", "a literal % is safe without args")

func test_lazy() -> void:
	print("\n--- Group 7: Lazy ---")
	_reset()
	var c := Counter.new()
	Log.debug("T", "%s", [c])
	assert_true(c.n == 0, "args are not turned into text when the level is off")
	Log.info("T", "%s", [c])
	assert_true(c.n == 1, "args are turned into text once when the level is on")

func test_memory_sink_level() -> void:
	print("\n--- Group 8: Memory sink level ---")
	_reset()
	Log.info("T", "a")
	Log.info("T", "b")
	Log.info("T", "c")
	assert_true(_warn.entries.is_empty(), "INFO is not kept by the WARN sink")
	assert_true(_all.entries.size() == 3, "the DEBUG sink keeps every INFO line")
	Log.warn("T", "w")
	Log.error("T", "e")
	assert_true(_warn.entries.size() == 2, "WARN and ERROR are kept by the WARN sink")
	var first: Dictionary = _warn.entries[0] if _warn.entries.size() > 0 else {}
	var second: Dictionary = _warn.entries[1] if _warn.entries.size() > 1 else {}
	assert_true(first.get("level", -1) == Log.Level.WARN, "first kept entry has level WARN")
	assert_true(first.get("tag", "") == "T", "first kept entry has the tag")
	assert_true(first.get("line", "") == "[T] w", "first kept entry has the line")
	assert_true(second.get("level", -1) == Log.Level.ERROR, "second kept entry has level ERROR")
	assert_true(second.get("line", "") == "[T] e", "second kept entry has the line")
	assert_true(second.get("msec", -1) >= first.get("msec", 0), "msec does not go backwards")

func test_ring() -> void:
	print("\n--- Group 9: Ring ---")
	_reset()
	for i in 205:
		Log.warn("T", "w%d", [i])
	assert_true(_warn.entries.size() == MemoryLogSink.DEFAULT_CAPACITY, "the sink is capped at DEFAULT_CAPACITY")
	var oldest: String = _warn.entries[0].line if _warn.entries.size() > 0 else ""
	var newest: String = _warn.entries[-1].line if _warn.entries.size() > 0 else ""
	assert_true(oldest == "[T] w5", "oldest lines are dropped first")
	assert_true(newest == "[T] w204", "newest line is last")

func test_console_and_no_sinks() -> void:
	print("\n--- Group 10: Console and no sinks ---")
	_reset()
	# Only INFO here: WARN and ERROR on the console sink would print warning and error lines.
	Log.sinks = [ConsoleLogSink.new()]
	Log.info("T", "console output")
	assert_true(true, "info through the console sink runs without error")
	Log.sinks = []
	Log.info("T", "silent")
	Log.warn("T", "silent")
	Log.error("T", "silent")
	assert_true(true, "log calls with no sinks run without error")
	assert_true(Log.enabled(Log.Level.INFO, "T"), "enabled() does not depend on sinks")

func test_several_sinks() -> void:
	print("\n--- Group 11: Several sinks ---")
	_reset()
	var other := MemoryLogSink.new()
	Log.sinks = [_all, other]
	Log.info("T", "both")
	assert_true(_all.entries.size() == 1, "first sink got the line")
	assert_true(other.entries.size() == 1, "second sink got the line")
	var other_line: String = other.entries[0].line if other.entries.size() > 0 else ""
	assert_true(_line(0) == other_line, "both sinks got the same line")

func test_add_remove() -> void:
	print("\n--- Group 12: add_sink and remove_sink ---")
	_reset()
	Log.sinks = []
	Log.add_sink(_all)
	Log.add_sink(_all)
	Log.add_sink(null)
	assert_true(Log.sinks.size() == 1, "a sink is added once and null is ignored")
	Log.info("T", "one")
	assert_true(_all.entries.size() == 1, "an added sink receives lines")
	Log.remove_sink(_all)
	assert_true(Log.sinks.is_empty(), "remove_sink takes the sink out")
	Log.info("T", "two")
	assert_true(_all.entries.size() == 1, "a removed sink receives nothing")
	Log.remove_sink(_all)
	assert_true(Log.sinks.is_empty(), "removing a sink twice is harmless")
