extends Node
## Runs main.tscn for testing the build panels by hand. F6 on this scene.
## K: ruin the selected tower, to test rebuild. L: add 500 gold.
## Adds the ProjectilePool that main.tscn does not have yet, so towers shoot.

const MAIN := preload("res://main.tscn")
const PROJECTILE_POOL := preload("res://entities/projectile/projectile_pool.tscn")
const DEBUG_GOLD := 500

var _main: Node

func _ready() -> void:
	_main = MAIN.instantiate()
	add_child(_main)
	if get_tree().get_first_node_in_group(&"projectile_pool") == null:
		_main.add_child(PROJECTILE_POOL.instantiate())

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_K:
			_ruin_selected()
		KEY_L:
			var gold := get_tree().get_first_node_in_group(&"gold_manager") as GoldManager
			if gold != null:
				gold.add(DEBUG_GOLD)

func _ruin_selected() -> void:
	var selection := _main.find_child("SelectionController", true, false) as SelectionController
	var service := get_tree().get_first_node_in_group(&"build_service") as BuildService
	if selection == null or service == null or selection.selected_slot == &"":
		return
	var slot := service.find_slot(selection.selected_slot)
	if slot != null:
		slot.ruin()
