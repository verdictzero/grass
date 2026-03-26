extends CanvasLayer
## Settings drawer panel — quality presets, sliders, toggles

signal settings_changed
signal rebuild_requested

@onready var panel: Panel = $Panel
@onready var overlay: ColorRect = $Overlay
@onready var close_button: Button = $Panel/VBox/Header/CloseButton
@onready var preset_container: HBoxContainer = $Panel/VBox/ScrollContainer/Settings/PresetSection/PresetRow

# Sliders
@onready var grass_slider: HSlider = $Panel/VBox/ScrollContainer/Settings/RenderSection/GrassRow/GrassSlider
@onready var grass_value: Label = $Panel/VBox/ScrollContainer/Settings/RenderSection/GrassRow/GrassValue
@onready var draw_dist_slider: HSlider = $Panel/VBox/ScrollContainer/Settings/RenderSection/DrawDistRow/DrawDistSlider
@onready var draw_dist_value: Label = $Panel/VBox/ScrollContainer/Settings/RenderSection/DrawDistRow/DrawDistValue
@onready var bloom_str_slider: HSlider = $Panel/VBox/ScrollContainer/Settings/PostSection/BloomStrRow/BloomStrSlider
@onready var bloom_str_value: Label = $Panel/VBox/ScrollContainer/Settings/PostSection/BloomStrRow/BloomStrValue
@onready var cloud_slider: HSlider = $Panel/VBox/ScrollContainer/Settings/EnvSection/CloudRow/CloudSlider
@onready var cloud_value: Label = $Panel/VBox/ScrollContainer/Settings/EnvSection/CloudRow/CloudValue
@onready var rain_slider: HSlider = $Panel/VBox/ScrollContainer/Settings/EnvSection/RainRow/RainSlider
@onready var rain_value: Label = $Panel/VBox/ScrollContainer/Settings/EnvSection/RainRow/RainValue
@onready var fog_slider: HSlider = $Panel/VBox/ScrollContainer/Settings/EnvSection/FogRow/FogSlider
@onready var fog_value: Label = $Panel/VBox/ScrollContainer/Settings/EnvSection/FogRow/FogValue

# Toggles
@onready var shadows_toggle: CheckButton = $Panel/VBox/ScrollContainer/Settings/ShadowSection/ShadowToggleRow/ShadowsToggle
@onready var bloom_toggle: CheckButton = $Panel/VBox/ScrollContainer/Settings/PostSection/BloomToggleRow/BloomToggle
@onready var fps_toggle: CheckButton = $Panel/VBox/ScrollContainer/Settings/DebugSection/FPSRow/FPSToggle

var is_open := false

func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(close_drawer)
	if overlay:
		overlay.gui_input.connect(_on_overlay_input)

func open_drawer() -> void:
	is_open = true
	visible = true
	_sync_ui()

func close_drawer() -> void:
	is_open = false
	visible = false

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_drawer()

func _sync_ui() -> void:
	if grass_slider:
		grass_slider.value = Config.gfx["grass_count"]
		if grass_value:
			grass_value.text = "%dK" % int(Config.gfx["grass_count"] / 1000)
	if draw_dist_slider:
		draw_dist_slider.value = Config.gfx["draw_dist"]
		if draw_dist_value:
			draw_dist_value.text = str(Config.gfx["draw_dist"])
	if bloom_str_slider:
		bloom_str_slider.value = Config.gfx["bloom_strength"]
		if bloom_str_value:
			bloom_str_value.text = "%.2f" % Config.gfx["bloom_strength"]
	if cloud_slider:
		cloud_slider.value = Config.gfx["cloud_count"]
		if cloud_value:
			cloud_value.text = str(Config.gfx["cloud_count"])
	if rain_slider:
		rain_slider.value = Config.gfx["rain_count"]
		if rain_value:
			rain_value.text = "%dK" % int(Config.gfx["rain_count"] / 1000)
	if fog_slider:
		fog_slider.value = Config.gfx["fog_density"]
		if fog_value:
			fog_value.text = "%.4f" % Config.gfx["fog_density"]
	if shadows_toggle:
		shadows_toggle.button_pressed = Config.gfx["shadows"]
	if bloom_toggle:
		bloom_toggle.button_pressed = Config.gfx["bloom"]
	if fps_toggle:
		fps_toggle.button_pressed = Config.gfx["show_fps"]

func apply_preset(preset_name: String) -> void:
	Config.apply_preset(preset_name)
	_sync_ui()
	rebuild_requested.emit()
