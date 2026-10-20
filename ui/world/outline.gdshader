shader_type spatial;
// Drawn as a material_overlay: the edges that turn away from the camera are painted over
// in the outline colour. Mixed, not added, so the glow still shows on white towers.
// No hull, because the tower models need cull_disabled and a grown hull would cover
// their front faces.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 outline_color : source_color = vec4(1.0, 0.72, 0.1, 1.0);
uniform float edge_start : hint_range(0.0, 1.0) = 0.25;
uniform float edge_end : hint_range(0.0, 1.0) = 0.6;
uniform float strength : hint_range(0.0, 2.0) = 1.0;
// Tint over the whole tower; keep it low so the model keeps its own colours.
uniform float fill : hint_range(0.0, 0.5) = 0.0;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = smoothstep(edge_start, edge_end, 1.0 - facing);
	ALBEDO = outline_color.rgb;
	ALPHA = clamp(fill + edge * strength, 0.0, 1.0);
}