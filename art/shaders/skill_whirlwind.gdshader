shader_type spatial;
// Whirlwind: one sweep of the sword, drawn as a ring-shaped trail on a flat plane round the
// commander. The head of the trail sits on local +X, where the sword is; the sword sweeps
// clockwise seen from above, so the trail lies behind it, counter-clockwise from +X.
// - Body: a band from inner_edge out to the radius, brighter towards the outside, fading along
//   the trail from the head to its end.
// - Rim: a bright edge along the outside, white at the head.
// - Glow: a soft haze just outside the rim.
// SkillFxManager turns the plane so +X follows the sword, sets sweep (how much of the turn the
// sword has drawn so far), and fades it out when the swing ends; it also scales the plane while
// the sweep forms. Depth test stays on so walls, towers and units hide it.
// Premultiplied alpha lets the trail blend normally while the glow only adds light.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_premul_alpha;

// The skill palettes are in art/palette.md (Skill chỉ huy); these defaults are the Frost one.
uniform vec4 core_color : source_color = vec4(0.914, 0.988, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.663, 0.914, 0.969, 1.0);
uniform vec4 band_color : source_color = vec4(0.161, 0.725, 0.910, 1.0);
uniform vec4 shard_color : source_color = vec4(0.522, 0.859, 0.949, 1.0);
uniform vec4 mid_color : source_color = vec4(0.141, 0.475, 0.616, 1.0);
uniform vec4 tail_color : source_color = vec4(0.090, 0.224, 0.306, 1.0);
// Longest trail behind the sword, as a part of one turn.
uniform float trail_turns = 0.85;
// How fast the trail fades from the head to its end; higher is a shorter bright part.
uniform float trail_falloff = 1.6;
// Where the band starts, as a part of the radius, and how softly it starts.
uniform float inner_edge = 0.3;
uniform float inner_soft = 0.25;
// Strength of the band at its inner and outer side.
uniform float body_inner = 0.15;
uniform float body_outer = 0.75;
// Width of the bright rim and of the glow outside it, as a part of the radius.
uniform float rim_width = 0.05;
uniform float glow_width = 0.06;
uniform float glow_alpha = 0.45;
// Part of the trail right behind the head that turns white.
uniform float head_length = 0.08;
// How far the glow reaches, as a part of the radius. SkillFxManager sizes the plane from it.
uniform float outer_reach = 1.25;
// Overall brightness. The Compatibility renderer has no HDR, so a high value burns to white.
uniform float brightness = 1.6;
// Sizes are in metres at scale 1.
instance uniform float radius = 3.0;
// Radians of the turn the sword has drawn since this sweep started.
instance uniform float sweep = 0.0;
// 0 hidden, 1 shown.
instance uniform float fade = 1.0;
// 1 normal, 0 when flashing is reduced: no white head and no extra brightness.
instance uniform float flicker = 1.0;
// Strength of this sweep.
instance uniform float weight = 1.0;

varying vec2 local_xz;

void vertex() {
	local_xz = VERTEX.xz;
}

void fragment() {
	float r = length(local_xz) / max(radius, 0.001);
	// Counter-clockwise from +X seen from above, so 0 is the head and it grows along the trail.
	float behind = mod(atan(-local_xz.y, local_xz.x), TAU);
	float drawn = clamp(sweep, 0.0, trail_turns * TAU);
	float along = 1.0 - clamp(behind / max(drawn, 0.001), 0.0, 1.0);
	float in_trail = step(behind, drawn) * smoothstep(0.0, 0.02, behind);
	float strength = pow(along, trail_falloff) * in_trail;

	// Band from the inner edge to the radius, stronger towards the outside.
	float band = smoothstep(inner_edge, inner_edge + inner_soft, r) * (1.0 - smoothstep(1.0, 1.0 + rim_width, r));
	float body_k = band * mix(body_inner, body_outer, smoothstep(inner_edge, 1.0, r)) * strength;
	vec3 body_rgb = mix(mix(tail_color.rgb, mid_color.rgb, along), mix(band_color.rgb, shard_color.rgb, along), along);

	float rim_k = exp(-abs(r - 1.0) / max(rim_width, 0.001)) * mix(0.35, 1.0, along) * in_trail * smoothstep(0.0, 0.15, along);
	float head = smoothstep(1.0 - head_length, 1.0, along) * flicker;
	vec3 rim_rgb = mix(rim_color.rgb, core_color.rgb, head);

	float glow_k = exp(-max(r - 1.0, 0.0) / max(glow_width, 0.001)) * step(1.0, r) * glow_alpha * strength;

	vec4 acc = vec4(body_rgb * body_k, body_k);
	acc = vec4(band_color.rgb * glow_k, glow_k) + acc * (1.0 - glow_k);
	rim_k = clamp(rim_k, 0.0, 1.0);
	acc = vec4(rim_rgb * rim_k, rim_k) + acc * (1.0 - rim_k);
	acc *= fade * weight;
	// acc is already premultiplied, so the colour is not divided by its alpha.
	ALBEDO = acc.rgb * mix(1.0, brightness, flicker);
	ALPHA = clamp(acc.a, 0.0, 1.0);
}
