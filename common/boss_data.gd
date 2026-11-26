class_name BossData
extends EnemyData
# TODO(Ender-Via): when the boss-wave playtest numbers are in, retune the triple stomp and combo damage multipliers here so a full chain still leaves a full-health commander alive above wave 5.

## Boss archetype definition with multi-phase mechanics 

@export_group("Phases & Health")
@export var armor_hp: int = 1200
@export var core_hp: int = 900
@export var transition_duration: float = 2.5

@export_group("Phase 2 Multipliers")
@export var phase2_speed_mult: float = 1.2
@export var phase2_attack_rate_mult: float = 1.3

@export_group("Phase 1 Resistances")
## Resistance multipliers per damage type in phase 1 (0.0 = immune).
@export var resist_table_phase1: Dictionary = {
	Enums.DamageType.PIERCE: 0.0,
	Enums.DamageType.MAGIC: 0.0,
	Enums.DamageType.BLAST: 1.0,
	Enums.DamageType.SLASH: 0.6,
	Enums.DamageType.TRAP: 1.0,
	Enums.DamageType.TRUE: 1.0,
}

@export_group("Navigation")
## Navigation layers of the navmesh baked for the large agent (agent_radius). 0 keeps the
## regular navmesh.
@export_flags_3d_navigation var nav_layers: int = 2

@export_group("Timer & Rewards")
@export var boss_timer: float = 90.0
@export var boss_gold: int = 100
@export var boss_prestige: int = 15


func _init() -> void:
	xp_value = 30
	move_speed = 1.6
	agent_radius = 1.6
	attack_range = 3.0
	attack_interval = 3.0
	knockback_immune = true
	base_hp = armor_hp + core_hp
	anim_walk = &"move/Walking_A"

@export_group("Stomp Attack")
@export var stomp_damage: int = 45
@export var stomp_radius: float = 3.0
@export var stomp_knockback: float = 3.0
@export var stomp_stun_duration: float = 0.0
@export var stomp_windup: float = 1.0
@export var stomp_screen_shake: float = 0.6
## Every stomp lands where the mace hits the ground: this many boss heights in front of the boss.
@export var stomp_forward_offset_heights: float = 1.25
## Used when the model height cannot be measured (no meshes, e.g. stripped test scenes).
@export var fallback_model_height: float = 3.17

@export_group("Commander AI")
## The commander counts as "in front" inside this cone (full angle) around the boss's facing.
@export var ai_front_arc_deg: float = 120.0
## Top turning speed between moves. Low values make flanking the boss pay off.
@export var ai_turn_rate_deg: float = 90.0
## Inside the Hazard Trial room there is nothing else to attack, so the boss turns this much faster
## to keep a commander circling behind it from fighting for free.
@export var hazard_turn_rate_mult: float = 2.0
## Commander at the flank or behind: triple stomp, then this many game seconds before the next one.
@export var triple_stomp_cooldown: float = 8.0
## Commander in front but out of the slash's reach, inside the ring the stomp would land on: the
## boss stomps it, then waits this many game seconds before it stomps the commander again.
@export var commander_stomp_cooldown: float = 6.0
## Below this share of total HP (armor + core) the combo competes with the normal attack.
@export var combo_hp_threshold: float = 0.5
## The boss minds the commander within the base aggro_range, or up to this far once the commander
## has hit it in the last aggro_duration seconds.
@export var commander_leash: float = 8.0
## Pause after the normal attack before the next move is chosen.
@export var attack_recovery: float = 0.6
## Longer pause after the triple stomp and the combo: the opening to hit back.
@export var heavy_attack_recovery: float = 1.75
## The boss shows up every few waves; appearance 1 is its first wave. Moves unlock by appearance:
## below triple_stomp_unlock_appearance a commander at the flank or behind gets the single stomp.
@export var triple_stomp_unlock_appearance: int = 2
## Below combo_unlock_appearance the front attack is always the normal attack.
@export var combo_unlock_appearance: int = 3
## Inside the Hazard Trial room the boss fights with the moveset of this many appearances earlier.
@export var hazard_appearance_offset: int = 1

@export_group("Utility AI")
## At each decision point every action gets a score (weight x its considerations) and the highest
## one wins. Actions within tie_margin of the best are rolled in proportion to their scores.
@export var ai_think_interval: float = 0.3
@export var tie_margin: float = 0.1
## The action family the boss is already doing (fighting the commander or pushing on) scores this
## much more, so two close scores do not flip back and forth.
@export var stickiness: float = 1.15
@export var weight_normal: float = 1.0
## Same as weight_normal makes it a 50/50 below combo_hp_threshold.
@export var weight_combo: float = 1.0
@export var weight_commander_stomp: float = 0.9
@export var weight_triple_stomp: float = 1.1
@export var weight_chase: float = 0.5
@export var weight_face: float = 0.5
## Leave the commander and push on to the next structure. Its score starts at push_base and climbs
## to the full weight while the commander keeps out of the boss's reach (behind it or kiting).
@export var weight_push: float = 1.5
@export var push_base: float = 0.2
## Seconds out of reach before pushing on starts to score higher, and how long it takes to peak.
@export var push_after: float = 2.5
@export var push_ramp: float = 1.5
## The out-of-reach count resets only after the commander stands in reach this long without a
## break (or the boss lands a hit), so circling past the boss's front does not reset it.
@export var reach_reset_time: float = 1.0
## Once the boss pushes on it ignores the commander for at least this long.
@export var push_commit_time: float = 4.0

@export_group("Normal Attack")
## One-handed slash; it uses the slash hitbox and timing of the combo below.
@export var normal_attack_damage: int = 18

@export_group("Combo Slam Attack")
@export var combo_slash_damage: int = 15
## Slash hitbox: a sector in front of the boss.
@export var combo_slash_range: float = 3.2
@export var combo_slash_arc_deg: float = 120.0
@export var combo_slash_duration: float = 1.57
@export var combo_slash_hit_time: float = 0.55
@export var combo_stab_damage: int = 20
## Stab hitbox: a narrow box straight ahead of the boss.
@export var combo_stab_range: float = 3.8
@export var combo_stab_width: float = 1.2
@export var combo_stab_knockback: float = 1.5
@export var combo_stab_duration: float = 1.40
@export var combo_stab_hit_time: float = 0.75
## The finisher is a stomp (BLAST) with its own timing, radius and share of stomp_damage.
@export var combo_slam_damage_mult: float = 0.75
@export var combo_slam_windup: float = 1.0
@export var combo_slam_duration: float = 2.83
@export var combo_slam_radius_mult: float = 1.0
@export var combo_slam_screen_shake: float = 0.7

@export_group("Triple Stomp Attack")
## Share of the slam clip each stomp plays before the next one restarts it (1.0 = whole clip).
@export var triple_stomp_clip_cut: float = 0.75
## Clip second at which the weapon meets the ground; the hit and the telegraph follow it.
@export var triple_stomp_hit_time: float = 0.97
@export var triple_stomp_anim_speed: float = 1.0
## One entry per stomp: radius as a multiple of stomp_radius, and the screen shake.
@export var triple_stomp_radius_mults: PackedFloat32Array = PackedFloat32Array([1.0, 1.5, 2.2])
@export var triple_stomp_screen_shakes: PackedFloat32Array = PackedFloat32Array([0.5, 0.8, 1.2])
## Share of stomp_damage each stomp deals, so the whole chain never kills a full-health commander.
@export var triple_stomp_damage_mults: PackedFloat32Array = PackedFloat32Array([0.5, 0.5, 0.75])

var stomp_cadence_phase1: float:
	get: return attack_interval

var stomp_cadence_phase2: float:
	get: return attack_interval / maxf(0.1, phase2_attack_rate_mult)



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

func get_scaled_hp(hp_mult: float) -> int:
	return get_scaled_armor_hp(hp_mult) + get_scaled_core_hp(hp_mult)

func get_scaled_armor_hp(hp_mult: float) -> int:
	return maxi(1, int(round(float(armor_hp) * hp_mult)))

func get_scaled_core_hp(hp_mult: float) -> int:
	return maxi(1, int(round(float(core_hp) * hp_mult)))

func get_scaled_boss_gold(wave: int) -> int:
	var mult: float = 1.0 + 0.04 * float(maxi(1, wave) - 1)
	return int(round(float(boss_gold) * mult))
