shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

// Warm daylight behind leaded glass: a diamond lattice drawn in object space.
uniform vec4 glass_color : source_color = vec4(1.0, 0.88, 0.7, 1.0);
uniform float glow = 2.5;
uniform float cells = 18.0;
uniform float lead_width = 0.12;

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	float u = abs(sin((obj_pos.z + obj_pos.y) * cells));
	float v = abs(sin((obj_pos.z - obj_pos.y) * cells));
	float lead = step(min(u, v), lead_width);
	ALBEDO = mix(glass_color.rgb * glow, vec3(0.02), lead);
	ALPHA = mix(0.85, 1.0, lead);
}
