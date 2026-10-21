extends Node
## A tour of the screens and the grounds, saved as pictures to look at (and for the store):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/screenshots.tscn -- OUT_DIR [lang] [WxH]

var out := "user://shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1 and args[1] != "":
		Game.settings.language = args[1]
		TranslationServer.set_locale(args[1])
		Game._size_theme()
	if args.size() > 2 and args[2] != "":
		var wh := args[2].split("x")
		get_tree().root.size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_HIGH
	ToonBody.material(true)
	var menu := Game.show_screen("res://ui/main_menu.gd")
	await _wait(90)
	await _shot("01_home")
	menu._lane.kho(1)
	await _wait(9)
	await _shot("02_home_kho")
	await _wait(30)
	await _shot("03_setup")
	Game.current._show_toss()
	await _wait(6)
	await _shot("04_toss")
	for spec in [["maidan", KhoRules.CLASSIC, "MAH", "ODI", 0], ["arena", KhoRules.FAST, "IND", "NEP", 0],
			["floodlit", KhoRules.CLASSIC, "KAR", "KER", 1], ["school", KhoRules.CLASSIC, "TEL", "DEL", 0]]:
		Game.start_match({"home": spec[2], "away": spec[3], "venue": spec[0], "format": spec[1], "turn_len": 300.0,
			"user_team": spec[4], "seed": 11, "mode": "quick", "chase_first": 0})
		await _wait(200)
		await _shot("05_match_" + String(spec[0]))
	Game.show_screen("res://ui/howto_screen.gd")
	await _wait(10)
	await _shot("06_howto")
	Game.show_screen("res://ui/settings_screen.gd")
	await _wait(10)
	await _shot("07_settings")
	var c = Game.new_cup("world", "IND")
	c.sim_round(true)
	Game.save_cup()
	Game.show_screen("res://ui/cup_screen.gd")
	await _wait(10)
	await _shot("08_cup")
	Game.delete_cup()
	get_tree().quit()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name)
