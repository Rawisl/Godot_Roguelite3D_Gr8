shader_type spatial;
// Sword Wave: a crescent of sword energy flying flat over the ground, drawn like a brush slash.
// The head is a solid white crescent with sharp tips; behind it straight streaks of different
// widths and lengths run back along the flight line, narrow to points and fade out. Streaks
// near the tips are shorter.
// Local -Z is the flight direction, local X runs across the wave.
// SkillFxManager moves the plane and sets tail_scale and fade, so it follows x2 / x3 and
// holds on Pause. Depth test stays on so walls, towers and units hide it.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

#include "res://art/shaders/slash_common.gdshaderinc"

// skill_slash_core and skill_slash_edge in art/palette.md.
uniform vec4 core_color : source_color = vec4(0.95, 0.97, 1.0, 1.0);
uniform vec4 tail_color : source_color = vec4(0.61, 0.77, 0.94, 0.8);
// Sizes are in metres. SkillFxManager sizes the plane from bulge and tail_length.
// How far the middle of the crescent leads the tips.
uniform float bulge = 0.9;
// Thickness of the solid white crescent in the middle. It thins to a point at each tip.
uniform float head_thickness = 0.7;
// Part of the head, at its back, over which it fades into the streaks.
uniform float head_fade = 0.6;
// Length of the longest streak behind the front edge.
uniform float tail_length = 3.5;
// Soft fill under the streaks, strongest at the head and gone by the end of the tail, so the
// head runs into the tail instead of standing apart.
uniform float body_alpha = 0.45;
// Part of the tail, at its end, over which everything fades out.
uniform float end_fade = 0.4;
// Streaks per metre across the wave, how much they break up, and the shortest one as a
// part of the tail.
uniform float streak_density = 5.0;
uniform float streak_breakup = 0.3;
uniform float streak_min_length = 0.25;
uniform float edge_softness = 0.04;
// Half the width of the wave, tip to tip.
instance uniform float half_width = 1.5;
// 0..1: the tail grows to full length as the wave leaves the commander.
instance uniform float tail_scale = 1.0;
// 0 hidden, 1 shown.
instance uniform float fade = 1.0;

varying vec2 local_xz;

void vertex() {
	local_xz = VERTEX.xz;
}

void fragment() {
	float u = local_xz.x / max(half_width, 0.001);
	float shape = max(1.0 - u * u, 0.0);
	// Distance behind the front edge (negative in front of it).
	float back = bulge * shape + local_xz.y;
	float front = smoothstep(0.0, edge_softness, back) * step(abs(u), 1.0);
	float head = back / max(head_thickness * shape, 0.001);
	float solid = 1.0 - smoothstep(1.0 - head_fade, 1.0, head);
	// 0 at the front edge, 1 at the end of the longest streak.
	float k = back / max(tail_length * tail_scale, 0.001);
	// The same, scaled so the tail gets shorter toward the tips.
	float k_tip = k / max(sqrt(shape), 0.05);
	float streak = slash_streaks(local_xz.x * streak_density, k_tip, back, streak_min_length, streak_breakup);
	float body = body_alpha * pow(clamp(1.0 - k_tip, 0.0, 1.0), 2.0);
	float alpha = front * max(max(solid, streak), body) * (1.0 - smoothstep(1.0 - end_fade, 1.0, k));
	ALBEDO = mix(core_color.rgb, tail_color.rgb, smoothstep(0.3, 1.0, k));
	ALPHA = clamp(alpha * mix(core_color.a, tail_color.a, k), 0.0, 1.0) * fade;
}
