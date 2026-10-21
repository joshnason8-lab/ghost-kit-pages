extends Node
## Each ground as the match camera sees it at the throw-in and from behind a goal, for checking how it looks:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/venue_view.tscn -- /out [venue]

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "user://venues"
	var only := a[1] if a.size() > 1 else ""
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_HIGH
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
		print("venue ", v)
	get_tree().quit()
