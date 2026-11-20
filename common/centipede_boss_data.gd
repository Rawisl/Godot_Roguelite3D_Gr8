class_name CentipedeBossData
extends BossData

## Skeletal Centipede: model scale, move numbers and AI weights on top of the shared boss fields.
## Every distance, speed and size marked "(body)" is the value at model_scale 1. The boss reads
## them through body() so a bigger or smaller model keeps the same proportions; times, damage and
## the lane-bound distances (aggro, leash, roll distances) are not scaled.
## The stomp and triple stomp fields of BossData are not used by this boss.

@export_group("Model")
## One number that sizes the model, its collision, its hitboxes and its clip-driven speeds.
@export_range(0.5, 3.0, 0.05) var model_scale: float = 1.6
## (body) Collision and hurt box of the torso.
@export var body_box_size: Vector3 = Vector3(1.1, 0.9, 1.8)
@export var body_box_center: Vector3 = Vector3(0.0, 0.45, 0.0)
## (body) Centre of the roll's hit circle, in the boss's own space.
@export var roll_ring_center: Vector3 = Vector3(0.0, 0.0, 0.375)

@export_group("Locomotion")
## (body) Ground speed at which the walk clip plays at its own speed.
@export var walk_anim_base_speed: float = 0.16
@export var walk_anim_max_scale: float = 6.0
## Between moves, a commander further off the facing than this gets a turn clip, not a slow turn.
@export var turn_clip_min_deg: float = 45.0
## Facing a structure this closely, the boss swings even if it is not dead on.
@export var structure_face_tolerance_deg: float = 10.0
## A turn up to this angle plays a quarter-turn clip; wider ones play the half-turn clip.
@export var turn_half_clip_deg: float = 135.0
## (body) Extra reach added to the walk-up range for the stall check.
@export var melee_reach_margin: float = 0.6

@export_group("Death")
@export var death_duration: float = 2.0
## (body) How far the model sinks into the floor while it dies.
@export var death_sink_depth: float = 0.9
@export var death_tilt_deg: float = 12.0

@export_group("Effect Anchors")
## Where the boss's electric core and its vents sit, read by BossFxManager.
@export var fx_core_bone: StringName = &"Torso_Upper"
@export var fx_core_offset: Vector3 = Vector3(0.0, 0.1, 0.3)
@export var fx_vent_bones: Array[StringName] = [&"Shoulder.L", &"Shoulder.R"]
@export var fx_vent_offset: Vector3 = Vector3(0.0, 0.15, -0.1)
## (body) Used when a bone is missing.
@export var fx_core_fallback: Vector3 = Vector3(0.0, 0.6, 0.7)
@export var fx_vent_fallback: Vector3 = Vector3(0.0, 1.0, 0.3)

@export_group("Slash")
## (body) Sector in front of the boss. A commander on the right half gets the first swing, on the
## left half the second, and dead ahead (slash_center_deg) the heavy third swing.
@export var slash_range: float = 1.7
@export var slash_arc_deg: float = 120.0
@export var slash_center_deg: float = 12.0
## Clip seconds in which the swing can hit (start, end).
@export var slash_hit_window: Vector2 = Vector2(0.6, 0.8167)
@export var la_damage: int = 14
@export var la3_damage: int = 22
@export var la3_knockback: float = 1.0
@export var la3_arc_deg: float = 150.0

@export_group("Combo")
## (body)
@export var combo_range: float = 1.7
@export var combo_arc_deg: float = 120.0
## Arc of the last hit, the heavy swing with both scythes.
@export var combo_finisher_arc_deg: float = 150.0
@export var combo_hit_damage: int = 4
@export var combo_finisher_damage: int = 12
@export var combo_finisher_knockback: float = 1.0
## Clip seconds of every hit (start, end); they follow the slash trails of the combo clip. The last
## one is the finisher.
@export var combo_hit_windows: PackedVector2Array = PackedVector2Array([
	Vector2(0.25, 0.4), Vector2(0.65, 0.8), Vector2(1.1667, 1.2667), Vector2(1.4333, 1.5333),
	Vector2(2.1112, 2.2), Vector2(2.3778, 2.4667), Vector2(2.6548, 2.749), Vector2(2.9058, 3.0),
	Vector2(3.5667, 3.6667), Vector2(3.8333, 3.9333), Vector2(4.4833, 4.6667)])
## Clip seconds in which the boss steps forward (start, end), at combo_move_speed.
@export var combo_move_windows: PackedVector2Array = PackedVector2Array([
	Vector2(0.8167, 1.0167), Vector2(1.55, 1.95), Vector2(3.0167, 3.4167)])
## (body) Metres per clip second.
@export var combo_move_speed: float = 0.6
@export var combo_cooldown: float = 8.0

@export_group("Spit")
## Clip second where the spit clip stops and holds while the stream runs.
@export var spit_freeze_time: float = 0.65
@export var spit_stream_start: float = 0.6
@export var spit_stream_duration: float = 3.0
@export var spit_stream_tick: float = 0.3
## (body) The stream is a cone on the floor: its tip is under the mouth.
@export var spit_stream_reach: float = 3.9
@export var spit_stream_half_angle_deg: float = 20.0
@export var spit_stream_tick_damage: int = 3
## (body) Distance from the boss in which the AI picks the spit.
@export var spit_min_reach: float = 1.8
@export var spit_max_reach: float = 4.8
## (body) Radius of the warning ring.
@export var spit_telegraph_radius: float = 2.0
@export var spit_cooldown: float = 9.0
## (body) Where the stream starts, ahead of the boss, when the effect is not there to say.
@export var spit_apex_fallback: float = 0.8
## (body) A target this close to the stream's tip is always inside the cone.
@export var spit_cone_tip_radius: float = 0.3
## Share of the pool's length, past its offset, where the warning ring is centred.
@export var spit_telegraph_along: float = 0.6
@export var spit_unlock_appearance: int = 1

@export_group("Poison Pool")
@export var pool_spawn_time: float = 1.05
## (body) Where the pool starts, in the boss's own space.
@export var pool_offset: Vector3 = Vector3(0.0, 0.012, 0.8237)
@export var pool_length: float = 4.3
@export var pool_cut_fraction: float = 0.25
@export var pool_half_angle_deg: float = 32.0
@export var pool_tick_damage: int = 4
@export var pool_tick_interval: float = 0.5
@export var pool_lifetime: float = 5.0
@export var pool_spread_time: float = 2.0
@export var pool_fade_time: float = 0.5

@export_group("Roll")
## (body) Metres per second once the roll is up to speed; matches the roll clip.
@export var roll_speed: float = 6.58
## (body)
@export var roll_hit_radius: float = 0.9
@export var roll_damage: int = 30
@export var roll_knockback: float = 4.0
## Lane distances, not scaled: the roll starts only when the commander is further than the minimum.
@export var roll_max_distance: float = 16.0
@export var roll_min_distance: float = 7.0
@export var roll_full_distance: float = 10.0
@export var roll_turn_rate_deg: float = 50.0
@export var roll_lean_max_deg: float = 15.0
## Seconds the roll takes to slow to a stop in its end clip.
@export var roll_end_slide_time: float = 0.45
## The roll ends when it covers less than this share of its expected distance for roll_blocked_time.
@export var roll_blocked_ratio: float = 0.4
@export var roll_blocked_time: float = 0.15
@export var roll_cooldown: float = 10.0
@export var roll_unlock_appearance: int = 2

@export_group("Centipede AI")
@export var weight_slash: float = 1.0
@export var weight_centipede_combo: float = 1.0
@export var weight_spit: float = 0.9
@export var weight_roll: float = 1.2


func body(value: float) -> float:
	return value * model_scale


func body_v3(value: Vector3) -> Vector3:
	return value * model_scale
