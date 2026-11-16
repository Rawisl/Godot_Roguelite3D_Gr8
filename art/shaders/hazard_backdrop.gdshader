shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
// Painted sky behind the Hazard Trial island, on a flat quad facing the fixed camera.
// The lower part fades darker so the eye stays on the island; the whole image can be dimmed a
// little so it never competes with the fight in front of it.

uniform sampler2D backdrop : source_color, filter_linear, repeat_disable;
// Brightness of the whole image.
uniform float brightness : hint_range(0.0, 1.5) = 0.9;
// Where the darkening starts and ends, 0 at the top of the image and 1 at the bottom.
uniform float dark_start : hint_range(0.0, 1.0) = 0.4;
uniform float dark_end : hint_range(0.0, 1.0) = 0.95;
// Brightness left at dark_end.
uniform float dark_floor : hint_range(0.0, 1.0) = 0.12;
uniform vec3 dark_tint : source_color = vec3(0.09, 0.05, 0.2);

void fragment() {
	vec3 col = texture(backdrop, UV).rgb * brightness;
	float t = smoothstep(dark_start, dark_end, UV.y);
	col = mix(col, dark_tint, t * (1.0 - dark_floor));
	ALBEDO = col;
}
