class_name StatCardTable
extends Resource
## Maps cards to the StatBlock modifiers they grant.

@export var entries: Array[StatCardEntry] = []


func entries_for(card_id: StringName) -> Array[StatCardEntry]:
	var result: Array[StatCardEntry] = []
	for entry in entries:
		if entry != null and entry.card_id == card_id:
			result.append(entry)
	return result
