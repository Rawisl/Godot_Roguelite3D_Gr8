class_name Fortress
extends StaticBody3D
## The main Fortress (SRS v1.7 sections 3.6.1, 6.5). Unique and fixed; cannot be built, sold or moved.
## Its HP is shared across the whole run. Damage, repairs and melee attack slots all go through here.

## Heal source names for fortress_repaired (REP-01, CMD-02).
const REPAIR_SOURCE_GOLD := &"GOLD"
const REPAIR_SOURCE_EMERGENCY := &"EMERGENCY"
## Tolerance for float comparisons of HP percentages.
const PCT_EPSILON := 0.000001

@export var stats: FortressStats
## Meta FORT_HP level. RunLoading sets it before the Fortress enters the tree (FORT-04, APL-01).
@export_range(0, 5) var fort_hp_level: int = 0

@onready var health: HealthComponent = %Health
@onready var _melee_slots: FortressMeleeSlots = %MeleeSlots

var _destroyed: bool = false
## Current wave state, tracked via EventBus.state_changed (FORT-05, REP-05).
var _wave_state: StringName = &"PREP"
var _low_hp_alerted_this_wave: bool = false


func _ready() -> void:
	var max_hp := compute_max_hp(stats.max_hp, fort_hp_level)
	health.max_hp = max_hp
	health.hp = max_hp
	health.hp_changed.connect(_on_hp_changed)
	health.died.connect(_on_died)
	_melee_slots.setup(stats.melee_slots)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.fortress_hp_changed.emit.call_deferred(health.hp, health.max_hp)


#region Stats
## Effective HP = base × (1 + 0.05 × FORT_HP level), computed once in RunLoading (section 6.5).
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


## Missing HP percentage as a float, not rounded before multiplying by price (REP-01).
func get_missing_pct() -> float:
	if health.max_hp <= 0:
		return 0.0
	return float(health.max_hp - health.hp) / float(health.max_hp) * 100.0
#endregion


#region Damage
## fortress_damage = raw × (1 - armor), rounded up once, minimum 1.
## TRUE damage (Overload) ignores armor (OVL-01). Armor is capped at fortress_armor_cap (APL-03).
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
	return _wave_state != &"PREP" and _wave_state != &"SUMMARY"


static func _damage_type_name(t: Enums.DamageType) -> StringName:
	return StringName(Enums.DamageType.keys()[t])
#endregion


#region Repair
## REP-01: quote for one repair button. step_pct is a percentage of max HP (10 or 25); <= 0 means "to full HP".
## Returns {heal: HP to restore, cost: gold to deduct, pct: percentage actually repaired}.
## If gold does not cover the full step, repair floor(gold / price per 1%) percent.
static func quote_repair(step_pct: float, hp: int, max_hp: int, gold: int, gold_per_pct: int) -> Dictionary:
	var none := {heal = 0, cost = 0, pct = 0.0}
	var missing_hp := max_hp - hp
	if missing_hp <= 0 or max_hp <= 0 or gold_per_pct <= 0 or gold <= 0:
		return none
	var missing_pct := float(missing_hp) / float(max_hp) * 100.0
	var to_full := step_pct <= 0.0 or step_pct >= missing_pct - PCT_EPSILON
	var pct := missing_pct if to_full else step_pct
	var cost := ceili(pct * gold_per_pct - PCT_EPSILON)
	if gold >= cost:
		var heal := missing_hp if to_full else _pct_to_hp(pct, max_hp, missing_hp)
		return {heal = heal, cost = cost, pct = pct}
	var affordable_pct := floori(float(gold) / float(gold_per_pct))
	if affordable_pct <= 0:
		return none
	return {heal = _pct_to_hp(affordable_pct, max_hp, missing_hp), cost = affordable_pct * gold_per_pct, pct = float(affordable_pct)}


## Healed HP is rounded down (REP-01) and never exceeds the missing HP.
static func _pct_to_hp(pct: float, max_hp: int, missing_hp: int) -> int:
	return mini(missing_hp, floori(pct * max_hp / 100.0 + PCT_EPSILON))


## Quote based on current HP, for the Fortress panel (PNL-04). step_ratio is a ratio as in
## FortressStats (repair_step_small_pct 0.10, repair_step_large_pct 0.25); <= 0 means "to full HP".
func quote_repair_now(step_ratio: float, gold: int) -> Dictionary:
	return quote_repair(step_ratio * 100.0, health.hp, health.max_hp, gold, stats.repair_gold_per_pct)


## Repair with gold. The Fortress does not own gold: the economy system passes the current gold and deducts
## exactly the returned "cost". Refused (cost 0) outside PREP (REP-05), at full HP (REP-04) or when destroyed.
func repair_with_gold(step_ratio: float, gold: int) -> Dictionary:
	var none := {heal = 0, cost = 0, pct = 0.0}
	if _destroyed or _wave_state != &"PREP" or is_full():
		return none
	var quote := quote_repair_now(step_ratio, gold)
	if quote.heal <= 0:
		return none
	var healed := health.heal(quote.heal)
	if healed > 0:
		EventBus.fortress_repaired.emit(healed, REPAIR_SOURCE_GOLD)
	quote.heal = healed
	return quote


## Emergency repair (CMD-02): heals heal_pct × max_hp at no gold cost. Charges, cooldown and the
## Commander mode condition are owned by the Commander (CMD-09). Here it only refuses at full HP (CMD-07) or when destroyed,
## and clamps at max on overheal (CMD-08, FORT-03). Returns the HP actually healed.
func emergency_repair(heal_pct: float) -> int:
	if _destroyed or is_full() or heal_pct <= 0.0:
		return 0
	var amount := floori(health.max_hp * heal_pct + PCT_EPSILON)
	var healed := health.heal(amount)
	if healed > 0:
		EventBus.fortress_repaired.emit(healed, REPAIR_SOURCE_EMERGENCY)
	return healed
#endregion


#region Melee attack slots (FORT-01, CRD-01 to CRD-04)
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
#endregion


func _on_hp_changed(hp: int, max_hp: int) -> void:
	EventBus.fortress_hp_changed.emit(hp, max_hp)
	_check_low_hp(hp, max_hp)


## ALR-01: at low_hp_warning_pct, raise a T1 alert once per wave.
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
