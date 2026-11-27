shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Fake sunbeam for the Compatibility renderer, which has no volumetric fog.
// The box runs along local -Z from the window; it fades towards the far end and the sides.
uniform vec4 beam_color : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float intensity = 0.32;
uniform vec3 half_size = vec3(0.75, 1.3, 2.7);

varying vec3 p;

void vertex() {
	p = VERTEX / half_size;
}

void fragment() {
	float along = clamp(0.5 - p.z * 0.5, 0.0, 1.0);
	float side = (1.0 - smoothstep(0.55, 1.0, abs(p.x))) * (1.0 - smoothstep(0.55, 1.0, abs(p.y)));
	float fade = (1.0 - along * 0.75) * side;
	ALBEDO = beam_color.rgb * intensity * fade;
}
