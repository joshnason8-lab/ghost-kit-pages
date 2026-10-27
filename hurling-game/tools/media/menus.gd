extends Node
## Every menu screen, 1920 x 1080 PNG, in English, for the website's media kit (menus/): the home screen, the match
## set-ups, the championship, each part of Settings, How to Play's three tabs, Move buttons, the pause menu, a real
## result (a match simulated to full time), the HD pack, Licences, Help and the privacy policy.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --fixed-fps 30 res://tools/media/menus.tscn -- <out dir>
## (Run by tools/media/make_media_kit.sh.)

var out := ""


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.dev = false
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	Game._size_theme()
	TouchControls.key_hints = false
	Game.delete_champ()
	Game.clear_suspended()
	await _screen("01_home", "res://ui/main_menu.gd", {}, 3.0)
	await _screen("02_throw_in_setup", "res://ui/quick_setup.gd")
	await _screen("03_watch_a_match_setup", "res://ui/quick_setup.gd", {"watch": true})
	await _screen("04_championship_pick_county", "res://ui/champ_screen.gd")
	var c: Championship = Game.new_champ("TIP")
	for i in 4:
		var f := c.next_fixture()
		if f.is_empty():
			c.play_others()
			continue
		var r := Sim.play(String(f.home), String(f.away))
		c.record_user_result({"home": f.home, "away": f.away, "score": r.score, "winner": r.winner})
	Game.save_champ()
	var h := await _screen("05_championship_fixtures", "res://ui/champ_screen.gd")
	h._tab = 1
	h._fill()
	await _wait(0.5)
	await _shot("06_championship_tables")
	Game.delete_champ()
	# Settings: one page in four parts, each shot scrolled to its heading.
	var parts := [["07_settings_game_and_screen", "SET_GAME"], ["08_settings_sound_controls", "SET_SOUND_CONTROLS"],
		["09_settings_about", "SET_ABOUT"]]
	var s := await _screen("", "res://ui/settings_screen.gd")
	for p in parts:
		_scroll_to(s, tr(p[1]))
		await _wait(0.4)
		await _shot(p[0])
	await _screen("10_how_to_play_rules", "res://ui/howto_screen.gd", {"tab": 0})
	await _screen("11_how_to_play_controls", "res://ui/howto_screen.gd", {"tab": 1})
	await _screen("12_how_to_play_officials", "res://ui/howto_screen.gd", {"tab": 2})
	await _screen("13_move_buttons", "res://ui/buttons_screen.gd")
	# A match: the pause menu over it; then a match played for a minute (nothing drawn) and the rest simulated, as the
	# pause menu's Simulate to the end does, for a real result (a whole match takes hours on a software renderer).
	Game.start_match({"home": "KIL", "away": "TIP", "venue": "county", "user_team": 0, "seed": 5, "length": 8, "mode": "quick"})
	var m: Node = Game.current
	await _wait(4.0)
	m.set_paused(true)
	await _wait(0.5)
	await _shot("14_pause")
	m.quit_match()
	Game.clear_suspended()
	Game.start_match({"home": "KIL", "away": "TIP", "venue": "county", "user_team": -1, "seed": 8, "length": 8, "mode": "watch"})
	RenderingServer.render_loop_enabled = false
	await _wait(60.0)
	if _where() == "match.gd":
		Game.current.sim_to_end()
	var guard := 0
	while _where() != "result_screen.gd" and guard < 30 * 60:
		await get_tree().process_frame
		guard += 1
	RenderingServer.render_loop_enabled = true
	await _wait(1.0)
	await _shot("15_result")
	await _screen("16_hd_pack", "res://ui/hd_pack_screen.gd", {}, 3.0)
	await _screen("17_licences", "res://ui/licences_screen.gd")
	await _screen("18_help", "res://ui/info_screen.gd", {"page": "help"})
	await _screen("19_privacy_policy", "res://ui/info_screen.gd", {"page": "privacy"})
	get_tree().quit()


func _screen(name: String, path: String, args := {}, secs := 0.6) -> Node:
	var n := Game.show_screen(path, args)
	await _wait(secs)
	if name != "":
		await _shot(name)
	return n


func _where() -> String:
	if Game.current == null or not is_instance_valid(Game.current):
		return ""
	return Game.current.get_script().resource_path.get_file()


## Scrolls the screen's scrolling box so the heading with this text is at its top.
func _scroll_to(screen: Node, heading: String) -> void:
	var sc: ScrollContainer = screen.find_children("*", "ScrollContainer", true, false)[0]
	for l in screen.find_children("*", "Label", true, false):
		if (l as Label).text == heading:
			sc.scroll_vertical = int((l as Label).global_position.y - sc.global_position.y + sc.scroll_vertical - 24.0)
			return


func _wait(s: float) -> void:
	for i in int(s * 30.0):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out.path_join(name + ".png"))
	print("menu ", name)
