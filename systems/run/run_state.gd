class_name RunState
extends Node

## In-memory runtime state container for the active run session.
## Tracks progress, economy, weapons, health, upgrades, and run statistics.
## Does not write any state to persistent disk storage during the run.

## The base sword: owned and equipped at the start of every run.
const BASE_WEAPON := &"sword_base"
## The run scene. Only a RunState inside it starts a run by itself.
const RUN_SCENE := "res://main.tscn"
## StatBlock source of the meta shop upgrade on the commander's max HP.
const META_SOURCE := &"meta"

# --- Progress ---
var wave_index: int = 1
var waves_cleared: int = 0
var run_elapsed: float = 0.0
var run_seed: int = 0
var start_wave: int = 1
var start_mult: float = 1.0
var victory_reached: bool = false

# --- Economy ---
var gold: int = 0
var mithril: int = 0
var prestige_pending: int = 0
var wave_gold_base: float = 0.0
var wave_prestige_buffer: int = 0
## Gold bonus from the meta shop, added to wave gold and boss gold.
var gold_pct_meta: float = 0.0

# --- Hazard Trial ---
var hazard_used: bool = false
var hazard_session: Dictionary = {}

# --- Weapons ---
var owned_weapons: Array[StringName] = [BASE_WEAPON]
var equipped_weapon: StringName = BASE_WEAPON
var chain_cd: float = 0.0

# --- Fortress & Emergency Repair ---
var fortress_hp: int = 1000
var fortress_max_hp: int = 1000
var emg_repair_charges: int = 3
var emg_repair_cd: float = 0.0
var emg_repair_heal_pct: float = 0.20

# --- Commander ---
var commander_hp: float = 100.0
var commander_max_hp: float = 100.0
var commander_mode: StringName = &"FRONTLINE"
var heal_phase: StringName = &"IDLE"
var heal_hold: float = 0.0

# --- Skill & XP ---
var xp: float = 0.0
var commander_level: int = 0
var pending_picks: int = 0
var active_slots: Array = []
var passive_slots: Array = []
var stat_stacks: Dictionary = {}
var rerolls_left: int = 1
var heal_station_built: bool = false

# --- Towers & Slots ---
var is_starter: Dictionary = {}
var ruined_type: Dictionary = {}
var ruined_level: Dictionary = {}
var tower_slots: Dictionary = {}

# --- Run Statistics ---
var run_kills: int = 0
var run_commander_kills: int = 0
var run_gold_earned: int = 0
var run_bosses_defeated: int = 0
var damage_by_tower_type: Dictionary = {}

# --- Wave & Boss ---
var enemies_alive: int = 0
var boss_timer: float = 0.0
var boss_phase: StringName = &""
var boss_enraged: bool = false

# --- Internal Runtime Control ---
var _current_state: StringName = &""
var _pending_fortress_destroyed: bool = false
var _pending_commander_died: bool = false
var _run_is_ended: bool = false
var _run_started: bool = false
var _configured: bool = false
## The config the run started from. Its values are the ones put on the scene at the start: the
## effective fields above follow the Fortress and the commander once they report their HP.
var _config: RunConfig = null


## Reads the run config before any other node of the run scene is ready, so the wave manager,
## the gold and the commander start from the values of this run.
func _enter_tree() -> void:
	if not _configured and _is_in_run_scene():
		init_from_config(RunLoader.take())


func _ready() -> void:
	add_to_group(&"run_state")
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.fortress_destroyed.connect(_on_fortress_destroyed)
	EventBus.commander_died.connect(_on_commander_died)
	EventBus.fortress_hp_changed.connect(_on_fortress_hp_changed)
	EventBus.commander_hp_changed.connect(_on_commander_hp_changed)
	EventBus.emergency_repair_state_changed.connect(_on_emergency_repair_state_changed)
	EventBus.mode_changed.connect(_on_commander_mode_changed)
	EventBus.run_started.connect(_on_run_started)
	_start_main_scene_run.call_deferred()


func _start_main_scene_run() -> void:
	if not _is_in_run_scene():
		return
	if not _configured:
		init_from_config(RunLoader.take())
	apply_to_scene()
	place_starter_towers()
	start_run()


func _is_in_run_scene() -> bool:
	if not is_inside_tree():
		return false
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == RUN_SCENE and scene.is_ancestor_of(self)


## RunLoading may call this after initialization; direct main launches use the same path.
func start_run() -> void:
	if _run_started:
		return
	_run_started = true
	SaveManager.record_run_start(start_wave, start_mult)
	EventBus.run_started.emit()


func _exit_tree() -> void:
	if EventBus.state_changed.is_connected(_on_state_changed):
		EventBus.state_changed.disconnect(_on_state_changed)
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)
	if EventBus.boss_defeated.is_connected(_on_boss_defeated):
		EventBus.boss_defeated.disconnect(_on_boss_defeated)
	if EventBus.fortress_destroyed.is_connected(_on_fortress_destroyed):
		EventBus.fortress_destroyed.disconnect(_on_fortress_destroyed)
	if EventBus.commander_died.is_connected(_on_commander_died):
		EventBus.commander_died.disconnect(_on_commander_died)
	if EventBus.fortress_hp_changed.is_connected(_on_fortress_hp_changed):
		EventBus.fortress_hp_changed.disconnect(_on_fortress_hp_changed)
	if EventBus.commander_hp_changed.is_connected(_on_commander_hp_changed):
		EventBus.commander_hp_changed.disconnect(_on_commander_hp_changed)
	if EventBus.emergency_repair_state_changed.is_connected(_on_emergency_repair_state_changed):
		EventBus.emergency_repair_state_changed.disconnect(_on_emergency_repair_state_changed)
	if EventBus.mode_changed.is_connected(_on_commander_mode_changed):
		EventBus.mode_changed.disconnect(_on_commander_mode_changed)
	if EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.disconnect(_on_run_started)


func _process(delta: float) -> void:
	if _current_state == &"COMBAT" or _current_state == &"BOSS_COMBAT":
		run_elapsed += delta


func init_from_config(config: RunConfig) -> void:
	if config == null:
		return
	_config = config
	wave_index = config.start_wave
	start_wave = config.start_wave
	start_mult = config.start_mult
	waves_cleared = maxi(0, config.start_wave - 1)
	gold = config.starting_gold
	run_seed = config.run_seed
	fortress_hp = config.fortress_max_hp
	fortress_max_hp = config.fortress_max_hp
	commander_hp = config.commander_max_hp
	commander_max_hp = config.commander_max_hp
	emg_repair_heal_pct = config.emg_repair_heal_pct
	gold_pct_meta = config.gold_pct_meta
	emg_repair_charges = GameConfig.emg_repair_charges_start
	emg_repair_cd = 0.0
	xp = 0.0
	commander_level = 0
	pending_picks = 0
	active_slots = []
	passive_slots = []
	stat_stacks = {}
	rerolls_left = config.rerolls_per_run
	heal_station_built = false
	mithril = 0
	owned_weapons = [BASE_WEAPON]
	equipped_weapon = BASE_WEAPON
	chain_cd = 0.0
	hazard_used = false
	hazard_session = {}
	victory_reached = false
	_configured = true


## Puts the run config on the Fortress, the commander and Emergency repair,
## full HP on both. Called once before the run starts; nodes that are missing are skipped.
func apply_to_scene() -> void:
	var fortress_max := _config.fortress_max_hp if _config != null else fortress_max_hp
	var commander_max := _config.commander_max_hp if _config != null else commander_max_hp
	var heal_pct := _config.emg_repair_heal_pct if _config != null else emg_repair_heal_pct
	var fortress := get_tree().get_first_node_in_group(&"fortress")
	var fortress_health := fortress.get(&"health") as HealthComponent if fortress != null else null
	if fortress_health != null:
		# hp first: set_max_hp is what tells the HUD.
		fortress_health.hp = fortress_max
		fortress_health.set_max_hp(fortress_max)
	var commander := get_tree().get_first_node_in_group(&"commander")
	if commander == null:
		return
	var block := commander.get(&"stat_block") as StatBlock
	var health := commander.get(&"health") as HealthComponent
	if block != null and health != null:
		block.set_add(&"commander_max_hp", META_SOURCE, commander_max - block.get_base(&"commander_max_hp"))
		health.hp = block.get_max_hp()
		health.set_max_hp(block.get_max_hp())
		# The commander sends its starting HP deferred, and when it is spawned after this node that
		# stale value arrives after the one above; send the real one again after it.
		EventBus.commander_hp_changed.emit.call_deferred(health.hp, health.max_hp)
	var repair := commander.get_node_or_null(^"EmergencyRepair")
	if repair != null and &"heal_bonus_pct" in repair:
		repair.set(&"heal_bonus_pct", maxf(0.0, heal_pct - GameConfig.emg_repair_base_heal_pct))


## The two starter towers of a run from wave 1 once the tutorial is done. Without the tutorial
## done the tutorial has the player build them instead, and a later start wave has none.
func place_starter_towers() -> bool:
	if start_wave != 1 or not bool(SaveManager.get_section(&"flags").get("tutorial_done", false)):
		return false
	# TODO(kiezroth): add BuildService.place_starter_towers() that builds a level 1 Arrow on starter_arrow_slot and a level 1 Cannon on starter_cannon_slot (full HP, default priority, no invested gold, is_starter); RunState calls it here before the first PREP.
	var build_service := get_tree().get_first_node_in_group(&"build_service")
	if build_service == null or not build_service.has_method(&"place_starter_towers"):
		return false
	build_service.call(&"place_starter_towers")
	return true


## Adds a weapon to the run and sends weapon_gained. False (and no signal) when the id is empty or the weapon is already owned.
func grant_weapon(id: StringName) -> bool:
	if id == &"" or owned_weapons.has(id):
		return false
	owned_weapons.append(id)
	EventBus.weapon_gained.emit(id)
	return true


## Equips an owned weapon. Only in PREP (anything else, HAZARD_TRIAL included, is refused) and
## never after the run has ended. False when the weapon is not owned or the state is wrong;
## weapon_equipped is sent only on success.
func equip_weapon(id: StringName) -> bool:
	if _run_is_ended or not owned_weapons.has(id) or get_current_state() != &"PREP":
		return false
	equipped_weapon = id
	EventBus.weapon_equipped.emit(id)
	return true


## The last wave state received. PREP until the first state_changed arrives.
func get_current_state() -> StringName:
	return _current_state if _current_state != &"" else &"PREP"


## Adds Mithril and tells the HUD and the Fortress panel. Zero or negative amounts are ignored.
func add_mithril(amount: int) -> void:
	if amount <= 0:
		return
	mithril += amount
	EventBus.mithril_changed.emit(mithril, amount)


## Takes Mithril in one step. Returns false and changes nothing when the amount is not positive or exceeds the stock.
func spend_mithril(amount: int) -> bool:
	if amount <= 0:
		return false
	if mithril < amount:
		return false
	mithril -= amount
	EventBus.mithril_changed.emit(mithril, -amount)
	return true


func end_run(end_type: StringName = &"DEFEAT") -> void:
	if _run_is_ended:
		return
	_run_is_ended = true
	var summary := build_summary(end_type, get_run_result())
	EventBus.run_ended.emit(end_type, summary)


## How the run went, apart from how it ended: SURVIVED once the victory wave was cleared,
## whatever the end type (abandoning included), DEFEAT before that.
func get_run_result() -> StringName:
	return &"SURVIVED" if victory_reached else &"DEFEAT"


func is_run_ended() -> bool:
	return _run_is_ended


## True when this run cleared more waves than the saved best for its start wave. Read before the
## save adds this run, which happens when run_ended is sent.
func is_new_record() -> bool:
	var best: Variant = SaveManager.get_section(&"profile").get("best_by_start", {})
	var saved_best := int((best as Dictionary).get(str(start_wave), 0)) if best is Dictionary else 0
	return waves_cleared > saved_best


func build_summary(end_type: StringName, run_result: StringName) -> Dictionary:
	return {
		"end_type": end_type,
		"run_result": run_result,
		"wave_index": wave_index,
		"waves_cleared": waves_cleared,
		"run_elapsed": run_elapsed,
		"run_seed": run_seed,
		"victory_reached": victory_reached,
		"gold": gold,
		"mithril": mithril,
		"prestige_pending": prestige_pending,
		"wave_prestige_buffer": wave_prestige_buffer,
		"prestige_gain": PrestigeCalc.prestige_gain(prestige_pending, wave_prestige_buffer, start_mult),
		"start_wave": start_wave,
		"start_mult": start_mult,
		"run_kills": run_kills,
		"run_commander_kills": run_commander_kills,
		"run_gold_earned": run_gold_earned,
		"run_bosses_defeated": run_bosses_defeated,
		"commander_level": commander_level,
		"equipped_weapon": equipped_weapon,
		"new_record": is_new_record(),
		# A run settled after the game was closed mid-run is never built here, so this is always
		# false; the leaderboard leaves such runs out.
		"recovered": false,
	}


func _resolve_run_termination() -> void:
	if _run_is_ended:
		return
	if not _pending_fortress_destroyed and not _pending_commander_died:
		return
	
	var end_type: StringName = &"FORTRESS_DESTROYED"
	if _pending_fortress_destroyed:
		end_type = &"FORTRESS_DESTROYED"
	elif _pending_commander_died:
		end_type = &"COMMANDER_DIED"
	
	end_run(end_type)


func _on_state_changed(new_state: StringName) -> void:
	_current_state = new_state


func _on_enemy_died(_enemy_type: StringName, _pos: Vector3, _gold_base: float, _prestige: int, is_cull: bool, hit_by_commander: bool) -> void:
	if is_cull:
		return
	run_kills += 1
	if hit_by_commander:
		run_commander_kills += 1


func _on_boss_defeated() -> void:
	run_bosses_defeated += 1


func _on_fortress_destroyed() -> void:
	_pending_fortress_destroyed = true
	_resolve_run_termination.call_deferred()


func _on_commander_died() -> void:
	_pending_commander_died = true
	_resolve_run_termination.call_deferred()


func _on_fortress_hp_changed(new_hp: int, max_hp: int, _delta: int) -> void:
	fortress_hp = new_hp
	fortress_max_hp = max_hp


func _on_commander_hp_changed(hp: int, max_hp: int) -> void:
	var commander := get_tree().get_first_node_in_group(&"commander")
	var health := commander.get(&"health") as HealthComponent if commander != null else null
	commander_hp = health.get_precise_hp() if health != null else float(hp)
	commander_max_hp = float(max_hp)


func _on_emergency_repair_state_changed(charges: int, cooldown: float, heal_pct: float) -> void:
	emg_repair_charges = charges
	emg_repair_cd = cooldown
	emg_repair_heal_pct = heal_pct


func _on_commander_mode_changed(mode: StringName) -> void:
	commander_mode = mode


## Mithril does not carry over between runs.
func _on_run_started() -> void:
	_run_started = true
	var previous := mithril
	mithril = 0
	if previous != 0:
		EventBus.mithril_changed.emit(0, -previous)
