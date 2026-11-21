shader_type spatial;
// Eye glow of the boss while it curls up for a roll: a small sphere at each eye, drawn as a
// see-through flat colour that is strongest in the middle and fades towards its silhouette, so
// there is no hard outline and the head texture stays visible through it. Blended additively so
// it still reads as a glow over the red cheek slit it sits in.
// glow (per instance) fades it in and out.
render_mode unshaded, blend_add, cull_back, shadows_disabled, depth_draw_never;

// boss_roll_eye in art/palette.md. Alpha is the opacity at the centre at full glow.
uniform vec4 color : source_color = vec4(1.0, 0.165, 0.165, 0.6);
// How fast the opacity falls off from the centre to the silhouette (higher: smaller core).
uniform float core_falloff : hint_range(0.1, 8.0) = 1.5;

// Per-instance, set by CentipedeFx.set_eye_glow while the boss roars (spit, combo, roll).
instance uniform float glow : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = color.rgb;
	ALPHA = color.a * glow * pow(facing, core_falloff);
}
