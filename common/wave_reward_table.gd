class_name WaveRewardTable
extends Resource

## Per-wave reward multipliers for waves 1..GameConfig.victory_wave; entry wave - 1 holds wave `wave`.
## Past victory_wave the gold multiplier is 1 + gold_reward_growth_per_wave * (wave - 1),
## the XP multiplier is 1 and Mithril stays at the victory_wave value. Extra rows are ignored.

## Values are stored as 32-bit floats; snap them back to the decimals typed in the balance sheet.
const SNAP_STEP: float = 0.0001
## Absorbs float error before rounding gold down (100 * 1.16 is 115.99999999999999 in floating point).
const FLOOR_TOLERANCE: float = 0.000001

@export var gold_mult: PackedFloat32Array = PackedFloat32Array()
@export var xp_mult: PackedFloat32Array = PackedFloat32Array()
@export var mithril_reward: PackedInt32Array = PackedInt32Array()


## Gold multiplier of `wave`; past the table it follows the per-wave growth formula.
func get_gold_mult(wave: int) -> float:
	var w := _clamp_wave(wave)
	if w > GameConfig.victory_wave:
		return _gold_mult_formula(w)
	if w > gold_mult.size():
		_report_missing_row("gold_mult", w, gold_mult.size())
		return _gold_mult_formula(w)
	return snappedf(gold_mult[w - 1], SNAP_STEP)


## XP multiplier of `wave`; 1.0 past the table.
func get_xp_mult(wave: int) -> float:
	var w := _clamp_wave(wave)
	if w > GameConfig.victory_wave:
		return 1.0
	if w > xp_mult.size():
		_report_missing_row("xp_mult", w, xp_mult.size())
		return 1.0
	return snappedf(xp_mult[w - 1], SNAP_STEP)


## Mithril paid for clearing `wave`; waves past victory_wave use the victory_wave value.
func get_mithril_reward(wave: int) -> int:
	var row := mini(_clamp_wave(wave), GameConfig.victory_wave)
	if mithril_reward.is_empty():
		_report_missing_row("mithril_reward", row, 0)
		return 0
	if row > mithril_reward.size():
		_report_missing_row("mithril_reward", row, mithril_reward.size())
		return mithril_reward[mithril_reward.size() - 1]
	return mithril_reward[row - 1]


## gold_reward * gold_mult(wave), times frontline_gold_mult once when the commander hit the unit.
func get_kill_gold(gold_reward: int, wave: int, hit_by_commander: bool) -> float:
	var commander_mult: float = GameConfig.frontline_gold_mult if hit_by_commander else 1.0
	return float(gold_reward) * get_gold_mult(wave) * commander_mult


## boss_gold_base * gold_mult(wave); no commander multiplier.
func get_boss_gold(wave: int) -> float:
	return float(GameConfig.boss_gold_base) * get_gold_mult(wave)


## Rounds gold down after absorbing float error.
static func floor_gold(amount: float) -> int:
	return int(floor(amount + FLOOR_TOLERANCE))


func _clamp_wave(wave: int) -> int:
	if wave < 1:
		push_error("Wave reward table queried with wave %d; using wave 1" % wave)
		return 1
	return wave


func _gold_mult_formula(wave: int) -> float:
	return 1.0 + GameConfig.gold_reward_growth_per_wave * float(wave - 1)


func _report_missing_row(column: String, wave: int, rows: int) -> void:
	push_error("Wave reward table has no %s row for wave %d (%d rows, victory_wave %d)" % [column, wave, rows, GameConfig.victory_wave])
