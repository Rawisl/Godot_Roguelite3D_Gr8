class_name EnemyData
extends Resource

## Enemy Data definition (SRS 3.7.1, v1.4).
## READ-ONLY at runtime: parameters are tuned in the .tres file.

@export_group("Identity")
@export var id: StringName = &"grunt"
@export var display_name_key: String = "enemy.grunt"

@export_group("Combat Stats")
@export var base_hp: int = 40
@export var base_damage: int = 6
@export var attack_interval: float = 1.0  # seconds between attacks
@export var attack_range: float = 1.5     # meters
@export var move_speed: float = 3.5       # meters / second
@export var damage_type: Enums.DamageType = Enums.DamageType.SLASH

@export_group("Spawning & Avoidance")
@export var spawn_cost: int = 1
@export var is_flying: bool = false
@export var is_ranged: bool = false
@export var knockback_immune: bool = false
@export var aggro_range: float = 10.0     # meters
@export var avoid_radius: float = 0.5     # meters
@export var avoid_priority: int = 1       # 1 for light units, 3 for brute

@export_group("Targeting Rules")
## Ordered category priority (SRS 3.7.3): PLAYER, BARRICADE, TOWER_GROUND, TOWER_WALL, FORTRESS
@export var target_rules: Array[StringName] = [&"BARRICADE", &"TOWER_GROUND", &"FORTRESS"]

@export_group("Rewards")
@export var gold_reward: int = 4
@export var prestige_reward: int = 1

# Backward-compatibility aliases for existing code
var max_hp: int:
	get: return base_hp
	set(v): base_hp = v
var damage: int:
	get: return base_damage
	set(v): base_damage = v


## ===================================================================
## FUNCTIONS (Thêm ở cuối file theo quy ước nhóm)
## ===================================================================

## Tính HP thực tế sau khi áp dụng hp_mult của wave (SCL-05)
func get_scaled_hp(hp_mult: float) -> int:
	return maxi(1, int(round(float(base_hp) * hp_mult)))

## Tính sát thương thực tế sau khi áp dụng dmg_mult của wave
func get_scaled_damage(dmg_mult: float) -> int:
	return maxi(1, int(round(float(base_damage) * dmg_mult)))

## Tính tốc độ di chuyển sau khi áp dụng speed_mult của wave
func get_scaled_speed(speed_mult: float) -> float:
	return move_speed * speed_mult

## Tính vàng thưởng theo wave w (SRS RWD-02: gold_reward_gốc * (1 + 0.04(w-1)))
func get_scaled_gold_reward(wave: int) -> int:
	var w: int = maxi(1, wave)
	var mult: float = 1.0 + 0.04 * float(w - 1)
	return int(round(float(gold_reward) * mult))
