class_name PrestigeCalc
extends RefCounted

## Prestige formulas shared by the wave summary, the run end and the interrupted-run recovery.


## Prestige for clearing wave `wave`: wave_prestige_base + floor(wave / wave_prestige_step).
static func wave_clear_prestige(wave: int) -> int:
	if GameConfig.wave_prestige_step <= 0:
		return GameConfig.wave_prestige_base
	return GameConfig.wave_prestige_base + maxi(wave, 1) / GameConfig.wave_prestige_step


## Prestige converted at the run end: floor((pending + prestige_buffer_ratio * buffer)
## * conversion_rate * start_mult), never negative.
static func prestige_gain(pending: int, buffer: int, start_mult: float) -> int:
	var raw: float = (float(pending) + GameConfig.prestige_buffer_ratio * float(buffer)) \
			* GameConfig.conversion_rate * start_mult
	return maxi(0, WaveRewardTable.floor_gold(raw))
