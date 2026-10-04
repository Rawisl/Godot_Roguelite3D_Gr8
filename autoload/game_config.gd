extends Node

## Global game configuration constants and parameters (SRS-EW-1.6, Section 6.3).

@export_group("Run and Wave")
@export var starting_gold: int = 150
@export var prep_time_early: float = 25.0
@export var prep_early_until_wave: int = 3
@export var prep_time_late: float = 30.0
@export var prep_time_boss: float = 45.0
@export var max_alive: int = 70
@export var summary_auto_advance: float = 10.0
@export var boss_wave_interval: int = 5

@export_group("Economy")
@export var early_call_gold_per_sec: int = 2
@export var early_call_cap: int = 40
@export var clear_mult_fast: float = 1.25
@export var clear_mult_normal: float = 1.00
@export var clear_mult_slow: float = 0.80
@export var clear_fast_threshold: float = 0.7
@export var clear_slow_threshold: float = 1.3
@export var par_time_offset: float = 15.0
@export var par_time_boss_ratio: float = 0.6
@export var gold_reward_growth_per_wave: float = 0.04
@export var boss_gold_base: int = 100
@export var boss_prestige: int = 15
@export var wave_prestige_base: int = 2
@export var wave_prestige_step: int = 5
@export var prestige_buffer_ratio: float = 0.5
@export var conversion_rate: float = 0.30
@export var sell_refund_pct: float = 0.60

@export_group("Emergency Repair")
@export var emg_repair_charges_max: int = 3
@export var emg_repair_charges_start: int = 3
@export var emg_repair_base_heal_pct: float = 0.20
@export var emergency_repair_cooldown: float = 60.0
@export var emg_repair_boss_refund: int = 1

@export_group("Armor Caps")
@export var commander_armor_cap: float = 0.75
@export var fortress_armor_cap: float = 0.60

@export_group("Tower General")
@export var max_projectiles: int = 200
@export var scan_interval: float = 0.2
@export var retarget_delay: float = 0.3
@export var tower_full_heal_on_prep: bool = true
@export var max_attackers_per_barricade: int = 5
@export var max_attackers_per_tower: int = 3
@export var sell_undo_window: float = 3.0

@export_group("Enemy and Aggro")
@export var retarget_interval: float = 0.4
@export var path_update_interval: float = 0.3
@export var aggro_duration: float = 4.0
@export var leash_distance: float = 25.0
@export var max_aggro_melee: int = 8
@export var bat_max_per_target: int = 6
@export var enemy_windup_time: float = 0.4
@export var enemy_stagger_time: float = 0.4
@export var enemy_knockback_immunity_time: float = 2.0
@export var retarget_batch_size: int = 8
@export var spawn_grace_max_time: float = 10.0
@export var frenzy_speed_mult: float = 1.5
@export var straggler_marker_time: float = 60.0
@export var frenzy_time: float = 240.0

@export_group("Anti-Stuck and Crowd")
@export var stuck_detect_time: float = 3.0
@export var stuck_progress_min: float = 0.5
@export var stuck_escalate_time: float = 3.0
@export var stuck_reset_time: float = 10.0
@export var queue_block_distance: float = 1.5
@export var ally_phase_time: float = 1.5
@export var commander_block_wait: float = 2.0
@export var recycle_max: int = 2
@export var wave_hard_cap: float = 300.0
@export var boss_stuck_time: float = 5.0
@export var boss_stuck_step_time: float = 5.0
@export var boss_hop_radius: float = 6.0
@export var crowd_claim_distance: float = 6.0
@export var crowd_wait_ring: float = 3.0
@export var crowd_wait_retarget_time: float = 3.0
@export var crowd_full_target_ignore_time: float = 5.0
@export var crowd_slot_audit_interval: float = 2.0
@export var wave_stall_timeout: float = 45.0
@export var hop_radius: float = 3.0
@export var hop_max_advance: float = 4.0
@export var no_damage_timeout: float = 10.0

@export_group("Boss and Overload")
@export var boss_intro_duration: float = 4.0
@export var boss_intro_skip_delay: float = 1.0
@export var boss_transition_time: float = 2.5
@export var boss_timer_base: float = 90.0
@export var boss_timer_step: float = 3.0
@export var boss_timer_max: float = 120.0
@export var overload_pct_base: float = 0.30
@export var overload_pct_step: float = 0.05
@export var overload_pct_max: float = 0.60
@export var overload_commander_pct: float = 0.60
@export var overload_warn_time: float = 30.0
@export var speed_lock_time: float = 20.0
@export var retreat_open_time: float = 15.0
@export var overload_countdown_time: float = 5.0

@export_group("Timing and Performance")
@export var fps_downscale_floor: float = 30.0
@export var fps_downscale_duration: float = 3.0


func get_prep_time(wave: int, is_boss: bool) -> float:
	if is_boss:
		return prep_time_boss
	return prep_time_early if wave <= prep_early_until_wave else prep_time_late


func get_par_time(spawn_duration: float, is_boss: bool, boss_timer: float = 90.0) -> float:
	return (par_time_boss_ratio * boss_timer) if is_boss else (spawn_duration + par_time_offset)


func get_clear_mult(clear_time: float, par_time: float) -> float:
	if par_time <= 0.0:
		return clear_mult_normal
	if clear_time <= clear_fast_threshold * par_time:
		return clear_mult_fast
	elif clear_time <= clear_slow_threshold * par_time:
		return clear_mult_normal
	return clear_mult_slow


func get_boss_timer(n: int) -> float:
	return minf(boss_timer_max, boss_timer_base + boss_timer_step * float(maxi(1, n) - 1))


func get_overload_fortress_pct(n: int) -> float:
	return minf(overload_pct_max, overload_pct_base + overload_pct_step * float(maxi(1, n)))
