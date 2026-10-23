extends Node
## Each ground as the match camera sees it at the throw-in and from behind a goal, and a wide shot from high in a
## corner (the sky and the surrounds), and from the pitch looking at the near and far stands (the crowd faces the
## field), for checking how it looks:
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
		# From the pitch, looking at the near stand (under the television camera) and the far one: every face toward
		# the field.
		# And from behind the near stand, where the television camera is: the backs of their heads.
		for side in [["near", Vector3(-20.0, 2.0, Pitch.HALF_W - 6.0), Vector3(-20.0, 3.5, Pitch.HALF_W + 9.0)],
				["far", Vector3(-20.0, 2.0, -Pitch.HALF_W + 6.0), Vector3(-20.0, 4.5, -Pitch.HALF_W - 10.0)],
				["near_behind", Vector3(-20.0, 7.5, Pitch.HALF_W + 17.0), Vector3(-20.0, 2.0, Pitch.HALF_W + 7.0)]]:
			var c := Camera3D.new()
			m.add_child(c)
			c.fov = 34.0
			c.look_at_from_position(side[1], side[2])
			c.make_current()
			for i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("venue_%s_crowd_%s.png" % [v, side[0]]))
			c.queue_free()
		print("venue ", v)
	get_tree().quit()
