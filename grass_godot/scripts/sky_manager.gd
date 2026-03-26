extends Node3D
## Sky dome, sun sphere, moon sphere

var sky_dome: MeshInstance3D
var sun_sphere: MeshInstance3D
var moon_sphere: MeshInstance3D
var sky_material: ShaderMaterial

func _ready() -> void:
	create_sky()

func create_sky() -> void:
	# Sky dome — large sphere rendered from inside
	var sky_mesh := SphereMesh.new()
	sky_mesh.radius = 900.0
	sky_mesh.height = 1800.0
	sky_mesh.radial_segments = 32
	sky_mesh.rings = 32

	sky_material = ShaderMaterial.new()
	sky_material.shader = preload("res://shaders/sky.gdshader")
	sky_material.set_shader_parameter("u_sun_pos", Vector3(0, 1, 0))
	sky_material.set_shader_parameter("u_time", 0.0)
	sky_material.set_shader_parameter("u_overcast", 0.0)
	sky_material.set_shader_parameter("u_snow", 0.0)

	sky_dome = MeshInstance3D.new()
	sky_dome.mesh = sky_mesh
	sky_dome.material_override = sky_material
	# Extra cull margin so it doesn't get frustum culled
	sky_dome.extra_cull_margin = 10000.0
	add_child(sky_dome)

	# Sun sphere
	var sun_mesh := SphereMesh.new()
	sun_mesh.radius = 18.0
	sun_mesh.height = 36.0
	sun_mesh.radial_segments = 16
	sun_mesh.rings = 16

	var sun_mat := StandardMaterial3D.new()
	sun_mat.albedo_color = Color(1.0, 0.93, 0.53)
	sun_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sun_mat.no_depth_test = true

	sun_sphere = MeshInstance3D.new()
	sun_sphere.mesh = sun_mesh
	sun_sphere.material_override = sun_mat
	sun_sphere.extra_cull_margin = 10000.0
	add_child(sun_sphere)

	# Moon sphere
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 12.0
	moon_mesh.height = 24.0
	moon_mesh.radial_segments = 16
	moon_mesh.rings = 16

	var moon_mat := StandardMaterial3D.new()
	moon_mat.albedo_color = Color(0.93, 0.96, 1.0)
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mat.no_depth_test = true

	moon_sphere = MeshInstance3D.new()
	moon_sphere.mesh = moon_mesh
	moon_sphere.material_override = moon_mat
	moon_sphere.extra_cull_margin = 10000.0
	add_child(moon_sphere)

func update_sky(_dt: float) -> void:
	sky_material.set_shader_parameter("u_sun_pos", Config.sun_dir)
	sky_material.set_shader_parameter("u_time", Config.real_time)

	# Smooth overcast transition
	var cur_overcast: float = sky_material.get_shader_parameter("u_overcast")
	var target_overcast: float = Config.w_val["overcast"]
	sky_material.set_shader_parameter("u_overcast", cur_overcast + (target_overcast - cur_overcast) * _dt * 2.0)

	var cur_snow: float = sky_material.get_shader_parameter("u_snow")
	var target_snow: float = Config.w_val["snow"]
	sky_material.set_shader_parameter("u_snow", cur_snow + (target_snow - cur_snow) * _dt * 2.0)

	# Sun/moon positions & visibility
	sun_sphere.position = Config.sun_dir * 850.0
	sun_sphere.visible = Config.sun_dir.y > -0.05
	moon_sphere.position = Config.moon_dir * 850.0
	moon_sphere.visible = Config.sun_dir.y < 0.05

	# Sky dome follows camera
	sky_dome.position = Config.cam_target
	sun_sphere.position += Config.cam_target
	moon_sphere.position += Config.cam_target
