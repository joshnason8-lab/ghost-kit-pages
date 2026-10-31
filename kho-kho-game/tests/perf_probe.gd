extends Node
## Draw calls, triangles and objects drawn per frame in a match, at each graphics level, at every venue (the biggest
## crowd is the floodlit stadium's), and the frame time at each:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/perf_probe.tscn
## The budgets (README, "Phones"): Low under 90 draw calls and 90k triangles, Medium 130 and 340k, High 190 and 700k.
## Also the video memory in use (all of it, and the textures' share), in MB.

const BUDGET := [[90, 90000], [130, 340000], [190, 700000]]


func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	var over := 0
	for venue in DB.venue_ids():
		# KK_GFX=0, 1 or 2: one level only, so its video memory is its own (textures stay cached from match to match).
		var levels := [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]
		if OS.get_environment("KK_GFX") != "":
			levels = [int(OS.get_environment("KK_GFX"))]
		for g in levels:
			for cam in [Game.CAM_TV, Game.CAM_POLE]:
				Game.settings.graphics = g
				# The broadcast camera, and the one behind the pole, which also sees the near side (Arena.show_near).
				Game.settings.camera = cam
				Game.start_match({"home": "MAH", "away": "ODI", "venue": venue, "format": KhoRules.FAST if venue == "arena" else KhoRules.CLASSIC,
					"turn_len": 300.0, "user_team": 0, "seed": 4, "mode": "quick", "chase_first": 0})
				for i in 90:
					await get_tree().process_frame
				var rs := RenderingServer
				var dc := rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
				var tris := rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
				var t0 := Time.get_ticks_usec()
				for i in 30:
					await get_tree().process_frame
				var ms := float(Time.get_ticks_usec() - t0) / 30000.0
				var ok: bool = dc <= BUDGET[g][0] and tris <= BUDGET[g][1]
				if not ok:
					over += 1
				print("venue %s graphics %d%s: %d draw calls, %d triangles, %d objects; scale %.2f; %.1f ms a frame here; video memory %.1f MB (textures %.1f)%s" % [venue, g, " (behind the pole)" if cam == Game.CAM_POLE else "", dc, tris,
					rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), get_viewport().scaling_3d_scale, ms,
					rs.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
					rs.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
					"" if ok else "  OVER BUDGET"])
	Game.goto_menu()
	await get_tree().process_frame
	get_tree().quit(1 if over > 0 else 0)
