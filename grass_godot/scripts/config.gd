extends Node
## Global state, settings, and constants for Grass Growing Simulator 2026

# --- WEATHER ENUM ---
enum Weather { CLEAR, RAIN, THUNDERSTORM, SNOW, TORNADO, HURRICANE }

const WEATHER_NAMES := ["Clear", "Rain", "Thunderstorm", "Snow", "Tornado", "Hurricane"]
const WEATHER_ICONS := ["\u2600\uFE0F", "\uD83C\uDF27\uFE0F", "\u26C8\uFE0F", "\u2744\uFE0F", "\uD83C\uDF2A\uFE0F", "\uD83C\uDF00"]

# --- WEATHER PROPERTIES ---
# { wind_range: [min, max], rain, snow, fog_mult, cloud_dark, overcast }
var WEATHER_PROPS := {
	Weather.CLEAR:        { "wind_range": [0.1, 0.3], "rain": 0.0,  "snow": 0.0, "fog_mult": 1.0, "cloud_dark": 0.0, "overcast": 0.0 },
	Weather.RAIN:         { "wind_range": [0.4, 0.7], "rain": 1.0,  "snow": 0.0, "fog_mult": 1.5, "cloud_dark": 0.4, "overcast": 0.7 },
	Weather.THUNDERSTORM: { "wind_range": [0.7, 1.0], "rain": 2.0,  "snow": 0.0, "fog_mult": 2.0, "cloud_dark": 0.8, "overcast": 0.9 },
	Weather.SNOW:         { "wind_range": [0.1, 0.4], "rain": 0.0,  "snow": 1.0, "fog_mult": 1.8, "cloud_dark": 0.3, "overcast": 0.5 },
	Weather.TORNADO:      { "wind_range": [1.0, 1.5], "rain": 0.8,  "snow": 0.0, "fog_mult": 2.5, "cloud_dark": 0.7, "overcast": 0.8 },
	Weather.HURRICANE:    { "wind_range": [1.5, 2.5], "rain": 3.0,  "snow": 0.0, "fog_mult": 4.0, "cloud_dark": 0.9, "overcast": 0.95 },
}

# --- COLOR PALETTE (grass + terrain matching) ---
const PALETTE := {
	"grass1":   Vector3(0.22, 0.55, 0.12),
	"grass2":   Vector3(0.35, 0.65, 0.15),
	"grass3":   Vector3(0.18, 0.45, 0.08),
	"grassTip": Vector3(0.42, 0.78, 0.18),
	"dead":     Vector3(0.35, 0.25, 0.08),
	"yellow":   Vector3(0.65, 0.6,  0.15),
}

# --- CAMERA ---
var cam_angle_h: float = 0.0
var cam_angle_v: float = 0.4
var cam_dist: float = 45.0
var cam_target: Vector3 = Vector3(0.0, 8.0, 0.0)

# --- TIME ---
var game_time: float = 0.25  # fraction of day (0-1), starts at 6 AM
var time_speed: float = 1.0
var real_time: float = 0.0

# --- WEATHER STATE ---
var current_weather: int = Weather.CLEAR

# Smoothly interpolated weather values
var w_val := {
	"rain": 0.0,
	"snow": 0.0,
	"wind_target": 0.2,
	"fog_mult": 1.0,
	"cloud_dark": 0.0,
	"overcast": 0.0,
}

# --- WIND ---
var wind_strength: float = 0.2
var wind_direction: float = 0.0
var wind_dir_target: float = 0.0

# --- GAME STATE ---
var total_grass_score: int = 0
var grass_growth_rate: int = 0
var snow_cover: float = 0.0
var time_since_rain: float = 0.0

# --- LIGHTING ---
var day_factor: float = 1.0
var sun_dir: Vector3 = Vector3(0.0, 1.0, 0.0)
var moon_dir: Vector3 = Vector3(0.0, -1.0, 0.0)

# --- LIGHTNING ---
var lightning_timer: float = 0.0
var lightning_flash_time: float = 0.0

# --- TORNADO ---
var tornado_pos: Vector3 = Vector3.ZERO
var tornado_active: bool = false
var tornado_angle: float = 0.0
var tornado_wander_target: Vector3 = Vector3.ZERO

# --- CHUNKS ---
const CHUNK_SIZE: int = 200
const CHUNK_RENDER_DIST: int = 3
var current_chunk_x: int = -999
var current_chunk_z: int = -999

# --- GRAPHICS SETTINGS ---
var gfx := {
	"grass_count": 200000,
	"shadows": true,
	"shadow_res": 2048,
	"bloom": true,
	"bloom_strength": 0.35,
	"antialias": true,
	"pixel_ratio": 1.5,
	"cloud_count": 20,
	"rain_count": 8000,
	"terrain_seg": 48,
	"draw_dist": 5000,
	"fog_density": 0.0006,
	"show_fps": false,
	"fog_particles": true,
	"fog_particle_count": 150,
}

# --- QUALITY PRESETS ---
const PRESETS := {
	"low": {
		"grass_count": 50000, "shadows": false, "shadow_res": 512, "bloom": false,
		"bloom_strength": 0.2, "pixel_ratio": 0.75, "cloud_count": 8, "rain_count": 2000,
		"terrain_seg": 32, "draw_dist": 2000, "fog_density": 0.001,
		"fog_particles": true, "fog_particle_count": 50
	},
	"medium": {
		"grass_count": 120000, "shadows": true, "shadow_res": 1024, "bloom": true,
		"bloom_strength": 0.25, "pixel_ratio": 1.0, "cloud_count": 14, "rain_count": 5000,
		"terrain_seg": 40, "draw_dist": 3500, "fog_density": 0.0008,
		"fog_particles": true, "fog_particle_count": 100
	},
	"high": {
		"grass_count": 200000, "shadows": true, "shadow_res": 2048, "bloom": true,
		"bloom_strength": 0.35, "pixel_ratio": 1.5, "cloud_count": 20, "rain_count": 8000,
		"terrain_seg": 48, "draw_dist": 5000, "fog_density": 0.0006,
		"fog_particles": true, "fog_particle_count": 150
	},
	"ultra": {
		"grass_count": 200000, "shadows": true, "shadow_res": 2048, "bloom": true,
		"bloom_strength": 0.5, "pixel_ratio": 2.0, "cloud_count": 28, "rain_count": 12000,
		"terrain_seg": 64, "draw_dist": 8000, "fog_density": 0.0004,
		"fog_particles": true, "fog_particle_count": 200
	},
}

# --- GAME RUNNING STATE ---
var game_started: bool = false

func get_grass_count_for_chunk(dist: int) -> int:
	var base := int(gfx["grass_count"] / 12)
	if dist <= 0:
		return base
	elif dist <= 1:
		return int(base * 0.6)
	elif dist <= 2:
		return int(base * 0.25)
	return int(base * 0.1)

func apply_preset(preset_name: String) -> void:
	if preset_name in PRESETS:
		var p: Dictionary = PRESETS[preset_name]
		for key in p:
			gfx[key] = p[key]

func cycle_weather() -> void:
	current_weather = (current_weather + 1) % WEATHER_NAMES.size()
