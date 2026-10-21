extends Node
## A tour of the screens, saved as PNGs (for checking by eye, and for the store's pictures):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/screenshots.tscn -- OUT_DIR [lang] [parts]
## parts: menus,match (both by default).

var out := "user://shots"
var lang := "en"
var parts := ["menus", "match"]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1 and args[1] != "":
		lang = args[1]
	if args.size() > 2 and args[2] != "":
		parts = Array(args[2].split(","))
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.language = lang
	TranslationServer.set_locale(lang)
	Game._size_theme()
	get_tree().root.size = Vector2i(1920, 1080)
	await frames(4)
	if "menus" in parts:
		await _menus()
	if "match" in parts:
		await _match()
	if "store" in parts:
		await _store()
	get_tree().quit()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _menus() -> void:
	Game.show_screen("res://ui/main_menu.gd")
	await frames(90)
	await shot("01_home")
	Game.show_screen("res://ui/quick_setup.gd")
	await frames(10)
	await shot("02_setup")
	Game.show_screen("res://ui/howto_screen.gd", {"tab": 1})
	await frames(10)
	await shot("03_howto_positions")
	Game.show_screen("res://ui/settings_screen.gd")
	await frames(10)
	await shot("04_settings")
	Game.show_screen("res://ui/result_screen.gd", {"result": (load("res://tests/fit_audit.gd") as Script).fake_result()})
	await frames(10)
	await shot("05_result")
	Game.delete_cup()
	var c = Game.new_cup("JAM")
	c.sim_next()
	Game.save_cup()
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(10)
	await shot("06_cup")
	var lg = Game.new_league("BBR")
	for i in 3:
		lg.sim_next()
	Game.save_league()
	Game.show_screen("res://ui/league_screen.gd")
	await frames(10)
	await shot("07_league")
	Game.delete_league()
	Game.delete_cup()


func _match() -> void:
	for v in [["arena", "AUS", "NZL"], ["outdoor", "MWI", "UGA"], ["hall", "ENG", "WAL"]]:
		Game.start_match({"home": v[1], "away": v[2], "venue": v[0], "quarter": 15, "difficulty": 1, "mode": "quick",
			"user_team": 0, "seed": 9})
		await frames(40)
		await shot("10_%s_centre" % v[0])
		await frames(200)
		await shot("11_%s_play" % v[0])
		await frames(160)
		await shot("12_%s_play2" % v[0])
	Game.goto_menu()
	await frames(4)


## The store's pictures: matches in the three venues as broadcast (no buttons), the home screen, How to Play's
## positions, and a match you play, with its buttons.
func _store() -> void:
	var n := 1
	for v in [["arena", "AUS", "NZL", 330], ["outdoor", "MWI", "UGA", 280], ["hall", "ENG", "WAL", 300]]:
		var m: Match = (load("res://game/match.gd") as Script).new()
		m.config = {"home": v[1], "away": v[2], "venue": v[0], "quarter": 15, "mode": "quick", "user_team": -1, "demo": true, "seed": 5}
		Game._swap(m)
		await frames(int(v[3]))
		await shot("store_%02d_%s" % [n, v[0]])
		n += 1
	Game.start_match({"home": "JAM", "away": "RSA", "venue": "arena", "quarter": 15, "difficulty": 1, "mode": "quick",
		"user_team": 0, "seed": 9})
	await frames(260)
	await shot("store_%02d_play" % n)
	n += 1
	Game.show_screen("res://ui/main_menu.gd")
	await frames(90)
	await shot("store_%02d_home" % n)
	n += 1
	Game.show_screen("res://ui/howto_screen.gd", {"tab": 1})
	await frames(10)
	await shot("store_%02d_positions" % n)
	n += 1
	Game.show_screen("res://ui/result_screen.gd", {"result": (load("res://tests/fit_audit.gd") as Script).fake_result()})
	await frames(10)
	await shot("store_%02d_result" % n)
