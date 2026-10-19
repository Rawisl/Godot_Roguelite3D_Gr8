@tool
extends Node3D
## Preview for the hover edge glow. Open this scene, expand the Outline material in the
## Inspector and drag its shader parameters; the towers update in the editor viewport.

@export var outline: ShaderMaterial:
	set(value):
		outline = value
		_apply()

func _ready() -> void:
	_apply()

func _apply() -> void:
	if not is_inside_tree():
		return
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = outline
