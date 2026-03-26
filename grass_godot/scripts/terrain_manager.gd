extends Node3D
## Chunk-based infinite terrain generation

var chunks: Dictionary = {}  # key: "cx,cz" -> { terrain: MeshInstance3D, grass_mesh: MultiMeshInstance3D, ... }
var terrain_shader: Shader
var grass_manager: Node  # set by main.gd

func _ready() -> void:
	terrain_shader = preload("res://shaders/terrain.gdshader")

func create_chunk_terrain(cx: int, cz: int) -> MeshInstance3D:
	var seg: int = Config.gfx["terrain_seg"]
	var chunk_size: float = float(Config.CHUNK_SIZE)
	var offset_x := float(cx) * chunk_size
	var offset_z := float(cz) * chunk_size

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Generate grid vertices
	var vertices := []
	var normals := []
	var step_size := chunk_size / float(seg)

	for iz in range(seg + 1):
		for ix in range(seg + 1):
			var lx := -chunk_size / 2.0 + float(ix) * step_size
			var lz := -chunk_size / 2.0 + float(iz) * step_size
			var wx := lx + offset_x
			var wz := lz + offset_z
			var wy := Noise.get_terrain_height(wx, wz)
			vertices.append(Vector3(wx, wy, wz))

	# Compute normals per vertex
	for iz in range(seg + 1):
		for ix in range(seg + 1):
			var idx := iz * (seg + 1) + ix
			var pos := vertices[idx]
			# Sample neighboring heights for normal
			var hL := Noise.get_terrain_height(pos.x - 1.0, pos.z)
			var hR := Noise.get_terrain_height(pos.x + 1.0, pos.z)
			var hD := Noise.get_terrain_height(pos.x, pos.z - 1.0)
			var hU := Noise.get_terrain_height(pos.x, pos.z + 1.0)
			var normal := Vector3(hL - hR, 2.0, hD - hU).normalized()
			normals.append(normal)

	# Build triangles
	for iz in range(seg):
		for ix in range(seg):
			var i00 := iz * (seg + 1) + ix
			var i10 := i00 + 1
			var i01 := (iz + 1) * (seg + 1) + ix
			var i11 := i01 + 1

			# Triangle 1
			st.set_normal(normals[i00])
			st.set_uv(Vector2(float(ix) / float(seg), float(iz) / float(seg)))
			st.add_vertex(vertices[i00])

			st.set_normal(normals[i10])
			st.set_uv(Vector2(float(ix + 1) / float(seg), float(iz) / float(seg)))
			st.add_vertex(vertices[i10])

			st.set_normal(normals[i01])
			st.set_uv(Vector2(float(ix) / float(seg), float(iz + 1) / float(seg)))
			st.add_vertex(vertices[i01])

			# Triangle 2
			st.set_normal(normals[i10])
			st.set_uv(Vector2(float(ix + 1) / float(seg), float(iz) / float(seg)))
			st.add_vertex(vertices[i10])

			st.set_normal(normals[i11])
			st.set_uv(Vector2(float(ix + 1) / float(seg), float(iz + 1) / float(seg)))
			st.add_vertex(vertices[i11])

			st.set_normal(normals[i01])
			st.set_uv(Vector2(float(ix) / float(seg), float(iz + 1) / float(seg)))
			st.add_vertex(vertices[i01])

	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = terrain_shader
	mat.set_shader_parameter("u_sun_dir", Vector3(0, 1, 0))
	mat.set_shader_parameter("u_moon_dir", Vector3(0, -1, 0))
	mat.set_shader_parameter("u_day_factor", 1.0)
	mat.set_shader_parameter("u_snow_cover", 0.0)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)

	return mesh_instance

func create_chunk(cx: int, cz: int) -> void:
	var key := "%d,%d" % [cx, cz]
	if chunks.has(key):
		return

	var dist := maxi(absi(cx - Config.current_chunk_x), absi(cz - Config.current_chunk_z))
	var terrain := create_chunk_terrain(cx, cz)

	var chunk_data := {
		"cx": cx,
		"cz": cz,
		"terrain": terrain,
		"grass_mesh": null,
		"blades": [],
		"health_data": PackedFloat32Array(),
		"lod_dist": dist
	}

	# Create grass for this chunk
	if grass_manager:
		grass_manager.create_chunk_grass(chunk_data, dist)

	chunks[key] = chunk_data

func dispose_chunk(chunk_data: Dictionary) -> void:
	if chunk_data["terrain"]:
		chunk_data["terrain"].queue_free()
	if chunk_data["grass_mesh"]:
		chunk_data["grass_mesh"].queue_free()

func update_chunks() -> void:
	var ccx := int(floor((Config.cam_target.x + float(Config.CHUNK_SIZE) / 2.0) / float(Config.CHUNK_SIZE)))
	var ccz := int(floor((Config.cam_target.z + float(Config.CHUNK_SIZE) / 2.0) / float(Config.CHUNK_SIZE)))

	if ccx == Config.current_chunk_x and ccz == Config.current_chunk_z:
		return

	Config.current_chunk_x = ccx
	Config.current_chunk_z = ccz

	# Create needed chunks
	for dx in range(-Config.CHUNK_RENDER_DIST, Config.CHUNK_RENDER_DIST + 1):
		for dz in range(-Config.CHUNK_RENDER_DIST, Config.CHUNK_RENDER_DIST + 1):
			var key := "%d,%d" % [ccx + dx, ccz + dz]
			if not chunks.has(key):
				create_chunk(ccx + dx, ccz + dz)

	# Remove far chunks
	var remove_keys: Array[String] = []
	for key in chunks:
		var chunk_data: Dictionary = chunks[key]
		if absi(chunk_data["cx"] - ccx) > Config.CHUNK_RENDER_DIST + 1 or \
		   absi(chunk_data["cz"] - ccz) > Config.CHUNK_RENDER_DIST + 1:
			remove_keys.append(key)

	for key in remove_keys:
		dispose_chunk(chunks[key])
		chunks.erase(key)

func update_terrain_uniforms() -> void:
	for key in chunks:
		var chunk_data: Dictionary = chunks[key]
		if chunk_data["terrain"] and chunk_data["terrain"].material_override:
			var mat: ShaderMaterial = chunk_data["terrain"].material_override
			mat.set_shader_parameter("u_sun_dir", Config.sun_dir)
			mat.set_shader_parameter("u_moon_dir", Config.moon_dir)
			mat.set_shader_parameter("u_day_factor", Config.day_factor)
			mat.set_shader_parameter("u_snow_cover", Config.snow_cover)
