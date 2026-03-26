extends Node3D
## MultiMesh grass with health/growth system — port of js/grass.js

var grass_shader: Shader
var blade_mesh: ArrayMesh
var terrain_manager: Node  # set by main.gd

func _ready() -> void:
	grass_shader = preload("res://shaders/grass.gdshader")
	blade_mesh = _create_blade_mesh()

func _create_blade_mesh() -> ArrayMesh:
	# 9 vertices forming 3 triangles (same as Three.js version)
	var verts := PackedVector3Array([
		Vector3(-0.06, 0, 0), Vector3(0.06, 0, 0), Vector3(0.04, 0.5, 0),
		Vector3(-0.06, 0, 0), Vector3(0.04, 0.5, 0), Vector3(-0.04, 0.5, 0),
		Vector3(-0.04, 0.5, 0), Vector3(0.04, 0.5, 0), Vector3(0.0, 1.0, 0),
	])
	var uvs := PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.5),
		Vector2(0, 0), Vector2(1, 0.5), Vector2(0, 0.5),
		Vector2(0, 0.5), Vector2(1, 0.5), Vector2(0.5, 1.0),
	])
	var normals := PackedVector3Array()
	for i in range(9):
		normals.append(Vector3(0, 0, 1))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func create_chunk_grass(chunk_data: Dictionary, dist: int) -> void:
	var count := Config.get_grass_count_for_chunk(dist)
	if count == 0:
		return

	var cx: int = chunk_data["cx"]
	var cz: int = chunk_data["cz"]
	var offset_x := float(cx) * float(Config.CHUNK_SIZE)
	var offset_z := float(cz) * float(Config.CHUNK_SIZE)
	var chunk_size := float(Config.CHUNK_SIZE)

	# Create MultiMesh
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_custom_data = true
	multi_mesh.instance_count = count
	multi_mesh.mesh = blade_mesh

	var blades := []
	blades.resize(count)
	var health_data := PackedFloat32Array()
	health_data.resize(count)

	for i in range(count):
		var lx := (randf() - 0.5) * chunk_size
		var lz := (randf() - 0.5) * chunk_size
		var wx := lx + offset_x
		var wz := lz + offset_z
		var wy := Noise.get_terrain_height(wx, wz)
		var rot := randf() * TAU
		var base_scale := 0.3 + randf() * 0.4
		var max_scale := 2.0 + randf() * 4.0
		var grow_speed := 0.005 + randf() * 0.02

		blades[i] = {
			"x": wx, "y": wy, "z": wz, "rot": rot,
			"scale": base_scale, "max_scale": max_scale, "grow_speed": grow_speed,
			"grown": false, "health": 1.0
		}
		health_data[i] = 1.0

		# Set instance transform
		var t := Transform3D()
		t = t.rotated(Vector3.UP, rot)
		t = t.scaled(Vector3(1.0, base_scale, 1.0))
		t.origin = Vector3(wx, wy, wz)
		multi_mesh.set_instance_transform(i, t)
		multi_mesh.set_instance_custom_data(i, Color(1.0, 0, 0, 0))  # health in R channel

	# Create material
	var mat := ShaderMaterial.new()
	mat.shader = grass_shader
	mat.set_shader_parameter("u_time", 0.0)
	mat.set_shader_parameter("u_wind_str", 0.3)
	mat.set_shader_parameter("u_wind_dir", Vector2(1.0, 0.5))
	mat.set_shader_parameter("u_sun_dir", Vector3(0, 1, 0))
	mat.set_shader_parameter("u_day_factor", 1.0)
	mat.set_shader_parameter("u_snow_cover", 0.0)

	var mesh_instance := MultiMeshInstance3D.new()
	mesh_instance.multimesh = multi_mesh
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Config.gfx["shadows"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.extra_cull_margin = 100.0
	add_child(mesh_instance)

	chunk_data["grass_mesh"] = mesh_instance
	chunk_data["blades"] = blades
	chunk_data["health_data"] = health_data

func update_grass(dt: float) -> void:
	if not terrain_manager:
		return

	var is_raining := Config.w_val["rain"] > 0.3
	var grow_mult := (3.0 if is_raining else 1.0) * (Config.day_factor * 0.7 + 0.3) * Config.time_speed

	var total_grown := 0
	var total_height := 0.0
	var total_blades := 0

	for key in terrain_manager.chunks:
		var chunk_data: Dictionary = terrain_manager.chunks[key]
		if not chunk_data["grass_mesh"]:
			continue

		var blades: Array = chunk_data["blades"]
		var mesh_instance: MultiMeshInstance3D = chunk_data["grass_mesh"]
		var multi_mesh: MultiMesh = mesh_instance.multimesh
		var matrix_changed := false
		var health_changed := false
		var frame_mod := int(Config.real_time) % 4

		for i in range(blades.size()):
			var b: Dictionary = blades[i]
			total_blades += 1

			# Health changes
			_update_blade_health(b, dt)

			# Sync health to custom data
			if absf(multi_mesh.get_instance_custom_data(i).r - b["health"]) > 0.01:
				multi_mesh.set_instance_custom_data(i, Color(b["health"], 0, 0, 0))
				health_changed = true

			# Growth (only if alive)
			if b["health"] > 0.1 and b["scale"] < b["max_scale"]:
				b["scale"] = minf(b["max_scale"], b["scale"] + b["grow_speed"] * grow_mult * dt * b["health"])
				if i % 4 == frame_mod:
					var t := Transform3D()
					t = t.rotated(Vector3.UP, b["rot"])
					t = t.scaled(Vector3(1.0, b["scale"], 1.0))
					t.origin = Vector3(b["x"], b["y"], b["z"])
					multi_mesh.set_instance_transform(i, t)
					matrix_changed = true

			if b["scale"] >= b["max_scale"] and not b["grown"]:
				b["grown"] = true
			if b["grown"] and b["health"] > 0.5:
				total_grown += 1
			total_height += b["scale"]

		# Update shader uniforms
		if mesh_instance.material_override:
			var mat: ShaderMaterial = mesh_instance.material_override
			mat.set_shader_parameter("u_time", Config.real_time)
			mat.set_shader_parameter("u_wind_str", Config.wind_strength)
			mat.set_shader_parameter("u_wind_dir", Vector2(cos(Config.wind_direction), sin(Config.wind_direction)))
			mat.set_shader_parameter("u_sun_dir", Config.sun_dir)
			mat.set_shader_parameter("u_day_factor", Config.day_factor)
			mat.set_shader_parameter("u_snow_cover", Config.snow_cover)

	# Global score
	if total_blades > 0:
		Config.total_grass_score = int(total_grown * 0.5 + (total_height / float(total_blades)) * 100.0)
		Config.grass_growth_rate = total_grown

func _update_blade_health(b: Dictionary, dt: float) -> void:
	var tdt := dt * Config.time_speed
	var health_delta := 0.0

	# Rain heals
	if Config.w_val["rain"] > 0.3:
		health_delta += 0.05 * tdt

	# Drought kills slowly
	if Config.time_since_rain > 300.0:
		health_delta -= 0.01 * tdt * minf(1.0, (Config.time_since_rain - 300.0) / 600.0)

	# Snow causes dormancy
	if Config.w_val["snow"] > 0.3 and b["health"] > 0.3:
		health_delta -= 0.02 * tdt

	# Tornado destruction
	if Config.tornado_active and Config.current_weather == Config.Weather.TORNADO:
		var dx := b["x"] - Config.tornado_pos.x
		var dz := b["z"] - Config.tornado_pos.z
		var dist := sqrt(dx * dx + dz * dz)
		if dist < 40.0:
			health_delta -= 0.5 * tdt * (1.0 - dist / 40.0)

	# Hurricane widespread damage
	if Config.current_weather == Config.Weather.HURRICANE:
		health_delta -= 0.03 * tdt

	# Clear weather slow recovery
	if Config.current_weather == Config.Weather.CLEAR and Config.w_val["rain"] < 0.1:
		health_delta += 0.01 * tdt

	b["health"] = clampf(b["health"] + health_delta, 0.0, 1.0)

func damage_grass_in_radius(wx: float, wz: float, radius: float, damage: float) -> void:
	if not terrain_manager:
		return
	for key in terrain_manager.chunks:
		var chunk_data: Dictionary = terrain_manager.chunks[key]
		if not chunk_data["grass_mesh"]:
			continue
		var blades: Array = chunk_data["blades"]
		for i in range(blades.size()):
			var b: Dictionary = blades[i]
			var dx := b["x"] - wx
			var dz := b["z"] - wz
			var dist := sqrt(dx * dx + dz * dz)
			if dist < radius:
				var falloff := 1.0 - dist / radius
				b["health"] = maxf(0.0, b["health"] - damage * falloff)
