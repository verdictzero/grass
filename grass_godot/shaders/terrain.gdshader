shader_type spatial;

uniform vec3 u_sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 u_moon_dir = vec3(0.0, -1.0, 0.0);
uniform float u_day_factor = 1.0;
uniform float u_snow_cover = 0.0;

varying vec3 v_world_pos;
varying float v_height;

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

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_height = VERTEX.y;
}

void fragment() {
	// Base grass colors
	vec3 grass1 = vec3(0.22, 0.55, 0.12);
	vec3 grass2 = vec3(0.35, 0.65, 0.15);
	vec3 grass3 = vec3(0.18, 0.45, 0.08);

	float n = noise2D(v_world_pos.xz * 0.05);
	float n2 = noise2D(v_world_pos.xz * 0.15 + vec2(50.0));
	vec3 base_col = mix(mix(grass1, grass2, n), grass3, smoothstep(5.0, 15.0, v_height));
	base_col *= 0.85 + n2 * 0.3;

	// Sun lighting
	float sun_diff = max(dot(NORMAL, normalize(u_sun_dir)), 0.0);
	vec3 sun_col = vec3(1.0, 0.95, 0.85) * sun_diff * 0.7 * u_day_factor;

	// Moon lighting
	float moon_diff = max(dot(NORMAL, normalize(u_moon_dir)), 0.0);
	vec3 moon_col = vec3(0.3, 0.35, 0.6) * moon_diff * 0.5 * (1.0 - u_day_factor);

	// Ambient
	float ambient = 0.2 + u_day_factor * 0.25;
	vec3 amb_col = mix(vec3(0.08, 0.1, 0.2), vec3(0.3, 0.3, 0.25), u_day_factor) * ambient;

	vec3 lit = base_col * (sun_col + moon_col + amb_col);

	// Snow cover
	float snow_noise = noise2D(v_world_pos.xz * 0.03) * 0.3 + 0.7;
	float up_facing = max(dot(NORMAL, vec3(0.0, 1.0, 0.0)), 0.0);
	float snow = u_snow_cover * snow_noise * up_facing;
	lit = mix(lit, vec3(0.9, 0.92, 0.95) * (sun_col + moon_col + amb_col), snow);

	ALBEDO = lit;
	SPECULAR = 0.0;
}
