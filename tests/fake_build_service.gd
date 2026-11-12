class_name FakeBuildService
extends BuildService
## Stands in for BuildService in the panel checks. It answers only the calls the Build, Tower and
## Heal station panels make, with values set by the checks. Everything else is the real service.

var build_options: Array[Dictionary] = []
var tower_info: Dictionary = {}
var prep := true
## Fake for the starter towers: the wave until which the tower cannot be sold. 0 means it can.
var sell_locked_until := 0

func get_build_options(_slot_id: StringName) -> Array[Dictionary]:
	return build_options

func get_tower_info(_slot_id: StringName) -> Dictionary:
	return tower_info

func is_prep() -> bool:
	return prep

func get_sell_locked_until_wave(_slot_id: StringName) -> int:
	return sell_locked_until

## A ruined slot for the clear rubble button; null means the slot is not ruined.
var ruined_slot: Slot = null
var cleared := 0

func find_slot(_slot_id: StringName) -> Slot:
	return ruined_slot

func clear_rubble(_slot_id: StringName) -> bool:
	cleared += 1
	ruined_slot.state = Enums.SlotState.EMPTY
	return true
