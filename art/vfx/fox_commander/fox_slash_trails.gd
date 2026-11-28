extends Node3D
## Slash trails of the Fox Commander combo (ribbons swept in Blender, one per combo hit).
## The melee clips key each ribbon's visible and trail_time, so this script never touches them.
## "Reduce flashing" (setting reduce_flash) hides the bright white trails through the shader's
## opacity instead of visible, which the clips would set back on the next hit.
## The trails stay out of the hit flash: its overlay would draw the whole ribbon in flat white,
## ignoring the shader's fade, so a hit during a slash showed a pale disc round the commander.


func _ready() -> void:
	add_to_group(HitReactionManager.NO_FLASH_GROUP)
	_apply(GameState.get_setting(&"reduce_flash", false) == true)
	EventBus.settings_changed.connect(_on_settings_changed)


func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"reduce_flash":
		_apply(value == true)


func _apply(reduce_flash: bool) -> void:
	for mesh in find_children("*", "GeometryInstance3D", true, false):
		(mesh as GeometryInstance3D).set_instance_shader_parameter(&"opacity", 0.0 if reduce_flash else 1.0)
