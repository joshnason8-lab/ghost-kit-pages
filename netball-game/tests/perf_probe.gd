extends Node
## Draw calls, primitives, objects drawn and video memory per frame in a match, at each graphics level, in each venue:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/perf_probe.tscn [-- venues [cam [levels]]]
## venues: arena,hall,outdoor (all by default); cam: tv, low or end (the broadcast camera by default); levels: 0,1,2
## (Low, Medium, High; all by default). Video memory counts everything loaded so far in the process (textures stay
## cached from one match to the next), so for one level's own figure run it alone: -- hall tv 1.

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
	get_tree().quit()
