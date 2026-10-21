class_name ScaleConfig
extends Resource

## Endless wave difficulty scale configuration 
## Tunable in .tres resource file (SCL-01)

@export_group("Budget & Duration")
@export var budget_base: float = 8.0
@export var budget_linear: float = 2.2
@export var budget_quadratic: float = 0.05
@export var scale_soft_cap_wave: int = 40
@export var budget_soft_cap_factor: float = 0.5
@export var spawn_duration_base: float = 15.0
@export var spawn_duration_linear: float = 0.5
@export var spawn_duration_min: float = 15.0
@export var spawn_duration_max: float = 45.0
@export var max_alive: int = 70

@export_group("Multipliers")
@export var hp_mult_base: float = 1.0
@export var hp_mult_linear: float = 0.10
@export var hp_mult_quadratic: float = 0.004

@export var dmg_mult_base: float = 1.0
@export var dmg_mult_linear: float = 0.06
@export var dmg_mult_quadratic: float = 0.002

@export var speed_mult_base: float = 1.0
@export var speed_mult_linear: float = 0.005
@export var speed_mult_max: float = 1.25

@export_group("Reward Scale")
@export var gold_growth_per_wave: float = 0.04

# Backward compatibility
@export var hp_growth_per_wave: float = 0.08
@export var damage_growth_per_wave: float = 0.05


## Raw unrounded budget formula f(w) = budget_base + budget_linear*(w-1) + budget_quadratic*(w-1)^2
func get_raw_budget(wave: int) -> float:
	var x: float = float(maxi(1, wave) - 1)
	return budget_base + budget_linear * x + budget_quadratic * (x * x)


## SCL-02: After scale_soft_cap_wave (40), growth is reduced by budget_soft_cap_factor (0.5):
## budget(w) = round(f(40) + budget_soft_cap_factor * (f(w) - f(40)))
func get_budget(wave: int) -> int:
	var w: int = maxi(1, wave)
	if w <= scale_soft_cap_wave:
		return int(round(get_raw_budget(w)))
	var f_cap: float = get_raw_budget(scale_soft_cap_wave)
	var f_w: float = get_raw_budget(w)
	return int(round(f_cap + budget_soft_cap_factor * (f_w - f_cap)))


## spawn_duration(w) = clamp(15 + 0.5(w-1), 15, 45)
func get_spawn_duration(wave: int) -> float:
	var x: float = float(maxi(1, wave) - 1)
	return clampf(spawn_duration_base + spawn_duration_linear * x, spawn_duration_min, spawn_duration_max)


## hp_mult(w) = 1 + 0.10(w-1) + 0.004(w-1)^2
func get_hp_mult(wave: int) -> float:
	var x: float = float(maxi(1, wave) - 1)
	return hp_mult_base + hp_mult_linear * x + hp_mult_quadratic * (x * x)


## dmg_mult(w) = 1 + 0.06(w-1) + 0.002(w-1)^2 
func get_dmg_mult(wave: int) -> float:
	var x: float = float(maxi(1, wave) - 1)
	return dmg_mult_base + dmg_mult_linear * x + dmg_mult_quadratic * (x * x)


## speed_mult(w) = min(1.25, 1 + 0.005(w-1)) 
func get_speed_mult(wave: int) -> float:
	var x: float = float(maxi(1, wave) - 1)
	return minf(speed_mult_max, speed_mult_base + speed_mult_linear * x)


## gold_reward(w) = gold_reward_base * (1 + 0.04(w-1)) (RWD-02)
func get_gold_reward(base_gold: int, wave: int) -> int:
	var mult: float = 1.0 + gold_growth_per_wave * float(maxi(1, wave) - 1)
	return int(round(float(base_gold) * mult))


func get_scale_summary(wave: int) -> Dictionary:
	return {
		"wave": wave,
		"budget": get_budget(wave),
		"spawn_duration": get_spawn_duration(wave),
		"hp_mult": get_hp_mult(wave),
		"dmg_mult": get_dmg_mult(wave),
		"speed_mult": get_speed_mult(wave)
	}
