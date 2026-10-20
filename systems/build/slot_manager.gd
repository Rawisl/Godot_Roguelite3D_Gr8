class_name SlotManager
extends Node3D

@export var required_wall_ids: Array[StringName] = [
	&"W1", &"W2", &"W3", &"W4", &"W5", &"W6"
]
## Where slots are collected from. Empty = every Slot in group "slot".
## GroundGrid (GRID-02) only has to spawn its cells before reload_slots() runs.
@export var slot_root: Node

# SLOT-05: slot_id prefix must match the zone (W = wall slot, G_c_r = ground grid cell).
const ZONE_BY_PREFIX := {
	"W": Enums.SlotZone.WALL,
	"G": Enums.SlotZone.GROUND,
}

var _slots: Dictionary = {}  # StringName -> Slot
# Built once per reload. Read-only
var _all: Array[Slot] = []  # WALL first, then GROUND, each by slot_id
var _by_zone: Dictionary = {}  # Enums.SlotZone -> Array[Slot], same order as _all
var _problems: PackedStringArray = []

func _ready() -> void:
	reload_slots()
	EventBus.state_changed.connect(_on_game_state_changed)

func reload_slots() -> void:
	_collect_slots()
	_validate_layout()

## Layout problems found by the last reload (SLOT-05 [LOG]). Empty = layout is valid.
func get_layout_problems() -> PackedStringArray:
	return _problems

## Collect Slots and append into _slots dictionary
func _collect_slots() -> void:
	_slots.clear()
	_all = []
	_by_zone = {}
	_problems.clear()
	for node in _gather_candidates():
		# soft validate node, if this node variable is not Slot it will become null
		# push bug instead crash
		var slot := node as Slot
		if slot == null:
			push_warning("SlotManager: node '%s' in group slot is not a Slot" % node.get_path())
			continue
		if _slots.has(slot.slot_id):
			_report("duplicate slot_id '%s'" % slot.slot_id)
			continue
		_slots[slot.slot_id] = slot
		_all.append(slot)
	_all.sort_custom(func(a: Slot, b: Slot) -> bool:
		if a.zone != b.zone:
			return a.zone < b.zone
		return String(a.slot_id).naturalnocasecmp_to(String(b.slot_id)) < 0)
	for slot in _all:
		if not _by_zone.has(slot.zone):
			var list: Array[Slot] = []
			_by_zone[slot.zone] = list
		_by_zone[slot.zone].append(slot)
	_all.make_read_only()
	for list: Array[Slot] in _by_zone.values():
		list.make_read_only()

func _gather_candidates() -> Array[Node]:
	if slot_root == null:
		return get_tree().get_nodes_in_group("slot")
	var result: Array[Node] = []
	for node in slot_root.find_children("*", "", true, false):
		if node.is_in_group("slot"):
			result.append(node)
	return result

# SLOT-05: [LOG] W1-W6 exist, each slot_id prefix matches its zone, no duplicate slot_id
func _validate_layout() -> void:
	for id in required_wall_ids:
		if not _slots.has(id):
			_report("missing slot '%s'" % id)

	for slot in _all:
		var id := slot.slot_id
		# prefix = first letter of id, refers to zone
		var prefix := String(id).left(1)
		if Enums.SlotZone.find_key(slot.zone) == null:
			_report("slot '%s' has invalid zone value %d" % [id, slot.zone])
		elif not ZONE_BY_PREFIX.has(prefix):
			_report("slot '%s' has unknown prefix, expected W (WALL) or G (GROUND)" % id)
		elif ZONE_BY_PREFIX[prefix] != slot.zone:
			_report("slot '%s' has zone %s, expected %s" % [
				id, Enums.SlotZone.find_key(slot.zone),
				Enums.SlotZone.find_key(ZONE_BY_PREFIX[prefix])])

func _report(msg: String) -> void:
	_problems.append(msg)
	push_warning("SlotManager: " + msg)

func get_slot(slot_id: StringName) -> Slot:
	return _slots.get(slot_id)

## Read-only, no copy. Use duplicate() if the caller needs to change the list.
func get_all_slots() -> Array[Slot]:
	return _all

## Read-only, no copy. Empty array when the zone has no slot.
func get_slots_in_zone(zone: Enums.SlotZone) -> Array[Slot]:
	if _by_zone.has(zone):
		return _by_zone[zone]
	var empty: Array[Slot] = []
	return empty

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
