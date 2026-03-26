extends Node3D
## Tornado funnel effect — port of js/tornado.js

const TORNADO_PARTICLES := 800

var tornado_system: GPUParticles3D
var tornado_mesh: MultiMeshInstance3D
var particle_offsets: PackedFloat32Array
var particle_heights: PackedFloat32Array

func create_tornado() -> void:
	if tornado_mesh:
		tornado_mesh.queue_free()
		tornado_mesh = null

	# Use MultiMesh for manual particle placement (more control than GPUParticles)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)

	var draw_mat := StandardMaterial3D.new()
	draw_mat.albedo_color = Color(0.333, 0.333, 0.333, 0.4)
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = draw_mat

	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.instance_count = TORNADO_PARTICLES
	multi_mesh.mesh = quad

	particle_offsets = PackedFloat32Array()
	particle_heights = PackedFloat32Array()
	particle_offsets.resize(TORNADO_PARTICLES)
	particle_heights.resize(TORNADO_PARTICLES)

	for i in range(TORNADO_PARTICLES):
		var h := randf()
		var angle := randf() * TAU
		particle_heights[i] = h
		particle_offsets[i] = angle

		var t := Transform3D()
		t.origin = Vector3(0, h * 80.0, 0)
		var s := 0.5 + randf() * 2.0
		t = t.scaled(Vector3(s, s, s))
		multi_mesh.set_instance_transform(i, t)

	tornado_mesh = MultiMeshInstance3D.new()
	tornado_mesh.multimesh = multi_mesh
	tornado_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tornado_mesh.extra_cull_margin = 200.0
	add_child(tornado_mesh)

func destroy_tornado() -> void:
	if tornado_mesh:
		tornado_mesh.queue_free()
		tornado_mesh = null

func update_tornado(dt: float) -> void:
	if Config.current_weather != Config.Weather.TORNADO or not Config.tornado_active:
		if tornado_mesh:
			destroy_tornado()
		return

	if not tornado_mesh:
		create_tornado()

	# Wander slowly
	if Config.tornado_pos.distance_to(Config.tornado_wander_target) < 5.0:
		Config.tornado_wander_target = Vector3(
			Config.cam_target.x + (randf() - 0.5) * 400.0,
			0.0,
			Config.cam_target.z + (randf() - 0.5) * 400.0
		)

	var wander_dir := (Config.tornado_wander_target - Config.tornado_pos).normalized()
	var wander_speed := 15.0 * dt
	Config.tornado_pos.x += wander_dir.x * wander_speed
	Config.tornado_pos.z += wander_dir.z * wander_speed
	Config.tornado_pos.y = Noise.get_terrain_height(Config.tornado_pos.x, Config.tornado_pos.z)

	# Rotate
	Config.tornado_angle += dt * 4.0

	# Update particle positions
	if tornado_mesh and tornado_mesh.multimesh:
		var mm := tornado_mesh.multimesh
		for i in range(TORNADO_PARTICLES):
			var h := particle_heights[i]
			var angle := particle_offsets[i] + Config.tornado_angle * (1.0 + h * 0.5)

			# Funnel shape: narrow at bottom, wider at top
			var radius := 3.0 + h * h * 35.0
			var noise_r := sin(angle * 3.0 + Config.real_time) * 2.0 * h

			var px := Config.tornado_pos.x + cos(angle) * (radius + noise_r)
			var py := Config.tornado_pos.y + h * 80.0
			var pz := Config.tornado_pos.z + sin(angle) * (radius + noise_r)

			var t := Transform3D()
			t.origin = Vector3(px, py, pz)
			mm.set_instance_transform(i, t)

	# Pulsing opacity
	if tornado_mesh and tornado_mesh.multimesh and tornado_mesh.multimesh.mesh:
		var mesh_res: QuadMesh = tornado_mesh.multimesh.mesh
		if mesh_res.material:
			var mat: StandardMaterial3D = mesh_res.material
			mat.albedo_color.a = 0.3 + sin(Config.real_time * 2.0) * 0.1
