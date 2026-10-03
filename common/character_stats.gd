class_name CharacterStats
extends Resource

## Commander stats (SRS 3.5.1, v1.4). Starting values, tune in the .tres file during playtests.
## READ-ONLY at runtime: never assign to these fields. Meta bonuses (e.g. CMD_HP) are applied
## once in RunLoading and stored in RunState (APL-01, APL-02).
## Ratio fields (*_pct) use 0.0 to 1.0 (60% = 0.6), matching the formula in SRS 3.5.7.
## Do not enter percentages such as 60 or 80.

@export_group("Survivability")
@export var commander_max_hp: int = 100
@export_range(0.0, 0.75, 0.01) var armor_pct: float = 0.0
@export_range(0.0, 1.0, 0.01) var prep_heal_pct: float = 0.6
@export_range(0.0, 1.0, 0.001) var commander_regen_pct_per_sec: float = 0.02
@export var commander_mode_damage_mult: float = 0.0

@export_group("Movement")
@export var move_speed: float = 6.0
@export var dodge_distance: float = 4.0
@export var dodge_iframe: float = 0.3
@export var dodge_cooldown: float = 1.5

@export_group("Sword")
@export var sword_damage: int = 20
@export var sword_damage_type: Enums.DamageType = Enums.DamageType.SLASH
@export var sword_range: float = 2.2
@export var sword_arc_deg: float = 120.0
@export var attack_interval: float = 0.45
@export var combo_hit3_mult: float = 1.5

@export_group("Skill And Mode")
@export var skill_cooldown: float = 12.0
@export var mode_switch_cooldown: float = 5.0
