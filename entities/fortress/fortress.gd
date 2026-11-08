class_name Fortress
extends StaticBody3D
## The main Fortress. Unique and fixed; cannot be built, sold or moved.
## Its HP is shared across the whole run. Damage, repairs and melee attack slots all go through here.

## Heal source names for fortress_repaired.
const REPAIR_SOURCE_MITHRIL := &"MITHRIL"
const REPAIR_SOURCE_EMERGENCY := &"EMERGENCY"
## Tolerance for float comparisons of HP percentages.
const PCT_EPSILON := 0.000001

@export var stats: FortressStats
## Meta FORT_HP level. RunLoading sets it before the Fortress enters the tree.
@export_range(0, 5) var fort_hp_level: int = 0

@onready var health: HealthComponent = %Health
@onready var _melee_slots: FortressMeleeSlots = %MeleeSlots

var _destroyed: bool = false
## Current wave state, tracked via EventBus.state_changed.
var _wave_state: StringName = &"PREP"
var _low_hp_alerted_this_wave: bool = false
## Last HP sent on fortress_hp_changed, used to compute delta.
var _last_hp: int = 0


func _ready() -> void:
	var max_hp := compute_max_hp(stats.max_hp, fort_hp_level)
	health.max_hp = max_hp
	health.hp = max_hp
	_last_hp = max_hp
	health.hp_changed.connect(_on_hp_changed)
	health.died.connect(_on_died)
	_melee_slots.setup(stats.melee_slots)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.fortress_hp_changed.emit.call_deferred(health.hp, health.max_hp, 0)


#region Stats
## Effective HP = base × (1 + 0.05 × FORT_HP level), computed once in RunLoading.
static func compute_max_hp(base_hp: int, level: int) -> int:
	return roundi(base_hp * (1.0 + 0.05 * level))


func get_hp() -> int:
	return health.hp


func get_max_hp() -> int:
	return health.max_hp


func is_full() -> bool:
	return health.hp >= health.max_hp


func is_destroyed() -> bool:
	return _destroyed


## Missing HP percentage as a float, not rounded before multiplying by price.
func get_missing_pct() -> float:
	if health.max_hp <= 0:
		return 0.0
	return float(health.max_hp - health.hp) / float(health.max_hp) * 100.0
#endregion


#region Damage
## fortress_damage = raw × (1 - armor), rounded up once, minimum 1.
## TRUE damage (Overload) ignores armor. Armor is capped at fortress_armor_cap.
static func compute_damage(raw: int, damage_type: Enums.DamageType, armor_pct: float) -> int:
	if raw <= 0:
		return 0
	if damage_type == Enums.DamageType.TRUE:
		return raw
	var armor := clampf(armor_pct, 0.0, GameConfig.fortress_armor_cap)
	return maxi(1, ceili(raw * (1.0 - armor) - PCT_EPSILON))


func take_damage(damage_input: Variant, p_damage_type: Enums.DamageType = Enums.DamageType.SLASH) -> void:
	if _destroyed:
		return
	var info: DamageInfo = null
	if damage_input is DamageInfo:
		info = damage_input
	elif damage_input is int:
		info = DamageInfo.new(damage_input, p_damage_type)
	if info == null:
		return
	if not _can_take_damage():
		return

	var final_amount := compute_damage(info.amount, info.damage_type, stats.armor_pct)
	if final_amount <= 0:
		return
	var final_info := DamageInfo.new(final_amount, info.damage_type, info.source, info.knockback_force, info.hit_direction)
	var taken := health.take_damage(final_info)
	if taken <= 0:
		return
	var src_name := &""
	if info.source != null and is_instance_valid(info.source):
		src_name = StringName(info.source.name)
	EventBus.fortress_damaged.emit(taken, _damage_type_name(info.damage_type), src_name)


func _can_take_damage() -> bool:
	return _wave_state == &"COMBAT" or _wave_state == &"BOSS_COMBAT"


static func _damage_type_name(t: Enums.DamageType) -> StringName:
	return StringName(Enums.DamageType.keys()[t])
#endregion


#region Repair
## Mithril repair: heals mithril_repair_pct × effective max HP, clamped at max. The Mithril itself is owned by
## RunState and spent by BuildService after this heals. Refused (0) when destroyed, outside PREP or at full HP.
## Returns the HP actually healed.
func repair_with_mithril() -> int:
	if _destroyed:
		return 0
	if _wave_state != &"PREP":
		return 0
	if is_full():
		return 0
	var amount := floori(health.max_hp * stats.mithril_repair_pct + PCT_EPSILON)
	var hp_before := health.hp
	health.heal(amount)
	var healed := health.hp - hp_before
	if healed > 0:
		EventBus.fortress_repaired.emit(healed, REPAIR_SOURCE_MITHRIL)
	return healed


## Emergency repair: heals heal_pct × max_hp at no gold cost. Charges, cooldown and the
## Commander mode condition are owned by the Commander. Here it only refuses at full HP or when destroyed,
## and clamps at max on overheal. Returns the HP actually healed.
func emergency_repair(heal_pct: float) -> int:
	if _destroyed or is_full() or heal_pct <= 0.0:
		return 0
	var amount := floori(health.max_hp * heal_pct + PCT_EPSILON)
	var healed := health.heal(amount)
	if healed > 0:
		EventBus.fortress_repaired.emit(healed, REPAIR_SOURCE_EMERGENCY)
	return healed
#endregion


#region Melee attack slots
## Claims one of the fortress_melee_slots attack positions. Returns false when full (the unit must WAIT).
func claim_melee_slot(attacker: Node3D) -> bool:
	return _melee_slots.claim(attacker)


func release_melee_slot(attacker: Node3D) -> void:
	_melee_slots.release(attacker)


func has_melee_slot(attacker: Node3D) -> bool:
	return _melee_slots.has(attacker)


## Attack position of a unit holding a slot. Without a slot, returns the gate center.
func get_melee_slot_position(attacker: Node3D) -> Vector3:
	return _melee_slots.position_for(attacker)


func get_free_melee_slots() -> int:
	return _melee_slots.free_count()


## Slot holders walk onto their slot before swinging (read by Enemy), as on towers, instead
## of stopping attack_range short; the units waiting behind them then fit on crowd_wait_ring.
func get_melee_arrive_distance() -> float:
	return Tower.MELEE_ARRIVE_DISTANCE
#endregion


func _on_hp_changed(hp: int, max_hp: int) -> void:
	var delta := hp - _last_hp
	_last_hp = hp
	EventBus.fortress_hp_changed.emit(hp, max_hp, delta)
	_check_low_hp(hp, max_hp)


## At low_hp_warning_pct, raise a T1 alert once per wave.
func _check_low_hp(hp: int, max_hp: int) -> void:
	if _destroyed or _low_hp_alerted_this_wave or max_hp <= 0 or hp <= 0:
		return
	var ratio := float(hp) / float(max_hp)
	if ratio > stats.low_hp_warning_pct:
		return
	_low_hp_alerted_this_wave = true
	EventBus.fortress_low_hp.emit(ratio)
	EventBus.alert_requested.emit(int(Enums.AlertTier.T1), &"alert.fortress_low", {})


func _on_died() -> void:
	if _destroyed:
		return
	_destroyed = true
	_melee_slots.release_all()
	EventBus.fortress_destroyed.emit()


func _on_state_changed(new_state: StringName) -> void:
	_wave_state = new_state


func _on_wave_started(_wave_index: int) -> void:
	_low_hp_alerted_this_wave = false
