extends Node
## Pictures of a match for looking at (not a test): a venue at a graphics level, a few moments in.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/shot.tscn -- OUT_PREFIX VENUE GFX [user] [secs,...] [cam]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := String(args[0]) if args.size() > 0 else "/tmp/shot"
	var venue := String(args[1]) if args.size() > 1 else "village"
	var g := int(args[2]) if args.size() > 2 else 2
	var user := int(args[3]) if args.size() > 3 else 0
	var times := (String(args[4]) if args.size() > 4 else "4,9,14").split(",")
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = g
	Game.settings.coach = false
	if args.size() > 5:
		Game.settings.camera = int(args[5])
	get_tree().root.size = Vector2i(1600, 900)
	await Crowd.bake(self)
	Game.start_match({"home": "ESC", "away": "LLA" if DB.venue(venue).rules == "ulama" else "PIS", "venue": venue, "user_team": user,
		"seed": 5, "mode": "quick", "length": 10, "difficulty": 1})
	var t0 := Time.get_ticks_msec()
	var frame := 0
	for ts in times:
		var want := int(float(ts) * 30.0)
		while frame < want:
			await get_tree().process_frame
			frame += 1
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_jpg("%s_%s_g%d_%s.jpg" % [out, venue, g, ts], 0.85)
	print("shots done in %d ms" % (Time.get_ticks_msec() - t0))
	get_tree().quit()
