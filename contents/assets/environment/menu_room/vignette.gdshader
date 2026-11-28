shader_type canvas_item;

// Darkens the screen corners so the room fades into shadow.
uniform float strength : hint_range(0.0, 1.0) = 0.88;
uniform float inner = 0.35;
uniform float outer = 0.95;

void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.0, 0.75) * 2.0;
	float d = length(p);
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(inner, outer, d) * strength);
}
