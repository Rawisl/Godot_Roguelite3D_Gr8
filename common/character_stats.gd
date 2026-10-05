class_name CharacterStats
extends Resource

## Commander stats. Starting values, tune in the .tres file during playtests.
## READ-ONLY at runtime: never assign to these fields. Meta bonuses (e.g. CMD_HP) are applied once in RunLoading and stored in RunState
## Do not enter percentages such as 60 or 80.

@export_group("Survivability")
@export var commander_max_hp: int = 100
@export_range(0.0, 0.75, 0.01) var armor_pct: float = 0.0
@export_range(0.0, 1.0, 0.01) var prep_heal_pct: float = 0.60
@export_range(0.0, 1.0, 0.001) var commander_regen_pct_per_sec: float = 0.02
@export_range(0.0, 1.0, 0.01) var commander_low_hp_warning_pct: float = 0.25
@export var commander_mode_damage_mult: float = 0.0
@export_range(0.0, 1.0, 0.01) var fall_damage_pct: float = 0.15

@export_group("Movement")
@export var move_speed: float = 6.0
@export var dodge_distance: float = 4.0
@export var dodge_iframe: float = 0.3
@export var dodge_cooldown: float = 1.5

@export_group("Sword & Attack")
@export var sword_damage: int = 20
@export var sword_damage_type: Enums.DamageType = Enums.DamageType.SLASH
@export var sword_range: float = 2.2
@export var sword_arc_deg: float = 120.0
@export var sword_max_targets: int = 3
@export var attack_interval: float = 0.45
@export var combo_hit3_mult: float = 1.5
@export var combo_window: float = 0.35
@export var combo_reset_time: float = 0.6
@export var combo_hit3_knockback: float = 1.5
@export var input_buffer_time: float = 0.15

@export_group("Skill - Battle Cry")
@export var skill_cooldown: float = 12.0
@export var skill_animation_time: float = 0.5
@export var battle_cry_radius: float = 6.0
@export var battle_cry_duration: float = 4.0
@export var battle_cry_damage_mult: float = 0.7

@export_group("Mode Switch, Deploy & Recall")
@export var mode_switch_cooldown: float = 5.0
@export var recall_time_in_zone: float = 0.6
@export var recall_time_outside: float = 3.0
@export var deploy_invuln_time: float = 0.6
@export var deploy_point_search_radius: float = 4.0
@export var deploy_clear_radius: float = 0.8
@export var deploy_shockwave_radius: float = 3.0
@export var deploy_shockwave_distance: float = 2.0
@export var retreat_fade_time: float = 0.5
