extends Node
## How long a match takes to start, from the tap (Game.play_match, as every Start, Watch AI and championship button
## calls it: the loading overlay, then the match built in steps) to the first frame of the match drawn and to play, and the longest frame on the way (a stall the phone
## shows as frozen). Each ground, the championship's start and Watch AI, on the graphics level given (0: Low):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/load_timing.tscn -- [graphics] [case]
## Measured here on desktop software rendering (llvmpipe): a phone's numbers differ; this compares entries and builds.

const PLAY_TIMEOUT := 30.0


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	Game.main = self
	Game.settings.sound = false
	Game.settings.coach = false
	Game.settings.graphics = int(a[0]) if a.size() > 0 else Game.GFX_LOW
	get_tree().root.size = Vector2i(1280, 720)
	# What the loading screen does before the home screen (once per run of the game).
	ModelBody.warm()
	await Crowd.render_sheet(get_tree())
	var cases := [
		["quick match, village", {"venue": "maidan", "format": KhoRules.CLASSIC, "user_team": 0, "mode": "quick"}],
		["quick match, school", {"venue": "school", "format": KhoRules.CLASSIC, "user_team": 0, "mode": "quick"}],
		["quick match, arena (fast)", {"venue": "arena", "format": KhoRules.FAST, "user_team": 0, "mode": "quick"}],
		["quick match, stadium", {"venue": "floodlit", "format": KhoRules.CLASSIC, "user_team": 0, "mode": "quick"}],
		["championship match", {"venue": "floodlit", "format": KhoRules.CLASSIC, "user_team": 0, "mode": "cup"}],
		["Watch AI", {"venue": "maidan", "format": KhoRules.CLASSIC, "user_team": -1, "mode": "quick", "watch": true}],
		["quick match, village again", {"venue": "maidan", "format": KhoRules.CLASSIC, "user_team": 0, "mode": "quick"}],
	]
	# One case only (a fresh process each: the first match of a run is the slow one, its resources and shaders cold).
	if a.size() > 1:
		cases = [cases[int(a[1])]]
	for c in cases:
		Game.show_screen("res://ui/main_menu.gd")
		for i in 40:
			await get_tree().process_frame
		var cfg: Dictionary = {"home": "MAH", "away": "ODI", "turn_len": 300.0, "seed": 5, "chase_first": 0}
		cfg.merge(c[1], true)
		var t0 := Time.get_ticks_usec()
		var last := t0
		var worst := 0
		# The real way in: a Start button's (Game.play_match: the loading overlay, then the match built in steps).
		Game.play_match(cfg)
		var ld := WsgLoading.current()
		var bar: Array = []
		if ld:
			ld.progressed.connect(func(fr: float, _l: String): bar.append(fr))
		await RenderingServer.frame_post_draw
		var cover_ms := (Time.get_ticks_usec() - t0) / 1000.0
		var covered := ld != null and is_instance_valid(ld) and ld.is_inside_tree()
		var first := -1
		while true:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			worst = maxi(worst, now - last)
			last = now
			var m: Node = Game.current
			if m and m.get("live") == true:
				first = now - t0
				break
			if (now - t0) / 1e6 > PLAY_TIMEOUT:
				break
		var forward := true
		for i in range(1, bar.size()):
			forward = forward and float(bar[i]) >= float(bar[i - 1])
		print("LOAD %-28s overlay %s at the first frame (%.0f ms)   playable %6.0f ms   longest frame %6.0f ms   bar %d moves%s, to %.2f" % [
			c[0], "UP" if covered else "NOT up", cover_ms, first / 1000.0, worst / 1000.0, bar.size(),
			"" if forward else " (WENT BACK)", float(bar[-1]) if not bar.is_empty() else 0.0])
		for i in 30:
			await get_tree().process_frame
	get_tree().quit()
