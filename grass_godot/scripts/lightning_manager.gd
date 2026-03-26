extends Node3D
## Lightning bolt system — port of js/lightning.js

var lightning_bolts: Array = []  # { mesh: MeshInstance3D, glow: MeshInstance3D, life: float }
var grass_manager: Node  # set by main.gd

func update_lightning(dt: float) -> void:
	# Only during thunderstorm
	if Config.current_weather != Config.Weather.THUNDERSTORM:
		_clear_lightning_bolts()
		return

	Config.lightning_timer -= dt
	if Config.lightning_timer <= 0.0:
		_strike_lightning()
		Config.lightning_timer = 3.0 + randf() * 10.0

	# Fade out existing bolts
	var i := lightning_bolts.size() - 1
	while i >= 0:
		var bolt: Dictionary = lightning_bolts[i]
		bolt["life"] -= dt
		if bolt["life"] <= 0.0:
			if bolt["mesh"]:
				bolt["mesh"].queue_free()
			if bolt["glow"]:
				bolt["glow"].queue_free()
			lightning_bolts.remove_at(i)
		else:
			var alpha := minf(1.0, bolt["life"] * 5.0)
			if bolt["mesh"] and bolt["mesh"].material_override:
				bolt["mesh"].material_override.albedo_color.a = alpha
			if bolt["glow"] and bolt["glow"].material_override:
				bolt["glow"].material_override.albedo_color.a = alpha * 0.3
		i -= 1

func _strike_lightning() -> void:
	var sx := Config.cam_target.x + (randf() - 0.5) * 300.0
	var sz := Config.cam_target.z + (randf() - 0.5) * 300.0
	var ground_y := Noise.get_terrain_height(sx, sz)
	var start_y := 70.0 + randf() * 30.0

	# Generate jagged bolt path
	var points: PackedVector3Array = []
	var segments := 12 + randi() % 8
	var cx := sx
	var cy := start_y
	var cz := sz

	points.append(Vector3(cx, cy, cz))

	for seg_i in range(1, segments + 1):
		var t := float(seg_i) / float(segments)
		cy = start_y + (ground_y - start_y) * t
		cx = sx + (randf() - 0.5) * 20.0 * (1.0 - t * 0.5)
		cz = sz + (randf() - 0.5) * 20.0 * (1.0 - t * 0.5)
		points.append(Vector3(cx, cy, cz))

	points[points.size() - 1].y = ground_y

	# Main bolt — using ImmediateMesh for lines
	var bolt_mesh := _create_bolt_mesh(points, Color(0.933, 0.933, 1.0, 1.0))
	add_child(bolt_mesh)

	# Glow (slightly larger, semi-transparent)
	var glow_mesh := _create_bolt_mesh(points, Color(0.667, 0.733, 1.0, 0.3))
	add_child(glow_mesh)

	lightning_bolts.append({ "mesh": bolt_mesh, "glow": glow_mesh, "life": 0.4 + randf() * 0.2 })

	# Branch bolts
	for seg_i in range(2, points.size() - 2):
		if randf() > 0.4:
			continue
		var branch_points: PackedVector3Array = [points[seg_i]]
		var bx := points[seg_i].x
		var by := points[seg_i].y
		var bz := points[seg_i].z
		var branch_len := 3 + randi() % 4
		for j in range(branch_len):
			bx += (randf() - 0.5) * 12.0
			by -= 3.0 + randf() * 5.0
			bz += (randf() - 0.5) * 12.0
			branch_points.append(Vector3(bx, by, bz))

		var branch_mesh := _create_bolt_mesh(branch_points, Color(0.8, 0.867, 1.0, 0.6))
		add_child(branch_mesh)
		lightning_bolts.append({ "mesh": branch_mesh, "glow": null, "life": 0.3 + randf() * 0.2 })

	# Flash effect
	Config.lightning_flash_time = 0.15

	# Damage grass at strike point
	if grass_manager:
		grass_manager.damage_grass_in_radius(sx, sz, 15.0, 1.0)

func _create_bolt_mesh(points: PackedVector3Array, color: Color) -> MeshInstance3D:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in points:
		im.surface_add_vertex(p)
	im.surface_end()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true

	var instance := MeshInstance3D.new()
	instance.mesh = im
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

func _clear_lightning_bolts() -> void:
	for bolt in lightning_bolts:
		if bolt["mesh"]:
			bolt["mesh"].queue_free()
		if bolt["glow"]:
			bolt["glow"].queue_free()
	lightning_bolts.clear()
