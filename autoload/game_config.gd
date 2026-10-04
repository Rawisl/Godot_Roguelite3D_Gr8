extends Node

## Global game configuration constants and parameters (SRS 6.1, 6.2).

@export_group("Run & Wave")
@export var prep_time_early: float = 25.0
@export var prep_time_normal: float = 30.0
@export var prep_time_boss: float = 45.0
@export var max_alive: int = 70
@export var max_projectiles: int = 200
@export var early_call_gold_per_sec: int = 2
@export var early_call_cap: int = 40
@export var summary_duration: float = 10.0
@export var starting_gold: int = 150
@export var start_mult: float = 1.0

@export_group("Economy & Repair")
@export var conversion_rate: float = 0.30
@export var sell_refund_pct: float = 0.60
@export var repair_gold_per_pct: int = 4

@export_group("Emergency Repair")
@export var emg_repair_charges_max: int = 3
@export var emergency_repair_cooldown: float = 60.0
@export var emg_repair_heal_pct_base: float = 0.20
@export var emg_repair_heal_pct_per_level: float = 0.03

@export_group("Anti-Stuck")
@export var stuck_detect_time: float = 3.0
@export var stuck_progress_min: float = 0.5
@export var recycle_max: int = 2
@export var wave_hard_cap: float = 300.0
@export var wave_stall_timeout: float = 45.0
@export var no_damage_timeout: float = 10.0
@export var boss_stuck_time: float = 5.0
@export var boss_hop_radius: float = 6.0

@export_group("Boss & Overload")
@export var boss_timer_base: float = 90.0
@export var boss_timer_max: float = 120.0
@export var boss_intro_duration: float = 4.0
@export var boss_retreat_window: float = 15.0
@export var boss_lock_x1_window: float = 20.0


func get_prep_time(wave: int, is_boss: bool) -> float:
	if is_boss:
		return prep_time_boss
	return prep_time_early if wave <= 3 else prep_time_normal

func get_par_time(spawn_duration: float, is_boss: bool, boss_timer: float = 90.0) -> float:
	return (0.6 * boss_timer) if is_boss else (spawn_duration + 15.0)

func get_clear_mult(clear_time: float, par_time: float) -> float:
	if par_time <= 0.0:
		return 1.0
	if clear_time <= 0.7 * par_time:
		return 1.25
	elif clear_time <= 1.3 * par_time:
		return 1.00
	return 0.80

func get_boss_timer(n: int) -> float:
	return minf(boss_timer_max, boss_timer_base + 3.0 * float(maxi(1, n) - 1))

func get_overload_fortress_pct(n: int) -> float:
	return minf(0.60, 0.30 + 0.05 * float(maxi(1, n)))
