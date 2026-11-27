shader_type canvas_item;
render_mode unshaded;

// Menu backdrop: hand-composed lighting, not a generated image.
// Warm club light from the left, cool rim from the right, slow dust, hard vignette.

uniform vec3 ink = vec3(0.082, 0.062, 0.108);
uniform vec3 gold = vec3(0.910, 0.690, 0.294);
uniform vec3 mint = vec3(0.373, 0.890, 0.631);
uniform float time_scale = 1.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 p = uv;
	p.x *= 1.777;

	float t = TIME * 0.05 * time_scale;

	// two soft key lights
	vec2 g1 = vec2(0.42 + sin(t) * 0.03, 0.46);
	vec2 g2 = vec2(1.28 + cos(t * 0.7) * 0.04, 0.36);
	float d1 = length(p - g1);
	float d2 = length(p - g2);

	vec3 col = ink;
	col += gold * 0.22 * smoothstep(0.80, 0.0, d1);
	col += gold * 0.06 * smoothstep(1.45, 0.0, d1);
	col += mint * 0.07 * smoothstep(0.85, 0.0, d2);

	// slow diagonal light shafts
	float shaft = sin((uv.x * 2.2 + uv.y * 1.4) * 3.14159 + t * 2.0);
	col += gold * 0.012 * max(shaft, 0.0);

	// dust motes
	float dust = noise(uv * 260.0 + vec2(t * 12.0, -t * 7.0));
	dust = smoothstep(0.90, 1.0, dust);
	col += vec3(1.0, 0.92, 0.78) * dust * 0.09;

	// heavy vignette so text sits on darkness
	vec2 c = uv - 0.5;
	float d = length(c * vec2(1.0, 1.15));
	col *= 0.34 + 0.66 * smoothstep(1.05, 0.05, d);

	// fine grain
	float g = hash21(floor(uv * vec2(1600.0, 900.0)) + floor(TIME * 24.0));
	col += (g - 0.5) * 0.016;

	COLOR = vec4(col, 1.0);
}
