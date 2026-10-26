class_name StatCardApplier
extends Node
## Writes picked cards into a StatBlock. Listens to EventBus.reward_picked while inside the tree.

signal applied(card_id: StringName)

@export var table: StatCardTable

var stat_block: StatBlock


func _ready() -> void:
	if table == null:
		push_warning("StatCardApplier has no card table, picked cards will have no effect")
	EventBus.reward_picked.connect(_on_reward_picked)


func apply_pick(card_id: StringName, new_level: int) -> void:
	if stat_block == null or table == null:
		return
	var entries := table.entries_for(card_id)
	if entries.is_empty():
		return
	# Setting a source again overwrites it, so there is no clear step that listeners could observe.
	for entry in entries:
		var value := entry.per_level * float(new_level)
		if entry.kind == StatCardEntry.Kind.ADD:
			stat_block.set_add(entry.stat_key, card_id, value)
		else:
			stat_block.set_mul(entry.stat_key, card_id, value)
	applied.emit(card_id)


func _on_reward_picked(card_id: StringName, _slot_kind: StringName, new_level: int) -> void:
	apply_pick(card_id, new_level)
