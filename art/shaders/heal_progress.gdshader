shader_type spatial;
// Hold progress at the commander's feet while E is held at a heal station: a faint full ring
// with a bright arc sweeping clockwise from twelve o'clock as the hold fills.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 track_color : source_color = vec4(0.357, 0.89, 0.478, 0.25);
uniform vec4 fill_color : source_color = vec4(0.62, 1.0, 0.7, 0.95);
uniform float radius = 0.8;
uniform float width = 0.13;
uniform float edge_softness = 0.02;
// 0..1, set by HealFxManager.
instance uniform float progress = 0.0;
instance uniform float fade = 1.0;

varying vec2 local_xz;

void vertex() {
	local_xz = VERTEX.xz;
}

void fragment() {
	float r = length(local_xz);
	float d = abs(r - radius) - width * 0.5;
	float band = 1.0 - smoothstep(0.0, edge_softness, d);
	// Screen-up on the ground is -X -Z for the game camera; sweep clockwise from there.
	float up = -(local_xz.x + local_xz.y) * 0.7071;
	float right = (local_xz.x - local_xz.y) * 0.7071;
	float angle = fract(atan(right, up) / 6.2831853 + 1.0);
	float filled = step(angle, progress);
	vec4 col = mix(track_color, fill_color, filled);
	ALBEDO = col.rgb;
	ALPHA = band * col.a * fade;
}
