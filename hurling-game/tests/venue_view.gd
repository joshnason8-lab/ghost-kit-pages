extends Node
## Each ground as the match camera sees it at the throw-in and from behind a goal, and a wide shot from high in a
## corner (the sky and the surrounds), for checking how it looks:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/venue_view.tscn -- /out [venue] [graphics 0-2]

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "user://venues"
	var only := a[1] if a.size() > 1 else ""
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = int(a[2]) if a.size() > 2 else Game.GFX_HIGH
	for v in DB.VENUES:
		if only != "" and v != only:
			continue
		Game.start_match({"home": "KIL", "away": "TIP", "venue": v, "user_team": -1, "seed": 2, "mode": "test"})
		for i in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("venue_%s.png" % v))
		var m: Node = Game.current
		m.cam.mode = Game.CAM_END
		for i in 60:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("venue_%s_end.png" % v))
		# A wide shot from high in a corner: the sky, the surrounds, the village or the town.
		var wide := Camera3D.new()
		m.add_child(wide)
		wide.fov = 62.0
		wide.far = 1500.0
		wide.look_at_from_position(Vector3(-Pitch.HALF_L - 30.0, 34.0, Pitch.HALF_W + 45.0), Vector3(25.0, 4.0, -40.0))
		wide.make_current()
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("venue_%s_wide.png" % v))
		wide.queue_free()
		print("venue ", v)
	get_tree().quit()
