class_name SlotManager
extends Node3D

## slot_ids that must exist on the map. Adding a slot only needs a new marker and its id here (SLOT-04).
@export var expected_ids: Array[StringName] = [
	&"W1", &"W2", &"W3", &"W4", &"W5", &"W6",
	&"N1", &"N2", &"N3", &"N4",
	&"F1", &"F2", &"F3", &"F4"
]

const ZONE_BY_PREFIX := {
	"W": Enums.SlotZone.WALL,
	"N": Enums.SlotZone.NEAR,
	"F": Enums.SlotZone.FAR,
}

var _slots: Dictionary = {}  # StringName -> Slot

func _ready() -> void:
	_collect_slots()
	_validate_layout()
	EventBus.state_changed.connect(_on_game_state_changed)

## Collect Slots tree and append into _slot dictionary
func _collect_slots() -> void:
	_slots.clear()
	for node in get_tree().get_nodes_in_group("slot"):
		# soft validate node, if this node variable is not Slot it will become null
		# push bug instead crash
		var slot := node as Slot
		if slot == null:
			push_warning("SlotManager: node '%s' in group slot is not a Slot" % node.get_path())
			continue
		if _slots.has(slot.slot_id):
			push_error("SlotManager: duplicate slot_id '%s'" % slot.slot_id)
			continue
		_slots[slot.slot_id] = slot
		slot.clicked.connect(_on_slot_clicked)

# SLOT-05: [LOG] check the fixed slot set and that each zone matches its W/N/F prefix
func _validate_layout() -> void:
	# Missing slot
	for id in expected_ids:
		if not _slots.has(id):
			push_warning("SlotManager: missing slot '%s'" % id)
	
	for id in _slots:
		var slot: Slot = _slots[id]
		# Incorrect id
		if not (id in expected_ids):
			push_warning("SlotManager: slot '%s' is not in expected_ids" % id)
		# Incorrect zone
		#prefix = First letter of id, refer to zone	
		var prefix := String(id).left(1)
		if ZONE_BY_PREFIX.has(prefix) and ZONE_BY_PREFIX[prefix] != slot.zone:
			push_warning("SlotManager: slot '%s' has zone %s, expected %s" % [
				id, Enums.SlotZone.keys()[slot.zone], 
				Enums.SlotZone.keys()[ZONE_BY_PREFIX[prefix]]])

func get_slot(slot_id: StringName) -> Slot:
	return _slots.get(slot_id)

func get_all_slots() -> Array[Slot]:
	var result: Array[Slot] = []
	for id in expected_ids:
		if _slots.has(id):
			result.append(_slots[id])
	return result

func get_slots_in_zone(zone: Enums.SlotZone) -> Array[Slot]:
	var result: Array[Slot] = []
	for slot in get_all_slots():
		if slot.zone == zone:
			result.append(slot)
	return result

# BLD-06: tower types not valid for the slot do not appear in the menu
func get_buildable_types(slot_id: StringName, towers: Array[TowerData]) -> Array[TowerData]:
	var result: Array[TowerData] = []
	var slot := get_slot(slot_id)
	if slot == null or not slot.is_free():
		return result
	for data in towers:
		if slot.allows(data):
			result.append(data)
	return result

## Reset every slot to EMPTY when a new run starts. Positions do not change (SLOT-05).
func reset_all() -> void:
	for slot in get_all_slots():
		slot.set_state(Enums.SlotState.EMPTY)

# SLOT-06: slot rings show in PREP and hide in COMBAT
func set_rings_visible(v: bool) -> void:
	for slot in get_all_slots():
		slot.set_buildable_visible(v)

func _on_game_state_changed(new_state: StringName) -> void:
	set_rings_visible(new_state == &"PREP")

func _on_slot_clicked(slot: Slot) -> void:
	EventBus.slot_selected.emit(slot.slot_id)
