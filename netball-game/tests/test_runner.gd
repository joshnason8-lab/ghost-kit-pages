extends Node
## The smoke test CI runs before building: every screen opens in every language; each rule the game plays is checked
## against the Rules of Netball (docs/RULES.md); the rules are seen at work in real matches (an offside called, a
## held ball, obstruction from closer than 0.9 m, the centre pass alternating); AI matches finish with real scores;
## extra time decides a knockout; nothing moves a player twice in a frame or faster than she can run; the cup plays
## to its medals and its save reads back. Headless:
##   godot --headless --path . --fixed-fps 30 res://tests/test_runner.tscn
## Exits 1 on any failure.

var failures := 0
var checks := 0


func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	var keep: Dictionary = Game.settings.duplicate(true)
	await _screens()
	_rules()
	_footwork()
	_sim()
	_cup()
	_league()
	await _matches()
	await _rules_in_play()
	await _motion()
	await _controls()
	await _league_options()
	await _sanctions_and_injury()
	await _break_screen()
	_tags()
	await _coach()
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


## Every screen, in every language: it opens and builds.
func _screens() -> void:
	var screens := ["res://ui/main_menu.gd", "res://ui/quick_setup.gd", "res://ui/settings_screen.gd", "res://ui/howto_screen.gd",
		"res://ui/records_screen.gd", "res://ui/cup_screen.gd", "res://ui/league_screen.gd", "res://ui/licences_screen.gd"]
	for pair in Game.LANGUAGES:
		Game.settings.language = pair[0]
		TranslationServer.set_locale(pair[0])
		Game._size_theme()
		check(tr("GAME_TITLE") != "GAME_TITLE", "%s: translations load" % pair[0])
		check(tr("BTN_PASS") != "BTN_PASS" and tr("BTN_PASS") != "", "%s: button labels" % pair[0])
		for path in screens:
			var s := Game.show_screen(path)
			await frames(3)
			check(is_instance_valid(s) and s.get_child_count() > 0, "%s: %s builds" % [pair[0], path])
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	Game._size_theme()


# ---------------------------------------------------------------- the rules, one by one

func _rules() -> void:
	# The court: 30.5 x 15.25 m in thirds, circles of 4.9 m, the centre circle 0.9 m across.
	check(is_equal_approx(Court.LENGTH, 30.5) and is_equal_approx(Court.WIDTH, 15.25), "court 30.5 x 15.25 m")
	check(is_equal_approx(Court.THIRD * 3.0, Court.LENGTH), "three equal thirds")
	check(is_equal_approx(Court.CIRCLE_R, 4.9) and is_equal_approx(Court.CENTRE_R * 2.0, 0.9), "goal circle 4.9 m, centre circle 0.9 m")
	check(is_equal_approx(Court.RING_H, 3.05) and is_equal_approx(Court.RING_R * 2.0, 0.38), "ring 3.05 m up, 380 mm across")
	check(Court.in_circle(Vector2(Court.HALF_L - 4.85, 0), 1) and not Court.in_circle(Vector2(Court.HALF_L - 5.0, 0), 1), "the circle's edge at 4.9 m")
	check(Court.in_circle(Vector2(Court.HALF_L - 3.0, 3.8), 1), "inside the circle, off to the side")
	# Positions and areas (R3, R14): each position's areas, and offside for a step outside them.
	var d := 1
	var att_circle := Vector2(Court.HALF_L - 2.0, 0)
	var att_third := Vector2(Court.HALF_L - 7.0, 6.0)
	var centre := Vector2(0, 3)
	var def_third := Vector2(-Court.HALF_L + 7.0, -6.0)
	var def_circle := Vector2(-Court.HALF_L + 2.0, 0)
	var spots := [att_circle, att_third, centre, def_third, def_circle]
	var want := {"GS": [1, 1, 0, 0, 0], "GA": [1, 1, 1, 0, 0], "WA": [0, 1, 1, 0, 0], "C": [0, 1, 1, 1, 0],
		"WD": [0, 0, 1, 1, 0], "GD": [0, 0, 1, 1, 1], "GK": [0, 0, 0, 1, 1]}
	for pos in want:
		for i in 5:
			var ok := not Rules.offside(pos, spots[i], d)
			check(ok == (want[pos][i] == 1), "%s %s area %d" % [pos, "may enter" if want[pos][i] == 1 else "is offside in", 5 - i])
	# On the line is fine (R14, 2024): a player touching her own area's line, not over it, is onside.
	check(not Rules.offside("GS", Vector2(Court.THIRD_X, 0), d), "GS on the transverse line: onside (on the line is fine)")
	check(Rules.offside("GS", Vector2(Court.THIRD_X - 0.1, 0), d), "GS over the transverse line, in the centre third: offside")
	check(not Rules.offside("GA", Vector2(Court.THIRD_X, 0), d), "GA on the transverse line: fine")
	check(not Rules.offside("WA", Vector2(Court.HALF_L - Court.CIRCLE_R, 0), d), "WA on the circle's line: onside")
	check(Rules.offside("WA", Vector2(Court.HALF_L - Court.CIRCLE_R + 0.15, 0), d), "WA inside the circle: offside")
	check(not Rules.offside("GK", Vector2(-Court.THIRD_X, 0), d) and Rules.offside("GK", Vector2(-Court.THIRD_X + 0.1, 0), d), "GK up to her transverse line, not over it")
	check(not Rules.offside("C", Vector2(Court.HALF_L + 0.5, 3), d), "off the court is not an area (a throw-in)")
	# Every position kept onside by the AI's helper lands in her areas.
	for pos in want:
		for p in [Vector2(14, 0), Vector2(-14, 0), Vector2(0, 0), Vector2(11, 6), Vector2(-11, -6)]:
			check(not Rules.offside(pos, Rules.onside_point(pos, p, d, 0.25), d), "onside_point keeps %s onside from %s" % [pos, p])
	# The centre pass (R8): alternating whoever scored.
	check(Rules.centre_pass_team(0, 0) == 0 and Rules.centre_pass_team(0, 1) == 1 and Rules.centre_pass_team(0, 2) == 0, "centre passes alternate")
	check(Rules.centre_pass_team(1, 0) == 1 and Rules.centre_pass_team(1, 5) == 0, "from whoever took the first")
	var cp_spots := {"C": Vector2(0.1, 0), "GS": Vector2(12, 0), "GA": Vector2(5.6, 2), "WA": Vector2(5.6, -4), "WD": Vector2(-5.6, 3),
		"GD": Vector2(-5.6, -2), "GK": Vector2(-12, 0)}
	check(Rules.centre_setup_faults(0, 0, cp_spots, 1).is_empty(), "a correct centre pass line-up")
	cp_spots.WA = Vector2(4.0, -4)
	check(Rules.centre_setup_faults(0, 0, cp_spots, 1) == ["WA"], "WA in the centre third before the whistle: breaking")
	cp_spots.WA = Vector2(5.6, -4)
	cp_spots.C = Vector2(0.6, 0)
	check(Rules.centre_setup_faults(0, 0, cp_spots, 1) == ["C"], "the C taking the pass outside the centre circle")
	check(Rules.centre_setup_faults(1, 0, {"C": Vector2(2, 2)}, -1).is_empty(), "the other C anywhere in the centre third")
	check(Rules.centre_pass_ok("WA", Vector2(3, 2)) and Rules.centre_pass_ok("GA", Vector2(-4, 0)), "the centre pass caught in the centre third")
	check(not Rules.centre_pass_ok("WA", Vector2(6, 2)), "caught beyond the centre third: a free pass")
	check(not Rules.centre_pass_ok("GS", Vector2(1, 0)) and not Rules.centre_pass_ok("GK", Vector2(1, 0)), "GS and GK may not take it")
	check(not Rules.centre_pass_ok("WD", Vector2(Court.THIRD_X, 0)), "a foot on the transverse line is not wholly in the centre third")
	# Playing the ball (and R12, short pass).
	check(not Rules.held_ball(2.9) and Rules.held_ball(3.05), "three seconds: held ball after them")
	check(Rules.short_pass(Vector2(0, 0), Vector2(0.6, 0)) and not Rules.short_pass(Vector2(0, 0), Vector2(1.5, 0)), "short pass: room for an opponent")
	check(Rules.over_third(-8.0, 8.0) and not Rules.over_third(-8.0, 2.0) and not Rules.over_third(-2.0, 8.0), "over a third")
	check(Rules.replayed_ball(3, 3, false) and not Rules.replayed_ball(3, 3, true) and not Rules.replayed_ball(3, 4, false), "replayed ball")
	# Obstruction (R13): 0.9 m from the landing foot, and only when defending.
	check(Rules.obstruction(Vector2.ZERO, Vector2(0.8, 0), true), "defending from 0.8 m: obstruction")
	check(not Rules.obstruction(Vector2.ZERO, Vector2(0.95, 0), true), "defending from 0.95 m: fine")
	check(not Rules.obstruction(Vector2.ZERO, Vector2(0.5, 0), false), "standing close with arms down: fine")
	check(Rules.obstruction(Vector2.ZERO, Vector2(1.0, 0), true, true), "leaping toward her: obstruction")
	# Contact (R16): penalised when it affects play.
	check(Rules.contact(0.6, true) and not Rules.contact(0.6, false) and not Rules.contact(0.05, true), "contact that affects play")
	# Scoring (R9).
	check(Rules.may_shoot("GS", att_circle, d) and Rules.may_shoot("GA", att_circle, d), "GS and GA shoot from the circle")
	check(not Rules.may_shoot("WA", att_circle, d) and not Rules.may_shoot("C", att_circle, d), "nobody else may")
	check(not Rules.may_shoot("GS", att_third, d), "not from outside the circle")
	check(Rules.may_shoot("GS", Vector2(Court.HALF_L - Court.CIRCLE_R, 0), d), "from the circle's line")
	check(not Rules.may_shoot("GS", att_circle, d, true), "a free pass in the circle may not be shot")
	check(Rules.goal_value(att_circle, d, false, 10.0) == 1, "every goal is one under the World Netball rules")
	check(Rules.goal_value(Vector2(Court.HALF_L - 3.5, 0), d, true, 200.0) == 2, "the Double Zone: two from 3.5 m in the last five minutes")
	check(Rules.goal_value(Vector2(Court.HALF_L - 2.0, 0), d, true, 200.0) == 1, "the Double Zone: one from 2 m")
	check(Rules.goal_value(Vector2(Court.HALF_L - 3.5, 0), d, true, 400.0) == 1, "the Double Zone: one before the last five minutes")
	check(Rules.goal_counts(true, true) and not Rules.goal_counts(false, true), "a shot released before the whistle counts")
	# Awards.
	var a := Rules.award("obstruction", 1, Vector2(Court.HALF_L - 3.0, 0), "GS", 1)
	check(a.to == 0 and a.kind == Rules.PENALTY and a.shot, "obstruction in the circle: penalty pass or shot")
	a = Rules.award("contact", 1, Vector2(0, 0), "GS", 1)
	check(a.kind == Rules.PENALTY and not a.shot, "contact outside the circle: penalty pass")
	a = Rules.award("footwork", 0, Vector2(Court.HALF_L - 3.0, 0), "GS", -1)
	check(a.to == 1 and a.kind == Rules.FREE and not a.shot, "footwork: a free pass, never a shot")
	for k in ["offside", "breaking", "held_ball", "short_pass", "over_third", "replayed_ball", "centre_pass_fault"]:
		check(Rules.INFRINGEMENTS[k] == Rules.FREE, "%s: free pass" % k)
	for k in ["obstruction", "contact", "intimidation"]:
		check(Rules.INFRINGEMENTS[k] == Rules.PENALTY, "%s: penalty pass" % k)
	var s := Rules.simultaneous(1, Vector2(2, 2))
	check(s.to == 1, "simultaneous infringement (2024): the team last in possession keeps it, no toss-up")
	check(Rules.simultaneous(0, Vector2(Court.HALF_L - 2.0, 0), 1).shot, "in its attacking circle, its GS or GA may shoot")
	var ti := Rules.throw_in(0, Vector2(4.0, Court.HALF_W))
	check(ti.to == 1 and ti.kind == Rules.THROW_IN, "out of court: a throw-in to the side that did not touch it last")
	var spot := Rules.throw_in_spot(Vector2(4.0, Court.HALF_W))
	check(spot.y > Court.HALF_W and spot.y - Court.HALF_W <= 0.15, "the thrower outside, within 15 cm of the line")
	check(Rules.takers(Vector2(Court.HALF_L - 2.0, 0), 1) == ["GS", "GA"], "a pass in the attacking circle: GS or GA takes it")
	check(Rules.takers(Vector2(0, 0), 1) == ["GA", "WA", "C", "WD", "GD"], "in the centre third: all but GS and GK")
	# Time: quarters, intervals, ends, extra time.
	check(Rules.period_length(1, 15.0) == 900.0, "quarters of 15 minutes")
	check(Rules.interval_after(1) == 4.0 and Rules.interval_after(2) == 12.0 and Rules.interval_after(3) == 4.0, "intervals of 4, 12 and 4 minutes")
	check(Rules.interval_after(2, true) == 8.0, "half-time of 8 by agreement")
	check(Rules.period_length(5, 15.0) == 420.0 and Rules.interval_after(5) == 1.0, "extra time: halves of 7 minutes, a minute between")
	for qn in range(1, 6):
		check(Rules.ends_for_quarter(0, qn, 1) == -Rules.ends_for_quarter(0, qn + 1, 1), "ends change after period %d" % qn)
		check(Rules.ends_for_quarter(0, qn, 1) == -Rules.ends_for_quarter(1, qn, 1), "the teams attack opposite ends")
	check(Rules.next_period(4, [50, 48], true) == 0, "a winner at full time: over")
	check(Rules.next_period(4, [50, 50], false) == 0, "level, no winner needed: a draw")
	check(Rules.next_period(4, [50, 50], true) == 5 and Rules.next_period(5, [55, 54], true) == 6, "level in a knockout: two halves of extra time")
	check(Rules.next_period(6, [58, 58], true) == 7, "still level: play on")
	check(not Rules.match_over(7, false, [59, 58], true) and Rules.match_over(7, false, [60, 58], true), "until a team leads by two")
	check(Rules.enough_players(5) and not Rules.enough_players(4), "five players at least")
	# Game management (R18): advance up to half a third, into the circle only from the goal third; escalate.
	var adv := Rules.advance(Vector2(0.0, 2.0), 1)
	check(is_equal_approx(adv.x, Court.THIRD * 0.5), "advance: half a third toward the goal attacked")
	check(not Court.in_circle(Rules.advance(Vector2(Court.THIRD_X - 0.5, 0), 1), 1), "advanced from the centre third: not into the circle")
	check(Court.in_circle(Rules.advance(Vector2(Court.HALF_L - 6.0, 0), 1), 1), "advanced within the goal third: may go into the circle")
	var esc := Rules.escalate(Rules.award("held_ball", 1, Vector2(Court.HALF_L - 2.0, 0), "GS", 1), 1)
	check(esc.kind == Rules.PENALTY and esc.shot, "escalate: a free pass in the circle becomes a penalty pass or shot")
	check(is_equal_approx(Rules.SUSPENSION, 120.0) and is_equal_approx(Rules.INJURY_STOP, 30.0), "suspension 2 min, injury stoppage 30 s")
	check(Rules.double_zone_live(299.0, 15.0) and not Rules.double_zone_live(301.0, 15.0), "the Double Zone's last five minutes")


## Footwork: the landing foot.
func _footwork() -> void:
	var f := Rules.Footwork.new()
	f.land("l")
	f.lift("r")
	f.ground("r")
	check(f.fault == "", "stepping with the other foot: fine")
	f.lift("l")
	check(f.fault == "", "lifting the landing foot to pass: fine")
	f.ground("l")
	check(f.fault == "footwork", "regrounding the landing foot: footwork")
	f = Rules.Footwork.new()
	f.land("both")
	f.lift("r")
	check(f.landing == "l" and f.fault == "", "landing on both: the first foot moved makes the other the landing foot")
	f = Rules.Footwork.new()
	f.land("r")
	f.drag("r")
	check(f.fault == "footwork", "dragging the landing foot: footwork")
	f = Rules.Footwork.new()
	f.land("l")
	f.hop("l")
	check(f.fault == "footwork", "a hop: footwork")


## Matches played out in numbers: real scores.
func _sim() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var tot := 0
	var n := 40
	for i in n:
		var r := Sim.play("ENG", "JAM", false, rng)
		tot += int(r.score[0]) + int(r.score[1])
	var avg := float(tot) / n / 2.0
	check(avg > 45.0 and avg < 65.0, "about 55 goals a team between equals (%.1f)" % avg)
	var big := Sim.play("AUS", "NAM", false, rng)
	check(int(big.score[0]) - int(big.score[1]) > 25, "a mismatch is a rout (%s)" % [big.score])
	for i in 30:
		var k := Sim.play("ENG", "ENG", true, rng)
		check(int(k.score[0]) != int(k.score[1]), "a knockout always has a winner")


## The Nations Cup: pools, semi-finals, the bronze match and the final.
func _cup() -> void:
	for home in ["ENG", "NAM", "AUS"]:
		var c: Cup = Game.new_cup(home)
		check(c.teams.size() == 8 and home in c.teams, "%s: eight nations, yours among them" % home)
		check(c.pools[0].size() == 4 and c.pools[1].size() == 4, "two pools of four")
		var guard := 0
		while c.stage != "done" and guard < 20:
			c.sim_next()
			guard += 1
		check(c.stage == "done", "%s: the cup finishes" % home)
		check(String(c.medals.get("gold", "")) != "" and String(c.medals.get("bronze", "")) != "" and c.medals.gold != c.medals.silver, "gold, silver and bronze")
		for p in 2:
			var t := c.pool_table(p)
			var pts := 0
			for r in t:
				pts += int(r.pts)
				check(int(r.p) == 3, "each team plays the other three in its pool")
			check(pts == 12, "two points a match shared out (%d)" % pts)
			check(int(t[0].pts) >= int(t[1].pts), "the table in order")
		Game.save_cup()
		Game.cup = null
		var back = Game.get_cup()
		check(back != null and back.medals.gold == c.medals.gold, "the cup saves and loads")
	Game.delete_cup()


# ---------------------------------------------------------------- real matches

func _play(cfg: Dictionary) -> Dictionary:
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = cfg
	add_child(m)
	var res: Dictionary = await m.finished
	m.queue_free()
	await frames(2)
	return res


## AI v AI matches, quarters shortened: they finish, both sides score at a real rate, the centre pass alternates.
func _matches() -> void:
	var cases := [["AUS", "NZL", "arena"], ["RSA", "MWI", "outdoor"], ["SGP", "SRI", "hall"]]
	var all_shots := 0
	var all_goals := 0
	for c in cases:
		var res := await _play({"home": c[0], "away": c[1], "venue": c[2], "user_team": -1, "demo": true, "seed": 11,
			"quarter_s": 75.0, "quarter": 15, "mode": "quick"})
		var sc: Array = res.score
		check(int(sc[0]) + int(sc[1]) > 3, "%s v %s: goals scored (%s)" % [c[0], c[1], sc])
		check(int(res.periods) == 4, "%s v %s: four quarters" % [c[0], c[1]])
		check((res.q_scores as Array).size() == 4, "a score for each quarter")
		var shots := 0
		var goals := 0
		for id in res.stats:
			shots += int(res.stats[id].attempts)
			goals += int(res.stats[id].goals)
			if int(res.stats[id].goals) > 0:
				check(String(res.stats[id].pos) in ["GS", "GA"], "only GS and GA score (%s)" % res.stats[id].pos)
		check(goals == int(sc[0]) + int(sc[1]), "the box score adds up to the score")
		all_shots += shots
		all_goals += goals
		var calls: Dictionary = res.calls
		check(calls.size() > 0, "%s v %s: the umpires call infringements (%s)" % [c[0], c[1], calls])
	var pct := float(all_goals) / maxf(1.0, float(all_shots))
	check(pct > 0.65 and pct < 0.95, "shooting at a real rate over three matches (%d%% of %d)" % [int(pct * 100), all_shots])
	check(all_goals >= 18, "goals at about a real rate (%d in three 5-minute matches)" % all_goals)
	# A knockout level at full time goes to extra time and ends with a winner.
	var ko := await _play({"home": "ENG", "away": "ENG", "venue": "arena", "user_team": -1, "demo": true, "seed": 3,
		"quarter_s": 30.0, "quarter": 15, "mode": "quick", "need_winner": true})
	check(int(ko.winner) >= 0, "a knockout has a winner (%s after %d periods)" % [ko.score, int(ko.periods)])


## The rules at work in a match: offside, held ball, obstruction within 0.9 m, the alternating centre pass.
func _rules_in_play() -> void:
	var m: Match = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "ENG", "away": "SCO", "venue": "hall", "user_team": -1, "demo": true, "seed": 21, "quarter": 15, "mode": "quick"}
	add_child(m)
	await frames(10)
	var t0 := Rules.centre_pass_team(m.cp_first, 0)
	check(m.restart.kind == Rules.CENTRE and int(m.restart.to) == t0, "the match starts with a centre pass to the toss winner")
	# Wait for live play.
	var guard := 0
	while m.phase != "live" and guard < 600:
		await frames(1)
		guard += 1
	check(m.phase == "live", "the centre pass whistle")
	check(m.cp_n == 1, "one centre pass taken")
	# Offside: put the GS into the centre third.
	var gs: Player = m.player_at(1 - t0, "GS")
	var events := []
	m.game_event.connect(func(k, info): events.append([k, info]))
	gs.p = Vector2(0, 2)
	gs.target = gs.p
	await frames(2)
	var off := events.filter(func(e): return e[0] == "call" and e[1].kind == "offside")
	check(not off.is_empty() and int(off[0][1].to) == t0, "offside called, a free pass to the other side")
	# Held ball: the taker holds on past three seconds.
	guard = 0
	while (m.phase != "live" or m.holder == null) and guard < 600:
		await frames(1)
		guard += 1
	var h: Player = m.holder
	if h:
		m.ai._decide[h] = 99.0
		m.hold_t = 2.95
		await frames(6)
		var held := events.filter(func(e): return e[0] == "call" and e[1].kind == "held_ball")
		check(not held.is_empty() and int(held[0][1].to) == 1 - h.team, "held ball after three seconds: free pass to the other side")
	# Obstruction: the defender of the next holder steps inside 0.9 m with arms up.
	guard = 0
	while (m.phase != "live" or m.holder == null) and guard < 600:
		await frames(1)
		guard += 1
	h = m.holder
	if h:
		m.ai._decide[h] = 99.0
		var dfd: Player = m.ai.marker_of(h)
		dfd.p = h.landing + Vector2(0.6, 0)
		m.ai.user_defend(dfd)
		await frames(2)
		var ob := events.filter(func(e): return e[0] == "call" and e[1].kind == "obstruction")
		check(not ob.is_empty() and String(ob[ob.size() - 1][1].award) == Rules.PENALTY, "obstruction from 0.6 m: penalty pass")
		# The penalised player stands out of play beside the thrower.
		guard = 0
		while m.phase != "setup" and guard < 200:
			await frames(1)
			guard += 1
		await frames(5)
		check(dfd.out_until > 0.0, "the penalised player is out of play until the pass")
	# Goals: after each, the centre pass goes to the other team from the one before.
	var cps := []
	m.game_event.connect(func(k, info):
		if k == "centre_setup":
			cps.append(int(info.team)))
	guard = 0
	while cps.size() < 4 and guard < 9000:
		await frames(1)
		guard += 1
	var alt := cps.size() >= 3
	for i in range(1, cps.size()):
		if cps[i] == cps[i - 1]:
			alt = false
	check(alt, "centre passes alternate after each goal (%s)" % [cps])
	m.queue_free()
	await frames(2)


## Movement (Kabaddi's motion audit): every player's position is written once a frame, never faster than she can
## run, and her strides keep pace with her speed.
func _motion() -> void:
	var m: Match = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "NZL", "away": "JAM", "venue": "arena", "user_team": -1, "demo": true, "seed": 8, "quarter": 15, "mode": "quick"}
	add_child(m)
	await frames(5)
	var last := {}
	var worst_jump := 0.0
	var twice := 0
	var stride_bad := 0
	for f in 900:
		await get_tree().process_frame
		var dt := 1.0 / 30.0
		for t in 2:
			for pl in m.players[t]:
				if pl.moves != 1:
					twice += 1
				if last.has(pl):
					var step: float = (pl.p - last[pl]).length()
					var cap: float = pl.speed_cap() * dt * 1.05 + 0.002
					if m.phase != "setup" or m.phase_t > 0.2:
						worst_jump = maxf(worst_jump, step - cap)
				last[pl] = pl.p
				var spd: float = pl.vel.length()
				if spd > 5.0 and pl.act == "run":
					var pair := lerpf(1.3, 2.9, clampf(spd / 7.0, 0.0, 1.0))
					if spd / pair > 3.0:
						stride_bad += 1
	check(twice == 0, "each player's position written once a frame (%d frames otherwise)" % twice)
	check(worst_jump <= 0.0001, "no player moves faster than she can run in a frame (worst over by %.3f m)" % worst_jump)
	check(stride_bad == 0, "strides keep pace with speed")
	m.queue_free()
	await frames(2)


## Your controls: a scripted thumb plays a match as the team. With the ball it picks a team-mate and passes (or
## shoots when it may); in defence it switches to the defender nearest the ball and runs at the ball. Nothing is
## played for you: a thumb that does nothing gets called for held ball.
func _controls() -> void:
	for mode in ["play", "idle"]:
		Game.settings.control = Game.CONTROL_TEAM
		var m: Match = (load("res://game/match.gd") as Script).new()
		m.config = {"home": "ENG", "away": "WAL", "venue": "hall", "user_team": 0, "seed": 4, "quarter": 15, "mode": "quick", "difficulty": 1}
		add_child(m)
		var passes := [0]
		var held := [0]
		m.game_event.connect(func(k, info):
			if k == "pass" and m.me and m.me.team == 0 and m.ai.last_passer and m.ai.last_passer.team == 0:
				passes[0] += 1
			if k == "call" and info.kind == "held_ball" and int(info.to) == 1:
				held[0] += 1)
		for f in 2700:
			await get_tree().process_frame
			if mode != "play" or m.phase != "live":
				continue
			var ids: Array = m.button_set()
			if f % 20 == 0 and m.me == m.holder:
				# A sensible thumb shoots from close, or when the three seconds are running out.
				var close: bool = m.me.landing.distance_to(Court.goal_post(m.me.dir)) < 3.2
				if "SHOOT" in ids and (close or m.hold_t > 1.6 or not "PASS" in ids):
					m._on_action("SHOOT")
				elif "PASS" in ids and m.hold_t > 0.5:
					m._on_action("PASS")
			elif m.holder and m.holder.team == 1:
				if f % 45 == 0:
					m._on_action("SWITCH")
				m.controls.joystick = Vector2.ZERO
		if mode == "play":
			check(passes[0] > 4, "your passes are thrown when you press PASS (%d)" % passes[0])
			check(int(m.score[0]) > 0, "your team scores with your passes and shots (%s)" % [m.score])
			check(held[0] <= 2, "a thumb that passes is rarely called for held ball (%d)" % held[0])
		else:
			check(held[0] >= 1, "nothing is played for you: an idle thumb is called for held ball (%d)" % held[0])
		m.queue_free()
		await frames(2)


## The league options: time-outs (90 s, time held, after a goal, two a half) and the Double Zone's two-point goal.
func _league_options() -> void:
	var m: Match = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "AUS", "away": "NZL", "venue": "arena", "user_team": -1, "demo": true, "seed": 2, "quarter": 15,
		"mode": "quick", "timeouts": true, "double_zone": true}
	add_child(m)
	await frames(5)
	check(m.timeouts == [2, 2], "two time-outs a team each half")
	check(not m.can_timeout(0) or m.phase == "setup", "a time-out only after a goal, before the centre pass")
	var guard := 0
	while m.phase != "goal" and guard < 6000:
		await frames(1)
		guard += 1
	if m.phase == "goal":
		var t0: float = m.time_left
		m.call_timeout(0)
		check(m.phase == "timeout" and m.timeouts[0] == 1, "a time-out called after a goal")
		await frames(10)
		check(is_equal_approx(m.time_left, t0), "time is held through a time-out")
	m.queue_free()
	await frames(2)


## Game management (R6) and stoppages (R10): a warning, then a two-minute suspension of playing time (off the court,
## the team a player short, back after it); an injury stoppage holds time.
func _sanctions_and_injury() -> void:
	var m: Match = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "JAM", "away": "TTO", "venue": "outdoor", "user_team": -1, "demo": true, "seed": 6, "quarter": 15,
		"mode": "quick", "no_injuries": true}
	add_child(m)
	var guard := 0
	while m.phase != "live" and guard < 600:
		await frames(1)
		guard += 1
	var pl: Player = m.player_at(0, "GD")
	for i in Match.WARN_AT:
		m._sanction(pl, "contact")
	check(pl.warned and pl.suspended == 0.0, "a warning after repeated penalties")
	for i in Match.SUSPEND_AT:
		m._sanction(pl, "obstruction")
	check(is_equal_approx(pl.suspended, Rules.SUSPENSION), "then a suspension of two minutes")
	m._sanction(m.player_at(0, "WA"), "footwork")
	check(not m.player_at(0, "WA").warned, "free-pass infringements are not sanctioned")
	await frames(240)
	check(not Court.on_court(pl.p), "the suspended player is off the court (%s)" % pl.p)
	var left := pl.suspended
	check(left < Rules.SUSPENSION and left > Rules.SUSPENSION - 9.0, "her suspension runs on playing time (%.1f left)" % left)
	pl.suspended = 0.2
	await frames(300)
	check(pl.suspended == 0.0 and Court.on_court(pl.p) and not Rules.offside(pl.pos, pl.p, pl.dir), "she comes back on to her own area")
	# Suspended a second time: ordered off; after four minutes of playing time a replacement may come on.
	var was_id := String(pl.data.id)
	for i in Match.SUSPEND_AT:
		m._sanction(pl, "contact")
	check(pl.ordered_off and is_equal_approx(pl.suspended, Rules.ORDERED_OFF_REPLACE), "suspended twice: ordered off, four minutes before a replacement")
	pl.suspended = 0.05
	await frames(10)
	check(not pl.ordered_off and String(pl.data.id) != was_id, "after four minutes a replacement comes on from the bench")
	# An injury stoppage.
	guard = 0
	while m.phase != "live" and guard < 600:
		await frames(1)
		guard += 1
	var dfd: Player = m.player_at(1, "GK")
	m._award(Rules.award("contact", 1, dfd.p, "GS", m.team_dir(0)), dfd, "contact")
	m._stop_award.injured = m.player_at(0, "GS")
	await frames(40)
	check(m.phase == "injury", "an injury stoppage after the call (%s)" % m.phase)
	var t0: float = m.time_left
	await frames(30)
	check(is_equal_approx(m.time_left, t0), "time is held for the injury")
	await frames(90)
	check(m.phase == "setup" or m.phase == "live", "play restarts with the award after the stoppage (%s)" % m.phase)
	m.queue_free()
	await frames(2)


## The interval screen (playtest: it was half empty, and a change button did not say who would come on): the teams'
## figures beside the score, and each change button naming the player who would come on.
func _break_screen() -> void:
	var m: Match = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "ENG", "away": "WAL", "venue": "hall", "user_team": 0, "seed": 5, "quarter": 15, "mode": "quick"}
	add_child(m)
	await frames(5)
	m.hud.show_break(1, 2)
	await frames(2)
	var texts := []
	var buttons := []
	var stack: Array = [m.hud._break]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Label:
			texts.append(n.text)
		elif n is Button:
			buttons.append(n)
	check(tr("BOX_FEEDS").to_upper() in texts and tr("BOX_GAINS").to_upper() in texts, "the interval shows the teams' figures")
	var gs: Player = m.player_at(0, "GS")
	var b: Button = null
	for x in buttons:
		if x.text.begins_with("GS "):
			b = x
	var coming := String(m.bench[0][m.next_on(gs)].name) if m.next_on(gs) >= 0 else ""
	check(b != null and coming != "" and b.text.ends_with(coming), "a change button names who would come on (%s)" % (b.text if b else "none"))
	if b:
		b.pressed.emit()
		check(String(gs.data.name) == coming, "tapping it brings her on")
	m.queue_free()
	await frames(2)


## Name tags over players standing together are stacked, not printed over each other (playtest: "GSK", "GD/D").
func _tags() -> void:
	var rs := [Rect2(100, 200, 40, 22), Rect2(110, 205, 40, 22), Rect2(300, 200, 40, 22), Rect2(105, 190, 40, 22)]
	var out: Array = HUD.declutter(rs)
	var overlap := 0
	for i in out.size():
		for j in range(i + 1, out.size()):
			if (out[i] as Rect2).grow(-1.0).intersects(out[j]):
				overlap += 1
	check(overlap == 0, "name tags never overlap (%d pairs did)" % overlap)
	check(out[2] == rs[2] and out[1] == rs[1], "a tag alone, and the one nearest the camera, stay where they are")


## The coach (playtest: a first-timer scored nothing and did not know the rings or buttons): each tip when it is
## needed, once; on for a first match, off after it.
func _coach() -> void:
	check(Coach.pick({}, {}) == "move", "the first tip is how to move")
	check(Coach.pick({"me_has_ball": true}, {"move": true}) == "pass", "with the ball: how to pass")
	check(Coach.pick({"me_has_ball": true, "may_shoot": true}, {"move": true, "pass": true}) == "shoot", "in the circle: how to shoot")
	check(Coach.pick({"they_have_ball": true}, {"move": true}) == "defend", "their ball: how to defend")
	check(Coach.pick({"they_have_ball": true}, {"move": true, "defend": true}) == "", "a tip is shown only once")
	for k in Coach.ORDER:
		var t := Coach.text(k)
		check(t != "COACH_" + k.to_upper() and not t.contains("{"), "the %s tip reads (%s)" % [k, t.left(30)])
	var was := Game.settings.duplicate()
	Game.settings.coach = true
	Game.settings.coached = false
	var m: Match = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "ENG", "away": "WAL", "venue": "hall", "user_team": 0, "seed": 6, "quarter": 15, "mode": "quick", "difficulty": 1}
	add_child(m)
	await frames(90)
	check(m.hud.coach != null and m.hud.coach.seen.has("move"), "a first match has the coach, and she starts with moving")
	m.time_left = 0.01
	m.q = 4
	var guard := 0
	while m.phase != "over" and guard < 900:
		if m.phase == "break":
			m.skip_break()
		await frames(1)
		guard += 1
	check(m.phase == "over" and not Game.settings.coach and Game.settings.coached, "after the first match the tips turn off")
	m.queue_free()
	await frames(2)
	Game.settings = was
	var demo: Match = (load("res://game/match.gd") as Script).new()
	demo.config = {"home": "ENG", "away": "WAL", "venue": "hall", "user_team": -1, "demo": true, "seed": 6, "quarter": 15, "mode": "quick"}
	add_child(demo)
	await frames(3)
	check(demo.hud.coach == null, "no coach when the AI plays itself")
	demo.queue_free()
	await frames(2)


## The Club Season: eight invented clubs, each plays the others once, the top four to the finals, a grand final.
func _league() -> void:
	var clubs: Array = DB.club_ids()
	check(clubs.size() == 8 and DB.team_ids().size() == DB.NATIONS.size(), "eight clubs, kept apart from the nations")
	for id in clubs:
		check(DB.squad(id).size() == 12 and DB.team(id).has("country"), "%s: a squad of twelve and a home country" % id)
	var l: League = Game.new_league("SKF")
	check(l.fixtures.size() == 28, "every club plays every other once (%d matches)" % l.fixtures.size())
	var pairs := {}
	for r in League.ROUNDS:
		var seen := {}
		for f in l.fixtures:
			if int(f.round) == r:
				seen[f.home] = true
				seen[f.away] = true
				var key := [f.home, f.away]
				key.sort()
				pairs[str(key)] = true
		check(seen.size() == 8, "round %d: every club plays" % (r + 1))
	check(pairs.size() == 28, "no pairing twice")
	var homes := {}
	for f in l.fixtures:
		homes[f.home] = int(homes.get(f.home, 0)) + 1
	check(homes.values().max() <= 4 and homes.values().min() >= 3, "home matches shared out (%s)" % [homes.values()])
	var nm := l.next_user_match()
	check(nm.home == "SKF" or nm.away == "SKF", "your next match is your club's")
	var guard := 0
	while l.stage == "season" and guard < 20:
		l.sim_next()
		guard += 1
	var t := l.table()
	var pts := 0
	for r in t:
		pts += int(r.pts)
		check(int(r.p) == 7, "each club plays seven")
	check(pts == 56, "two points a match shared out (%d)" % pts)
	check(l.stage == "semis" and l.finals.size() == 2 and l.finals[0].home == t[0].id and l.finals[0].away == t[3].id
		and l.finals[1].home == t[1].id and l.finals[1].away == t[2].id, "first plays fourth, second plays third")
	var titles := int(Game.records.get("seasons_played", 0))
	while l.stage != "done" and guard < 40:
		l.sim_next()
		guard += 1
	check(l.stage == "done" and l.finals.size() == 3 and l.champion == l.finals[2].winner, "a grand final, and champions")
	check(int(Game.records.get("seasons_played", 0)) == titles + 1, "the season goes in the record book")
	Game.save_league()
	Game.league = null
	var back = Game.get_league()
	check(back != null and back.champion == l.champion and back.fixtures.size() == 28, "the season saves and loads")
	Game.delete_league()
