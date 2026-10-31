extends Node
## The smoke test CI runs before building: every screen opens in every language; a season and a tournament play
## through to their champions; AI matches in each event finish with scores the laws allow; a team event's regus never
## use a player twice; every spectator in every venue faces the court; every move from motion capture loads and keeps
## its feet from sliding; the save files read back. Headless:
##   godot --headless --path . --fixed-fps 30 res://tests/test_runner.tscn
## Exits 1 on any failure.

var failures := 0
var checks := 0


func _ready() -> void:
	Game.main = self
	Game.reset_settings_for_tests()
	var keep: Dictionary = Game.settings.duplicate(true)
	# The shared foundation (FoundationLink, on Medium and High when this machine has the licensed clips; CI may not)
	# is tested in its own section; elsewhere the matches run without it, as a build without the clips does.
	FoundationLink.off = true
	await _screens()
	_rules_helpers()
	_season()
	_cup()
	_team_event_lineups()
	await _crowd_facing()
	_mocap_moves()
	await _crowd_people()
	_ball_spins()
	_sounds()
	_graphics_auto()
	_detail_by_level()
	await _legal_pages()
	await _back_everywhere()
	await _play_as_and_officials()
	await _matches()
	await _sim_to_end()
	FoundationLink.off = false
	await _foundation(WsgClips.available())
	FoundationLink.off = true
	Game.settings = keep
	Game.delete_season()
	Game.delete_cup()
	print("test_runner: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Every screen, in every language: it opens and builds without leaving the screen empty.
func _screens() -> void:
	var screens := ["res://ui/main_menu.gd", "res://ui/quick_setup.gd", "res://ui/settings_screen.gd", "res://ui/howto_screen.gd",
		"res://ui/records_screen.gd", "res://ui/season_hub.gd", "res://ui/cup_screen.gd", "res://ui/licences_screen.gd"]
	for pair in Game.LANGUAGES:
		Game.settings.language = pair[0]
		TranslationServer.set_locale(pair[0])
		Game._size_theme()
		check(tr("GAME_TITLE") != "GAME_TITLE", "%s: translations load" % pair[0])
		check(tr("BTN_SPIKE") != "BTN_SPIKE" and tr("BTN_SPIKE") != "", "%s: button labels" % pair[0])
		for path in screens:
			var s := Game.show_screen(path)
			await frames(3)
			check(is_instance_valid(s) and s.get_child_count() > 0, "%s: %s builds" % [pair[0], path])
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	Game._size_theme()


## A set's score is one the laws allow: to set_points, by two from (points - 1)-all, up to the cap.
static func valid_set(a: int, b: int, points: int) -> bool:
	var cap := 17 if points == 15 else 25
	var hi := maxi(a, b)
	var lo := mini(a, b)
	if hi == cap:
		return lo == cap - 1 or lo == cap - 2   # 17-16 at the cap, or 17-15 won by two
	return hi >= points and hi < cap and hi - lo >= 2 and (hi == points or hi - lo == 2)


func _rules_helpers() -> void:
	check(valid_set(15, 9, 15), "15-9 is a set")
	check(valid_set(16, 14, 15), "16-14 is a set")
	check(valid_set(17, 16, 15), "17-16 is a set (the cap)")
	check(not valid_set(15, 14, 15), "15-14 is not")
	check(not valid_set(18, 16, 15), "18-16 is not (past the cap)")
	check(valid_set(21, 10, 21) and valid_set(25, 24, 21), "21-point sets and their cap")
	check(Sim.table_points(2, 0) == 3 and Sim.table_points(2, 1) == 2 and Sim.table_points(1, 2) == 1 and Sim.table_points(0, 2) == 0, "table points")
	check(Court.in_court(Vector3(-Court.HALF - 0.05, 0, 0), 0), "a ball on the back line is in")
	check(not Court.in_court(Vector3(-Court.HALF - 0.2, 0, 0), 0), "a ball 20 cm past the line is out")
	var sol: Array = Ball.solve_apex(Vector3(-4, 1, 0), Vector3(3, 0.1, 1), 3.5)
	var land := Ball.pos_at(Vector3(-4, 1, 0), sol[0], sol[1])
	check(land.distance_to(Vector3(3, 0.1, 1)) < 0.01, "a solved lob lands where it was aimed")


## The leagues, run as they are in real life (Season): Malaysia's seven Grand Prix with the STL's points, the last two
## down and Division 1's finalists up; Thailand's ties of two regus, home and away; Indonesia's regions and national
## finals. Each reaches a champion, its scores are legal, and its save reads back.
func _season() -> void:
	# Malaysia, a Premier club: seven Grand Prix, each a full tournament.
	var my: Season = Game.new_season("MY", "PRK")
	_play_out(my)
	check(my.phase == "done" and my.champion != "", "MY: the season reaches a champion")
	check(my.gps_done() == 7, "MY: seven Grand Prix played (%d)" % my.gps_done())
	var total := 0
	var want := 0
	for row in my.gp_table():
		total += int(row.pts)
	for ev in my.events:
		for id in ev.place:
			want += int(DB.GP_POINTS[ev.place[id]])
	check(total == want and total >= 7 * (32 + 28 + 24 + 21 + 15 * 4), "MY: each Grand Prix shares out the STL's points (%d)" % total)
	for ev in my.events:
		var places := {}
		for id in ev.place:
			places[ev.place[id]] = int(places.get(ev.place[id], 0)) + 1
		check(places.get("1", 0) == 1 and places.get("2", 0) == 1 and places.get("3", 0) == 1 and places.get("4", 0) == 1
			and places.get("qf", 0) == 4 and int(places.get("g1", 0)) + int(places.get("g0", 0)) == 4, "MY: a Grand Prix's finishes (%s)" % places)
		_legal_sets(ev, "MY")
	check(my.relegated.size() == 2 and not (my.relegated[0] in my.premier), "MY: two relegated")
	check(my.awards().size() == 4, "MY: four awards")
	Game.save_season()
	Game.season = null
	var back = Game.get_season()
	check(back != null and back.champion == my.champion and back.gp_table()[0].id == my.gp_table()[0].id, "MY: the season saves and loads")
	# The next season: the relegated two in Division 1, two promoted from it.
	var nx: Season = my.next_season()
	check(nx.premier.size() == 12 and nx.promoted.size() == 2, "MY: next season, twelve in the Premier League with two promoted")
	for id in my.relegated:
		check(not (id in nx.premier) or id in nx.promoted, "MY: %s relegated (or straight back up)" % id)
	# A Division 1 club: one tournament; its finalists go up, and you on with them into the Premier League.
	var d1: Season = Game.new_season("MY", "TRG")
	check(d1.division == 2 and d1.events.size() == 1, "MY: a Division 1 club starts in Division 1")
	_play_out(d1)
	check(d1.phase == "done" and d1.promoted.size() == 2 and d1.relegated.size() == 2 and d1.premier.size() == 10,
		"MY: Division 1 sends two up, the Premier League two down (%d, %d, %d)" % [d1.promoted.size(), d1.relegated.size(), d1.premier.size()])
	var d2: Season = d1.next_season()
	check(d2.premier.size() == (10 if d2.division == 2 else 12), "MY: next season, twelve again once Division 1 is played (%d, division %d)" % [d2.premier.size(), d2.division])
	_play_out(d2)
	check(d2.phase == "done" and d2.champion != "", "MY: a second season plays out")
	check(("TRG" in d1.promoted) == (d1.gps_done() == 7), "MY: promoted, you play the Premier season (%s, %d GPs)" % ["TRG" in d1.promoted, d1.gps_done()])
	# Thailand: home and away, ties of two regus.
	var th: Season = Game.new_season("TH", "SPB")
	_play_out(th)
	check(th.phase == "done" and th.champion == th.table()[0].id, "TH: the champion tops the table")
	var draws := 0
	for row in th.table():
		check(int(row.p) == 14, "TH: %s played everyone home and away (%d)" % [row.id, int(row.p)])
		check(int(row.pts) == int(row.w) * 2 + int(row.d), "TH: 2 points a win, 1 a draw")
		draws += int(row.d)
	check(draws > 0, "TH: some ties are drawn 1-1")
	for rnd in th.events[0].stages[0].rounds:
		for f in rnd:
			check((f.regus as Array).size() == 2 and int(f.sets[0]) + int(f.sets[1]) == 2, "TH: a tie is two regus")
	_legal_sets(th.events[0], "TH")
	# Indonesia: your region, then the national finals.
	for women in [false, true]:
		var id_s: Season = Game.new_season("ID", "SOL", women)
		check(id_s.women == women, "ID: women's league too")
		_play_out(id_s)
		check(id_s.phase == "done" and id_s.champion != "", "ID: a champion")
		var fin: Dictionary = id_s.events[id_s.events.size() - 1]
		check(String(fin.kind) == "finals" and (fin.clubs as Array).size() == 10, "ID: ten clubs in the national finals")
		_legal_sets(fin, "ID")
	check(not Game.new_season("MY", "PRK", true).women, "MY: men only, as the STL is")


func _play_out(se: Season) -> void:
	var guard := 0
	while se.phase != "done" and guard < 300:
		se.sim_round()
		guard += 1


func _legal_sets(ev: Dictionary, lid: String) -> void:
	for st in ev.stages:
		for rnd in st.rounds:
			for f in rnd:
				check(bool(f.played), "%s: every fixture played" % lid)
				for sc in f.set_scores:
					check(valid_set(int(sc[0]), int(sc[1]), 15), "%s: set %s is legal" % [lid, sc])


func _cup() -> void:
	for kind in Cup.KINDS:
		for women in [false, true]:
			var c: Cup = Game.new_cup(kind, "USA" if kind == "world" else "LAO", women, "regu")
			var guard := 0
			while c.stage != "done" and guard < 20:
				c.sim_next()
				guard += 1
			check(c.stage == "done", "%s %s: the tournament finishes" % [kind, "women" if women else "men"])
			check(String(c.medals.get("gold", "")) != "" and (c.medals.get("bronze", []) as Array).size() == 2, "%s: gold and two bronzes" % kind)
			check(c.group_table(0).size() == 4 and c.group_table(1).size() == 4, "%s: two groups of four" % kind)
			check(c.user in c.groups[0] or c.user in c.groups[1], "%s: your country is in it" % kind)
			check((c.groups[0] + c.groups[1]).all(func(id): return id in Cup.KINDS[kind].field), "%s: only the event's nations play in it" % kind)
	# The regional events are their regions' nations only.
	for id in Cup.KINDS["asia"].field + Cup.KINDS["sea"].field:
		check(not (id in ["USA", "FRA", "GER", "AUS"]), "%s: an Asian nation in an Asian event" % id)
	for id in Cup.KINDS["sea"].field:
		check(id in ["THA", "MAS", "VIE", "INA", "MYA", "PHI", "LAO", "SGP", "CAM", "BRU"], "%s: a Southeast Asian nation at the Southeast Asian event" % id)


func _team_event_lineups() -> void:
	var used := []
	for i in 3:
		var r := DB.regu("THA", false, 3, used)
		check(r.size() == 3, "team event: regu %d has three players" % (i + 1))
		for p in r:
			check(not (p.id in used), "team event: #%d plays once" % int(p.num))
			used.append(p.id)


## AI matches in each event: they finish, with legal set scores.
## Every venue, at every graphics level: each spectator faces the court's centre (their forward, on the ground, within
## about 45 degrees of the way to it), the near stands as much as the far ones.
func _crowd_facing() -> void:
	var keep: int = Game.settings.graphics
	for v in DB.VENUES:
		for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
			Game.settings.graphics = g
			var a := Arena.new(v[0], false, [Color("ff8a1f")])
			add_child(a)
			await frames(1)
			# (The crowd's own list: a headless MultiMesh keeps no transforms to read back.)
			var placed: Array[Transform3D] = []
			if a.crowd:
				placed = a.crowd.placed
			check(not placed.is_empty() and placed.size() == a.crowd.multimesh.instance_count, "%s (graphics %d): a crowd" % [v[0], g])
			var worst := 1.0
			var near := 0
			for xf in placed:
				var fwd := Vector3(xf.basis.z.x, 0, xf.basis.z.z).normalized()
				var to_c := Vector3(-xf.origin.x, 0, -xf.origin.z).normalized()
				worst = minf(worst, fwd.dot(to_c))
				if xf.origin.z < 0.0:
					near += 1
			check(worst > 0.7, "%s (graphics %d): every spectator faces the court (worst %.2f, %d on the near side)" % [v[0], g, worst, near])
			a.queue_free()
			await frames(1)
	Game.settings.graphics = keep


## The spectators are whole people: seated ones' feet on the floor under their seats, standing ones' on the ground;
## the sheet has both, from the front and from behind, and the cheering's frames (within 4096 px for older phones);
## the flags in the crowd are the two teams'.
func _crowd_people() -> void:
	for hi in [false, true]:
		var figs := Crowd.FIGS_HI if hi else Crowd.FIGS
		var cell := Vector2(Crowd.FIG_W_HI, Crowd.FIG_H_HI) if hi else Vector2(Crowd.FIG_W, Crowd.FIG_H)
		var size := Crowd.sheet(hi).get_size()
		check(size == cell * Vector2(Crowd.cols(figs), Crowd.SHEET_ROWS) and size.x <= 4096 and size.y <= 4096,
			"the %s crowd sheet: %d figures, their cheering (%s)" % ["bigger" if hi else "small", figs, size])
		var last := Crowd.cheer_cell(figs / 2 - 1, Crowd.CHEER_FRAMES - 1, Crowd.VIEWS.size() - 1, figs)
		check(Crowd.cell(last, figs).y < Crowd.SHEET_ROWS and Crowd.cell(Crowd.ROWS * figs, figs) == Vector2i(0, 8),
			"the %s crowd sheet's cells fit it" % ["bigger" if hi else "small"])
	check(Crowd.CHEERS.size() >= Crowd.FIGS_HI / 2, "a cheer for each person on the bigger sheet")
	for v in ["beach", "national"]:
		var a := Arena.new(v, false, [Color("ff8a1f")])
		add_child(a)
		await frames(1)
		var standing := 0
		var seated_ok := true
		for i in a.crowd.spots.size():
			var spot: Vector3 = a.crowd.spots[i]
			var feet: Vector3 = a.crowd.placed[i].origin
			if is_equal_approx(feet.y, spot.y):
				standing += 1
			else:
				seated_ok = seated_ok and is_equal_approx(feet.y, spot.y - Crowd.SEAT)
		check(seated_ok, "%s: seated spectators' feet are a seat's height under them" % v)
		if v == "beach":
			check(standing > 20, "beach: people stand on the sand (%d)" % standing)
		else:
			check(standing == 0, "national: everyone in the stands is seated (%d standing)" % standing)
		a.crowd.show_teams("THA", "LAO")
		var tex: Texture2D = Crowd._flag_material().get_shader_parameter("flags")
		var img := tex.get_image() if tex else null
		check(img != null and img.get_pixel(Crowd.FLAG_W / 2, Crowd.FLAG_H / 2).is_equal_approx(Flags.image("THA", Crowd.FLAG_W, Crowd.FLAG_H).get_pixel(Crowd.FLAG_W / 2, Crowd.FLAG_H / 2))
			and img.get_pixel(Crowd.FLAG_W + 4, 4).is_equal_approx(Flags.image("LAO", Crowd.FLAG_W, Crowd.FLAG_H).get_pixel(4, 4)),
			"%s: the crowd waves Thailand's and Laos' flags" % v)
		a.queue_free()
		await frames(1)


## Every recorded sound is there and loads (Sfx.FILES; the loops loop), and every sound the game asks for by name
## (Sfx.play, play_at, react, voice, ambience, in the game's and the screens' code, and each venue's ambience) is one
## Sfx has, recorded or made.
func _sounds() -> void:
	for k in Sfx.FILES:
		var path := "res://assets/audio/%s.ogg" % k
		check(ResourceLoader.exists(path), "sound %s is there" % k)
		var st = load(path) if ResourceLoader.exists(path) else null
		check(st is AudioStream and (st as AudioStream).get_length() > 0.0, "sound %s loads" % k)
	Sfx._ensure()
	for k in Sfx.LOOPS:
		check(Sfx.streams.get(k) is AudioStreamOggVorbis and (Sfx.streams[k] as AudioStreamOggVorbis).loop, "sound %s loops" % k)
	var asked := {}
	var re := RegEx.create_from_string("Sfx\\.(play|play_at|react|voice|ambience)\\(\"(\\w+)\"")
	for dir in ["res://game/", "res://ui/", "res://autoload/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				for m in re.search_all(FileAccess.get_file_as_string(dir + f)):
					var name := m.get_string(2)
					match m.get_string(1):
						"react":
							name = "crowd_" + name if name != "applause" else name
						"voice":
							name += "_1"
					asked[name] = f
	for v in Arena.AMBIENCE:
		asked[String(Arena.AMBIENCE[v][0])] = "arena.gd"
	asked["bounce_sand"] = "sfx.gd"
	for k in ["whistle", "whistle_long", "whistle_double", "whistle_final", "whistle_gym"]:
		asked[k] = "match.gd (_whistle)"
	asked["step_court"] = "sfx.gd"
	asked["step_sand"] = "sfx.gd"
	check(asked.size() > 15, "the sounds asked for are found in the code (%d)" % asked.size())
	for k in asked:
		check(Sfx.streams.has(k), "sound %s (asked for in %s) is one there is" % [k, asked[k]])


## The ball spins in the air: a spin once it is kicked, and the ball's mesh turns with it.
func _ball_spins() -> void:
	var b := Ball.new()
	add_child(b)
	b.launch(Vector3(0, 1, 0), Vector3(4, 6, 1), 0.0)
	check(absf(b.spin_rate) >= 5.0, "the ball spins once kicked (%.1f rad/s)" % b.spin_rate)
	var before: Basis = b._mesh.global_transform.basis
	b.turn(0.1)
	check(not before.is_equal_approx(b._mesh.global_transform.basis), "the ball turns as it flies")
	b.queue_free()


## Low loads what it always has (the surfaces at 512 px, the 2K skies, the players' 1024 px textures, the 16-figure
## crowd); Medium and High their own bigger files (2K surfaces, 4K skies, 2048 px players, the 32-figure crowd).
func _detail_by_level() -> void:
	var keep: int = Game.settings.graphics
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		var low: bool = g == Game.GFX_LOW
		var m := Scenery.surface("clean_asphalt")
		var tex: Texture2D = m.get_shader_parameter("albedo_tex")
		check(tex.resource_path.ends_with("_1k.jpg" if low else "_2k.jpg") and tex.get_width() == (512 if low else 2048),
			"graphics %d: the surfaces' %s (%d px)" % [g, tex.resource_path.get_file(), tex.get_width()])
		var env := Environment.new()
		Scenery.sky(env, "qwantani_sunset_puresky")
		var pano: Texture2D = (env.sky.sky_material as ShaderMaterial).get_shader_parameter("panorama")
		check(pano.get_width() == (2048 if low else 4096), "graphics %d: the sky %d px wide" % [g, pano.get_width()])
		var mat := RealBody.material_for({"jersey": Color(0.1, 0.2, 0.3)})
		var skin: Texture2D = mat.get_shader_parameter("albedo_tex")
		check(skin.get_width() == (1024 if low else 2048), "graphics %d: the players' texture %d px" % [g, skin.get_width()])
		check(Crowd.hi() != low and Crowd.material().get_shader_parameter("figs") == float(Crowd.FIGS if low else Crowd.FIGS_HI),
			"graphics %d: the crowd's sheet (%d figures)" % [g, Crowd.material().get_shader_parameter("figs")])
	Game.settings.graphics = keep
	Crowd.material()


## Graphics on Auto by default, and Auto never above what a slow match lowered it to.
func _graphics_auto() -> void:
	check(bool(Game.settings.gfx_auto), "graphics are on Auto for a new player")
	var keep: int = Game.settings.gfx_cap
	Game.settings.gfx_cap = Game.GFX_LOW
	check(Game.auto_graphics() == Game.GFX_LOW, "Auto stays at the level a slow match lowered it to")
	Game.settings.gfx_cap = keep
	check(Game.auto_graphics() == Game.detect_graphics(), "Auto is the level picked for the phone")


## Settings > About's three pages, in the game (no internet): each opens with its words, in every language. The
## licences name the engine and every source the game's assets and sounds come from; the privacy policy has its date
## and the address to write to; the help has the rules and the graphics levels, and the button to email us.
func _legal_pages() -> void:
	var must := {"licences": ["Godot Engine", "MIT", "mocap.cs.cmu.edu", "Mixamo", "Meshy", "Poly Haven", "Kenney",
			"MoCap Online", "ActorCore",
			"opengameart.org", "Pixabay", "charlesheffley009", "framptones", "freesound_community", "Mixkit", "Gregor Quendel",
			"JC Sounds", "SIL Open Font License", "FreeType"],
		"privacy": ["joshnason8@gmail.com", "2026"], "help": ["joshnason8@gmail.com"]}
	var keep := String(Game.settings.language)
	for lang in ["en", "th", "ja", "my"]:
		TranslationServer.set_locale(lang)
		for kind in ["licences", "privacy", "help"]:
			var s: Control = (load("res://ui/licences_screen.gd" if kind == "licences" else "res://ui/doc_screen.gd") as Script).new()
			s.setup({"kind": kind, "back": func(): pass})
			add_child(s)
			await frames(2)
			var text := ""
			var buttons := 0
			for n in s.find_children("*", "", true, false):
				if n is Label:
					text += (n as Label).text + "\n"
				elif n is RichTextLabel:
					text += (n as RichTextLabel).get_parsed_text() + "\n"
				elif n is Button:
					buttons += 1
			check(text.length() > {"licences": 20000, "privacy": 250, "help": 600}[kind], "%s %s: words on the page (%d characters)" % [lang, kind, text.length()])
			check(not text.contains("{") and not text.contains("PRIV_") and not text.contains("HELP_"), "%s %s: no raw keys or placeholders" % [lang, kind])
			check(buttons >= 1, "%s %s: a way back" % [lang, kind])
			if lang == "en":
				for w in must[kind]:
					check(text.contains(w), "%s names %s" % [kind, w])
			if kind == "help":
				check(text.contains(tr("RULES_SCORE")) and text.contains(tr("GFX_HIGH")), "%s help: the rules and the graphics levels" % lang)
			s.queue_free()
			await frames(1)
	TranslationServer.set_locale(keep)


## The phone's Back on every screen: it leaves the screen (as its own Back button does); what is open over a screen
## (the language picker, a team picker's list, League Season's "Abandon?") closes first and the screen stays; in a
## match it pauses and resumes, and closes the pause menu's Settings first. (On the home screen with nothing open it
## leaves the game: not pressed here.)
func _back_everywhere() -> void:
	Game.goto_menu()
	await frames(2)
	var menu: Node = Game.current
	menu._open_language()
	await frames(2)
	Game.go_back()
	await frames(2)
	check(Game.current == menu and not is_instance_valid(menu.get("_picker")), "Back closes the language picker, on the home screen")
	for path in ["res://ui/quick_setup.gd", "res://ui/settings_screen.gd", "res://ui/howto_screen.gd", "res://ui/records_screen.gd",
			"res://ui/season_hub.gd", "res://ui/cup_screen.gd", "res://ui/licences_screen.gd", "res://ui/doc_screen.gd"]:
		var s: Node = Game.show_screen(path, {"kind": "help"} if path.ends_with("doc_screen.gd") else {})
		await frames(2)
		Game.go_back()
		await frames(2)
		check(Game.current != s and is_instance_valid(Game.current), "Back leaves %s" % path.get_file().get_basename())
	# A team picker's list.
	var qs: Node = Game.show_screen("res://ui/quick_setup.gd")
	await frames(2)
	var ob: OptionButton = qs.find_children("*", "OptionButton", true, false)[0]
	ob.show_popup()
	await frames(2)
	var listed := ob.get_popup().visible
	Game.go_back()
	await frames(2)
	check(listed and not ob.get_popup().visible and Game.current == qs, "Back closes a team picker's list, on Quick Match")
	# "Abandon the season?"
	Game.new_season("TH", "SPB")
	var hub: Node = Game.show_screen("res://ui/season_hub.gd")
	await frames(2)
	hub._confirm_abandon()
	await frames(2)
	var asked: Array = hub.find_children("*", "ConfirmationDialog", true, false).filter(func(d): return d.visible)
	Game.go_back()
	await frames(2)
	check(asked.size() == 1 and not asked[0].visible and Game.current == hub and Game.season != null,
		"Back closes League Season's \"Abandon?\" and keeps the season")
	Game.delete_season()
	# A match: Back pauses; with the pause menu's Settings open, closes them; then resumes.
	Game.start_match({"home": "THA", "away": "MAS", "venue": "national", "event": "regu", "sets": 1, "points": 15,
		"difficulty": 2, "mode": "quick", "user_team": 0, "women": false, "seed": 3})
	await frames(3)
	var m: Node = Game.current
	Game.go_back()
	await frames(1)
	var paused := bool(m.paused)
	m.hud.open_settings()
	await frames(1)
	Game.go_back()
	await frames(1)
	var settings_closed: bool = not m.hud.settings_open() and bool(m.paused)
	Game.go_back()
	await frames(1)
	check(paused and settings_closed and not bool(m.paused) and Game.current == m,
		"Back in a match: pauses, closes the pause menu's Settings, resumes")
	Game.goto_menu()
	await frames(2)


## Play as one player: only his touches are yours (the team's: all of them); the white ring is under him. The officials
## move (their heads follow the ball) and wear suits: the jacket and trousers, the shirt, the tie and the shoes each
## somewhere on the model.
func _play_as_and_officials() -> void:
	var keep: int = Game.settings.play_as
	for role in [-1, DB.POS_STRIKER, DB.POS_TEKONG]:
		Game.settings.play_as = role
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": "THA", "away": "MAS", "venue": "national", "event": "regu", "sets": 1, "points": 15, "user_team": 0,
			"seed": 3, "mode": "quick"}
		add_child(m)
		await frames(3)
		var yours := 0
		var theirs := 0
		var ringed := 0
		for side in 2:
			for p in m.players_on(side):
				var pl: Player = p
				if m._is_user(pl):
					yours += 1
					check(role < 0 or pl.role == role, "playing as %d: %s is yours" % [role, pl.data.id])
				if pl.side != m._user_side():
					theirs += int(m._is_user(pl))
				ringed += int(pl.is_mine())
		check(yours == (3 if role < 0 else 1), "playing as %d: %d of yours" % [role, yours])
		check(theirs == 0, "playing as %d: none of theirs is yours" % role)
		check(ringed == (0 if role < 0 else 1), "playing as %d: the ring under %d" % [role, ringed])
		if role == -1:
			var o: RealBody = m.officials[0]
			m._officials.tick(1.0, Vector3(-6, 2, 0), true)
			var left: Vector3 = o.pose.head
			m._officials.tick(1.0, Vector3(6, 2, 0), true)
			var right: Vector3 = o.pose.head
			check(absf(left.y - right.y) > 30.0, "the referee's head follows the ball (%.0f° to %.0f°)" % [left.y, right.y])
			# Four officials: the referee sitting, the assistant and a line judge at each end standing. A ball driven
			# at a line judge's knees: he steps out of its way, and back to his place after.
			check(m.officials.size() == 4 and m._judges.size() == 2, "four officials, two line judges (%d, %d)" % [m.officials.size(), m._judges.size()])
			var j: RealBody = m._judges[0]
			var home := j.position
			var bp := home + Vector3(-signf(home.x) * 6.0, 1.0, 0.0)
			var moved := 0.0
			for f in 30:
				bp += Vector3(signf(home.x) * 9.0 / 30.0, 0, 0)
				m._officials.tick(1.0 / 30.0, bp, true)
				moved = maxf(moved, j.position.distance_to(home))
			for f in 120:
				m._officials.tick(1.0 / 30.0, Vector3(0, 2, 0), true)
			check(moved > 0.8 and j.position.distance_to(home) < 0.1, "the line judge gets out of the ball's way (%.2f m) and back (%.2f m)" % [moved, j.position.distance_to(home)])
			check((m._subs[0] as Array).size() > 0 and (m._subs[1] as Array).size() > 0, "substitutes on both benches")
			var suited := 0
			for b in m.officials:
				var mat := (b as RealBody).mesh_instance.material_override as ShaderMaterial
				suited += int(mat != null and mat.get_shader_parameter("suit_tex") != null)
			check(suited == m.officials.size(), "the officials in suits (%d of %d)" % [suited, m.officials.size()])
			var img := (load(RealBody.SUIT) as Texture2D).get_image()
			var parts := [0, 0, 0, 0]
			for y in range(0, img.get_height(), 2):
				for x in range(0, img.get_width(), 2):
					var c := img.get_pixel(x, y)
					for k in 4:
						parts[k] += int(c[k] > 0.5)
			check(parts[0] > 20000 and parts[1] > 300 and parts[2] > 40 and parts[3] > 2000,
				"the suit: cloth, shirt, tie and shoes (%s texels)" % [parts])
		m.queue_free()
		await frames(2)
	Game.settings.play_as = keep


## Every move from motion capture (the Mixamo kicks and the CMU jumps) loads, and on both models a foot on the floor
## moves less than 3 cm from one frame to the next (0.9 m/s at 30 frames a second).
func _mocap_moves() -> void:
	var conv := preload("res://tools/models/fbx_to_move.gd")
	for w in [false, true]:
		var rig := RealBody.rig(w)
		for name in Moves.CLIPS:
			if name in ["run", "walk"]:
				continue   # (strides: the feet move, the runner with them)
			check(Moves.is_clip(name), "%s: its motion capture loads" % name)
			var s: Array = conv.slide(rig, name)
			check(float(s[0]) < 0.03, "%s (%s): feet on the floor don't slide (worst %.3f m a frame)" % [name, "woman" if w else "man", float(s[0])])


func _matches() -> void:
	var cases := [["regu", 3, 15, "THA", "MAS", "national"], ["quadrant", 1, 15, "JPN", "VIE", "beach"], ["doubles", 1, 15, "PHI", "LAO", "park"],
		["regu", 1, 21, "KLC", "SLA", "provincial"]]
	for c in cases:
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": c[3], "away": c[4], "venue": c[5], "event": c[0], "sets": c[1], "points": c[2], "user_team": -1,
			"demo": true, "seed": 77, "mode": "quick", "women": c[0] == "quadrant"}
		add_child(m)
		var res: Dictionary = await m.finished
		check(int(res.sets[0]) != int(res.sets[1]), "%s: a winner" % c[0])
		for sc in res.set_scores:
			check(valid_set(int(sc[0]), int(sc[1]), int(c[2])), "%s: set %s is legal" % [c[0], sc])
		check((res.log as Array).size() > 10, "%s: rallies were played" % c[0])
		var kills := 0
		for id in res.stats:
			kills += int(res.stats[id].kills)
		check(kills > 0, "%s: spikes won points" % c[0])
		m.queue_free()
		await frames(2)


## Simulate to the end (the pause menu): offered in a season's or a tournament's match, not a quick one; from the score
## as it stands, it finishes the match with a winner and legal sets.
func _sim_to_end() -> void:
	for mode in ["quick", "cup"]:
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": "THA", "away": "MAS", "venue": "national", "event": "regu", "sets": 3, "points": 15, "user_team": 0,
			"demo": true, "seed": 5, "mode": mode}
		add_child(m)
		await frames(3)
		check(m.can_sim_to_end() == (mode == "cup"), "simulate to the end offered in a %s match: %s" % [mode, mode == "cup"])
		if mode == "quick":
			# The pause menu and its Settings over the match: your joystick and buttons hidden (they read touches
			# before the menus, and would take the taps meant for them), and back when the match goes on.
			check(m.controls.visible, "your controls showing in a match of yours")
			m.set_paused(true)
			check(not m.controls.visible, "your controls hidden under the pause menu")
			m.hud.open_settings()
			check(not m.controls.visible, "your controls hidden under the pause menu's Settings")
			m.hud.close_settings()
			m.set_paused(false)
			check(m.controls.visible, "your controls back when the match goes on")
		if mode == "cup":
			m.points = [9, 6]
			m.sets = [1, 0]
			m.set_scores = [[15, 11]]
			m.set_no = 2
			m.set_paused(true)
			m.sim_to_end()
			var res: Dictionary = await m.finished
			check(maxi(int(res.sets[0]), int(res.sets[1])) == 2 and int(res.sets[0]) != int(res.sets[1]), "simulated to the end: a winner, %s" % [res.sets])
			check((res.set_scores[0] as Array) == [15, 11], "simulated to the end: the sets already played kept")
			for sc in res.set_scores:
				check(valid_set(int(sc[0]), int(sc[1]), 15), "simulated to the end: set %s is legal" % [sc])
			check(int((res.set_scores[1] as Array)[0]) >= 9 and int((res.set_scores[1] as Array)[1]) >= 6, "simulated to the end: from the score as it stood")
		m.queue_free()
		await frames(2)


# ---------------------------------------------------------------- the shared foundation (FoundationLink)

func _foundation_match(venue := "national", seed := 77, event := "regu", user := -1) -> Node:
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "THA", "away": "MAS", "venue": venue, "event": event, "sets": 1, "points": 15, "user_team": user,
		"demo": true, "seed": seed, "mode": "quick"}
	add_child(m)
	return m


## What match m draws: its visible geometry (every body, the venue, the crowd), by kind.
func _drawn(m: Node) -> Dictionary:
	var out := {}
	for n in m.find_children("*", "GeometryInstance3D", true, false):
		if (n as GeometryInstance3D).is_visible_in_tree():
			var k := n.get_class()
			out[k] = int(out.get(k, 0)) + 1
	return out


## Low is the budget phone's level (the Galaxy A16) and stays exactly as it was: with the licensed clips or without, a
## Low match draws the game's own bodies (no links, no foundation replays), the same things in the same number. On
## Medium and High (with the clips) every player, official and substitute is drawn by the foundation on the man's or
## woman's body: each at his place, the game's hidden; under the game's moves every joint on the game's and the
## kicking foot (or the head) where the game's meets the ball; the capture walking the players between points, its
## feet planted, and the officials; the ball carried in the drawn hands; the point's best moment replayed, one a point
## at most, by priority, a tap skips it; lowered to Low mid-match, the game's own bodies again. Without the clips
## nobody has a link anywhere.
func _foundation(available: bool) -> void:
	var was := int(Game.settings.graphics)
	Game.settings.graphics = Game.GFX_LOW
	var lows := []
	for off in [true, false]:
		FoundationLink.off = off
		var lm := _foundation_match("beach")
		await frames(4)
		var links := (lm._all_bodies() as Array).filter(func(b): return (b as RealBody).link != null).size()
		lows.append([_drawn(lm), links, lm.wsg_replay == null, lm.find_children("Foundation", "", true, false).size()])
		lm.queue_free()
		await frames(2)
	FoundationLink.off = false
	check(lows[1][1] == 0 and lows[1][2] and lows[1][3] == 0 and lows[0][0] == lows[1][0],
		"foundation: Low draws the game's own bodies, the same %d things as without the foundation (%s)"
		% [(lows[1][0] as Dictionary).values().reduce(func(x, y): return x + y, 0), lows[1][0]])
	# The replays a point earns (its log row: touches, why, team, seq), one at most, the best first.
	for c in [[[1, "ace", 0, "serve"], "horse", "horse_ace"], [[1, "ace", 0, "serve"], "power", "ace"],
			[[4, "kill_head_spike", 0, "serve|receive set attack"], "", "head_spike"],
			[[9, "block", 1, "serve|receive set attack|block!"], "", "block"],
			[[3, "kill_roll", 1, "serve|receive set attack"], "roll", "roll"],
			[[7, "kill_tapak", 0, "serve|receive set attack|receive set attack"], "", "dig"],
			[[7, "kill_roll", 0, "serve|receive set attack|receive set attack"], "", "roll"],
			[[4, "kill_tapak", 1, "serve|receive set attack"], "", "tapak"],
			[[8, "out", 0, "serve|receive set attack|receive set attack|receive"], "", "dig"],
			[[9, "out", 1, "serve|receive set over|receive set attack|receive set over"], "", "rally"],
			[[3, "out", 1, "serve|receive set attack"], "", ""]]:
		var got: String = (load("res://game/match.gd") as Script).replay_kind(c[0], c[1])
		check(got == c[2], "replays: %s (%s) -> %s (%s)" % [c[0], c[1], c[2] if c[2] != "" else "none", got])
	Game.settings.graphics = Game.GFX_HIGH
	var hm := _foundation_match("national", 5, "quadrant")
	await frames(4)
	var hb: Array = hm._all_bodies()
	check(not available or hb.all(func(b): return (b as RealBody).link != null) and hb.size() == 16,
		"foundation: High, a quadrant: all %d linked" % hb.size())
	hm.queue_free()
	await frames(2)
	Game.settings.graphics = Game.GFX_MEDIUM
	var m := _foundation_match("national", 77)
	await frames(4)
	var bodies: Array = m._all_bodies()
	if not available:
		check(bodies.all(func(b): return (b as RealBody).link == null) and m.wsg_replay == null,
			"foundation off (no licensed clips): nobody has a link, the game draws as before")
		m.queue_free()
		await frames(2)
		Game.settings.graphics = was
		return
	var missing := bodies.filter(func(b): return (b as RealBody).link == null).size()
	check(missing == 0 and bodies.size() == 14, "foundation: every player, official and substitute linked on Medium (%d, %d missing)" % [bodies.size(), missing])
	for b in bodies:
		(b as RealBody).link.measure = true
	var seen := {}
	var shown := 0
	var drift := 0.0
	var hips_gap := 0.0
	var gap_n := 0
	var gap_off := 0
	var contacts := 0
	var contact_gap := 0.0
	var phase := {}
	var walked := 0
	var slide := 0.0
	var slide_n := 0
	var last_foot := {}
	var slide_why := ""
	var hist := {}
	var held_gap := 0.0
	var held_n := 0
	var official_moves := 0
	var points_seen := 0
	var replay_end := -100
	for i in 2400:
		await frames(1)
		if m.state == m.S.REPLAY:
			replay_end = i
			continue
		points_seen = m.log.size()
		for b in bodies:
			var rb: RealBody = b
			var l: FoundationLink = rb.link
			if l == null or not l.last.has("Hips"):
				continue
			var fresh: bool = l.last.frame != seen.get(l, -1)
			seen[l] = l.last.frame
			if not l.body.is_visible_in_tree() or rb.mesh_instance.visible:
				shown += 1
			if not fresh or m.state == m.S.REPLAY or i < replay_end + 3:
				continue
			var hp: Vector3 = l.last.Hips
			var at := rb.global_position
			if l.last.mode == "full" and float(l.last.w) >= 1.0 and float(l.last.pw) >= 1.0:
				drift = maxf(drift, Vector2(hp.x - rb.game_hips().x, hp.z - rb.game_hips().z).length())
			elif l.last.mode == "move" and float(l.last.pw) <= 0.0:
				drift = maxf(drift, Vector2(hp.x - at.x, hp.z - at.z).length() - 0.25)
			if l.kind == "official" and l.mode == "move":
				official_moves += 1
			if l.kind != "player":
				continue
			var pl: Player = rb.get_parent()
			if l.last.mode == "full" and float(l.last.w) >= 1.0 and float(l.last.pw) >= 1.0:
				hips_gap = maxf(hips_gap, l.joint_gap("Hips"))
				for jb in ["Head", "LeftHand", "RightLeg", "RightFoot"]:
					gap_n += 1
					gap_off += int(l.joint_gap(jb) > 0.05)
			# At each move's contact: the part that meets the ball on the game's body, and the same on the drawn one.
			if pl.move != "" and Moves.CONTACT.has(pl.move) and l.mode == "full" and float(l.last.w) >= 1.0:
				var c: Array = Moves.CONTACT[pl.move]
				var tt: float = (m.now - pl.move_start) / Moves.length(pl.move)
				var was_t: float = phase.get(pl, -1.0)
				phase[pl] = tt
				if was_t >= 0.0 and was_t < float(c[4]) and tt >= float(c[4]):
					var best := []
					for part in ["instep_l", "instep_r", "head"]:
						var cp: Array = l.contact_points(part)
						var dball: float = (cp[0] as Vector3).distance_to(m.ball.global_position)
						if best.is_empty() or dball < float(best[0]):
							best = [dball, (cp[0] as Vector3).distance_to(cp[1])]
					contacts += 1
					contact_gap = maxf(contact_gap, float(best[1]))
			else:
				phase[pl] = -1.0
			var hh: Array = hist.get(l, [])
			hh.append("[%d %s yaw %.2f ly %.2f pos %s ank %s %s c %s ls %d]" % [i, l.mode, pl._yaw, l.loco.yaw, pl.position.snapped(Vector3.ONE * 0.01), (l.loco.planter.ankle_world[0] as Vector3).snapped(Vector3.ONE * 0.01), (l.loco.planter.ankle_world[1] as Vector3).snapped(Vector3.ONE * 0.01), l.loco.planter.contact, l.loco.state])
			if hh.size() > 10:
				hh.pop_front()
			hist[l] = hh
			# Walking under the capture: a planted foot stays where it was put.
			if l.mode == "move" and pl.vel.length() > 0.6:
				walked += 1
			for k in 2:
				var key := [l, k]
				var p: Vector3 = l.loco.planter.ankle_world[k]
				# (On the floor: the ankle within 4 cm of its standing height.)
				var down: bool = l.mode in ["move", "carry"] and l.legacy.weight <= 0.0 and l._pw <= 0.0 and float(l.loco.planter.contact[k]) > 0.5 \
					and p.y < (l.body.joints["LeftFoot"] as Vector3).y * l.body.global_transform.basis.get_scale().y + 0.04
				if down and last_foot.has(key):
					var sl := Vector2(p.x - last_foot[key].x, p.z - last_foot[key].z).length()
					if sl > slide:
						slide_why = "%s %s v %.2f frame %d hist %s" % [l.mode, l.loco.state, pl.vel.length(), i, hist.get(l, [])]
					slide = maxf(slide, sl)
					slide_n += 1
				if down:
					last_foot[key] = p
				else:
					last_foot.erase(key)
			# The ball carried: drawn in the drawn hands.
			if m._carrier == pl and l.mode in ["move", "carry"]:
				var bp: Vector3 = m.ball._mesh.global_position
				held_gap = maxf(held_gap, bp.distance_to(l.ball_point(pl._two >= 0.5)))
				held_n += 1
	check(shown == 0, "foundation: its bodies drawn, the game's hidden (%d frames otherwise)" % shown)
	check(drift < 0.05, "foundation: every body drawn at its own place (hips at most %.2f m off the game's)" % drift)
	check(hips_gap < 0.02 and gap_n > 5000 and gap_off <= gap_n / 50,
		"foundation: under the game's moves every joint lies on the game body's (hips at most %.1f cm off; head, hand, knee and ankle over 5 cm in %d of %d)"
		% [hips_gap * 100.0, gap_off, gap_n])
	check(contacts >= 20 and contact_gap < 0.04,
		"foundation: at contact the drawn foot or head is where the game's meets the ball (%d contacts, at most %.1f cm apart)" % [contacts, contact_gap * 100.0])
	check(walked > 300, "foundation: the capture walks the players between points (%d body-frames)" % walked)
	check(slide_n > 300 and slide < 0.03, "foundation: a planted foot does not slide under the capture (worst %.3f m a frame over %d: %s)" % [slide, slide_n, slide_why])
	check(held_n > 20 and held_gap < 0.02, "foundation: the ball carried is in the drawn hands (%d frames, at most %.1f cm off)" % [held_n, held_gap * 100.0])
	check(official_moves > 1000, "foundation: the officials standing and stepping under the capture (%d body-frames)" % official_moves)
	var per_point := {}
	for r in m.replays:
		per_point[r[0]] = int(per_point.get(r[0], 0)) + 1
	check(per_point.values().all(func(v): return v == 1) and m.replays.size() <= points_seen,
		"replays: one a point at most (%d over %d points: %s)" % [m.replays.size(), points_seen, m.replays])
	# A replay: the foundation's bodies as drawn (WsgReplay), the match still; a tap skips it.
	var guard := 0
	while m.state != m.S.REPLAY and guard < 6000:
		await frames(1)
		guard += 1
	var playing: bool = m.state == m.S.REPLAY and m.wsg_replay.playing and FoundationLink.frozen
	check(playing and m.replays.size() > 0, "replays: the point's moment (%s), the foundation's bodies as they were drawn" % [m.replays.back() if m.replays.size() > 0 else "none"])
	if playing:
		await frames(20)
		m.hud._replay_tag.pressed.emit()   # (a tap anywhere: the replay's tag covers the screen)
		await frames(3)
		check(m.state != m.S.REPLAY and not m.wsg_replay.playing and not FoundationLink.frozen, "replays: a tap skips it, back to the match (state %d)" % m.state)
	# Lowered to Low mid-match (WsgAutoTier): the game's own bodies again, no foundation replays.
	m.lower_graphics()
	await frames(3)
	var back: bool = bodies.all(func(b): return (b as RealBody).link == null and (b as RealBody).mesh_instance.visible)
	check(back and m.wsg_replay == null and m.find_children("Foundation", "", true, false).is_empty() and int(Game.settings.graphics) == Game.GFX_LOW,
		"foundation: lowered to Low mid-match, the game's own bodies again")
	m.queue_free()
	await frames(2)
	Game.settings.graphics = was
