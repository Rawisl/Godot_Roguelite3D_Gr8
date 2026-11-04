class_name RewardOfferGenerator
extends RefCounted
## Builds one REWARD_PICK offer: up to count different cards drawn by weight without replacement.
## Pure: reads the state and catalog, changes nothing.

static func make_rng(run_seed: int, picks_used: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, "reward", picks_used])
	return rng

## 0 when the card cannot be offered now.
static func get_weight(state: RunSkillState, data: SkillData) -> int:
	if data == null:
		return 0
	if data.requires_flag != &"" and not state.has_flag(data.requires_flag):
		return 0
	if not state.can_take(data):
		return 0
	if not data.is_slotted():
		return GameConfig.reward_weight_stat
	if state.get_level(data.id) > 0:
		return GameConfig.reward_weight_owned
	return GameConfig.reward_weight_new

static func has_offer(state: RunSkillState, catalog: Array[SkillData]) -> bool:
	for data in catalog:
		if get_weight(state, data) > 0:
			return true
	return false

static func generate(state: RunSkillState, catalog: Array[SkillData], rng: RandomNumberGenerator, count: int) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	if count <= 0:
		return cards
	var candidates: Array[SkillData] = []
	var seen: Dictionary[StringName, bool] = {}
	for data in catalog:
		if data == null or seen.has(data.id):
			continue
		seen[data.id] = true
		if get_weight(state, data) > 0:
			candidates.append(data)
	while cards.size() < count and not candidates.is_empty():
		var total := 0.0
		for data in candidates:
			total += get_weight(state, data)
		var r := rng.randf() * total
		var chosen := candidates.size() - 1
		var running := 0.0
		for i in candidates.size():
			running += get_weight(state, candidates[i])
			if running > r:
				chosen = i
				break
		cards.append(make_card(state, candidates[chosen]))
		candidates.remove_at(chosen)
	return cards

## Card shared by the UI and reward_picked: next_level is the new_level that reward_picked carries.
static func make_card(state: RunSkillState, data: SkillData) -> Dictionary:
	var level := state.get_level(data.id)
	return {
		"id": data.id,
		"kind": StringName(SkillData.Kind.keys()[data.kind]),
		"level": level,
		"next_level": level + 1,
		"is_new": level == 0,
		"data": data,
	}
