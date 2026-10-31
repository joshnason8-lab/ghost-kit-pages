extends Node
## Draw calls, primitives and objects drawn a frame in a match at each graphics level, at the biggest venue (the
## national stadium, 30 players and 8 officials), and the frame time this machine takes:
##   xvfb-run -a godot --path . --fixed-fps 30 res://tests/perf_probe.tscn [-- venue level [nopack]]
## (Vulkan, the game's renderer; --rendering-driver opengl3 for the GL fallback.)
## With a venue and a level (0-2) it measures that one alone, so the video memory is that level's own (textures stay
## loaded once used, so in one run each level would count the last's too).
## (README.md has the numbers.) Also the logic's cost: the match's own time a frame, which a phone's CPU pays.

func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	Game.settings.coach = false     # the first match's coach card would be on the screen at the moment measured
	var a := OS.get_cmdline_user_args()
	Ultra.removed = "nopack" in a     # High as a phone without the HD pack draws it
	for venue in (["stadium", "parish"] if a.is_empty() else [a[0]]):
		for g in ([Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH] if a.size() < 2 else [int(a[1])]):
			Game.settings.graphics = g
			ToonBody.material(g > Game.GFX_LOW)
			Game.start_match({"home": "KIL", "away": "TIP", "venue": venue, "user_team": 0, "seed": 4, "mode": "quick", "length": 14})
			for i in 240:
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
			var crowd := 0
			var m: Node = Game.current
			if m.stadium.crowd.multimesh:
				crowd = m.stadium.crowd.multimesh.instance_count
			print("%s graphics %d: up to %d draw calls, %d triangles, %d objects; %d in the crowd; scale %.2f; %.1f ms a frame here; video memory %.1f MB (textures %.1f MB)" % [venue, g,
				draws, prims, objs, crowd, get_viewport().scaling_3d_scale, ms,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0])
	# The logic alone: a match's _process, timed.
	get_tree().quit()
