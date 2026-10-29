shader_type spatial;
// Frontline aura ring around the commander. A soft line at the aura radius, a faint
// fill that gets stronger toward the edge, and a slow ripple moving outward.
// Depth test stays on so walls, towers and units hide it.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

// ally_accent, the same gold as the aura icons.
uniform vec4 ring_color : source_color = vec4(0.91, 0.76, 0.35, 0.85);
// Sizes are in metres. The plane must be at least 2 x (radius + glow room) wide.
// Set per ring by AuraFxManager, so the shared material is never written to.
instance uniform float radius = 12.0;
uniform float border_width = 0.18;
uniform float edge_softness = 0.08;
uniform float glow_falloff = 0.35;
uniform float glow_strength = 0.35;
// Fill alpha at the centre and just inside the line.
uniform float fill_center = 0.0;
uniform float fill_edge = 0.10;
uniform float ripple_speed = 0.35;
uniform float ripple_width = 0.12;
uniform float ripple_alpha = 0.12;
uniform float pulse_speed = 2.0;
uniform float pulse_amount = 0.25;
// 0 hidden, 1 shown. Set by AuraFxManager while it fades in and out.
instance uniform float fade = 1.0;

varying vec2 local_xz;

void vertex() {
	local_xz = VERTEX.xz;
}

void fragment() {
	float r = length(local_xz);
	float d = r - radius;
	// Distance to the border band, 0 inside it.
	float band = abs(d + border_width * 0.5) - border_width * 0.5;
	float border = 1.0 - smoothstep(0.0, edge_softness, band);
	float glow = exp(-max(band, 0.0) / glow_falloff) * glow_strength;
	float inside = 1.0 - smoothstep(-edge_softness, 0.0, d);
	float t = clamp(r / radius, 0.0, 1.0);
	float fill = inside * mix(fill_center, fill_edge, t * t);
	// One ring at a time travels from the centre to the edge.
	float front = fract(TIME * ripple_speed) * radius;
	float ripple = inside * (1.0 - smoothstep(0.0, ripple_width * radius, abs(r - front))) * ripple_alpha * t;
	float pulse = 1.0 - pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed));
	ALBEDO = ring_color.rgb;
	ALPHA = clamp(max(max(border * pulse * ring_color.a, glow * pulse), fill + ripple), 0.0, 1.0) * fade;
}
