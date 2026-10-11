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

void fragment() {
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
