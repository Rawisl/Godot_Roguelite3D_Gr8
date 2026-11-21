shader_type spatial;
// Wind-up glow on a boss scythe blade: a flat-colour shell pushed out along the normals of a
// copy of the blade mesh. Used twice on the same mesh: an ink shell (larger, drawn first) and
// a white shell on top (smaller, next_pass, higher render_priority).
// The shell's back faces only show around the blade's silhouette, so they draw the white rim
// and the ink outline. Its front faces cover the blade itself and are drawn at veil opacity,
// so the blade's own texture stays visible under a light wash.
// The mesh needs smooth normals. glow (per instance) grows the shell and fades it in.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

// boss_slash_core / boss_slash_ink in art/palette.md.
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Opacity of the front faces over the blade (0: rim only, 1: solid).
uniform float veil : hint_range(0.0, 1.0) = 0.25;
// Opacity of the back faces around the silhouette (1: solid rim; set it to veil for a soft
// see-through shell with no outline, as on the boss body after a roll).
uniform float rim : hint_range(0.0, 1.0) = 1.0;
// How far the shell sits out from the blade surface at full glow, in metres.
uniform float inflate = 0.025;
// Flicker of the shell size while glowing: amount in metres and speed in cycles per second.
uniform float pulse_amount = 0.006;
uniform float pulse_speed = 9.0;

// Per-instance, driven over time by the attack (AnimationPlayer for now).
instance uniform float glow : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	float pulse = sin(TIME * pulse_speed * TAU) * pulse_amount;
	VERTEX += NORMAL * (inflate + pulse) * glow;
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a * (FRONT_FACING ? veil : rim) * smoothstep(0.0, 0.2, glow);
}
