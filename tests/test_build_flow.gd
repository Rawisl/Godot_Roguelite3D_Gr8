extends Node
## Runs main.tscn for testing the build panels by hand. F6 on this scene.
## K: ruin the selected tower, to test rebuild. L: add 500 gold.
## J: raise the commander level by 1, to test the upgrade limits.
## H: damage the Fortress. N / M / O: repair it by the small step, the large step, to full.
## Adds the ProjectilePool that main.tscn does not have yet, so towers shoot.

const MAIN := preload("res://main.tscn")
const PROJECTILE_POOL := preload("res://entities/projectile/projectile_pool.tscn")
const DEBUG_GOLD := 500
const DEBUG_FORTRESS_DAMAGE_PCT := 0.33

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
		KEY_J:
			var svc := get_tree().get_first_node_in_group(&"build_service") as BuildService
			if svc != null:
				EventBus.level_up.emit(svc.get_commander_level() + 1, 0)
		KEY_H:
			_damage_fortress()
		KEY_N:
			_repair_fortress(&"small")
		KEY_M:
			_repair_fortress(&"large")
		KEY_O:
			_repair_fortress(&"full")
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

func _damage_fortress() -> void:
	var fortress := get_tree().get_first_node_in_group(&"fortress") as Fortress
	if fortress == null:
		return
	# Straight to the HealthComponent: Fortress.take_damage ignores hits outside combat.
	fortress.health.take_damage(floori(fortress.get_max_hp() * DEBUG_FORTRESS_DAMAGE_PCT), Enums.DamageType.TRUE)

func _repair_fortress(step: StringName) -> void:
	var fortress := get_tree().get_first_node_in_group(&"fortress") as Fortress
	var service := get_tree().get_first_node_in_group(&"build_service") as BuildService
	var gold := get_tree().get_first_node_in_group(&"gold_manager") as GoldManager
	if fortress == null or service == null or gold == null:
		return
	var ratio := 0.0
	if step == &"small":
		ratio = fortress.stats.repair_step_small_pct
	elif step == &"large":
		ratio = fortress.stats.repair_step_large_pct
	var ok := service.repair_fortress(ratio)
	print("repair_fortress(%s) -> %s, hp %d/%d, gold %d" % [ratio, ok, fortress.get_hp(), fortress.get_max_hp(), gold.gold])
