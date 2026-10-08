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
	if args_only == "moves":
		await _moves()
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
