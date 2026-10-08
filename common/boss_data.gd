class_name BossData
extends EnemyData

## Boss archetype definition with multi-phase mechanics 

@export_group("Phases & Health")
@export var armor_hp: int = 1200
@export var core_hp: int = 900
@export var transition_duration: float = 2.5

@export_group("Phase 2 Multipliers")
@export var phase2_speed_mult: float = 1.2
@export var phase2_attack_rate_mult: float = 1.3

@export_group("Phase 1 Resistances")
## Resistance multipliers per damage type in phase 1 (0.0 = immune, DMG-01, DMG-02)
@export var resist_table_phase1: Dictionary = {
	Enums.DamageType.PIERCE: 0.0,
	Enums.DamageType.MAGIC: 0.0,
	Enums.DamageType.BLAST: 1.0,
	Enums.DamageType.SLASH: 0.6,
	Enums.DamageType.TRAP: 1.0,
	Enums.DamageType.TRUE: 1.0,
}

@export_group("Timer & Rewards")
@export var boss_timer: float = 90.0
@export var boss_gold: int = 100
@export var boss_prestige: int = 15


func get_resist(dmg_type: Enums.DamageType, phase: Enums.BossPhase) -> float:
	if dmg_type == Enums.DamageType.TRUE:
		return 1.0
	match phase:
		Enums.BossPhase.ARMORED:
			return float(resist_table_phase1.get(dmg_type, 1.0))
		Enums.BossPhase.TRANSITION:
			return 1.5
		Enums.BossPhase.EXPOSED:
			return 1.25
	return 1.0

func is_immune(dmg_type: Enums.DamageType, phase: Enums.BossPhase) -> bool:
	return is_zero_approx(get_resist(dmg_type, phase))

func get_scaled_armor_hp(hp_mult: float) -> int:
	return maxi(1, int(round(float(armor_hp) * hp_mult)))

func get_scaled_core_hp(hp_mult: float) -> int:
	return maxi(1, int(round(float(core_hp) * hp_mult)))

func get_scaled_boss_gold(wave: int) -> int:
	var mult: float = 1.0 + 0.04 * float(maxi(1, wave) - 1)
	return int(round(float(boss_gold) * mult))
