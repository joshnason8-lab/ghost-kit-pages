extends Node
## The store's screenshots, rendered from the game at 1920 x 1080 on High graphics: matches on each court (the hip
## strikes, the dives, the ring's moment), the home screen's stela, match setup, the tournament and How to Play.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tools/store/store_shots.tscn -- OUT_DIR [only]

var out := "/tmp"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "/tmp"
	var only := String(args[1]) if args.size() > 1 else ""
	Game.main = self
	Game.settings.sound = false
	Game.settings.coach = false
	Game.settings.dev = false
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.auto_gfx = false   # the software renderer here is slow; keep High for the pictures
	TouchControls.key_hints = false
	get_tree().root.size = Vector2i(1920, 1080)
	await Crowd.bake(self)
	var shots := [
		["01_village", "es", "match", {"venue": "village", "home": "ESC", "away": "LLA"}, 9.0],
		["02_stone", "en", "match", {"venue": "stone", "home": "PIS", "away": "VAL"}, 11.0],
		["03_night", "es", "match", {"venue": "night", "home": "FLO", "away": "COP"}, 13.0],
		["04_festival", "pt", "match", {"venue": "festival", "home": "SAV", "away": "QUE"}, 10.0],
		["05_home", "es", "res://ui/main_menu.gd", {}, 4.0],
		["06_setup", "en", "res://ui/quick_setup.gd", {}, 2.0],
		["07_howto", "es", "res://ui/howto_screen.gd", {"tab": 3}, 2.0],
		["08_cup", "fr", "res://ui/cup_screen.gd", {}, 2.0],
	]
	for s in shots:
		if only != "" and not String(s[0]).begins_with(only):
			continue
		Game.settings.language = s[1]
		TranslationServer.set_locale(s[1])
		Game._size_theme()
		if s[2] == "match":
			var cfg: Dictionary = s[3]
			var rules := String(DB.venue(cfg.venue).rules)
			Game.start_match({"home": cfg.home, "away": cfg.away, "venue": cfg.venue, "rules": rules, "side": 5 if rules == "ulama" else 3,
				"user_team": -1, "seed": 7, "mode": "watch", "length": 10, "difficulty": 2, "stage": tr("FRIENDLY")})
			var m: Node = Game.current
			for i in int(float(s[4]) * 30.0):
				await get_tree().process_frame
			# Roll on until someone is mid hip-strike or dive, for a lively picture.
			var guard := 0
			while guard < 300:
				guard += 1
				await get_tree().process_frame
				var acting := false
				for pl in m.all_players():
					if pl.action in [Player.A.STRIKE, Player.A.DIVE] and pl.action_u() > 0.3 and pl.action_u() < 0.6:
						acting = true
				if acting:
					break
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, s[0]])
			print("shot ", s[0])
			continue
		else:
			if String(s[2]).ends_with("cup_screen.gd"):
				Game.settings.mode = "classic"
				Game.new_cup("PIS")
				var c: Cup = Game.get_cup()
				var f := c.next_fixture()
				var r := Sim.play(String(f.home), String(f.away), c.rules, 3)
				c.record_user_result({"home": f.home, "away": f.away, "winner": 0 if f.home == "PIS" else 1, "count": r.count})
				Game.save_cup()
			Game.show_screen(String(s[2]), s[3])
		for i in int(float(s[4]) * 30.0):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, s[0]])
		print("shot ", s[0])
	Game.delete_cup()
	get_tree().quit()
