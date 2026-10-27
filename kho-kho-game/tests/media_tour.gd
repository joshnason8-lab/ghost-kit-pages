extends Node
## The pictures for the store and the media kit, from the game itself (tools/store/make_kit.sh runs it):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/media_tour.tscn -- OUT menus|action
## menus: every screen, in English, at 1920 x 1080, named by screen (01_home.png ...).
## action [ground,ground...]: matches on each ground on High, caught at their moments: a kho, a dive, a pole turn, an out and the crowd
## up for it (the HUD on: what a player sees), and a wide view of each ground with the HUD off.

var out := ""
var _want := {}      # event kind -> file name, for the match being filmed
var _m: Node = null


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	var mode := a[1] if a.size() > 1 else "menus"
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	# The settings as a new player has them, whatever the machine's saved ones say (make_kit.sh also runs this with
	# its own empty user folder).
	var fresh := {"camera": Game.CAM_TV, "difficulty": 1, "format": Game.FMT_CLASSIC, "turn_len": 0, "tags": 0, "btn_size": 0,
			"btn_places": {}, "left_handed": false, "music": true, "vibration": true, "fps": Game.FPS_SMOOTH,
			"follow_on": true, "powerplay": true, "lane_assist": true, "dev": false}
	for k in fresh:
		Game.settings[k] = fresh[k]
	Game.settings.coach = false
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.auto_gfx = false
	get_tree().root.size = Vector2i(1920, 1080)
	Game._size_theme()
	ModelBody.warm()
	await Crowd.render_sheet(get_tree())
	if mode == "menus":
		await _menus()
	else:
		await _action(a[2].split(",") if a.size() > 2 else [])
	get_tree().quit()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _menus() -> void:
	var menu := Game.show_screen("res://ui/main_menu.gd")
	await _wait(90)
	await _shot("01_home")
	menu._open_language()
	await _wait(12)
	await _shot("02_language")
	menu._picker.close()
	var setup := Game.show_screen("res://ui/match_setup.gd")
	await _wait(20)
	await _shot("03_quick_match_setup")
	setup._show_toss()
	await _wait(8)
	await _shot("04_toss")
	Game.show_screen("res://ui/match_setup.gd", {"watch": true})
	await _wait(12)
	await _shot("05_watch_a_match")
	Game.delete_cup()
	Game.show_screen("res://ui/cup_screen.gd")
	await _wait(12)
	await _shot("06_championships")
	var cup = Game.new_cup("national", "MAH")
	cup.sim_round(true)
	Game.save_cup()
	Game.show_screen("res://ui/cup_screen.gd")
	await _wait(12)
	await _shot("07_championship_groups")
	Game.delete_cup()
	var st := Game.show_screen("res://ui/settings_screen.gd")
	await _wait(12)
	await _shot("08_settings")
	for sc in st.find_children("*", "ScrollContainer", true, false):
		(sc as ScrollContainer).scroll_vertical = 100000
	await _wait(6)
	await _shot("09_settings_more")
	for tab in 3:
		Game.show_screen("res://ui/howto_screen.gd", {"tab": tab})
		await _wait(12)
		await _shot("%02d_how_to_play_%s" % [10 + tab, ["rules", "controls", "moves"][tab]])
	Game.show_screen("res://ui/records_screen.gd")
	await _wait(10)
	await _shot("13_records")
	Game.show_screen("res://ui/button_layout.gd")
	await _wait(10)
	await _shot("14_move_buttons")
	Game.show_screen("res://ui/licences_screen.gd")
	await _wait(10)
	await _shot("15_licences")
	Game.show_screen("res://ui/help_screen.gd")
	await _wait(10)
	await _shot("16_help")
	Game.show_screen("res://ui/privacy_screen.gd")
	await _wait(10)
	await _shot("17_privacy")
	Game.start_match({"home": "MAH", "away": "ODI", "venue": "school", "format": KhoRules.CLASSIC, "turn_len": 300.0,
		"difficulty": 1, "mode": "quick", "user_team": 0, "chase_first": 0, "seed": 3})
	await _wait(200)
	await _shot("18_match")
	var m: Node = Game.current
	m.set_paused(true)
	await _wait(8)
	await _shot("19_pause")
	m.set_paused(false)
	m.hud.show_interval()
	await _wait(8)
	await _shot("20_between_turns")
	m.hud._interval.queue_free()
	var r := Sim.play("MAH", "ODI", KhoRules.CLASSIC, 540.0, false, false, 4)
	r.config = {"mode": "quick", "home": "MAH", "away": "ODI", "user_team": 0}
	r.stats = {}
	for k in 2:
		for pd in DB.pick(["MAH", "ODI"][k], false, 9, false):
			r.stats[pd.id] = {"name": pd.name, "num": pd.num, "side": k, "outs": 2, "dives": 1, "pole_dives": 0, "khos": 14,
				"def_time": 141.0, "best_run": 96.0, "run": 0.0, "times_out": 1, "fouls": 0}
	Game.show_screen("res://ui/result_screen.gd", {"result": r})
	await _wait(12)
	await _shot("21_result")


## Each ground, with a match on it (the AI on both sides, the camera low and close), caught at its moments.
func _action(only: Array) -> void:
	var specs := [["maidan", KhoRules.CLASSIC, "MAH", "ODI"], ["school", KhoRules.CLASSIC, "KAR", "KER"],
		["floodlit", KhoRules.CLASSIC, "TEL", "DEL"], ["arena", KhoRules.FAST, "IND", "NEP"]]
	for spec in specs:
		var v: String = spec[0]
		if not only.is_empty() and not v in only:
			continue
		Game.settings.camera = Game.CAM_TV
		Game.start_match({"home": spec[2], "away": spec[3], "venue": v, "format": spec[1], "turn_len": 300.0,
			"user_team": -1, "demo": true, "seed": 21, "mode": "quick", "chase_first": 0})
		_m = Game.current
		await _wait(150)
		# A wide view of the ground, the HUD off.
		_m.hud.visible = false
		_m._ring.visible = false
		_m.cam_locked = true
		_m.cam.position = Vector3(-6.0, 9.0, 26.0)
		_m.cam.look_at(Vector3(4.0, 3.0, -20.0))
		await _wait(2)
		await _shot("%s_ground" % v)
		_m.cam_locked = false
		_m.hud.visible = true
		_m._ring.visible = true
		_m._cam_mode = Game.CAM_CLOSE
		_want = {"kho": "%s_kho" % v, "dive": "%s_dive" % v, "pole_turn": "%s_pole_turn" % v, "out": "%s_out" % v}
		_m.game_event.connect(_on_event)
		var t := 0
		while not _want.is_empty() and t < 3600:
			await _wait(1)
			t += 1
		_m.game_event.disconnect(_on_event)


func _on_event(kind: String) -> void:
	# Not in a turn's first seconds, under its banner (the demo match starts itself again when it ends).
	if not _want.has(kind) or _m.clock > _m.turn_len - 3.0:
		return
	var name: String = _want[kind]
	_want.erase(kind)
	# The moment a little after it starts: the dive in the air, the swing half round, the crowd up after an out.
	var after: int = {"kho": 4, "dive": 7, "pole_turn": 8, "out": 20}.get(kind, 4)
	await _wait(after)
	await _shot(name)
