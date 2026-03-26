extends Node3D
## Multi-layer cloud system — port of js/clouds.js

var cloud_shader: Shader
var cloud_layers := { "high": [], "mid": [], "low": [] }

func _ready() -> void:
	cloud_shader = preload("res://shaders/cloud.gdshader")

func create_cloud_plane(seed_val: float, y: float, size_min: float, size_max: float, spread_x: float, spread_z: float) -> MeshInstance3D:
	var size := size_min + randf() * (size_max - size_min)
	var height_ratio := 0.4 + randf() * 0.5

	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(size, size * height_ratio)

	var mat := ShaderMaterial.new()
	mat.shader = cloud_shader
	mat.render_priority = -1
	mat.set_shader_parameter("u_time", 0.0)
	mat.set_shader_parameter("u_overcast", 0.0)
	mat.set_shader_parameter("u_seed", seed_val)
	mat.set_shader_parameter("u_day_factor", 1.0)
	mat.set_shader_parameter("u_layer_dark", 0.0)

	var instance := MeshInstance3D.new()
	instance.mesh = plane_mesh
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = 2000.0

	# Random rotation around Y
	instance.rotation.z = randf() * TAU

	instance.position = Vector3(
		(randf() - 0.5) * spread_x,
		y + randf() * 20.0,
		(randf() - 0.5) * spread_z
	)

	instance.set_meta("speed", 1.0 + randf() * 3.0)
	instance.set_meta("base_y", instance.position.y)
	instance.set_meta("spread_x", spread_x)

	return instance

func create_clouds() -> void:
	# Clear existing
	for layer_name in cloud_layers:
		for c in cloud_layers[layer_name]:
			c.queue_free()
		cloud_layers[layer_name].clear()

	var count: int = Config.gfx["cloud_count"]

	# High cirrus
	var high_count := int(count * 0.25)
	for i in range(high_count):
		var c := create_cloud_plane(randf() * 100.0, 130.0 + randf() * 40.0, 200.0, 400.0, 1200.0, 1200.0)
		c.set_meta("speed", 3.0 + randf() * 5.0)
		add_child(c)
		cloud_layers["high"].append(c)

	# Mid cumulus
	var mid_count := int(count * 0.5)
	for i in range(mid_count):
		var c := create_cloud_plane(randf() * 100.0, 65.0 + randf() * 35.0, 120.0, 250.0, 1000.0, 1000.0)
		add_child(c)
		cloud_layers["mid"].append(c)

	# Low stratus
	var low_count := int(count * 0.25)
	for i in range(low_count):
		var c := create_cloud_plane(randf() * 100.0, 35.0 + randf() * 20.0, 150.0, 300.0, 800.0, 800.0)
		c.set_meta("speed", 0.5 + randf() * 1.5)
		add_child(c)
		cloud_layers["low"].append(c)

func update_clouds(dt: float) -> void:
	var overcast: float = Config.w_val["overcast"]

	_update_layer(cloud_layers["high"], 0.0, -1.0, dt)
	_update_layer(cloud_layers["mid"], Config.w_val["cloud_dark"] * 0.5, -1.0, dt)
	_update_layer(cloud_layers["low"], Config.w_val["cloud_dark"], 0.3, dt)

func _update_layer(layer: Array, layer_dark: float, vis_overcast: float, dt: float) -> void:
	var overcast: float = Config.w_val["overcast"]

	for c in layer:
		if not is_instance_valid(c):
			continue

		var speed: float = c.get_meta("speed")
		var base_y: float = c.get_meta("base_y")
		var spread_x: float = c.get_meta("spread_x")

		# Move with wind
		c.position.x += speed * dt * (1.0 + Config.wind_strength)
		var half := spread_x / 2.0
		if c.position.x > Config.cam_target.x + half:
			c.position.x = Config.cam_target.x - half
		if c.position.x < Config.cam_target.x - half:
			c.position.x = Config.cam_target.x + half

		# Follow camera Z loosely
		c.position.z += (Config.cam_target.z - c.position.z) * 0.001

		# Gentle bobbing
		c.position.y = base_y + sin(Config.real_time * 0.2 + c.position.z * 0.008) * 3.0

		# Uniforms
		if c.material_override:
			var mat: ShaderMaterial = c.material_override
			mat.set_shader_parameter("u_time", Config.real_time)
			mat.set_shader_parameter("u_overcast", overcast)
			mat.set_shader_parameter("u_day_factor", Config.day_factor)
			mat.set_shader_parameter("u_layer_dark", layer_dark)

		# Low clouds only visible during storms
		if vis_overcast >= 0.0:
			c.visible = overcast > vis_overcast
