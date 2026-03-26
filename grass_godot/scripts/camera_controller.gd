extends Camera3D
## Orbit camera with WASD movement, mouse drag, scroll zoom, touch support

var dragging := false
var last_mouse_pos := Vector2.ZERO
var pinching := false
var last_pinch_dist := 0.0

func _ready() -> void:
	position = Vector3(0, 20, 45)

func _unhandled_input(event: InputEvent) -> void:
	# Mouse drag for orbit
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			last_mouse_pos = event.position
		# Mouse scroll for zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			Config.cam_dist = max(8.0, Config.cam_dist - 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			Config.cam_dist = min(200.0, Config.cam_dist + 3.0)

	if event is InputEventMouseMotion and dragging:
		var delta := event.position - last_mouse_pos
		Config.cam_angle_h -= delta.x * 0.005
		Config.cam_angle_v = clamp(Config.cam_angle_v + delta.y * 0.005, -0.1, 1.2)
		last_mouse_pos = event.position

	# Touch controls
	if event is InputEventScreenTouch:
		if event.pressed:
			dragging = true
			last_mouse_pos = event.position
		else:
			dragging = false
			pinching = false

	if event is InputEventScreenDrag and not pinching:
		var delta := event.position - last_mouse_pos
		Config.cam_angle_h -= delta.x * 0.005
		Config.cam_angle_v = clamp(Config.cam_angle_v + delta.y * 0.005, -0.1, 1.2)
		last_mouse_pos = event.position

func _process(delta: float) -> void:
	if not Config.game_started:
		return

	# WASD movement
	var move_speed := 25.0 * delta
	var forward := Vector3(-sin(Config.cam_angle_h), 0, -cos(Config.cam_angle_h))
	var right := Vector3(forward.z, 0, -forward.x)

	if Input.is_action_pressed("move_forward"):
		Config.cam_target += forward * move_speed
	if Input.is_action_pressed("move_back"):
		Config.cam_target -= forward * move_speed
	if Input.is_action_pressed("move_left"):
		Config.cam_target -= right * move_speed
	if Input.is_action_pressed("move_right"):
		Config.cam_target += right * move_speed

	# Ground collider — target always above terrain
	var terrain_y := Noise.get_terrain_height(Config.cam_target.x, Config.cam_target.z)
	Config.cam_target.y = terrain_y + 2.0

	# Position camera on orbit
	var cx := Config.cam_target.x + sin(Config.cam_angle_h) * Config.cam_dist * cos(Config.cam_angle_v)
	var cy := Config.cam_target.y + Config.cam_dist * sin(Config.cam_angle_v)
	var cz := Config.cam_target.z + cos(Config.cam_angle_h) * Config.cam_dist * cos(Config.cam_angle_v)

	# Camera ground collider
	var cam_terrain_y := Noise.get_terrain_height(cx, cz)
	var final_cy := max(cy, cam_terrain_y + 1.0)

	var target_pos := Vector3(cx, final_cy, cz)
	position = position.lerp(target_pos, 0.08)
	look_at(Config.cam_target, Vector3.UP)
