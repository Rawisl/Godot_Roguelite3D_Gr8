class_name WeaponDrop
extends RefCounted
## Picks the weapon a boss drops: one the run does not own yet, drawn evenly from the pool.
## Pure: reads its arguments, changes nothing.

static func make_rng(run_seed: int, wave_index: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, "weapon", wave_index])
	return rng

## &"" when every weapon of the pool is already owned. The pool order does not matter:
## candidates are sorted by id before the draw, so the same seed gives the same weapon.
static func pick(run_seed: int, wave_index: int, owned: Array[StringName], pool: Array[StringName]) -> StringName:
	var candidates: Array[StringName] = []
	for id in pool:
		if id == &"" or owned.has(id) or candidates.has(id):
			continue
		candidates.append(id)
	if candidates.is_empty():
		return &""
	candidates.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var rng := make_rng(run_seed, wave_index)
	return candidates[rng.randi_range(0, candidates.size() - 1)]
