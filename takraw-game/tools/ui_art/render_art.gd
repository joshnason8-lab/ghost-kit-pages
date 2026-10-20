extends Node
## Renders the menu tiles' figures from the game's own players, posed, onto transparent PNGs in assets/ui/:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/ui_art/render_art.tscn

const ARTS := [
	# name, move, moment, kit, shorts, skin, yaw (degrees), ball offset from the contact
	["spike", "roll", 0.48, "ff8a1f", "2a1a0e", "c98a5a", 70.0],
	["serve", "horse", 0.55, "2fb36a", "123d2a", "b07448", 60.0],
	["block", "block", 0.45, "3f8cff", "0f2a55", "e0b48c", 20.0],
	["celebrate", "celebrate", 0.25, "19b3a3", "0e3b4f", "8d5a36", 10.0],
]


func _ready() -> void:
	Game.settings.graphics = Game.GFX_HIGH
	for a in ARTS:
		var sv := SubViewport.new()
		sv.size = Vector2i(1120, 1280)
		sv.transparent_bg = true
		sv.own_world_3d = true
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(sv)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		sv.add_child(env)
		var b := ToonBody.new({"jersey": Color(a[3]), "shorts": Color(a[4]), "skin": Color(a[5]), "hair_style": 0, "band": Color("f3efe6")})
		sv.add_child(b)
		var p := Moves.sample(String(a[1]), float(a[2]))
		b.apply(p)
		b.position.y = float(p.get("y", 0.0))
		b.rotation.y = deg_to_rad(float(a[6]) + float(p.get("yaw", 0.0)))
		var cam := Camera3D.new()
		cam.fov = 22
		sv.add_child(cam)
		var top := 2.0 + float(p.get("y", 0.0)) + (0.5 if a[1] == "roll" else 0.0)
		cam.position = Vector3(0, top * 0.5 + 0.1, 7.6)
		cam.look_at(Vector3(0, top * 0.5, 0))
		if a[1] in ["roll", "horse"]:
			var ball := Ball.new()
			sv.add_child(ball)
			var c: Array = Moves.CONTACT[a[1]]
			var right := Vector3(-1, 0, 0).rotated(Vector3.UP, b.rotation.y)
			var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(float(a[6])))
			ball.hold(fwd * float(c[1]) + right * float(c[2]) + Vector3(0, float(c[0]), 0))
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
