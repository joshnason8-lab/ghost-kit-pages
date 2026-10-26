extends Node
## The venues at each graphics level: a centre pass and a moment of play in each, saved as PNGs, and what each venue
## costs to draw (the frame's draw calls and primitives with the venue shown, less the same frame with it hidden):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/venue_shots.tscn -- OUT_DIR [levels] [venues]
## levels: low,medium,high (low,high by default); venues: arena,hall,outdoor (all by default). OUT_DIR "-" saves no
## pictures, only the numbers. Besides the broadcast camera's centre pass and play, its close shot of the post after a
## goal, and a shot from each other camera.

var out := "-"
var levels := ["low", "high"]
var venues := ["arena", "hall", "outdoor"]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1 and args[1] != "":
		levels = Array(args[1].split(","))
	if args.size() > 2 and args[2] != "":
		venues = Array(args[2].split(","))
	if out != "-":
		DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	get_tree().root.size = Vector2i(1920, 1080)
	for lv: String in levels:
		var g := ["low", "medium", "high"].find(lv)
		Game.settings.graphics = g
		ToonBody.material(g > Game.GFX_LOW)
		for v: String in venues:
			Game.start_match({"home": "AUS", "away": "NZL", "venue": v, "quarter": 15, "difficulty": 1, "mode": "quick",
				"user_team": 0, "seed": 9})
			await frames(40)
			await shot("%s_%s_centre" % [v, lv])
			var all: Vector2i = await info()
			var m = Game.current
			m.arena.visible = false
			await frames(3)
			var bare: Vector2i = await info()
			m.arena.visible = true
			print("%s %s: %d draw calls, %d primitives in all; the venue %d draw calls, %d primitives" % [v, lv,
				all.x, all.y, all.x - bare.x, all.y - bare.y])
			await frames(200)
			await shot("%s_%s_play" % [v, lv])
			# A goal: the TV camera's close shot of the post, its goal light flashing, the boards crying it.
			m._goal(m.player_at(0, "GS"), 1)
			await frames(20)
			await shot("%s_%s_goal_close" % [v, lv])
			await frames(80)
			# The other two cameras: courtside, and behind the goal.
			for c: Array in [[Game.CAM_LOW, "low_cam"], [Game.CAM_END, "end_cam"]]:
				m.cam.set_mode(c[0])
				await frames(20)
				await shot("%s_%s_%s" % [v, lv, c[1]])
			m.cam.set_mode(Game.CAM_TV)
		# The home screen's live match behind the menu (Medium and High only: Low has a plain backdrop).
		if g != Game.GFX_LOW and out != "-":
			for v: String in venues:
				var menu: Node = Game.show_screen("res://ui/main_menu.gd")
				await frames(2)
				for i in menu.ATTRACT.size():
					if menu.ATTRACT[i][2] == v:
						menu._pick = i
						break
				menu._start_attract()
				await frames(150)
				await shot("%s_%s_menu" % [v, lv])
	get_tree().quit()


func info() -> Vector2i:
	await RenderingServer.frame_post_draw
	return Vector2i(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	if out == "-":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
