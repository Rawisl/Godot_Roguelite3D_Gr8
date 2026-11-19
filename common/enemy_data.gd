class_name EnemyData
extends Resource

## Base definition for enemy archetypes 

@export_group("Identity")
@export var id: StringName = &"grunt"
@export var display_name_key: String = "enemy.grunt"

@export_group("Combat Stats")
@export var base_hp: int = 40
@export var base_damage: int = 6
@export var attack_interval: float = 1.0
@export var attack_range: float = 1.5
@export var move_speed: float = 3.5
@export var damage_type: Enums.DamageType = Enums.DamageType.SLASH
@export var knockback_force: float = 0.0
@export var projectile_speed: float = 20.0

@export_group("Visuals & Animation")
@export var anim_walk: StringName = &"move/Running_A"
@export var anim_attack: StringName = &"melee/Melee_1H_Attack_Slice_Diagonal"
@export var anim_shoot: StringName = &""

@export_group("Spawning & Navigation")
@export var spawn_cost: int = 1
@export var is_flying: bool = false
@export var is_ranged: bool = false
@export var knockback_immune: bool = false
@export var aggro_range: float = 10.0
@export var agent_radius: float = 0.5

@export_group("Targeting Rules")
## Ordered category priority: PLAYER, BARRICADE, TOWER_GROUND, TOWER_WALL, FORTRESS
@export var target_rules: Array[StringName] = [&"BARRICADE", &"TOWER_GROUND", &"FORTRESS"]

@export_group("Rewards")
@export var gold_reward: int = 4
@export var prestige_reward: int = 1
@export var xp_value: int = 1

@export_group("Traits")
## Every trait is off by default, so a unit without them behaves as before.
# TODO(Ender-Via): make Enemy act on is_stealth, invuln_*, revive_*, explode_* and is_charger when the Assassin, Knight, Undead, Suicide Squad and Brute rework land; read the flags here, never the unit id.
@export var is_stealth: bool = false
@export var stealth_opacity: float = 1.0
@export var explode_on_contact: bool = false
@export var explode_on_death: bool = false
@export var explode_radius: float = 0.0
@export var explode_damage: int = 0
@export var explode_windup: float = 0.0
@export var invuln_hp_threshold: float = 0.0
@export var invuln_duration: float = 0.0
@export var is_charger: bool = false
@export var impact_damage: int = 0
@export var impact_knockback: float = 0.0
@export var revive_count: int = 0
@export var revive_delay: float = 0.0
@export var revive_dmg_mult: float = 1.0

## Trait ids shown to the player (EnemyTraits.ALL), from the flags above, in that order.
var traits: Array[StringName]:
	get:
		var result: Array[StringName] = []
		if is_stealth:
			result.append(&"stealth")
		if explode_on_contact or explode_on_death:
			result.append(&"explode")
		if invuln_duration > 0.0 and invuln_hp_threshold > 0.0:
			result.append(&"undying")
		if revive_count > 0:
			result.append(&"revive")
		if is_charger:
			result.append(&"charge")
		return result

# Backward-compatibility aliases
var max_hp: int:
	get: return base_hp
	set(v): base_hp = v
var damage: int:
	get: return base_damage
	set(v): base_damage = v


func get_scaled_hp(hp_mult: float) -> int:
	return maxi(1, int(round(float(base_hp) * hp_mult)))

func get_scaled_damage(dmg_mult: float) -> int:
	return maxi(1, int(round(float(base_damage) * dmg_mult)))

func get_scaled_speed(speed_mult: float) -> float:
	return move_speed * speed_mult
