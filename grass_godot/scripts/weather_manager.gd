extends Node
## Weather state machine + wind system — port of js/weather.js

signal weather_changed(weather_type: int)

func cycle_weather() -> void:
	Config.cycle_weather()
	_on_weather_change()

func set_weather(type: int) -> void:
	Config.current_weather = type
	_on_weather_change()

func _on_weather_change() -> void:
	# Tornado init
	if Config.current_weather == Config.Weather.TORNADO and not Config.tornado_active:
		Config.tornado_pos = Vector3(
			Config.cam_target.x + (randf() - 0.5) * 200.0,
			0.0,
			Config.cam_target.z + (randf() - 0.5) * 200.0
		)
		Config.tornado_pos.y = Noise.get_terrain_height(Config.tornado_pos.x, Config.tornado_pos.z)
		Config.tornado_wander_target = Config.tornado_pos
		Config.tornado_active = true

	if Config.current_weather != Config.Weather.TORNADO:
		Config.tornado_active = false

	# Hurricane wind rotation
	if Config.current_weather == Config.Weather.HURRICANE:
		Config.wind_dir_target = Config.wind_direction

	weather_changed.emit(Config.current_weather)

func update_weather(dt: float) -> void:
	var props: Dictionary = Config.WEATHER_PROPS[Config.current_weather]
	var tdt := dt * 3.0  # transition speed

	# Smooth interpolation of weather values
	Config.w_val["rain"] += (props["rain"] - Config.w_val["rain"]) * tdt
	Config.w_val["snow"] += (props["snow"] - Config.w_val["snow"]) * tdt
	Config.w_val["fog_mult"] += (props["fog_mult"] - Config.w_val["fog_mult"]) * tdt
	Config.w_val["cloud_dark"] += (props["cloud_dark"] - Config.w_val["cloud_dark"]) * tdt
	Config.w_val["overcast"] += (props["overcast"] - Config.w_val["overcast"]) * tdt

	# Wind
	var wind_range: Array = props["wind_range"]
	var wind_min: float = wind_range[0]
	var wind_max: float = wind_range[1]
	var wind_target := wind_min + sin(Config.real_time * 0.1) * (wind_max - wind_min) * 0.5 + (wind_max - wind_min) * 0.5
	Config.wind_strength += (wind_target - Config.wind_strength) * dt * 2.0

	# Wind direction
	if Config.current_weather == Config.Weather.HURRICANE:
		Config.wind_dir_target += dt * 0.5
	elif Config.current_weather == Config.Weather.TORNADO and Config.tornado_active:
		var to_tornado := atan2(
			Config.tornado_pos.z - Config.cam_target.z,
			Config.tornado_pos.x - Config.cam_target.x
		)
		Config.wind_dir_target += (to_tornado - Config.wind_dir_target) * dt * 2.0
	else:
		Config.wind_dir_target += (randf() - 0.5) * 0.02

	Config.wind_direction += (Config.wind_dir_target - Config.wind_direction) * dt * 3.0

	# Track rain time for drought
	if Config.w_val["rain"] > 0.3:
		Config.time_since_rain = 0.0
	else:
		Config.time_since_rain += dt * Config.time_speed

	# Snow cover accumulation
	if Config.w_val["snow"] > 0.3:
		Config.snow_cover = minf(1.0, Config.snow_cover + dt * 0.05 * Config.time_speed)
	else:
		Config.snow_cover = maxf(0.0, Config.snow_cover - dt * 0.03 * Config.time_speed)
