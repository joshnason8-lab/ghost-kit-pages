extends Node
## The smoke test CI runs before building: every screen opens in every language; a season and a tournament play
## through to their champions; AI matches in each event finish with scores the laws allow; a team event's regus never
## use a player twice; every spectator in every venue faces the court; the moves built on the CMU library's jumps load
## and keep their feet from sliding; the save files read back. Headless:
##   godot --headless --path . --fixed-fps 30 res://tests/test_runner.tscn
## Exits 1 on any failure.

var failures := 0
var checks := 0


func _ready() -> void:
	Game.main = self
	Game.reset_settings_for_tests()
	var keep: Dictionary = Game.settings.duplicate(true)
	await _screens()
	_rules_helpers()
	_season()
	_cup()
	_team_event_lineups()
	await _crowd_facing()
	_mocap_moves()
	await _matches()
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


## The moves built on real jumps (Moves.CMU): each loads from its clip, and while a foot is on the floor it doesn't
## slide more than 3 cm from one frame to the next (30 a second), on the man's model and on the woman's.
func _mocap_moves() -> void:
	for w in [false, true]:
		var rig := RealBody.rig(w)
		for name in Moves.CMU:
			check(Moves.is_clip(name), "%s: its motion capture loads" % name)
			var frames := int(round(Moves.length(name) * 30.0)) + 1
			var worst := 0.0
			var last := {}
			for i in frames:
				var p := Moves.sample(name, float(i) / float(frames - 1))
				rig.solve(p)
				var yaw := deg_to_rad(float(p.get("yaw", 0.0)))
				for side in ["Left", "Right"]:
					var at := (rig.sole(side) + Vector3(0, float(p.get("y", 0.0)), 0)).rotated(Vector3.UP, yaw)
					var down := at.y < RealBody.SOLE_DOWN
					if down and last.has(side) and last[side][1]:
						worst = maxf(worst, Vector2(at.x - last[side][0].x, at.z - last[side][0].z).length())
					last[side] = [at, down]
			check(worst < 0.03, "%s (%s): feet on the floor don't slide (worst %.3f m a frame)" % [name, "woman" if w else "man", worst])


func _matches() -> void:
	var cases := [["regu", 3, 15, "THA", "MAS", "dome"], ["quadrant", 1, 15, "JPN", "VIE", "beach"], ["doubles", 1, 15, "PHI", "LAO", "street"],
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
