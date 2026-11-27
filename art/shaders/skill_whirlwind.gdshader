shader_type spatial;
// Whirlwind: a ring of three spinning blades round the commander, drawn in four layers per blade.
// 1. Wisp: a thin broken arc just outside the blade.
// 2. Glow: a soft cyan haze hugging the outer edge, under the shard.
// 3. Shard: a broad flat panel whose tail is cut off at a hard diagonal.
// 4. Rim: a bright leading edge on the outer side, sharp at the tip and tapering along the arc.
// A faint glow sits under the blades at the centre. The blades start small, grow to the full
// radius, spin counter-clockwise seen from above, then the side blades leave first and the main
// blade thins and fades. The outer edge of a full-size blade is exactly at radius.
// Local +X is the start direction of the main blade.
// SkillFxManager sets radius, age_ms, fade and flicker, so it follows x2 / x3 and holds on Pause.
// It also draws two thinner rings inside and outside the main one with the ring_* values.
// Depth test stays on so walls, towers and units hide it.
// Premultiplied alpha lets the blades blend normally while the glow only adds light.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_premul_alpha;

// The skill palettes are in art/palette.md (Skill chỉ huy); these defaults are the Frost one.
uniform vec4 core_color : source_color = vec4(0.914, 0.988, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.663, 0.914, 0.969, 1.0);
uniform vec4 band_color : source_color = vec4(0.161, 0.725, 0.910, 1.0);
uniform vec4 shard_color : source_color = vec4(0.522, 0.859, 0.949, 1.0);
uniform vec4 mid_color : source_color = vec4(0.141, 0.475, 0.616, 1.0);
uniform vec4 tail_color : source_color = vec4(0.090, 0.224, 0.306, 1.0);
// Timeline in milliseconds: the blades grow until form_ms, spin at full size until unravel_ms,
// then break up and are gone at end_ms. SkillFxManager reads end_ms as the life of the effect.
uniform float form_ms = 83.0;
uniform float unravel_ms = 250.0;
uniform float end_ms = 400.0;
// Degrees per second.
uniform float spin_speed = 1800.0;
// Size of the blades at the cast, as a part of radius.
uniform float start_radius = 0.29;
// Strength of the main blade and of the two side blades.
uniform vec3 blade_weights = vec3(1.0, 0.55, 0.3);
// Length of the main blade and of the side blades, as a part of one turn.
uniform float main_arc = 0.42;
uniform float side_arc = 0.28;
// Width of the shard panel and of the rim, as a part of the blade radius.
uniform float panel_width = 0.32;
uniform float rim_width = 0.07;
// Strength of the glow along the outer edge.
uniform float rim_glow = 0.4;
// Where the wisp arc sits, as a part of the blade radius. The plane must reach past it.
uniform float wisp_offset = 1.12;
uniform float wisp_alpha = 0.35;
// Strength of the glow under the blades.
uniform float centre_glow = 0.22;
// Overall brightness. The Compatibility renderer has no HDR, so a high value burns to white.
uniform float brightness = 1.6;
// Sizes are in metres. The plane must be at least 2 x radius x wisp_offset wide.
instance uniform float radius = 3.0;
// Milliseconds since the cast, on game time.
instance uniform float age_ms = 0.0;
// 0 hidden, 1 shown.
instance uniform float fade = 1.0;
// 1 normal, 0 when flashing is reduced: no bright burst at the cast and no extra brightness.
instance uniform float flicker = 1.0;
// Extra rings reuse the shader: the defaults draw the main ring. The ring radius is radius x
// ring_scale, the plane must be sized for it.
instance uniform float ring_scale = 1.0;
// Turn offset in radians and spin speed as a multiple of spin_speed.
instance uniform float ring_phase = 0.0;
instance uniform float ring_spin = 1.0;
// Multiplies the strength of the whole ring, and of its centre glow.
instance uniform float ring_weight = 1.0;
instance uniform float ring_centre = 1.0;
// The ring starts this many milliseconds after age_ms starts counting.
instance uniform float ring_delay_ms = 0.0;

varying vec2 local_xz;

void vertex() {
	local_xz = VERTEX.xz;
}

// Random value at a whole step along the arc. k keeps the three blades apart.
float ring_value(float step_index, float k, float mul, float seed) {
	return fract(sin(step_index * mul + k) * seed);
}

void fragment() {
	float ms = clamp(age_ms - ring_delay_ms, 0.0, end_ms);
	// A delayed ring stays hidden until its own start.
	float started = step(ring_delay_ms, age_ms);
	vec2 p = local_xz / max(radius * ring_scale, 0.001);
	float r = length(p);
	// Grows counter-clockwise seen from above.
	float a = atan(-p.y, p.x);
	float grow = smoothstep(0.0, form_ms, ms);
	float R = mix(start_radius, 1.0, grow);
	float spin = ms * 0.001 * radians(spin_speed) * ring_spin + ring_phase;
	float fade_all = 1.0 - smoothstep(end_ms - 70.0, end_ms, ms);
	// Main blade first; the side blades leave before the unravel and the main one thins.
	vec3 w = blade_weights;
	w.y *= 1.0 - smoothstep(unravel_ms - 20.0, unravel_ms + 40.0, ms);
	w.z *= 1.0 - smoothstep(unravel_ms - 50.0, unravel_ms + 10.0, ms);
	w.x *= smoothstep(0.0, 40.0, ms + 40.0);
	w.y *= smoothstep(0.0, 40.0, ms);
	w.z *= smoothstep(0.0, 40.0, ms - 10.0);
	float thin = mix(1.0, 0.35, smoothstep(unravel_ms, end_ms - 20.0, ms));
	float aa = max(fwidth(r), 0.0001) * 1.5;

	// Centre glow under the blades. It bursts out in the first 60 ms and is off without flicker.
	float glow_a = centre_glow * ring_centre * flicker * (1.0 - smoothstep(0.0, R * 0.95, r))
		* smoothstep(0.0, 60.0, ms) * (1.0 - smoothstep(unravel_ms, end_ms - 60.0, ms));
	vec4 acc = vec4(mix(mid_color.rgb, tail_color.rgb, clamp(r / max(R, 0.001), 0.0, 1.0)) * glow_a, glow_a);

	for (int k = 2; k >= 0; k--) {
		float wi = w[k];
		if (wi <= 0.001) {
			continue;
		}
		float kf = float(k);
		float head = spin + kf * TAU / 3.0 + kf * 0.35;
		// 0 at the head, grows towards the tail.
		float behind = mod(head - a + 10.0 * TAU, TAU);
		// The arc length leaves gaps between the blades.
		float s = behind / (TAU * mix(main_arc, side_arc, kf * 0.5));
		if (s > 1.0) {
			continue;
		}
		float Ri = R * (1.0 - 0.06 * kf);
		// 0 on the outer edge, grows inwards.
		float depth = Ri - r;
		// Value noise along the arc: breaks up the inner edge and the wisps.
		float na = s * 9.0 + kf * 3.1;
		float nz = mix(ring_value(floor(na), kf, 12.9898, 43758.5), ring_value(floor(na) + 1.0, kf, 12.9898, 43758.5),
			fract(na) * fract(na) * (3.0 - 2.0 * fract(na)));
		float nb = s * 23.0 + kf * 7.7;
		float nz2 = mix(ring_value(floor(nb), kf, 78.233, 12543.3), ring_value(floor(nb) + 1.0, kf, 78.233, 12543.3), fract(nb));

		// Thin wisp arc just outside the blade.
		float wisp_w = (0.012 + 0.01 * (1.0 - s)) / 0.62;
		float wisp_k = (1.0 - smoothstep(wisp_w, wisp_w + aa, abs(r - Ri * wisp_offset)))
			* (1.0 - smoothstep(0.2, 0.75, s)) * wisp_alpha * wi * smoothstep(0.35, 0.6, nz2);
		vec3 wisp_rgb = mix(rim_color.rgb, mix(mid_color.rgb, tail_color.rgb, clamp(s * 2.0 - 1.0, 0.0, 1.0)), clamp(s * 2.0, 0.0, 1.0));

		// Broad flat shard panel with a hard diagonal cut at its tail.
		float pw = panel_width * Ri * thin * max(wi, 0.35) * (0.75 + 0.5 * nz);
		// Painterly inner edge.
		float soft = aa + 0.025 * Ri;
		float cut = mix(0.42, 0.22, clamp(depth / max(pw, 0.001), 0.0, 1.0));
		float panel = (1.0 - smoothstep(cut - 0.01, cut, s)) * smoothstep(-aa, 0.0, depth)
			* (1.0 - smoothstep(pw - soft, pw, depth)) * smoothstep(0.0, 0.03, s);
		float panel_k = panel * 0.95 * (0.55 + 0.45 * wi) * mix(1.0, 0.65, clamp(s / max(cut, 0.001), 0.0, 1.0));
		// Soft glow hugging the rim, under the panel.
		float glow_k = exp(-abs(depth + 0.01 * Ri) / (0.06 * Ri)) * rim_glow * wi
			* smoothstep(0.0, 0.1, s) * (1.0 - smoothstep(0.3, 0.9, s));
		vec3 panel_rgb = mix(mix(rim_color.rgb, shard_color.rgb, 0.5), band_color.rgb, clamp(depth / max(pw, 0.001), 0.0, 1.0) * 0.8);

		// Bright leading rim along the outer edge: sharp tip, tapered tail.
		float rw = rim_width * Ri * smoothstep(0.0, 0.12, s) * (1.0 - smoothstep(0.35, 1.0, s)) * thin;
		float rim_k = smoothstep(-aa, 0.0, depth + rw * 0.2) * (1.0 - smoothstep(rw - aa, rw, depth))
			* clamp(rw * 250.0, 0.0, 1.0) * wi;
		vec3 rim_rgb = mix(core_color.rgb, rim_color.rgb, clamp(depth / max(rw, 0.001), 0.0, 1.0));

		acc = vec4(wisp_rgb * wisp_k, wisp_k) + acc * (1.0 - wisp_k);
		acc = vec4(band_color.rgb * glow_k, glow_k) + acc * (1.0 - glow_k);
		acc = vec4(panel_rgb * panel_k, panel_k) + acc * (1.0 - panel_k);
		acc = vec4(rim_rgb * rim_k, rim_k) + acc * (1.0 - rim_k);
	}
	acc *= fade_all * fade * ring_weight * started;
	// acc is already premultiplied, so the colour is not divided by its alpha.
	ALBEDO = acc.rgb * mix(1.0, brightness, flicker);
	ALPHA = clamp(acc.a, 0.0, 1.0);
}
