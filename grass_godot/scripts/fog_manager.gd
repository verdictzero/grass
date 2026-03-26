extends Node3D
## Procedural fog particle system — port of js/fog.js

var fog_texture: ImageTexture
var fog_sprites: Array = []

func create_fog_texture() -> void:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)

	for y in range(size):
		for x in range(size):
			var nx := float(x) / float(size)
			var ny := float(y) / float(size)

			# FBM noise for cloudy shape
			var val := 0.0
			var amp := 0.5
			var freq := 1.0
			for o in range(5):
				val += amp * Noise.smooth_noise(nx * freq * 4.0 + o * 7.3, ny * freq * 4.0 + o * 3.1)
				amp *= 0.5
				freq *= 2.0

			# Radial falloff
			var cx_val := nx - 0.5
			var cy_val := ny - 0.5
			var r := sqrt(cx_val * cx_val + cy_val * cy_val) * 2.0
			var radial := maxf(0.0, 1.0 - r * r)

			var alpha := clampf(val * radial, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	fog_texture = ImageTexture.create_from_image(img)

func create_fog_particles() -> void:
	# Clean up old
	for s in fog_sprites:
		if is_instance_valid(s):
			s.queue_free()
	fog_sprites.clear()

	if not Config.gfx["fog_particles"]:
		return
	if not fog_texture:
		create_fog_texture()

	var count: int = Config.gfx["fog_particle_count"]

	for i in range(count):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = fog_texture
		mat.albedo_color = Color(1, 1, 1, 0.06 + randf() * 0.06)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.no_depth_test = false

		var sprite := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var size_val := 15.0 + randf() * 35.0
		quad.size = Vector2(size_val, size_val * (0.3 + randf() * 0.4))
		quad.material = mat
		sprite.mesh = quad
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		sprite.position = Vector3(
			(randf() - 0.5) * 500.0,
			2.0 + randf() * 20.0,
			(randf() - 0.5) * 500.0
		)

		sprite.set_meta("base_y", sprite.position.y)
		sprite.set_meta("speed", 0.5 + randf() * 2.0)
		sprite.set_meta("phase", randf() * TAU)
		sprite.set_meta("drift_x", (randf() - 0.5) * 0.5)
		sprite.set_meta("base_opacity", mat.albedo_color.a)

		add_child(sprite)
		fog_sprites.append(sprite)

func update_fog_particles(dt: float) -> void:
	if not Config.gfx["fog_particles"] or fog_sprites.is_empty():
		return

	var fog_intensity: float = Config.w_val["fog_mult"]
	var is_snowy := Config.w_val["snow"] > 0.3

	for s in fog_sprites:
		if not is_instance_valid(s):
			continue

		var speed: float = s.get_meta("speed")
		var base_y: float = s.get_meta("base_y")
		var phase: float = s.get_meta("phase")
		var drift_x: float = s.get_meta("drift_x")
		var base_opacity: float = s.get_meta("base_opacity")

		# Move with wind
		s.position.x += (cos(Config.wind_direction) * Config.wind_strength * speed + drift_x) * dt * 3.0
		s.position.z += (sin(Config.wind_direction) * Config.wind_strength * speed) * dt * 3.0

		# Gentle vertical bob
		s.position.y = base_y + sin(Config.real_time * 0.3 + phase) * 2.0

		# Re-center around camera
		var dx := s.position.x - Config.cam_target.x
		var dz := s.position.z - Config.cam_target.z
		if absf(dx) > 250.0 or absf(dz) > 250.0:
			s.position.x = Config.cam_target.x + (randf() - 0.5) * 400.0
			s.position.z = Config.cam_target.z + (randf() - 0.5) * 400.0
			s.position.y = 2.0 + randf() * 20.0
			s.set_meta("base_y", s.position.y)

		# Opacity based on weather
		var target_op := base_opacity * fog_intensity * (1.5 if is_snowy else 1.0)
		if s.mesh and s.mesh.material:
			var mat: StandardMaterial3D = s.mesh.material
			mat.albedo_color.a += (target_op - mat.albedo_color.a) * dt * 2.0

			# Snow-tinted fog
			if is_snowy:
				mat.albedo_color = mat.albedo_color.lerp(Color(0.9, 0.92, 0.95, mat.albedo_color.a), dt)
			else:
				mat.albedo_color = mat.albedo_color.lerp(Color(1, 1, 1, mat.albedo_color.a), dt)
