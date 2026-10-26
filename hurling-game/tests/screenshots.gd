extends Node
## Renders a tour of the screens to PNGs. Needs a display (xvfb works):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/screenshots.tscn -- /out/dir [lang] [only]

var out := "user://shots"
var only := ""


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	if a.size() > 1 and a[1] != "":
		Game.settings.language = a[1]
		TranslationServer.set_locale(a[1])
		Game._size_theme()
	if a.size() > 2:
		only = a[2]
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_HIGH
	Game.delete_champ()
	var tour := [
		["menu", "res://ui/main_menu.gd", {}, 2.5], ["setup", "res://ui/quick_setup.gd", {}, 0.4],
		["settings", "res://ui/settings_screen.gd", {}, 0.4], ["howto", "res://ui/howto_screen.gd", {}, 0.4],
		["howto_controls", "res://ui/howto_screen.gd", {"tab": 1}, 0.4], ["champ_pick", "res://ui/champ_screen.gd", {}, 0.4],
		["move_buttons", "res://ui/buttons_screen.gd", {}, 0.4],
		["info_privacy", "res://ui/info_screen.gd", {"page": "privacy"}, 0.4], ["info_help", "res://ui/info_screen.gd", {"page": "help"}, 0.4],
	]
	for t in tour:
		if only != "" and not String(t[0]).begins_with(only):
			continue
		Game.show_screen(t[1], t[2])
		await _wait(t[3])
		await shot(t[0])
	if only == "" or only.begins_with("champ"):
		var c: Championship = Game.new_champ("TIP")
		for i in 3:
			var f := c.next_fixture()
			if f.is_empty():
				c.play_others()
				continue
			var r := Sim.play(String(f.home), String(f.away))
			c.record_user_result({"home": f.home, "away": f.away, "score": r.score, "winner": r.winner})
		Game.save_champ()
		var h := Game.show_screen("res://ui/champ_screen.gd")
		await _wait(0.3)
		await shot("champ_next")
		h._tab = 1
		h._fill()
		await _wait(0.3)
		await shot("champ_tables")
		Game.delete_champ()
	if only == "" or only.begins_with("match"):
		var venue := "county" if only == "" else only.trim_prefix("match_")
		if not DB.VENUES.has(venue):
			venue = "county"
		Game.start_match({"home": "KIL", "away": "TIP", "venue": venue, "difficulty": 1, "mode": "quick", "user_team": 0, "seed": 7})
		await _wait(3.5)
		await shot("match_intro")
		for i in 6:
			await _wait(2.5)
			await shot("match_play_%d" % i)
	if only == "" or only.begins_with("result"):
		var r := Sim.play("KIL", "TIP")
		r.config = {"mode": "quick", "stage": "Semi-final"}
		r.user_team = 0
		r.pstats = {}
		for id in r.scorers:
			var team_k := 0 if String(id).begins_with("KIL") else 1
			r.pstats[id] = {"goals": r.scorers[id][0], "points": r.scorers[id][1], "free_g": 0, "free_p": 0, "wides": 0, "team": team_k, "num": 0}
		r.tstats = [{"shots": 30, "wides": 9, "frees": 10}, {"shots": 26, "wides": 8, "frees": 12}]
		r.star = r.scorers.keys()[0]
		Game.show_screen("res://ui/result_screen.gd", {"result": r})
		await _wait(0.4)
		await shot("result")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)
