shader_type spatial;
render_mode cull_disabled, skip_vertex_transform;

// Uniforms
uniform float u_time = 0.0;
uniform float u_wind_str = 0.3;
uniform vec2 u_wind_dir = vec2(1.0, 0.5);
uniform vec3 u_sun_dir = vec3(0.0, 1.0, 0.0);
uniform float u_day_factor = 1.0;
uniform float u_snow_cover = 0.0;

// Per-instance custom data: x = health
varying float v_y;
varying vec3 v_world_pos;
varying float v_health;

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
	// Read health from instance custom data
	v_health = INSTANCE_CUSTOM.x;

	// Wilt scale based on health
	float wilt_scale = 0.3 + 0.7 * smoothstep(0.0, 0.4, v_health);
	vec3 local_pos = VERTEX * vec3(1.0, wilt_scale, 1.0);

	// Apply instance transform (MODEL_MATRIX includes instance transform for MultiMesh)
	vec4 world_pos4 = MODEL_MATRIX * vec4(local_pos, 1.0);
	v_world_pos = world_pos4.xyz;

	// Wind displacement
	float wind_phase = dot(v_world_pos.xz, normalize(u_wind_dir) * 0.15) + u_time * 2.5;
	float wind_wave = sin(wind_phase) * 0.5 + sin(wind_phase * 2.3 + 1.5) * 0.25 + sin(wind_phase * 0.7 + 3.0) * 0.25;
	float height_factor = local_pos.y;

	world_pos4.x += wind_wave * u_wind_str * height_factor * 1.8;
	world_pos4.z += wind_wave * u_wind_str * height_factor * 0.6 * sin(u_time * 0.5 + v_world_pos.x);

	v_y = local_pos.y;

	VERTEX = (VIEW_MATRIX * world_pos4).xyz;
	NORMAL = (VIEW_MATRIX * MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	// Healthy color gradient
	vec3 base_green = vec3(0.22, 0.55, 0.12);
	vec3 tip_green = vec3(0.42, 0.78, 0.18);
	vec3 healthy_col = mix(base_green, tip_green, v_y);

	// Dead/dying colors
	vec3 yellow_col = vec3(0.65, 0.6, 0.15);
	vec3 dead_col = vec3(0.35, 0.25, 0.08);

	// Blend based on health
	vec3 col;
	if (v_health > 0.5) {
		col = mix(yellow_col, healthy_col, (v_health - 0.5) * 2.0);
	} else {
		col = mix(dead_col, yellow_col, v_health * 2.0);
	}

	// Per-blade variation
	float n = noise2D(v_world_pos.xz * 0.05);
	float n2 = noise2D(floor(v_world_pos.xz * 2.0));
	col *= 0.85 + n * 0.2 + n2 * 0.1;

	// Sun lighting
	float sun_factor = max(u_sun_dir.y, 0.0) * 0.6 + 0.15;
	vec3 sun_lit = col * sun_factor * vec3(1.0, 0.97, 0.9);

	// Moon lighting
	float moon_factor = max(-u_sun_dir.y, 0.0) * 0.5;
	vec3 moon_lit = col * moon_factor * vec3(0.4, 0.5, 0.8);

	// Ambient
	vec3 amb_lit = col * mix(0.12, 0.22, u_day_factor);

	vec3 final_col = sun_lit * u_day_factor + moon_lit * (1.0 - u_day_factor) + amb_lit;

	// Snow on tips
	float snow_on_blade = u_snow_cover * v_y * (0.7 + n * 0.3);
	float snow_light = max(sun_factor * u_day_factor, moon_factor * (1.0 - u_day_factor)) + 0.15;
	final_col = mix(final_col, vec3(0.88, 0.9, 0.95) * snow_light, snow_on_blade);

	ALBEDO = final_col;
	// Disable default lighting since we compute our own
	SPECULAR = 0.0;
}
