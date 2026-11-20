// Toon shading that tints only a unit's clothing and gear: the bones (light, nearly grey texels
// of the skeleton texture) keep their own colour, everything else is multiplied by cloth_color.
// Used to give a skeleton type its own outfit colour while its bones stay white.
shader_type spatial;
render_mode cull_disabled;

#include "res://art/shaders/toon_common.gdshaderinc"

uniform vec4 cloth_color : source_color = vec4(1.0);
// A texel counts as bone above this brightness and under this saturation (in the texture's own
// sRGB values), with a soft edge so the tint does not cut off hard.
uniform float bone_min_brightness : hint_range(0.0, 1.0) = 0.66;
uniform float bone_max_saturation : hint_range(0.0, 1.0) = 0.32;

void fragment() {
	toon_surface(UV, ALBEDO, ROUGHNESS, AO, AO_LIGHT_AFFECT);
	vec3 t = pow(texture(albedo_texture, UV).rgb, vec3(1.0 / 2.2));
	float brightness = dot(t, vec3(0.2126, 0.7152, 0.0722));
	float top = max(t.r, max(t.g, t.b));
	float saturation = top > 0.0 ? (top - min(t.r, min(t.g, t.b))) / top : 0.0;
	float bone = smoothstep(bone_min_brightness - 0.06, bone_min_brightness + 0.04, brightness)
		* (1.0 - smoothstep(bone_max_saturation - 0.05, bone_max_saturation + 0.05, saturation));
	ALBEDO *= mix(cloth_color.rgb, vec3(1.0), bone);
}
