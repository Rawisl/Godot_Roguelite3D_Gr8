class_name RunLoader
extends RefCounted
## Builds the RunConfig of a new run while the loading screen is up, and hands it to the
## RunState of the run scene, which is created only after the loading screen is gone.
## Static only: the hand-over survives the scene change.

static var _pending: RunConfig = null


## A run seed for a new run. Never 0, so a run built here is told apart from a default config.
static func new_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return maxi(1, rng.randi() & 0x7fffffff)


## The meta shop levels in the save, or an empty table when the save has none.
static func saved_meta_levels() -> Dictionary:
	var levels: Variant = SaveManager.get_section(&"meta").get("levels", {})
	return levels if levels is Dictionary else {}


## RunConfig of a new run from the meta shop levels. The meta upgrades are added once here and
## the config never changes afterwards. A seed of 0 draws a new one.
static func build_config(meta_levels: Dictionary, run_seed: int = 0) -> RunConfig:
	var seed_value := run_seed if run_seed != 0 else new_seed()
	return RunConfig.create_default(seed_value, MetaUpgrades.get_run_modifiers(meta_levels))


## Keeps the config for the RunState of the next run scene. A second call replaces the first.
static func hand_over(config: RunConfig) -> void:
	_pending = config


static func has_pending() -> bool:
	return _pending != null


## The config handed over by the loading screen, once. When the run scene was opened without the
## loading screen (F5 in the editor), a config is built from the save the same way.
static func take() -> RunConfig:
	var config := _pending
	_pending = null
	if config == null:
		config = build_config(saved_meta_levels())
	return config
