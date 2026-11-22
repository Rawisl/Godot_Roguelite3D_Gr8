shader_type spatial;
// Poison pool on the floor after the boss's spit, on the fan built by PoisonPoolMesh
// (art/vfx/poison_pool_mesh.gd). Noise breaks the fan into ragged puddles: a dark green body,
// a bright lime rim along each puddle's edge and small pale bubbles that pop in and out. No ink
// outline. spread (per instance) grows every puddle from its own centre out to its edge (the
// noise threshold drops from seed_level to its full-coverage value); opacity fades them and
// shrinks them back into smaller pools.
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;

// boss_spit_pool_core / _rim / _bubble in art/palette.md.
uniform vec4 core_color : source_color = vec4(0.122, 0.549, 0.078, 0.85);
uniform vec4 rim_color : source_color = vec4(0.549, 1.0, 0.18, 0.95);
uniform vec4 bubble_color : source_color = vec4(0.894, 1.0, 0.541, 1.0);
// Noise frequency, in cycles per metre.
uniform float noise_scale = 1.8;
// Share of the fan covered by puddles at full opacity (0..1).
uniform float coverage : hint_range(0.0, 1.0) = 0.62;
// Width of the bright rim, in noise units.
uniform float rim_width : hint_range(0.0, 0.3) = 0.06;
// Puddles thin out towards the fan's border over this share of the UV range.
uniform float border_fade : hint_range(0.0, 0.5) = 0.18;
// Noise level where the first specks of each puddle show up at the start of the spread
// (near the noise's peaks, so puddles start from their centres).
uniform float seed_level : hint_range(0.0, 1.0) = 0.78;
// Bubbles per metre, and pops per second.
uniform float bubble_density = 7.0;
uniform float bubble_speed = 1.4;
// How far the pools shrink while fading out (raises the noise threshold).
uniform float fade_shrink : hint_range(0.0, 1.0) = 0.35;

// Per-instance, set by PoisonPool as the pool spreads and fades.
instance uniform float spread : hint_range(0.0, 1.0) = 1.0;
instance uniform float opacity : hint_range(0.0, 1.0) = 1.0;

varying vec2 floor_pos;

void vertex() {
	floor_pos = VERTEX.xz;
}

float pool_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float pool_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(pool_hash(i), pool_hash(i + vec2(1.0, 0.0)), u.x),
		mix(pool_hash(i + vec2(0.0, 1.0)), pool_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float pool_fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int k = 0; k < 4; k++) {
		sum += pool_noise(p) * amp;
		p = p * 2.03 + vec2(17.0, 9.0);
		amp *= 0.5;
	}
	return sum / 0.9375;
}

void fragment() {
	float n = pool_fbm(floor_pos * noise_scale);
	// Thin the puddles towards the fan's border so the outline reads as splashes, not a shape.
	float border = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	n -= (1.0 - smoothstep(0.0, border_fade, border)) * 0.35;
	// Grow each puddle from its centre: start near the noise peaks, end at full coverage.
	float threshold = mix(seed_level, 1.0 - coverage, spread) + (1.0 - opacity) * fade_shrink;
	float d = n - threshold;
	float puddle = smoothstep(0.0, 0.015, d) * step(0.001, spread);
	float rim = 1.0 - smoothstep(0.0, rim_width, d);
	vec3 col = mix(core_color.rgb, rim_color.rgb, rim);
	// Bubbles: one candidate per cell, shown for part of each pop cycle, only inside the pool.
	vec2 cell = floor(floor_pos * bubble_density);
	vec2 cell_uv = fract(floor_pos * bubble_density);
	float h = pool_hash(cell);
	vec2 centre = vec2(pool_hash(cell + 3.1), pool_hash(cell + 7.7)) * 0.6 + 0.2;
	float pop = fract(TIME * bubble_speed + h);
	float radius = 0.18 * sin(pop * PI);
	float bubble = (1.0 - smoothstep(radius * 0.7, radius, length(cell_uv - centre))) * step(0.65, h);
	bubble *= smoothstep(rim_width, rim_width * 2.0, d);
	col = mix(col, bubble_color.rgb, bubble * 0.8);
	ALBEDO = col;
	ALPHA = puddle * mix(core_color.a, rim_color.a, rim) * smoothstep(0.0, 0.15, opacity);
}
