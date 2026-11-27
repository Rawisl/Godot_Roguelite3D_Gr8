shader_type spatial;
// Sword Wave: a wide shallow crescent of sword energy flying flat over the ground, in the same
// family as the Whirlwind blades. Layers, back to front:
// 1. Wisp: five thin broken streaks behind the hollow, they leave first.
// 2. Shard: two overlapping layers of blade shards streaming back from the inner edge and
//    fanning out, each cut off at a slant and narrowing to a point.
// 3. Glow: a soft cyan haze hugging the front edge.
// 4. Body and rim: the crescent itself, the outer disc minus an inner disc of the same radius
//    shifted back, with a bright rim on the front edge. The tips close because the inner edge
//    moves outward towards them.
// Shape maths runs in "wave space" q (X across, +Y forward) where the half width of the arc is
// arc_half; the plane is scaled so that arc_half lands on the half_width instance uniform.
// Local -Z is the flight direction and the node sits on the middle of the front edge.
// SkillFxManager moves the plane and sets half_width, tail_scale, fade, game_time and flicker, so
// it follows x2 / x3 and holds on Pause. Depth test stays on so walls, towers and units hide it.
// Premultiplied alpha lets the blade blend normally while the glow only adds light.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_premul_alpha;

// The skill palettes are in art/palette.md (Skill chỉ huy); these defaults are the Frost one.
uniform vec4 core_color : source_color = vec4(0.914, 0.988, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.663, 0.914, 0.969, 1.0);
uniform vec4 band_color : source_color = vec4(0.161, 0.725, 0.910, 1.0);
uniform vec4 shard_color : source_color = vec4(0.522, 0.859, 0.949, 1.0);
uniform vec4 mid_color : source_color = vec4(0.141, 0.475, 0.616, 1.0);
uniform vec4 tail_color : source_color = vec4(0.090, 0.224, 0.306, 1.0);

// Crescent in wave space: radius of both discs, the height of the outer disc centre, how far back
// the inner disc is shifted, half the width of the arc, and how far the inner edge moves out at
// the tips so they close.
uniform float arc_radius = 1.4;
uniform float arc_origin = -0.6;
uniform float inner_shift = 0.16;
uniform float arc_half = 0.85;
uniform float tip_close = 0.17;
// Ripples on the inner edge: size around the circle, amount, and how much the edge thins and
// roughens while the wave fades.
uniform float edge_cells = 6.0;
uniform float edge_ripple = 0.035;
uniform float edge_fade_thin = 0.06;
// Width of the bright rim at the middle (thins to a point at the tips) and of the glow, and the
// glow strength.
uniform float rim_width = 0.05;
uniform float glow_width = 0.06;
uniform float glow_alpha = 0.45;
// Shards: lanes in the front and back layers, the shortest length, the extra length a lane can
// get, how much they fan out behind the inner edge, and how short they get when fading.
uniform float lanes_front = 8.0;
uniform float lanes_back = 11.0;
uniform float shard_min = 0.25;
uniform float shard_extra = 0.45;
uniform float shard_fan = 0.8;
uniform float shard_fade_len = 0.45;
// Wisps: their opacity, the spacing between them, their length, how fast the gaps drift per
// second, and the fade level at which they are gone.
uniform float wisp_alpha = 0.45;
uniform float wisp_spacing = 0.26;
uniform float wisp_length = 0.75;
uniform float wisp_scroll = 4.0;
uniform float wisp_gone_at = 0.5;
// Seconds the wave takes to form, and the size it starts at (a part of the full size).
uniform float form_time = 0.06;
uniform float start_scale = 0.55;
// How far the plane reaches in wave space: sideways from the middle, behind the front edge, and
// the margin in front of it. SkillFxManager sizes the plane from these.
uniform float side_extent = 1.35;
uniform float tail_extent = 1.25;
uniform float front_margin = 0.3;
// Overall brightness. The Compatibility renderer has no HDR, so a high value burns to white.
uniform float brightness = 1.4;
// Half the width of the wave, tip to tip.
instance uniform float half_width = 1.5;
// 0..1: the shards and wisps grow to full length as the wave leaves the commander.
instance uniform float tail_scale = 1.0;
// 0 hidden, 1 shown.
instance uniform float fade = 1.0;
// Seconds since the cast, on game time. Drives the growth and the drifting gaps.
instance uniform float game_time = 0.0;
// 1 normal, 0 when flashing is reduced: the gaps in the wisps stop drifting.
instance uniform float flicker = 1.0;

varying vec2 local_xz;

void vertex() {
	local_xz = VERTEX.xz;
}

float wave_rand(float x) {
	return fract(sin(x) * 43758.5);
}

void fragment() {
	float grow = smoothstep(0.0, max(form_time, 0.001), game_time);
	float fade_t = 1.0 - clamp(fade, 0.0, 1.0);
	float wisp_fade = smoothstep(wisp_gone_at, 1.0, fade);
	float reach = mix(0.5, 1.0, tail_scale);

	// Wave space: the front edge of the outer disc is at local z = 0, +q.y points forward.
	float s = max(half_width, 0.001) / arc_half;
	vec2 q = vec2(local_xz.x, -local_xz.y) / s;
	// Grow around the front edge so it stays on the node while forming, then move to the disc centre.
	q /= mix(start_scale, 1.0, grow);
	q.y += arc_origin + arc_radius;
	float aa = max(fwidth(q.y), 1e-4) * 1.5;

	vec2 o = vec2(0.0, arc_origin);
	vec2 inner_c = vec2(0.0, arc_origin - inner_shift);
	float d_o = length(q - o);
	float d_i = length(q - inner_c);
	float xn = clamp(abs(q.x) / arc_half, 0.0, 1.0);
	float taper = sqrt(clamp(1.0 - xn * xn, 0.0, 1.0));

	// Torn inner edge along the angle around the inner circle.
	float ang = atan(q.x, q.y - inner_c.y) * edge_cells;
	float ei = floor(ang);
	float ef = fract(ang);
	float edge_n = mix(wave_rand(ei * 12.9898), wave_rand((ei + 1.0) * 12.9898), ef * ef * (3.0 - 2.0 * ef));
	float inner_r = arc_radius + edge_ripple * (edge_n - 0.5) * mix(1.0, 2.0, fade_t)
		+ edge_fade_thin * fade_t + tip_close * (1.0 - taper);

	float in_outer = 1.0 - smoothstep(arc_radius - aa, arc_radius, d_o);
	float out_inner = smoothstep(inner_r - 0.02, inner_r, d_i);
	float body_a = in_outer * out_inner * step(abs(q.x), arc_half);
	float depth = arc_radius - d_o;
	float rw = rim_width * taper;

	vec4 acc = vec4(0.0);

	// Distance behind the inner edge at this x.
	float inner_y = inner_c.y + sqrt(max(arc_radius * arc_radius - q.x * q.x, 0.0));
	float back = inner_y - q.y;

	// Long broken wisps behind the hollow.
	for (int w = 0; w < 5; w++) {
		float fw = float(w);
		float wx = (fw - 2.0) * wisp_spacing * (1.0 + max(back, 0.0) * 0.3);
		float wd = abs(q.x - wx);
		float wlen = (wisp_length - abs(fw - 2.0) * 0.12) * reach;
		float wt = clamp(back / max(wlen, 0.001), 0.0, 1.0);
		float seg = fract(back * 5.0 - game_time * wisp_scroll * flicker + fw * 0.37);
		float wa = (1.0 - smoothstep(0.008, 0.008 + aa * 2.0, wd)) * step(0.0, back) * (1.0 - smoothstep(0.7, 1.0, wt))
			* smoothstep(0.25, 0.4, seg) * wisp_alpha * wisp_fade;
		vec3 wc = mix(rim_color.rgb, mix(mid_color.rgb, tail_color.rgb, clamp(wt * 2.0 - 1.0, 0.0, 1.0)), clamp(wt * 2.0, 0.0, 1.0));
		acc = vec4(wc * wa, wa) + acc * (1.0 - wa);
	}

	// Shards: two overlapping layers streaming back from the inner edge, fanning out.
	float shard_len = mix(1.0, shard_fade_len, fade_t) * reach;
	for (int j = 1; j >= 0; j--) {
		float fj = float(j);
		float n = (j == 0) ? lanes_front : lanes_back;
		float xs = q.x / (1.0 + max(back, 0.0) * shard_fan);
		float lc = (xs / arc_half + 1.0) * 0.5 * n + fj * 0.5;
		float li = floor(lc);
		float lf = fract(lc);
		float h1 = wave_rand(li * 78.233 + fj * 17.0);
		float h2 = fract(sin(li * 39.425 + fj * 5.3) * 12543.3);
		float lane_x = (li + 0.5 - fj * 0.5) / n * 2.0 - 1.0;
		float len = (shard_min + shard_extra * h2) * (1.0 - lane_x * lane_x * 0.7) * shard_len * ((j == 0) ? 1.0 : 0.75);
		float b0 = -0.03;
		float t = clamp((back - b0) / max(len, 0.001), 0.0, 1.0);
		float half_w = (0.18 + 0.17 * h1) * (1.0 - 0.8 * t);
		float side = 1.0 - smoothstep(half_w - 0.1, half_w, abs(lf - 0.5));
		float cut_end = len + (lf - 0.5) * 0.2 * ((mod(li, 2.0) < 1.0) ? 1.0 : -1.0);
		float along = step(b0, back) * (1.0 - smoothstep(cut_end - 0.01, cut_end, back - b0)) * step(abs(lane_x), 1.0);
		float sa = side * along * ((j == 0) ? 0.9 : 0.6) * mix(1.0, 0.5, t) * grow;
		vec3 sc = mix(mix(shard_color.rgb, band_color.rgb, clamp(t * 1.6, 0.0, 1.0)), mid_color.rgb, clamp(t * 2.0 - 1.0, 0.0, 1.0));
		acc = vec4(sc * sa, sa) + acc * (1.0 - sa);
	}

	// Soft cyan glow around the front edge.
	float glow_a = exp(-abs(d_o - arc_radius) / max(glow_width, 0.001)) * glow_alpha * taper
		* smoothstep(arc_radius - 0.02, arc_radius + 0.06, d_i) * grow;
	acc = vec4(band_color.rgb * glow_a, glow_a) + acc * (1.0 - glow_a);

	// Solid crescent body: rim colour at the front edge, shard colour towards the hollow.
	vec3 body_c = mix(rim_color.rgb, shard_color.rgb, clamp((d_i - inner_r) / 0.12, 0.0, 1.0));
	acc = vec4(body_c * body_a, body_a) + acc * (1.0 - body_a);
	float rim_a = in_outer * (1.0 - smoothstep(rw - aa, rw, depth)) * out_inner * clamp(rw * 60.0, 0.0, 1.0);
	vec3 rim_c = mix(core_color.rgb, rim_color.rgb, clamp(depth / max(rw, 0.001), 0.0, 1.0));
	acc = vec4(rim_c * rim_a, rim_a) + acc * (1.0 - rim_a);

	acc *= fade;
	// acc is already premultiplied, so the colour is not divided by its alpha.
	ALBEDO = acc.rgb * brightness;
	ALPHA = clamp(acc.a, 0.0, 1.0);
}
