extends Node3D
## Rain & snow particle systems — port of js/weather.js rain/snow

var rain_particles: GPUParticles3D
var snow_particles: GPUParticles3D
var rain_material: ParticleProcessMaterial
var snow_material: ParticleProcessMaterial
var rain_draw_pass: QuadMesh
var snow_draw_pass: QuadMesh

func create_rain() -> void:
	if rain_particles:
		rain_particles.queue_free()
		rain_particles = null

	var count: int = Config.gfx["rain_count"]

	rain_material = ParticleProcessMaterial.new()
	rain_material.direction = Vector3(0, -1, 0)
	rain_material.spread = 5.0
	rain_material.initial_velocity_min = 30.0
	rain_material.initial_velocity_max = 55.0
	rain_material.gravity = Vector3(0, -30, 0)
	rain_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_material.emission_box_extents = Vector3(200, 60, 200)
	rain_material.lifetime_randomness = 0.3
	rain_material.color = Color(0.667, 0.8, 1.0, 0.0)  # starts transparent

	rain_draw_pass = QuadMesh.new()
	rain_draw_pass.size = Vector2(0.1, 0.8)

	var draw_mat := StandardMaterial3D.new()
	draw_mat.albedo_color = Color(0.667, 0.8, 1.0, 0.5)
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.no_depth_test = false
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	rain_draw_pass.material = draw_mat

	rain_particles = GPUParticles3D.new()
	rain_particles.amount = count
	rain_particles.lifetime = 3.0
	rain_particles.process_material = rain_material
	rain_particles.draw_pass_1 = rain_draw_pass
	rain_particles.visibility_aabb = AABB(Vector3(-250, -10, -250), Vector3(500, 150, 500))
	rain_particles.emitting = false
	add_child(rain_particles)

func create_snow() -> void:
	if snow_particles:
		snow_particles.queue_free()
		snow_particles = null

	var count := int(Config.gfx["rain_count"] * 0.6)

	snow_material = ParticleProcessMaterial.new()
	snow_material.direction = Vector3(0, -1, 0)
	snow_material.spread = 15.0
	snow_material.initial_velocity_min = 5.0
	snow_material.initial_velocity_max = 15.0
	snow_material.gravity = Vector3(0, -5, 0)
	snow_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	snow_material.emission_box_extents = Vector3(200, 50, 200)
	snow_material.lifetime_randomness = 0.4
	snow_material.color = Color(0.933, 0.957, 1.0, 0.0)

	snow_draw_pass = QuadMesh.new()
	snow_draw_pass.size = Vector2(0.6, 0.6)

	var draw_mat := StandardMaterial3D.new()
	draw_mat.albedo_color = Color(0.933, 0.957, 1.0, 0.6)
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	snow_draw_pass.material = draw_mat

	snow_particles = GPUParticles3D.new()
	snow_particles.amount = count
	snow_particles.lifetime = 8.0
	snow_particles.process_material = snow_material
	snow_particles.draw_pass_1 = snow_draw_pass
	snow_particles.visibility_aabb = AABB(Vector3(-250, -10, -250), Vector3(500, 150, 500))
	snow_particles.emitting = false
	add_child(snow_particles)

func update_rain_snow(_dt: float) -> void:
	# Rain
	if rain_particles:
		var target_opacity := minf(0.6, Config.w_val["rain"] * 0.3)
		rain_particles.emitting = target_opacity > 0.01
		rain_particles.position = Config.cam_target + Vector3(0, 40, 0)

		# Wind push
		if rain_material:
			var wind_push := Config.wind_strength * 8.0
			if Config.current_weather == Config.Weather.HURRICANE:
				wind_push = Config.wind_strength * 25.0
			rain_material.gravity = Vector3(
				cos(Config.wind_direction) * wind_push,
				-30.0,
				sin(Config.wind_direction) * wind_push
			)

		# Update draw material opacity
		if rain_draw_pass and rain_draw_pass.material:
			var mat: StandardMaterial3D = rain_draw_pass.material
			var cur_a := mat.albedo_color.a
			mat.albedo_color.a = cur_a + (target_opacity - cur_a) * _dt * 3.0

	# Snow
	if snow_particles:
		var target_opacity := 0.6 if Config.w_val["snow"] > 0.3 else 0.0
		snow_particles.emitting = target_opacity > 0.01
		snow_particles.position = Config.cam_target + Vector3(0, 30, 0)

		if snow_material:
			var wind_effect := Config.wind_strength * 2.0
			snow_material.gravity = Vector3(
				cos(Config.wind_direction) * wind_effect,
				-5.0,
				sin(Config.wind_direction) * wind_effect
			)

		if snow_draw_pass and snow_draw_pass.material:
			var mat: StandardMaterial3D = snow_draw_pass.material
			var cur_a := mat.albedo_color.a
			mat.albedo_color.a = cur_a + (target_opacity - cur_a) * _dt * 3.0

func rebuild_rain() -> void:
	create_rain()

func rebuild_snow() -> void:
	create_snow()
