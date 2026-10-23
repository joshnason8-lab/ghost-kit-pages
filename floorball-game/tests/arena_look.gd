extends Node
## The venue's look and cost, for whoever works on the rink, hall and crowd. Needs a window:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 res://tests/arena_look.tscn -- OUT_DIR [shots|static|cams|all] [arena,hall,school] [0,1,2]
## (the last two optional: which venues, and for "static" which graphics levels)
## "probe": tests/perf_probe's whole-frame count (a match, players and HUD) for the venues named (the school by
## default; perf_probe itself covers the arena and the hall).
## "static": the venue alone (rink, hall, crowd, lights; no players, ball or HUD) from the broadcast camera, its draw
## calls and triangles at each graphics level. "shots": a demo match in each venue at Low and High, pictures saved.
## "cams": each venue at Low and High from the broadcast camera and from behind the goal, and the home screen's live
## match (the menu backdrop, in the arena and the hall, the venues it picks from), pictures saved.

var out := "user://arena_look"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var what := args[1] if args.size() > 1 else "all"
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().root.size = Vector2i(1280, 720)
	Game.main = self
	Game.settings.sound = false
	Game.settings.auto_gfx = false
	var only: Array = Array(args[2].split(",")) if args.size() > 2 else []
	var levels: Array = [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]
	if args.size() > 3:
		levels = Array(args[3].split(",")).map(func(x: String) -> int: return int(x))
	if what in ["static", "all"]:
		await _static(only, levels)
	if what in ["shots", "all"]:
		await _shots(args[2].split(",") if args.size() > 2 else [])
	if what == "probe":
		await _probe(only if not only.is_empty() else ["school"], levels)
	if what in ["cams", "all"]:
		await _cams(only, [Game.GFX_LOW, Game.GFX_HIGH] if args.size() <= 3 else levels)
	get_tree().quit()


func _static(only: Array, levels: Array) -> void:
	for venue in ["arena", "hall", "school"]:
		if not only.is_empty() and not only.has(venue):
			continue
		for g in levels:
			Game.settings.graphics = g
			var root := Node3D.new()
			add_child(root)
			Game.apply_graphics(get_viewport())
			var a := Arena.new(venue, [Color("1e5bb8")], [Color("f2f2f2")])
			root.add_child(a)
			var cam := Camera3D.new()
			cam.fov = 38.0
			cam.near = 0.2
			cam.far = 220.0
			root.add_child(cam)
			cam.global_position = Vector3(0, 11.0, 23.5)
			cam.look_at(Vector3(0, 0, -0.8))
			cam.current = true
			await _frames(20)
			var rs := RenderingServer
			var dc := rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			var pr := rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			# And toward an end, where the most crowd is seen.
			cam.global_position = Vector3(13.5, 11.0, 23.5)
			cam.look_at(Vector3(15, 0, -0.8))
			await _frames(6)
			var t0 := Time.get_ticks_usec()
			await _frames(20)
			var ms := float(Time.get_ticks_usec() - t0) / 20000.0
			var parts := ""
			if OS.get_environment("ARENA_PARTS") != "":
				# What each part costs here: the frame time with it hidden.
				for c in a.get_children():
					if c is GeometryInstance3D:
						c.visible = false
						var t1 := Time.get_ticks_usec()
						await _frames(10)
						parts += " %s:%.1f" % ["%s#%d" % [c.get_class(), c.get_index()] , float(Time.get_ticks_usec() - t1) / 10000.0]
						c.visible = true
			print("  frame %.1f ms here (a guide only)%s" % [ms, parts])
			var dc2 := rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			var pr2 := rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			print("STATIC %s gfx %d: centre %d draw calls %d triangles; end %d draw calls %d triangles; video mem %.1f MB tex %.1f MB" % [
				venue, g, dc, pr, dc2, pr2,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0])
			await _shot("static_%s_g%d_end" % [venue, g])
			# Closer looks, for checking the fittings: the far wall's end and its benches, an end wall's door, the
			# ceiling's lamps (and the arena's lower tier).
			var hx: float = {"arena": 34.0, "hall": 27.0}.get(venue, 24.0)
			var hz: float = {"arena": 27.0, "hall": 19.0}.get(venue, 16.0)
			var views := [["corner", Vector3(10, 4.5, -4), Vector3(hx - 3.0, 1.5, -hz + 1.0)],
				["door", Vector3(hx - 9.0, 2.5, -5.0), Vector3(hx, 2.2, -9.5)],
				["ceiling", Vector3(-hx + 8.0, 3.5, 6.0), Vector3(hx - 4.0, 9.0, -2.0)],
				["lamp", Vector3(1.0, 6.5, 2.5), Vector3(3.5, 8.3, 0.0)],
				["board", Vector3(hx - 8.0, 5.0 if venue != "school" else 2.6, 4.0), Vector3(hx - 2.0, 8.6 if venue == "hall" else 3.3, 0.0)]]
			if venue == "arena":
				views = [["tier", Vector3(-3, 2.5, 2.0), Vector3(-6, 2.2, -14.0)]]
			for vw in views:
				cam.global_position = vw[1]
				cam.look_at(vw[2])
				await _frames(4)
				await _shot("detail_%s_g%d_%s" % [venue, g, vw[0]])
			if venue == "arena" and g == Game.GFX_HIGH:
				# A goal: the crowd up on its feet.
				Crowd.set_excite(1.0)
				await _frames(4)
				await _shot("static_arena_goal")
				Crowd.set_excite(0.0)
				# The hall over the stands, where the broadcast picture's top edge is.
				cam.global_position = Vector3(0, 11.0, 23.5)
				cam.look_at(Vector3(26, 7, -24))
				await _frames(4)
				await _shot("static_arena_corner")
			root.queue_free()
			await _frames(3)


func _shots(only: Array) -> void:
	var cases := [["arena", "SWE", "FIN", false], ["hall", "SUI", "CZE", true], ["school", "LAT", "SVK", false]]
	for c in cases:
		if not only.is_empty() and not only.has(c[0]):
			continue
		for g in [Game.GFX_LOW, Game.GFX_HIGH]:
			Game.settings.graphics = g
			Game.start_match({"home": c[1], "away": c[2], "venue": c[0], "user_team": 0, "mode": "quick", "seed": 11, "period": 8.0, "women": c[3]})
			await _frames(300)
			await _shot("match_%s_g%d" % [c[0], g])


func _cams(only: Array, levels: Array) -> void:
	var cases := [["arena", "SWE", "FIN", false], ["hall", "SUI", "CZE", true], ["school", "LAT", "SVK", false]]
	for g in levels:
		Game.settings.graphics = g
		for c in cases:
			if not only.is_empty() and not only.has(c[0]):
				continue
			for cm in [Game.CAM_TV, Game.CAM_END]:
				Game.settings.camera = cm
				Game.start_match({"home": c[1], "away": c[2], "venue": c[0], "user_team": 0, "mode": "quick", "seed": 11, "period": 8.0, "women": c[3]})
				await _frames(300)
				await _shot("cam_%s_g%d_%s" % [c[0], g, "tv" if cm == Game.CAM_TV else "end"])
		Game.settings.camera = Game.CAM_TV
		# The home screen picks the arena or the hall at random: open it until each has been seen.
		if OS.get_environment("ARENA_NO_MENU") != "":
			continue
		var seen := {}
		for attempt in 12:
			Game.goto_menu()
			await _frames(240)
			var demo: Node = null
			for n in get_tree().root.find_children("*", "", true, false):
				if n.get("config") is Dictionary and (n.get("config") as Dictionary).get("menu", false):
					demo = n
					break
			var v := String(demo.config.venue) if demo else "?"
			if seen.has(v) or (not only.is_empty() and not only.has(v)):
				continue
			seen[v] = true
			await _shot("menu_%s_g%d" % [v, g])
			if seen.size() >= 2:
				break


func _probe(venues: Array, levels: Array) -> void:
	for venue in venues:
		for g in levels:
			Game.settings.graphics = g
			Game.settings.camera = Game.CAM_TV
			Game.start_match({"home": "SWE", "away": "FIN", "venue": venue, "user_team": 0, "seed": 4, "mode": "quick", "period": 8.0})
			await _frames(200)
			var rs := RenderingServer
			print("PROBE %s graphics %d: %d draw calls, %d primitives, %d objects" % [venue, g,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name)
