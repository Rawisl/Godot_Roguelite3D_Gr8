class_name RunConfig
extends RefCounted

## Immutable configuration container initialized during run setup.
# TODO(Ender-Via): when RunLoading builds the run config, pass MetaUpgrades.get_run_modifiers(SaveManager.get_section(&"meta")["levels"]) as p_meta to create_default so the four permanent upgrades apply once per run.

var start_wave: int = 1
var starting_gold: int = 0
var start_mult: float = 1.0
var run_seed: int = 0
var fortress_max_hp: int = 1000
var commander_max_hp: float = 100.0
var emg_repair_heal_pct: float = 0.20
var gold_pct_meta: float = 0.0
var rerolls_per_run: int = 1


static func create_default(p_seed: int = 0, p_meta: Dictionary = {}) -> RunConfig:
	var cfg := RunConfig.new()
	cfg.run_seed = p_seed
	cfg.start_wave = int(p_meta.get("start_wave", 1))
	cfg.starting_gold = int(p_meta.get("starting_gold", GameConfig.starting_gold if "starting_gold" in GameConfig else 0))
	cfg.start_mult = float(p_meta.get("start_mult", 1.0))
	cfg.fortress_max_hp = int(p_meta.get("fortress_max_hp", 1000))
	cfg.commander_max_hp = float(p_meta.get("commander_max_hp", 100.0))
	cfg.emg_repair_heal_pct = float(p_meta.get("emg_repair_heal_pct", 0.20))
	cfg.gold_pct_meta = float(p_meta.get("gold_pct_meta", 0.0))
	cfg.rerolls_per_run = int(p_meta.get("rerolls_per_run", 1))
	return cfg
