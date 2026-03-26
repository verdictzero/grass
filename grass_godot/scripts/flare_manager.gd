extends Node3D
## Sun & Moon lens flares — port of js/flare.js
## Simplified for Godot: glow sprites positioned near sun/moon

var sun_flare_sprite: Sprite3D
var moon_flare_sprite: Sprite3D
var sun_streak_sprite: Sprite3D
var moon_streak_sprite: Sprite3D
var flare_texture: ImageTexture
var streak_texture: ImageTexture

func _ready() -> void:
	_create_flare_textures()
	_create_flares()

func _create_flare_textures() -> void:
	# Central glow texture
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := float(size) / 2.0

	for y in range(size):
		for x in range(size):
			var dx := float(x) - center
			var dy := float(y) - center
			var dist := sqrt(dx * dx + dy * dy) / center
			var alpha := maxf(0.0, 1.0 - dist)
			alpha = alpha * alpha  # quadratic falloff
			var r := lerpf(1.0, 1.0, dist)
			var g := lerpf(1.0, 0.8, dist)
			var b := lerpf(1.0, 0.4, dist)
			img.set_pixel(x, y, Color(r, g, b, alpha * 0.6))

	flare_texture = ImageTexture.create_from_image(img)

	# Streak texture (horizontal gradient)
	var streak_size := 256
	var streak_img := Image.create(streak_size, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(streak_size):
			var t := float(x) / float(streak_size)
			var center_dist := absf(t - 0.5) * 2.0
			var alpha := maxf(0.0, 1.0 - center_dist * center_dist) * 0.3
			var vy := absf(float(y) - 16.0) / 16.0
			alpha *= maxf(0.0, 1.0 - vy * vy)
			streak_img.set_pixel(x, y, Color(1.0, 0.9, 0.7, alpha))

	streak_texture = ImageTexture.create_from_image(streak_img)

func _create_flares() -> void:
	# Sun flare
	sun_flare_sprite = Sprite3D.new()
	sun_flare_sprite.texture = flare_texture
	sun_flare_sprite.pixel_size = 0.5
	sun_flare_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sun_flare_sprite.transparent = true
	sun_flare_sprite.no_depth_test = true
	sun_flare_sprite.render_priority = 100
	sun_flare_sprite.modulate = Color(1.0, 0.87, 0.53, 0.0)
	add_child(sun_flare_sprite)

	# Sun streak
	sun_streak_sprite = Sprite3D.new()
	sun_streak_sprite.texture = streak_texture
	sun_streak_sprite.pixel_size = 1.0
	sun_streak_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sun_streak_sprite.transparent = true
	sun_streak_sprite.no_depth_test = true
	sun_streak_sprite.render_priority = 100
	sun_streak_sprite.modulate = Color(1.0, 0.8, 0.4, 0.0)
	add_child(sun_streak_sprite)

	# Moon flare (smaller/dimmer)
	moon_flare_sprite = Sprite3D.new()
	moon_flare_sprite.texture = flare_texture
	moon_flare_sprite.pixel_size = 0.25
	moon_flare_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	moon_flare_sprite.transparent = true
	moon_flare_sprite.no_depth_test = true
	moon_flare_sprite.render_priority = 100
	moon_flare_sprite.modulate = Color(0.67, 0.73, 0.93, 0.0)
	add_child(moon_flare_sprite)

	# Moon streak
	moon_streak_sprite = Sprite3D.new()
	moon_streak_sprite.texture = streak_texture
	moon_streak_sprite.pixel_size = 0.4
	moon_streak_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	moon_streak_sprite.transparent = true
	moon_streak_sprite.no_depth_test = true
	moon_streak_sprite.render_priority = 100
	moon_streak_sprite.modulate = Color(0.53, 0.6, 0.8, 0.0)
	add_child(moon_streak_sprite)

func update_flares(dt: float, camera: Camera3D) -> void:
	_update_flare_group(sun_flare_sprite, sun_streak_sprite, Config.sun_dir, true, dt, camera)
	_update_flare_group(moon_flare_sprite, moon_streak_sprite, Config.moon_dir, false, dt, camera)

func _update_flare_group(flare: Sprite3D, streak: Sprite3D, dir: Vector3, is_sun: bool, dt: float, camera: Camera3D) -> void:
	if not flare or not camera:
		return

	var cam_fwd := -camera.global_transform.basis.z
	var dot_view := cam_fwd.dot(dir.normalized())

	var overcast: float = Config.w_val["overcast"]
	var visible := (is_sun and Config.sun_dir.y > -0.05) or (not is_sun and Config.sun_dir.y < 0.05)

	var intensity := maxf(0.0, dot_view) if visible else 0.0
	intensity *= (1.0 - overcast * 0.9)
	if not is_sun:
		intensity *= (1.0 - Config.day_factor)

	# Check if on screen
	var world_pos := dir * 850.0 + Config.cam_target
	if not camera.is_position_behind(world_pos):
		var screen_pos := camera.unproject_position(world_pos)
		var viewport_size := camera.get_viewport().get_visible_rect().size
		if screen_pos.x < -viewport_size.x * 0.2 or screen_pos.x > viewport_size.x * 1.2 or \
		   screen_pos.y < -viewport_size.y * 0.2 or screen_pos.y > viewport_size.y * 1.2:
			intensity = 0.0
	else:
		intensity = 0.0

	var fade_speed := 4.0

	# Flare
	var target_op := intensity * (0.3 if is_sun else 0.15)
	flare.modulate.a += (target_op - flare.modulate.a) * dt * fade_speed
	flare.position = dir * 840.0 + Config.cam_target

	# Streak
	if streak:
		var streak_target_op := intensity * (0.2 if is_sun else 0.08)
		streak.modulate.a += (streak_target_op - streak.modulate.a) * dt * fade_speed
		streak.position = dir * 840.0 + Config.cam_target
