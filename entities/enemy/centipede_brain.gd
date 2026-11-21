class_name CentipedeBrain
extends RefCounted

## Utility scoring for the Skeletal Centipede: what to do next when fighting near the commander.
## Pure functions over a Situation snapshot, so the scoring is testable without a scene. The boss
## only acts on the pick at a decision point (never in the middle of a move).
## Distances in the Situation are metres; the data's distance bands are body units and are read
## through the data's body().

const SLASH: StringName = &"slash"
const COMBO: StringName = &"combo"
const SPIT: StringName = &"spit"
const ROLL: StringName = &"roll"
const CHARGE_ROLL: StringName = &"charge_roll"
const DASH_LEFT: StringName = &"dash_left"
const DASH_RIGHT: StringName = &"dash_right"
const DASH_FRONT: StringName = &"dash_front"
const CHASE: StringName = &"chase"
const FACE: StringName = &"face"
const PUSH: StringName = &"push"

## Fixed order, so a tie roll is the same for the same seed.
const ACTIONS: Array[StringName] = [SLASH, COMBO, SPIT, ROLL, CHARGE_ROLL, DASH_LEFT, DASH_RIGHT, DASH_FRONT, CHASE, FACE, PUSH]
## Moves that compete as one entry: the best of a group stands for it, then the group is split by score.
const MELEE_GROUP: Array[StringName] = [SLASH, COMBO]
const DASH_GROUP: Array[StringName] = [DASH_LEFT, DASH_RIGHT]


## What the boss knows about the fight at one decision point.
class Situation extends RefCounted:
	## A valid commander that the boss minds (close, or hit the boss recently).
	var engaged: bool = false
	var in_front: bool = false
	var in_slash: bool = false
	## Standing where the spit's pool would be.
	var in_spit_reach: bool = false
	## Flat distance to the nearest point of the commander, in metres.
	var distance: float = 0.0
	## How far the boss's facing is off the commander, in degrees (0 to 180).
	var off_angle_deg: float = 0.0
	## Sine of the commander's bearing from the boss's facing: positive when it is on the boss's left.
	var commander_lateral: float = 0.0
	## Seconds the commander has stayed where the boss cannot hit it.
	var t_away: float = 0.0
	var hp_fraction: float = 1.0
	## A structure or the Fortress to push on to (none inside the Hazard Trial room).
	var has_objective: bool = false
	var combo_unlocked: bool = false
	var combo_ready: bool = false
	var roll_unlocked: bool = false
	var roll_ready: bool = false
	var charge_roll_unlocked: bool = false
	var charge_roll_ready: bool = false
	var spit_unlocked: bool = false
	var spit_ready: bool = false
	var dash_unlocked: bool = false
	var dash_ready: bool = false
	## 0 to 1 per side: how much that side is worth (toward the Fortress) and whether it is free.
	var dash_left_share: float = 0.0
	var dash_right_share: float = 0.0
	var dash_front_ready: bool = false
	## 1 when the forward dash can be done (has its clips, nothing in the way), 0 otherwise.
	var dash_front_share: float = 0.0
	## 0 to 1: how much a chase is worth by where it leads (toward the Fortress is 1).
	var chase_fortress_share: float = 1.0
	## Turn clips the boss played within the turn-pressure window.
	var recent_turns: int = 0
	## The boss dashed a moment ago: Face, Spit and the rolls are weighted up.
	var dash_buff: bool = false
	## The boss pushed on recently and ignores the commander for now.
	var push_committed: bool = false
	## The boss is currently pushing on rather than fighting the commander.
	var pushing: bool = false


static func is_commander_action(action: StringName) -> bool:
	return action != PUSH and action != &""


static func _b(cond: bool) -> float:
	return UtilityBrain.gate(cond)


## Score of every action (0 = not possible right now).
static func score_all(s: Situation, d: CentipedeBossData) -> Dictionary:
	var fight := _b(s.engaged and not s.push_committed)
	var front := _b(s.in_front)
	var in_slash := _b(s.in_slash)
	var buff_face := d.dash_buff_face_mult if s.dash_buff else 1.0
	var buff_spit := d.dash_buff_spit_mult if s.dash_buff else 1.0
	var buff_charge := d.dash_buff_charge_roll_mult if s.dash_buff else 1.0
	var buff_roll := d.dash_buff_roll_mult if s.dash_buff else 1.0
	# After a dash the boss only turns back once it is clearly off the commander.
	var needs_face := s.off_angle_deg > d.dash_face_min_deg if s.dash_buff else not s.in_front
	# A side dash is worth most when the commander is off the boss's front, and it leaps away from it.
	var dash_base := d.weight_dash * fight * _b(s.dash_unlocked) * _b(s.dash_ready) \
			* _b(s.distance <= d.body(d.dash_trigger_reach)) \
			* (d.dash_side_front_mult if s.in_front else d.dash_side_off_front_mult)
	var dash_front_cooling := s.dash_unlocked and not s.dash_front_ready
	var turn_pressure := UtilityBrain.ramp(float(s.recent_turns), float(d.turn_roll_min_turns), float(d.turn_roll_full_turns))
	var scores := {
		SLASH: d.weight_slash * fight * front * in_slash,
		COMBO: d.weight_centipede_combo * fight * front * in_slash * _b(s.combo_unlocked)
				* _b(s.combo_ready) * (1.0 if s.hp_fraction < d.combo_hp_threshold else d.combo_high_hp_mult)
				* (d.combo_dash_front_cooldown_mult if dash_front_cooling else 1.0),
		SPIT: d.weight_spit * buff_spit * fight * front * _b(not s.in_slash) * _b(s.in_spit_reach)
				* _b(s.spit_unlocked) * _b(s.spit_ready),
		# The rolls ignore where the commander stands (inside slash reach, behind, near or far); turn
		# pressure only raises the roll's weight.
		ROLL: d.weight_roll * buff_roll * fight * _b(s.roll_unlocked) * _b(s.roll_ready)
				* lerpf(1.0, d.turn_roll_max_mult, turn_pressure),
		CHARGE_ROLL: d.weight_charge_roll * buff_charge * fight * _b(s.charge_roll_unlocked) * _b(s.charge_roll_ready),
		DASH_LEFT: dash_base * s.dash_left_share * _dash_away_share(s, 1.0, d),
		DASH_RIGHT: dash_base * s.dash_right_share * _dash_away_share(s, -1.0, d),
		DASH_FRONT: d.weight_dash_front * fight * front * _b(not s.in_slash) * _b(s.dash_unlocked)
				* _b(s.dash_front_ready) * s.dash_front_share
				* _b(s.distance >= d.body(d.dash_front_min_distance) and s.distance <= d.body(d.dash_front_max_distance)),
		CHASE: d.weight_chase * fight * front * _b(not s.in_slash) * s.chase_fortress_share,
		FACE: d.weight_face * buff_face * fight * _b(needs_face),
		PUSH: d.weight_push * _b(s.has_objective)
				* (d.push_base + (1.0 - d.push_base) * UtilityBrain.ramp(s.t_away, d.push_after, d.push_after + d.push_ramp)),
	}
	for action: StringName in ACTIONS:
		if (action == PUSH) == s.pushing:
			scores[action] *= d.stickiness
	return scores


## How much a side dash is worth by where the commander stands: 1 when it leaps away from the
## commander, dash_toward_share when it leaps toward it, in between when the commander is dead behind.
## side is +1 for the boss's left and -1 for its right.
static func _dash_away_share(s: Situation, side: float, d: CentipedeBossData) -> float:
	return lerpf(d.dash_toward_share, 1.0, UtilityBrain.ramp(-side * s.commander_lateral, -d.dash_away_band, d.dash_away_band))


## The best action. The melee moves and the two dashes each compete as one entry (their best
## score); actions within tie_margin of the best are rolled in proportion to their scores, and the
## winning group is then split by the scores of its members. roll is only called when a draw is
## needed, so a clear choice does not use up the random stream.
## Returns &"" when nothing scores (no commander to fight and nothing to push on to).
static func pick(scores: Dictionary, d: CentipedeBossData, roll: Callable) -> StringName:
	var top := scores.duplicate()
	_merge_group(top, MELEE_GROUP)
	_merge_group(top, DASH_GROUP)
	var choice := UtilityBrain.pick(ACTIONS, top, d.tie_margin, roll)
	if choice == MELEE_GROUP[0]:
		return UtilityBrain.weighted(MELEE_GROUP, scores, roll)
	if choice == DASH_GROUP[0]:
		return UtilityBrain.weighted(DASH_GROUP, scores, roll)
	return choice


## The group's first action takes the best score of the group and the others drop out.
static func _merge_group(top: Dictionary, group: Array[StringName]) -> void:
	var best := 0.0
	for action: StringName in group:
		best = maxf(best, float(top.get(action, 0.0)))
		top[action] = 0.0
	top[group[0]] = best


static func decide(s: Situation, d: CentipedeBossData, roll: Callable) -> StringName:
	return pick(score_all(s, d), d, roll)
