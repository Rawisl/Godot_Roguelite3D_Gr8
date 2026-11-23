shader_type spatial;
// Soft halo behind each eye of the boss while it roars. A camera-facing quad that is drawn on top
// of the head (no depth test), so the glow stays readable from the zoomed-out game camera even
// when the head turns away or the eye is only a few pixels wide. Added over the scene, brightest
// in the middle and fading to nothing at the quad edge.
// glow (per instance) fades it in and out.
render_mode unshaded, blend_add, depth_test_disabled, cull_disabled, shadows_disabled;

// boss_roll_eye_halo in art/palette.md. Alpha is the strength at the centre at full glow.
uniform vec4 color : source_color = vec4(1.0, 0.55, 0.12, 0.8);
// How fast the strength falls off from the centre to the quad edge (higher: tighter core).
uniform float falloff : hint_range(0.1, 8.0) = 1.6;

// Per-instance, set by CentipedeFx.set_eye_glow together with the eye sphere.
instance uniform float glow : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	// Face the camera but keep the node's scale, so the quad size follows the boss's model scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = clamp(length(UV * 2.0 - 1.0), 0.0, 1.0);
	float soft = pow(1.0 - smoothstep(0.0, 1.0, d), falloff);
	ALBEDO = color.rgb;
	ALPHA = color.a * glow * soft;
}
