// Toon shading for a unit that is only partly visible (the Assassin). The material's opacity
// is set from the unit's EnemyData.stealth_opacity by stealth_model.gd, never written here.
// Ordered dither (discard), like toon_dither.gdshader, so it sorts like a solid mesh; a plain
// uniform rather than an instance uniform, so it does not take room in the instance buffer.
shader_type spatial;
render_mode cull_disabled;

#include "res://art/shaders/toon_common.gdshaderinc"

uniform float opacity : hint_range(0.0, 1.0) = 1.0;
// Light the surface gives off on its own (the eyes); black for none.
uniform vec4 glow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float glow_energy = 0.0;

const float BAYER_8X8[64] = float[](
	0.0, 32.0, 8.0, 40.0, 2.0, 34.0, 10.0, 42.0,
	48.0, 16.0, 56.0, 24.0, 50.0, 18.0, 58.0, 26.0,
	12.0, 44.0, 4.0, 36.0, 14.0, 46.0, 6.0, 38.0,
	60.0, 28.0, 52.0, 20.0, 62.0, 30.0, 54.0, 22.0,
	3.0, 35.0, 11.0, 43.0, 1.0, 33.0, 9.0, 41.0,
	51.0, 19.0, 59.0, 27.0, 49.0, 17.0, 57.0, 25.0,
	15.0, 47.0, 7.0, 39.0, 13.0, 45.0, 5.0, 37.0,
	63.0, 31.0, 55.0, 23.0, 61.0, 29.0, 53.0, 21.0);

void fragment() {
	if (opacity < 1.0) {
		ivec2 p = ivec2(FRAGCOORD.xy) % 8;
		if (opacity <= (BAYER_8X8[p.y * 8 + p.x] + 0.5) / 64.0) {
			discard;
		}
	}
	toon_surface(UV, ALBEDO, ROUGHNESS, AO, AO_LIGHT_AFFECT);
	EMISSION = glow.rgb * glow_energy;
}
