shader_type canvas_item;
render_mode unshaded, blend_add;

// Radial speed streaks, driven by the motor's actual speed.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint = vec3(0.91, 0.69, 0.29);
uniform float streak_count = 42.0;

float hash11(float n) {
	return fract(sin(n * 78.233) * 43758.5453);
}

void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	c.x *= 1.777; // keep streaks circular at 16:9
	float ang = atan(c.y, c.x);
	float r = length(c);

	float cell = floor((ang + 3.14159) * streak_count / 6.28318);
	float rnd = hash11(cell);
	float spawn = step(0.62, rnd);
	float phase = fract(r * 1.35 - TIME * (0.55 + rnd * 0.9) + rnd);

	float streak = spawn * smoothstep(0.72, 1.0, phase) * smoothstep(0.55, 1.05, r);
	float fade = smoothstep(0.02, 0.18, intensity);
	COLOR = vec4(tint, streak * intensity * 0.55 * fade);
}
