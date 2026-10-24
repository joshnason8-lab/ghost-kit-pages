extends Node
## Draw calls, primitives and objects drawn per frame in a match, and the video memory in use (all of it, and the
## textures'), at each graphics level:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/perf_probe.tscn [-- venues [levels]]
## venues: comma-separated ids, or "all" (default: the Grand Dome, the biggest); levels: 0,1,2 (Low, Medium, High).

func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	var a := OS.get_cmdline_user_args()
	var venues: Array = ["dome"]
	if a.size() > 0:
		venues = DB.VENUES.map(func(v): return v[0]) if a[0] == "all" else Array(a[0].split(","))
	var levels: Array = [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]
	if a.size() > 1:
		levels = Array(a[1].split(",")).map(func(s): return int(s))
	for venue in venues:
		for g in levels:
			Game.settings.graphics = g
			RealBody.warm()
			Game.start_match({"home": "THA", "away": "MAS", "venue": venue, "event": "regu", "sets": 1, "points": 15,
				"user_team": 0, "seed": 4, "mode": "quick"})
			for i in 150:
				await get_tree().process_frame
			var rs := RenderingServer
			print("%s graphics %d: %d draw calls, %d primitives, %d objects; scale %.2f; video memory %.1f MB, textures %.1f MB" % [venue, g,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), get_viewport().scaling_3d_scale,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0])
	get_tree().quit()
