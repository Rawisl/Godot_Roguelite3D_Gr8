class_name UiFormat
extends RefCounted
## Formats numbers and times the same way regardless of the OS locale.

static func time_mmss(seconds: float) -> String:
	var total := maxi(ceili(seconds), 0)
	return "%02d:%02d" % [floori(total / 60.0), total % 60]

static func decimal(value: float, digits: int = 1) -> String:
	return "%.*f" % [digits, value]

## Fills named placeholders such as {gold} instead of concatenating strings.
static func tr_fmt(key: StringName, params: Dictionary) -> String:
	return TranslationServer.translate(key).format(params)
