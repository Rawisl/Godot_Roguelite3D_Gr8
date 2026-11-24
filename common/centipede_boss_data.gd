class_name CentipedeBossData
extends BossData
# TODO(kiezroth): when the centipede gets a core model of its own, set fx_show_core back to true (script default and skeletal_centipede_boss.tres) so the armor break lights its core again.

## Skeletal Centipede: model scale, move numbers and AI weights on top of the shared boss fields.
## Every distance, speed and size marked "(body)" is the value at model_scale 1. The boss reads
## them through body() so a bigger or smaller model keeps the same proportions; times, damage and
## the speed caps (which are set by the size of the lane, not of the boss) are not scaled.
## The stomp and triple stomp fields of BossData are not used by this boss.

@export_group("Model")
## One number that sizes the model, its collision, its hitboxes and its clip-driven speeds.
@export_range(3.0, 4.5, 0.05) var model_scale: float = 3.0
## (body) Collision box of the torso.
@export var body_box_size: Vector3 = Vector3(1.1, 0.9, 1.8)
@export var body_box_center: Vector3 = Vector3(0.0, 0.45, 0.0)
## (body) Box that takes hits (the sword, towers, shots). It reaches further ahead than the torso, so
## a commander facing the boss lands its swings and the scythes are covered while they swing.
@export var hurt_box_size: Vector3 = Vector3(1.1, 0.9, 2.0)
@export var hurt_box_center: Vector3 = Vector3(0.0, 0.45, 0.1)
## (body) Centre of the roll's hit circle, in the boss's own space.
@export var roll_ring_center: Vector3 = Vector3(0.0, 0.0, 0.375)

@export_group("Engagement")
## (body) The boss minds a commander this close, and one that hit it recently within the leash.
## Wide enough that the ranged moves can score without the commander having to strike first.
@export var engage_range: float = 5.5
@export var engage_leash: float = 7.0

@export_group("Structures")
## Share of the slash reach (body) at which the boss starts hitting a structure: the walk-up stops
## closer than the slash can reach, so a swing never falls short.
@export var structure_reach_share: float = 0.8
## Seconds a tower or Barricade holds the boss back in a row while it chases the commander before
## it turns on that structure.
@export var blocked_retarget_time: float = 0.85
## A frame where the boss touches a structure and walks less than this share of its walk speed
## counts as held back.
@export_range(0.0, 1.0) var blocked_speed_share: float = 0.25
## Most seconds the boss keeps at a structure it turned on before it may go back to the commander
## (a structure that breaks, or a commander in reach, frees it sooner).
@export var blocked_lock_time: float = 8.0

@export_group("Locomotion")
## (body) Ground speed at which the walk clip plays at its own speed.
@export var walk_anim_base_speed: float = 0.16
@export var walk_anim_max_scale: float = 6.0
## (body) Distance from the body's axis the feet travel while it turns in place; sets how fast the
## walk clip plays for a given turning speed.
@export var turn_step_radius: float = 0.5
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
## Whether the armor break lights the electric core on this boss.
@export var fx_show_core: bool = false
## Share of the spit particles' authored speed, so the stream lands in the pool.
@export var fx_spit_speed_scale: float = 0.6

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
## Seconds before the heavy third swing can be picked again; meanwhile a commander dead ahead gets the side swing.
@export var la3_cooldown: float = 4.0

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
## Spans of the combo clip (start, end; clip seconds) in which the boss stops the clip to take a
## step instead: the clip holds at start, the walk plays for combo_step_time, then the clip goes on
## from end. None of them may overlap a hit window.
@export var combo_move_windows: PackedVector2Array = PackedVector2Array([
	Vector2(0.8167, 1.0167), Vector2(1.55, 1.95), Vector2(3.0167, 3.4167)])
## (body) Metres per clip second while stepping.
@export var combo_move_speed: float = 0.75
## Clip seconds each step lasts.
@export var combo_step_time: float = 0.8
## Degrees per clip second the boss turns toward its target while stepping.
@export var combo_step_turn_rate_deg: float = 120.0
## (body) A step stops once the gap to the target is down to this.
@export var combo_step_stop_gap: float = 1.0
## Degrees. A step that would end early (target near, or the way blocked) goes on turning in place
## until the face is within this of the target.
@export var combo_step_face_tolerance_deg: float = 10.0
## (body) A gap to the target wider than this cancels the combo, unless a hit window is open.
@export var combo_cancel_distance: float = 2.6
## Clip seconds of the pull-back to rest when the combo is cancelled.
@export var combo_cancel_time: float = 0.25
## Game seconds of rest after a cancelled combo, before the next move.
@export var combo_cancel_recovery: float = 0.05
@export var combo_cooldown: float = 8.0

@export_group("Spit")
## Clip second where the spit clip stops and holds while the stream runs.
@export var spit_freeze_time: float = 0.65
@export var spit_stream_start: float = 0.6
@export var spit_stream_duration: float = 3.0
@export var spit_stream_tick: float = 0.3
## The stream is a cone on the floor: its tip is under the mouth and it reaches the far edge of the pool.
@export var spit_stream_half_angle_deg: float = 20.0
@export var spit_stream_tick_damage: int = 3
@export var spit_cooldown: float = 30.0
## (body) Where the stream starts, ahead of the boss, when the effect is not there to say.
@export var spit_apex_fallback: float = 0.8
## (body) A target this close to the stream's tip is always inside the cone.
@export var spit_cone_tip_radius: float = 0.3
@export var spit_unlock_appearance: int = 1

@export_group("Poison Pool")
@export var pool_spawn_time: float = 1.05
## (body) Centre of the circular pool, in the boss's own space: where the stream lands.
@export var pool_center: Vector3 = Vector3(0.0, 0.012, 2.87)
## Metres, not scaled: the pool is the same size at every model scale. The AI spits when the
## commander stands inside it.
@export var pool_radius: float = 3.0
@export var pool_tick_damage: int = 4
@export var pool_tick_interval: float = 0.5
@export var pool_lifetime: float = 5.0
@export var pool_spread_time: float = 2.0
@export var pool_fade_time: float = 0.5

@export_group("Roll")
## (body) Ground speed at which the roll clip plays at its own speed (1x). The roll itself runs at
## the smaller of this and roll_speed_cap; the clip slows down by the difference.
@export var roll_speed: float = 6.58
## Metres per second, not scaled: the fastest the roll goes at any model scale.
@export var roll_speed_cap: float = 11.0
## (body)
@export var roll_hit_radius: float = 0.9
@export var roll_damage: int = 30
@export var roll_knockback: float = 4.0
## (body)
@export var roll_max_distance: float = 7.0
@export var roll_turn_rate_deg: float = 50.0
@export var roll_lean_max_deg: float = 15.0
## Seconds the roll takes to slow to a stop in its end clip.
@export var roll_end_slide_time: float = 0.45
## The roll ends when it covers less than this share of its expected distance for roll_blocked_time.
@export var roll_blocked_ratio: float = 0.4
@export var roll_blocked_time: float = 0.15
## Shared with the charge roll.
@export var roll_cooldown: float = 30.0
@export var roll_unlock_appearance: int = 2

@export_group("Charge Roll")
## A roll that homes in on the commander: slower than the plain roll, bends harder, runs for a time
## instead of a distance and stops shortly after it lands a hit. Needs no front-facing commander.
## Metres per second, not scaled.
@export var charge_roll_speed_cap: float = 9.0
## Seconds of game time the roll's loop runs.
@export var charge_roll_loop_time: float = 4.5
@export var charge_roll_turn_rate_deg: float = 70.0
@export var charge_roll_damage: int = 26
## Seconds the roll goes straight on after it hit the commander before it ends.
@export var charge_roll_after_hit_time: float = 0.5
@export var charge_roll_unlock_appearance: int = 3

@export_group("Dash")
## Share of the dash clip's own sideways travel (2.0 body) the boss covers; the leap is airborne, so a shorter one keeps the feet in place.
@export var dash_travel_scale: float = 0.6
## Seconds of rest after the dash ends.
@export var dash_recovery: float = 0.05
## Seconds of the leap clip kept after the root has stopped travelling: the feet touch down, then the dash ends.
@export var dash_land_time: float = 0.1
## Degrees per second (of the leap clip) the boss turns toward the commander while airborne; the leap's path stays the one set at take-off.
@export var dash_air_turn_rate_deg: float = 300.0
## (body) A commander this close (and fighting the boss) makes the dash worth taking.
@export var dash_trigger_reach: float = 2.6
## Shared by the left and the right dash.
@export var dash_cooldown: float = 20.0
@export var dash_unlock_appearance: int = 2
## Score share of the side that leads toward where the boss came from; the Fortress side is 1.
@export var dash_spawn_side_share: float = 0.2
## Side dot product (flat unit vectors) over which the share runs from the spawn side to the Fortress side.
@export var dash_side_dot_band: float = 0.5
## Seconds after a dash in which the moves below are weighted up.
@export var dash_buff_time: float = 3.0
@export var dash_buff_face_mult: float = 4.0
@export var dash_buff_spit_mult: float = 2.0
@export var dash_buff_charge_roll_mult: float = 1.6
@export var dash_buff_roll_mult: float = 1.15
## During the buff the boss turns back to the commander once it is off the facing by more than this.
@export var dash_face_min_deg: float = 15.0
## The forward dash has a cooldown of its own.
@export var dash_front_cooldown: float = 20.0
## Share of a side dash's score while the commander is in front of the boss, and while it is anywhere else.
@export var dash_side_front_mult: float = 0.5
@export var dash_side_off_front_mult: float = 3.0
## Share of the chase score when the chase leads straight away from the Fortress; toward it the share is 1.
@export var chase_off_fortress_share: float = 0.3
## Dot product (flat unit vectors, commander direction against Fortress direction) over which that share runs.
@export var chase_fortress_band: float = 0.5
## Share of a side dash's score when it leaps toward the commander; the side away from it counts fully.
@export var dash_toward_share: float = 0.5
## Sine of the commander's bearing over which that share runs (a commander dead behind scores the middle of the two).
@export var dash_away_band: float = 0.3
## (body) The forward dash is picked when the commander's gap is between these: after the leap the
## commander is out of the torso but still inside the slash.
@export var dash_front_min_distance: float = 2.1
@export var dash_front_max_distance: float = 2.9

@export_group("Turn Pressure")
## A boss that keeps turning to face the commander gets its roll weighted up: the turn clips of this
## many game seconds are counted.
@export var turn_roll_window: float = 10.0
## The roll's weight and distance gate start to rise above this count and are full at turn_roll_full_turns.
@export var turn_roll_min_turns: int = 1
@export var turn_roll_full_turns: int = 3
## Roll weight multiplier at full pressure.
@export var turn_roll_max_mult: float = 2.5

@export_group("Centipede AI")
@export var weight_slash: float = 1.2
@export var weight_centipede_combo: float = 1.0
## Share of the combo weight above the HP threshold.
@export var combo_high_hp_mult: float = 0.25
@export var weight_spit: float = 0.9
@export var weight_roll: float = 1.2
@export var weight_charge_roll: float = 1.0
@export var weight_dash: float = 0.6
@export var weight_dash_front: float = 1.5
## Share of the combo weight (on top of the HP rule) while the forward dash cools down.
@export var combo_dash_front_cooldown_mult: float = 1.2


func body(value: float) -> float:
	return value * model_scale


func body_v3(value: Vector3) -> Vector3:
	return value * model_scale
