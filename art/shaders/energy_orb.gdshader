shader_type spatial;
// Energy orb floating over the heal station: a bright core, a brighter rim and a slow swirl
// moving through it. Greys out as the station's HP store runs dry. Nothing blinks.
render_mode unshaded, shadows_disabled;

uniform vec4 core_color : source_color = vec4(0.72, 0.97, 0.76, 1.0);
uniform vec4 rim_color : source_color = vec4(0.38, 0.86, 0.5, 1.0);
uniform vec4 empty_color : source_color = vec4(0.46, 0.49, 0.52, 1.0);
// Turns per second of the swirl.
uniform float swirl_speed = 0.3;
uniform float swirl_strength = 0.14;
// 1 full store, 0 empty. Set per station by HealFxManager.
instance uniform float store = 1.0;

varying vec3 dir;

void vertex() {
	dir = normalize(VERTEX);
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float t = TIME * swirl_speed * 6.2831853;
	float swirl = sin(dir.x * 7.0 + t) * sin(dir.y * 6.0 - t * 0.7) * sin(dir.z * 7.0 + t * 0.5);
	vec3 col = mix(core_color.rgb, rim_color.rgb, fres) + swirl * swirl_strength + fres * 0.1;
	ALBEDO = mix(empty_color.rgb, col, clamp(store, 0.0, 1.0));
}
