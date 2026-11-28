shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Bright glare from the open doorway: a soft round bloom with a few faint rays, always facing
// the camera.
uniform vec4 glare_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform float strength = 0.0;
uniform float rays = 10.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float core = exp(-r * r * 6.0);
	float halo = exp(-r * 2.5) * 0.5;
	float streak = pow(abs(cos(atan(p.y, p.x) * rays * 0.5)), 24.0) * exp(-r * 1.8) * 0.35;
	ALBEDO = glare_color.rgb * (core + halo + streak) * strength * (1.0 - smoothstep(0.85, 1.0, r));
}
