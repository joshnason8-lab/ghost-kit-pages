extends Node
# A match on a ground, pictures at a few moments: godot ... res://tests/quickshot.tscn -- OUT venue gfx frames...
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	Game.main = self
	Game.settings.sound = false
	Game.settings.coach = false
	Game.settings.graphics = int(a[2])
	Game.settings.camera = int(OS.get_environment("KK_CAM")) if OS.get_environment("KK_CAM") != "" else Game.CAM_TV
	get_tree().root.size = Vector2i(1280, 720)
	ModelBody.warm()
	await Crowd.render_sheet(get_tree())
	if a[1].begins_with("home"):
		# The menu over its backdrop match: "home:N" picks the backdrop (main_menu.gd ATTRACT[N]).
		var menu := Game.show_screen("res://ui/main_menu.gd")
		await get_tree().process_frame
		menu._pick = int(a[1].get_slice(":", 1))
		menu._start_attract()
	else:
		Game.start_match({"home": "MAH", "away": "ODI", "venue": a[1], "format": KhoRules.FAST if a[1] == "arena" else KhoRules.CLASSIC,
			"turn_len": 300.0, "user_team": -1, "seed": 5, "mode": "quick", "chase_first": 0})
	var done := 0
	for k in range(3, a.size()):
		var n := int(a[k])
		for i in n - done:
			await get_tree().process_frame
			# KK_WIDE: a wide view from high behind the near side, to see the place round the field.
			if OS.get_environment("KK_WIDE") != "" and Game.current and Game.current.get("cam"):
				Game.current.cam_locked = true
				Game.current.cam.position = Vector3(-6.0, 9.0, 26.0)
				Game.current.cam.look_at(Vector3(4.0, 3.0, -20.0))
		done = n
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_g%s_%d.png" % [a[0], a[1].replace(":", ""), a[2], n])
		print("shot ", n)
	get_tree().quit()
