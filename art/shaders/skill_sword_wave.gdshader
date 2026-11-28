shader_type spatial;
// Sword Wave: a crescent of sword energy flying flat over the ground, drawn like one Whirlwind
// sweep: the front edge is the blade, the trail behind it fades back towards where it came from.
// - Body: the trail, strongest and lightest at the blade, darker and fainter further back. It is
//   longest in the middle and closes to nothing at the tips.
// - Rim: a bright edge along the blade, white in the middle.
// - Glow: a soft haze just in front of the blade.
// Shape maths runs in "wave space" q (X across, +Y forward) where the half width of the arc is
// arc_half; the plane is scaled so that arc_half lands on the half_width instance uniform.
// Local -Z is the flight direction and the node sits on the middle of the front edge.
// SkillFxManager moves the plane and sets half_width, tail_scale, fade, game_time and flicker, so
// it follows x2 / x3 and holds on Pause. Depth test stays on so walls, towers and units hide it.
// Premultiplied alpha lets the trail blend normally while the glow only adds light.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_premul_alpha;

// The skill palettes are in art/palette.md (Skill chỉ huy); these defaults are the Frost one.
uniform vec4 core_color : source_color = vec4(0.914, 0.988, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.663, 0.914, 0.969, 1.0);
uniform vec4 band_color : source_color = vec4(0.161, 0.725, 0.910, 1.0);
uniform vec4 shard_color : source_color = vec4(0.522, 0.859, 0.949, 1.0);
uniform vec4 mid_color : source_color = vec4(0.141, 0.475, 0.616, 1.0);
uniform vec4 tail_color : source_color = vec4(0.090, 0.224, 0.306, 1.0);

// Blade in wave space: radius of the front arc, the height of its centre, and half the width of
// the arc.
uniform float arc_radius = 1.0;
uniform float arc_origin = -0.6;
uniform float arc_half = 0.85;
// Trail behind the blade: its length in the middle, how fast it fades from the blade to its end
// (higher is a shorter bright part), how much shorter it gets while the wave fades, and the
// strength at its end and at the blade.
uniform float trail_length = 1.25;
uniform float trail_falloff = 1.4;
uniform float trail_fade_len = 0.5;
uniform float body_back = 0.2;
uniform float body_front = 0.4;
// How sharply the trail shortens towards the tips (1 follows the arc, higher is pointier), and
// how softly it ends at its sides, as a part of the half width.
uniform float tip_power = 2.0;
uniform float side_soft = 0.3;
// Width of the bright rim at the middle (thins to a point at the tips) and of the glow, and the
// glow strength.
uniform float rim_width = 0.05;
uniform float glow_width = 0.09;
uniform float glow_alpha = 0.65;
// Part of the blade, from the middle outwards, that turns white.
uniform float head_width = 0.5;
// Seconds the wave takes to form, and the size it starts at (a part of the full size).
uniform float form_time = 0.06;
uniform float start_scale = 0.55;
// How far the plane reaches in wave space: sideways from the middle, behind the front edge, and
// the margin in front of it. SkillFxManager sizes the plane from these.
uniform float side_extent = 1.35;
uniform float tail_extent = 1.7;
uniform float front_margin = 0.45;
// Overall brightness. The Compatibility renderer has no HDR, so a high value burns to white.
uniform float brightness = 1.7;
// Half the width of the wave, tip to tip.
instance uniform float half_width = 1.5;
// 0..1: the trail grows to full length as the wave leaves the commander.
instance uniform float tail_scale = 1.0;
// 0 hidden, 1 shown.
instance uniform float fade = 1.0;
// Seconds since the cast, on game time. Drives the growth.
instance uniform float game_time = 0.0;
// 1 normal, 0 when flashing is reduced: no white blade and no extra brightness.
instance uniform float flicker = 1.0;

varying vec2 local_xz;

void vertex() {
	local_xz = VERTEX.xz;
}

void fragment() {
	float grow = smoothstep(0.0, max(form_time, 0.001), game_time);
	float fade_t = 1.0 - clamp(fade, 0.0, 1.0);

	// Wave space: the front edge of the arc is at local z = 0, +q.y points forward.
	float s = max(half_width, 0.001) / arc_half;
	vec2 q = vec2(local_xz.x, -local_xz.y) / s;
	// Grow around the front edge so it stays on the node while forming, then move to the arc centre.
	q /= mix(start_scale, 1.0, grow);
	q.y += arc_origin + arc_radius;
	float aa = max(fwidth(q.y), 1e-4) * 1.5;

	vec2 o = vec2(0.0, arc_origin);
	float d_o = length(q - o);
	float xn = clamp(abs(q.x) / arc_half, 0.0, 1.0);
	float taper = sqrt(clamp(1.0 - xn * xn, 0.0, 1.0));
	// Distance behind the blade, along the radius of the arc.
	float behind = arc_radius - d_o;
	// Only the front half of the circle is the blade; the back half never draws.
	float in_side = (1.0 - smoothstep(1.0 - side_soft, 1.0, xn)) * step(arc_origin, q.y);

	// Trail: longest in the middle, closing at the tips; it grows as the wave leaves and shortens
	// while it fades.
	float len = trail_length * pow(taper, tip_power) * mix(0.3, 1.0, tail_scale) * mix(1.0, trail_fade_len, fade_t);
	float along = 1.0 - clamp(behind / max(len, 0.001), 0.0, 1.0);
	float in_trail = smoothstep(-aa, 0.0, behind) * step(behind, len) * in_side;
	float strength = pow(along, trail_falloff) * in_trail;
	float body_k = strength * mix(body_back, body_front, along) * grow;
	vec3 body_rgb = mix(mix(tail_color.rgb, mid_color.rgb, along), mix(band_color.rgb, shard_color.rgb, along), along);

	// Rim along the blade, white towards the middle.
	float rw = rim_width * taper;
	float rim_k = exp(-abs(behind) / max(rw, 0.001)) * smoothstep(-rw * 2.0, 0.0, behind) * in_side * grow;
	float head = (1.0 - smoothstep(0.0, max(head_width, 0.001), xn)) * flicker;
	vec3 rim_rgb = mix(rim_color.rgb, core_color.rgb, head);

	// Soft glow just in front of the blade.
	float glow_k = exp(-max(-behind, 0.0) / max(glow_width, 0.001)) * step(behind, 0.0) * step(arc_origin, q.y)
		* glow_alpha * taper * grow;

	vec4 acc = vec4(body_rgb * body_k, body_k);
	acc = vec4(band_color.rgb * glow_k, glow_k) + acc * (1.0 - glow_k);
	rim_k = clamp(rim_k, 0.0, 1.0);
	acc = vec4(rim_rgb * rim_k, rim_k) + acc * (1.0 - rim_k);
	acc *= fade;
	// acc is already premultiplied, so the colour is not divided by its alpha.
	ALBEDO = acc.rgb * mix(1.0, brightness, flicker);
	ALPHA = clamp(acc.a, 0.0, 1.0);
}
