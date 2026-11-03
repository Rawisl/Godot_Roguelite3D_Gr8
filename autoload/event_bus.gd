extends Node
@warning_ignore_start("unused_signal")

#-----------------------Run and Wave-----------------------#
signal run_started
signal run_ended(end_type: StringName, summary: Dictionary)  # FORTRESS_DESTROYED | COMMANDER_DIED | ABANDONED
signal run_recovered(prestige_gain: int)  # recover interrupted run
signal wave_started(wave_index: int)
signal wave_cleared(wave_index: int)
signal state_changed(new_state: StringName)  # PREP | COMBAT | SUMMARY | BOSS_INTRO | BOSS_COMBAT
signal prep_timer_changed(remaining: float)
signal wave_preview_ready(wave_index: int, composition: Dictionary, is_boss: bool)
signal early_call_requested  # UI -> Wave (call wave early - press G)
signal wave_summary_ready(summary: Dictionary)  # emitted AFTER save completes
signal summary_continue_requested  # UI -> Wave: press Continue or after 10s countdown in SUMMARY
signal fortress_destroyed
signal fortress_hp_changed(new_hp: int, max_hp: int, delta: int)  # delta < 0 on HP loss
signal fortress_damaged(amount: int, damage_type: StringName, source: StringName)
signal fortress_low_hp(ratio: float)  #once per wave
signal fortress_repaired(amount: int, source: StringName)  # source: GOLD | EMERGENCY
#------------------------------------------------------#

#-----------------------Enemy-----------------------#

signal enemy_spawned(enemy: Node)
signal enemy_died(enemy_type: StringName, position: Vector3, gold_base: int, prestige: int, is_cull: bool, hit_by_commander: bool)  # is_cull: no reward, no kill credit, hit_by_commander 
signal enemy_count_changed(alive: int, queued: int, total: int)  # reminder thresholds 20 and 45
signal straggler_marker_shown(enemy: Node)  # after 60s
signal frenzy_started(enemy: Node)  # after 240s
signal stuck_event_logged(tier: int, enemy_type: StringName, position: Vector3, wave_index: int)

#------------------------------------------------------#

#-----------------------Commander-----------------------#
signal commander_died
signal commander_hp_changed(hp: int, max_hp: int)
signal heal_state_changed(state: StringName, source_slot: StringName, hold_progress: float)  # IDLE | HOLD | HEALING | CANCELLED | DEPLETED, progress 0..1 and sent at most 10 times a second while holding
signal commander_low_hp_changed(is_low: bool)  # HP below commander_low_hp_warning_pct, emitted only when it flips
signal mode_changed(mode: StringName)  # FRONTLINE | COMMANDER
signal mode_switch_denied(reason: StringName, remaining: float)
signal mode_switch_cooldown_started(duration: float)  # ModeSwitch -> HUD, only when the switch costs a cooldown
signal recall_started(duration: float)
signal recall_cancelled
signal recall_completed
signal aura_changed(active: bool)  # Frontline aura source on/off: mode, stun, recall, deploy, death
signal skill_cooldown_changed(skill_id: StringName, remaining: float, total: float)
signal emergency_repair_state_changed(charges: int, cooldown: float, heal_pct: float)
signal emergency_repair_denied(reason: StringName)
signal emergency_repair_charge_granted(charges: int)
signal retreat_availability_changed(available: bool, reason: StringName)
signal retreat_performed
#------------------------------------------------------#


#-----------------------Currency and build-----------------------#
signal gold_changed(gold: int)
signal gold_delta(delta: int)  # floating "+xx" text on HUD
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
signal tower_immunity_changed(slot_id: StringName, is_immune: bool)
signal heal_tower_hp_changed(slot_id: StringName, new_hp: int, max_hp: int)  # Heal station store, at most 10 times a second
signal build_denied(reason: StringName, shortfall: int)
signal projectile_hit(target: Node, amount: int, damage_type: StringName, resist: float)
#------------------------------------------------------#

#-----------------------Boss-----------------------#
signal boss_spawned
signal boss_intro_started(boss_id: StringName)
signal boss_timer_changed(t: float)
signal boss_timer_milestone(t_mark: int)  # 30, 20, 15, 5
signal boss_hp_changed(armor_hp: int, core_hp: int, phase: StringName)
signal boss_phase_changed(phase: StringName)  # ARMORED | TRANSITION | EXPOSED
signal telegraph_started(kind: StringName, position: Vector3, radius: float, duration: float) 
signal overload_resolved(fortress_damage: int, commander_exposed: bool)  # emitted once per boss wave
signal boss_defeated
#------------------------------------------------------#


#-----------------------Time-----------------------#
signal time_scale_changed(scale: int)
signal pause_changed(is_paused: bool)
signal performance_degraded(fps: float)
#------------------------------------------------------#

#-----------------------Meta, save, setting-----------------------#
signal meta_item_purchased(item_id: StringName, new_level: int)
signal save_completed
signal save_failed(reason: StringName)
signal settings_changed(key: StringName, value: Variant)
#------------------------------------------------------#


#-----------------------Skill and reward-----------------------#
signal reward_picked(card_id: StringName, slot_kind: StringName, new_level: int)  # UI -> StatBlock, SkillRunner, RunState. new_level is the absolute level after the pick
signal skill_cast(skill_id: StringName, slot_index: int, level: int, origin: Vector3, radius: float)  # SkillRunner -> VFX, audio, once per cast
#------------------------------------------------------#


#------------------Warning, sfx, audio, tutorial,...------------------#
signal alert_requested(tier: int, key: StringName, params: Dictionary)  # tier 1 | 2 | 3; key = locale key
signal screen_shake_requested(intensity: float, source: StringName)
signal sfx_requested(sound_id: StringName, position: Vector3, priority: int)
signal duck_requested(amount_db: float, duration: float)
signal tutorial_step_completed(step_id: StringName)
#------------------------------------------------------#

#-----------------------Progression-----------------------#
signal xp_changed(xp: float, level: int, to_next: float, pending_picks: int)
signal level_up(new_level: int, pending_picks: int)
signal reward_offered(cards: Array, rerolls_left: int)
signal skill_slots_changed(active: Array, passive: Array)
#------------------------------------------------------#

@warning_ignore_restore("unused_signal")
