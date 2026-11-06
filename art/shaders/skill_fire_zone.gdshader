shader_type spatial;
// Firebomb burn area: a disc of drifting flame with a brighter rim at the radius.
// Amber with a noise texture, no hatching, so it never reads as a boss telegraph (red, hatched).
// Animated with game_time from SkillFxManager instead of TIME, so it follows x2 / x3 and holds
// on Pause. The flicker is a slow brightness swell, capped at 3 per second.
// Depth test stays on so walls, towers and units hide it.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

// skill_fire_core, skill_fire_rim and skill_fire_dark in art/palette.md.
uniform vec4 core_color : source_color = vec4(1.0, 0.70, 0.28, 0.55);
uniform vec4 rim_color : source_color = vec4(1.0, 0.83, 0.42, 0.9);
uniform vec4 dark_color : source_color = vec4(0.78, 0.33, 0.12, 0.35);
// Sizes are in metres. The plane must be at least 2 x (radius + edge_softness) wide.
uniform float rim_width = 0.15;
uniform float edge_softness = 0.1;
uniform float noise_scale = 1.4;
uniform float drift_speed = 0.35;
// Brightness swell. Never above 3 per second.
uniform float flicker_hz = 1.2;
uniform float flicker_amount = 0.2;
instance uniform float radius = 2.5;
// Seconds of game time since the fire started.
instance uniform float game_time = 0.0;
// 0 with reduced flashing on, 1 otherwise.
instance uniform float flicker = 1.0;
// 0 hidden, 1 shown.
instance uniform float fade = 1.0;

varying vec2 local_xz;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 s = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, s.x), mix(c, d, s.x), s.y);
}

void vertex() {
	local_xz = VERTEX.xz;
}

void fragment() {
	float r = length(local_xz);
	float inside = 1.0 - smoothstep(radius - edge_softness, radius, r);
	vec2 p = local_xz * noise_scale;
	float n = value_noise(p + vec2(0.0, game_time * drift_speed)) * 0.6
		+ value_noise(p * 2.1 - vec2(game_time * drift_speed * 1.3, 0.0)) * 0.4;
	float band = abs(r - radius + rim_width * 0.5) - rim_width * 0.5;
	float rim = 1.0 - smoothstep(0.0, edge_softness, band);
	float hz = min(flicker_hz, 3.0);
	float swell = 1.0 - flicker * flicker_amount * (0.5 + 0.5 * sin(game_time * TAU * hz));
	vec3 fill = mix(dark_color.rgb, core_color.rgb, n);
	float fill_alpha = inside * mix(dark_color.a, core_color.a, n);
	ALBEDO = mix(fill, rim_color.rgb, rim);
	ALPHA = clamp(max(fill_alpha, rim * rim_color.a), 0.0, 1.0) * swell * fade;
}
