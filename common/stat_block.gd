class_name StatBlock
extends RefCounted
## Effective stat values: (base + sum(add)) * (1 + sum(mul)).
## Base values are read live from a CharacterStats resource, which is never written to.
## Modifiers are keyed by source, so setting a source again replaces its previous value.

signal changed

var base_stats: CharacterStats

# stat_key -> { source -> float }
var _add: Dictionary = {}
var _mul: Dictionary = {}


func _init(stats: CharacterStats = null) -> void:
	base_stats = stats


func set_modifier(stat_key: StringName, source: StringName, add_value: float = 0.0, mul_value: float = 0.0) -> void:
	_set_entry(_add, stat_key, source, add_value)
	_set_entry(_mul, stat_key, source, mul_value)
	changed.emit()


func set_add(stat_key: StringName, source: StringName, value: float) -> void:
	_set_entry(_add, stat_key, source, value)
	changed.emit()


func set_mul(stat_key: StringName, source: StringName, value: float) -> void:
	_set_entry(_mul, stat_key, source, value)
	changed.emit()


func clear_source(source: StringName) -> void:
	var removed := false
	for table: Dictionary in [_add, _mul]:
		for stat_key: StringName in table.keys():
			var sources: Dictionary = table[stat_key]
			if sources.erase(source):
				removed = true
			if sources.is_empty():
				table.erase(stat_key)
	if removed:
		changed.emit()


func clear_all() -> void:
	if _add.is_empty() and _mul.is_empty():
		return
	_add.clear()
	_mul.clear()
	changed.emit()


## Base value from CharacterStats. Keys that CharacterStats does not have start from 0.
func get_base(stat_key: StringName) -> float:
	if base_stats == null:
		return 0.0
	var value: Variant = base_stats.get(stat_key)
	if value == null:
		return 0.0
	return float(value)


func get_value(stat_key: StringName) -> float:
	return (get_base(stat_key) + get_add_total(stat_key)) * (1.0 + get_mul_total(stat_key))


## Same as get_value, then clamped to [0, cap]. Used for armor-like stats.
func get_capped(stat_key: StringName, cap: float) -> float:
	return clampf(get_value(stat_key), 0.0, cap)


func get_add_total(stat_key: StringName) -> float:
	return _sum(_add, stat_key)


func get_mul_total(stat_key: StringName) -> float:
	return _sum(_mul, stat_key)


## Effective max HP, rounded down.
func get_max_hp() -> int:
	return floori(get_value(&"commander_max_hp"))


func _set_entry(table: Dictionary, stat_key: StringName, source: StringName, value: float) -> void:
	if is_zero_approx(value):
		if table.has(stat_key):
			(table[stat_key] as Dictionary).erase(source)
		return
	if not table.has(stat_key):
		table[stat_key] = {}
	(table[stat_key] as Dictionary)[source] = value


func _sum(table: Dictionary, stat_key: StringName) -> float:
	var total := 0.0
	if table.has(stat_key):
		for value: float in (table[stat_key] as Dictionary).values():
			total += value
	return total
