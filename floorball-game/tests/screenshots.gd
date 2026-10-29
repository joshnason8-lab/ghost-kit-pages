extends Node
## Pictures of the game, to look at: the home screen, the setup, a match at several moments and from each camera,
## the result. Needs a window (xvfb on a server):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 res://tests/screenshots.tscn -- OUT_DIR [lang] [WxH]

var out := "user://shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	if args.size() > 1:
		Game.settings.language = args[1]
		TranslationServer.set_locale(args[1])
		Game._size_theme()
	if args.size() > 2:
		var wh := args[2].split("x")
		get_tree().root.size = Vector2i(int(wh[0]), int(wh[1]))
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = int(Game.settings.get("graphics", 2)) if Game.settings.graphics >= 0 else 2
	await frames(4)
	Game.goto_menu()
	await frames(90)
	await shot("01_menu")
	Game.show_screen("res://ui/quick_setup.gd")
	await frames(10)
	await shot("02_setup")
	Game.start_match({"home": "SWE", "away": "FIN", "venue": "arena", "user_team": 0, "mode": "quick", "seed": 11, "period": 8.0})
	await frames(30)
	await shot("03_intro")
	await frames(300)
	await shot("04_play")
	await frames(420)
	await shot("05_play")
	var m: Node = Game.current
	m.cam.mode = Game.CAM_HIGH
	await frames(90)
	await shot("06_high")
	m.cam.mode = Game.CAM_END
	await frames(90)
	await shot("07_end")
	m.cam.mode = Game.CAM_TV
	m.set_paused(true)
	await frames(4)
	await shot("08_pause")
	m.set_paused(false)
	Game.start_match({"home": "SUI", "away": "CZE", "venue": "hall", "user_team": 0, "mode": "quick", "seed": 5, "period": 8.0, "women": true})
	await frames(500)
	await shot("09_hall")
	Game.start_match({"home": "LAT", "away": "SVK", "venue": "school", "user_team": 0, "mode": "quick", "seed": 8, "period": 8.0})
	await frames(500)
	await shot("10_school")
	Game.show_screen("res://ui/howto_screen.gd", {"tab": 2})
	await frames(8)
	await shot("11_signs")
	Game.show_screen("res://ui/settings_screen.gd")
	await frames(8)
	await shot("12_settings")
	get_tree().quit()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name)
