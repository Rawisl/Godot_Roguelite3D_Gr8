shader_type spatial;
// White sword-slash trail for the Fox Commander combo.
// The ribbon mesh is swept by the blade in Blender: UV.x runs along the swing, UV.y across the blade
// (0 at the tip edge after the glTF flip), and UV2.x * 100 is the clip frame at which the blade passed.
// The clip's animation drives `trail_time` (current clip frame), so only the swept part shows and fades.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

instance uniform float trail_time = -1000.0;
instance uniform float life = 4.0;

uniform vec4 color_rim : source_color = vec4(0.30, 0.42, 0.55, 1.0);
uniform vec4 color_mid : source_color = vec4(0.62, 0.78, 0.90, 1.0);
uniform vec4 color_bright : source_color = vec4(0.88, 0.95, 1.0, 1.0);
uniform vec4 color_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow = 1.6;
uniform float boost = 1.6;
uniform float alpha_scale = 1.6;
uniform float gap_fill : hint_range(0.0, 1.0) = 0.55;
uniform float edge_power = 2.0;
uniform float hot_core_power = 12.0;
uniform sampler2D streak_noise : repeat_enable, filter_linear_mipmap;
uniform vec2 streak_scale = vec2(0.3, 5.2);
uniform vec2 sparkle_scale = vec2(60.0, 14.0);
uniform float sparkle_size = 0.06;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float sparkle_distance(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float d = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 point = vec2(hash12(cell + o), hash12(cell + o + 17.0));
			d = min(d, length(o + point - f));
		}
	}
	return d;
}

vec3 ramp(float t) {
	if (t < 0.3) return mix(color_rim.rgb, color_mid.rgb, t / 0.3);
	if (t < 0.6) return mix(color_mid.rgb, color_bright.rgb, (t - 0.3) / 0.3);
	return mix(color_bright.rgb, color_core.rgb, clamp((t - 0.6) / 0.25, 0.0, 1.0));
}

void fragment() {
	float u = UV.x;
	float v = 1.0 - UV.y;  // back to Blender's convention: 0 at the guard side, 1 at the tip
	float age = trail_time - UV2.x * 100.0;
	float swept = step(-0.001, age);
	float fade = pow(clamp(1.0 - age / life, 0.0, 1.0), 1.4);
	float vis = swept * fade;

	float width = pow(sin(u * PI), 0.6);
	float inner = 1.0 - width;
	float shape = smoothstep(inner, inner + 0.18, v);
	float edge = pow(v, edge_power) * 0.55 + 0.45;

	float n = texture(streak_noise, vec2(u, v) * streak_scale).r;
	float streak = mix(gap_fill, 1.0, smoothstep(0.35, 0.7, n));
	float spark = (1.0 - smoothstep(0.0, sparkle_size, sparkle_distance(vec2(u, v) * sparkle_scale))) * shape * 0.8;

	float intensity = clamp((shape * edge * streak + spark) * vis, 0.0, 1.0);
	float hot = pow(fade, hot_core_power) * shape * pow(v, 1.5) * swept;
	float total = clamp((intensity + hot) * boost, 0.0, 1.0);

	ALBEDO = ramp(total) * (1.0 + total * glow);
	ALPHA = clamp(total * alpha_scale, 0.0, 1.0);
}
