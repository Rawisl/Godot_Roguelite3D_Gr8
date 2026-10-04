class_name BossData
extends EnemyData

## Boss Data definition (SRS 3.8.2, v1.4).
## READ-ONLY at runtime: parameters are tuned in the .tres file.

@export_group("Boss Phases & Health")
@export var armor_hp: int = 1200
@export var core_hp: int = 900
@export var transition_duration: float = 2.5  # giây choáng khi vỡ giáp (SRS 3.8.4)

@export_group("Phase 2 Buffs")
@export var phase2_speed_mult: float = 1.2
@export var phase2_attack_rate_mult: float = 1.3

@export_group("Damage Resistances (Phase 1)")
## resist_table: { Enums.DamageType: float (multiplier) }. 0.0 = miễn nhiễm hoàn toàn (DMG-01, DMG-02)
@export var resist_table_phase1: Dictionary = {
	Enums.DamageType.PIERCE: 0.0,
	Enums.DamageType.MAGIC: 0.0,
	Enums.DamageType.BLAST: 1.0,
	Enums.DamageType.SLASH: 0.6,
	Enums.DamageType.TRAP: 1.0,
	Enums.DamageType.TRUE: 1.0,
}

@export_group("Boss Overload & Timer")
@export var boss_timer: float = 90.0

@export_group("Boss Rewards")
@export var boss_gold: int = 100
@export var boss_prestige: int = 15


## ===================================================================
## FUNCTIONS (Thêm ở cuối file theo quy ước nhóm)
## ===================================================================

## Lấy hệ số kháng sát thương theo loại sát thương và pha hiện tại (DMG-01, SRS 3.8.4)
## Phase: ARMORED (0) dùng resist_table_phase1. TRANSITION (1) nhận x1.5 mọi loại. EXPOSED (2) nhận x1.25 mọi loại.
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

## Kiểm tra miễn nhiễm hoàn toàn với loại sát thương hay không (resist == 0.0)
func is_immune(dmg_type: Enums.DamageType, phase: Enums.BossPhase) -> bool:
	return is_zero_approx(get_resist(dmg_type, phase))

## Tính armor_hp sau khi nhân hp_mult của wave
func get_scaled_armor_hp(hp_mult: float) -> int:
	return maxi(1, int(round(float(armor_hp) * hp_mult)))

## Tính core_hp sau khi nhân hp_mult của wave
func get_scaled_core_hp(hp_mult: float) -> int:
	return maxi(1, int(round(float(core_hp) * hp_mult)))

## Tính vàng thưởng khi diệt boss theo wave: 100 * (1 + 0.04(w-1)) (SRS BRW-01)
func get_scaled_boss_gold(wave: int) -> int:
	var w: int = maxi(1, wave)
	var mult: float = 1.0 + 0.04 * float(w - 1)
	return int(round(float(boss_gold) * mult))
