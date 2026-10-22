extends Node
## The venue's look and cost, for whoever works on the rink, hall and crowd. Needs a window:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 res://tests/arena_look.tscn -- OUT_DIR [shots|static|all] [arena,hall,school]
## "static": the venue alone (rink, hall, crowd, lights; no players, ball or HUD) from the broadcast camera, its draw
## calls and triangles at each graphics level. "shots": a demo match in each venue at Low and High, pictures saved.

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
	if what in ["static", "all"]:
		await _static()
	if what in ["shots", "all"]:
		await _shots(args[2].split(",") if args.size() > 2 else [])
	get_tree().quit()


func _static() -> void:
	for venue in ["arena", "hall", "school"]:
		for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name)
