extends Node3D
## How dark the sun's shadow is on each ground's court, for Arena.SHADE (the players' floor shadows on Low): the court
## seen from straight above in linear light (no tonemap curve, glow, grade or fog) with the sun and without it, which is
## all a shadow keeps (the ground's baked light). Run again after a re-bake (tools/bake_lighting):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 640x640 res://tests/shade_check.tscn

const EXPOSURE := 0.3   # keeps the sunlit court under 1 with the linear tonemap


func _ready() -> void:
	Game.settings.graphics = Game.GFX_MEDIUM
	for id in ["dome", "stadium", "village", "monsoon", "beach"]:
		var arena := Arena.new()
		add_child(arena)
		arena.build(id, Color("1f6fd0"), Color("d02f2f"), "")
		var env := arena.env
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.tonemap_exposure = EXPOSURE
		env.glow_enabled = false
		env.adjustment_enabled = false
		env.fog_enabled = false
		arena.sun.shadow_enabled = false
		var cam := Camera3D.new()
		cam.fov = 50.0
		add_child(cam)
		var lit := 0.0
		var shaded := 0.0
		for at in [Vector3(-2.5, 0, 2.0), Vector3(2.5, 0, -2.0)]:   # the field either side of the midline
			cam.position = at + Vector3(0, 4.0, 0)
			cam.rotation = Vector3(-PI / 2, 0, 0)
			arena.sun.visible = true
			lit += await _luminance() * 0.5
			arena.sun.visible = false
			shaded += await _luminance() * 0.5
		# The Compatibility renderer blends in sRGB: the floor shadow's alpha takes the sRGB value down by this much.
		var shade := 1.0 - _srgb(shaded) / _srgb(lit)
		print("shade_check: %s lit %.3f, shaded %.3f, linear light: SHADE %.2f" % [id, lit, shaded, shade])
		arena.free()
		cam.free()
	get_tree().quit()


## The picture's mean luminance, in linear light at exposure 1.
func _luminance() -> float:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var sum := 0.0
	var n := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y).srgb_to_linear()
			sum += c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			n += 1
	return sum / n / EXPOSURE


func _srgb(x: float) -> float:
	return Color(x, x, x).linear_to_srgb().r
