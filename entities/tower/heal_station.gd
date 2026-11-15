class_name HealStation
extends Tower
## Heal station: a ground building whose HP is the store the commander heals from (heal_channel.gd).
## It never attacks, never refills, and turns to rubble through the Slot when the store is empty.
## Draining is fractional: the part below 1 HP waits in _carry, HealthComponent keeps the whole HP.
## An upgrade adds only the store the new level gains.
# TODO(kiezroth): distinguish combat destruction from a drained store before routing station alerts.

## Store updates on EventBus are merged to at most one per interval (real time).
const STORE_SIGNAL_INTERVAL := 0.1
const EPSILON := 0.000001

## Store left, with the drained fraction taken off. Read by HealChannel.
var hp: float:
	get:
		return maxf(0.0, float(health.hp) - _carry) if health != null and health.hp > 0 else 0.0

## Store capacity. Read by the heal effects.
var max_hp: float:
	get:
		return float(health.max_hp) if health != null else 0.0

var _carry: float = 0.0
var _store_signal_due: float = 0.0
var _store_signal_pending := false

func _ready() -> void:
	add_to_group(&"heal_station")
	super._ready()
	# Never scans for or shoots at anything.
	range_area.monitoring = false
	set_physics_process(false)
	set_process(false)
	# Connected after super so the apply_level call while building sends nothing.
	health.hp_changed.connect(_on_store_changed)

func take_damage(damage_input: Variant, p_damage_type: Enums.DamageType = Enums.DamageType.SLASH) -> int:
	if not is_inside_tree() or is_queued_for_deletion() or health == null or health.hp <= 0:
		return 0
	var info: DamageInfo
	if damage_input is DamageInfo:
		# AoE can share a hit across receivers; preserve the original hit.
		var hit: DamageInfo = damage_input
		info = DamageInfo.new(hit.amount, hit.damage_type, hit.source,
			hit.knockback_force, hit.hit_direction, hit.hit_by_commander)
		info.raw = hit.raw
		info.dealt_mult = hit.dealt_mult
		info.is_dot = hit.is_dot
		info.resist = hit.resist
		info.immune = hit.immune
	elif damage_input is int:
		info = DamageInfo.new(damage_input, p_damage_type)
	else:
		return health.take_damage(damage_input, p_damage_type)
	if info.amount <= 0:
		return 0
	var multiplier := 1.0
	var manager := get_tree().get_first_node_in_group(&"wave_manager")
	if manager != null:
		var config := manager.get(&"scale_config") as ScaleConfig
		if config != null:
			multiplier = config.get_dmg_mult(int(manager.get(&"current_wave")))
	info.amount = maxi(1, ceili(float(info.amount) / pow(maxf(multiplier, 1.0), GameConfig.heal_tower_dmg_norm_exp)))
	return health.take_damage(info, p_damage_type)

func heals_on_prep() -> bool:
	return false

## The first call (while building, and every rebuild) fills the store like any tower.
## Later calls are upgrades: the store grows by what the new level adds and is never refilled.
func apply_level(new_level: int) -> void:
	if _lv == null:
		super.apply_level(new_level)
		return
	level = new_level
	_lv = data.levels[level - 1]
	(range_shape.shape as CylinderShape3D).radius = _lv.attack_range
	# Adds max_hp(new) - max_hp(old) and sends one hp_changed; _carry is left as it is.
	health.set_max_hp(_lv.max_hp, true)

## A station ruined while it still has HP (Overload) stops being a source in the same frame.
func is_alive() -> bool:
	return health.hp > 0 and not is_queued_for_deletion()

## Takes amount (can be below 1) out of the store. Not damage: no hit effect, no hit_by_commander.
func drain(amount: float) -> void:
	if amount <= 0.0 or not is_alive():
		return
	_carry += amount
	var whole := floori(_carry + EPSILON)
	if whole <= 0:
		return
	_carry = maxf(_carry - float(whole), 0.0)
	_remove_store(whole)

func _remove_store(amount: int) -> void:
	health.hp = maxi(0, health.hp - amount)
	health.hp_changed.emit(health.hp, health.max_hp)
	if health.hp == 0:
		_carry = 0.0
		health.died.emit()

## Refund follows the store left.
func get_sell_value() -> int:
	if health.max_hp <= 0:
		return 0
	return floori(float(invested_gold) * GameConfig.sell_refund_pct * hp / float(health.max_hp) + EPSILON)

func _on_store_changed(new_hp: int, new_max_hp: int) -> void:
	if new_hp <= 0 or TimeManager.real_time >= _store_signal_due:
		_emit_store(new_hp, new_max_hp)
	else:
		_store_signal_pending = true
		set_process(true)

func _process(_delta: float) -> void:
	if _store_signal_pending and TimeManager.real_time >= _store_signal_due:
		_emit_store(health.hp, health.max_hp)
	if not _store_signal_pending:
		set_process(false)

func _emit_store(new_hp: int, new_max_hp: int) -> void:
	_store_signal_pending = false
	_store_signal_due = TimeManager.real_time + STORE_SIGNAL_INTERVAL
	if slot_id != &"":
		EventBus.heal_tower_hp_changed.emit(slot_id, new_hp, new_max_hp)
