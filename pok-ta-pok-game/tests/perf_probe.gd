extends Node
## Draw calls, triangles and objects drawn a frame in a match at each graphics level and court (ten players, two
## judges, the crowd), and the frame time this machine takes:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/perf_probe.tscn [-- venues [coded]]
## (venues comma-separated; "coded": the code-built bodies instead of the realistic ones, to compare ("rigged" otherwise);
## then the graphics levels, comma-separated: one level a run gives its video memory alone, without the caches of others)
## (README.md has the numbers.) Budgets on Low: about 100 draw calls and 90k triangles.

func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	Game.settings.coach = false
	get_tree().root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	# The level measured is set before the crowd's sheet is baked, as the game does at loading.
	Game.settings.graphics = int(args[2].split(",")[0]) if args.size() > 2 else Game.GFX_LOW
	await Crowd.bake(self)
	var venues: Array = Array(args[0].split(",")) if args.size() > 0 else DB.VENUE_ORDER
	Body.use_rigged = not (args.size() > 1 and args[1] == "coded")
	for venue in venues:
		var levels: Array = [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]
		if args.size() > 2:
			levels = Array(args[2].split(",")).map(func(x): return int(x))
		for g in levels:
			Game.settings.graphics = g
			var rules := String(DB.venue(venue).rules)
			Game.start_match({"home": "ESC", "away": "LLA", "venue": venue, "rules": rules, "side": 5 if rules == "ulama" else 4,
				"user_team": 0, "seed": 4, "mode": "quick", "length": 10})
			for i in 150:
				await get_tree().process_frame
			var rs := RenderingServer
			var draws := 0
			var prims := 0
			var objs := 0
			var n := 0
			var t0 := Time.get_ticks_usec()
			for i in 60:
				await get_tree().process_frame
				draws = maxi(draws, rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
				prims = maxi(prims, rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
				objs = maxi(objs, rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
				n += 1
			var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / n
			var vmem := rs.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0
			var tmem := rs.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0
			var m: Node = Game.current
			var crowd: int = m.venue.crowd.spots.size()
			print("%s graphics %d: up to %d draw calls, %d triangles, %d objects; %d in the crowd; scale %.2f; %.1f ms a frame here; video memory %.0f MB (textures %.0f MB)" % [venue, g,
				draws, prims, objs, crowd, get_viewport().scaling_3d_scale, ms, vmem, tmem])
	get_tree().quit()
