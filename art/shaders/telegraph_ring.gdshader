shader_type spatial;
// Telegraph of a boss AoE: a thick red border with a dark outline, diagonal hatching inside so
// the area reads without relying on colour, a solid fill growing from the centre to the edge over
// the wind-up and a countdown arc just inside the border, so the hit time reads without sound.
// Depth test is off so walls, towers and units never hide it. Nothing blinks.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;

// danger and danger_fill in art/palette.md.
uniform vec4 danger_color : source_color = vec4(1.0, 0.176, 0.176, 1.0);
uniform vec4 outline_color : source_color = vec4(0.25, 0.0, 0.0, 1.0);
// Light so the countdown stands out from the red.
uniform vec4 arc_color : source_color = vec4(1.0, 0.92, 0.88, 0.95);
// Sizes are in metres. The plane must be at least 2 x (radius + outline_width) wide.
// Set per telegraph by TelegraphFxManager, so the shared material is never written to.
instance uniform float radius = 3.0;
uniform float border_width = 0.22;
uniform float outline_width = 0.07;
uniform float edge_softness = 0.03;
uniform float hatch_spacing = 0.45;
// Share of each stripe period that is drawn.
uniform float hatch_width = 0.35;
uniform float hatch_alpha = 0.45;
// How far the stripes lean toward outline_color.
uniform float hatch_darken = 0.55;
// Alpha of the area before the fill reaches it, and of the fill itself.
uniform float base_alpha = 0.12;
uniform float fill_alpha = 0.35;
// The countdown arc sits inside the border.
uniform float arc_width = 0.12;
uniform float arc_gap = 0.08;
// 0 at the start of the wind-up, 1 at the hit.
instance uniform float progress = 0.0;
// 0 hidden, 1 shown. Fades out right after the hit.
instance uniform float fade = 1.0;

varying vec2 local_xz;

void vertex() {
	local_xz = VERTEX.xz;
}

float band(float d, float inner, float outer) {
	float a = smoothstep(inner - edge_softness, inner, d);
	float b = 1.0 - smoothstep(outer, outer + edge_softness, d);
	return a * b;
}

void fragment() {
	float r = length(local_xz);
	// Inside the area, border included.
	float inside = 1.0 - smoothstep(radius, radius + edge_softness, r);

	float border = band(r, radius - border_width, radius);
	float outline = band(r, radius, radius + outline_width)
			+ band(r, radius - border_width - outline_width, radius - border_width);

	// Stripes along world Z, so they do not swim when the camera moves. The game camera looks
	// down -X -Z (CameraRig), where they read as a diagonal hazard hatch.
	float stripe = fract(local_xz.x / hatch_spacing);
	float hatch = 1.0 - smoothstep(hatch_width, hatch_width + edge_softness * 2.0, stripe);

	float filled = 1.0 - smoothstep(progress * radius, progress * radius + edge_softness, r);

	// Arc swept clockwise from the top of the screen as the wind-up runs. Screen up on the
	// ground is (-X, -Z) and screen right is (+X, -Z) for the game camera.
	float up = -(local_xz.x + local_xz.y) * 0.7071;
	float right = (local_xz.x - local_xz.y) * 0.7071;
	float angle = fract(atan(right, up) / 6.2831853 + 1.0);
	float arc_outer = radius - border_width - outline_width - arc_gap;
	float arc = band(r, arc_outer - arc_width, arc_outer) * step(angle, progress);

	vec3 color = danger_color.rgb;
	float alpha = inside * max(base_alpha, filled * fill_alpha);
	// Dark stripes, so they still show once the red fill has covered the area.
	float stripes = inside * (1.0 - border) * hatch;
	color = mix(color, outline_color.rgb, stripes * hatch_darken);
	alpha = max(alpha, stripes * hatch_alpha);
	alpha = max(alpha, border * danger_color.a);
	color = mix(color, danger_color.rgb, border);
	// The dark outline keeps the edge readable on light floors and over other red.
	color = mix(color, outline_color.rgb, clamp(outline, 0.0, 1.0));
	alpha = max(alpha, outline * outline_color.a);
	color = mix(color, arc_color.rgb, arc);
	alpha = max(alpha, arc * arc_color.a);
	ALBEDO = color;
	ALPHA = clamp(alpha, 0.0, 1.0) * fade;
}
