class_name FortressStats
extends Resource

@export_group("Survivability")
@export var max_hp: int = 1000
## Base value. Run value = max_hp * (1 + 0.05 * FORT_HP level), computed at RunLoading.
## Damage taken = raw * (1 - armor_pct), rounded up, min 1, TRUE ignores it.
## armor_pct is capped by GameConfig.fortress_armor_cap.
@export_range(0.0, 0.6, 0.01) var armor_pct: float = 0.0
## Number of melee enemies that can attack the fortress at the same time.
@export var melee_slots: int = 12


@export_group("Repair")
## Share of max_hp one Mithril heals, capped at max_hp.
@export_range(0.01, 1.0, 0.01) var mithril_repair_pct: float = 0.20


@export_group("Warning")
## HUD low HP warning threshold.
@export_range(0.0, 1.0, 0.01) var low_hp_warning_pct: float = 0.3
