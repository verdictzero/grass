extends Node3D
## Main: init, animate loop, game orchestration
## Grass Growing Simulator 2026 — GOTY Edition (Godot 4 Port)

# Child managers
@onready var camera: Camera3D = $Camera3D
@onready var sky_manager: Node3D = $SkyManager
@onready var terrain_manager: Node3D = $TerrainManager
@onready var grass_manager: Node3D = $GrassManager
@onready var weather_manager: Node = $WeatherManager
@onready var cloud_manager: Node3D = $CloudManager
@onready var rain_snow_manager: Node3D = $RainSnowManager
@onready var fog_manager: Node3D = $FogManager
@onready var lightning_manager: Node3D = $LightningManager
@onready var tornado_manager: Node3D = $TornadoManager
@onready var flare_manager: Node3D = $FlareManager
@onready var title_screen: CanvasLayer = $TitleScreen
@onready var hud: CanvasLayer = $HUD
@onready var settings_drawer: CanvasLayer = $SettingsDrawer

# Lights
var sun_light: DirectionalLight3D
var moon_light: DirectionalLight3D
var ambient_light: DirectionalLight3D  # We'll use environment instead
var lightning_light: OmniLight3D

# Environment
var world_env: WorldEnvironment
var environment: Environment

# FPS tracking
var fps_frames := 0
var fps_time := 0.0

func _ready() -> void:
	# Set up cross-references
	terrain_manager.grass_manager = grass_manager
	grass_manager.terrain_manager = terrain_manager
	lightning_manager.grass_manager = grass_manager

	# Create lights
	_create_lights()

	# Create environment (bloom, fog, tonemapping)
	_create_environment()

	# Connect UI signals
	title_screen.game_started.connect(_on_game_started)
	hud.weather_cycle_requested.connect(func(): weather_manager.cycle_weather())
	hud.settings_requested.connect(func(): settings_drawer.open_drawer())
	settings_drawer.rebuild_requested.connect(_rebuild_all)

func _on_game_started() -> void:
	hud.visible = true

	# Create initial systems
	sky_manager.create_sky()
	cloud_manager.create_clouds()
	rain_snow_manager.create_rain()
	rain_snow_manager.create_snow()
	fog_manager.create_fog_particles()

	# Force initial chunk creation
	Config.current_chunk_x = -999
	terrain_manager.update_chunks()

func _process(delta: float) -> void:
	if not Config.game_started:
		return

	var dt := minf(delta, 0.05)
	Config.real_time += dt

	# --- TIME ---
	Config.game_time += (dt * Config.time_speed) / 120.0
	Config.game_time = fmod(Config.game_time, 1.0)

	# --- SUN/MOON POSITION ---
	var sun_angle := Config.game_time * PI * 2.0 - PI / 2.0
	var sun_x := cos(sun_angle) * 200.0
	var sun_y := sin(sun_angle) * 200.0
	Config.sun_dir = Vector3(sun_x, sun_y, 50.0).normalized()
	Config.moon_dir = -Config.sun_dir

	# --- DAY FACTOR ---
	Config.day_factor = clampf((Config.sun_dir.y + 0.1) / 0.4, 0.0, 1.0)

	# --- WEATHER ---
	weather_manager.update_weather(dt)

	# --- LIGHTING ---
	_update_lights(dt)

	# --- SKY ---
	sky_manager.update_sky(dt)

	# --- FOG ---
	_update_fog(dt)

	# --- CHUNKS ---
	terrain_manager.update_chunks()

	# --- GRASS ---
	grass_manager.update_grass(dt)

	# --- TERRAIN UNIFORMS ---
	terrain_manager.update_terrain_uniforms()

	# --- CLOUDS ---
	cloud_manager.update_clouds(dt)

	# --- RAIN/SNOW ---
	rain_snow_manager.update_rain_snow(dt)

	# --- FOG PARTICLES ---
	fog_manager.update_fog_particles(dt)

	# --- LIGHTNING ---
	lightning_manager.update_lightning(dt)

	# --- TORNADO ---
	tornado_manager.update_tornado(dt)

	# --- LENS FLARES ---
	flare_manager.update_flares(dt, camera)

	# --- HUD ---
	hud.update_hud()

	# --- ENVIRONMENT ---
	_update_environment(dt)

	# --- FPS ---
	fps_frames += 1
	fps_time += dt
	if fps_time >= 0.5:
		var fps := roundi(float(fps_frames) / fps_time)
		if hud.fps_label:
			hud.fps_label.text = "%d FPS" % fps
		fps_frames = 0
		fps_time = 0.0

func _create_lights() -> void:
	# Sun — directional with shadows
	sun_light = DirectionalLight3D.new()
	sun_light.light_color = Color(1.0, 0.933, 0.867)
	sun_light.light_energy = 1.0
	sun_light.shadow_enabled = Config.gfx["shadows"]
	sun_light.directional_shadow_max_distance = 400.0
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun_light)

	# Moon — directional, cooler
	moon_light = DirectionalLight3D.new()
	moon_light.light_color = Color(0.533, 0.6, 0.8)
	moon_light.light_energy = 0.15
	moon_light.shadow_enabled = false
	add_child(moon_light)

	# Lightning — omni light
	lightning_light = OmniLight3D.new()
	lightning_light.light_color = Color(0.933, 0.933, 1.0)
	lightning_light.light_energy = 0.0
	lightning_light.omni_range = 600.0
	lightning_light.position = Vector3(0, 80, 0)
	add_child(lightning_light)

func _update_lights(dt: float) -> void:
	# Sun
	sun_light.look_at_from_position(
		Config.sun_dir * 150.0 + Config.cam_target,
		Config.cam_target,
		Vector3.UP
	)
	sun_light.light_energy = Config.day_factor * 1.8

	# Sun color — warm, shifts at sunset
	var sun_hue := 0.1 + (1.0 - Config.day_factor) * 0.02
	sun_light.light_color = Color.from_hsv(sun_hue, 0.5, 0.6 + Config.day_factor * 0.4)

	# Sunset golden hour
	var sunset_factor := maxf(0.0, 1.0 - absf(Config.sun_dir.y) * 5.0) * 0.6
	sun_light.light_color = sun_light.light_color.lerp(Color(1.0, 0.45, 0.15), sunset_factor)

	# Moon
	moon_light.look_at_from_position(
		Config.moon_dir * 150.0 + Config.cam_target,
		Config.cam_target,
		Vector3.UP
	)
	moon_light.light_energy = (1.0 - Config.day_factor) * 0.7
	moon_light.light_color = Color.from_hsv(0.6, 0.35, 0.75)

	# Lightning flash decay
	if Config.lightning_flash_time > 0.0:
		Config.lightning_flash_time -= dt
		var flash := maxf(0.0, Config.lightning_flash_time * 15.0)
		lightning_light.light_energy = flash * 8.0
	else:
		lightning_light.light_energy = 0.0

func _create_environment() -> void:
	environment = Environment.new()

	# Tonemap
	environment.tonemap_mode = Environment.TONE_MAP_ACES
	environment.tonemap_exposure = 1.1

	# Glow (bloom)
	environment.glow_enabled = Config.gfx["bloom"]
	environment.glow_intensity = 0.8
	environment.glow_strength = Config.gfx["bloom_strength"]
	environment.glow_bloom = 0.1
	environment.glow_hdr_threshold = 0.6

	# Fog
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.55, 0.7, 0.85)
	environment.fog_density = Config.gfx["fog_density"]
	environment.fog_aerial_perspective = 0.5

	# Ambient light (replaces Three.js AmbientLight + HemisphereLight)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.25, 0.25, 0.35)
	environment.ambient_light_energy = 0.5

	# Background — sky dome handles this
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0)

	world_env = WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)

func _update_environment(dt: float) -> void:
	if not environment:
		return

	var rain_val: float = Config.w_val["overcast"]
	var snow_val: float = Config.w_val["snow"]

	# Dynamic fog color
	var base_fog_r := 0.55 * Config.day_factor + 0.05
	var base_fog_g := 0.7 * Config.day_factor + 0.05
	var base_fog_b := 0.85 * Config.day_factor + 0.1
	var fog_r := base_fog_r * (1.0 - rain_val * 0.3)
	var fog_g := base_fog_g * (1.0 - rain_val * 0.3)
	var fog_b := base_fog_b * (1.0 - rain_val * 0.2)
	# Snow whitens fog
	fog_r = fog_r * (1.0 - snow_val * 0.3) + snow_val * 0.3 * 0.8
	fog_g = fog_g * (1.0 - snow_val * 0.3) + snow_val * 0.3 * 0.82
	fog_b = fog_b * (1.0 - snow_val * 0.3) + snow_val * 0.3 * 0.85
	environment.fog_light_color = Color(fog_r, fog_g, fog_b)

	# Dynamic fog density
	environment.fog_density = Config.gfx["fog_density"] * Config.w_val["fog_mult"]

	# Exposure
	var rain_damp: float = rain_val
	environment.tonemap_exposure = (0.4 + Config.day_factor * 0.8) * (1.0 - rain_damp * 0.25)

	# Ambient light — warm day, cool night
	var amb_day := Color(0.35, 0.35, 0.3)
	var amb_night := Color(0.1, 0.12, 0.25)
	environment.ambient_light_color = amb_day.lerp(amb_night, 1.0 - Config.day_factor)
	environment.ambient_light_energy = 0.35 + Config.day_factor * 0.4

	# Bloom
	environment.glow_enabled = Config.gfx["bloom"]
	environment.glow_strength = Config.gfx["bloom_strength"]

	# Lightning bloom spike
	if Config.lightning_flash_time > 0.0:
		environment.glow_strength = minf(2.0, Config.gfx["bloom_strength"] + 1.0)

func _rebuild_all() -> void:
	# Rebuild all dynamic systems after settings change
	terrain_manager.chunks.clear()
	Config.current_chunk_x = -999
	terrain_manager.update_chunks()
	cloud_manager.create_clouds()
	rain_snow_manager.rebuild_rain()
	rain_snow_manager.rebuild_snow()
	fog_manager.create_fog_particles()

	# Update shadow settings
	sun_light.shadow_enabled = Config.gfx["shadows"]

	# Update camera far plane
	camera.far = Config.gfx["draw_dist"]
