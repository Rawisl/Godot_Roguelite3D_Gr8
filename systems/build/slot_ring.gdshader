shader_type spatial;
// SLOT-06: build ring on a slot. Rounded square outline with a soft edge and a faint fill.
// Hovered and selected rings get a thicker steady line and a glow around it.
// Depth test stays on so walls, towers and units hide it.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 ring_color : source_color = vec4(1.0, 1.0, 1.0, 0.6);
// Placeholder until Art picks a colour; palette `ruined` is too dark to read on the floor.
uniform vec4 ruined_color : source_color = vec4(0.78, 0.45, 0.23, 0.7);
// Golden brown: the slot picked for building.
uniform vec4 selected_color : source_color = vec4(0.92, 0.66, 0.28, 1.0);
// Sizes are in metres, so resizing the plane only changes how much room the glow has.
uniform float box_half = 1.14;
uniform float border_width = 0.14;
uniform float corner_radius = 0.38;
uniform float edge_softness = 0.06;
uniform float fill_alpha = 0.12;
uniform float glow_falloff = 0.08;
uniform float glow_strength = 0.6;
uniform float pulse_speed = 2.5;
uniform float pulse_amount = 0.3;

// Set per slot from slot.gd.
instance uniform float ruined = 0.0;
instance uniform float hovered = 0.0;
instance uniform float selected = 0.0;

varying vec2 local_xz;

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void vertex() {
	local_xz = VERTEX.xz;
}

void fragment() {
	float d = rounded_box(local_xz, vec2(box_half), corner_radius);
	float lit = max(hovered, selected);
	float bw = border_width * (1.0 + 0.5 * lit);
	// Distance to the border band, 0 inside it.
	float band = abs(d + bw * 0.5) - bw * 0.5;
	float border = 1.0 - smoothstep(0.0, edge_softness, band);
	float glow = exp(-max(band, 0.0) / glow_falloff) * glow_strength * lit;
	float inside = 1.0 - smoothstep(-edge_softness, 0.0, d);
	float pulse = 1.0 - pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed));
	vec4 base = mix(ring_color, ruined_color, ruined);
	vec4 c = mix(base, selected_color, selected);
	float line = border * mix(pulse * base.a, 1.0, lit);
	ALBEDO = c.rgb;
	ALPHA = clamp(max(max(line, glow), inside * fill_alpha * (1.0 + lit)), 0.0, 1.0);
}
