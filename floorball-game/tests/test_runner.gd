extends Node
## The tests CI runs before building. The rules module, rule by rule (docs/RULES.md lists the rule each check stands
## for); every screen opens in every language; every scrolling page scrolls when dragged on its text; the World
## Finals plays through to its medals and its save reads back; AI matches finish with results the laws allow and
## numbers like real floorball's. Headless:
##   godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn [-- quick]
## Exits 1 on any failure.

var failures := 0
var checks := 0
var quick := false


func _ready() -> void:
	quick = "quick" in OS.get_cmdline_user_args()
	Game.main = self
	Game.settings.sound = false
	var keep: Dictionary = Game.settings.duplicate(true)
	_rink()
	_restarts()
	_offences()
	_goals()
	_clock()
	_penalties()
	_overtime_shootout()
	_plurals()
	_translations()
	_cup()
	_season()
	await _screens()
	await _penalty_shot()
	await _match_parts()
	await _coach()
	await _matches()
	Game.settings = keep
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


# ---------------------------------------------------------------- the rules, one by one

## 101-103: the rink, its areas and the goals.
func _rink() -> void:
	check(Rules.LENGTH == 40.0 and Rules.WIDTH == 20.0, "101: the rink is 40 x 20 m")
	check(is_equal_approx(Rules.HALF_L - Rules.GOAL_LINE, 3.5), "102: the goal line is 3.5 m from the end board")
	check(is_equal_approx(Rules.CREASE_BACK - Rules.CREASE_FRONT, 4.0) and is_equal_approx(Rules.CREASE_HALF_W * 2.0, 5.0), "102.3: the goal crease is 4 x 5 m")
	check(is_equal_approx(Rules.HALF_L - Rules.CREASE_BACK, 2.85), "102.3: the goal crease is 2.85 m from the end board")
	check(is_equal_approx(Rules.GOAL_LINE - Rules.GK_AREA_FRONT, 1.0) and is_equal_approx(Rules.GK_AREA_HALF_W * 2.0, 2.5), "102.4: the goalkeeper area is 1 x 2.5 m")
	check(is_equal_approx(Rules.CREASE_BACK - Rules.GOAL_LINE, 0.65), "102.4: the goalkeeper area 0.65 m in front of the crease's rear line")
	check(is_equal_approx(Rules.GOAL_W, 1.6) and is_equal_approx(Rules.GOAL_H, 1.15), "103: the goal is 160 x 115 cm")
	check(Rules.in_goal_crease(Vector2(15.0, 2.0), 1) and not Rules.in_goal_crease(Vector2(12.0, 0.0), 1), "the goal crease, inside and out")
	check(Rules.in_gk_area(Vector2(16.0, 0.5), 1) and not Rules.in_gk_area(Vector2(15.0, 0.0), 1) and not Rules.in_gk_area(Vector2(16.0, 1.5), 1), "the goalkeeper area, inside and out")
	check(not Rules.in_rink(Vector2(19.9, 9.9)) and Rules.in_rink(Vector2(19.9, 0.0)) and Rules.in_rink(Vector2(0.0, 9.9)), "101: the corners are rounded")
	var dots := Rules.faceoff_dots()
	check(dots.size() == 7 and dots.has(Vector2(16.5, 8.5)) and dots.has(Vector2(0, -8.5)), "102: the centre spot and six face-off dots, 1.5 m from the boards")
	check(Rules.BALL_D == 0.072, "the ball is 72 mm")


## 503, 504, 506: where play restarts.
func _restarts() -> void:
	check(Rules.nearest_faceoff(Vector2(14.0, 6.0)) == Vector2(16.5, 8.5), "503: a face-off at the nearest dot")
	check(Rules.nearest_faceoff(Vector2(1.0, -3.0)) == Vector2(0, -8.5), "503: the centre spot is not one of the nearest dots")
	var hi := Rules.hit_in_spot(Vector2(5.0, 10.0))
	check(is_equal_approx(hi.y, 8.5) and is_equal_approx(hi.x, 5.0), "504: a hit-in 1.5 m from the board where it left (%s)" % hi)
	check(Rules.hit_in_spot(Vector2(18.5, -9.0)) == Vector2(16.5, -8.5), "504: never behind the goal line's extension: the nearest dot on it")
	var side := Rules.hit_in_spot(Vector2(-12.0, -10.0))
	check(is_equal_approx(side.y, -8.5), "504: on the far side too (%s)" % side)
	check(Rules.free_hit_spot(Vector2(0, 3)) == Vector2(0, 3), "506: a free-hit where the offence was")
	check(Rules.free_hit_spot(Vector2(18.0, 2.0)) == Vector2(16.5, 8.5), "506: from behind the goal line's extension, the nearest dot on it")
	var near := Rules.free_hit_spot(Vector2(14.0, 0.0))
	check(is_equal_approx(near.x, Rules.GK_AREA_FRONT - 3.5) and is_equal_approx(near.y, 0.0), "506: moved straight out to 3.5 m from the goalkeeper area (%s)" % near)
	check(Rules.free_hit_spot(Vector2(11.5, 1.0)) == Vector2(11.5, 1.0), "506: 3.5 m is from the goalkeeper area, not the goal crease (a free-hit 4 m out stays)")
	var side_near := Rules.free_hit_spot(Vector2(14.5, 2.5))
	var g := Vector2(Rules.GOAL_LINE, 0.0)
	check(Rules.gk_area_distance(side_near, 1) >= 3.49 and absf((side_near - g).normalized().cross((Vector2(14.5, 2.5) - g).normalized())) < 0.01, "506: moved out along the line from the goal's centre (%s)" % side_near)
	check(Rules.keeps_distance(Vector2(3.0, 0), Vector2.ZERO) and not Rules.keeps_distance(Vector2(2.5, 0), Vector2.ZERO), "504, 506: opponents 3 m from the ball")


## 507, 605, 607: what each offence leads to.
func _offences() -> void:
	for id in ["stick_hit", "hook", "high_stick", "high_ball", "between_legs", "push", "obstruct", "head", "hand", "jump", "lying",
			"gk_area", "gk_hold", "gk_over_centre", "gk_backpass", "gk_outside", "delay", "bad_restart"]:
		check(Rules.sanction(id) == "free_hit", "507: %s is a free-hit" % id)
		check(Rules.offence_rule(id).begins_with("507"), "507: %s has its rule number (%s)" % [id, Rules.offence_rule(id)])
	check(Rules.sanction("hook", true) == "pen2", "605: dangerous hooking is 2 minutes")
	check(Rules.sanction("stick_hit", false, true) == "pen5", "607: violent stick play is 5 minutes")
	for id in ["trip", "slash", "hold", "too_many", "block_lying", "charge"]:
		check(Rules.sanction(id) == "pen2", "605: %s is a minor bench penalty" % id)
	check(Rules.sanction("rough_board") == "pen5", "607: pushing into the boards violently is a major")
	check(Rules.sanction("unsporting") == "pen10", "610: unsportsmanlike behaviour is a personal penalty")
	check(Rules.sanction("fight") == "match", "614: violent conduct is a match penalty")
	check(Rules.sanction("slash", false, true) == "pen5", "a violent minor becomes a major")


## 701-703: goals.
func _goals() -> void:
	var base := {"last_team": 0, "defending_team": 1, "how": "stick", "from_front": true}
	check(bool(Rules.judge_goal(base).ok), "702: played in with the stick: a goal")
	check(not bool(Rules.judge_goal(base.merged({"from_front": false}, true)).ok), "702: not from the front: no goal")
	check(not bool(Rules.judge_goal(base.merged({"how": "kick"}, true)).ok), "703: kicked in: no goal")
	check(not bool(Rules.judge_goal(base.merged({"how": "head"}, true)).ok), "703: headed in: no goal")
	check(not bool(Rules.judge_goal(base.merged({"how": "hand"}, true)).ok), "703: by hand: no goal")
	check(bool(Rules.judge_goal(base.merged({"how": "gk_throw"}, true)).ok), "702 (2026): a goalkeeper's throw may score")
	check(bool(Rules.judge_goal(base.merged({"how": "deflect_defender"}, true)).ok), "702: off a defender: a goal")
	check(bool(Rules.judge_goal(base.merged({"how": "body"}, true)).ok), "702: off an attacker's body without intent: a goal")
	check(not bool(Rules.judge_goal(base.merged({"how": "body", "deliberate": true}, true)).ok), "703: directed in with the body: no goal")
	check(not bool(Rules.judge_goal(base.merged({"attack_offence": true}, true)).ok), "703: after an attacking offence: no goal")
	check(not bool(Rules.judge_goal(base.merged({"too_many": true}, true)).ok), "703: too many players: no goal")
	check(not bool(Rules.judge_goal(base.merged({"clock_done": true}, true)).ok), "701: after the period's time: no goal")
	var own := Rules.judge_goal({"last_team": 1, "defending_team": 1, "how": "kick", "from_front": true})
	check(bool(own.ok) and bool(own.get("own_goal", false)), "702: an own goal counts however it went in")


## 201: the clock.
func _clock() -> void:
	var s := Rules.State.new()
	check(Rules.PERIODS == 3 and Rules.PERIOD_S == 1200.0 and Rules.INTERVAL_S == 600.0, "201: three periods of 20 minutes, 10-minute intervals")
	s.tick(10.0, false)
	check(s.clock == 0.0, "201: effective time: the clock stands at a stoppage")
	s.tick(10.0, true)
	check(is_equal_approx(s.clock, 10.0), "201: and runs in play")
	var r := Rules.State.new()
	r.clock_mode = Rules.CLOCK_RUNNING
	r.tick(30.0, false)
	check(is_equal_approx(r.clock, 30.0), "201: a league's running clock runs through stoppages")
	r.period = 3
	r.clock = Rules.PERIOD_S - 170.0
	r.tick(5.0, false)
	check(is_equal_approx(r.clock, Rules.PERIOD_S - 170.0), "201 (2026): the last 3 minutes are always effective time")
	var q := Rules.State.new()
	q.period_s = 60.0
	check(q.tick(70.0, true) == "period_end" and is_equal_approx(q.clock, 60.0), "the period ends on its time, never past it")
	check(q.end_period() == "interval" and q.period == 2 and q.clock == 0.0, "201: an interval, then the next period")
	check(Rules.TIMEOUT_S == 30.0 and q.timeouts == [1, 1], "202: one 30-second time-out a team")
	check(Rules.GK_HOLD_S == 3.0, "507.16: the goalkeeper holds the ball 3 seconds at most")


## 601-614: the penalty bench.
func _penalties() -> void:
	var s := Rules.State.new()
	s.add_penalty(0, "a", "pen2", "trip")
	check(s.strength(0) == 4 and s.strength(1) == 5, "604: a minor penalty takes a player off")
	s.tick(60.0, true)
	check(is_equal_approx(float(s.penalties[0][0].left), 60.0), "604: penalty time runs with the game clock")
	s.tick(60.0, true)
	check(s.penalties[0].is_empty() and s.strength(0) == 5, "604: after 2 minutes he comes back")
	s.add_penalty(0, "a", "pen2")
	s.goal(1)
	check(s.penalties[0].is_empty(), "604: a power-play goal ends the minor penalty")
	s.add_penalty(0, "b", "pen5")
	s.goal(1)
	check(s.penalties[0].size() == 1 and s.strength(0) == 4, "606: a major is served in full, goals or not")
	var e := Rules.State.new()
	e.add_penalty(0, "a", "pen2")
	e.add_penalty(1, "b", "pen2")
	e.goal(1)
	check(e.penalties[0].size() == 1, "604: at equal strength a goal ends no penalty")
	var sh := Rules.State.new()
	sh.add_penalty(0, "a", "pen2")
	sh.goal(0)
	check(sh.penalties[0].size() == 1, "604: a short-handed goal ends no penalty of the scorers")
	var three := Rules.State.new()
	three.add_penalty(0, "a", "pen2")
	three.add_penalty(0, "b", "pen2")
	three.add_penalty(0, "c", "pen2")
	check(three.strength(0) == 3, "601: never fewer than three outfield players")
	check(not bool(three.penalties[0][2].running), "601: a third penalty waits until one of the first two ends")
	three.tick(120.0, true)
	check(three.penalties[0].size() == 1 and bool(three.penalties[0][0].running), "601: then it starts")
	var two := Rules.State.new()
	two.add_penalty(0, "a", "pen2")
	two.add_penalty(0, "b", "pen2")
	two.tick(30.0, true)
	two.add_penalty(0, "a", "pen2")   # a second offence by the same player waits too
	two.goal(1)
	check(two.penalties[0].size() == 2, "604: one goal ends one penalty (%d left)" % two.penalties[0].size())
	var pers := Rules.State.new()
	pers.add_penalty(0, "a", "pen10", "unsporting", "b")
	check(pers.strength(0) == 4 and pers.in_box(0).has("a") and not pers.in_box(0).has("b"), "609: a personal penalty comes with a minor, both sat by the offender")
	pers.tick(120.0, true)
	check(pers.strength(0) == 5 and pers.in_box(0).has("a"), "609: the team is whole after 2 minutes, the player sits his 10")
	pers.tick(599.0, true)
	check(pers.in_box(0).has("a"), "609: the 10 minutes start when the minor ends (out 2 + 10)")
	pers.tick(2.0, true)
	check(not pers.in_box(0).has("a"), "609: the player may come back after 12 minutes")
	var mp := Rules.State.new()
	mp.add_penalty(0, "a", "match", "fight", "b")
	check(mp.strength(0) == 4 and float(mp.penalties[0][0].left) == Rules.PEN_MAJOR_S, "613: a match penalty: the team serves 5 minutes")
	var co := Rules.State.new()
	co.add_penalty(0, "a", "pen2")
	co.add_penalty(1, "b", "pen2")
	co.mark_coincidental("pen2")
	check(co.strength(0) == 5 and co.strength(1) == 5, "2026: coincidental penalties no longer take players off the rink")
	check(co.in_box(0).has("a") and co.in_box(1).has("b"), "2026: the penalised players still sit")
	var ot := Rules.State.new()
	ot.period_s = 60.0
	ot.knockout = true
	ot.add_penalty(0, "a", "pen2")
	for i in 3:
		ot.tick(60.0, true)
		ot.end_period()
	check(ot.phase == "overtime" and ot.penalties[0].is_empty(), "the clock runs a penalty out across the periods")


## 203, 204: overtime and the penalty-shot competition.
func _overtime_shootout() -> void:
	var s := Rules.State.new()
	s.period_s = 10.0
	for i in 2:
		s.tick(10.0, true)
		check(s.end_period() == "interval", "periods 1 and 2 end in an interval")
	s.tick(10.0, true)
	check(s.end_period() == "done" and s.winner == -1, "a level group match is a draw")
	var k := Rules.State.new()
	k.period_s = 10.0
	k.knockout = true
	for i in 3:
		k.tick(10.0, true)
		k.end_period()
	check(k.phase == "overtime" and k.period == 4, "203: level and a winner needed: overtime")
	check(Rules.OT_IFF_S == 600.0, "203: overtime of 10 minutes")
	k.goal(1)
	check(k.phase == "done" and k.winner == 1, "203: sudden victory, the first goal wins")
	var so := Rules.State.new()
	so.phase = "shootout"
	var seq := [[true, false], [true, false], [true, false]]
	var decided := false
	for i in 3:
		so.shootout_shot(0, seq[i][0])
		decided = so.shootout_shot(1, seq[i][1])
	check(decided and so.winner == 0, "204: decided early once one side cannot catch up (3-0 after three each)")
	var sd := Rules.State.new()
	sd.phase = "shootout"
	var d := false
	for i in 5:
		sd.shootout_shot(0, i < 2)
		d = sd.shootout_shot(1, i < 2)
	check(not d and sd.phase == "shootout", "204: level after five each: on to one each")
	sd.shootout_shot(0, true)
	d = sd.shootout_shot(1, false)
	check(d and sd.winner == 0, "204: then decided when one scores and the other does not")
	check(sd.final_goals()[0] == 1, "a shoot-out win counts one goal")
	var mv := Rules.State.new()
	check(mv.may_shoot(0, "a", []) and not mv.may_shoot(0, "a", ["a"]), "204: the first five shots by five different players")
	for i in 5:
		mv.shootout[0].append(false)
	check(mv.may_shoot(0, "a", ["a", "b", "c", "d", "e"]), "204 (2026): after five, any player, again")


func _plurals() -> void:
	check(Game.plural_form("cs", 1) == "ONE" and Game.plural_form("cs", 3) == "FEW" and Game.plural_form("cs", 8) == "OTHER", "Czech plurals")
	check(Game.plural_form("pl", 1) == "ONE" and Game.plural_form("pl", 4) == "FEW" and Game.plural_form("pl", 12) == "MANY" and Game.plural_form("pl", 22) == "FEW", "Polish plurals")
	check(Game.plural_form("lv", 0) == "ZERO" and Game.plural_form("lv", 1) == "ONE" and Game.plural_form("lv", 11) == "ZERO" and Game.plural_form("lv", 21) == "ONE" and Game.plural_form("lv", 4) == "OTHER", "Latvian plurals")
	check(Game.plural_form("fr", 0) == "ONE" and Game.plural_form("en", 0) == "OTHER" and Game.plural_form("ja", 1) == "OTHER", "French, English, Japanese plurals")


## Every language has every key, its plural forms, and no placeholder lost in translation.
func _translations() -> void:
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/src/en.json"))
	var ph := RegEx.create_from_string("\\{[a-z_]+\\}")
	for pair in Game.LANGUAGES:
		var code: String = pair[0]
		var path := "res://i18n/src/%s.json" % code
		if code == "en":
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		check(d is Dictionary, "%s: translation file reads" % code)
		if not (d is Dictionary):
			continue
		var missing := 0
		var bad := []
		for k in en:
			if k.ends_with("_ONE") or k.ends_with("_OTHER"):
				continue
			if not d.has(k):
				missing += 1
				continue
			var want := {}
			for m in ph.search_all(String(en[k])):
				want[m.get_string()] = true
			for w in want:
				if not String(d[k]).contains(w):
					bad.append(k)
		check(missing == 0, "%s: every key translated (%d missing)" % [code, missing])
		check(bad.is_empty(), "%s: placeholders kept %s" % [code, bad.slice(0, 5)])
		for n in [1, 2, 5, 11, 22, 0]:
			var form := Game.plural_form(code, n)
			check(d.has("MINUTES_" + form) or (form == "OTHER" and d.has("MINUTES_OTHER")), "%s: plural form %s for %d" % [code, form, n])


func _cup() -> void:
	for women in [false, true]:
		var c: Cup = Game.new_cup("LAT", women)
		check(c.groups.size() == 4 and (c.groups[0] as Array).size() == 4, "the World Finals: four groups of four")
		check("SWE" in c.groups[0] or "SWE" in c.groups[1], "the top seeds in groups A and B")
		var guard := 0
		while c.stage != "done" and guard < 40:
			c.sim_next()
			guard += 1
		check(c.stage == "done" and String(c.medals.get("gold", "")) != "", "the World Finals reach their medals")
		var draws := 0
		for rnd in c.fixtures.groups:
			for f in rnd:
				if int(f.goals[0]) == int(f.goals[1]):
					draws += 1
		for st in ["playoffs", "qf", "sf", "medals"]:
			for f in c.fixtures[st][0]:
				check(int(f.goals[0]) != int(f.goals[1]), "%s: a knockout match has a winner" % st)
		var t := c.group_table(0)
		check(int(t[0].pts) >= int(t[1].pts) and int(t[0].p) == 3, "a group table: three matches each, in points order")
		Game.save_cup()
		Game.cup = null
		var back = Game.get_cup()
		check(back != null and back.medals.gold == c.medals.gold, "the World Finals save and load")
	Game.delete_cup()


## The club season: 3-2-1-0 points, the table's tiebreaks, every pair of the ten clubs met once, the play-offs
## seeded 1 v 4 and 2 v 3, and the season saved and carried on.
func _season() -> void:
	var keep_season = Game.season
	var reg := {"goals": [4, 2], "ot": false, "so": false}
	var otw := {"goals": [2, 3], "ot": true, "so": false}
	var sow := {"goals": [5, 4], "ot": true, "so": true}
	check(Season.points(reg, 0) == 3 and Season.points(reg, 1) == 0, "season: 3 for a win in regulation, 0 for a loss in it")
	check(Season.points(otw, 1) == 2 and Season.points(otw, 0) == 1, "season: 2 for a win in overtime, 1 for a loss in it")
	check(Season.points(sow, 0) == 2 and Season.points(sow, 1) == 1, "season: 2 for a win on penalty shots, 1 for a loss on them")
	check(DB.club_ids().size() == 10, "season: ten clubs")
	for id in DB.club_ids():
		check(not DB.TEAMS.has(id) and String(id).length() == 3, "season: %s is a three-letter code no national team has" % id)
		check(DB.team_name(id) != "" and not DB.team_name(id).begins_with("TEAM_"), "season: %s has a name" % id)
		check(DB.rating(id) < DB.rating("SWE") and DB.rating(id) < DB.rating("FIN"), "season: %s is below the top national teams" % id)
		check(DB.squad(id).size() == DB.squad("SWE").size() and DB.kits(id, "FOX").size() == 2, "season: %s has a squad and a kit" % id)
		var crest := UI.badge(id)
		check(crest is Crest, "season: %s shows a crest" % id)
		crest.free()
	# The table: points first, then goal difference, then goals scored.
	var t := Season.create("FOX", false, 7)
	var c: Array = t.clubs
	t.fixtures.league = [[
		{"home": c[0], "away": c[1], "played": true, "goals": [5, 1], "ot": false, "so": false, "user": false},
		{"home": c[2], "away": c[3], "played": true, "goals": [3, 0], "ot": false, "so": false, "user": false},
		{"home": c[4], "away": c[5], "played": true, "goals": [4, 1], "ot": false, "so": false, "user": false},
		{"home": c[6], "away": c[7], "played": true, "goals": [2, 1], "ot": true, "so": false, "user": false},
		{"home": c[8], "away": c[9], "played": false, "goals": [0, 0], "ot": false, "so": false, "user": false}]]
	var order := []
	for r in t.table():
		order.append(r.id)
	check(order[0] == c[0] and order[1] == c[4] and order[2] == c[2], "season: level on points, goal difference, then goals scored (%s)" % [order.slice(0, 3)])
	check(order[3] == c[6] and order[4] == c[7], "season: an overtime win (2) above an overtime loss (1)")
	check(order[7] == c[5] and order[8] == c[3] and order[9] == c[1], "season: losers by goal difference, then goals (%s)" % [order.slice(7, 10)])
	var row6: Dictionary = t.table()[3]
	check(int(row6.otw) == 1 and int(row6.pts) == 2 and int(row6.w) == 0, "season: an overtime win counts in OTW")
	for women in [false, true]:
		var s: Season = Game.new_season("OTR", women)
		var pairs := {}
		var ok_rounds := true
		for rnd in s.fixtures.league:
			var seen := {}
			for f in rnd:
				var k := "%s|%s" % ([f.home, f.away] if String(f.home) < String(f.away) else [f.away, f.home])
				pairs[k] = int(pairs.get(k, 0)) + 1
				seen[f.home] = true
				seen[f.away] = true
			if seen.size() != 10:
				ok_rounds = false
		var once := true
		for k in pairs:
			if int(pairs[k]) != 1:
				once = false
		check(s.fixtures.league.size() == 9 and pairs.size() == 45 and once, "season: nine rounds, all 45 pairings exactly once (%d)" % pairs.size())
		check(ok_rounds, "season: every club plays in every round")
		# Three rounds, the first your match played as a match ends (in overtime), then saved and carried on.
		var mine: Dictionary = s.user_fixture()
		var side := 0 if mine.home == "OTR" else 1
		var g := [2, 2]
		g[side] = 3
		s.record_user_result({"goals": g, "ot": true, "so": false})
		check(s.round == 1 and bool(mine.played), "season: your result plays the round")
		var mrow := {}
		for r in s.table():
			if r.id == "OTR":
				mrow = r
		check(int(mrow.pts) == 2 and int(mrow.otw) == 1, "season: your overtime win is 2 points")
		s.sim_next()
		s.sim_next()
		Game.save_season()
		var before: Array = s.table()
		Game.season = null
		var back = Game.get_season()
		check(back != null and back.round == 3 and back.stage == "league" and String(back.user) == "OTR" and bool(back.women) == women, "season: saves and carries on")
		var after: Array = back.table()
		check(String(after[0].id) == String(before[0].id) and int(after[0].pts) == int(before[0].pts) and String(after[9].id) == String(before[9].id), "season: the table reads back")
		var guard := 0
		while back.stage != "done" and guard < 20:
			back.sim_next()
			guard += 1
		check(back.stage == "done" and String(back.champion) != "" and back.user_finish() != "", "season: reaches its champion (%s)" % back.user_finish())
		var draws := 0
		for rnd in back.fixtures.league:
			for f in rnd:
				if int(f.goals[0]) == int(f.goals[1]):
					draws += 1
		check(draws == 0, "season: no league match is drawn")
		var tab: Array = back.table()
		check(int(tab[0].p) == 9 and int(tab[0].pts) >= int(tab[1].pts), "season: nine matches each, in points order")
		var sf: Array = back.fixtures.sf[0]
		check(String(sf[0].home) == String(tab[0].id) and String(sf[0].away) == String(tab[3].id) and String(sf[1].home) == String(tab[1].id) and String(sf[1].away) == String(tab[2].id), "season: semi-finals 1 v 4 and 2 v 3")
		var fin: Dictionary = back.fixtures.final[0][0]
		check(int(fin.goals[0]) != int(fin.goals[1]) and String(back.champion) in [String(fin.home), String(fin.away)], "season: the final decides the champion")
		check(String(fin.home) in [Season._winner_of(sf[0]), Season._winner_of(sf[1])] and String(fin.away) in [Season._winner_of(sf[0]), Season._winner_of(sf[1])], "season: the semi-finals' winners in the final")
	# A club out of the top four: the play-offs are played without it.
	var out := Season.create("OTR", false, 11)
	var guard2 := 0
	while out.stage == "league" and guard2 < 20:
		out.sim_next()
		guard2 += 1
	if out.place("OTR") > 4:
		check(out.stage == "done" and out.user_finish() == "missed", "season: out of the top four, the season ends with the league")
	Game.delete_season()
	Game.season = keep_season


# ---------------------------------------------------------------- screens

func _screens() -> void:
	var screens := ["res://ui/main_menu.gd", "res://ui/quick_setup.gd", "res://ui/settings_screen.gd", "res://ui/howto_screen.gd",
		"res://ui/cup_screen.gd", "res://ui/season_screen.gd", "res://ui/licences_screen.gd", "res://ui/button_layout_screen.gd"]
	var langs: Array = Game.LANGUAGES if not quick else [Game.LANGUAGES[0], Game.LANGUAGES[2]]
	for pair in langs:
		Game.settings.language = pair[0]
		TranslationServer.set_locale(pair[0])
		Game._size_theme()
		check(tr("GAME_TITLE") != "GAME_TITLE", "%s: translations load" % pair[0])
		check(tr("BTN_SHOOT") != "BTN_SHOOT" and tr("BTN_SHOOT") != "", "%s: button labels" % pair[0])
		for path in screens:
			var s := Game.show_screen(path)
			await frames(3)
			check(is_instance_valid(s) and s.get_child_count() > 0, "%s: %s builds" % [pair[0], path])
		for tab in 3:
			Game.show_screen("res://ui/howto_screen.gd", {"tab": tab})
			await frames(2)
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	Game._size_theme()
	Game.new_cup("SWE")
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(3)
	check(Game.current.get_child_count() > 0, "the World Finals hub builds")
	Game.delete_cup()
	# The club season's hub in every language: the table, your match, the play-offs, the end.
	for pair in langs:
		TranslationServer.set_locale(pair[0])
		Game._size_theme()
		var season: Season = Game.new_season("WLV")
		Game.show_screen("res://ui/season_screen.gd")
		await frames(2)
		check(Game.current.get_child_count() > 0, "%s: the club season hub builds" % pair[0])
		for i in 9:
			season.sim_next()
		Game.show_screen("res://ui/season_screen.gd")
		await frames(2)
		check(Game.current.get_child_count() > 0, "%s: the club season's play-offs build" % pair[0])
		while season.stage != "done":
			season.sim_next()
		Game.show_screen("res://ui/season_screen.gd")
		await frames(2)
		check(Game.current.get_child_count() > 0, "%s: the club season's end builds" % pair[0])
		Game.show_screen("res://ui/main_menu.gd")
		await frames(2)
		Game.delete_season()
	TranslationServer.set_locale("en")
	Game._size_theme()


## Chapter 8: a foul that stops a clear chance is a penalty shot, from the centre spot at the goal the fouled team
## attacks, the clock stopped while it is taken; anywhere else it is a free-hit.
func _penalty_shot() -> void:
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": -1, "demo": true, "seed": 3, "period": 4.0}
	add_child(m)
	while m.phase != "live":
		await get_tree().physics_frame
	var a: float = m.attack_dir(0)
	var v: Player = m.skaters(0)[0]
	var d: Player = m.skaters(1)[0]
	# Everyone else of the defending side well behind the play.
	for o: Player in m.skaters(1):
		o.respawn(Vector2(-a * 12.0, -6.0 + m.skaters(1).find(o) * 3.0))
	v.respawn(Vector2(a * 9.0, 0.5))
	d.respawn(Vector2(a * 8.0, 0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(m._clear_chance(v, d), "a clear chance: in front of goal, nobody but the goalkeeper between")
	var far: Player = m.skaters(0)[1]
	far.respawn(Vector2(-a * 5.0, 3.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not m._clear_chance(far, d), "in his own half: no clear chance")
	m.ball.carrier = v
	m._whistle_offence(d, "hook", "free_hit", v.pos, v)
	check(m.phase == "shootout" and bool(m._so.in_match) and int(m._so.team) == 0, "chapter 8: a penalty shot for the fouled team")
	var clock: float = m.rules.clock
	var guard := 0
	while m.phase == "shootout" and guard < 60 * 20:
		await get_tree().physics_frame
		guard += 1
	check(m.phase != "shootout", "the penalty shot is taken and play goes on (%s)" % m.phase)
	check(is_equal_approx(m.rules.clock, clock), "2026: the clock stands during a penalty shot")
	m.queue_free()
	await frames(2)


## The match's own pieces, each on a live AI match: a won tackle keeps the ball, a penalty's player walks to the
## penalty bench and comes back when it is over, the empty net, passive play.
func _match_parts() -> void:
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": -1, "demo": true, "seed": 5, "period": 4.0}
	add_child(m)
	while m.phase != "live":
		await get_tree().physics_frame
	var a: float = m.attack_dir(0)
	# A tackle won: the ball on the tackler's blade, and the player who lost it cannot take it straight back.
	var won := false
	for k in 60:
		var car: Player = m.skaters(1)[0]
		var def: Player = m.skaters(0)[0]
		car.respawn(Vector2(0, 0))
		def.respawn(Vector2(0.9, 0))
		await get_tree().physics_frame
		await get_tree().physics_frame
		m.ball.release()
		m.ball.carrier = car
		def.act = ""
		m._carry_ball()
		def.pos = m.ball.floor_pos() + Vector2(0.35, 0.0)   # the test's own placing, by the ball
		def.facing = PI
		m.tackle(def, car)
		if m.ball.carrier == def:
			await get_tree().physics_frame
			won = m.ball.carrier == def or (m.ball.last_team == 0)
			break
		if m.phase != "live":
			while m.phase != "live":
				await get_tree().physics_frame
	check(won, "a tackle won keeps the ball (it does not go straight back to the carrier)")
	while m.phase != "live":
		await get_tree().physics_frame
	# A minor: the player walks to the penalty bench, his team plays one fewer, and he is back when it is over.
	var off: Player = m.skaters(0)[1]
	var id := String(off.data.id)
	m._penalise(off, "pen2", "trip")
	var sitter: Player = m.sitters[0][0]
	check(m.rules.strength(0) == 4 and sitter.visible and String(sitter.data.id) == id, "105: the penalised player is seen going to the penalty bench")
	for i in 420:
		await get_tree().physics_frame
	check(sitter.pos.distance_to(m._box_seat(0, 0)) < 1.2, "105: he sits in his team's penalty bench (%s)" % sitter.pos)
	m._tick_clock(Rules.PEN_MINOR_S + 1.0, true)
	var short := 0
	for i in range(1, 6):
		if m.players[0][i].in_box:
			short += 1
	check(m.rules.strength(0) == 5 and short == 0 and not sitter.visible, "a penalty over: the team is whole again on the rink (%d places empty)" % short)
	m.queue_free()
	await frames(2)

	# The empty net: one goal down late in the last period, the goalkeeper off for a sixth outfield player.
	m = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": -1, "demo": true, "seed": 6, "period": 4.0}
	add_child(m)
	while m.phase != "live":
		await get_tree().physics_frame
	m.rules.period = Rules.PERIODS
	m.rules.goals = [0, 1]
	m.rules.clock = m.rules.period_s - 15.0
	a = m.attack_dir(0)
	check(m.ai[0].wants_empty_net() and not m.ai[1].wants_empty_net(), "the team behind wants an empty net late in the last period")
	var c: Player = m.skaters(0)[0]
	c.respawn(Vector2(a * 4.0, 0.0))
	await get_tree().physics_frame
	m.ball.release()
	m.ball.carrier = c
	m._empty_net()
	check(m.pulled[0], "with the ball in their half, the goalkeeper goes off")
	var gk: Player = m.keeper(0)
	var zone: Vector2 = m.sub_zone(0)
	gk.respawn(Vector2((zone.x + zone.y) * 0.5, -Rules.HALF_W + 0.4))
	await get_tree().physics_frame
	m._empty_net()
	check(not gk.on_rink and m.skaters(0).size() == 6, "302: over the board in the substitution zone, a sixth outfield player on (%d)" % m.skaters(0).size())
	m._set_phase("goal")
	check(gk.on_rink and gk.visible and m.skaters(0).size() == 5 and not m.pulled[0], "after a goal the goalkeeper is back in his net")
	m.queue_free()
	await frames(2)

	# 507.20: passive play warned, then a free-hit to the other team.
	m = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": -1, "demo": true, "seed": 7, "period": 4.0}
	add_child(m)
	while m.phase != "live":
		await get_tree().physics_frame
	a = m.attack_dir(0)
	c = m.skaters(0)[3]
	c.respawn(Vector2(-a * 8.0, 2.0))
	await get_tree().physics_frame
	m.ball.release()
	m.ball.carrier = c
	m._carry_ball()   # the ball on his blade, in his own end
	m.passive = {"team": 0, "t": m.PASSIVE_S + 0.5, "warned": false, "w": 0.0}
	m._passive_tick(0.02)
	check(bool(m.passive.warned), "507.20: a team keeping the ball in its own end is warned of passive play")
	m.passive.w = m.PASSIVE_WARN_S + 0.5
	m._passive_tick(0.02)
	check(m.phase == "whistle" and int(m.restart.team) == 1 and String(m.restart.why) == "delay", "507.20: still passive after the warning, a free-hit to the other team")
	m.queue_free()
	await frames(2)


## A first match with you in it: the coach's first tip shows, each tip once, and none when they are turned off. Your
## free-hit kept waiting goes to the other team.
func _coach() -> void:
	Game.settings.tips = true
	Game.settings.tips_seen = []
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": 0, "seed": 8, "period": 4.0, "mode": "quick"}
	add_child(m)
	var guard := 0
	while (m.phase != "live" or m.hud.coach_showing() == "") and guard < 600:
		await get_tree().physics_frame
		guard += 1
	check(m.hud.coach_showing() == tr("TIP_MOVE"), "a first match: the coach's first tip is how to move (%s)" % m.hud.coach_showing())
	check(not m.hud.coach("TIP_MOVE"), "each tip is said once")
	Game.settings.tips = false
	m.hud._coach_t = 0.0
	m.hud._coach_gap = 0.0
	check(not m.hud.coach("TIP_GOAL"), "no tips when they are turned off")
	# Your free-hit, not taken.
	while m.phase != "live":
		await get_tree().physics_frame
	var spot := Vector2(-m.attack_dir(0) * 3.0, 2.0)
	m._begin_restart({"kind": "free_hit", "team": 0, "spot": spot, "why": "push", "sanction": "free_hit", "line": ""})
	check(m.user_player == m.restart.taker, "you take your team's free-hit")
	guard = 0
	while int(m.restart.get("team", 0)) == 0 and guard < 60 * 20:
		await get_tree().physics_frame
		guard += 1
	check(int(m.restart.team) == 1 and String(m.restart.why) == "delay", "507.20: a free-hit kept waiting goes to the other team")
	m.queue_free()
	await frames(2)


# ---------------------------------------------------------------- matches

## AI matches: they finish, the score is the goals logged, the numbers look like floorball's (goals per match, shots,
## save rate), and every player's position is written once a frame and moves no faster than a person runs.
func _matches() -> void:
	var cases := [["SWE", "FIN", "arena", false], ["SUI", "CZE", "hall", true], ["LAT", "THA", "school", false]]
	if quick:
		cases = cases.slice(0, 1)
	var total_goals := 0
	var total_sog := 0
	var total_saves := 0
	var total_sa := 0
	var n := 0
	for c in cases:
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": c[0], "away": c[1], "venue": c[2], "user_team": -1, "demo": true, "seed": 7 + n, "mode": "quick",
			"period": 3.0, "knockout": c[3]}
		add_child(m)
		var audit := {"multi": 0, "fast": 0, "frames": 0}
		var last := {}
		var done := [false]
		var res := {}
		m.finished.connect(func(r):
			res.merge(r)
			done[0] = true)
		var guard := 0
		while not done[0] and guard < 60 * 60 * 25:
			await get_tree().physics_frame
			guard += 1
			for t in 2:
				for p in m.players[t]:
					if p.writes > 1:
						audit.multi += 1
					var k := str(p.get_instance_id())
					if last.has(k) and not p.respawned and p.visible:
						var step: float = (p.pos - last[k]).length()
						if step > Player.MAX_SPEED * (1.0 / 60.0) * 1.4 + 0.02:
							audit.fast += 1
					last[k] = p.pos
			audit.frames += 1
		check(done[0], "%s v %s: the match finishes" % [c[0], c[1]])
		check(audit.multi == 0, "%s v %s: one write of each player's position a frame (%d)" % [c[0], c[1], audit.multi])
		check(audit.fast == 0, "%s v %s: nobody moves faster than a sprint or jumps (%d of %d frames)" % [c[0], c[1], audit.fast, audit.frames])
		var g: Array = res.get("goals", [0, 0])
		var logged := [0, 0]
		for e in res.get("log", []):
			if String(e.kind) == "goal":
				logged[int(e.team)] += 1
		var so: Array = res.get("shootout", [[], []])
		if not (so[0] as Array).is_empty():
			logged[int(res.winner)] += 1
		check(logged == [int(g[0]), int(g[1])], "%s v %s: the score is the goals logged (%s, %s)" % [c[0], c[1], logged, g])
		if c[3]:
			check(int(res.winner) >= 0, "%s v %s: a knockout match has a winner" % [c[0], c[1]])
		var ts: Array = res.team_stats
		total_goals += int(g[0]) + int(g[1])
		total_sog += int(ts[0].sog) + int(ts[1].sog)
		for id in res.stats:
			total_saves += int(res.stats[id].saves)
			total_sa += int(res.stats[id].sa)
		print("match %s v %s: %d-%d, shots on goal %d-%d, all shots %d-%d, saves %d/%d, faceoffs %d-%d, penalties %d, calls %d" % [c[0], c[1], g[0], g[1],
			ts[0].sog, ts[1].sog, ts[0].shots, ts[1].shots, total_saves, total_sa, ts[0].fo, ts[1].fo, _count(res.log, "penalty"), (res.calls as Array).size()])
		n += 1
		m.queue_free()
		await frames(2)
	# Over 3 x 3-minute periods a real match's 60 minutes would bring ~10 goals: scaled, about 1.5 a match.
	check(total_sog > n * 4, "shots on goal are taken (%d in %d matches)" % [total_sog, n])
	# Saves of shots on goal (saves + goals): three in four in real matches; over three short matches it varies, so
	# the bounds are wide: a goalkeeper who saves everything or nothing is a bug (tests/ai_bench measures it closely).
	if quick:
		return
	check(total_sa > 0 and float(total_saves) / float(total_sa) > 0.45 and float(total_saves) / float(total_sa) < 0.985, "goalkeepers save most, not all, shots on goal (%d/%d)" % [total_saves, total_sa])
	check(total_saves < total_sa, "some shots on goal go in (%d saves of %d)" % [total_saves, total_sa])


func _count(log: Array, kind: String) -> int:
	var k := 0
	for e in log:
		if String(e.kind) == kind:
			k += 1
	return k
