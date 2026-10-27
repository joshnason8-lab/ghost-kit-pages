extends Node
## A tour of the screens, saved as PNGs (for checking by eye, and for the store's pictures):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/screenshots.tscn -- OUT_DIR [lang] [parts]
## parts: menus,match (both by default), store, media. A fourth argument sets the graphics: low, medium or high.
## media: the media kit's pictures; kitmenus: every menu screen for the kit, a picture per scroll page
## (tools/media/make_media_kit.sh runs both on High).

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
	if args.size() > 3:   # the graphics level: low, medium or high
		Game.settings.graphics = ["low", "medium", "high"].find(args[3])
		ToonBody.material(int(Game.settings.graphics) > Game.GFX_LOW)
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
	if "media" in parts:
		await _media()
	if "kitmenus" in parts:
		await _kit_menus()
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
	for about in ["help", "privacy"]:
		Game.show_screen("res://ui/%s_screen.gd" % about)
		await frames(8)
		await shot("04_%s" % about)
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


## The media kit's pictures (tools/media): the three venues' play as broadcast (AI v AI, the scoreboard and no
## buttons): a centre pass, a shot under the post, a goal with the close shot and the boards crying it; the team card;
## the home screen, quick setup, the Nations Cup, How to Play and a result. While it waits for a moment of play
## nothing is drawn (the match runs on at the fixed frame rate; on software GL a High frame costs a second).
func _media() -> void:
	Game.settings.auto_gfx = false   # never lowered for running slowly
	Game.settings.dev = false
	Game.settings.camera = Game.CAM_TV
	var seen := {}
	var m: Match = _media_match("arena", "AUS", "NZL", 5)
	m.game_event.connect(func(k: String, info: Dictionary): seen[k] = info)
	await drawn(45)
	await shot("media_01_arena_centre_pass")
	await until(seen, "shot_start", 12)
	await shot("media_02_arena_shot")
	await until(seen, "goal", 24)
	await shot("media_03_arena_goal")
	m = _media_match("hall", "ENG", "WAL", 7)
	seen.clear()
	m.game_event.connect(func(k: String, info: Dictionary): seen[k] = info)
	await drawn(220)
	await shot("media_04_hall_play")
	await until(seen, "goal", 20)
	await shot("media_05_hall_goal")
	m = _media_match("outdoor", "MWI", "UGA", 5)
	await drawn(280)
	await shot("media_06_outdoor_play")
	m = _media_match("arena", "JAM", "RSA", 3)
	m.hud.show_card()
	await drawn(24)
	await shot("media_07_team_card")
	RenderingServer.render_loop_enabled = true
	Game.show_screen("res://ui/main_menu.gd")
	await drawn(90)
	await shot("media_08_home")
	Game.show_screen("res://ui/quick_setup.gd", {"home": "ENG", "away": "JAM"})
	await drawn(12)
	await shot("media_09_quick_setup")
	Game.delete_cup()
	var c = Game.new_cup("JAM")
	c.sim_next()
	Game.save_cup()
	Game.show_screen("res://ui/cup_screen.gd")
	await drawn(12)
	await shot("media_10_nations_cup")
	Game.delete_cup()
	Game.show_screen("res://ui/howto_screen.gd", {"tab": 1})
	await drawn(12)
	await shot("media_11_how_to_play")
	Game.show_screen("res://ui/result_screen.gd", {"result": (load("res://tests/fit_audit.gd") as Script).fake_result()})
	await drawn(12)
	await shot("media_12_result")
	RenderingServer.render_loop_enabled = true


func _media_match(venue: String, home: String, away: String, seed_n: int) -> Match:
	var m: Match = (load("res://game/match.gd") as Script).new()
	m.config = {"home": home, "away": away, "venue": venue, "quarter": 15, "mode": "quick", "user_team": -1,
		"demo": true, "seed": seed_n}
	Game._swap(m)
	return m


## n frames, only the last few drawn.
func drawn(n: int) -> void:
	RenderingServer.render_loop_enabled = false
	await frames(maxi(0, n - 4))
	RenderingServer.render_loop_enabled = true
	await frames(mini(n, 4))


## Undrawn until the match's next event of this kind (or two minutes), then n frames, the last few drawn.
func until(seen: Dictionary, kind: String, n: int) -> void:
	seen.erase(kind)
	RenderingServer.render_loop_enabled = false
	for i in 3600:
		if seen.has(kind):
			break
		await get_tree().process_frame
	await drawn(n)


## Every menu screen for the media kit, clean (English, no debug overlay), saved as menu_NN_<screen>: a screen that
## scrolls is saved a page at a time (_2, _3...).
func _kit_menus() -> void:
	Game.settings.auto_gfx = false
	Game.settings.dev = false
	RenderingServer.render_loop_enabled = true
	_menu_n = 1
	await _page("res://ui/main_menu.gd", {}, "home", 90)
	await _page("res://ui/quick_setup.gd", {"home": "ENG", "away": "JAM"}, "quick_setup")
	# Settings as a player first sees them (this tour turns the sound and the automatic graphics off).
	Game.settings.sound = true
	Game.settings.auto_gfx = true
	await _page("res://ui/settings_screen.gd", {}, "settings")
	Game.settings.sound = false
	Game.settings.auto_gfx = false
	for t in 4:
		await _page("res://ui/howto_screen.gd", {"tab": t}, "how_to_play_%d_%s" % [t + 1,
			["the_game", "positions", "rules", "controls"][t]])
	# A match you play: its pause menu, and the interval at quarter time.
	Game.start_match({"home": "ENG", "away": "JAM", "venue": "arena", "quarter": 15, "difficulty": 1, "mode": "quick",
		"user_team": 0, "seed": 9})
	await drawn(120)
	var m = Game.current
	m.set_paused(true)
	await drawn(12)
	await shot("menu_%02d_pause" % _menu_n)
	_menu_n += 1
	m.set_paused(false)
	m.hud.show_break(1, 2)
	await drawn(12)
	await pages("menu_%02d_interval" % _menu_n)
	_menu_n += 1
	m.hud.hide_break()
	await _page("res://ui/result_screen.gd", {"result": (load("res://tests/fit_audit.gd") as Script).fake_result()},
		"result")
	Game.delete_cup()
	await _page("res://ui/cup_screen.gd", {}, "nations_cup_pick")
	var c = Game.new_cup("JAM")
	c.sim_next()
	c.sim_next()
	Game.save_cup()
	await _page("res://ui/cup_screen.gd", {}, "nations_cup")
	Game.delete_cup()
	Game.delete_league()
	await _page("res://ui/league_screen.gd", {}, "club_season_pick")
	var lg = Game.new_league("BBR")
	for i in 3:
		lg.sim_next()
	Game.save_league()
	await _page("res://ui/league_screen.gd", {}, "club_season")
	Game.delete_league()
	# The record book, filled in for the picture (not saved).
	var kept: Dictionary = Game.records
	Game.records = {"played": 12, "won": 8, "drawn": 1, "lost": 3, "goals": 498, "best_margin": 14,
		"best_win": "JAM 53 – 39 TTO", "top_shooter_goals": 41, "top_shooter": "%s (GS)" % DB.squad("JAM")[0].name,
		"cups_played": 2, "cups_won": 1, "seasons_played": 1, "titles_won": 0}
	await _page("res://ui/records_screen.gd", {}, "records")
	Game.records = kept
	await _page("res://ui/licences_screen.gd", {}, "licences", 30, 1)   # the credits; then the legal texts
	await _page("res://ui/help_screen.gd", {}, "help")
	await _page("res://ui/privacy_screen.gd", {}, "privacy")
	Game.goto_menu()
	await frames(4)


var _menu_n := 1


func _page(script: String, args: Dictionary, name: String, settle := 12, most_pages := 4) -> void:
	Game.show_screen(script, args)
	await drawn(settle)
	await pages("menu_%02d_%s" % [_menu_n, name], most_pages)
	_menu_n += 1


## A shot of the screen, and of each further page of its scroll boxes (one box at a time, the others at the top);
## at most 1 + most_pages pages a box.
func pages(name: String, most_pages := 4) -> void:
	await shot(name)
	var k := 2
	for sc: ScrollContainer in Game.current.find_children("*", "ScrollContainer", true, false):
		if not sc.is_visible_in_tree():
			continue
		var bar := sc.get_v_scroll_bar()
		var most := int(bar.max_value - bar.page)
		if most <= 8:
			continue
		var step := int(sc.size.y * 0.85)
		var y := 0
		for i in most_pages:
			if y >= most:
				break
			y = mini(most, y + step)
			sc.scroll_vertical = y
			await drawn(3)
			await shot("%s_%d" % [name, k])
			k += 1
		sc.scroll_vertical = 0
		await drawn(2)
