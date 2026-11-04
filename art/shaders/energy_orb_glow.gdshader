shader_type spatial;
// Soft halo around the energy orb: a larger shell, brightest where it faces the camera and
// fading out at its silhouette. Fades with the station's HP store.
render_mode unshaded, shadows_disabled, cull_back, depth_draw_never, blend_add;

uniform vec4 glow_color : source_color = vec4(0.45, 0.92, 0.55, 1.0);
uniform float strength = 0.28;
instance uniform float store = 1.0;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = glow_color.rgb;
	ALPHA = pow(facing, 2.5) * strength * clamp(store, 0.0, 1.0);
}
