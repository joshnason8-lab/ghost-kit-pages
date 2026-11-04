extends Node
## Stills of the game at one graphics level and one window shape, for checking by eye (on Low, the phones' level):
##   xvfb-run -a -s "-screen 0 2400x1200x24" godot --path . --rendering-driver opengl3 --fixed-fps 30 \
##     res://tests/low_stills.tscn -- OUT_DIR [WxH] [level] [parts]
## WxH: the window (1600x720 by default: a 20:9 phone); level: low, medium or high (low by default); parts:
## quick,season (both by default), throwin (the AI's throw-ins alone, three a venue). quick: a Quick Match in each venue: the centre pass line-up, the TV camera in play,
## a penalty pass set up, a throw-in, a goal's close shot of the post and its replay, the pause menu after it with
## Team changes (Substitutions and Positions), and the interval screen. season: a Club Season's hub, a match in a
## club's hall, the finals on the hub (a single season and a home-and-away one). A fifth argument: the venues
## (arena,hall,outdoor by default). (Low has no replays: the foundation's bodies are kept for them, Medium and High.)
## The game's own loading screen runs first, as in the game.

var out := ""
var parts := ["quick", "season"]
var tag := ""
var venues := ["arena", "hall", "outdoor"]


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else "user://stills"
	var sz := Vector2i(1600, 720)
	if a.size() > 1 and a[1] != "":
		var wh := a[1].split("x")
		sz = Vector2i(int(wh[0]), int(wh[1]))
	var level := ["low", "medium", "high"].find(a[2]) if a.size() > 2 and a[2] != "" else Game.GFX_LOW
	if a.size() > 3 and a[3] != "":
		parts = Array(a[3].split(","))
	if a.size() > 4 and a[4] != "":
		venues = Array(a[4].split(","))
	tag = "%dx%d" % [sz.x, sz.y]
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = level
	Game.settings.auto_gfx = false
	Game.settings.coach = false
	Game.settings.language = "en"
	WsgFoundation.tier = level
	ToonBody.material(level > Game.GFX_LOW)
	get_tree().root.size = sz
	DisplayServer.window_set_size(sz)
	var loading: Node = (load("res://ui/loading_screen.gd") as Script).new()
	add_child(loading)
	loading.run()
	var guard := 0
	while (Game.loading or Game.current == null) and guard < 3000:
		await get_tree().process_frame
		guard += 1
	await frames(20)
	if "quick" in parts:
		for v: Array in [["arena", "AUS", "NZL"], ["hall", "ENG", "WAL"], ["outdoor", "MWI", "UGA"]]:
			if v[0] in venues:
				await _quick(v[0], v[1], v[2])
	if "season" in parts:
		await _season()
	if "throwin" in parts:
		for v: Array in [["arena", "AUS", "NZL"], ["hall", "ENG", "WAL"], ["outdoor", "MWI", "UGA"]]:
			if v[0] in venues:
				await _throwins(v[0], v[1], v[2])
	print("low_stills: done")
	get_tree().quit()


func _quick(venue: String, home: String, away: String) -> void:
	Game.start_match({"home": home, "away": away, "venue": venue, "quarter": 15, "difficulty": 1, "mode": "quick",
		"user_team": 0, "seed": 9, "no_injuries": true})
	await frames(45)
	var m: Match = Game.current
	var seen := {}
	m.game_event.connect(func(k: String, info: Dictionary): seen[k] = info)
	await shot("%s_01_centre" % venue)
	await until(func(): return m.phase == "live", 600)
	await frames(150)
	await shot("%s_02_play" % venue)
	# A penalty pass: a contact by the defending GD on the GA, near the circle (to the AI's side: yours would wait
	# for your tap).
	await until(func(): return m.phase == "live", 900)
	var on: Player = m.player_at(1, "GA")
	var by: Player = m.player_at(0, "GD")
	var at := Vector2(9.0 * on.dir, 3.0)
	m.pass_info = {}
	m.shot_info = {}
	m._release_holder()
	on.p = at
	on.vel = Vector2.ZERO
	on.target = at
	by.p = at + Vector2(-on.dir * 0.6, 0.15)
	by.vel = Vector2.ZERO
	by.target = by.p
	await frames(1)
	m._infringe("contact", by, at)
	await until(func(): return m.phase == "setup" and m.holder != null and m.holder == m.restart.get("taker") and m.holder.stopped, 300)
	await frames(6)
	await shot("%s_03_penalty" % venue)
	# A throw-in on the near side line.
	await until(func(): return m.phase == "live", 900)
	m.pass_info = {}
	m.shot_info = {}
	m._award(Rules.throw_in(0, Vector2(-4.0, Court.HALF_W)), null, "throw_in")
	await until(func(): return String(m.restart.get("kind", "")) == Rules.THROW_IN and m.restart.get("taker") != null and (m.restart.taker as Player).p.distance_to(m.restart.spot) < 0.3, 300)
	await frames(6)
	await shot("%s_04_throwin" % venue)
	# A goal in play (undrawn till then): the close shot of the post, then its replay.
	seen.erase("shot_start")
	RenderingServer.render_loop_enabled = false
	await until(func(): return seen.has("shot_start"), 9000)
	RenderingServer.render_loop_enabled = true
	await frames(3)
	await shot("%s_05a_shooting" % venue)
	seen.erase("goal")
	RenderingServer.render_loop_enabled = false
	await until(func(): return seen.has("goal"), 9000)
	RenderingServer.render_loop_enabled = true
	await frames(24)
	await shot("%s_05_goal_close" % venue)
	if m.wsg_replay:
		await until(func(): return m.phase == "replay", 200)
		await frames(40)
		await shot("%s_06_replay" % venue)
	await until(func(): return m.phase == "setup", 600)
	await frames(2)
	# The pause menu (Team changes, after a goal), the substitutions and the positions.
	m.set_paused(true)
	await frames(4)
	await shot("%s_07_pause" % venue)
	var gc: Node = m.hud.find_child("GoalChange", true, false)
	if gc:
		(gc as Button).pressed.emit()
		await frames(4)
		await shot("%s_08_subs" % venue)
		var tc: Node = m.hud.find_child("TeamChanges", true, false)
		if tc:
			m.hud._swap_mode = true
			m.hud._fill_changes(tc, true)
			await frames(4)
			await shot("%s_09_positions" % venue)
		m.hud._close_changes()
	else:
		print("low_stills: %s: no Team changes in the pause menu" % venue)
	m.set_paused(false)
	await frames(2)
	# The interval: the quarter's last seconds run out.
	await until(func(): return m.phase == "live", 900)
	m.time_left = 0.2
	await until(func(): return m.hud._break != null, 900)
	await frames(8)
	await shot("%s_10_interval" % venue)
	m.hud.hide_break()
	Game.goto_menu()
	await frames(6)


func _throwins(venue: String, home: String, away: String) -> void:
	Game.start_match({"home": home, "away": away, "venue": venue, "quarter": 15, "difficulty": 1, "mode": "quick",
		"user_team": 0, "seed": 9, "no_injuries": true})
	await frames(10)
	var m: Match = Game.current
	var k := 1
	for at: Vector2 in [Vector2(-4.0, Court.HALF_W), Vector2(5.0, Court.HALF_W), Vector2(2.0, -Court.HALF_W)]:
		await until(func(): return m.phase == "live", 900)
		m.pass_info = {}
		m.shot_info = {}
		m._award(Rules.throw_in(0, at), null, "throw_in")
		await until(func(): return String(m.restart.get("kind", "")) == Rules.THROW_IN and m.restart.get("taker") != null and (m.restart.taker as Player).p.distance_to(m.restart.spot) < 0.3, 300)
		await frames(2)
		await shot("%s_throwin_%d" % [venue, k])
		k += 1
	Game.goto_menu()
	await frames(6)


func _season() -> void:
	Game.delete_league()
	var lg = Game.new_league(String(DB.club_ids()[0]), 4, 1)
	for i in 2:
		lg.sim_next()
	Game.save_league()
	Game.show_screen("res://ui/league_screen.gd")
	await frames(12)
	await shot("season_01_hub")
	# Play: the button's own match, with its loading overlay; the overlay at the tap.
	var nm: Dictionary = lg.next_user_match()
	Game.current._play(lg, nm)
	await frames(1)
	await shot("season_02_loading_tap")
	await until(func(): return not WsgLoading.busy(), 3000)
	var m: Match = Game.current
	await frames(10)
	await shot("season_03_card")
	if m.hud.card:
		m.hud.card.close()
	await frames(40)
	await shot("season_04_hall_centre")
	await until(func(): return m.phase == "live", 900)
	await frames(200)
	await shot("season_05_hall_play")
	Game.goto_menu()
	await frames(6)
	# The finals: a single season (7 rounds) and a home-and-away one (14), played to the finals.
	for legs in [1, 2]:
		Game.delete_league()
		lg = Game.new_league(String(DB.club_ids()[0]), 4, legs)
		var guard := 0
		while lg.stage == "season" and guard < 40:
			lg.sim_next()
			guard += 1
		Game.save_league()
		Game.show_screen("res://ui/league_screen.gd")
		await frames(12)
		await shot("season_%02d_finals_%s" % [5 + legs, "single" if legs == 1 else "home_away"])
		await pages("season_%02d_finals_%s" % [5 + legs, "single" if legs == 1 else "home_away"])
		lg.sim_next()
		Game.save_league()
		Game.show_screen("res://ui/league_screen.gd")
		await frames(12)
		await shot("season_%02d_finals_%s_wk2" % [5 + legs, "single" if legs == 1 else "home_away"])
	Game.delete_league()


func until(cond: Callable, most: int) -> void:
	for i in most:
		if cond.call():
			return
		await get_tree().process_frame
	print("low_stills: waited %d frames in vain" % most)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join("%s_%s.png" % [name, tag]))
	var di := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var pr := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print("low_stills: %s_%s %d draw calls %d primitives" % [name, tag, di, pr])


## The rest of a scrolling screen, a page at a time.
func pages(name: String) -> void:
	var k := 2
	for sc: ScrollContainer in Game.current.find_children("*", "ScrollContainer", true, false):
		if not sc.is_visible_in_tree():
			continue
		var bar := sc.get_v_scroll_bar()
		var most := int(bar.max_value - bar.page)
		if most <= 8:
			continue
		var y := 0
		for i in 3:
			if y >= most:
				break
			y = mini(most, y + int(sc.size.y * 0.85))
			sc.scroll_vertical = y
			await frames(3)
			await shot("%s_%d" % [name, k])
			k += 1
