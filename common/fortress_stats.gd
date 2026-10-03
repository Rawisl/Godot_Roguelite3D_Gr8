class_name FortressStats
extends Resource

@export_group("Survivability")
@export var max_hp: int = 1000
## Damage taken = raw * (1 - armor_pct), rounded up, max = 60% (APL-03)
@export_range(0.0, 0.6, 0.01) var armor_pct: float = 0.0
## Number of melee enemies that can attack the fortress at the same time (FORT-01).
@export var melee_slots: int = 12


@export_group("Repair")
## Gold per 1% of max_hp missing. (REP-01, GLD-07)
@export var repair_gold_per_pct: int = 4


@export_group("Warning")
## HUD low HP warning threshold (ALR-01, FORT-06).
@export_range(0.0, 1.0, 0.01) var low_hp_warning_pct: float = 0.3
