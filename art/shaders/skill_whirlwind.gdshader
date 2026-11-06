shader_type spatial;
// Whirlwind: one blade sweep around the commander, drawn like a brush slash. The head is a
// wide solid white area; behind it the slash breaks into curved streaks of different widths
// and lengths that narrow to points and fade out along the circle. No outline at the radius.
// Animated from SkillFxManager (progress, fade), so it follows x2 / x3 and holds on Pause.
// Depth test stays on so walls, towers and units hide it.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

#include "res://art/shaders/slash_common.gdshaderinc"

// skill_slash_core and skill_slash_edge in art/palette.md.
uniform vec4 core_color : source_color = vec4(0.95, 0.97, 1.0, 1.0);
uniform vec4 tail_color : source_color = vec4(0.61, 0.77, 0.94, 0.8);
// Part of the radius the slash covers, measured inward from the edge.
uniform float blade_band = 0.65;
// Length of the tail behind the head, as a part of one turn.
uniform float tail = 0.45;
// Part of the tail, from the head, that is solid white, and how long the solid part takes to fade.
uniform float head_part = 0.12;
uniform float head_fade = 0.25;
// How far the inner side of the head trails the outer side, as a part of one turn.
uniform float head_slant = 0.04;
// Soft fill under the streaks, strongest at the head and gone by the end of the tail, so the
// head runs into the tail instead of standing apart.
uniform float body_alpha = 0.45;
// Part of the tail, at its end, over which everything fades out.
uniform float end_fade = 0.4;
// Streaks per metre across the radius, how much they break up, and the shortest one as a
// part of the tail.
uniform float streak_density = 5.0;
uniform float streak_breakup = 0.3;
uniform float streak_min_length = 0.25;
uniform float edge_softness = 0.08;
// Sizes are in metres. The plane must be at least 2 x (radius + edge_softness) wide.
instance uniform float radius = 3.0;
// 0 = head at the start angle, 1 = one full turn done.
instance uniform float progress = 0.0;
// 0 hidden, 1 shown.
instance uniform float fade = 1.0;

varying vec2 local_xz;

void vertex() {
	local_xz = VERTEX.xz;
}

void fragment() {
	float r = length(local_xz);
	float inner = radius * (1.0 - blade_band);
	float t = clamp((r - inner) / max(radius - inner, 0.001), 0.0, 1.0);
	// Angle from the plane's +X axis, 0..1 round the circle.
	float a = fract(atan(local_xz.y, local_xz.x) / TAU + 1.0);
	float behind = progress - a - head_slant * (1.0 - t);
	// 0 at the head, 1 at the end of the tail.
	float k = behind / max(tail, 0.001);
	float on_tail = step(0.0, behind) * step(k, 1.0);
	float outside = 1.0 - smoothstep(radius - edge_softness, radius, r);
	float inside = smoothstep(0.0, 0.12, t);
	float solid = 1.0 - smoothstep(head_part, head_part + head_fade, k);
	float streak = slash_streaks(r * streak_density, k, behind * TAU * max(r, 0.001),
		streak_min_length, streak_breakup);
	float alpha = on_tail * outside * inside * max(max(solid, streak), body_alpha * (1.0 - k) * (1.0 - k))
		* (1.0 - smoothstep(1.0 - end_fade, 1.0, k));
	ALBEDO = mix(core_color.rgb, tail_color.rgb, smoothstep(0.3, 1.0, k));
	ALPHA = clamp(alpha * mix(core_color.a, tail_color.a, k), 0.0, 1.0) * fade;
}
