shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform float u_time = 0.0;
uniform float u_overcast = 0.0;
uniform float u_seed = 0.0;
uniform float u_day_factor = 1.0;
uniform float u_layer_dark = 0.0;

// --- Noise functions ---
float hash2D(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise2D(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2D(i);
	float b = hash2D(i + vec2(1.0, 0.0));
	float c = hash2D(i + vec2(0.0, 1.0));
	float d = hash2D(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbmNoise(vec2 p, int octaves) {
	float v = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 6; i++) {
		if (i >= octaves) break;
		v += amp * noise2D(p * freq);
		amp *= 0.5;
		freq *= 2.0;
	}
	return v;
}

void fragment() {
	vec2 uv_coord = UV;
	vec2 p = uv_coord * 3.0 + vec2(u_time * 0.02, u_time * 0.005) + u_seed * 10.0;

	float n1 = fbmNoise(p * 1.0, 6);
	float n2 = fbmNoise(p * 2.5 + vec2(5.3, 1.7), 4);
	float n3 = fbmNoise(p * 6.0 + vec2(9.1, 4.3), 3);

	float cloud = n1 * 0.6 + n2 * 0.3 + n3 * 0.1;

	// Coverage increases with overcast
	float coverage = mix(0.42, 0.25, u_overcast);
	cloud = smoothstep(coverage, coverage + 0.25, cloud);

	// Edge fade
	float edge_fade = smoothstep(0.0, 0.15, uv_coord.x) * smoothstep(1.0, 0.85, uv_coord.x)
	               * smoothstep(0.0, 0.15, uv_coord.y) * smoothstep(1.0, 0.85, uv_coord.y);
	cloud *= edge_fade;

	// Colors
	vec3 day_cloud = vec3(1.0, 0.99, 0.96);
	vec3 storm_cloud = vec3(0.35, 0.37, 0.42);
	vec3 night_cloud = vec3(0.12, 0.14, 0.22);

	vec3 col = mix(night_cloud, day_cloud, u_day_factor);
	col = mix(col, storm_cloud, u_overcast * 0.8 + u_layer_dark * 0.3);

	// Bloom edge highlight
	col += vec3(0.15, 0.12, 0.08) * pow(cloud, 3.0) * u_day_factor;

	float alpha = cloud * mix(0.6, 0.95, u_overcast);
	ALBEDO = col;
	ALPHA = alpha;
}
