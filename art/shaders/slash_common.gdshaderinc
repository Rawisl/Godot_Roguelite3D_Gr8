// Shared by the Whirlwind and Sword Wave shaders: brush streaks behind a slash.

float slash_hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float slash_noise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(slash_hash(i), slash_hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

// Streaks laid side by side across lane (lane = metres across the slash x streaks per metre),
// running back along the tail. k is 0 at the head and 1 at the end of the tail; along is the
// distance back from the head in metres, used to break the streaks up.
// Every streak has its own width, length and brightness, and narrows to a point at its end.
// Returns the streak alpha, 0..1.
float slash_streaks(float lane, float k, float along, float min_length, float breakup) {
	float id = floor(lane);
	float x = abs(fract(lane) - 0.5);
	float length_k = mix(min_length, 1.0, slash_hash(id + 3.7));
	float left = clamp(1.0 - k / length_k, 0.0, 1.0);
	float streak_half = mix(0.15, 0.42, slash_hash(id + 5.1)) * left;
	float aa = fwidth(lane);
	// A spent streak is gone, not a hairline left by the antialiasing.
	float body = (1.0 - smoothstep(streak_half - aa, streak_half + aa, x)) * smoothstep(0.0, 0.02, left);
	float gaps = mix(1.0, smoothstep(0.1, 0.5, slash_noise(along * 1.2 + id * 13.1)), breakup);
	float brightness = mix(0.7, 1.0, slash_hash(id + 9.2));
	return body * gaps * brightness * mix(0.5, 1.0, left) * step(0.0, k);
}
