class_name SkillPalette
extends Resource
## The colours of the Whirlwind and Sword Wave visuals for one sword. The first six are the colour
## parameters of the skill shaders; spark colours the sparks that fly with the effect.

@export var core: Color = Color.WHITE
@export var rim: Color = Color.WHITE
@export var band: Color = Color.WHITE
@export var shard: Color = Color.WHITE
@export var mid: Color = Color.WHITE
@export var tail: Color = Color.WHITE
@export var spark: Color = Color.WHITE


## Writes the six shader colours onto material.
func apply_to(material: ShaderMaterial) -> void:
	material.set_shader_parameter(&"core_color", core)
	material.set_shader_parameter(&"rim_color", rim)
	material.set_shader_parameter(&"band_color", band)
	material.set_shader_parameter(&"shard_color", shard)
	material.set_shader_parameter(&"mid_color", mid)
	material.set_shader_parameter(&"tail_color", tail)
