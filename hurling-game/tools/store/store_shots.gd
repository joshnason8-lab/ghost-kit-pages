extends Node
## The store's screenshots, 1920 x 1080, from the game itself: matches at their moments (a roll spike as it is hit, a
## serve, a block), and the menus. Writes store/graphics/screenshots/ and store/graphics/feature_src.png:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1920x1080 res://tools/store/store_shots.tscn

var out := "res://store/graphics/screenshots"


func _ready() -> void:
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.assist = 2
	Game.settings.game_speed = 2
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	var only := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	if only == "feature":
		await _moment("01_roll_spike", {"home": "THA", "away": "MAS", "venue": "dome", "seed": 11}, "attack", "roll")
		get_tree().quit()
		return
	await _moment("01_roll_spike", {"home": "THA", "away": "MAS", "venue": "dome", "seed": 11}, "attack", "roll")
	await _moment("02_serve", {"home": "VIE", "away": "INA", "venue": "national", "seed": 3}, "serve", "")
	await _moment("03_mall", {"home": "MAS", "away": "THA", "venue": "mall", "seed": 21, "stage": "Final"}, "set", "")
	await _moment("04_beach", {"home": "PHI", "away": "LAO", "venue": "beach", "seed": 8}, "attack", "")
	Game.delete_season()
	Game.delete_cup()
	Game.show_screen("res://ui/main_menu.gd")
	await _wait(2.0)
	await _shot("05_menu")
	var se = Game.new_season("TH", "SPB")
	for i in 4:
		se.sim_round()
	Game.show_screen("res://ui/season_hub.gd")
	await _wait(0.5)
	await _shot("06_season")
	var cup = Game.new_cup("world", "MAS")
	cup.sim_next()
	cup.sim_next()
	Game.show_screen("res://ui/cup_screen.gd")
	await _wait(0.5)
	await _shot("07_world_cup")
	Game.settings.language = "th"
	TranslationServer.set_locale("th")
	Game._size_theme()
	Game.show_screen("res://ui/main_menu.gd")
	await _wait(2.0)
	await _shot("08_thai")
	Game.delete_season()
	Game.delete_cup()
	get_tree().quit()


## Plays a match until the moment: a touch of kind (and move) about to be made by the left-hand side.
func _moment(name: String, cfg: Dictionary, kind: String, mv: String) -> void:
	var c := {"event": "regu", "sets": 3, "points": 15, "difficulty": 2, "mode": "quick", "user_team": 0, "women": false}
	c.merge(cfg, true)
	Game.start_match(c)
	var m: Node = Game.current
	var guard := 0
	while guard < 60 * 120:
		await get_tree().process_frame
		guard += 1
		var p: Dictionary = m.plan
		if p.is_empty():
			continue
		var target := String(p.kind) == kind and (mv == "" or String(p.move) == mv)
		# Nothing is played for you: press for each of your touches, the one to picture a little early so its move is
		# under way.
		if bool(p.get("user", false)) and not p.has("press_t") and float(m.now) >= float(p.t) - (0.15 if target else 0.02):
			m._on_action(String((m.input_window.get("choices", ["KICK"]) as Array)[0]))
		if not target:
			continue
		if float(p.t) - float(m.now) < (0.04 if kind != "serve" else 0.12):
			m.paused = true
			break
	await _wait(0.1)
	await _shot(name)
	if name == "01_roll_spike":
		m.hud.visible = false
		m.controls.visible = false
		for side in 2:
			for pl in m.players_on(side):
				pl.set_tag("")
		await _wait(0.1)
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://store/graphics/feature_src.png"))
	Game.goto_menu()
	await _wait(0.3)


func _wait(s: float) -> void:
	for i in maxi(1, int(s * 30.0)):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(out.path_join(name + ".jpg"), 0.9)
	print("shot ", name)
