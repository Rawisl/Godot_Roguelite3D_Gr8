class_name UtilityBrain
extends RefCounted

## Scoring helpers shared by the bosses' brains (BulwarkBrain, CentipedeBrain). Each brain keeps its
## own actions, Situation and weights; this holds only the parts that do not depend on them.


## 0 at or below from, 1 at or above to, linear in between.
static func ramp(x: float, from: float, to: float) -> float:
	if to <= from:
		return 1.0 if x >= from else 0.0
	return clampf((x - from) / (to - from), 0.0, 1.0)


## 1 when cond holds, otherwise 0: lets a condition multiply into a score.
static func gate(cond: bool) -> float:
	return 1.0 if cond else 0.0


## The best of actions (listed in a fixed order, so a tie roll is the same for the same seed).
## Actions within tie_margin of the best are rolled in proportion to their scores; roll is only
## called then, so a clear choice does not use up the random stream.
## Returns &"" when nothing scores.
static func pick(actions: Array[StringName], scores: Dictionary, tie_margin: float, roll: Callable) -> StringName:
	var best_score := 0.0
	for action: StringName in actions:
		best_score = maxf(best_score, float(scores.get(action, 0.0)))
	if best_score <= 0.0:
		return &""
	var floor_score := best_score * (1.0 - tie_margin)
	var close: Array[StringName] = []
	var total := 0.0
	for action: StringName in actions:
		var score := float(scores.get(action, 0.0))
		if score > 0.0 and score >= floor_score:
			close.append(action)
			total += score
	if close.size() == 1:
		return close[0]
	return _draw(close, scores, total, roll)


## One of the actions that score, drawn in proportion to their scores (no margin). Roll is only
## called when two or more score. Returns &"" when none does.
static func weighted(actions: Array[StringName], scores: Dictionary, roll: Callable) -> StringName:
	var scoring: Array[StringName] = []
	var total := 0.0
	for action: StringName in actions:
		var score := float(scores.get(action, 0.0))
		if score > 0.0:
			scoring.append(action)
			total += score
	if scoring.is_empty():
		return &""
	if scoring.size() == 1:
		return scoring[0]
	return _draw(scoring, scores, total, roll)


static func _draw(candidates: Array[StringName], scores: Dictionary, total: float, roll: Callable) -> StringName:
	var r: float = float(roll.call()) * total
	for action in candidates:
		r -= float(scores[action])
		if r < 0.0:
			return action
	return candidates[candidates.size() - 1]
