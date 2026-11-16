shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Faint ring of puffy toon clouds around the Hazard Trial island, drawn on a flat ring mesh.
// UV.x runs once around the ring (0..1), UV.y across it (0 inside, 1 outside). COLOR.r is a
// per-ring seed so every ring gets its own clumps from the one material.

uniform vec3 cloud_color : source_color = vec3(0.95, 0.93, 1.0);
uniform vec3 shade_color : source_color = vec3(0.74, 0.7, 0.96);
// Overall see-through: the rings only hint at the clouds of the painted sky.
uniform float opacity : hint_range(0.0, 1.0) = 0.22;
// Clumps around the ring and puffs on their edges.
uniform float clumps : hint_range(1.0, 12.0) = 4.0;
uniform float puffs : hint_range(4.0, 80.0) = 24.0;
// Part of the ring left as open sky between clumps.
uniform float gaps : hint_range(0.0, 1.0) = 0.35;
uniform float softness : hint_range(0.001, 0.3) = 0.035;

varying float seed;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm2(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		sum += noise2(p) * amp;
		p = p * 2.07 + vec2(5.3, 1.9);
		amp *= 0.5;
	}
	return sum;
}

void vertex() {
	seed = COLOR.r;
}

void fragment() {
	float a = UV.x * TAU;
	// Sampling on a circle keeps the ring seamless where UV.x wraps.
	vec2 around = vec2(cos(a), sin(a));
	vec2 offset = vec2(seed * 37.0, seed * 11.0);
	// Clumps: where the band is thick, thin or missing.
	float clump = fbm2(around * clumps * 0.5 + offset);
	float present = smoothstep(gaps, gaps + 0.15, clump);
	// Band across the ring, wavering and swelling with the clumps.
	float centre = 0.5 + (fbm2(around * 2.0 + offset.yx) - 0.5) * 0.35;
	float half_width = 0.06 + 0.26 * clump;
	// Round puffs on both edges: the absolute sine makes each puff a dome (puffs is rounded so the
	// domes meet where UV.x wraps), the noise on the circle varies their size.
	float dome = abs(sin(UV.x * round(puffs) * PI));
	float puff = dome * (0.06 + noise2(around * puffs * 0.3 + offset) * 0.14);
	float d = abs(UV.y - centre) - half_width - puff;
	float body = (1.0 - smoothstep(-softness, softness, d)) * present;
	// Two toon tones: the inner (island) side lit, the outer side in shade.
	float lit = step(UV.y, centre + 0.04);
	ALBEDO = mix(shade_color, cloud_color, lit);
	ALPHA = body * opacity;
}
