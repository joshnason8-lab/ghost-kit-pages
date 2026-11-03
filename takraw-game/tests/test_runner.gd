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
	_serve_toss_clear()
	_officials_back_away()
	_no_glide_between_points()
	_no_glide_in_play()
	await _solid_props()
	_jitter()
	_stick_follows_screen()
	await _watch_ai()
	await _loading_overlay()
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


var _verbose := OS.get_environment("TEST_VERBOSE") == "1"


func check(ok: bool, what: String) -> void:
	checks += 1
	if _verbose:
		print("CHECK ", "ok   " if ok else "FAIL ", what)   # (TEST_VERBOSE=1: every check, to compare two runs)
	if not ok:
		failures += 1
		print("FAIL: ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Until a Start button's match has loaded (the loading overlay gone: Game.play_match).
func loaded() -> void:
	for i in 900:
		if not WsgLoading.busy():
			return
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
			await _until_built(s)
			check(is_instance_valid(s) and s.get_child_count() > 0, "%s: %s builds" % [pair[0], path])
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	Game._size_theme()


## A page that adds its long texts a piece a frame (the licences): until it has them all (at most 300 frames).
func _until_built(s: Node) -> void:
	for i in 300:
		if not is_instance_valid(s) or not s.has_method("built") or s.built():
			return
		await frames(1)


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
## Every venue, at every graphics level, its crowd the shared foundation's (0.15.0; the owner: fans sitting on their
## seats, not in them, standing on the floor, facing the play): its places declared (Arena.crowd_venue), the share the
## level fills them (Low 40%, Medium 70%, High all), drawn as the shared cards in one draw call (seen from behind, their
## backs), and every card measured
## (WsgCrowdCards.audit): a seated fan's seat of the trousers on their seat, the card in front of the seat, never in
## it, and every fan within 35 degrees of the play's nearest part. tools/wsg/crowd_audit.gd measures the 3D fans too.
func _crowd_facing() -> void:
	var keep: int = Game.settings.graphics
	for v in DB.VENUES:
		for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
			Game.settings.graphics = g
			var a := Arena.new(v[0], false, [Color("ff8a1f")])
			add_child(a)
			await frames(1)
			var ok: bool = a.crowd != null and a.crowd.cards != null
			check(ok, "%s (graphics %d): a crowd" % [v[0], g])
			if ok:
				var places: Dictionary = a.crowd.places
				var n: int = places.spots.size()
				var shown: int = a.crowd.cards.placed_cards.size()
				var draws := a.crowd.cards.find_children("*", "MultiMeshInstance3D", false, false).size()
				var res: Dictionary = a.crowd.cards.audit(Arena.crowd_venue(v[0]), places)
				var fails: Array = res.fails
				var hips: Array = res.hips
				var facing: float = res.facing
				var want: float = Game.crowd_density()
				check(n > 50 and absf(float(shown) / n - want) < 0.08, "%s (graphics %d): %d of its %d places filled (%.0f%%, the level's %.0f%%)"
					% [v[0], g, shown, n, 100.0 * shown / maxf(n, 1), 100.0 * want])
				check(draws == 1, "%s (graphics %d): the crowd in one draw call (%d)" % [v[0], g, draws])
				check(fails.is_empty(), "%s (graphics %d): every fan sits on their seat (hips %+.3f..%+.3f m), in front of it, and faces the play (at most %.0f degrees off) %s"
					% [v[0], g, hips[0] if hips[0] != INF else 0.0, hips[1] if hips[1] != -INF else 0.0, facing, str(fails)])
			a.queue_free()
			await frames(1)
	Game.settings.graphics = keep


## The spectators: on the sand they stand, in the arena's stands they sit (and the jury at their table); the flags in
## the crowd are the two teams'.
func _crowd_people() -> void:
	for v in ["beach", "national"]:
		var a := Arena.new(v, false, [Color("ff8a1f")])
		add_child(a)
		await frames(1)
		var standing := 0
		var seated := 0
		for i in a.crowd.places.spots.size():
			if float(a.crowd.places.seat[i]) > 0.0:
				seated += 1
			else:
				standing += 1
		if v == "beach":
			check(standing > 40 and seated == 0, "beach: people stand on the sand (%d)" % standing)
		else:
			check(standing == 0 and seated > 1000, "national: everyone in the stands is seated (%d seated, %d standing)" % [seated, standing])
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


## Low loads what it always has (the surfaces at 512 px, the 2K skies, the players' 1024 px textures); Medium and High
## their own bigger files (2K surfaces, 4K skies, 2048 px players). (The crowd: the shared cards at every level.)
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
	Game.settings.graphics = keep


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
			"JC Sounds", "SIL Open Font License", "FreeType", "MoCap Online", "ActorCore"],
		"privacy": ["joshnason8@gmail.com", "2026"], "help": ["joshnason8@gmail.com"]}
	var keep := String(Game.settings.language)
	for lang in ["en", "th", "ja", "my"]:
		TranslationServer.set_locale(lang)
		for kind in ["licences", "privacy", "help"]:
			var s: Control = (load("res://ui/licences_screen.gd" if kind == "licences" else "res://ui/doc_screen.gd") as Script).new()
			s.setup({"kind": kind, "back": func(): pass})
			add_child(s)
			await frames(2)
			await _until_built(s)
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


## The serve's toss keeps the ball out of the bodies (the owner saw it go into the thrower's as he wound up): every
## frame the thrower holds it, from his crouch to his release, the ball, where the match has it and where it is drawn
## (on the shared rig's hands on Medium and High), is outside his torso, head, thighs and shins; and from his hand to
## the server's kick, outside the server's torso and head. And the throw is the real one (0.14.3, the owner: "notice
## it's ONE hand"): the ball in his right hand all the while (the left nowhere near it); in regu the thrower down in his
## crouch as he begins, the ball low; let go at about chest height. Low (the Galaxy A16's) and High, men and women,
## regu and doubles, a few serves each.
const _BODY_CAPS := [["torso", "hips", "neck", 0.13], ["head", "head", "", 0.10], ["thigh_l", "thigh_l", "shin_l", 0.08],
	["thigh_r", "thigh_r", "shin_r", 0.08], ["shin_l", "shin_l", "foot_l", 0.055], ["shin_r", "shin_r", "foot_r", 0.055]]


## The ball's least clearance from a player's body (metres; below 0 it is inside), over the capsules named.
static func ball_clearance(pl: Node, p: Vector3, caps: Array) -> Array:
	var least := [INF, ""]
	for c in _BODY_CAPS:
		if not caps.has(c[0]):
			continue
		var a: Vector3 = pl.body.bone_world(c[1])
		var b: Vector3 = a + Vector3.UP * 0.18 if c[2] == "" else pl.body.bone_world(c[2])
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
		var d := p.distance_to(a + ab * t) - float(c[3]) - Ball.RADIUS
		if d < float(least[0]):
			least = [d, c[0]]
	return least


func _serve_toss_clear() -> void:
	var keep: int = Game.settings.graphics
	var all_caps: Array = _BODY_CAPS.map(func(c): return c[0])
	for level in [Game.GFX_LOW, Game.GFX_HIGH]:
		Game.settings.graphics = level
		for women in [false, true]:
			for ev in ["regu", "doubles"]:
				var m: Node = (load("res://game/match.gd") as Script).new()
				m.config = {"home": "THA", "away": "MAS", "venue": "national", "event": ev, "sets": 1, "points": 15,
					"user_team": -1, "demo": true, "seed": 4, "mode": "quick", "women": women}
				add_child(m)
				var thrower_least := [INF, ""]
				var server_least := [INF, ""]
				var serves := 0
				var frames_held := 0
				var off_palm := 0.0        # the ball from his right palm, held (m)
				var left_near := INF       # his left hand's nearest to the ball, held (m)
				var crouched := 0          # serves begun from the crouch, the ball low
				var low_most := 0.0
				var released := []         # the ball's height as he lets go
				var was_held := false
				var last := [false, INF]   # the frame before: him down in his crouch, the ball's height
				var was_toss := false
				for i in 30 * 150:
					m._process(1.0 / 30.0)
					m.set("_start_replay_after", -1.0)
					var th: Node = m._thrower()
					var crouching: bool = int(m.state) == int(m.S.SETUP) and th.toss_crouch and th.carrying
					var toss: bool = int(m.state) == int(m.S.TOSS)
					if toss and not was_toss:
						serves += 1
						if bool(last[0]) and float(last[1]) < 0.55:
							crouched += 1
						low_most = maxf(low_most, float(last[1]))
					was_toss = toss
					last = [th.crouched(), m.ball.global_position.y]
					if not toss and not crouching:
						was_held = false
						if serves >= 4 and int(m.state) != int(m.S.SETUP):
							break
						continue
					if th.carrying:
						frames_held += 1
						var mesh: Node3D = m.ball.get("_mesh")
						for p in [m.ball.global_position, mesh.global_position if mesh else m.ball.global_position]:
							var c := ball_clearance(th, p, all_caps)
							if float(c[0]) < float(thrower_least[0]):
								thrower_least = c
						off_palm = maxf(off_palm, m.ball.global_position.distance_to(th.carry_point()) if not th.body.link else 0.0)
						left_near = minf(left_near, m.ball.global_position.distance_to(th.body.bone_world("hand_l")))
						was_held = true
					else:
						if was_held and int(m.state) == int(m.S.TOSS):
							released.append(m.ball.global_position.y)
						was_held = false
						if m.ball.flying and th != m._server():
							var c2 := ball_clearance(m._server(), m.ball.global_position, ["torso", "head"])
							if float(c2[0]) < float(server_least[0]):
								server_least = c2
				var what := "%s %s %s" % [["Low", "Medium", "High"][level], "women" if women else "men", ev]
				check(serves >= 3 and frames_held > 20, "serve toss (%s): %d serves played, the ball held %d frames" % [what, serves, frames_held])
				check(float(thrower_least[0]) > 0.0, "serve toss (%s): the ball stays outside the thrower's body (least %.3f m, %s)" % [what, float(thrower_least[0]), thrower_least[1]])
				check(off_palm < 0.01 and left_near > 0.2, "serve toss (%s): one hand: the ball in his right (at most %.3f m off it), his left %.2f m from it at the nearest" % [what, off_palm, left_near])
				var rel_lo: float = released.min() if not released.is_empty() else 0.0
				var rel_hi: float = released.max() if not released.is_empty() else 0.0
				var tall := 0.94 if women else 1.0
				check(released.size() >= 3 and rel_lo > 0.85 * tall and rel_hi < 1.3 * tall,
					"serve toss (%s): let go at about chest height (%.2f-%.2f m, %d throws)" % [what, rel_lo, rel_hi, released.size()])
				if ev == "regu":
					check(crouched == serves, "serve toss (%s): the thrower throws from his crouch, the ball low (%d of %d serves; the ball at most %.2f m up)" % [what, crouched, serves, low_most])
					check(float(server_least[0]) > 0.0, "serve toss (%s): the thrown ball stays outside the server's torso and head (least %.3f m)" % [what, float(server_least[0])])
				m.queue_free()
				remove_child(m)
	Game.settings.graphics = keep


## The worst joint jolt in a frame (the jitter test, 0.14.3): a joint's second difference from one frame to the next,
## the sudden change in its speed that shows as a pop. Every move alone, on both models, 60 times a second, under
## JOLT_MOVE (the block's raised leg and its turn came in within one frame: 0.70 m; now 0.15). And two matches, Low and
## High, every player's hands, feet and head at 30 fps, under JOLT_MATCH: a cheer cut a spiker's roll short (his head
## 1.66 m), a move that ended as he ran put him straight into his stride (a foot 0.93), a kick still finishing after the
## point flickered between its legs and a walk's (1.1). The worst left is a hand taking the ball (0.70).
const JOLT_MOVE := 0.25    # m/frame^2 at 60 fps (900 m/s^2)
const JOLT_MATCH := 0.85   # m/frame^2 at 30 fps (765 m/s^2)
const PoseProbe := preload("res://tests/pose_probe.gd")


func _jitter() -> void:
	for women in [false, true]:
		var rows: Array = PoseProbe.jolts(women)
		rows.sort_custom(func(a, b): return float(a[1][0]) > float(b[1][0]))
		var over := rows.filter(func(r): return float(r[1][0]) >= JOLT_MOVE)
		check(rows.size() >= 20 and over.is_empty(), "jitter: every move alone on the %s's model, its worst jolt under %.2f m/frame^2 at 60 fps (worst: %s %.3f, %s at %.2f; %d moves)"
			% ["woman" if women else "man", JOLT_MOVE, rows[0][0], float(rows[0][1][0]), rows[0][1][1], float(rows[0][1][2]), rows.size()])
	var keep: int = Game.settings.graphics
	for setup in [[Game.GFX_LOW, "regu", false], [Game.GFX_HIGH, "doubles", true]]:
		Game.settings.graphics = setup[0]
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": "THA", "away": "MAS", "venue": "national", "event": setup[1], "sets": 1, "points": 15,
			"user_team": -1, "demo": true, "seed": 7, "mode": "quick", "women": setup[2]}
		add_child(m)
		var hist := {}
		var worst := [0.0, ""]
		var n := 0
		for i in 30 * 120:
			m._process(1.0 / 30.0)
			m.set("_start_replay_after", -1.0)
			for side in 2:
				for pl in m.players_on(side):
					for b in ["hand_l", "hand_r", "foot_l", "foot_r", "head"]:
						var key := [pl, b]
						var h: Array = hist.get(key, [])
						h.append(pl.body.bone_world(b))
						if h.size() > 3:
							h.pop_front()
						hist[key] = h
						if h.size() == 3:
							n += 1
							var d: float = ((h[2] as Vector3) - 2.0 * (h[1] as Vector3) + (h[0] as Vector3)).length()
							if d > float(worst[0]):
								worst = [d, "%s, move '%s', %s" % [b, pl.move, m.S.keys()[int(m.state)]]]
		check(n > 50000 and float(worst[0]) < JOLT_MATCH, "jitter: in a match (%s, %s, %s), every hand, foot and head under %.2f m/frame^2 at 30 fps (worst %.3f: %s; %d joint-frames)"
			% [["Low", "Medium", "High"][setup[0]], setup[1], "women" if setup[2] else "men", JOLT_MATCH, float(worst[0]), worst[1], n])
		m.queue_free()
		remove_child(m)
	Game.settings.graphics = keep


## The stick is the screen's (0.14.4; the owner found it wrong in other games off the side camera): in each camera
## (broadcast, side on, behind your end), your team on either side, your player put where the picture's middle, its
## edges and its corners show the floor, the stick pushed 8 ways through the steering itself: he runs the stick's way
## on the screen, within 10 degrees (before, by the camera's turn alone: 24-33 degrees out at the picture's middle, on
## the diagonals, and 50-56 at its edges); the aim across the other court too. And a cut to another camera is taken in over about 0.2 s: the frame after it he
## still runs nearly as before, and 0.3 s on the new picture's way.
func _stick_follows_screen() -> void:
	var dirs := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]
	var names := {Game.CAM_TV: "broadcast", Game.CAM_SIDE: "side on", Game.CAM_END: "end"}
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "THA", "away": "MAS", "venue": "national", "event": "regu", "sets": 1, "points": 15,
		"user_team": 0, "demo": true, "seed": 3, "mode": "quick"}
	add_child(m)
	for i in 10:
		m._process(1.0 / 30.0)
	var pl: Player = m.players_on(m._user_side())[0]
	var vp: Vector2 = m.cam.get_viewport().get_visible_rect().size
	for cam_side in [1, 0]:   # (your team starts on side 1; the sides change ends between sets)
		m.cam.set("_user_side", cam_side)
		for mode in [Game.CAM_TV, Game.CAM_SIDE, Game.CAM_END]:
			m.cam.mode = mode
			m.cam.snap()
			var worst := [0.0, ""]
			var n := 0
			var spots := 0
			for fx in [0.5, 0.15, 0.85]:
				for fy in [0.5, 0.2, 0.85]:
					var spot: Vector3 = m._floor_at(Vector2(vp.x * fx, vp.y * fy))
					if not spot.is_finite():
						continue   # (no floor there: the stands)
					spots += 1
					for j in dirs:
						# (a push straight into a prop - the net post ahead of a spot on the net's line, a bench - he goes
						# round, as he must: that push says nothing of the stick's way; WsgSolidProps, the props test)
						var way: Vector3 = m._cam_dir(j.normalized(), spot)
						if bool(m.arena.solid.sweep(spot + Vector3(0, 0.9, 0), spot + way * 2.0 + Vector3(0, 0.9, 0), Player.BODY_R + 0.35).get("hit", false)):
							continue
						var a := _steer(m, pl, spot, j.normalized(), 9, true)
						n += 1
						if a > float(worst[0]):
							worst = [a, "stick %s at the screen's %.2f, %.2f" % [j, fx, fy]]
			check(spots >= 6 and float(worst[0]) < 10.0, "stick (%s camera from side %d): he runs the stick's way on the screen, within 10 degrees (worst %.1f: %s; %d pushes at %d places)"
				% [names[mode], cam_side, float(worst[0]), worst[1], n, spots])
			# Aiming a kick or a serve: the stick moves the aim across the other court the screen's way too.
			var aim_worst := 0.0
			for opp in [0, 1]:
				var base := Vector3(Court.sgn(opp) * 5.0, 0, 0)
				for j in dirs:
					var a: Vector2 = m.cam.unproject_position(base)
					var b: Vector2 = m.cam.unproject_position(base + m._cam_dir(j.normalized(), base) * 0.05)
					aim_worst = maxf(aim_worst, rad_to_deg(absf((b - a).angle_to(j))))
			check(aim_worst < 10.0, "stick (%s camera from side %d): aiming, the stick moves the aim across either court the screen's way (worst %.1f degrees)"
				% [names[mode], cam_side, aim_worst])
		# A cut: the broadcast camera, your player running up the screen, then straight to the end camera.
		m.cam.mode = Game.CAM_TV
		m.cam.snap()
		var mid: Vector3 = m._floor_at(vp * 0.5)
		_steer(m, pl, mid, Vector2(0, -1), 9, true)
		var before: Vector3 = pl.target - pl.position
		m.cam.mode = Game.CAM_END
		m.cam.snap()
		_steer(m, pl, pl.position, Vector2(0, -1), 1, false)
		var just: Vector3 = pl.target - pl.position
		_steer(m, pl, pl.position, Vector2(0, -1), 9, false)
		var after := _steer(m, pl, pl.position, Vector2(0, -1), 6, false)
		var turned := rad_to_deg(absf(Vector2(before.x, before.z).angle_to(Vector2(just.x, just.z))))
		check(turned < 45.0 and after < 10.0, "stick (from side %d): a cut to another camera is eased in (the frame after it %.0f degrees off his way before; 0.3 s on, %.1f off the new picture's up)"
			% [cam_side, turned, after])
	m.queue_free()
	remove_child(m)


## Your player at spot (fresh: the stick's axes there at once) or where he is, the stick pushed j for frames (1/30 s):
## through Match._user_steer as in a rally, the camera still. The angle (degrees) between his run on the screen and j.
func _steer(m: Node, pl: Player, spot: Vector3, j: Vector2, frames: int, fresh: bool) -> float:
	pl.position = Vector3(spot.x, 0.0, spot.z)
	pl.target = pl.position
	pl.vel = Vector3.ZERO
	m.plan = {"player": pl, "user": true, "kind": "receive", "t": m.now + 60.0, "stand": pl.position, "pos": pl.position,
		"touch": 0, "move": "sila", "auto": false, "press_t": m.now, "from_set": true, "mirror": false}
	m.state = m.S.RALLY
	if fresh:
		m.set("_stick_axes", [])
	var from: Vector2 = m.cam.unproject_position(pl.position)
	for f in frames:
		m.set("_joy", j)
		m._user_steer(1.0 / 30.0)
		pl.tick(1.0 / 30.0, m.now)
	var to: Vector2 = m.cam.unproject_position(pl.position)
	if (to - from).length() < 0.5:
		return 180.0
	return rad_to_deg(absf((to - from).angle_to(j)))


## An official backing away (out of the ball's way, still facing the court) steps backwards, rather than running
## forward on the spot as he slides back (the owner saw that): his lower foot's speed over the floor against his own is
## about 1 (a forward stride sends it back at about twice his speed). Low (the A16's) and High.
func _officials_back_away() -> void:
	var keep: int = Game.settings.graphics
	for level in [Game.GFX_LOW, Game.GFX_HIGH]:
		Game.settings.graphics = level
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": "THA", "away": "MAS", "venue": "national", "event": "regu", "sets": 1, "points": 15,
			"user_team": -1, "demo": true, "seed": 3, "mode": "quick"}
		add_child(m)
		var offs: Officials = m.get("_officials")
		var o: Officials.One = null
		for one in offs.list:
			if one.standing:
				o = one
				break
		o.back_t = 1e9
		o.off_to = -o.body.global_transform.basis.z.normalized() * 1.2
		var ball := Vector3(0, 0.1, 30)
		var foot_speed := 0.0
		var body_speed := 0.0
		var n := 0
		var was := {}
		for i in 45:
			offs.tick(1.0 / 30.0, ball, true)
			var pos: Vector3 = o.body.global_position
			var fl: Vector3 = o.body.bone_world("foot_l")
			var fr: Vector3 = o.body.bone_world("foot_r")
			var low := "l" if fl.y < fr.y else "r"
			var f: Vector3 = fl if low == "l" else fr
			if not was.is_empty() and pos.distance_to(was.pos) > 0.001 and was.low == low:
				var step := pos.distance_to(was.pos)
				if step > 0.4 / 30.0:   # backing at 0.4 m/s or more
					body_speed += step
					foot_speed += Vector2(f.x - was.f.x, f.z - was.f.z).length()
					n += 1
			was = {"pos": pos, "f": f, "low": low}
		var ratio := foot_speed / maxf(body_speed, 0.001)
		check(n >= 4 and ratio < 1.4, "%s: an official backing away steps back (his lower foot over the floor at %.2f of his speed over %d frames; a forward stride skates it at about 2)" % [["Low", "Medium", "High"][level], ratio, n])
		m.queue_free()
		remove_child(m)
	Game.settings.graphics = keep


## Between points nobody glides (the owner saw a player slide back to his place after fetching the ball): over each
## half second a player walks (over 0.8 m/s, on the ground), the gap between his feet changes as he steps, whatever
## move of his is playing (picking the ball up, lobbing it to the thrower, cheering). A regu and a doubles match, Low.
func _no_glide_between_points() -> void:
	var keep: int = Game.settings.graphics
	Game.settings.graphics = Game.GFX_LOW
	var walks := 0
	var glides := []
	for ev in ["regu", "doubles"]:
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": "THA", "away": "MAS", "venue": "national", "event": ev, "sets": 1, "points": 15,
			"user_team": -1, "demo": true, "seed": 7, "mode": "quick"}
		add_child(m)
		var runs := {}
		for i in 30 * 150:
			m._process(1.0 / 30.0)
			m.set("_start_replay_after", -1.0)
			if not int(m.state) in [int(m.S.SETUP), int(m.S.DEAD), int(m.S.BREAK)]:
				runs.clear()
				continue
			for side in 2:
				for pp in m.players_on(side):
					var pl: Player = pp
					if pl.vel.length() <= 0.8 or absf(pl.body.position.y) > 0.02:
						runs.erase(pl)
						continue
					var fl: Vector3 = pl.body.bone_world("foot_l")
					var fr: Vector3 = pl.body.bone_world("foot_r")
					var run: Array = runs.get(pl, [])
					run.append([Vector2(fl.x - fr.x, fl.z - fr.z).length(), pl.move])
					runs[pl] = run
					if run.size() >= 15:
						var gaps: Array = run.map(func(e): return float(e[0]))
						if float(gaps.max()) - float(gaps.min()) < 0.08:
							glides.append(String(run[7][1]))
						else:
							walks += 1
						runs[pl] = []
		m.queue_free()
		remove_child(m)
	check(walks >= 30 and glides.is_empty(), "between points, %d half-second walks, all stepping (glides: %s)" % [walks + glides.size(), glides])
	Game.settings.graphics = keep


## The owner: "players still gliding a lot, like when getting in position to spike or block ... when getting the ball
## too ... prepping to block he is in a folded position and glides around." In an AI match (tests/glide_probe.gd), of
## the way the players go with a foot on the floor, the share that foot slid along with them (moving over half their
## speed; 0.15.2: running 87%, walking 63%, the block 99%, the dig and the chest 96-98%): now under a third, the
## receiving touches and the block under 35%.
func _no_glide_in_play() -> void:
	var stats: Dictionary = GlideProbe.measure(self, 150.0, [7])
	var steps: Dictionary = stats.get("_steps", {})
	stats.erase("_steps")
	for kind in ["run", "walk (between points)"]:
		var v: Array = steps.get(kind, [])
		v.sort()
		var med := float(v[v.size() / 2]) if not v.is_empty() else INF
		check(v.size() > 100 and med < 0.02, "a planted foot stays put %s: half its %d steps slide under %.1f cm (under 2)" % [
			"running" if kind == "run" else "walking between points", v.size(), 100.0 * med])
	var share := func(kinds: Array) -> Array:
		var moved := 0.0
		var glided := 0.0
		for k in kinds:
			if stats.has(k):
				moved += float(stats[k][1])
				glided += float(stats[k][2])
		return [glided / maxf(moved, 0.001), moved]
	for row in [[["run"], 0.30, "running in the rally"], [["walk (between points)"], 0.25, "walking between points"],
			[["block"], 0.35, "getting into position to block"], [["chest", "header", "sila", "thigh"], 0.35, "getting to the ball"]]:
		var s: Array = share.call(row[0])
		check(float(s[1]) > 3.0 and float(s[0]) < float(row[1]), "no gliding %s: %.0f%% of %.0f m slid (under %.0f%%)" % [row[2], 100.0 * float(s[0]), float(s[1]), 100.0 * float(row[1])])


## The owner: "There will NEVER be a time when a player or referee should walk through a table or bench etc. A ball
## should also bounce off these items." Every venue's props are solid (Arena.solid, the shared WsgSolidProps): the net
## posts, the referee's chair, the scorers' table and the benches among them; the players, the officials on their feet
## and the ball go by them; a ball sent at the scorers' table comes back off it. (tools/wsg/prop_audit.gd, in CI, plays
## a match at each venue and fails on anyone inside a prop or a ball through one.)
func _solid_props() -> void:
	for v in DB.VENUES:
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": "THA", "away": "MAS", "venue": v[0], "event": "regu", "sets": 1, "points": 15, "user_team": -1,
			"demo": true, "seed": 3, "mode": "quick"}
		add_child(m)
		var s: WsgSolidProps = m.arena.solid
		var names := {}
		for p in s.props:
			names[String(p.name)] = int(names.get(String(p.name), 0)) + 1
		var want := ["net post", "referee's chair", "scorers' table"]
		var missing := want.filter(func(n): return not names.has(n))
		check(missing.is_empty() and (names.has("team bench") or names.has("gym_bench")) and s.props.size() > 12,
			"%s: its props solid (%d: %s), missing %s" % [v[0], s.props.size(), names.keys().slice(0, 12), missing])
		var wired: bool = m.ball.solid == s and m.players_on(0).all(func(pl): return (pl as Player).solid == s) and m.get("_officials").solid == s
		check(wired, "%s: the players, the officials and the ball go by the props" % v[0])
		# A ball at the table, from the court's side (clear of the referee's chair in front of its middle): it comes back
		# off it, never through.
		var post_z: float = Court.HALF_W + Court.POST_OUT
		var r: Dictionary = s.bounce(Vector3(0.8, 0.5, post_z + 1.4), Vector3(0, 0, 12.0), Ball.RADIUS, 0.25)
		check(not (r.hits as Array).is_empty() and float((r.vel as Vector3).z) < 0.0 and float((r.pos as Vector3).z) < post_z + 2.25,
			"%s: a ball sent at the scorers' table comes back off it (%s)" % [v[0], r.pos])
		if String(v[0]) == "national":
			await _fetch_behind_bench(m, post_z)
		m.queue_free()
		remove_child(m)


## 0.15.4's stuck match (BOT_SEED 6): a ball come to rest behind a team bench. The fetcher must go round the bench and
## pick it up (he walked up and down in front of it for good), and the thrower given it after 14 s goes to his place
## with it (he kept heading for where it had lain).
func _fetch_behind_bench(m: Node, post_z: float) -> void:
	m.process_mode = Node.PROCESS_MODE_DISABLED   # (stepped here)
	var dt := 1.0 / 30.0
	var spot := Vector3(-3.67, Ball.RADIUS, post_z + 2.4 + 0.67)   # behind the left bench, 0.6 m in from its end
	for k in 2:
		m._process(dt)
	m.state = m.S.SETUP
	m.state_t = 0.0
	m.set("_carrier", null)
	for side in 2:
		for pp in m.players_on(side):
			(pp as Player).carrying = false
	m.ball.flying = false
	m.ball.loose = true
	m.ball.vel = Vector3.ZERO
	m.ball.global_position = spot
	m._fetch_ball()
	var f: Player = m.get("_fetcher")
	var got := -1.0
	var inside := 0.0
	for i in int(13.5 / dt):
		m._process(dt)
		if f:
			inside = maxf(inside, float(m.arena.solid.penetration(f.position, Player.BODY_R, Player.BODY_H)[0]))
		if m.get("_carrier") != null and got < 0.0:
			got = float(m.state_t)
			break
	check(f != null and got >= 0.0 and got < 14.0, "a ball behind the team bench: the fetcher goes round and picks it up (%.1f s)" % got)
	check(inside <= 0.02, "the fetcher round the bench, not through it (%.3f m in)" % inside)
	# The 14 s fallback: the thrower given the ball goes to his place with it.
	var th: Player = m._thrower()
	m.state = m.S.SETUP
	m.state_t = 14.5
	m.set("_carrier", null)
	m.set("_fetcher", th)
	th.target = spot
	th.face_to = spot
	m._step(dt)
	var place: Vector3 = m._serve_spot(th, th.side, th.side == m._serving_side())
	check(m.get("_carrier") == th and th.target.distance_to(place) < 0.01 and not th.face_to.is_finite() and m.get("_fetcher") == null,
		"the thrower given the ball after 14 s goes to his place with it")
	await frames(1)


## Watch AI (on the home screen): its setup in every language (the two teams, no side of yours, no difficulty); the
## match it starts the computer's on both sides, from the broadcast camera, the score up and no controls; 2x and back
## to 1x; Back pauses and resumes; replays; played to the end, its result "Match over", the records untouched; and
## Quit (the pause menu's) back to the home screen.
func _watch_ai() -> void:
	var keep_lang := String(Game.settings.language)
	Game.goto_menu()
	await frames(2)
	var entry: Button = null
	for l in Game.current.find_children("*", "Label", true, false):
		if (l as Label).text == tr("MENU_WATCH"):
			var x: Node = l
			while x and not (x is Button):
				x = x.get_parent()
			entry = x
	check(entry != null, "the home screen has Watch AI")
	if entry:
		entry.pressed.emit()
		await frames(2)
		check(Game.current.get_script().resource_path.ends_with("quick_setup.gd") and bool(Game.current.get("watch")),
			"Watch AI opens its setup")
	for pair in Game.LANGUAGES:
		Game.settings.language = pair[0]
		TranslationServer.set_locale(pair[0])
		Game._size_theme()
		var s: Node = Game.show_screen("res://ui/quick_setup.gd", {"watch": true})
		await frames(2)
		var words := []
		for n in s.find_children("*", "", true, false):
			if n is Label:
				words.append((n as Label).text)
			elif n is Button:
				words.append((n as Button).text)
		var all := "\n".join(words).to_lower()   # (a field's title is drawn in capitals)
		var has := func(k: String) -> bool: return all.contains(tr(k).to_lower())
		check(has.call("MENU_WATCH") and has.call("WATCH") and has.call("TEAM_A") and has.call("TEAM_B") and has.call("WATCH_NOTE"),
			"%s: Watch AI's setup has its title, Watch, the two teams and its note" % pair[0])
		check(not has.call("DIFFICULTY") and not has.call("YOUR_TEAM"), "%s: Watch AI's setup has no difficulty and no side of yours" % pair[0])
		check(not all.contains("menu_watch") and not all.contains("watch_note") and not all.contains("team_a"), "%s: Watch AI's words translated" % pair[0])
	Game.settings.language = keep_lang
	TranslationServer.set_locale(Game.language())
	Game._size_theme()
	var played := int(Game.records.get("played", 0))
	var qs: Node = Game.show_screen("res://ui/quick_setup.gd", {"watch": true})
	await frames(2)
	qs.set("_venue", "mall")
	qs._play()
	await loaded()
	var m: Node = Game.current
	check(m.has_method("set_paused") and int(m.user_team) == -1 and String(m.config.mode) == "watch", "Watch AI starts a match nobody plays")
	check(not m.controls.visible and m.hud.visible, "Watch AI: the score up, no controls")
	check(int(m.cam.mode) == Game.CAM_TV, "Watch AI: the broadcast camera")
	var sp: Button = m.hud.get("_speed")
	check(sp != null and sp.text == "1×", "Watch AI: a speed button at 1x")
	if sp:
		sp.pressed.emit()
		check(is_equal_approx(float(m.time_scale), 2.0) and sp.text == "2×", "Watch AI: 2x doubles the match's clock")
		sp.pressed.emit()
		check(is_equal_approx(float(m.time_scale), 1.0) and sp.text == "1×", "Watch AI: and back to 1x")
	Game.go_back()
	await frames(1)
	var paused_now := bool(m.paused)
	Game.go_back()
	await frames(1)
	check(paused_now and not bool(m.paused), "Watch AI: Back pauses the match and resumes it")
	m.hud.set_watch_speed(2.0)
	var replays := 0
	var was_replay := false
	for i in 30 * 60 * 25:
		if int(m.state) == int(m.S.OVER):
			break
		m._process(1.0 / 30.0)
		var r := int(m.state) == int(m.S.REPLAY)
		if r and not was_replay:
			replays += 1
		was_replay = r
	check(int(m.state) == int(m.S.OVER), "Watch AI: the match played to the end (%s)" % [m.set_scores])
	check(replays >= 1, "Watch AI: replays shown (%d)" % replays)
	for i in 600:
		if Game.current != m:
			break
		await frames(1)
	var res: Node = Game.current
	var title := ""
	for l in res.find_children("*", "Label", true, false):
		if (l as Label).text == tr("MATCH_OVER"):
			title = (l as Label).text
	check(res != m and title != "", "Watch AI: its result says the match is over (no victory or defeat)")
	check(int(Game.records.get("played", 0)) == played, "Watch AI: the records untouched")
	# Quit from the pause menu: back to the home screen.
	var qs2: Node = Game.show_screen("res://ui/quick_setup.gd", {"watch": true})
	await frames(2)
	qs2._play()
	await loaded()
	var m2: Node = Game.current
	m2.set_paused(true)
	await frames(1)
	m2.quit_match()
	await frames(3)
	check(Game.current.get_script().resource_path.ends_with("main_menu.gd"), "Watch AI: Quit match goes back to the home screen")


## The owner: "when you click start game there is a loading delay ... users might think the game has frozen." A real
## tap on Quick match's Play: in the tap's own frame the loading overlay (the shared WsgLoading) is up and the button
## off; it stays up, frame after frame, until the match has started; the bar only goes forward, moves in many frames and reaches the end; a second start and Back do nothing meanwhile; the match is built
## in steps (no step's slice of main-thread work over the foundation's 250 ms), drawn a part at a time (the warm-up)
## and held till its frames come smoothly (the settle); then it starts, every part of it shown, its clock running. Every Start button goes the same way (play_match).
func _loading_overlay() -> void:
	var qs: Node = Game.show_screen("res://ui/quick_setup.gd")
	await frames(3)
	var btn: Button = qs.get("_play_btn")
	check(btn != null and btn.is_visible_in_tree(), "Quick match has its Play button")
	if btn == null:
		return
	var at := btn.get_global_rect().get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		get_viewport().push_input(ev, true)   # (in the viewport's own coordinates: the window is stretched)
	var ld := WsgLoading.current()
	check(ld != null and ld.is_inside_tree() and (ld.parts().root as Control).visible and btn.disabled,
		"a tap on Play: the loading overlay up and the button off in the tap's own frame")
	if ld == null:
		return
	check((ld.parts().title as Label).text == tr("LOADING"), "the overlay says Loading in the game's language")
	var first: Node = Game.current
	Game.play_match({"home": "THA", "away": "MAS", "venue": "beach"})
	Game.go_back()
	await frames(1)
	var bar := -1.0
	var back := false
	var moved := 0
	var up := 0
	var matches := {}
	var reached := [0.0]   # (the bar's target: what it shows eases toward it)
	ld.progressed.connect(func(f: float, _l: String): reached[0] = maxf(reached[0], f))
	while WsgLoading.busy() and up < 900:
		var b := ld.shown()
		back = back or b < bar - 1e-6
		moved += 1 if b > bar + 1e-6 else 0
		bar = b
		up += 1
		matches[Game.current] = true
		await frames(1)
	var m: Node = Game.current
	check(first == qs and matches.size() <= 2 and m != qs and m.has_method("set_paused") and String(m.config.venue) == "national",
		"one match loads: a second start and Back while it loads do nothing (%d screens seen)" % matches.size())
	check(not back and moved >= 8 and float(reached[0]) >= 1.0, "the bar only goes forward, moves in %d of %d frames and reaches the end (%.2f, shown %.2f)" % [moved, up, float(reached[0]), bar])
	var r: Dictionary = Game.last_load
	check(r.get("failed", ["?"]).is_empty() and float(r.get("longest_slice_ms", 1e9)) < WsgLoading.STALL_MS,
		"built in steps: the longest slice of main-thread work %.0f ms (%s), under %.0f %s" % [float(r.get("longest_slice_ms", -1)),
		r.get("longest_slice", ""), WsgLoading.STALL_MS, r.get("steps", {})])
	var shown := 0
	var hidden := 0
	for g in m.find_children("*", "GeometryInstance3D", true, false):
		if (g as GeometryInstance3D).visible:
			shown += 1
			hidden += 1 if (g as GeometryInstance3D).layers == 0 else 0
	var warm: Dictionary = r.get("warm", {})
	check(int(warm.get("frames", 0)) >= 3 and int(warm.get("looks", 0)) > 5 and hidden == 0 and shown > 20,
		"drawn a part at a time (the warm-up): %d looks over %d frames, %d parts shown, none left hidden (%d)" % [int(warm.get("looks", 0)),
		int(warm.get("frames", 0)), shown, hidden])
	check(r.has("settled"), "held up until its frames run smoothly (settled %s, %.0f ms)" % [str(r.get("settled")), float(r.get("settle_ms", -1))])
	var t0 := float(m.state_t)
	await frames(5)
	check(m.process_mode == Node.PROCESS_MODE_INHERIT and int(m.state) == int(m.S.INTRO) and float(m.state_t) > t0,
		"then it starts: its clock running, the introduction under way")
	check(not is_instance_valid(qs) or not qs.is_inside_tree(), "the setup screen has gone")


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
	var drawn := {}   # body -> its feet as drawn: [L ankle, L toe, R ankle, R toe] (WsgNoteChecks.feet in skeleton_updated)
	var slide_why := ""
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
			# (The feet as drawn - planted - are read as the skeleton finishes them: bone_world outside skeleton_updated is
			# the clip's pose, not the planted one.)
			if not drawn.has(l.body):
				drawn[l.body] = []
				var wb: WsgBody = l.body
				wb.skeleton.skeleton_updated.connect(func(): drawn[wb] = WsgNoteChecks.feet(wb))
			var fresh: bool = l.last.frame != seen.get(l, -1)
			var gap_frames := maxi(1, int(l.last.frame) - int(seen.get(l, int(l.last.frame) - 1)))
			seen[l] = l.last.frame
			if not l.body.is_visible_in_tree() or rb.mesh_instance.visible:
				shown += 1
			if not fresh or m.state == m.S.REPLAY or i < replay_end + 3:
				continue
			var hp: Vector3 = l.last.Hips
			var at := rb.global_position
			# (Posed every frame: a far one, posed every second, is carried to his next place with his last pose between.)
			var each := l.pose_every == 1
			if not each:
				pass
			elif l.last.mode == "full" and float(l.last.w) >= 1.0 and float(l.last.pw) >= 1.0:
				drift = maxf(drift, Vector2(hp.x - rb.game_hips().x, hp.z - rb.game_hips().z).length())
			elif l.last.mode == "move" and float(l.last.pw) <= 0.0:
				drift = maxf(drift, Vector2(hp.x - at.x, hp.z - at.z).length() - 0.25)
			if l.kind == "official" and l.mode == "move":
				official_moves += 1
			if l.kind != "player":
				continue
			var pl: Player = rb.get_parent()
			if each and l.last.mode == "full" and float(l.last.w) >= 1.0 and float(l.last.pw) >= 1.0:
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
			# Walking under the capture: a planted foot stays where it was put.
			if l.mode == "move" and pl.vel.length() > 0.6:
				walked += 1
			for k in 2:
				var key := [l, k]
				var feet: Array = drawn.get(l.body, [])
				if feet.size() < 4:
					continue
				var p: Vector3 = feet[k * 2]
				var toe: Vector3 = feet[k * 2 + 1]
				# (On the floor: the ankle within 4 cm of its standing height.)
				var down: bool = l.mode in ["move", "carry"] and l.legacy.weight <= 0.0 and l._pw <= 0.0 and float(l.loco.planter.contact[k]) > 0.5 \
					and p.y < (l.body.joints["LeftFoot"] as Vector3).y * l.body.global_transform.basis.get_scale().y + 0.04
				if down and last_foot.has(key):
					# The smaller of the drawn ankle's and toe's move this frame, as the shared foundation's foot_slip measures:
					# a heel rolling up over a held ball of the foot is not a slide (the planter holds a foot flat on the floor
					# however fast it moves, 13f00e2: rolling off it read 4 cm on the planter's ankle alone), and a real slide
					# moves both ends.
					var held: Array = last_foot[key]
					var sl := minf(Vector2(p.x - held[0].x, p.z - held[0].z).length(), Vector2(toe.x - held[1].x, toe.z - held[1].z).length()) / gap_frames
					if sl > slide:
						slide_why = "%s, gait state %d, %.2f m/s, frame %d" % [l.mode, l.loco.state, pl.vel.length(), i]
					slide = maxf(slide, sl)
					slide_n += 1
				if down:
					last_foot[key] = [p, toe]
				else:
					last_foot.erase(key)
			# The ball carried: drawn in the drawn hands.
			if m._carrier == pl and l.mode in ["move", "carry"]:
				var bp: Vector3 = m.ball._mesh.global_position
				held_gap = maxf(held_gap, bp.distance_to(l.ball_point(false)))
				held_n += 1
	check(shown == 0, "foundation: its bodies drawn, the game's hidden (%d frames otherwise)" % shown)
	check(drift < 0.05, "foundation: every body drawn at its own place (hips at most %.2f m off the game's)" % drift)
	check(hips_gap < 0.02 and gap_n > 5000 and gap_off <= gap_n / 50,
		"foundation: under the game's moves every joint lies on the game body's (hips at most %.1f cm off; head, hand, knee and ankle over 5 cm in %d of %d)"
		% [hips_gap * 100.0, gap_off, gap_n])
	check(contacts >= 20 and contact_gap < 0.04,
		"foundation: at contact the drawn foot or head is where the game's meets the ball (%d contacts, at most %.1f cm apart)" % [contacts, contact_gap * 100.0])
	check(walked > 300, "foundation: the capture walks the players between points (%d body-frames)" % walked)
	# The rig's boots (WsgFootFlat, 0.15.1): their heel-to-toe rise at rest, measured on each character (the modifier
	# turns them flat where it is 2 degrees or more), for the log.
	print("foundation: the rig's boots' sole tilt (degrees; WsgFootFlat flattens %.0f or more): %s" % [WsgFootFlat.MIN_TILT, FoundationLink.sole_tilt])
	check(slide_n > 150 and slide < 0.03, "foundation: a planted foot does not slide under the capture (worst %.3f m a frame over %d: %s)" % [slide, slide_n, slide_why])
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
