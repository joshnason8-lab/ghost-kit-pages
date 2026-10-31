extends Node
## Renders the menu tiles' figures from the game's own players, posed, onto transparent PNGs in assets/ui/:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/ui_art/render_art.tscn

const ARTS := [
	# name, move, moment (-1: as the ball is met), kit, shorts, skin, yaw (degrees), a woman
	["spike", "roll", -1.0, "ff8a1f", "2a1a0e", "c98a5a", 70.0, false],
	["serve", "serve", -1.0, "2fb36a", "123d2a", "b07448", 60.0, true],
	["block", "block", -1.0, "3f8cff", "0f2a55", "e0b48c", 35.0, false],
	["celebrate", "celebrate", 0.25, "19b3a3", "0e3b4f", "8d5a36", 10.0, true],
]


func _ready() -> void:
	Game.settings.graphics = Game.GFX_HIGH
	for a in ARTS:
		var sv := SubViewport.new()
		sv.size = Vector2i(1120, 1280)
		sv.transparent_bg = true
		sv.msaa_3d = Viewport.MSAA_4X
		sv.own_world_3d = true
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(sv)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.8, 0.83, 0.9)
		env.environment.ambient_light_energy = 0.7
		env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		sv.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-40, 35, 0)
		sun.light_energy = 1.3
		sv.add_child(sun)
		var b := RealBody.new({"jersey": Color(a[3]), "shorts": Color(a[4]), "skin": Color(a[5]), "women": a[7]})
		sv.add_child(b)
		var t := float(a[2]) if float(a[2]) >= 0.0 else float(Moves.CONTACT[a[1]][4])
		var p := Moves.sample(String(a[1]), t)
		b.apply(p)
		b.position.y = float(p.get("y", 0.0))
		b.rotation.y = deg_to_rad(float(a[6]) + float(p.get("yaw", 0.0)))
		var cam := Camera3D.new()
		cam.fov = 22
		sv.add_child(cam)
		var top := 2.0 + float(p.get("y", 0.0)) + (0.5 if a[1] == "roll" else 0.0)
		cam.position = Vector3(0, top * 0.5 + 0.1, 7.6)
		cam.look_at(Vector3(0, top * 0.5, 0))
		if a[1] in ["roll", "serve"]:
			var ball := Ball.new()
			sv.add_child(ball)
			var c: Array = Moves.CONTACT[a[1]]
			var right := Vector3(-1, 0, 0).rotated(Vector3.UP, b.rotation.y)
			var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(float(a[6])))
			ball.hold(fwd * float(c[1]) + right * float(c[2]) + Vector3(0, float(c[0]) - (0.1 if a[7] else 0.0), 0))
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := sv.get_texture().get_image()
		# Just the figure (and its ball), with a little room round it.
		var used := img.get_used_rect().grow(10).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img = img.get_region(used)
		img.save_png(ProjectSettings.globalize_path("res://assets/ui/art_%s.png" % a[0]))
		print("art ", a[0])
		sv.queue_free()
	get_tree().quit()
