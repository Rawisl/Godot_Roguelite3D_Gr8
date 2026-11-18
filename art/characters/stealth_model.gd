extends Node3D
## Model of a stealth unit (the Assassin). Draws every mesh at the unit's stealth opacity through
## its material: the opacity comes from the EnemyData of the unit above the model
## (stealth_opacity when is_stealth is on), never from a value in this script. Without a unit
## above it (a preview or a test) preview_opacity is used.
## The material is copied once per model, so each Assassin can have its own opacity.

@export var material: ShaderMaterial = preload("res://contents/assets/characters/enemy and boss/textures/assassin_material.tres")
## The eyes glow through the dark body; same opacity as the rest.
@export var eyes_material: ShaderMaterial = preload("res://contents/assets/characters/enemy and boss/textures/assassin_eyes.tres")
## Opacity shown when no unit data is found.
@export_range(0.0, 1.0) var preview_opacity := 0.5

var _material: ShaderMaterial
var _eyes: ShaderMaterial


func _ready() -> void:
	_material = material.duplicate() as ShaderMaterial
	_eyes = eyes_material.duplicate() as ShaderMaterial
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_override = _eyes if String(mesh.name).ends_with("Eyes") else _material
	set_opacity(_unit_opacity())


func set_opacity(value: float) -> void:
	_material.set_shader_parameter(&"opacity", clampf(value, 0.0, 1.0))
	_eyes.set_shader_parameter(&"opacity", clampf(value, 0.0, 1.0))


func get_opacity() -> float:
	return float(_material.get_shader_parameter(&"opacity"))


func _unit_opacity() -> float:
	var n := get_parent()
	while n != null:
		var data: Variant = n.get(&"data")
		if data is Resource and data.get(&"is_stealth") != null:
			return float(data.get(&"stealth_opacity")) if data.get(&"is_stealth") else 1.0
		n = n.get_parent()
	return preview_opacity
