extends Node
## Draw calls, primitives and objects drawn per frame in a match, at each graphics level, in the biggest venue:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/perf_probe.tscn

func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		RealBody.warm()
		Game.start_match({"home": "THA", "away": "MAS", "venue": "dome", "event": "regu", "sets": 1, "points": 15,
			"user_team": 0, "seed": 4, "mode": "quick"})
		for i in 150:
			await get_tree().process_frame
		var rs := RenderingServer
		print("graphics %d: %d draw calls, %d primitives, %d objects; scale %.2f" % [g,
			rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), get_viewport().scaling_3d_scale])
	get_tree().quit()
