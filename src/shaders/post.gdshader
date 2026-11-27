shader_type canvas_item;
render_mode unshaded;

// Authored post stack: vignette + chromatic aberration + film grain + damage tint.
// No generated textures: every value here is hand-tuned.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette : hint_range(0.0, 1.0) = 0.42;
uniform float aberration : hint_range(0.0, 1.0) = 0.0;
uniform float grain : hint_range(0.0, 0.2) = 0.022;
uniform float hurt : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float dash : hint_range(0.0, 1.0) = 0.0;
uniform vec3 pulse_tint = vec3(1.0, 0.36, 0.36);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float d = length(c);

	float ab = (aberration * 0.010 + pulse * 0.004) * (0.30 + d * 1.4);
	vec3 col;
	col.r = texture(screen_tex, uv + c * ab).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - c * ab).b;

	// soft vignette, slightly warmer in the corners
	float vig = smoothstep(1.02, 0.18, d * (0.85 + vignette));
	col *= mix(1.0, vig, 0.55 + vignette * 0.45);

	// grain (animates at 24 fps, not per frame, so it reads as film)
	float g = hash21(floor(uv * vec2(1600.0, 900.0)) + floor(TIME * 24.0));
	col += (g - 0.5) * grain;

	// dash: a radial smear that pulls the frame past the camera, plus hot streaks
	if (dash > 0.001) {
		vec3 smear = vec3(0.0);
		float total = 0.0;
		for (int i = 1; i <= 5; i++) {
			float k = float(i) * 0.016 * dash;
			float w = 1.0 - float(i) / 6.5;
			smear += texture(screen_tex, uv + c * k).rgb * w;
			total += w;
		}
		smear /= max(total, 0.001);
		col = mix(col, smear * 1.07, dash * 0.8);
		col += vec3(1.0, 0.80, 0.46) * dash * 0.10 * smoothstep(0.18, 0.62, d);
	}

	// role pulse (you are IT) + damage
	col = mix(col, col * pulse_tint, pulse * (0.10 + d * 0.35));
	col = mix(col, vec3(0.72, 0.10, 0.13), hurt * (0.10 + d * 0.45));

	COLOR = vec4(col, 1.0);
}
