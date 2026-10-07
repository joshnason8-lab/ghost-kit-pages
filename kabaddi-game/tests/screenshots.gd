extends Node
## Renders a tour of screens and grounds to PNGs. Needs a display (xvfb works):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/screenshots.tscn -- /out/dir

var out := "user://shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_HIGH
	await _tour()
	get_tree().quit(0)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _tour() -> void:
	Game.show_screen("res://ui/main_menu.gd")
	await frames(40)
	await shot("01_menu")
	Game.show_screen("res://ui/quick_setup.gd")
	await frames(5)
	await shot("02_quick_setup")
	Game.show_screen("res://ui/create_player.gd")
	await frames(20)
	await shot("03_create_player")
	Game.delete_career()
	Game.new_career({"name": "Arjun Malik", "state": "STATE_HARYANA", "role": "raider", "skin": 2, "hair": 0, "build": 1})
	Game.show_screen("res://ui/auction_screen.gd")
	await frames(150)
	await shot("04_auction")
	Game.delete_cup()
	Game.new_cup("IND")
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(5)
	await shot("05_cup")

	var cams := {"dome": [0, 1, 2], "village": [0], "stadium": [2], "monsoon": [0], "beach": [0]}
	var pairs := {"dome": ["MUM", "CHD"], "village": ["PAT", "HYD"], "stadium": ["IND", "IRN"], "monsoon": ["KOL", "BLR"], "beach": ["CHE", "JAI"]}
	var i := 6
	for arena in cams.keys():
		Game.start_match({"home": pairs[arena][0], "away": pairs[arena][1], "arena": arena, "mode": "quick", "control": "all", "length": 0, "difficulty": 1})
		var m: Node = Game.current
		# Let the intro run, then wait for the raid to get going.
		var guard := 0
		while m.phase != "raid" and guard < 600:
			await get_tree().process_frame
			guard += 1
		await frames(70)
		for c in cams[arena]:
			m.cam.mode = c
			await frames(25)
			await shot("%02d_%s_cam%d" % [i, arena, c])
			i += 1
	Game.settings.language = "hi"
	TranslationServer.set_locale("hi")
	Game.show_screen("res://ui/main_menu.gd")
	await frames(30)
	await shot("%02d_menu_hindi" % i)
	TranslationServer.set_locale("ta")
	Game.show_screen("res://ui/settings_screen.gd")
	await frames(5)
	await shot("%02d_settings_tamil" % (i + 1))
	TranslationServer.set_locale("en")
