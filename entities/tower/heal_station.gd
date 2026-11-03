class_name HealStation
extends Tower
## Heal station: a ground building whose HP is the store the commander heals from (heal_channel.gd).
## It never attacks, never refills, and turns to rubble through the Slot when the store is empty.
## Draining is fractional: the part below 1 HP waits in _carry, HealthComponent keeps the whole HP.
# TODO(week 10): scale enemy damage to the store down by the wave damage multiplier
# TODO(week 10): tell a drained store apart from a destroyed one for the alerts

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

func heals_on_prep() -> bool:
	return false

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
