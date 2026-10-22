extends Node
## The store's screenshots, 1920 x 1080, from the game itself: matches at their moments (a strike for a point, a
## catch in the air), at each ground, and the menus, two of them in Irish. Writes store/graphics/screenshots/ (the
## feature graphic is the owner's artwork: make_feature.py):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 res://tools/store/store_shots.tscn [-- only]

var out := "res://store/graphics/screenshots"


func _ready() -> void:
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.dev = false
	TouchControls.key_hints = false
	_lang("en")
	var only := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	if only == "" or only == "matches":
		await _moment("01_strike", {"home": "COR", "away": "LIM", "venue": "stadium", "seed": 12, "stage": tr("STAGE_FINAL")}, ["strike", "strike_stick"])
		await _moment("02_catch", {"home": "GAL", "away": "CLA", "venue": "county", "seed": 7}, ["catch"])
		await _moment("03_parish", {"home": "WEX", "away": "KIL", "venue": "parish", "seed": 3}, ["strike", "strike_stick", "hand_pass"])
		await _moment("04_lights", {"home": "DUB", "away": "WAT", "venue": "night", "seed": 9}, ["catch", "lift", "strike"])
	if only == "" or only == "menus":
		Game.delete_champ()
		Game.show_screen("res://ui/main_menu.gd")
		await _wait(3.0)
		await _shot("05_programme")
		Game.show_screen("res://ui/quick_setup.gd")
		await _wait(0.5)
		await _shot("06_team_sheets")
		var c: Championship = Game.new_champ("TIP")
		for i in 6:
			var f := c.next_fixture()
			if f.is_empty():
				c.play_others()
				continue
			var r := Sim.play(String(f.home), String(f.away))
			c.record_user_result({"home": f.home, "away": f.away, "score": r.score, "winner": r.winner})
		Game.save_champ()
		var h := Game.show_screen("res://ui/champ_screen.gd")
		await _wait(0.3)
		h._tab = 1
		h._fill()
		await _wait(0.5)
		await _shot("07_championship")
		Game.delete_champ()
		_lang("ga")
		Game.show_screen("res://ui/main_menu.gd")
		await _wait(3.0)
		await _shot("08_as_gaeilge")
		await _moment("09_cluiche", {"home": "LIM", "away": "COR", "venue": "county", "seed": 14}, ["strike", "strike_stick"])
		_lang("en")
	get_tree().quit()


func _lang(code: String) -> void:
	Game.settings.language = code
	TranslationServer.set_locale(code)
	Game._size_theme()


## Plays a match until one of the actions is under way near the ball, in the picture, then pauses on it.
func _moment(name: String, cfg: Dictionary, actions: Array, hud := true) -> void:
	var c := {"difficulty": 2, "mode": "quick", "user_team": 0, "length": 30}
	c.merge(cfg, true)
	Game.start_match(c)
	var m: Node = Game.current
	if not hud:
		m.hud.visible = false
		m.controls.visible = false
	var guard := 0
	var found := false
	# Nothing is drawn while the moment is looked for (a software renderer draws 1080p slowly); on again for the shot.
	RenderingServer.render_loop_enabled = false
	while guard < 30 * 120 and not found:
		await get_tree().process_frame
		guard += 1
		if guard < 30 * 6:
			continue
		for p in m.all_players():
			var pl: Player = p
			if pl.action in actions and pl.action_t > pl.contact_time(pl.action) * 0.6 and pl.action_t < pl.contact_time(pl.action) * 1.1 \
					and pl.global_position.distance_to(m.ball.global_position) < 3.0 and m.cam.camera.is_position_in_frustum(pl.global_position):
				found = true
				break
	m.paused = true
	RenderingServer.render_loop_enabled = true
	await _wait(0.1)
	await _shot(name)
	m.paused = false


func _wait(s: float) -> void:
	for i in int(s * 30.0):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if name.begins_with("../"):
		img.save_png(out.path_join(name + ".png"))
	else:
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(out.path_join(name + ".jpg"), 0.9)
	print("shot ", name)
