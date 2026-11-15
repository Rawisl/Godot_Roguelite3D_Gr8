class_name MetaUpgrades
extends RefCounted
## The four permanent meta shop upgrades and what their levels add to a run. Static only:
## the shop service, the save clamp and run loading read the same data from here.

## In shop order.
const ITEMS: Array[ShopItem] = [
	preload("res://data/config/meta_shop/fort_hp.tres"),
	preload("res://data/config/meta_shop/gold_pct.tres"),
	preload("res://data/config/meta_shop/cmd_hp.tres"),
	preload("res://data/config/meta_shop/emg_repair.tres"),
]
const FORTRESS_STATS: FortressStats = preload("res://data/config/fortress_stats.tres")
const COMMANDER_STATS: CharacterStats = preload("res://data/config/commander_stats.tres")

## Null when the id is not one of the shop items.
static func find_item(item_id: StringName) -> ShopItem:
	for item in ITEMS:
		if item.id == item_id:
			return item
	return null

## Max level per item id, keyed by String like meta.levels in the save.
static func get_max_levels() -> Dictionary:
	var result := {}
	for item in ITEMS:
		result[String(item.id)] = item.get_max_level()
	return result

## Values for RunConfig.create_default (its p_meta) from the saved meta.levels. The effect
## steps in the shop data are display numbers (percent or points), so they are divided here.
static func get_run_modifiers(levels: Dictionary) -> Dictionary:
	var fort_add := _effect_added(&"FORT_HP", levels)
	var cmd_add := _effect_added(&"CMD_HP", levels)
	var emg_add := _effect_added(&"EMG_REPAIR", levels)
	var gold_add := _effect_added(&"GOLD_PCT", levels)
	return {
		"fortress_max_hp": roundi(FORTRESS_STATS.max_hp * (1.0 + fort_add / 100.0)),
		"commander_max_hp": float(COMMANDER_STATS.commander_max_hp) + cmd_add,
		"emg_repair_heal_pct": GameConfig.emg_repair_base_heal_pct + emg_add / 100.0,
		"gold_pct_meta": gold_add / 100.0,
	}

## What the saved level of an item adds on top of level 0, in the item's display unit.
static func _effect_added(item_id: StringName, levels: Dictionary) -> float:
	var item := find_item(item_id)
	if item == null:
		return 0.0
	var level := int(levels.get(String(item_id), 0))
	return item.get_effect(level) - item.get_effect(0)
