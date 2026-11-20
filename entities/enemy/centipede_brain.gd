class_name CentipedeBrain
extends RefCounted

## Utility scoring for the Skeletal Centipede: what to do next when fighting near the commander.
## Pure functions over a Situation snapshot, so the scoring is testable without a scene. The boss
## only acts on the pick at a decision point (never in the middle of a move).

const SLASH: StringName = &"slash"
const COMBO: StringName = &"combo"
const SPIT: StringName = &"spit"
const ROLL: StringName = &"roll"
const CHASE: StringName = &"chase"
const FACE: StringName = &"face"
const PUSH: StringName = &"push"

## Fixed order, so a tie roll is the same for the same seed.
const ACTIONS: Array[StringName] = [SLASH, COMBO, SPIT, ROLL, CHASE, FACE, PUSH]


## What the boss knows about the fight at one decision point.
class Situation extends RefCounted:
	## A valid commander that the boss minds (close, or hit the boss recently).
	var engaged: bool = false
	var in_front: bool = false
	var in_slash: bool = false
	## Inside the spit's distance band and cone.
	var in_spit_reach: bool = false
	## Flat distance to the nearest point of the commander, in metres.
	var distance: float = 0.0
	## Seconds the commander has stayed where the boss cannot hit it.
	var t_away: float = 0.0
	var hp_fraction: float = 1.0
	## A structure or the Fortress to push on to (none inside the Hazard Trial room).
	var has_objective: bool = false
	var combo_unlocked: bool = false
	var combo_ready: bool = false
	var roll_unlocked: bool = false
	var roll_ready: bool = false
	var spit_unlocked: bool = false
	var spit_ready: bool = false
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
	var scores := {
		SLASH: d.weight_slash * fight * front * _b(s.in_slash),
		COMBO: d.weight_centipede_combo * fight * front * _b(s.in_slash) * _b(s.combo_unlocked)
				* _b(s.combo_ready) * _b(s.hp_fraction < d.combo_hp_threshold),
		SPIT: d.weight_spit * fight * front * _b(not s.in_slash) * _b(s.in_spit_reach)
				* _b(s.spit_unlocked) * _b(s.spit_ready),
		ROLL: d.weight_roll * fight * front * _b(not s.in_slash) * _b(s.roll_unlocked) * _b(s.roll_ready)
				* UtilityBrain.ramp(s.distance, d.roll_min_distance, d.roll_full_distance),
		CHASE: d.weight_chase * fight * front * _b(not s.in_slash),
		FACE: d.weight_face * fight * _b(not s.in_front),
		PUSH: d.weight_push * _b(s.has_objective)
				* (d.push_base + (1.0 - d.push_base) * UtilityBrain.ramp(s.t_away, d.push_after, d.push_after + d.push_ramp)),
	}
	for action: StringName in ACTIONS:
		if (action == PUSH) == s.pushing:
			scores[action] *= d.stickiness
	return scores


## The best action. Actions within tie_margin of the best are rolled in proportion to their
## scores; roll is only called then, so a clear choice does not use up the random stream.
## Returns &"" when nothing scores (no commander to fight and nothing to push on to).
static func pick(scores: Dictionary, d: CentipedeBossData, roll: Callable) -> StringName:
	return UtilityBrain.pick(ACTIONS, scores, d.tie_margin, roll)


static func decide(s: Situation, d: CentipedeBossData, roll: Callable) -> StringName:
	return pick(score_all(s, d), d, roll)
