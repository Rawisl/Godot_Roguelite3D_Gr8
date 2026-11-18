class_name BulwarkBrain
extends RefCounted
# TODO(Ender-Via): after the boss-wave playtest, replace the on/off front and reach checks with curves (angle off the facing for the turn, distance to the stomp ring for the stomp) so close situations score differently.

## Utility scoring for the Bulwark: what to do next when fighting near the commander.
## Pure functions over a Situation snapshot, so the scoring is testable without a scene.
## The boss only acts on the pick at a decision point (never in the middle of a move).

const NORMAL: StringName = &"normal"
const COMBO: StringName = &"combo"
const STOMP: StringName = &"stomp"
const TRIPLE: StringName = &"triple"
const CHASE: StringName = &"chase"
const FACE: StringName = &"face"
const PUSH: StringName = &"push"

## Fixed order, so a tie roll is the same for the same seed.
const ACTIONS: Array[StringName] = [NORMAL, COMBO, STOMP, TRIPLE, CHASE, FACE, PUSH]


## What the boss knows about the fight at one decision point.
class Situation extends RefCounted:
	## A valid commander that the boss minds (close, or hit the boss recently).
	var engaged: bool = false
	var in_front: bool = false
	var in_slash: bool = false
	## Inside the ring a stomp started right now would land on.
	var in_ring: bool = false
	## Inside the last, widest ring of the triple stomp.
	var in_triple_reach: bool = false
	## Seconds the commander has stayed where the boss cannot hit it.
	var t_away: float = 0.0
	var hp_fraction: float = 1.0
	## A structure or the Fortress to push on to (none inside the Hazard Trial room).
	var has_objective: bool = false
	var combo_unlocked: bool = false
	var triple_unlocked: bool = false
	var triple_ready: bool = false
	var commander_stomp_ready: bool = false
	## The boss pushed on recently and ignores the commander for now.
	var push_committed: bool = false
	## The boss is currently pushing on rather than fighting the commander.
	var pushing: bool = false


static func is_commander_action(action: StringName) -> bool:
	return action != PUSH and action != &""


## 0 at or below from, 1 at or above to, linear in between.
static func ramp(x: float, from: float, to: float) -> float:
	if to <= from:
		return 1.0 if x >= from else 0.0
	return clampf((x - from) / (to - from), 0.0, 1.0)


static func _b(cond: bool) -> float:
	return 1.0 if cond else 0.0


## Score of every action (0 = not possible right now).
static func score_all(s: Situation, d: BossData) -> Dictionary:
	var fight := _b(s.engaged and not s.push_committed)
	var front := _b(s.in_front)
	var scores := {
		NORMAL: d.weight_normal * fight * front * _b(s.in_slash),
		COMBO: d.weight_combo * fight * front * _b(s.in_slash) * _b(s.combo_unlocked)
				* _b(s.hp_fraction < d.combo_hp_threshold),
		STOMP: d.weight_commander_stomp * fight * front * _b(not s.in_slash) * _b(s.in_ring)
				* _b(s.commander_stomp_ready),
		TRIPLE: d.weight_triple_stomp * fight * _b(not s.in_front) * _b(s.in_triple_reach)
				* _b(s.triple_unlocked) * _b(s.triple_ready),
		CHASE: d.weight_chase * fight * front * _b(not s.in_slash),
		FACE: d.weight_face * fight * _b(not s.in_front),
		PUSH: d.weight_push * _b(s.has_objective)
				* (d.push_base + (1.0 - d.push_base) * ramp(s.t_away, d.push_after, d.push_after + d.push_ramp)),
	}
	for action: StringName in ACTIONS:
		if (action == PUSH) == s.pushing:
			scores[action] *= d.stickiness
	return scores


## The best action. Actions within tie_margin of the best are rolled in proportion to their
## scores; roll is only called then, so a clear choice does not use up the random stream.
## Returns &"" when nothing scores (no commander to fight and nothing to push on to).
static func pick(scores: Dictionary, d: BossData, roll: Callable) -> StringName:
	var best_score := 0.0
	for action: StringName in ACTIONS:
		best_score = maxf(best_score, float(scores.get(action, 0.0)))
	if best_score <= 0.0:
		return &""
	var floor_score := best_score * (1.0 - d.tie_margin)
	var close: Array[StringName] = []
	var total := 0.0
	for action: StringName in ACTIONS:
		var score := float(scores.get(action, 0.0))
		if score > 0.0 and score >= floor_score:
			close.append(action)
			total += score
	if close.size() == 1:
		return close[0]
	var r: float = float(roll.call()) * total
	for action in close:
		r -= float(scores[action])
		if r < 0.0:
			return action
	return close[close.size() - 1]


static func decide(s: Situation, d: BossData, roll: Callable) -> StringName:
	return pick(score_all(s, d), d, roll)
