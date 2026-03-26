shader_type spatial;
render_mode unshaded, cull_front;

uniform vec3 u_sun_pos = vec3(0.0, 1.0, 0.0);
uniform float u_time = 0.0;
uniform float u_overcast = 0.0;
uniform float u_snow = 0.0;

void fragment() {
	// Direction from camera to sky point
	vec3 dir = normalize(-VERTEX);
	float y = dir.y * 0.5 + 0.5;
	float sun_h = u_sun_pos.y;

	// Day sky
	vec3 day_top = vec3(0.25, 0.55, 0.95);
	vec3 day_bot = vec3(0.6, 0.8, 1.0);
	vec3 day_col = mix(day_bot, day_top, pow(y, 0.8));

	// Sunset sky
	vec3 sunset_top = vec3(0.15, 0.1, 0.35);
	vec3 sunset_bot = vec3(0.9, 0.4, 0.15);
	vec3 sunset_col = mix(sunset_bot, sunset_top, pow(y, 0.5));

	// Night sky
	vec3 night_top = vec3(0.02, 0.02, 0.08);
	vec3 night_bot = vec3(0.05, 0.05, 0.15);
	vec3 night_col = mix(night_bot, night_top, pow(y, 0.6));

	// Blend day/night/sunset
	float day_f = smoothstep(-0.1, 0.3, sun_h);
	float sunset_f = smoothstep(-0.2, 0.0, sun_h) * (1.0 - smoothstep(0.0, 0.25, sun_h));

	vec3 col = mix(night_col, day_col, day_f);
	col = mix(col, sunset_col, sunset_f * 0.7);

	// Sun glow
	float sun_dot = max(dot(dir, normalize(u_sun_pos)), 0.0);
	col += vec3(1.0, 0.8, 0.4) * pow(sun_dot, 64.0) * 2.0 * max(sun_h, 0.0);
	col += vec3(1.0, 0.6, 0.3) * pow(sun_dot, 8.0) * 0.3 * max(sun_h + 0.1, 0.0);

	// Moon glow
	vec3 moon_pos = -normalize(u_sun_pos);
	float moon_dot = max(dot(dir, moon_pos), 0.0);
	float moon_glow = pow(moon_dot, 128.0) * 1.5 + pow(moon_dot, 16.0) * 0.15;
	col += vec3(0.6, 0.7, 1.0) * moon_glow * (1.0 - day_f);

	// Overcast (rain/storm)
	vec3 overcast_col = vec3(0.45, 0.48, 0.52);
	col = mix(col, overcast_col, u_overcast * 0.7);

	// Snow tint
	vec3 snow_sky = vec3(0.65, 0.68, 0.72);
	col = mix(col, snow_sky, u_snow * 0.5);

	// Stars
	float star_hash = fract(sin(dot(floor(dir * 500.0), vec3(127.1, 311.7, 74.7))) * 43758.5453);
	float star = step(0.998, star_hash) * (1.0 - day_f) * (1.0 - u_overcast) * (1.0 - u_snow);
	col += vec3(star) * 0.8;

	ALBEDO = col;
}
