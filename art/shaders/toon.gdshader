// Toon / cel shading dùng chung cho nhân vật, tower, fortress (SRS 2.5).
// Sáng tối chia thành `bands` bậc, vùng tối nhuộm `shadow_tint` thay vì đen.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform int bands : hint_range(1, 4) = 2;
uniform float band_softness : hint_range(0.0, 0.2) = 0.03;
uniform vec4 shadow_tint : source_color = vec4(0.3, 0.32, 0.45, 1.0);
uniform float light_strength : hint_range(0.0, 2.0) = 0.75;
uniform float ambient_strength : hint_range(0.0, 1.0) = 0.55;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;

// Độ đặc của vật che, OcclusionManager chỉnh theo từng instance.
// Dither theo ma trận Bayer 8x8 (discard), không dùng alpha blend.
instance uniform float dither_alpha : hint_range(0.0, 1.0) = 1.0;

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
	if (dither_alpha < 1.0) {
		ivec2 p = ivec2(FRAGCOORD.xy) % 8;
		if (dither_alpha <= (BAYER_8X8[p.y * 8 + p.x] + 0.5) / 64.0) {
			discard;
		}
	}
	ALBEDO = texture(albedo_texture, UV).rgb * albedo_color.rgb;
	ROUGHNESS = 1.0;
	// Dùng AO để giảm ánh sáng môi trường, không ảnh hưởng đèn
	AO = ambient_strength;
	AO_LIGHT_AFFECT = 0.0;
}

void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float q = lit * float(bands);
	float edge = smoothstep(0.5 - band_softness, 0.5 + band_softness, fract(q));
	float stepped = clamp((floor(q) + edge) / float(bands), 0.0, 1.0);
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), stepped);

	float rim = smoothstep(1.0 - rim_width, 1.0, 1.0 - dot(NORMAL, VIEW));
	shade += vec3(rim * rim_strength * stepped);

	DIFFUSE_LIGHT += shade * light_strength * LIGHT_COLOR / PI;
}
