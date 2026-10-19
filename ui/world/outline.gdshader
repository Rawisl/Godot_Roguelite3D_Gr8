shader_type spatial;
// Drawn as a material_overlay: only the edges that turn away from the camera glow,
// so the model keeps its own colours and details. No hull, because the tower models
// need cull_disabled and a grown hull would cover their front faces.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 outline_color : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform float edge_start : hint_range(0.0, 1.0) = 0.514;
uniform float edge_end : hint_range(0.0, 1.0) = 1;
uniform float strength : hint_range(0.0, 2.0) = 0.3;
// A faint tint over the whole tower so the hover still reads on faces that look at the camera.
uniform float fill : hint_range(0.0, 0.5) = 0.8;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = smoothstep(edge_start, edge_end, 1.0 - facing);
	ALBEDO = outline_color.rgb;
	ALPHA = clamp(fill + edge * strength, 0.0, 1.0);
}