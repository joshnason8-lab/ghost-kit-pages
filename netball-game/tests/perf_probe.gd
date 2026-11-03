extends Node
## Draw calls, primitives, objects drawn and video memory per frame in a match, at each graphics level, in each venue:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/perf_probe.tscn [-- venues [cam [levels]]]
## venues: arena,hall,outdoor (all by default); cam: tv, low or end (the broadcast camera by default); levels: 0,1,2
## (Low, Medium, High; all by default). Video memory counts everything loaded so far in the process (textures stay
## cached from one match to the next), so for one level's own figure run it alone: -- hall tv 1.
## peak (a fourth argument, frames): the most draw calls and primitives of any frame over that many frames of play on
## the camera, then a goal's close shot of the post (90 frames) and the other two cameras (60 frames each).

func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	var args := OS.get_cmdline_user_args()
	var venues := ["arena", "hall", "outdoor"]
	if args.size() > 0 and args[0] != "":
		venues = Array(args[0].split(","))
	var cam := Game.CAM_TV
	if args.size() > 1:
		cam = {"tv": Game.CAM_TV, "low": Game.CAM_LOW, "end": Game.CAM_END}.get(args[1], Game.CAM_TV)
	var levels := [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]
	if args.size() > 2 and args[2] != "":
		levels = Array(args[2].split(",")).map(func(s): return int(s))
	var peak := int(args[3]) if args.size() > 3 else 0
	for v: String in venues:
		for g in levels:
			Game.settings.graphics = g
			ToonBody.material(g > Game.GFX_LOW)
			Game.start_match({"home": "AUS", "away": "NZL", "venue": v, "quarter": 15, "user_team": 0, "seed": 4, "mode": "quick"})
			Game.current.cam.set_mode(cam)
			for i in 150:
				await get_tree().process_frame
			var rs := RenderingServer
			print("%s graphics %d: %d draw calls, %d primitives, %d objects; scale %.2f; video memory %.1f MB (textures %.1f MB, buffers %.1f MB); %d fps here" % [v, g,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), get_viewport().scaling_3d_scale,
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
				Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
				Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
				Engine.get_frames_per_second()])
			if peak > 0:
				var m = Game.current
				var phases := [["play", peak, -1], ["goal close", 90, -2]]
				for c in [Game.CAM_TV, Game.CAM_LOW, Game.CAM_END]:
					if c != cam:
						phases.append([["tv", "low", "end"][[Game.CAM_TV, Game.CAM_LOW, Game.CAM_END].find(c)] + " camera", 60, c])
				var most := Vector2i.ZERO
				var parts := []
				for ph: Array in phases:
					if int(ph[2]) == -2:
						m._goal(m.player_at(0, "GS"), 1)
					elif int(ph[2]) >= 0:
						m.cam.set_mode(int(ph[2]))
					var top := Vector2i.ZERO
					for i in int(ph[1]):
						await RenderingServer.frame_post_draw
						top.x = maxi(top.x, rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
						top.y = maxi(top.y, rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
					most = Vector2i(maxi(most.x, top.x), maxi(most.y, top.y))
					parts.append("%s %d/%dk" % [ph[0], top.x, top.y / 1000])
				print("%s graphics %d peak: %d draw calls, %d primitives (%s)" % [v, g, most.x, most.y, ", ".join(parts)])
	get_tree().quit()
