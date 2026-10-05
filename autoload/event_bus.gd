extends Node
@warning_ignore_start("unused_signal")

#-----------------------Run and Wave-----------------------#
signal run_started
signal run_ended(end_type: StringName, summary: Dictionary)  # FORTRESS_DESTROYED | COMMANDER_DIED | ABANDONED
signal run_recovered(prestige_gain: int)  # khoi phuc run gian doan (3.12.4)
signal wave_started(wave_index: int)
signal wave_cleared(wave_index: int)
signal state_changed(new_state: StringName)  # PREP | COMBAT | SUMMARY | BOSS_INTRO | BOSS_COMBAT
signal prep_timer_changed(remaining: float)
signal wave_preview_ready(wave_index: int, composition: Dictionary, is_boss: bool)  # PNL-05
signal early_call_requested  # UI -> Wave (call wave early - press G)
signal wave_summary_ready(summary: Dictionary)  # phat SAU KHI save xong (SAV-05, GLD-08)
signal fortress_destroyed
signal fortress_hp_changed(hp: int, max_hp: int)
signal fortress_damaged(amount: int, damage_type: StringName, source: StringName)
signal fortress_low_hp(ratio: float)  # ALR-01, mot lan moi wave
signal fortress_repaired(amount: int, source: StringName)  # source: GOLD | EMERGENCY
#------------------------------------------------------#

#-----------------------Enemy-----------------------#

signal enemy_spawned(enemy: Node)
signal enemy_died(enemy_type: StringName, position: Vector3, gold_base: int, prestige: int, is_cull: bool)  # is_cull: khong thuong, khong tinh kill (RWD-03)
signal enemy_count_changed(alive: int, queued: int, total: int)  # HUD-03, nguong nhac 20 va 45
signal straggler_marker_shown(enemy: Node)  # EN-01, sau 60 s
signal frenzy_started(enemy: Node)  # EN-02, sau 240 s
signal stuck_event_logged(tier: int, enemy_type: StringName, position: Vector3, wave_index: int)  # NAV-14

#------------------------------------------------------#

#-----------------------Commander-----------------------#
signal commander_died
signal commander_hp_changed(hp: int, max_hp: int)
signal mode_changed(mode: StringName)  # FRONTLINE | COMMANDER
signal mode_switch_denied(reason: StringName, remaining: float)  # HUD-06
signal recall_started(duration: float)
signal recall_cancelled
signal recall_completed
signal skill_cooldown_changed(skill_id: StringName, remaining: float, total: float)
signal emergency_repair_state_changed(charges: int, cooldown: float, heal_pct: float)  # HUD-13, PNL-04
signal emergency_repair_denied(reason: StringName)
signal emergency_repair_charge_granted(charges: int)  # BRW-07
signal retreat_availability_changed(available: bool, reason: StringName)  # RET-05
signal retreat_performed
#------------------------------------------------------#


#-----------------------Currency and build-----------------------#
signal gold_changed(gold: int)
signal gold_delta(delta: int)  # so noi "+xx" tren HUD (GLD-05)
signal prestige_pending_changed(value: int)
signal prestige_balance_changed(value: int)
signal slot_state_changed(slot_id: StringName, state: StringName)  # EMPTY | OCCUPIED | RUINED
signal slot_selected(slot_id: StringName)
signal tower_selected(slot_id: StringName)
signal tower_built(slot_id: StringName, type: StringName)
signal tower_upgraded(slot_id: StringName, type: StringName, level: int)
signal tower_sold(slot_id: StringName)
signal tower_destroyed(slot_id: StringName)
signal tower_priority_changed(slot_id: StringName, priority: StringName)
signal tower_immunity_changed(slot_id: StringName, is_immune: bool)  # BOSS-13
signal build_denied(reason: StringName, shortfall: int)  # BLD-01
signal projectile_hit(target: Node, amount: int, damage_type: StringName, resist: float)
#------------------------------------------------------#

#-----------------------Boss-----------------------#
signal boss_spawned
signal boss_intro_started(boss_id: StringName)
signal boss_timer_changed(t: float)
signal boss_timer_milestone(t_mark: int)  # 30, 20, 15, 5 (BTM-04)
signal boss_hp_changed(armor_hp: int, core_hp: int, phase: StringName)  # HUD-02
signal boss_phase_changed(phase: StringName)  # ARMORED | TRANSITION | EXPOSED
signal telegraph_started(kind: StringName, position: Vector3, radius: float, duration: float)  # FBK-06
signal overload_resolved(fortress_damage: int, commander_exposed: bool)  # chi emit mot lan moi wave boss (OVL-03)
signal boss_defeated
#------------------------------------------------------#


#-----------------------Time-----------------------#
signal time_scale_changed(scale: int)
signal pause_changed(is_paused: bool)
signal performance_degraded(fps: float)  # ALR-10
#------------------------------------------------------#

#-----------------------Meta, save, setting-----------------------#
signal meta_item_purchased(item_id: StringName, new_level: int)
signal save_completed
signal save_failed(reason: StringName)  # ALR-11
signal settings_changed(key: StringName, value: Variant)
#------------------------------------------------------#


#------------------Warning, sfx, audio, tutorial,...------------------#
signal alert_requested(tier: int, key: StringName, params: Dictionary)  # tier 1 | 2 | 3; key = locale key
signal screen_shake_requested(intensity: float, source: StringName)  # FBK-03, ACC-05
signal sfx_requested(sound_id: StringName, position: Vector3, priority: int)  # AUD-02, AUD-03
signal duck_requested(amount_db: float, duration: float)  # AUD-05
signal tutorial_step_completed(step_id: StringName)
#------------------------------------------------------#

@warning_ignore_restore("unused_signal")
