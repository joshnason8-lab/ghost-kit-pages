extends Node
## Draw calls, primitives and objects drawn per frame in a match, at each graphics level, in the biggest venue (the
## city arena, 5,200 in the stands) and the sports hall; and the frame time this machine takes (a guide only: a
## phone's GPU is what counts), with the CPU time of the frame's game logic (process) and of posing the people on the
## rink (game/player.gd, game/body.gd, game/rigged_body.gd: motion capture and the pose in code). Needs a window:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/perf_probe.tscn

func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	Game.settings.auto_gfx = false
	for venue in ["arena", "hall"]:
		for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
			Game.settings.graphics = g
			Game.start_match({"home": "SWE", "away": "FIN", "venue": venue, "user_team": 0, "seed": 4, "mode": "quick", "period": 8.0})
			for i in 200:
				await get_tree().process_frame
			var rs := RenderingServer
			var t0 := Time.get_ticks_usec()
			var process := 0.0
			for i in 60:
				await get_tree().process_frame
				process += Performance.get_monitor(Performance.TIME_PROCESS)
			var ms := float(Time.get_ticks_usec() - t0) / 60000.0
			print("%s graphics %d: %d draw calls, %d primitives, %d objects; render scale %.2f; %.1f ms a frame here (game logic %.2f ms)" % [venue, g,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), get_viewport().scaling_3d_scale, ms, process / 60.0 * 1000.0])
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
