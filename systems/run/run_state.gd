class_name RunState
extends Node

## In-memory runtime state container for the active run session.
## Tracks progress, economy, weapons, health, upgrades, and run statistics.
## Does not write any state to persistent disk storage during the run.

## The base sword: owned and equipped at the start of every run.
const BASE_WEAPON := &"sword_base"

# --- Progress ---
var wave_index: int = 1
var waves_cleared: int = 0
var run_elapsed: float = 0.0
var run_seed: int = 0
var victory_reached: bool = false

# --- Economy ---
var gold: int = 0
var mithril: int = 0
var prestige_pending: int = 0
var wave_gold_base: float = 0.0
var wave_prestige_buffer: int = 0

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


func _process(delta: float) -> void:
	if _current_state == &"COMBAT" or _current_state == &"BOSS_COMBAT":
		run_elapsed += delta


func init_from_config(config: RunConfig) -> void:
	if config == null:
		return
	wave_index = config.start_wave
	waves_cleared = maxi(0, config.start_wave - 1)
	gold = config.starting_gold
	run_seed = config.run_seed
	fortress_hp = config.fortress_max_hp
	fortress_max_hp = config.fortress_max_hp
	commander_hp = config.commander_max_hp
	commander_max_hp = config.commander_max_hp
	emg_repair_heal_pct = config.emg_repair_heal_pct
	rerolls_left = config.rerolls_per_run
	owned_weapons = [BASE_WEAPON]
	equipped_weapon = BASE_WEAPON


## Adds a weapon to the run. False when the id is empty or the weapon is already owned.
func grant_weapon(id: StringName) -> bool:
	if id == &"" or owned_weapons.has(id):
		return false
	owned_weapons.append(id)
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


func end_run(end_type: StringName = &"DEFEAT") -> void:
	if _run_is_ended:
		return
	_run_is_ended = true
	var run_result: StringName = &"SURVIVED" if victory_reached else &"DEFEAT"
	if end_type == &"ABANDONED":
		run_result = &"SURVIVED" if victory_reached else &"ABANDONED"
	
	var summary := build_summary(end_type, run_result)
	EventBus.run_ended.emit(end_type, summary)


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
		"run_kills": run_kills,
		"run_commander_kills": run_commander_kills,
		"run_gold_earned": run_gold_earned,
		"run_bosses_defeated": run_bosses_defeated,
		"commander_level": commander_level,
		"equipped_weapon": equipped_weapon,
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


func _on_enemy_died(_enemy_type: StringName, _pos: Vector3, _gold_base: int, _prestige: int, is_cull: bool, hit_by_commander: bool) -> void:
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
	commander_hp = float(hp)
	commander_max_hp = float(max_hp)


func _on_emergency_repair_state_changed(charges: int, cooldown: float, heal_pct: float) -> void:
	emg_repair_charges = charges
	emg_repair_cd = cooldown
	emg_repair_heal_pct = heal_pct


func _on_commander_mode_changed(mode: StringName) -> void:
	commander_mode = mode
