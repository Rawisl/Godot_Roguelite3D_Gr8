class_name FortressStats
extends Resource

@export_group("Survivability")
@export var max_hp: int = 1000
## Base value. Run value = max_hp * (1 + 0.05 * FORT_HP level), computed at RunLoading (6.5, FORT-04).
## Damage taken = raw * (1 - armor_pct), rounded up, min 1, TRUE ignores it (3.6.1).
## armor_pct is capped by GameConfig.fortress_armor_cap (APL-03).
@export_range(0.0, 0.6, 0.01) var armor_pct: float = 0.0
## Number of melee enemies that can attack the fortress at the same time (FORT-01).
@export var melee_slots: int = 12


@export_group("Repair")
## Gold per 1% of max_hp missing. (REP-01, GLD-07)
@export var repair_gold_per_pct: int = 4
## Two quick repair buttons, as a fraction of max_hp. The third button is "full HP". (REP-01, 6.5)
@export_range(0.01, 1.0, 0.01) var repair_step_small_pct: float = 0.10
@export_range(0.01, 1.0, 0.01) var repair_step_large_pct: float = 0.25


@export_group("Warning")
## HUD low HP warning threshold (ALR-01, FORT-06).
@export_range(0.0, 1.0, 0.01) var low_hp_warning_pct: float = 0.3
