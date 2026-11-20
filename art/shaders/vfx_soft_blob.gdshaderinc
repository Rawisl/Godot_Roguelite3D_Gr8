// Shared body of the soft blob particle shaders (vfx_soft_blob_add / vfx_soft_blob_mix).
// A round, soft-edged blob on a camera-facing quad (QuadMesh, size 1 x 1), coloured by the
// particle colour (CPUParticles3D color / color_ramp). A little noise breaks up the edge so the
// blobs do not read as perfect discs. No outline.
// cut_fraction hides the particle for the first part of its life: the poison spit emits from a
// virtual cone tip behind the mouth, and this keeps the stretch inside the head invisible.

// Size of the quad in metres (the particle scale multiplies it).
uniform float size = 0.07;
// 0: hard disc, 1: fades all the way from the centre to the edge.
uniform float softness : hint_range(0.0, 1.0) = 0.6;
// How much the edge is pushed in and out by noise.
uniform float noise_amount : hint_range(0.0, 1.0) = 0.2;
// Blend of a pale hot centre into the particle colour (0: none).
uniform float hot_core : hint_range(0.0, 1.0) = 0.0;
// boss_spit_core_hot in art/palette.md.
uniform vec4 hot_color : source_color = vec4(0.894, 1.0, 0.541, 1.0);
// Share of the particle's life during which it stays fully hidden.
uniform float cut_fraction : hint_range(0.0, 1.0) = 0.0;

varying float life;
varying float seed;

void vertex() {
	life = INSTANCE_CUSTOM.y;
	seed = INSTANCE_CUSTOM.x;
	// Billboard: keep the particle's position and scale but face the camera.
	float scale = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale, INV_VIEW_MATRIX[1] * scale, INV_VIEW_MATRIX[2] * scale, MODEL_MATRIX[3]);
	VERTEX *= size;
}

float blob_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float blob_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(blob_hash(i), blob_hash(i + vec2(1.0, 0.0)), u.x),
		mix(blob_hash(i + vec2(0.0, 1.0)), blob_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float angle = atan(p.y, p.x);
	float wobble = blob_noise(vec2(angle * 1.6 + seed * 40.0, seed * 17.0)) - 0.5;
	float r = length(p) / max(1.0 + wobble * noise_amount, 0.2);
	float mask = 1.0 - smoothstep(1.0 - softness, 1.0, r);
	float shown = smoothstep(cut_fraction, cut_fraction + 0.03, life);
	ALBEDO = mix(COLOR.rgb, hot_color.rgb, hot_core * (1.0 - smoothstep(0.0, 0.6, r)));
	ALPHA = COLOR.a * mask * shown;
}
