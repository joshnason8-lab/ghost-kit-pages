extends Node
## Tap to the first playable frame of a match, for each way into one, and the longest frame on the way (the screen
## frozen): what the player waits through after tapping Start. Not a test; the numbers for the loading work.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/load_time.tscn -- [GFX]
func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 0
	Game.settings.auto_gfx = false
	if OS.has_environment("NO_CLIPS"):
		WsgToonDriver.off = true
		FoundationLink.off = true
	get_tree().root.size = Vector2i(1280, 720)
	await Crowd.bake(self)
	Game.goto_menu()
	for i in 30:
		await get_tree().process_frame
	var runs := [
		["quick, village (ulama)", {"home": "ESC", "away": "LLA", "venue": "village", "mode": "quick", "user_team": 0}],
		["quick, festival", {"home": "ESC", "away": "LLA", "venue": "festival", "mode": "quick", "user_team": 0}],
		["quick, stone (classic, ritual)", {"home": "PIS", "away": "VAL", "venue": "stone", "mode": "quick", "user_team": 0}],
		["quick, night (classic)", {"home": "PIS", "away": "VAL", "venue": "night", "mode": "quick", "user_team": 0}],
		["tournament match", {"home": "ESC", "away": "LLA", "venue": "village", "mode": "cup", "user_team": 0, "stage": "Quarter-final"}],
		["Watch AI, stone", {"home": "PIS", "away": "VAL", "venue": "stone", "mode": "watch", "user_team": -1}],
		["play again (village)", {"home": "ESC", "away": "LLA", "venue": "village", "mode": "quick", "user_team": 0}],
	]
	for r in runs:
		var cfg: Dictionary = r[1].duplicate()
		cfg.rules = DB.venue(cfg.venue).rules
		cfg.seed = 3
		cfg.difficulty = 1
		await RenderingServer.frame_post_draw
		var t0 := Time.get_ticks_usec()
		Game.start_match(cfg)
		var built := Time.get_ticks_usec() - t0
		var last := t0
		var worst := 0
		var first := -1
		for f in 90:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			worst = maxi(worst, now - last)
			last = now
			if first < 0 and Game.current != null and Game.current.is_inside_tree() and Game.current.get("cam") != null:
				first = now - t0
		print("LOAD %-32s tap->first frame %5d ms   longest frame %5d ms   (built in %d ms, drawn in the rest)" % [r[0], first / 1000, worst / 1000, built / 1000])
		Game.goto_menu()
		for i in 30:
			await get_tree().process_frame
	get_tree().quit()
