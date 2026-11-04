shader_type spatial;
// Healing pool of the heal station: bright in the middle, a slow swirl turning across it.
// The colour follows how much HP the station still holds, so a station running dry fades
// toward grey water. Unshaded, so it reads as glowing whatever the light.
render_mode unshaded, shadows_disabled;

uniform vec4 rim_color : source_color = vec4(0.5, 0.86, 0.94, 1.0);
uniform vec4 core_color : source_color = vec4(0.86, 0.98, 1.0, 1.0);
uniform vec4 empty_color : source_color = vec4(0.32, 0.38, 0.42, 1.0);
// Radius of the pool in the model, in metres.
uniform float pool_radius = 0.69;
// Turns per second of the swirl. Slow on purpose: it moves, it never blinks.
uniform float swirl_speed = 0.12;
uniform float swirl_arms = 3.0;
uniform float swirl_strength = 0.1;
// 1 full store, 0 empty. Set per station by HealFxManager. The station's other surfaces use
// toon_dither, whose dither_alpha takes instance slot 0, so this one takes slot 1.
instance uniform float store : instance_index(1) = 1.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float r = clamp(length(local_pos.xz) / pool_radius, 0.0, 1.0);
	float a = atan(local_pos.z, local_pos.x);
	float swirl = sin(a * swirl_arms + r * 7.0 - TIME * swirl_speed * 6.2831853) * 0.5 + 0.5;
	vec3 col = mix(core_color.rgb, rim_color.rgb, smoothstep(0.0, 0.9, r));
	col += swirl * swirl_strength * (1.0 - 0.5 * r);
	ALBEDO = mix(empty_color.rgb, col, 0.25 + 0.75 * clamp(store, 0.0, 1.0));
}
