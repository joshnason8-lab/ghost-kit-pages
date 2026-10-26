extends Node
## The smoke test CI runs before building: every screen opens in every language; each rule the game plays is checked
## against the Rules of Netball (docs/RULES.md); the rules are seen at work in real matches (an offside called, a
## held ball, obstruction from closer than 0.9 m, the centre pass alternating); AI matches finish with real scores;
## extra time decides a knockout; nothing moves a player twice in a frame or faster than she can run; the cup plays
## to its medals and its save reads back; every sound the code asks for is there and loads, and is credited. Headless:
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
	await _mocap()
	await _controls()
	await _league_options()
	await _sanctions_and_injury()
	await _break_screen()
	await _cp_drive()
	await _goal_reset()
	await _front_mark()
	await _rebound_spots()
	await _umpire_goal_line()
	await _huddle()
	await _reserves()
	_tags()
	await _coach()
	await _navigation()
	await _crowd_facing()
	_sounds()
	await _sounds_in_play()
	await _low_unchanged()
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
	# The players are the owner's model (HeroBody), the umpires the code-built figure; a running player's legs come
	# from the Mixamo clips; her bib carries her position's letters.
	var pl0: Player = m.players[0][0]
	check(pl0.body is HeroBody and pl0.body.skeleton.get_bone_count() == ToonBody.BONES.size(), "a player is drawn with the owner's model, on the game's bones")
	check(not (m.umpires[0].body is HeroBody), "an umpire keeps the code-built figure")
	var mat: ShaderMaterial = pl0.body.mesh_instance.material_override
	check(mat.get_shader_parameter("letter") == ToonBody.LETTERS.find(pl0.pos) and mat.get_shader_parameter("letters") != null, "her bib carries her position's letters (%s)" % pl0.pos)
	var ran := false
	for f in 300:
		await get_tree().process_frame
		for t in 2:
			for pl in m.players[t]:
				if pl.act == "run" and pl.vel.length() > 4.5 and pl.clip_body > 0.8 and pl.body.pose.get("thigh_l") is Quaternion:
					ran = true
		if ran:
			break
	check(ran, "a player running at speed takes her legs from the run clips")
	var lf := HeroBody.stride_pose("Fast_Run", 0.25)
	var lt: Vector3 = (lf[0][ToonBody.BONES.map(func(b): return b[0]).find("thigh_l")] as Quaternion) * Vector3.DOWN
	check(lt.z > 0.25, "the sprint clip: the left thigh forward at the stride's phase 1/4 (%.2f)" % lt.z)
	m.queue_free()
	await frames(2)


## The motion capture (assets/player/mocap.json, tools/player/cmu_bvh.py): every clip loads on the game's bones, and
## as the match plays them a planted foot stays put. The limit is 2 cm over a planted phase: under a sole's grip on a
## court, about a third of a shoe's width, and less than a pixel at the match camera's distance; a foot that skates
## shows at 5 cm and up.
const PLANT_SLIDE := 0.02


func _mocap() -> void:
	var names := ["slide_left", "slide_right", "land_l", "land_r"]
	for nm in names:
		var c := HeroBody.mocap(nm)
		var fr: Array = c.frames
		check(fr.size() >= 10 and (fr[0] as Array).size() == ToonBody.BONES.size() + 1 and fr[0][0] is Quaternion,
			"motion capture %s loads: %d frames on the game's %d bones" % [nm, fr.size(), ToonBody.BONES.size()])
		check(String(c.plant).length() == fr.size() and is_equal_approx(float(c.fps), 30.0), "%s: 30 fps, its planted feet marked" % nm)
	var sq: Array = DB.squad("NZL")
	# The side-step: a marker going sideways (her right, then her left) at 3 m/s, eyes on the ball ahead.
	for side: float in [-1.0, 1.0]:
		var pl := Player.new(0, sq[5], "GD")
		add_child(pl)
		await frames(1)
		pl.fenced = false
		pl.place(Vector2.ZERO, 0.0)
		var drive := func(_f: int) -> void:
			pl.set_act("mark")
			pl.look_on = true
			pl.look_at_p = pl.p + Vector2(0, 8)
			pl.target = pl.p + Vector2(side * 5.0, 0)
			pl.want_speed = 3.0
		var planted := func() -> String:
			if pl.slide < 0.97:
				return ""
			var nm := "slide_left" if pl.slide_side > 0.0 else "slide_right"
			var plant: String = HeroBody.mocap(nm).plant
			return plant[int(pl.slide_phase * (plant.length() - 1) + 0.5) % (plant.length() - 1)]
		var worst := _plant_slide(pl, drive, planted, 90)
		check(pl.slide > 0.97, "a marker going sideways side-steps (%.2f of the slide)" % pl.slide)
		check(worst < PLANT_SLIDE, "the side-step to her %s: planted feet move %.1f cm at most" % ["left" if side > 0 else "right", worst * 100.0])
		pl.queue_free()
	# The landing: caught at a jog and at a sprint, on either foot; the landing foot stays where it came down.
	for case: Array in [[3.5, "l"], [6.5, "r"], [5.0, "l"]]:
		var pl := Player.new(0, sq[2], "WA")
		add_child(pl)
		await frames(1)
		pl.fenced = false
		pl.place(Vector2.ZERO, 0.0)
		var spd: float = case[0]
		var foot: String = case[1]
		pl.vel = Vector2(0, spd)
		var landed := [Vector2.INF]
		var drive := func(f: int) -> void:
			if f < 20:
				pl.set_act("run")
				pl.target = pl.p + Vector2(0, 8)
				pl.want_speed = spd
			elif f == 20:
				pl.stopped = true
				pl.set_act("hold")
				pl.start_landing(foot)
				landed[0] = pl.landing
		var planted := func() -> String:
			if pl.land_clip == "" or pl.land_w < 0.97:
				return ""
			var c := HeroBody.mocap(pl.land_clip)
			var plant: String = c.plant
			var t := HeroBody.mocap_time_at(pl.land_clip, pl.land_d)
			var ch := plant[mini(int(t * float(c.fps) + 0.5), plant.length() - 1)]
			# Only the landing foot is held to the line: the other may step.
			return foot if ch == foot or ch == "b" else ""
		var worst := _plant_slide(pl, drive, planted, 60)
		check(worst < PLANT_SLIDE, "a landing on the %s foot from %.1f m/s: the landing foot moves %.1f cm at most" % [foot, spd, worst * 100.0])
		var ankle := pl.body.bone_world("foot_" + foot)
		check(Vector2(ankle.x, ankle.z).distance_to(landed[0]) < 0.3, "she comes down on her landing spot (%.2f m off)" % Vector2(ankle.x, ankle.z).distance_to(landed[0]))
		check(pl.vel.length() < 0.05 and pl.land_clip != "", "she stops on the landing (%.2f m/s)" % pl.vel.length())
		pl.queue_free()
	await frames(1)


## Runs a player frame by frame (drive(f) sets what she does, then she advances 1/30 s): for each frame, planted()
## names her planted feet ("l", "r", "b" or ""); returns the furthest a foot moved over the floor in one planted run.
func _plant_slide(pl: Player, drive: Callable, planted: Callable, n: int) -> float:
	var start := {}
	var worst := 0.0
	for f in n:
		drive.call(f)
		pl.advance(1.0 / 30.0)
		var ch: String = planted.call()
		for s in ["l", "r"]:
			var down: bool = ch == s or ch == "b"
			var w := pl.body.bone_world("foot_" + s)
			var at := Vector2(w.x, w.z)
			if down:
				if not start.has(s):
					start[s] = at
				worst = maxf(worst, at.distance_to(start[s]))
			else:
				start.erase(s)
	return worst


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


# ---------------------------------------------------------------- the match study (docs/MATCH_STUDY.md)

func _study_match(seed: int, cfg := {}) -> Match:
	var m: Match = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "AUS", "away": "NZL", "venue": "arena", "user_team": -1, "demo": true, "seed": seed, "quarter": 15,
		"mode": "quick", "no_injuries": true}
	m.config.merge(cfg, true)
	add_child(m)
	return m


func _wait_live(m: Match, limit := 600) -> void:
	var guard := 0
	while m.phase != "live" and guard < limit:
		await frames(1)
		guard += 1


## The centre pass: on the whistle the GA and WA drive flat out, straight into the centre third, away from their
## markers; and through play the GS holds (posts) by the post when the ball is in her goal third, arm out.
func _cp_drive() -> void:
	var m := _study_match(31)
	await _wait_live(m)
	var t := int(m.restart.to)
	var d := m.team_dir(t)
	var ok := true
	for pos in ["GA", "WA"]:
		var pl: Player = m.player_at(t, pos)
		var spot: Vector2 = m.ai.drive_spot(pl)
		ok = ok and m.ai._drive.has(pl) and absf(pl.lead_to.x) < Court.THIRD_X - 2.0 and pl.lead_to.x * d < pl.p.x * d - 1.5
		ok = ok and absf(spot.x - d * (Court.THIRD_X - 2.6)) < 0.05
		var mk: Player = m.ai.marker_of(pl)
		ok = ok and (spot.y - pl.p.y) * (pl.p.y - mk.p.y) >= 0.0   # across away from her marker
	check(ok, "the centre pass whistle: the GA and WA drive into the centre third, away from their markers")
	var ga0: Player = m.player_at(t, "GA")
	var flat: bool = ga0.want_speed == ga0.speed_cap() or m.pass_info.get("to") == ga0
	await frames(15)
	var fast := 0
	for pos in ["GA", "WA"]:
		var pl: Player = m.player_at(t, pos)
		if flat and pl.vel.length() > 3.0 and pl.vel.x * d < 0.0:
			fast += 1
	check(fast >= 1, "they go flat out (%d of 2 over 4 m/s toward the centre third)" % fast)
	# Through play: the GS posts (stands holding, arm out) when the ball is in her goal third.
	var posts := 0
	var deep := 0
	for f in 1800:
		await frames(1)
		if m.phase != "live":
			continue
		for tt in 2:
			var gs: Player = m.player_at(tt, "GS")
			if m.ball.court_pos().x * gs.dir > Court.THIRD_X and m.holder != null and m.holder.team == tt and gs != m.holder:
				deep += 1
				if gs.act == "post":
					posts += 1
	check(deep > 0 and posts > deep / 3, "the GS holds by the post while her team has the ball in her goal third (%d of %d frames)" % [posts, deep])
	m.queue_free()
	await frames(2)


## After a goal nobody sprints: everyone walks or jogs back to the next centre pass (the C taking it may hurry), and
## the whistle comes within a few seconds.
func _goal_reset() -> void:
	var m := _study_match(32)
	await _wait_live(m)
	await frames(20)
	var t := int(m.restart.to)
	var gs: Player = m.player_at(t, "GS")
	m.pass_info = {}
	m._release_holder()
	m._goal(gs, 1)
	var nxt := Rules.centre_pass_team(m.cp_first, m.cp_n)
	var taker: Player = m.player_at(nxt, "C")
	var fastest := 0.0
	var secs := 0.0
	while not (m.phase == "live" and m.cp_n == 2) and secs < 15.0:
		await frames(1)
		secs += 1.0 / 30.0
		if (m.phase == "goal" and m.phase_t > 1.0) or m.phase == "setup":
			for tt in 2:
				for pl in m.players[tt]:
					if pl != taker:
						fastest = maxf(fastest, pl.vel.length())
	check(fastest <= TeamAI.JOG + 0.05, "after a goal the players jog back (fastest %.1f m/s)" % fastest)
	check(m.phase == "live" and secs < 8.5, "the next centre pass is whistled within a few seconds (%.1f s)" % secs)
	m.queue_free()
	await frames(2)


## Circle defence: the GK and GD front the shooters (between ball and shooter) while the ball is outside the circle
## in their goal third, drop goal-side once it is on the circle's edge; the lower levels front less; off the ball
## the others shade toward the front of the circle. Feeders sit on the circle's edge.
func _front_mark() -> void:
	var m := _study_match(33)
	await frames(3)
	var a := 0
	var gs: Player = m.player_at(a, "GS")
	var gk: Player = m.player_at(1 - a, "GK")
	var post := Court.goal_post(gs.dir)
	gs.p = post + Vector2(-gs.dir * 2.0, 0.5)
	gs.vel = Vector2.ZERO
	var b_out := post + Vector2(-gs.dir * 7.5, 3.0)
	var s: Vector2 = m.ai.mark_spot(gk, gs, b_out)
	check(s.distance_to(b_out) < gs.p.distance_to(b_out) - 0.5, "ball outside the circle: the GK fronts the GS (%s)" % s)
	var b_edge := post + Vector2(-gs.dir * 5.2, 0.0)
	var s2: Vector2 = m.ai.mark_spot(gk, gs, b_edge)
	check(s2.distance_to(post) < gs.p.distance_to(post), "ball on the circle's edge: she drops goal-side (%s)" % s2)
	m.user_team = a
	m.config.difficulty = 0
	var s3: Vector2 = m.ai.mark_spot(gk, gs, b_out)
	check(s3.distance_to(b_out) > s.distance_to(b_out) + 0.2 and m.ai.front_weight(1 - a) < 0.5, "on the easiest level she fronts less")
	m.user_team = -1
	m.config.erase("difficulty")
	var wd: Player = m.player_at(1 - a, "WD")
	var wa: Player = m.player_at(a, "WA")
	wa.p = post + Vector2(-gs.dir * 9.0, 4.5)
	wa.vel = Vector2.ZERO
	var own := Court.goal_post(-wd.dir)
	var front := own + Vector2(wd.dir * (Court.CIRCLE_R + 1.2), 0.0)
	var plain := wa.p + (b_out - wa.p).normalized() * 0.7 + (own - wa.p).normalized() * 0.55
	var z: Vector2 = m.ai.mark_spot(wd, wa, b_out)
	check(z.distance_to(front) < plain.distance_to(front) - 0.5, "off the ball the WD shades toward the front of the circle")
	# Feeders: with the ball in the goal third, the WA's and C's spots are on the circle's edge, outside it.
	m.ball.dead(Vector3(b_out.x, 1.0, b_out.y))
	var feed_ok := true
	for pos in ["WA", "C"]:
		var pl: Player = m.player_at(a, pos)
		var at: Vector2 = m.ai._anchor(pl)
		var r := at.distance_to(post)
		feed_ok = feed_ok and r > Court.CIRCLE_R and r < Court.CIRCLE_R + 1.2 and not Rules.offside(pl.pos, at, pl.dir)
	check(feed_ok, "the WA and C feed from the circle's edge")
	m.queue_free()
	await frames(2)


## Rebounds: as a shot goes up the GS and GA turn to the post inside, either side of it; the GK and GD box out round
## them; the others hold.
func _rebound_spots() -> void:
	var m := _study_match(34)
	await _wait_live(m)
	var guard := 0
	while (m.holder == null or m.phase != "live") and guard < 300:
		await frames(1)
		guard += 1
	var a := m.holder.team
	var gs: Player = m.player_at(a, "GS")
	var post := Court.goal_post(gs.dir)
	var spots := {}
	var ok := true
	for t in 2:
		for pl in m.players[t]:
			var at: Vector2 = m.ai.rebound_spot(pl, gs)
			spots[pl] = at
			var key: String = ("A" if t == a else "D") + pl.pos
			if key in ["AGS", "AGA"]:
				ok = ok and absf(at.distance_to(post) - 0.9) < 0.05
			elif key in ["DGK", "DGD"]:
				ok = ok and absf(at.distance_to(post) - 1.8) < 0.05 and not Rules.offside(pl.pos, at, pl.dir)
			else:
				ok = ok and at == Vector2.INF
	var ga: Player = m.player_at(a, "GA")
	ok = ok and signf((spots[gs] as Vector2).y) != signf((spots[ga] as Vector2).y)
	ok = ok and signf((spots[m.player_at(1 - a, "GK")] as Vector2).y) == signf((spots[gs] as Vector2).y)
	check(ok, "rebound spots: GS and GA inside either side of the post, GK and GD outside them, the rest hold")
	# A shot that misses: everyone goes to it as it flies.
	m.pass_info = {}
	m._release_holder()
	gs.vel = Vector2.ZERO
	gs.p = post + Vector2(-gs.dir * 2.5, 0.3)
	m._give(gs, false)
	m.ai._decide[gs] = 99.0
	m.shoot()
	m.shot_info.goal = false
	var d0 := ga.p.distance_to(post)
	await frames(30)
	var targets := true
	for pos in ["GA"]:
		targets = targets and m.player_at(a, pos).target.distance_to(m.ai.rebound_spot(m.player_at(a, pos), gs)) < 0.05
	for pos in ["GK", "GD"]:
		var pl: Player = m.player_at(1 - a, pos)
		if pl != m.ai.marker_of(gs):
			targets = targets and pl.target.distance_to(m.ai.rebound_spot(pl, gs)) < 0.05
	check(m.shot_info.has("by") and targets, "during the shot they run to their rebound spots")
	check(d0 < 1.2 or ga.p.distance_to(post) < d0, "the GA closes on the post (%.1f m from %.1f)" % [ga.p.distance_to(post), d0])
	m.queue_free()
	await frames(2)


## The umpire: round the corner onto her goal line when the ball is in her circle (never across the court), back to
## her side line when it goes up the court; she jogs; she stands still to signal; a light teal shirt.
func _umpire_goal_line() -> void:
	var u := Umpire.new(1)
	add_child(u)
	await frames(1)
	var dt := 1.0 / 30.0
	u.p = Vector2(11.0, u.side * (Court.HALF_W + Umpire.LINE))
	var on_court := 0
	var fastest := 0.0
	var ball := Vector2(13.5, 1.0)
	for i in 300:
		u.follow(ball)
		u.advance(dt, ball)
		on_court += 1 if Court.on_court(u.p) else 0
		fastest = maxf(fastest, u.vel.length())
	check(fastest <= Umpire.JOG + 0.01, "she jogs to the goal line (%.1f m/s)" % fastest)
	check(u.at_end and u.p.distance_to(u.end_spot()) < 0.3 and absf(u.p.x) > Court.HALF_L + 0.5, "ball in her circle: the umpire on her goal line (%s)" % u.p)
	ball = Vector2(2.0, -1.0)
	for i in 400:
		u.follow(ball)
		u.advance(dt, ball)
		on_court += 1 if Court.on_court(u.p) else 0
		fastest = maxf(fastest, u.vel.length())
	check(not u.at_end and u.p.distance_to(Vector2(2.0, u.side * (Court.HALF_W + Umpire.LINE))) < 0.3, "ball up the court: back on her side line (%s)" % u.p)
	check(on_court == 0, "round the corner, never across the court (%d frames on it)" % on_court)
	check(fastest <= Umpire.SPEED + 0.01, "never faster than a run to catch up with play (%.1f m/s)" % fastest)
	ball = Vector2(13.5, 1.0)
	for i in 10:
		u.follow(ball)
		u.advance(dt, ball)
	var moving := u.vel.length()
	u.call_signal("contact", 1)
	for i in 20:
		u.follow(ball)
		u.advance(dt, ball)
	check(moving > 1.0 and u.sig != "" and u.vel.length() < 0.05, "she stops and stands still while she signals")
	var shirt: Color = u.body.look.dress
	check(shirt.g > shirt.r + 0.2 and shirt.b > shirt.r + 0.2 and shirt.v > 0.6, "a light teal shirt (%s)" % shirt.to_html(false))
	u.queue_free()
	await frames(1)


## A break: each team huddles by its bench, the seven in a tight ring facing in, the umpires in the middle; the
## interval screen comes up over it; after it, everyone is back on her spot for the centre pass.
func _huddle() -> void:
	var m := _study_match(35, {"user_team": 0, "demo": false})
	await frames(10)
	m._end_period()
	check(m.phase == "break" and m.hud._break == null, "the break: the teams walk to their huddles first")
	await frames(330)
	check(m.hud._break != null, "then the interval screen")
	var worst := 0.0
	var facing_in := true
	for t in 2:
		var c: Vector2 = TeamAI.huddle_centre(t)
		for pl in m.players[t]:
			worst = maxf(worst, pl.p.distance_to(m.ai.huddle_spot(pl)))
			var want := atan2(c.x - pl.p.x, c.y - pl.p.y)
			facing_in = facing_in and absf(angle_difference(pl.facing, want)) < 0.5 and pl.act == "huddle"
		check(c.distance_to(TeamAI.bench_spot(t)) < 1.5, "team %d's huddle is by its bench" % t)
	check(worst < 0.4, "each team in a tight ring at its huddle (worst %.2f m off)" % worst)
	check(facing_in, "facing in")
	var mid := true
	for u in m.umpires:
		mid = mid and u.p.distance_to(Vector2(u.half * 0.8, 0.0)) < 0.4
	check(mid, "the umpires in the middle")
	m.skip_break()
	await frames(3)
	var back := m.phase == "setup" and m.q == 2
	for t in 2:
		for pl in m.players[t]:
			back = back and Court.on_court(pl.p) and not Rules.offside(pl.pos, pl.p, pl.dir) and pl.act != "huddle"
			back = back and pl.fenced == (pl != m.me or bool(Game.settings.onside))
	check(back, "after the break everyone is on her spot for the centre pass")
	m.queue_free()
	await frames(2)


## The reserves stand in front of their benches on Medium and High; Low draws none (it stays as it was).
func _reserves() -> void:
	var was := int(Game.settings.graphics)
	for g in [Game.GFX_LOW, Game.GFX_HIGH]:
		Game.settings.graphics = g
		var m := _study_match(36)
		await frames(3)
		var r := m.get_node_or_null("Reserves")
		if g == Game.GFX_LOW:
			check(r == null, "Low: no reserves drawn")
		else:
			var n: int = m.bench[0].size() + m.bench[1].size()
			var by_bench := r != null and r.get_child_count() == n and n > 0
			if by_bench:
				for b in r.get_children():
					var p := Vector2(b.position.x, b.position.z)
					by_bench = by_bench and not Court.on_court(p) and p.distance_to(TeamAI.bench_spot(0 if p.x < 0.0 else 1)) < 3.0
			check(by_bench, "High: the %d reserves stand by their benches" % n)
		m.queue_free()
		await frames(2)
	Game.settings.graphics = was


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


## Pausing and going back (playtest: the pause button sat off screen; Esc did nothing in a browser; Back with the
## language list open quit the game).
func _navigation() -> void:
	Game.show_screen("res://ui/settings_screen.gd")
	await frames(3)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await frames(3)
	check(String(Game.current.get_script().resource_path).ends_with("main_menu.gd"), "Esc goes back (settings to home)")
	var menu = Game.current
	menu._open_language()
	await frames(3)
	Game.go_back()
	await frames(3)
	check(Game.current == menu and is_instance_valid(menu) and (menu._picker == null or not is_instance_valid(menu._picker) or not menu._picker.visible or menu._picker.is_queued_for_deletion()),
		"Back with the language list open closes the list, not the game")
	Game.start_match({"home": "ENG", "away": "WAL", "venue": "hall", "user_team": 0, "seed": 7, "quarter": 15, "mode": "quick", "difficulty": 1})
	await frames(30)
	var m = Game.current
	var b: Button = m.hud.pause_button()
	var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	check(b.is_visible_in_tree() and view.encloses(b.get_global_rect()) and b.get_global_rect().size.x > 40, "the pause button is on screen (%s)" % b.get_global_rect())
	b.pressed.emit()
	await frames(2)
	check(m.paused, "it pauses the match")
	m.set_paused(false)
	Game.goto_menu()
	await frames(3)


## Every spectator faces the court (the owner's report: the near stand's crowd looked the wrong way): each crowd
## instance's forward points at the court's middle, in every venue, and the near stand shows its backs to the
## broadcast camera behind it.
func _crowd_facing() -> void:
	var was: int = int(Game.settings.graphics)
	Game.settings.graphics = Game.GFX_HIGH
	for venue in ["arena", "hall", "outdoor"]:
		var m: Match = (load("res://game/match.gd") as Script).new()
		m.config = {"home": "ENG", "away": "WAL", "venue": venue, "user_team": -1, "demo": true, "seed": 3, "quarter": 15, "mode": "quick"}
		add_child(m)
		await frames(3)
		var crowds := m.find_children("*", "Crowd", true, false)
		var n := 0
		var bad := 0
		for c: Crowd in crowds:
			# (Headless, the MultiMesh keeps no instance data: each seat's turn comes from Crowd.facing, as build sets it.)
			for spot: Vector3 in c.spots:
				var xf := c.global_transform * Transform3D(Crowd.facing(spot), spot)
				var fwd := Vector2(xf.basis.z.x, xf.basis.z.z).normalized()
				var to := Vector2(-xf.origin.x, -xf.origin.z).normalized()
				n += 1
				if fwd.dot(to) <= 0.7:
					bad += 1
		check(n > 0 and bad == 0, "%s: every spectator faces the court (%d of %d do not)" % [venue, bad, n])
		m.queue_free()
		await frames(2)
	Game.settings.graphics = was


## Every sound the code names is there and loads: the recordings in assets/audio/ (each credited in docs/SOUNDS.md),
## every name in a Sfx.play / play_at call, the crowd's reactions in every venue, the venues' looping beds.
func _sounds() -> void:
	Sfx._ensure()
	var files := []
	for f in DirAccess.get_files_at("res://assets/audio"):
		if f.ends_with(".ogg") or f.ends_with(".ogg.import"):
			var n := f.trim_suffix(".import")
			if not n in files:
				files.append(n)
	var credits := FileAccess.get_file_as_string("res://docs/SOUNDS.md")
	for f in files:
		var s = load("res://assets/audio/" + f)
		check(s is AudioStreamOggVorbis and (s as AudioStream).get_length() > 0.0, "sound %s loads" % f)
		# (Numbered takes are credited together: catch_1..3.ogg.)
		var stem := RegEx.create_from_string("_[0-9]+$").sub(f.trim_suffix(".ogg"), "")
		check(credits.contains("`" + stem), "sound %s is credited in docs/SOUNDS.md" % f)
	var wanted: Array = Sfx.FILES.duplicate()
	for k in Sfx.VARIANTS:
		for i in int(Sfx.VARIANTS[k]):
			wanted.append("%s_%d" % [k, i + 1])
	for k in wanted:
		check(ResourceLoader.exists("res://assets/audio/%s.ogg" % k) and Sfx.streams.has(k), "sound %s: file there and loaded" % k)
	# Every literal name the scripts play.
	var re := RegEx.create_from_string("Sfx\\.(play|play_at)\\(\"([a-z_0-9]+)\"")
	var names := {}
	for dir in ["res://autoload", "res://game", "res://ui"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				for m in re.search_all(FileAccess.get_file_as_string(dir + "/" + f)):
					names[m.get_string(2)] = f
	check(names.size() >= 6, "found the scripts' sounds (%d)" % names.size())
	for n in names:
		check(Sfx.streams.has(n) or Sfx.VARIANTS.has(n), "%s plays \"%s\": it exists" % [names[n], n])
	for v in ["arena", "hall", "outdoor"]:
		var bed: AudioStream = Sfx.streams.get("amb_" + v)
		check(bed is AudioStreamOggVorbis and (bed as AudioStreamOggVorbis).loop, "the %s's bed loops" % v)
	for k in ["crowd_cheer", "crowd_cheer_small", "crowd_ooh", "crowd_groan", "applause", "applause_hall", "applause_small"]:
		check(Sfx.streams.has(k), "the crowd's %s" % k)
	Sfx.venue("hall")
	Sfx.pause(true)
	Sfx.pause(false)
	Sfx.venue("arena")
	check(Sfx._crowd.stream == Sfx.bed("arena"), "the arena's bed is the one set")
	# The whistle: recorded takes of each kind, the gym's in a hall.
	for k in ["whistle_short_1", "whistle_short_2", "whistle_short_3", "whistle_long_1", "whistle_long_2", "whistle_long_3",
			"whistle_double", "whistle_final", "whistle_gym"]:
		check(Sfx.streams.get(k) is AudioStreamOggVorbis, "the whistle: %s" % k)
	Sfx.asked.clear()
	for kind in ["short", "long", "double", "final"]:
		Sfx.whistle(kind, Vector3.ZERO)
	check(int(Sfx.asked.get("whistle", 0)) == 4 and Sfx.asked.size() == 1, "every whistle counts as the whistle (%s)" % [Sfx.asked])
	# Medium and High: the long beds and the extra takes, each loading and credited; Low's beds are Low's.
	var was: int = int(Game.settings.graphics)
	Game.settings.graphics = Game.GFX_HIGH
	for v in ["arena", "hall", "outdoor"]:
		var b: AudioStream = Sfx.bed(v)
		check(b is AudioStreamOggVorbis and (b as AudioStreamOggVorbis).loop and b.get_length() > 40.0
			and b != Sfx.streams.get("amb_" + v), "High: the %s's long bed (%.0f s)" % [v, b.get_length() if b else 0.0])
	for k in Sfx.HD_TAKES:
		for i in int(Sfx.HD_TAKES[k]):
			check(Sfx.streams.get("hd/%s_%d" % [k, i + 2]) is AudioStreamOggVorbis, "High: the take hd/%s_%d" % [k, i + 2])
	for f in DirAccess.get_files_at("res://assets/audio/hd"):
		if f.ends_with(".ogg"):
			var stem := RegEx.create_from_string("_[0-9]+$").sub(f.trim_suffix(".ogg"), "")
			check(credits.contains("`hd/" + stem), "sound hd/%s is credited in docs/SOUNDS.md" % f)
	Game.settings.graphics = Game.GFX_LOW
	for v in ["arena", "hall", "outdoor"]:
		check(Sfx.bed(v) == Sfx.streams.get("amb_" + v), "Low: the %s's bed as before" % v)
	Game.settings.graphics = was


## The sounds at work: a match you play has the catches, the whistle and the steps of its surface, its venue's bed,
## its sounds on court from a capped set of 3D speakers, and the pause menu holds them. The home screen's match asks
## for none of the new ones.
func _sounds_in_play() -> void:
	for venue in ["hall", "outdoor"]:
		Sfx.asked.clear()
		var m: Match = (load("res://game/match.gd") as Script).new()
		m.config = {"home": "ENG", "away": "WAL", "venue": venue, "user_team": 0, "seed": 8, "quarter": 15, "mode": "quick", "difficulty": 1}
		add_child(m)
		await frames(900)
		var surface := "step_floor" if venue == "hall" else "step_court"
		for k in ["whistle", "catch", "pass", surface]:
			check(int(Sfx.asked.get(k, 0)) > 0, "%s: a match plays %s (%d)" % [venue, k, int(Sfx.asked.get(k, 0))])
		check(int(Sfx.asked.get("step_floor" if venue == "outdoor" else "step_court", 0)) == 0, "%s: only its own surface's steps" % venue)
		check(int(Sfx.asked.get("squeak", 0)) <= 900 / 27 + 1, "%s: squeaks kept sparse (%d)" % [venue, int(Sfx.asked.get("squeak", 0))])
		check(int(Sfx.asked.get(surface, 0)) <= 900 / 3 + 1, "%s: steps kept sparse (%d)" % [venue, int(Sfx.asked.get(surface, 0))])
		check(m.find_children("*", "AudioStreamPlayer3D", false, false).size() == Sfx.VOICES_3D, "%s: %d speakers on court, no more" % [venue, Sfx.VOICES_3D])
		check(Sfx._crowd.stream == Sfx.bed(venue), "%s: the venue's own bed" % venue)
		m.set_paused(true)
		check(not Sfx._crowd.playing or Sfx._crowd.stream_paused, "%s: the pause menu holds the crowd" % venue)
		m.set_paused(false)
		m.queue_free()
		await frames(2)
	Sfx.asked.clear()
	var d: Match = (load("res://game/match.gd") as Script).new()
	d.config = {"home": "ENG", "away": "WAL", "venue": "hall", "user_team": -1, "demo": true, "attract": true, "seed": 8, "quarter": 3, "mode": "quick"}
	add_child(d)
	await frames(600)
	var extra := []
	for k in Sfx.asked:
		if not k in ["whistle", "pass", "rim", "swish", "applause"]:
			extra.append(k)
	check(extra.is_empty() and int(Sfx.asked.get("whistle", 0)) > 0, "the home screen's match asks only for what it always did (also: %s)" % [extra])
	d.queue_free()
	await frames(2)
	Sfx.stop_all()


## The textures Low draws with in each venue, as they were before Medium and High got sharper ones (recorded from
## 0.6.0-beta): Low loads exactly these, at these sizes; Medium and High load the sharper copies (Game.HD_TEX) and
## the crowd's 32-figure sheet instead.
const LOW_TEXTURES := {
	"arena": ["<ImageTexture> 128x64", "res://assets/player/hero_albedo.jpg 1024x1024", "res://assets/player/hero_mask.png 512x512",
		"res://assets/ui/bib_letters.png 896x128", "res://assets/venue/arena_atlas.jpg 1024x2048",
		"res://assets/venue/surfaces/white_maple_veneer_albedo_1k.jpg 1024x1024"],
	"hall": ["<ImageTexture> 128x64", "res://assets/player/hero_albedo.jpg 1024x1024", "res://assets/player/hero_mask.png 512x512",
		"res://assets/ui/bib_letters.png 896x128", "res://assets/venue/hall_atlas.jpg 1024x1024",
		"res://assets/venue/surfaces/ceiling_interior_albedo_1k.jpg 1024x1024",
		"res://assets/venue/surfaces/concrete_block_wall_normal_1k.jpg 1024x1024",
		"res://assets/venue/surfaces/white_maple_veneer_albedo_1k.jpg 1024x1024"],
	"outdoor": ["<ImageTexture> 128x64", "res://assets/player/hero_albedo.jpg 1024x1024", "res://assets/player/hero_mask.png 512x512",
		"res://assets/ui/bib_letters.png 896x128", "res://assets/venue/outdoor_atlas.jpg 2048x2048",
		"res://assets/venue/outdoor_cards.png 2048x1024", "res://assets/venue/skies/netball_court_sky_2k.jpg 2048x1024",
		"res://assets/venue/surfaces/asphalt_02_albedo_1k.jpg 1024x1024",
		"res://assets/venue/surfaces/clean_asphalt_albedo_1k.jpg 1024x1024"],
}


## Low is as it was: in each venue a Low match draws with exactly the textures it did before (LOW_TEXTURES), none of
## the sharper copies, and its crowd and sounds are Low's; on High the same match uses the sharper copies.
func _low_unchanged() -> void:
	var was: int = int(Game.settings.graphics)
	for g in [Game.GFX_LOW, Game.GFX_HIGH]:
		Game.settings.graphics = g
		for venue in ["arena", "hall", "outdoor"]:
			var m: Match = (load("res://game/match.gd") as Script).new()
			m.config = {"home": "AUS", "away": "NZL", "venue": venue, "user_team": 0, "seed": 4, "quarter": 15, "mode": "quick"}
			add_child(m)
			await frames(3)
			var got := textures_in(m)
			if g == Game.GFX_LOW:
				var want := PackedStringArray(LOW_TEXTURES[venue])
				check(got == want, "Low, %s: the same textures as before (got %s)" % [venue, ", ".join(got)])
				check(Sfx._crowd.stream == Sfx.streams.get("amb_" + venue), "Low, %s: the same bed as before" % venue)
			else:
				var hd := 0
				for t in got:
					for k in Game.HD_TEX:
						if t.begins_with(Game.tex_path(k, g) + " ") and Game.tex_path(k, g) != k:
							hd += 1
						check(not t.begins_with(String(k) + " "), "High, %s: not the Low copy of %s" % [venue, k])
				check(hd >= 3, "High, %s: the sharper textures (%d)" % [venue, hd])
				check(", ".join(got).contains("crowd_hd.png 2048x512"), "High, %s: the crowd's 32 people" % venue)
			m.queue_free()
			await frames(2)
	Game.settings.graphics = was


## Every texture a match's scene draws with (its materials' textures, the sky's), as "path WxH" (a texture made in
## code: "<ClassName> WxH"), sorted and without repeats.
static func textures_in(root: Node) -> PackedStringArray:
	var seen := {}
	var mats: Array[Material] = []
	for n in root.find_children("*", "", true, false):
		if n is GeometryInstance3D:
			var g := n as GeometryInstance3D
			if g.material_override:
				mats.append(g.material_override)
			if g is MeshInstance3D and (g as MeshInstance3D).mesh:
				var mi := g as MeshInstance3D
				for s in mi.mesh.get_surface_count():
					for m in [mi.get_surface_override_material(s), mi.mesh.surface_get_material(s)]:
						if m:
							mats.append(m)
			if g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh and (g as MultiMeshInstance3D).multimesh.mesh:
				var mm := (g as MultiMeshInstance3D).multimesh.mesh
				for s in mm.get_surface_count():
					if mm.surface_get_material(s):
						mats.append(mm.surface_get_material(s))
		elif n is WorldEnvironment and (n as WorldEnvironment).environment and (n as WorldEnvironment).environment.sky:
			mats.append((n as WorldEnvironment).environment.sky.sky_material)
	var done := {}
	while not mats.is_empty():
		var m: Material = mats.pop_back()
		if m == null or done.has(m):
			continue
		done[m] = true
		if m.next_pass:
			mats.append(m.next_pass)
		var texs: Array = []
		if m is ShaderMaterial and (m as ShaderMaterial).shader:
			for u in (m as ShaderMaterial).shader.get_shader_uniform_list():
				texs.append((m as ShaderMaterial).get_shader_parameter(u.name))
		elif m is BaseMaterial3D:
			for p in m.get_property_list():
				if String(p.name).ends_with("_texture"):
					texs.append(m.get(p.name))
		for t in texs:
			if t is Texture2D:
				var tex := t as Texture2D
				var name := tex.resource_path if tex.resource_path != "" else "<%s>" % tex.get_class()
				seen["%s %dx%d" % [name, tex.get_width(), tex.get_height()]] = true
	var out := PackedStringArray(seen.keys())
	out.sort()
	return out
