shader_type spatial;
// Speed lines behind the rolling boss, on the mesh built by RollSpeedLines (art/vfx/
// roll_speed_lines.gd). Every quad is a line laid along the node's -Z; its width is opened here,
// across the line and towards the camera, so the line stays a thin even stroke from any angle.
// Each line streams backwards in a loop: it slides away from the body and fades in and out, with
// its own phase taken from UV2.x. The front end never moves towards the body. No outline.
// intensity (per instance) shows or hides all lines.
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never, skip_vertex_transform;

// boss_roll_line in art/palette.md. Alpha is the opacity of a line at full intensity.
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.8);
// Width of a line in metres at model scale 1; it is multiplied by the model's scale.
uniform float line_width = 0.012;
// How far a line slides backwards over one loop, in metres, and loops per second.
uniform float slide_amount = 0.35;
uniform float slide_speed = 2.2;
// How much a line's tail stretches out over one loop (fraction of its length).
uniform float stretch_amount : hint_range(0.0, 1.0) = 0.4;
// How strongly the opacity flickers on top of the loop fade (0: steady).
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.3;
uniform float flicker_speed = 11.0;

// Per-instance, driven over time by the roll (AnimationPlayer for now).
instance uniform float intensity : hint_range(0.0, 1.0) = 1.0;

varying float v_fade;

void vertex() {
	float rand = UV2.x;
	float line_len = UV2.y;
	float cycle = fract(TIME * slide_speed + rand);
	// Slide the whole line back, and the tail a bit further so the line stretches as it goes.
	float back = cycle * slide_amount + UV.x * cycle * stretch_amount * line_len;
	vec3 local = VERTEX + vec3(0.0, 0.0, -back);

	vec3 pos = (MODELVIEW_MATRIX * vec4(local, 1.0)).xyz;
	vec3 axis = normalize((MODELVIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
	vec3 to_cam = normalize(-pos);
	vec3 side = cross(axis, to_cam);
	// Looking straight down the line: any direction across it works, take the view's up.
	if (length(side) < 0.05) {
		side = vec3(0.0, 1.0, 0.0);
	}
	// The boss is scaled up, so the width follows the model scale to stay as thick as the body.
	float model_scale = length(MODEL_MATRIX[0].xyz);
	pos += normalize(side) * UV.y * line_width * model_scale * 0.5;
	VERTEX = pos;

	float flicker = 1.0 - flicker_amount * (0.5 + 0.5 * sin((TIME * flicker_speed + rand * 7.0) * TAU));
	v_fade = sin(cycle * PI) * flicker;
}

void fragment() {
	// Solid at the front end, thinning out towards the tail.
	float along = 1.0 - smoothstep(0.35, 1.0, UV.x);
	ALBEDO = color.rgb;
	ALPHA = color.a * intensity * v_fade * along;
}
