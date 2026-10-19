// Toon / cel shading dùng chung cho nhân vật, quân địch, fortress, môi trường.
// Không có dither: vật có thể bị làm mờ khi che (tower) dùng toon_dither.gdshader.
shader_type spatial;
render_mode cull_disabled;

#include "res://art/shaders/toon_common.gdshaderinc"

void fragment() {
	toon_surface(UV, ALBEDO, ROUGHNESS, AO, AO_LIGHT_AFFECT);
}
