class_name UiFormat
extends RefCounted
## Formats numbers and times the same way regardless of the OS locale.

static func time_mmss(seconds: float) -> String:
	var total := maxi(ceili(seconds), 0)
	return "%02d:%02d" % [floori(total / 60.0), total % 60]

static func decimal(value: float, digits: int = 1) -> String:
	return "%.*f" % [digits, value]

## Whole numbers without ".0" (3, not 3.0), others with up to `digits` decimals.
static func num(value: float, digits: int = 1) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return String.num(value, digits)

## Model tier (bậc) of a tower level: 1 below the tier 2 level, 2 up to the tier 3 level, then 3.
static func model_tier(level: int) -> int:
	if level >= GameConfig.tower_tier3_level:
		return 3
	if level >= GameConfig.tower_tier2_level:
		return 2
	return 1

## Fills named placeholders such as {gold} instead of concatenating strings.
static func tr_fmt(key: StringName, params: Dictionary) -> String:
	return TranslationServer.translate(key).format(params)
