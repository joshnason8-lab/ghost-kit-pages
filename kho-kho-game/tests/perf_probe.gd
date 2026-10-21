extends Node
## Draw calls, triangles and objects drawn per frame in a match, at each graphics level, at every venue (the biggest
## crowd is the floodlit stadium's), and the frame time at each:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/perf_probe.tscn
## The budgets (README, "Phones"): Low under 90 draw calls and 90k triangles, Medium 130 and 280k, High 180 and 600k.

const BUDGET := [[90, 90000], [130, 280000], [180, 600000]]


func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	var over := 0
	for venue in DB.venue_ids():
		for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
			Game.settings.graphics = g
			ToonBody.material(g > Game.GFX_LOW)
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
			print("venue %s graphics %d: %d draw calls, %d triangles, %d objects; scale %.2f; %.1f ms a frame here%s" % [venue, g, dc, tris,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), get_viewport().scaling_3d_scale, ms,
				"" if ok else "  OVER BUDGET"])
	Game.goto_menu()
	await get_tree().process_frame
	get_tree().quit(1 if over > 0 else 0)
