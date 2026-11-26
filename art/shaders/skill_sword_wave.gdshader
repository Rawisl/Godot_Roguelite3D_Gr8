shader_type spatial;
// Sword Wave: a crescent of sword energy flying flat over the ground, drawn in four layers.
// 1. Rim: a smooth near-white band on the convex leading edge, thinning to a point at the tips.
// 2. Band: a thick saturated cyan body behind the rim. Its back edge is torn into flame-like
//    tongues of different lengths by drifting noise and its brightness pulses gently.
// 3. Tail: a few broad pale shards with white highlights and thin filaments trailing back,
//    fanning out along the crescent normal and fading to dark blue.
// 4. Halo: a soft cyan glow around the crescent. It is added on top of the scene, since the
//    Compatibility renderer has no glow.
// The front edge is a circular arc: the middle leads, the tips sweep back and curl inward.
// Local -Z is the flight direction, local X runs across the wave.
// SkillFxManager moves the plane and sets tail_scale, fade, game_time and flicker, so it follows
// x2 / x3 and holds on Pause. Depth test stays on so walls, towers and units hide it.
// Premultiplied alpha lets the crescent blend normally while the halo only adds light.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_premul_alpha;

#include "res://art/shaders/slash_common.gdshaderinc"

// skill_wave_* in art/palette.md.
uniform vec4 core_color : source_color = vec4(0.914, 0.988, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.663, 0.914, 0.969, 1.0);
uniform vec4 band_color : source_color = vec4(0.161, 0.725, 0.910, 0.95);
uniform vec4 shard_color : source_color = vec4(0.52, 0.86, 0.95, 0.95);
uniform vec4 mid_color : source_color = vec4(0.141, 0.475, 0.616, 0.75);
uniform vec4 tail_color : source_color = vec4(0.090, 0.224, 0.306, 0.5);
uniform vec4 halo_color : source_color = vec4(0.161, 0.725, 0.910, 1.0);
// Sizes are in metres. SkillFxManager sizes the plane from bulge, tail_length and halo_width.
// How far the middle of the crescent leads the tips.
uniform float bulge = 1.0;
// Thickness of the rim and of the band behind it in the middle. Both thin to a point at the tips.
uniform float rim_thickness = 0.5;
uniform float band_thickness = 1.1;
// How far behind the middle of the front edge the tips sit, as a part of half_width. The more
// the tips sweep back, the deeper the hollow inside the crescent.
uniform float tip_sweep = 1.15;
// Exponent of the head thickness along the arc: 1 tapers to sharp tips, lower is fuller.
uniform float head_taper = 1.2;
// Tongues torn out of the back edge of the band: size per metre across the wave, depth 0..1
// (how much of the band they can cut away), and how fast they drift in time.
uniform float band_noise_scale = 5.5;
uniform float band_tear = 0.7;
uniform float band_scroll = 0.6;
// How strongly the tongues and the tail converge: 1 / tail_fan is the distance behind the front
// edge where the lanes would meet.
uniform float tail_fan = 0.12;
// How much the band brightness pulses, and how often per second. The rate is capped at 3.
uniform float band_pulse = 0.15;
uniform float pulse_hz = 2.0;
// Length of the longest streak behind the front edge.
uniform float tail_length = 2.6;
// Shards and filaments per metre across the wave, and the filaments' opacity.
uniform float shard_density = 2.2;
uniform float filament_density = 8.0;
uniform float filament_alpha = 0.7;
// How much the streaks break up, and the shortest one as a part of the tail.
uniform float streak_breakup = 0.3;
uniform float streak_min_length = 0.35;
// Soft fill under the streaks, strongest at the head and gone by the end of the tail, so the
// head runs into the tail instead of standing apart.
uniform float body_alpha = 0.3;
// Opacity of the tail where it leaves the head, 0..1. Low values leave a dark bite inside the crescent.
uniform float tail_bite = 0.25;
// Part of the tail, at its end, over which everything fades out.
uniform float end_fade = 0.4;
// How far the glow reaches from the head. It is exactly zero at this distance.
uniform float halo_width = 0.45;
uniform float halo_strength = 0.4;
uniform float edge_softness = 0.04;
// Half the width of the wave, tip to tip.
instance uniform float half_width = 1.5;
// 0..1: the tail grows to full length as the wave leaves the commander.
instance uniform float tail_scale = 1.0;
// 0 hidden, 1 shown.
instance uniform float fade = 1.0;
// Seconds since the cast, on game time. Drives the band tears and pulse.
instance uniform float game_time = 0.0;
// 1 normal, 0 when flashing is reduced: the band stops pulsing and drifting.
instance uniform float flicker = 1.0;

varying vec2 local_xz;

void vertex() {
	local_xz = VERTEX.xz;
}

float wave_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float wave_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 s = f * f * (3.0 - 2.0 * f);
	return mix(mix(wave_hash(i), wave_hash(i + vec2(1.0, 0.0)), s.x),
		mix(wave_hash(i + vec2(0.0, 1.0)), wave_hash(i + vec2(1.0, 1.0)), s.x), s.y);
}

// One lane of blades: each is widest at the head and tapers to a point. lane is the coordinate
// across the wave, k the distance along the tail (0..1), max_half the widest half width in lane
// units. highlight is a thin bright spine on some of the blades.
float wave_blade(float lane, float k, float along, float min_length, float max_half, float breakup, out float highlight) {
	float id = floor(lane);
	float x = abs(fract(lane) - 0.5);
	float length_k = mix(min_length, 1.0, wave_hash(vec2(id + 3.7, 1.3)));
	float left = clamp(1.0 - k / length_k, 0.0, 1.0);
	float half_w = mix(0.55, 1.0, wave_hash(vec2(id + 5.1, 2.9))) * max_half * left;
	float aa = fwidth(lane);
	float body = (1.0 - smoothstep(half_w - aa, half_w + aa, x)) * smoothstep(0.0, 0.03, left) * step(0.0, k);
	float gaps = mix(1.0, smoothstep(0.1, 0.5, wave_noise(vec2(along * 1.2 + id * 13.1, id))), breakup);
	float spine = (1.0 - smoothstep(0.0, max(half_w * 0.45, aa), x)) * step(0.5, wave_hash(vec2(id + 7.7, 4.1)));
	highlight = spine * body;
	return body * gaps * mix(0.55, 1.0, left);
}

void fragment() {
	float u = local_xz.x / max(half_width, 0.001);
	float shape = max(1.0 - u * u, 0.0);
	float lean = sqrt(shape);
	// Distance behind the front edge (negative in front of it). The front edge is an arc that
	// leads at the middle and sweeps back to the tips.
	float front_d = tip_sweep * half_width * (1.0 - lean);
	float back = local_xz.y + bulge - front_d;
	float inside = smoothstep(0.0, edge_softness, back) * step(abs(u), 1.0);
	// Lanes are straight lines converging on a point behind the wave: vertical in the middle,
	// slanting inward toward the tips, like the normal of the arc.
	float fan_x = local_xz.x / max(1.0 - max(back, 0.0) * tail_fan, 0.3);

	float head_lean = pow(lean, head_taper);
	float rim_w = rim_thickness * head_lean;
	float band_w = band_thickness * head_lean;

	// Tail: broad shards and thin filaments, shorter toward the tips.
	// The tail leaves from the inner edge of the head and from the tips.
	float k = max(back - (rim_w + band_w * 0.8), 0.0) / max(tail_length * tail_scale, 0.001);
	float k_tip = k / (0.6 + 0.4 * lean);
	float shard_hl;
	float fil_hl;
	float shard_m = wave_blade(fan_x * shard_density, k_tip, back, streak_min_length, 0.48, streak_breakup, shard_hl);
	float fil_m = wave_blade(fan_x * filament_density + 17.0, k_tip * 0.6, back, streak_min_length, 0.2, streak_breakup, fil_hl) * filament_alpha;
	// The tail starts faint at the inner edge and grows, leaving a dark bite inside the crescent.
	float bite = mix(tail_bite, 1.0, smoothstep(0.0, 0.2, k));
	float fade_k = (1.0 - smoothstep(1.0 - end_fade, 1.0, k)) * inside * bite;
	float far = smoothstep(0.15, 1.0, k);
	vec3 shard_rgb = mix(shard_color.rgb, tail_color.rgb, far);
	vec3 fil_rgb = mix(mid_color.rgb, tail_color.rgb, far);
	float shard_a = clamp(shard_m * mix(shard_color.a, tail_color.a, clamp(k, 0.0, 1.0)), 0.0, 1.0) * fade_k;
	float fil_a = clamp(fil_m * mix(mid_color.a, tail_color.a, clamp(k, 0.0, 1.0)), 0.0, 1.0) * fade_k;
	float fill_a = body_alpha * pow(clamp(1.0 - k_tip, 0.0, 1.0), 2.0) * mid_color.a * fade_k;
	vec3 rgb = mid_color.rgb * fill_a;
	float a = fill_a;
	rgb = fil_rgb * fil_a + rgb * (1.0 - fil_a);
	a = fil_a + a * (1.0 - fil_a);
	rgb = shard_rgb * shard_a + rgb * (1.0 - shard_a);
	a = shard_a + a * (1.0 - shard_a);
	// White highlights on the broad shards, fading with distance.
	float hl_a = clamp(shard_hl * (1.0 - far) * 0.6, 0.0, 1.0) * shard_a;
	rgb = rim_color.rgb * hl_a + rgb * (1.0 - hl_a);
	a = hl_a + a * (1.0 - hl_a);

	// Band: the solid body is torn from behind into tongues that drift slowly over time.
	float t = game_time * band_scroll * flicker;
	float n1 = wave_noise(vec2(fan_x * band_noise_scale, t));
	float n2 = wave_noise(vec2(fan_x * band_noise_scale * 2.7 + 9.0, t * 1.4 + 4.0));
	float tongue = pow(smoothstep(0.3, 0.85, n1 * 0.7 + n2 * 0.5), 1.4);
	float reach = band_w * mix(1.0 - band_tear, 1.0, tongue);
	float band_depth = back - rim_w;
	float band_mask = (1.0 - smoothstep(reach - edge_softness, reach + edge_softness, band_depth)) * inside;
	float pulse = 1.0 + band_pulse * flicker * sin(game_time * TAU * min(pulse_hz, 3.0));
	float band_a = band_mask * band_color.a;
	// The body is bright cyan near the rim and cools toward the torn ends.
	vec3 band_rgb = mix(band_color.rgb, mid_color.rgb, smoothstep(0.35, 1.0, band_depth / max(reach, 0.001)) * 0.7) * pulse;
	rgb = band_rgb * band_a + rgb * (1.0 - band_a);
	a = band_a + a * (1.0 - band_a);

	// Rim: smooth on the outside, never eaten by the noise. Near-white on the front edge.
	float rim_pos = clamp(back / max(rim_w, 0.001), 0.0, 1.0);
	float rim_mask = inside * (1.0 - smoothstep(rim_w - edge_softness, rim_w, back));
	float rim_a = rim_mask * mix(core_color.a, rim_color.a, rim_pos);
	vec3 rim_rgb = mix(core_color.rgb, rim_color.rgb, rim_pos * rim_pos);
	rgb = rim_rgb * rim_a + rgb * (1.0 - rim_a);
	a = rim_a + a * (1.0 - rim_a);

	// Halo: distance to the head (rim and body), ahead of it and past the tips included. It is
	// exactly zero at halo_width, which stays inside the plane.
	float dx = max(abs(local_xz.x) - half_width, 0.0);
	float dy = back < 0.0 ? -back : max(back - (rim_w + band_w), 0.0);
	float falloff = 1.0 - smoothstep(0.0, max(halo_width, 0.001), length(vec2(dx, dy)));
	float halo = halo_strength * falloff * falloff;

	ALBEDO = (rgb + halo_color.rgb * halo * (1.0 - a)) * fade;
	ALPHA = clamp(a, 0.0, 1.0) * fade;
}
