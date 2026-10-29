extends Node
## Renders a tour of screens and grounds to PNGs. Needs a display (xvfb works):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/screenshots.tscn -- /out/dir

var out := "user://shots"
var args_only := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		args_only = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_HIGH
	await _tour()
	get_tree().quit(0)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _tour() -> void:
	# A language's code and a colon in front of any tour renders it in that language: "hi:menus", "ta:tags".
	if args_only.find(":") == 2 and args_only.left(2) in ["en", "hi", "mr", "ta", "te", "kn", "bn", "pa"]:
		Game.settings.language = args_only.left(2)
		TranslationServer.set_locale(args_only.left(2))
		args_only = args_only.substr(3)
	if args_only == "moves":
		await _moves()
		return
	if args_only == "tags":
		await _tags()
		return
	if args_only == "hud":
		await _hud()
		return
	if args_only == "store":
		await _store()
		return
	if args_only == "store_extra":
		await _store_extra()
		return
	if args_only == "dev":
		# The developer's overlay over a raid (DevOverlay), as a tester sees it after seven taps on the version.
		var dev_was: bool = Game.settings.dev
		Game.settings.dev = true
		Game.start_match({"home": "CHE", "away": "DEL", "arena": "dome", "mode": "quick", "control": "all", "length": 0,
			"difficulty": 1, "first_raider": 0})
		var dm: Node = Game.current
		var dg := 0
		while dm.phase != "raid" and dg < 900:
			await get_tree().process_frame
			dg += 1
		await frames(90)
		await shot("dev_overlay")
		Game.settings.dev = dev_was
		Game.save_settings()   # the match may have saved it on (lowering the graphics saves the settings)
		return
	if args_only == "awards":
		var sq: Array = DB.team("PAT").squad
		var aw := {"mvp": {"pid": sq[0].id, "name": sq[0].name, "team": "PAT", "raid": 212, "tackle": 14},
			"raider": {"pid": sq[0].id, "name": sq[0].name, "team": "PAT", "raid": 212, "tackle": 14},
			"defender": {"pid": "DEL_6", "name": DB.team("DEL").squad[6].name, "team": "DEL", "raid": 3, "tackle": 71}}
		Game.show_screen("res://ui/awards_screen.gd", {"awards": aw, "label": "Season 1", "mine": "PAT"})
		await frames(40)
		await shot("30_awards")
		return
	if args_only == "language":
		# The main menu's language picker, then the menu rebuilt in Tamil.
		var menu := Game.show_screen("res://ui/main_menu.gd")
		await frames(120)
		menu._open_language()
		await frames(20)
		await shot("lang_1_picker")
		var tamil: Button = menu._picker.find_children("*", "Button", true, false)[5]
		tamil.pressed.emit()
		await frames(40)
		await shot("lang_2_menu_ta")
		menu._open_language()
		await frames(20)
		await shot("lang_3_picker_ta")
		Game.set_language("")
		return
	if args_only.begins_with("fans"):
		# The crowd on each ground (or one: "fans:dome"), from the broadcast camera and close up from the court.
		var only := args_only.substr(5) if args_only.length() > 5 else ""
		for g in ["dome", "stadium", "village", "monsoon", "beach"]:
			if only != "" and g != only:
				continue
			Game.start_match({"home": "MUM", "away": "PUN", "arena": g, "mode": "quick", "length": 0, "difficulty": 1,
				"autoplay": true})
			var fm: Node = Game.current
			var fg := 0
			while fm.phase != "raid" and fg < 900:
				await get_tree().process_frame
				fg += 1
			fm.hud.visible = false
			await frames(30)
			await shot("fans_%s_tv" % g)
			var fc: Camera3D = fm.cam.cam
			fm.cam.set_process(false)
			fm.cam.set_physics_process(false)
			fc.global_position = Vector3(0.0, 1.7, 6.0)
			fc.look_at(Vector3(-11.0, 1.6, 2.0))
			await frames(4)
			await shot("fans_%s_near" % g)
			fm.cam.set_process(true)
			fm.cam.set_physics_process(true)
		return
	if args_only == "watch":
		# Watch: the computer plays both sides, the score and pause shown, no touch buttons.
		Game.show_screen("res://ui/quick_setup.gd")
		await frames(10)
		await shot("watch_1_setup")
		Game.current._play(true)
		var wm: Node = Game.current
		var wg := 0
		while wm.phase != "raid" and wg < 900:
			await get_tree().process_frame
			wg += 1
		await frames(60)
		await shot("watch_2_match")
		return
	if args_only == "signs":
		# The league's name on the boards and the run-off, from the corner of the mat (in the tour's language).
		Game.start_match({"home": "MUM", "away": "PUN", "arena": "dome", "mode": "quick", "length": 0, "difficulty": 1,
			"autoplay": true})
		var sm: Node = Game.current
		await frames(20)
		sm.set_process(false)
		var c: Camera3D = sm.cam.cam
		c.global_position = Vector3(5.5, 1.6, -9.0)
		c.look_at(Vector3(0, 0.4, -12.5))
		await frames(3)
		await shot("signs_board")
		return
	if args_only == "walkout":
		# The final's walk-out, and a derby's intro.
		var s2: Script = load("res://game/match.gd")
		var m: Node = s2.new()
		m.config = {"home": "KEN", "away": "IND", "arena": "stadium", "mode": "quick", "walkout": true, "length": 0, "difficulty": 1}
		Game._swap(m)
		await frames(45)
		await shot("e14_walkout")
		var d: Node = s2.new()
		d.config = {"home": "MUM", "away": "PUN", "arena": "dome", "mode": "quick", "derby": "DERBY_MAHARASHTRA", "length": 0, "difficulty": 1}
		Game._swap(d)
		await frames(30)
		await shot("e15_derby")
		return
	if args_only in ["engage", "engage2d"]:
		await _engage(args_only == "engage")
		return
	if args_only == "howto":
		# Every page of How to Play.
		var how := Game.show_screen("res://ui/howto_screen.gd")
		for i in how.TOPICS.size():
			how._show(i)
			await frames(12)
			await shot("howto_%d" % i)
		return
	if args_only.begins_with("screen:"):
		# One screen: screen:res://ui/main_menu.gd
		Game.show_screen(args_only.substr(7))
		await frames(200 if args_only.ends_with("main_menu.gd") else 30)
		await shot("one")
		return
	if args_only == "thumbs":
		# Ground pictures for the Quick Match screen (tools/ui_art makes the JPEGs).
		for a in DB.ARENAS:
			Game.start_match({"home": "MUM", "away": "CHD", "arena": a.id, "mode": "quick", "autoplay": true, "attract": true, "length": 0, "difficulty": 2})
			var mt: Node = Game.current
			await frames(150)
			mt.cam.mode = Game.CAM_TV
			await frames(60)
			await shot("ground_" + String(a.id))
		return
	if args_only == "demos":
		Game.show_screen("res://ui/tutorial_menu.gd")
		await frames(10)
		var tm: Node = Game.current
		for pair in [["cant", 1.2], ["touch", 1.7], ["toe", 1.75], ["bonus", 2.7], ["kick", 2.05], ["dubki", 1.45],
				["lion", 1.45], ["escape", 1.0], ["tackle", 2.4], ["chain", 2.4], ["waist", 2.4], ["dash", 1.85]]:
			tm._select(pair[0])
			tm._demo._t = float(pair[1]) - 0.35
			await frames(21)
			await shot("demo_" + String(pair[0]))
		return
	if args_only == "menus":
		await _menus()
		return
	if args_only == "result":
		# Settings, and the result screen's summary and box score: quicker than every menu.
		Game.show_screen("res://ui/settings_screen.gd")
		await frames(8)
		await shot("r1_settings")
		var rs := Game.show_screen("res://ui/result_screen.gd", {"result": load("res://tests/fit_audit.gd").sample_result()})
		await frames(10)
		await shot("r2_result")
		_tap((rs.get_meta("header_right") as Node).find_children("*", "Button", true, false)[1])
		await frames(6)
		await shot("r3_box_score")
		_tap(rs._box.get_child(0).get_child(1))
		await frames(6)
		await shot("r4_box_score_away")
		return
	if args_only == "buttons":
		await _buttons()
		return
	if args_only == "pickers":
		# The franchise and country pickers alone (both built by UI.team_grid), quicker than every menu.
		Game.delete_season()
		Game.show_screen("res://ui/season_hub.gd")
		await frames(8)
		await shot("p1_franchise")
		Game.delete_cup()
		Game.show_screen("res://ui/cup_screen.gd")
		await frames(8)
		await shot("p2_country")
		return
	if args_only != "":
		await _grounds()
		return
	Game.show_screen("res://ui/main_menu.gd")
	await frames(240)
	await shot("01_menu")
	Game.delete_season()
	Game.show_screen("res://ui/season_hub.gd")
	await frames(5)
	await shot("01b_season_pick")
	Game.new_season("PAT")
	Game.show_screen("res://ui/auction_screen.gd", {"mode": "owner"})
	await frames(200)
	await shot("01c_owner_auction")
	Game.delete_season()
	Game.show_screen("res://ui/tutorial_menu.gd")
	await frames(5)
	await shot("01d_training")
	Game.show_screen("res://ui/trophy_screen.gd", {"team": "IND", "title": "Nations Cup", "back": "res://ui/main_menu.gd"})
	await frames(90)
	await shot("01e_trophy")
	Game.show_screen("res://ui/quick_setup.gd")
	await frames(5)
	await shot("02_quick_setup")
	Game.show_screen("res://ui/create_player.gd")
	await frames(20)
	await shot("03_create_player")
	Game.delete_career()
	Game.new_career({"name": "Arjun Malik", "state": "STATE_HARYANA", "role": "raider", "skin": 2, "hair": 0, "build": 1})
	Game.show_screen("res://ui/auction_screen.gd")
	await frames(150)
	await shot("04_auction")
	Game.delete_cup()
	Game.new_cup("IND")
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(5)
	await shot("05_cup")
	await _grounds()


## Every menu screen, for checking layouts at phone shapes (run with --resolution 1560x720
## for a 19.5:9 phone such as a Galaxy A16).
## A tap on a chip: it lights, as a finger's would light it, and does what it does.
func _tap(b: Button) -> void:
	b.button_pressed = true
	b.pressed.emit()


func _menus() -> void:
	Game.show_screen("res://ui/main_menu.gd")
	await frames(240)
	await shot("m01_menu")
	Game.show_screen("res://ui/quick_setup.gd")
	await frames(8)
	await shot("m02_quick")
	Game.show_screen("res://ui/settings_screen.gd")
	await frames(8)
	await shot("m03_settings")
	Game.show_screen("res://ui/howto_screen.gd")
	await frames(8)
	await shot("m04_howto")
	Game.show_screen("res://ui/tutorial_menu.gd")
	await frames(30)
	await shot("m05_training")
	Game.delete_season()
	Game.show_screen("res://ui/season_hub.gd")
	await frames(8)
	await shot("m06_season_pick")
	Game.new_season("PAT")
	Game.show_screen("res://ui/auction_screen.gd", {"mode": "owner"})
	await frames(200)
	await shot("m07_auction")
	var au: Node = Game.current
	if au.has_method("_finish_all"):
		au._finish_all()
		await frames(30)
		await shot("m08_auction_done")
	var se = Game.get_season()
	if String(se.phase) == "auction":
		var eng = se.make_auction()
		eng.resolve_all(false)
		se.finish_auction(eng)
		Game.save_season()
	Game.show_screen("res://ui/season_hub.gd")
	await frames(8)
	await shot("m09_season_hub")
	Game.delete_season()
	Game.delete_cup()
	Game.show_screen("res://ui/cup_screen.gd")   # no cup yet: pick your country
	await frames(8)
	await shot("m10a_cup_country")
	Game.new_cup("IND")
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(8)
	await shot("m10_cup")
	Game.show_screen("res://ui/trophy_screen.gd", {"team": "IND", "title": "Nations Cup", "back": "res://ui/main_menu.gd"})
	await frames(90)
	await shot("m11_trophy")
	var rs := Game.show_screen("res://ui/result_screen.gd", {"result": load("res://tests/fit_audit.gd").sample_result()})
	await frames(10)
	await shot("m12_result")
	_tap((rs.get_meta("header_right") as Node).find_children("*", "Button", true, false)[1])
	await frames(6)
	await shot("m12b_box_score")
	Game.delete_cup()


## Who is who: the tags over the players in the broadcast view, defending and raiding, then names over everyone.
func _tags() -> void:
	for spec in [[1, 0, "tags_1_defend"], [0, 0, "tags_2_raid"], [1, 1, "tags_3_everyone"]]:
		Game.settings.tags = spec[1]
		Game.start_match({"home": "MUM", "away": "CHD", "arena": "dome", "mode": "quick", "control": "all", "length": 0,
			"difficulty": 0, "first_raider": spec[0], "passive": true})
		var m: Node = Game.current
		var guard := 0
		while m.phase != "raid" and guard < 900:
			await get_tree().process_frame
			guard += 1
		await frames(50)
		await shot(spec[2])
	Game.settings.tags = 2


## The match's HUD in the tour's language, quickly (the 3D world is not drawn): the scoreboard and buttons with the
## language's longest call up under a short one, its longest hint, a banner, the pause menu and the final's walk-out.
func _hud() -> void:
	Game.settings.graphics = Game.GFX_LOW
	Game.start_match({"home": "MUM", "away": "CHD", "arena": "dome", "mode": "quick", "control": "all", "length": 0,
		"difficulty": 1, "first_raider": 0, "passive": true})
	var m: Node = Game.current
	await frames(2)
	m.cam.cam.cull_mask = 0
	var guard := 0
	while m.phase != "raid" and guard < 900:
		await get_tree().process_frame
		guard += 1
	await frames(10)
	var hud: Node = m.hud
	m.set_process(false)
	var font: Font = Game.font_display
	var longest := func(prefix: String) -> String:
		var best := ""
		for k in _keys(prefix):
			var t := tr(k).format({"name": "R. Sehrawat", "n": 2, "team": DB.team_name("CHD")})
			if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x > font.get_string_size(best, HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x:
				best = t
		return best
	hud.event(tr("EV_TOUCH") if tr("EV_TOUCH") != "EV_TOUCH" else "Touch!", Game.C_GOLD, true, hud.EV_TOUCH)
	hud.event(longest.call("EV_"), Game.C_SAFFRON, false, hud.EV_RESULT)
	hud.hint(longest.call("HINT_"))
	await frames(12)
	await shot("hud_1_calls")
	for c in hud.events_box.get_children():
		c.free()
	hud.hint("")
	hud.banner(tr("TIMEOUT_BY").format({"team": DB.team_name("CHD")}))
	await frames(14)
	await shot("hud_2_banner")
	hud.banner_l.visible = false
	hud.show_pause(true)
	await frames(8)
	await shot("hud_3_pause")
	hud.show_pause(false)
	var s2: Script = load("res://game/match.gd")
	var w: Node = s2.new()
	w.config = {"home": "KEN", "away": "IND", "arena": "stadium", "mode": "quick", "walkout": true, "length": 0, "difficulty": 1}
	Game._swap(w)
	await frames(3)
	w.cam.cam.cull_mask = 0
	await frames(40)
	await shot("hud_4_walkout")


## The store's pictures (run at 1920x1080): two raids on different grounds, the final's walk-out, the home screen,
## the season's hub and auction, and the Nations Cup. The 3D world is drawn only for the moment of each picture
## (software drawing is slow), so the waits between them are quick.
func _store() -> void:
	var world := func(m: Node, on: bool): m.cam.cam.cull_mask = 0xFFFFF if on else 0
	var raid_shot := func(cfg: Dictionary, wait: int, name: String):
		Game.start_match(cfg)
		var m: Node = Game.current
		await frames(2)
		world.call(m, false)
		var guard := 0
		while m.phase != "raid" and guard < 1200:
			await get_tree().process_frame
			guard += 1
		await frames(wait)
		world.call(m, true)
		await frames(4)
		await shot(name)
	await raid_shot.call({"home": "MUM", "away": "CHD", "arena": "dome", "mode": "quick", "autoplay": true, "length": 0,
		"difficulty": 2, "first_raider": 0}, 75, "store_1_raid")
	await raid_shot.call({"home": "IND", "away": "IRN", "arena": "stadium", "mode": "quick", "autoplay": true, "length": 0,
		"difficulty": 2, "first_raider": 1}, 95, "store_2_stadium")
	var s2: Script = load("res://game/match.gd")
	var w: Node = s2.new()
	w.config = {"home": "KEN", "away": "IND", "arena": "stadium", "mode": "quick", "walkout": true, "length": 0, "difficulty": 1}
	Game._swap(w)
	await frames(2)
	world.call(w, false)
	await frames(50)
	world.call(w, true)
	await frames(4)
	await shot("store_3_final")
	await _store_menu()
	Game.delete_season()
	var se = Game.new_season("PAT")
	se.seed_value = 4242
	var eng: AuctionEngine = se.make_auction()
	eng.resolve_all(false)
	se.finish_auction(eng)
	for i in 5:
		se.simulate_user_match()
	se.news_seen = se.news_n[0]
	Game.save_season()
	Game.show_screen("res://ui/season_hub.gd")
	await frames(40)
	await shot("store_5_season")
	while se.phase != "done":
		if se.next_user_fixture() == null:
			se._advance()
		else:
			se.simulate_user_match()
	se.next_year()
	se.retained = se.default_retained().slice(0, 4)
	se.retain_done = true
	Game.save_season()
	Game.show_screen("res://ui/auction_screen.gd", {"mode": "owner"})
	await frames(150)
	await shot("store_6_auction")
	Game.delete_season()
	Game.delete_cup()
	var cup = Game.new_cup("IND")
	cup.confirm_squad(cup.best_squad(), String(cup.best_squad()[0].id))
	for i in 2:
		cup.simulate_user_match()
	cup.news_seen = cup.news_n[0]
	Game.save_cup()
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(40)
	await shot("store_7_cup")
	Game.delete_cup()
	await _store_extra()   # the home screen again, and its language picker


## The home screen for the store, without the beta's version number in its corner.
func _store_menu() -> Node:
	var menu := Game.show_screen("res://ui/main_menu.gd")
	await frames(2)
	for l in menu.find_children("*", "Label", true, false):
		if String(l.text).begins_with("v0."):
			l.modulate.a = 0.0
	await frames(118)
	await shot("store_4_menu")
	return menu


## The home screen and its language picker, and a raid at the stadium without the HUD (behind the store's feature
## graphic).
func _store_extra() -> void:
	var menu: Node = await _store_menu()
	menu._open_language()
	await frames(20)
	await shot("store_8_languages")
	Game.start_match({"home": "IND", "away": "IRN", "arena": "stadium", "mode": "quick", "autoplay": true, "length": 0,
		"difficulty": 2, "first_raider": 1})
	var m: Node = Game.current
	await frames(2)
	m.cam.cam.cull_mask = 0
	var guard := 0
	while m.phase != "raid" and guard < 1200:
		await get_tree().process_frame
		guard += 1
	await frames(95)
	m.hud.visible = false
	m.cam.cam.cull_mask = 0xFFFFF
	await frames(4)
	await shot("store_feature_bg")


func _keys(prefix: String) -> Array:
	var out := []
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/src/en.json"))
	for k in d:
		if String(k).begins_with(prefix):
			out.append(k)
	return out


## Raid moves: the raid buttons, then dubki, lion jump and kicks frozen mid-move.
func _moves() -> void:
	Game.settings.difficulty = 0
	Game.start_match({"home": "MUM", "away": "CHD", "arena": "dome", "mode": "quick", "control": "all", "length": 0, "difficulty": 0, "first_raider": 0, "passive": true})
	var m: Node = Game.current
	var guard := 0
	while m.phase != "raid" and guard < 600:
		await get_tree().process_frame
		guard += 1
	var rd: Athlete = m.raider
	var opp: int = 1 - m.raiding
	var defs: Array = m.defenders()
	# Buttons, with a defender winding up low so Lion jump lights.
	rd.position = m.pos_in(opp, 0.0, 2.0)
	defs[3].tackle_kind = "ankle"
	defs[3].position = m.pos_in(opp, 0.3, 3.2)
	defs[3].set_state("telegraph", 99.0)
	m.cam.mode = Game.CAM_THIRD
	for k in 4:
		m._on_action("cant")
		await frames(18)
	await shot("20_raid_buttons")
	m.set_process(false)
	m.hud.visible = false
	m.controls.visible = false
	var cam := Camera3D.new()
	cam.fov = 40
	m.add_child(cam)
	cam.current = true
	var hide_far := func(keep: Array):
		for a in m.athletes:
			a.visible = keep.has(a)
	var hold := func(a: Athlete, st: String, k: float):
		a.set_state(st, 1000.0)
		a.st_t = 1000.0 * k
	# Dubki under linked hands.
	var c = m.pos_in(opp, 0.0, 3.0)
	for d in defs:
		m._unchain(d)
	defs[1].position = c + Vector3(-0.55, 0, 0)
	defs[2].position = c + Vector3(0.55, 0, 0)
	for d in [defs[1], defs[2]]:
		d.facing = Vector3(0, 0, signf(m.side(m.raiding)))
		hold.call(d, "ready", 0.5)
	m._link(defs[1], defs[2])
	m.phase = "raid"
	m._update_chain_links()
	rd.position = c + Vector3(0, 0, 0.1)
	rd.facing = Vector3(0, 0, m.side(m.raiding))
	hold.call(rd, "dubki", 0.5)
	hide_far.call([rd, defs[1], defs[2]])
	cam.position = c + Vector3(1.3, 1.25, 3.3 * m.side(m.raiding))
	cam.look_at(c + Vector3(0, 0.6, 0))
	await frames(30)
	await shot("21_move_dubki")
	m._unchain(defs[1])
	m._update_chain_links()
	# Lion jump over an ankle dive.
	defs[1].tackle_kind = "ankle"
	defs[1].position = c + Vector3(0, 0, 0.9 * m.side(m.raiding))
	defs[1].facing = Vector3(0, 0, -m.side(m.raiding))
	hold.call(defs[1], "dive", 0.9)
	hold.call(rd, "jump", 0.5)
	hide_far.call([rd, defs[1]])
	cam.position = c + Vector3(4.2, 1.2, 0.4 * m.side(m.raiding))
	cam.look_at(c + Vector3(0, 0.8, 0.4 * m.side(m.raiding)))
	await frames(30)
	await shot("22_move_lion_jump")
	# Back kick and side kick.
	hold.call(rd, "backkick", 0.5)
	rd.kick_back = 1.0
	rd.kick_side = 0.15
	defs[2].position = c - Vector3(0, 0, 1.3 * m.side(m.raiding))
	hold.call(defs[2], "ready", 0.5)
	var rd2: Athlete = defs[4]
	rd2.position = c + Vector3(0, 0, -2.2)
	rd2.facing = Vector3(0, 0, 1)
	hold.call(rd2, "backkick", 0.5)
	rd2.kick_back = 0.1
	rd2.kick_side = 1.0
	hide_far.call([rd, defs[2], rd2])
	cam.position = c + Vector3(4.2, 1.4, -0.9)
	cam.look_at(c + Vector3(0, 0.7, -0.9))
	await frames(30)
	await shot("23_move_kicks")
	# Tackles winding up: ankle, thigh, waist, dash.
	var row := [defs[0], defs[1], defs[2], defs[3]]
	var styles := ["ankle", "thigh", "waist", "dash"]
	for i in 4:
		var d: Athlete = row[i]
		d.tackle_kind = styles[i]
		d.position = c + Vector3(-2.1 + 1.4 * i, 0, 0)
		d.facing = Vector3(0, 0, 1)
		hold.call(d, "telegraph", 0.5)
	hide_far.call(row)
	cam.position = c + Vector3(0, 1.2, 4.8)
	cam.look_at(c + Vector3(0, 0.7, 0))
	await frames(30)
	await shot("24_tackle_styles")
	m.queue_free()
	await frames(3)
	# Defending: the tackle buttons, with the raider near the side line so Dash lights.
	Game.start_match({"home": "MUM", "away": "CHD", "arena": "dome", "mode": "quick", "control": "all", "length": 0, "difficulty": 0, "first_raider": 1, "passive": true})
	var m2: Node = Game.current
	var g2 := 0
	while m2.phase != "raid" and g2 < 600:
		await get_tree().process_frame
		g2 += 1
	await frames(40)
	m2.raider.position = m2.pos_in(0, 0.0, 2.5)
	m2.raider.position.x = 4.3
	m2.cam.mode = Game.CAM_THIRD
	await frames(8)
	await shot("25_defend_buttons")


func _grounds() -> void:

	var cams := {"dome": [0, 1, 2], "village": [0], "stadium": [2], "monsoon": [0], "beach": [0]}
	if args_only != "":
		cams = {args_only: [0]}
	var pairs := {"dome": ["MUM", "CHD"], "village": ["PAT", "HYD"], "stadium": ["IND", "IRN"], "monsoon": ["KOL", "BLR"], "beach": ["CHE", "JAI"]}
	var i := 6
	for arena in cams.keys():
		Game.start_match({"home": pairs[arena][0], "away": pairs[arena][1], "arena": arena, "mode": "quick", "control": "all", "length": 0, "difficulty": 1, "first_raider": 0 if arena != "village" else 1})
		var m: Node = Game.current
		# Let the intro run, then wait for the raid to get going.
		var guard := 0
		while m.phase != "raid" and guard < 600:
			await get_tree().process_frame
			guard += 1
		await frames(70)
		if m.raid.get("cant_tap", false):
			for k in 6:
				m._on_action("cant")
				await frames(18)
		if m.raiding == 1 and m.controlled:
			m._toggle_chain(m.controlled)
			await frames(20)
		for c in cams[arena]:
			m.cam.mode = c
			await frames(25)
			await shot("%02d_%s_cam%d" % [i, arena, c])
			i += 1
		if arena == "dome":
			# Catch the reactions after a raid ends.
			m.cam.mode = Game.CAM_TV
			m.config["autoplay"] = true
			var g := 0
			while m.phase != "post" and g < 1500:
				await get_tree().process_frame
				g += 1
			await frames(14)
			await shot("%02d_reactions" % i)
			i += 1
	if args_only != "":
		return
	Game.settings.language = "hi"
	TranslationServer.set_locale("hi")
	Game.show_screen("res://ui/main_menu.gd")
	await frames(30)
	await shot("%02d_menu_hindi" % i)
	TranslationServer.set_locale("ta")
	Game.show_screen("res://ui/settings_screen.gd")
	await frames(5)
	await shot("%02d_settings_tamil" % (i + 1))
	TranslationServer.set_locale("en")


## The League Season and Nations Cup screens of the news-and-auction update: hub, breaking news, match day,
## retentions, war room, auction, grades, hall of fame, cup squad, cup hub, menu ticker, final walk-out.
func _engage(with_3d := true) -> void:
	Game.delete_season()
	var se = Game.new_season("PAT")
	se.seed_value = 4242
	var eng: AuctionEngine = se.make_auction()
	eng.resolve_all(false)
	se.finish_auction(eng)
	for i in 5:
		se.simulate_user_match()
	Game.save_season()
	se.news_seen = se.news_n[0]   # no breaking news over the hub's picture
	Game.show_screen("res://ui/season_hub.gd")
	await frames(40)
	await shot("e01_season_hub")
	var fresh := []
	for it in se.news:
		if int(it.p) >= 2:
			fresh.append(it)
	NewsTicker.breaking(Game.current, fresh.slice(-3), func(): pass)
	await frames(30)
	await shot("e02_breaking")
	Game.show_screen("res://ui/match_day.gd")
	await frames(30)
	await shot("e03_match_day")
	# A season on: retentions, war room, auction.
	while se.phase != "done":
		if se.next_user_fixture() == null:
			se._advance()
		else:
			se.simulate_user_match()
	se.next_year()
	se.news_seen = se.news_n[0]
	Game.save_season()
	Game.show_screen("res://ui/season_hub.gd")
	await frames(30)
	await shot("e04_preseason")
	Game.show_screen("res://ui/retention_screen.gd")
	await frames(30)
	await shot("e05_retentions")
	se.retained = se.default_retained().slice(0, 4)
	se.retain_done = true
	var wr := Game.show_screen("res://ui/war_room.gd")
	await frames(10)
	var n := 0
	for l in wr.eng.lots:
		if n < 3 and Scout.fit(l.player, wr.eng.teams[se.team].squad) >= 2:
			wr._pin(l)
			n += 1
	await frames(30)
	await shot("e06_war_room")
	var au := Game.show_screen("res://ui/auction_screen.gd", {"mode": "owner"})
	await frames(150)
	await shot("e07_auction")
	au._finish_all()
	await frames(40)
	await shot("e08_auction_grades")
	Game.show_screen("res://ui/hall_of_fame.gd")
	await frames(30)
	await shot("e09_hall_of_fame")
	# The Nations Cup.
	Game.delete_cup()
	var cup = Game.new_cup("KEN")
	Game.show_screen("res://ui/cup_squad.gd")
	await frames(30)
	await shot("e10_cup_squad")
	cup.confirm_squad(cup.best_squad(), String(cup.best_squad()[0].id))
	for i in 2:
		cup.simulate_user_match()
	cup.news_seen = cup.news_n[0]
	Game.save_cup()
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(40)
	await shot("e11_cup_hub")
	if not with_3d:
		Game.delete_cup()
		Game.delete_season()
		return
	Game.show_screen("res://ui/main_menu.gd")
	await frames(200)
	await shot("e12_menu_ticker")
	Game.show_screen("res://ui/trophy_screen.gd", {"team": "KEN", "title": tr("UNDERDOG_TROPHY"), "underdog": true, "back": "res://ui/main_menu.gd"})
	await frames(60)
	await shot("e13_underdog_trophy")
	var s2: Script = load("res://game/match.gd")
	var m: Node = s2.new()
	m.config = {"home": "KEN", "away": "IND", "arena": "stadium", "mode": "quick", "walkout": true, "length": 0, "difficulty": 1}
	Game._swap(m)
	await frames(60)
	await shot("e14_walkout")
	Game.goto_menu()
	await frames(5)
	Game.delete_cup()
	Game.delete_season()



## The match buttons at each size (Settings > Button size), raiding and defending, Break free while held; the pause
## menu; Move buttons over the paused match, a button mid-drag and let go; and Move buttons from Settings, for either hand.
func _buttons() -> void:
	var size_was := int(Game.settings.btn_size)
	var places_was: Array = Game.settings.btn_places
	Game.settings.btn_places = []
	Game.start_match({"home": "MUM", "away": "CHD", "arena": "dome", "mode": "quick", "control": "all", "length": 0,
		"difficulty": 1, "first_raider": 0, "passive": true})
	var m: Node = Game.current
	var guard := 0
	while m.phase != "raid" and guard < 900:
		await get_tree().process_frame
		guard += 1
	await frames(30)
	m.set_process(false)
	var c: TouchControls = m.controls
	for i in TouchControls.SIZE_K.size():
		Game.settings.btn_size = i
		c.queue_redraw()
		await frames(3)
		await shot("b%d_raid_%s" % [i + 1, ["normal", "large", "xl"][i]])
	c.set_context("defend")
	await frames(3)
	await shot("b4_defend_xl")
	c.set_context("raid")
	c.held = true
	await frames(3)
	await shot("b5_held_xl")
	c.held = false
	Game.settings.btn_size = 0
	m.set_paused(true)
	await frames(4)
	await shot("b6_pause")
	m.hud._move_buttons()
	await frames(6)
	await shot("b7_move_in_match")
	# Dubki picked up and dragged onto Lion jump's place: Lion jump makes way.
	var dubki: Vector2 = c._buttons().filter(func(b): return b.id == "dubki")[0].pos
	var jump: Vector2 = c._buttons().filter(func(b): return b.id == "jump")[0].pos
	c._input(_touch_ev(0, dubki, true))
	c._input(_drag_ev(0, dubki.lerp(jump, 0.6)))
	c._input(_drag_ev(0, jump))
	await frames(3)
	await shot("b8_dragging")
	c._input(_touch_ev(0, jump, false))
	await frames(3)
	await shot("b9_let_go")
	m.hud.layout_panel.finish()
	m.queue_free()
	await frames(3)
	Game.settings.btn_places = []
	var lh_was: bool = Game.settings.left_handed
	for lh in [false, true]:
		Game.settings.left_handed = lh
		Game.settings.btn_size = 1
		Game.show_screen("res://ui/button_layout.gd")
		await frames(120)
		await shot("b10_settings_editor" if not lh else "b11_settings_editor_left")
	Game.settings.left_handed = lh_was
	Game.show_screen("res://ui/settings_screen.gd")
	await frames(8)
	var sc: ScrollContainer = Game.current.find_children("*", "ScrollContainer", true, false)[0]
	sc.scroll_vertical = 10000
	await frames(4)
	await shot("b12_settings")
	Game.settings.btn_size = size_was
	Game.settings.btn_places = places_was
	Game.save_settings()


func _touch_ev(i: int, at: Vector2, down: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = at
	e.pressed = down
	return e


func _drag_ev(i: int, at: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = at
	return e
