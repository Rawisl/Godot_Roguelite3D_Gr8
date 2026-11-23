shader_type spatial;
// Boss scythe slash: an inked crescent drawn on a ribbon mesh that follows the blade tip.
// Mesh contract: UV.x runs along the swing (0 where the slash starts, 1 where it ends), UV.y
// runs across the ribbon (0 on the outer edge traced by the blade tip, 1 on the inner edge),
// and NORMAL holds the unit direction from the inner edge to the tip for that row.
// The vertex stage keeps the tip path where it is but turns the ribbon's width to face the
// camera, so the crescent reads at full width from a top-down camera whichever way the boss
// faces. The ribbon is also drawn wider than the crescent (ribbon_pad) so flying shards have
// room to move.
// progress moves the head of the crescent along the swing; the crescent spans from the start
// of the swing (or tail_length behind the head) to the head, sharp at the head, widest just
// behind it and thinning to a hairline at the tail.
// crack draws ink cracks over the body from the tail towards the head; shatter then breaks
// the body apart along those cracks, shard by shard in the same order: each shard is thrown
// outwards, speeding up and shrinking until it is gone.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

// boss_slash_core, boss_slash_band and boss_slash_ink in art/palette.md.
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 band_color : source_color = vec4(0.72, 0.72, 0.72, 1.0);
uniform vec4 ink_color : source_color = vec4(0.02, 0.02, 0.02, 1.0);

// Per-instance, driven over time by the attack (AnimationPlayer for now).
instance uniform float progress : hint_range(0.0, 1.0) = 1.0;
instance uniform float crack : hint_range(0.0, 1.0) = 0.0;
instance uniform float shatter : hint_range(0.0, 1.0) = 0.0;
instance uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Distance between the ribbon's two edges in the mesh, in metres.
uniform float mesh_width = 0.54;
// Width of the crescent's ribbon once it faces the camera, in metres.
uniform float ribbon_width = 0.6;
// Extra width drawn on each side for flying shards, as a share of ribbon_width.
uniform float ribbon_pad = 0.6;
// Length of the tip path, in metres. Keeps the shards roughly round.
uniform float arc_length = 1.69;

// Shape, in UV units across the ribbon (1.0 = ribbon_width) and along the swing.
// Longest the crescent gets, as a share of the swing. 1.0 keeps the whole swing.
uniform float tail_length : hint_range(0.05, 1.0) = 1.0;
// Widest part of the white and grey body.
uniform float max_thickness : hint_range(0.0, 1.0) = 0.5;
// Gap kept between the ribbon's outer edge and the body, so the outer ink has room.
uniform float outer_margin : hint_range(0.0, 0.5) = 0.08;
// Share of the crescent length, from the head, over which it grows from a point to full width.
uniform float head_taper : hint_range(0.01, 0.6) = 0.14;
// Higher values thin the tail faster.
uniform float tail_power : hint_range(0.2, 4.0) = 1.5;
// Where the grey band starts, as a share of the body width from the outer side.
uniform float band_start : hint_range(0.0, 1.0) = 0.68;
uniform float ink_outer : hint_range(0.0, 0.3) = 0.06;
uniform float ink_inner : hint_range(0.0, 0.3) = 0.02;

// Cracks and shards.
// Average shard size, in metres.
uniform float shard_size = 0.2;
// Random spread of when each shard cracks and breaks, so the front is jagged.
uniform float shard_jitter : hint_range(0.0, 1.0) = 0.35;
// Width of a crack line once fully open, and of the ink edge on a flying shard,
// in shard-size units.
uniform float crack_width : hint_range(0.0, 0.5) = 0.16;
// How much a shard shrinks by the time it is gone, in shard-size units.
uniform float shard_shrink : hint_range(0.0, 1.0) = 0.45;
// How far a shard is thrown by the time it is gone, in shard-size units. Keep under 1.5:
// a shard is only looked for up to two cells away.
uniform float burst_distance = 1.4;
// Sideways scatter of the throw direction (0: straight out from the boss).
uniform float burst_spread : hint_range(0.0, 2.0) = 1.0;
// Share of the shatter time each shard takes to fly off.
uniform float shard_life : hint_range(0.05, 1.0) = 0.4;

varying float v_across;

void vertex() {
	float mesh_across = UV.y;
	float across = mesh_across * (1.0 + 2.0 * ribbon_pad) - ribbon_pad;
	v_across = across;
	vec3 to_tip = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 tip = pos + to_tip * mesh_width * mesh_across;
	vec3 view = normalize((INV_VIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	vec3 side = to_tip - view * dot(to_tip, view);
	float side_len = length(side);
	side = side_len > 1e-4 ? side / side_len : normalize(cross(view, vec3(0.0, 1.0, 0.0)));
	pos = tip - side * ribbon_width * across;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(pos, 1.0)).xyz;
}

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash22(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// 1 where x > 0, 0 where x < 0, antialiased over w.
float inside(float x, float w) {
	return clamp(x / max(w, 1e-5) + 0.5, 0.0, 1.0);
}

vec2 shard_site(vec2 cell) {
	return cell + 0.5 + (hash22(cell) - 0.5) * 0.9;
}

// Nearest shard to g, and how far g is from that shard's edge (0 on the crack).
void nearest_shard(vec2 g, out vec2 cell, out float edge) {
	vec2 ip = floor(g);
	float f1 = 8.0;
	float f2 = 8.0;
	cell = ip;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = ip + vec2(float(x), float(y));
			float dist = length(shard_site(c) - g);
			if (dist < f1) {
				f2 = f1;
				f1 = dist;
				cell = c;
			} else if (dist < f2) {
				f2 = dist;
			}
		}
	}
	edge = f2 - f1;
}

// When a shard cracks and breaks, 0..1. Tail shards come first.
float shard_order(vec2 cell, float head, float span) {
	float centre_s = clamp((head - shard_site(cell).x * shard_size / arc_length) / span, 0.0, 1.0);
	return (1.0 - centre_s) * (1.0 - shard_jitter) + hash12(cell) * shard_jitter;
}

// The unbroken crescent at (u, across). Returns colour and alpha; body is 1 on the white and
// grey part (not the ink).
vec4 crescent(float u, float across, vec2 aa, float head, float span, out float body) {
	float s = (head - u) / span;
	float aa_s = aa.x / span;
	float profile = smoothstep(0.0, head_taper, s) * pow(clamp(1.0 - s, 0.0, 1.0), tail_power);
	float thickness = max_thickness * profile;
	float on_swing = inside(s, aa_s) * inside(1.0 - s, aa_s);
	// Ink thins out towards the tips so the points stay sharp.
	float ink_scale = sqrt(clamp(profile * 4.0, 0.0, 1.0));
	float d = across - outer_margin;
	body = inside(d, aa.y) * inside(thickness - d, aa.y);
	float ink = inside(d + ink_outer * ink_scale, aa.y) * inside(thickness + ink_inner * ink_scale - d, aa.y);
	float k = d / max(thickness, 1e-4);
	vec3 col = mix(core_color.rgb, band_color.rgb, inside(k - band_start, aa.y / max(thickness, 1e-4)));
	col = mix(ink_color.rgb, col, body);
	return vec4(col, ink * on_swing);
}

void fragment() {
	float u = UV.x;
	float across = v_across;
	vec2 aa = vec2(fwidth(u), fwidth(across));

	float head = progress;
	float tail = max(0.0, head - tail_length);
	float span = max(head - tail, 1e-4);

	vec2 to_grid = vec2(arc_length, ribbon_width) / shard_size;
	vec2 g = vec2(u, across) * to_grid;
	float aa_g = max(aa.x * to_grid.x, aa.y * to_grid.y);

	float body;
	vec4 result = crescent(u, across, aa, head, span, body);

	if (crack > 0.0 && shatter <= 0.0) {
		vec2 cell;
		float edge;
		nearest_shard(g, cell, edge);
		float crack_open = clamp((crack * 1.25 - shard_order(cell, head, span)) / 0.25, 0.0, 1.0);
		float line = 1.0 - inside(edge - crack_width * crack_open, aa_g);
		result.rgb = mix(result.rgb, ink_color.rgb, line * crack_open * body);
	} else if (shatter > 0.0) {
		// Each pixel looks for the shard that has flown over it: shift back by each nearby
		// shard's throw and check the pixel lands inside that shard.
		result = vec4(0.0);
		vec2 ip = floor(g);
		bool found = false;
		for (int y = -2; y <= 2 && !found; y++) {
			for (int x = -2; x <= 2 && !found; x++) {
				vec2 c = ip + vec2(float(x), float(y));
				float order = shard_order(c, head, span);
				float breaking = clamp((shatter * (1.0 + shard_life) - order) / shard_life, 0.0, 1.0);
				if (breaking >= 0.99) {
					continue;
				}
				vec2 dir = normalize(vec2((hash12(c + 3.1) - 0.5) * burst_spread, -(0.4 + hash12(c + 7.7))));
				vec2 q = g - dir * burst_distance * breaking * breaking;
				vec2 qc;
				float edge;
				nearest_shard(q, qc, edge);
				if (distance(qc, c) > 0.1) {
					continue;
				}
				float shrink = shard_shrink * breaking;
				if (edge < shrink) {
					continue;
				}
				float shard_body;
				vec4 piece = crescent(q.x / to_grid.x, q.y / to_grid.y, aa, head, span, shard_body);
				if (piece.a < 0.5) {
					continue;
				}
				float open = breaking > 0.0 ? 1.0 : clamp((crack * 1.25 - order) / 0.25, 0.0, 1.0);
				float line = 1.0 - inside(edge - shrink - crack_width * open, aa_g);
				piece.rgb = mix(piece.rgb, ink_color.rgb, line * open * shard_body);
				result = piece;
				found = true;
			}
		}
	}

	ALBEDO = result.rgb;
	ALPHA = result.a * opacity;
}
