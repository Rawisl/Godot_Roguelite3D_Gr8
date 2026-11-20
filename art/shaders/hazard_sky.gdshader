shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, fog_disabled, skip_vertex_transform;
// Sky around the Hazard Trial island: a sphere kept centred on the camera. Below the horizon it
// shows the top-down picture of the cloud vortex, straight down in the middle of the picture.
// Above the horizon the picture is mirrored across the horizon, so its outer clouds rise as a
// band from the horizon, and the band fades into a gradient that darkens towards the top.

uniform sampler2D sky_image : source_color, filter_linear, repeat_disable;
// Brightness of the whole sky.
uniform float brightness : hint_range(0.0, 1.5) = 0.9;
// Angle from straight down, in degrees, where the edge of the picture would land. Over 90 puts
// the horizon inside the picture's outer clouds and keeps the edge out of sight.
uniform float rim_angle : hint_range(30.0, 120.0) = 100.0;
// Middle of the vortex in the picture, in UV.
uniform vec2 image_center = vec2(0.5, 0.5);
// Part of the picture's radius, at its edge, that fades into horizon_color.
uniform float horizon_blend : hint_range(0.0, 0.5) = 0.1;
// Average purple of the picture's outer ring: the bottom of the gradient above the horizon and
// the sky past the picture's edge.
uniform vec3 horizon_color : source_color = vec3(0.337, 0.298, 0.722);
// Deep purple at the top of the sky.
uniform vec3 zenith_color : source_color = vec3(0.165, 0.086, 0.376);
// Degrees above the horizon where the gradient reaches zenith_color.
uniform float zenith_angle : hint_range(5.0, 90.0) = 45.0;
// Degrees above the horizon where the mirrored band of clouds has faded out.
uniform float cloud_band_height : hint_range(1.0, 45.0) = 15.0;

// Direction from the camera in room space: the room's -Z (top of the screen) is the top of the picture.
varying vec3 sky_dir;

void vertex() {
	sky_dir = VERTEX;
	// The sphere follows the camera, so it never comes closer and never shows a seam.
	vec3 world_pos = INV_VIEW_MATRIX[3].xyz + mat3(MODEL_MATRIX) * VERTEX;
	VERTEX = (VIEW_MATRIX * vec4(world_pos, 1.0)).xyz;
}

// The picture seen at from_down radians from straight down, towards flat_dir on the ground.
// Equidistant around straight down, so there is no seam and no angle around the vertical.
vec3 vortex_picture(float from_down, vec2 flat_dir) {
	float r = from_down / radians(rim_angle);
	float flat_len = length(flat_dir);
	vec2 p = flat_len > 0.00001 ? flat_dir / flat_len * r : vec2(0.0);
	// The picture is 2:1 because the round vortex was painted at a slant; half of it on each axis
	// spreads the vortex back to a circle.
	vec3 col = texture(sky_image, image_center + 0.5 * p).rgb;
	return mix(col, horizon_color, smoothstep(1.0 - horizon_blend, 1.0, r));
}

void fragment() {
	vec3 dir = normalize(sky_dir);
	// 0 straight down, PI / 2 at the horizon, PI straight up.
	float from_down = acos(clamp(-dir.y, -1.0, 1.0));
	// Above the horizon, the same angle below it: the picture mirrored, meeting itself at the horizon.
	vec3 picture = vortex_picture(min(from_down, PI - from_down), dir.xz);
	// 0 at and below the horizon.
	float above = max(from_down - PI * 0.5, 0.0);
	float t = clamp(above / radians(zenith_angle), 0.0, 1.0);
	// Darkens quickly just above the band, then settles towards the top.
	vec3 sky = mix(horizon_color, zenith_color, 1.0 - (1.0 - t) * (1.0 - t));
	// The whole lower half is the picture; the band of mirrored clouds fades out going up.
	float band = 1.0 - smoothstep(0.0, radians(cloud_band_height), above);
	ALBEDO = mix(sky, picture, band) * brightness;
}
