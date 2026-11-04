shader_type spatial;
// Beam of healing from a heal station to the commander. Soft bands drift along it toward
// the commander; the ends fade so it does not cut off hard. Nothing blinks.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

// Same green as the heal range ring (heal_ring.tres).
uniform vec4 beam_color : source_color = vec4(0.62, 1.0, 0.68, 1.0);
uniform float band_count = 3.0;
// Bands per second passing any point; kept low so it reads as flow, not flicker.
uniform float band_speed = 1.2;
// How much darker the gaps between bands are than the full colour.
uniform float band_strength = 0.25;
uniform float end_fade = 0.12;
instance uniform float fade = 1.0;

void fragment() {
	// UV.y runs along the beam: 0 at the station, 1 at the commander.
	float v = UV.y;
	float ends = smoothstep(0.0, end_fade, v) * smoothstep(1.0, 1.0 - end_fade, v);
	float bands = 0.5 + 0.5 * sin((v * band_count - TIME * band_speed) * 6.2831853);
	ALBEDO = beam_color.rgb * (1.0 - band_strength * (1.0 - bands));
	ALPHA = ends * fade * 0.9;
}
