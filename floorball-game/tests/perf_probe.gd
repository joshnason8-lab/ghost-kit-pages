extends Node
## Draw calls, primitives and objects drawn per frame in a match, at each graphics level, in the biggest venue (the
## city arena, 5,200 in the stands) and the sports hall; and the frame time this machine takes (a guide only: a
## phone's GPU is what counts). Needs a window:
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
			for i in 60:
				await get_tree().process_frame
			var ms := float(Time.get_ticks_usec() - t0) / 60000.0
			print("%s graphics %d: %d draw calls, %d primitives, %d objects; render scale %.2f; %.1f ms a frame here" % [venue, g,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), get_viewport().scaling_3d_scale, ms])
	get_tree().quit()
