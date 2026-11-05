extends Node
## Draw calls, primitives and objects drawn per frame in a match, at each graphics level, in the biggest venue (the
## city arena, 5,200 in the stands) and the sports hall; and the frame time this machine takes (a guide only: a
## phone's GPU is what counts), and the CPU time of posing the people on the rink (game/player.gd, game/body.gd, game/rigged_body.gd: motion capture and the pose in code). Needs a window:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/perf_probe.tscn [-- venue level]

func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	Game.settings.auto_gfx = false
	# One venue and level ("-- hall 1") measures video memory cleanly (a run of several keeps the earlier ones' textures).
	var a := OS.get_cmdline_user_args()
	var venues: Array = [a[0]] if a.size() > 0 else ["arena", "hall"]
	var levels: Array = [int(a[1])] if a.size() > 1 else [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]
	for venue in venues:
		for g in levels:
			Game.settings.graphics = g
			Game.start_match({"home": "SWE", "away": "FIN", "venue": venue, "user_team": 0, "seed": 4, "mode": "quick", "period": 8.0})
			for i in 200:
				await get_tree().process_frame
			var rs := RenderingServer
			var t0 := Time.get_ticks_usec()
			for i in 60:
				await get_tree().process_frame
			var ms := float(Time.get_ticks_usec() - t0) / 60000.0
			print("%s graphics %d: %d draw calls, %d primitives, %d objects; render scale %.2f; %.1f ms a frame here; video memory %.1f MB (textures %.1f MB, buffers %.1f MB)" % [venue, g,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), get_viewport().scaling_3d_scale, ms,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0])
	# Posing: the twelve players and two referees of a match, running, for 300 frames.
	Game.show_screen("res://ui/main_menu.gd")
	await get_tree().process_frame
	var people: Array[Player] = []
	for i in 14:
		var p := Player.new({"id": "SWE%02d" % i, "height": 1.8, "num": i}, 0, "R" if i >= 12 else ("G" if i % 6 == 5 else "F"), i % 6)
		p.off_boards = true
		add_child(p)
		people.append(p)
	var t1 := Time.get_ticks_usec()
	for n in 300:
		for i in people.size():
			people[i].want_vel = Vector2.from_angle(i * 0.7) * (1.0 + (i % 5) * 1.5)
			people[i].step(1.0 / 60.0)
	print("posing 14 people: %.3f ms a frame here" % (float(Time.get_ticks_usec() - t1) / 300000.0))
	get_tree().quit()
