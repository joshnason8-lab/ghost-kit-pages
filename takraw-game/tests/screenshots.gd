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
	Game.delete_season()
	Game.delete_cup()
	var tour := [
		["menu", "res://ui/main_menu.gd", {}, 1.5], ["quick", "res://ui/quick_setup.gd", {}, 0.4],
		["settings", "res://ui/settings_screen.gd", {}, 0.4], ["howto", "res://ui/howto_screen.gd", {}, 0.4],
		["moves", "res://ui/howto_screen.gd", {"tab": 2}, 0.4], ["season_pick", "res://ui/season_hub.gd", {}, 0.4],
		["cup_pick", "res://ui/cup_screen.gd", {}, 0.4], ["records", "res://ui/records_screen.gd", {}, 0.4],
		["privacy", "res://ui/doc_screen.gd", {"kind": "privacy"}, 0.4], ["help", "res://ui/doc_screen.gd", {"kind": "help"}, 0.4],
	]
	for t in tour:
		if only != "" and not String(t[0]).begins_with(only):
			continue
		Game.show_screen(t[1], t[2])
		await _wait(t[3])
		await shot(t[0])
	if only == "" or only.begins_with("season"):
		for ls in [["MY", "KLC", 9, "season_hub"], ["TH", "SPB", 5, "season_th"], ["ID", "SOL", 6, "season_id"], ["MY", "PRK", 300, "season_end"]]:
			Game.new_season(ls[0], ls[1])
			for i in int(ls[2]):
				if Game.season.phase != "done":
					Game.season.sim_round()
			Game.show_screen("res://ui/season_hub.gd")
			await _wait(0.4)
			await shot(ls[3])
	if only == "" or only.begins_with("cup"):
		Game.new_cup("royal", "MAS")
		Game.cup.sim_next()
		Game.show_screen("res://ui/cup_screen.gd")
		await _wait(0.4)
		await shot("cup_hub")
	if only == "" or only.begins_with("match"):
		Game.start_match({"home": "THA", "away": "MAS", "venue": "national", "event": "regu", "sets": 3, "points": 15,
			"difficulty": 1, "mode": "quick", "user_team": 0, "seed": 7})
		await _wait(3.5)
		await shot("match_serve")
		await _wait(2.0)
		await shot("match_rally")
		await _wait(4.0)
		await shot("match_rally2")
	if only == "" or only.begins_with("result"):
		var r := Sim.play("THA", "MAS")
		r.config = {"mode": "quick", "stage": "Semi-final", "home": "THA", "away": "MAS"}
		r.user_team = 0
		r.potm = r.stats.values()[0]
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
