shader_type spatial;
// An inked star sparkle on a camera-facing quad (QuadMesh, size 1 x 1). points sets how many
// spikes it has (4 for a twinkle, 6 for a "*").
// Over its life the star grows, peaks half way and shrinks away, turning a little as it goes.
// The life comes from the per-instance pop (a sparkle placed by hand), or, with
// particle_life on, from the particle's own life (CPUParticles3D).
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

// boss_slash_core and boss_slash_ink in art/palette.md.
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 ink_color : source_color = vec4(0.02, 0.02, 0.02, 1.0);

instance uniform float pop : hint_range(0.0, 1.0) = 0.5;
uniform bool particle_life = false;
uniform int points = 4;
// Size of the star at its peak, in metres.
uniform float size = 0.12;
// Radius between the spikes, as a share of the spike length.
uniform float inner_radius : hint_range(0.0, 1.0) = 0.22;
// Higher values give thinner spikes.
uniform float spike_sharpness = 6.0;
uniform float ink_share : hint_range(0.0, 0.5) = 0.22;
// Turn over the whole life, in turns.
uniform float spin = 0.15;

varying float life;
varying float seed;

void vertex() {
	life = particle_life ? INSTANCE_CUSTOM.y : pop;
	seed = particle_life ? INSTANCE_CUSTOM.x : 0.0;
	// Billboard: keep the quad's position and scale but face the camera.
	float scale = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale, INV_VIEW_MATRIX[1] * scale, INV_VIEW_MATRIX[2] * scale, MODEL_MATRIX[3]);
	VERTEX *= size;
}

float inside(float x) {
	float w = max(fwidth(x), 1e-5);
	return clamp(x / w + 0.5, 0.0, 1.0);
}

void fragment() {
	float grow = sin(clamp(life, 0.0, 1.0) * PI);
	vec2 p = (UV - 0.5) * 2.0 / max(grow, 1e-3);
	float a = atan(p.y, p.x) + (life * spin + seed) * TAU;
	float spike = pow(abs(cos(a * float(points) * 0.5)), spike_sharpness);
	float radius = mix(inner_radius, 1.0, spike);
	float r = length(p);
	float outline = inside(radius - r);
	float body = inside(radius * (1.0 - ink_share) - ink_share * 0.3 - r);
	ALBEDO = mix(ink_color.rgb, core_color.rgb, body);
	ALPHA = outline * step(0.001, grow);
}
