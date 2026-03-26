extends CanvasLayer
## In-game HUD — time, weather, score, speed controls

signal weather_cycle_requested
signal speed_changed(speed: float)
signal settings_requested

@onready var blade_count_label: Label = $HUD/StatsPanel/BladeCount
@onready var avg_height_label: Label = $HUD/StatsPanel/AvgHeight
@onready var grass_score_label: Label = $HUD/StatsPanel/GrassScore
@onready var time_display: Label = $HUD/EnvPanel/TimeDisplay
@onready var weather_display: Label = $HUD/EnvPanel/WeatherDisplay
@onready var wind_display: Label = $HUD/EnvPanel/WindDisplay
@onready var weather_button: Button = $WeatherButton
@onready var settings_button: Button = $SettingsButton
@onready var fps_label: Label = $FPSCounter
@onready var speed_buttons: HBoxContainer = $SpeedControl/SpeedButtons

var fps_frames := 0
var fps_time := 0.0

func _ready() -> void:
	visible = false
	weather_button.pressed.connect(func(): weather_cycle_requested.emit())
	settings_button.pressed.connect(func(): settings_requested.emit())

	# Speed buttons
	for btn in speed_buttons.get_children():
		if btn is Button:
			btn.pressed.connect(_on_speed_button.bind(btn))

func _on_speed_button(btn: Button) -> void:
	var spd := float(btn.get_meta("speed"))
	Config.time_speed = spd
	speed_changed.emit(spd)
	# Update active state
	for b in speed_buttons.get_children():
		if b is Button:
			b.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5) if b == btn else Color.WHITE)

func update_hud() -> void:
	if not visible:
		return

	# Time display
	var hours := int(Config.game_time * 24.0)
	var mins := int((Config.game_time * 24.0 - float(hours)) * 60.0)
	var ampm := "PM" if hours >= 12 else "AM"
	var h12 := hours % 12
	if h12 == 0:
		h12 = 12
	if time_display:
		time_display.text = "%d:%02d %s" % [h12, mins, ampm]

	# Stats
	var total_blades := 0
	var grown_count := 0
	# These come from the grass manager via Config
	if blade_count_label:
		blade_count_label.text = str(Config.grass_growth_rate)
	if avg_height_label:
		var avg := 0.0
		if Config.grass_growth_rate > 0:
			avg = Config.total_grass_score / float(maxi(1, Config.grass_growth_rate)) * 0.2
		avg_height_label.text = "%.1f cm" % avg
	if grass_score_label:
		grass_score_label.text = str(Config.total_grass_score)

	# Weather
	if weather_display:
		weather_display.text = "%s %s" % [Config.WEATHER_ICONS[Config.current_weather], Config.WEATHER_NAMES[Config.current_weather]]
	if weather_button:
		weather_button.text = "%s %s" % [Config.WEATHER_ICONS[Config.current_weather], Config.WEATHER_NAMES[Config.current_weather].to_upper()]

	# Wind
	var wind_names := ["Calm", "Breeze", "Windy", "Gusty", "INTENSE", "EXTREME"]
	var wi := mini(5, int(Config.wind_strength * 4.0))
	if wind_display:
		wind_display.text = wind_names[wi]

	# FPS
	if fps_label and Config.gfx["show_fps"]:
		fps_label.visible = true
	elif fps_label:
		fps_label.visible = false
