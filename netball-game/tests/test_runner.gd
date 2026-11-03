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
	# The shared foundation (FoundationLink, on Medium and High when this machine has the licensed clips; CI has not)
	# is tested in its own sections; elsewhere the matches run without it, as CI's do, in the time CI allows.
	var foundation_ok := WsgClips.available()
	FoundationLink.off = true
	if "stick" in OS.get_cmdline_user_args():
		# (Only the stick in every camera: tests/test_runner.tscn -- stick)
		await _stick_camera()
		print("test_runner: %d checks, %d failures" % [checks, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if "howto" in OS.get_cmdline_user_args():
		# (Only How to Play's position courts, their pictures too in a window: xvfb-run ... test_runner.tscn -- howto)
		await _howto_positions()
		print("test_runner: %d checks, %d failures" % [checks, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if "body" in OS.get_cmdline_user_args():
		# (Only the bodies on every path: tests/test_runner.tscn -- body)
		await _body_checks()
		print("test_runner: %d checks, %d failures" % [checks, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if "ball" in OS.get_cmdline_user_args():
		# (Only the ball, the nets and advantage: tests/test_runner.tscn -- ball)
		_ball_flight()
		_ball_uncaught()
		await _ball_in_play()
		await _ball_free_in_play()
		await _net_sway()
		await _advantage_clear()
		await _restart_spacing()
		await _two_goal_lead()
		print("test_runner: %d checks, %d failures" % [checks, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if "loading" in OS.get_cmdline_user_args():
		# (Only the loading overlay on the Start buttons: tests/test_runner.tscn -- loading)
		await _loading_overlay()
		print("test_runner: %d checks, %d failures" % [checks, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if "gait" in OS.get_cmdline_user_args():
		# (Only the run: tests/test_runner.tscn -- gait)
		await _gait_steps()
		print("test_runner: %d checks, %d failures" % [checks, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	await _screens()
	await _about_pages()
	_rules()
	_footwork()
	_ball_flight()
	_ball_uncaught()
	_sim()
	_cup()
	_league()
	await _matches()
	await _rules_in_play()
	await _ball_in_play()
	await _ball_free_in_play()
	await _net_sway()
	await _advantage_clear()
	await _restart_spacing()
	await _two_goal_lead()
	await _motion()
	await _mocap()
	await _gait_steps()
	await _body_checks()
	await _controls()
	await _stick_camera()
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
	await _venue_study()
	await _watch_ai()
	await _loading_overlay()
	FoundationLink.off = false
	await _foundation(foundation_ok)
	await _replays()
	await _low_unchanged()       # (again, the foundation available: Low draws exactly what it did)
	FoundationLink.off = true
	await _howto_positions()
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
		"res://ui/records_screen.gd", "res://ui/cup_screen.gd", "res://ui/league_screen.gd", "res://ui/licences_screen.gd",
		"res://ui/help_screen.gd", "res://ui/privacy_screen.gd", "res://ui/watch_setup.gd"]
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


## Settings > About: Licences, Help and the privacy policy each open in the game (offline), from Settings' own
## buttons, with their words in them and a way back.
func _about_pages() -> void:
	var want := {"LICENCES": ["res://ui/licences_screen.gd", ["Godot Engine", "mocap.cs.cmu.edu", "MoCap Online", "ActorCore", "Pixabay", "Kenney", "Poly Haven", "SIL Open Font License"]],
		"HELP_SUPPORT": ["res://ui/help_screen.gd", [tr("CTRL_MOVE"), tr("RULES_FOOTWORK"), tr("GFX_LOW"), "Report a bug", "@"]],
		"PRIVACY_POLICY": ["res://ui/privacy_screen.gd", ["no personal data", "internet permission", "Last updated", "Contact", "@"]]}
	for key in want:
		var settings := Game.show_screen("res://ui/settings_screen.gd")
		await frames(3)
		var btn: Button = null
		for b in settings.find_children("*", "Button", true, false):
			if (b as Button).text == tr(key):
				btn = b
		check(btn != null, "Settings has a %s button" % key)
		if btn == null:
			continue
		btn.pressed.emit()
		await frames(4)
		var s: Node = Game.current
		var waited := 0
		while is_instance_valid(s) and s.has_method("built") and not s.built() and waited < 300:
			waited += 1
			await frames(1)
		check(is_instance_valid(s) and s.get_script() != null and String(s.get_script().resource_path) == want[key][0], "%s opens %s in the game" % [key, want[key][0]])
		var words := ""
		for rt in s.find_children("*", "RichTextLabel", true, false):
			words += (rt as RichTextLabel).get_parsed_text() + "\n"
		check(words.length() > 600, "%s is not empty (%d characters)" % [key, words.length()])
		for w in want[key][1]:
			check(words.contains(w), "%s mentions %s" % [key, w])
		check(s.find_children("*", "ScrollContainer", true, false).size() > 0, "%s scrolls" % key)
	Game.show_screen("res://ui/settings_screen.gd")
	await frames(2)


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


## The ball flies as a ball does (Ball.plan): gravity at 9.81 m/s², its speed across the floor constant through each
## leg, from the hands to the catch; a chest pass at 8-14 m/s, a long shoulder pass no harder than 17; a lob 1.5-3 m
## over the hands, hanging over a second, slower across than a chest pass; a bounce pass off the floor; a shot
## released at 45-55 degrees from 3 m out and more (steeper under the post), dropping into the ring.
func _ball_flight() -> void:
	var dt := 1.0 / 30.0
	var hand := Vector3(0.0, 1.35, 0.0)
	var cases := [["chest", 3.0], ["chest", 6.0], ["chest", 9.0], ["chest", 12.0], ["shoulder", 11.0], ["shoulder", 16.0],
		["shoulder", 21.0], ["lob", 4.0], ["lob", 7.0], ["lob", 10.0], ["bounce", 3.5], ["bounce", 5.5], ["shot", 0.6],
		["shot", 2.0], ["shot", 3.0], ["shot", 4.0], ["shot", 4.85]]
	var ring := Court.ring_centre(1) + Vector3(0, 0.05, 0)
	var chest_vh := {}
	for c: Array in cases:
		var kind: String = c[0]
		var d: float = c[1]
		var from := hand
		var to := Vector3(d * 0.96, 1.3, d * 0.28)
		match kind:
			"lob":
				to.y = 2.05
			"bounce":
				to.y = 0.95
			"shot":
				from = ring + Vector3(-d * 0.8, 0.0, d * 0.6)
				from.y = 2.45
				to = ring
		var pl := Ball.plan(kind, from, to)
		var dur := float(pl.dur)
		var name := "%s %.1f m" % [kind, d]
		check(Ball.plan_at(pl, 0.0).distance_to(from) < 0.001 and Ball.plan_at(pl, 1.0).distance_to(to) < 0.001,
			"ball: a %s pass leaves the hands and arrives where it is caught" % name)
		# Sampled as the game samples it (30 a second): the second difference of its height is gravity; its speed
		# across the floor the same each step (except across a bounce pass's bounce).
		var ys: Array = []
		var flats: Array = []
		var n := int(dur / dt)
		var acc_bad := 0.0
		var vh_spread := 0.0
		for i in n + 1:
			ys.append(Ball.plan_at(pl, i * dt / dur))
		var bounce_i := int(float(pl.bounce) * dur / dt) if float(pl.bounce) > 0.0 else -10
		for i in range(1, n):
			if absi(i - bounce_i) <= 1:
				continue
			var a: float = (ys[i + 1].y - 2.0 * ys[i].y + ys[i - 1].y) / (dt * dt)
			acc_bad = maxf(acc_bad, absf(a + Ball.G) / Ball.G)
		for i in n:
			if absi(i - bounce_i) <= 1:
				continue
			flats.append(Vector2(ys[i + 1].x - ys[i].x, ys[i + 1].z - ys[i].z).length() / dt)
		if flats.size() > 1 and float(pl.bounce) < 0.0:
			vh_spread = (flats.max() - flats.min()) / maxf(flats.max(), 0.01)
		check(acc_bad < 0.02, "ball: %s, its vertical acceleration is gravity, -9.81 m/s² (off by %.1f%%)" % [name, acc_bad * 100.0])
		check(vh_spread < 0.01, "ball: %s, its speed across the floor constant in flight (spread %.1f%%)" % [name, vh_spread * 100.0])
		var v0 := Ball.plan_vel(pl, 0.0)
		var vh := Vector2(v0.x, v0.z).length()
		var apex := maxf(v0.y, 0.0) * maxf(v0.y, 0.0) / (2.0 * Ball.G)
		print("  ball: %-14s %.2f s, released at %.1f m/s (%.1f across, %.0f deg), %.2f m over the hands at the top" %
			[name, dur, v0.length(), vh, rad_to_deg(atan2(v0.y, vh)), apex])
		match kind:
			"chest":
				check(v0.length() >= 8.0 and v0.length() <= 14.0, "ball: %s at 8-14 m/s (%.1f)" % [name, v0.length()])
				chest_vh[d] = vh
			"shoulder":
				check(v0.length() >= 11.0 and v0.length() <= 17.5, "ball: %s at 11-17.5 m/s (%.1f)" % [name, v0.length()])
			"lob":
				check(apex >= 1.5 and apex <= 3.0, "ball: %s, 1.5-3 m over the hands at the top (%.2f)" % [name, apex])
				check(dur >= 1.0 and dur <= 1.7, "ball: %s hangs 1-1.7 s (%.2f)" % [name, dur])
				var chest := Ball.plan("chest", from, Vector3(to.x, 1.3, to.z))
				var cv := Ball.plan_vel(chest, 0.0)
				check(vh < Vector2(cv.x, cv.z).length() * 0.75, "ball: %s, slower across the floor than a chest pass (%.1f m/s)" % [name, vh])
			"bounce":
				var k := float(pl.bounce)
				var down := Ball.plan_vel(pl, k - 0.001)
				var up := Ball.plan_vel(pl, k + 0.001)
				var e := up.y / maxf(-down.y, 0.01)
				check(k > 0.3 and k < 0.8 and absf(Ball.plan_at(pl, k).y - Ball.R) < 0.002 and down.y < -2.0 and e > 0.6 and e < 0.95,
					"ball: %s meets the floor and comes up off it (%.0f%% of the way, down %.1f m/s, up %.1f)" % [name, k * 100.0, -down.y, up.y])
			"shot":
				var ang := rad_to_deg(atan2(v0.y, vh))
				var v1 := Ball.plan_vel(pl, 1.0)
				var entry := rad_to_deg(atan2(-v1.y, Vector2(v1.x, v1.z).length()))
				if d >= 3.0:
					check(ang >= 45.0 and ang <= 55.0, "ball: %s released at 45-55 degrees (%.0f)" % [name, ang])
				else:
					check(ang >= 55.0 and ang <= 85.0, "ball: %s under the post, a steeper arc (%.0f degrees)" % [name, ang])
				check(v1.y < 0.0 and entry >= 38.0 and apex + from.y - to.y >= 0.44, "ball: %s drops into the ring from above (%.0f degrees, top %.2f m over it)" % [name, entry, apex + from.y - to.y])
	# The ball itself, stepped as in a match: a lob falls at g.
	var b := Ball.new()
	add_child(b)
	var ys2: Array = []
	b.throw("lob", hand, Vector3(7.0, 2.05, 1.0))
	while b.f_t + dt <= b.f_dur:
		b.step(dt)
		ys2.append(b.position.y)
	var worst := 0.0
	for i in range(1, ys2.size() - 1):
		worst = maxf(worst, absf((ys2[i + 1] - 2.0 * ys2[i] + ys2[i - 1]) / (dt * dt) + Ball.G))
	check(ys2.size() > 25 and worst < Ball.G * 0.02, "ball: stepped frame by frame, a lob falls at g (worst %.2f m/s² off, %d frames)" % [worst, ys2.size()])
	b.free()


## In a match the passes fly as Ball.plan says: frame by frame, each pass in the air falls at g and keeps its speed
## across the floor; the flight times follow the kind and length (lobs hang longest).
func _ball_in_play() -> void:
	var m := _study_match(36)
	await _wait_live(m)
	var flights := {}
	var cur: Array = []
	var cur_kind := ""
	var bad_acc := 0.0
	var bad_vh := 0.0
	var steps := 0
	for f in 900:
		await frames(1)
		var flying: bool = m.ball.state == "flight" and m.pass_info.has("to") and m.ball.f_t <= m.ball.f_dur and m.speed == 1
		if flying and m.ball.f_bounce < 0.0:
			if cur.is_empty():
				cur_kind = String(m.pass_info.kind)
			cur.append(m.ball.position)
		elif not cur.is_empty():
			for i in range(1, cur.size() - 1):
				var a: float = (cur[i + 1].y - 2.0 * cur[i].y + cur[i - 1].y) * 900.0
				bad_acc = maxf(bad_acc, absf(a + Ball.G) / Ball.G)
				var h0 := Vector2(cur[i].x - cur[i - 1].x, cur[i].z - cur[i - 1].z).length()
				var h1 := Vector2(cur[i + 1].x - cur[i].x, cur[i + 1].z - cur[i].z).length()
				bad_vh = maxf(bad_vh, absf(h1 - h0) / maxf(h0, 0.001))
				steps += 1
			flights[cur_kind] = int(flights.get(cur_kind, 0)) + 1
			cur = []
	check(steps > 20 and bad_acc < 0.02, "ball in play: passes fall at g frame by frame (%d steps, worst %.1f%% off)" % [steps, bad_acc * 100.0])
	check(steps > 20 and bad_vh < 0.01, "ball in play: and keep their speed across the floor (worst %.1f%% change a frame)" % [bad_vh * 100.0])
	check(flights.size() >= 1, "ball in play: passes seen (%s)" % [flights])
	m.queue_free()
	await frames(2)


## The nets are rope: a goal whips the net it drops through (its foot out 18 cm and more, enough to see from the TV
## camera's wide shot), ripples and billows it, then it settles; the other net is still. A shot off the ring shakes
## it (12 cm and more). In every venue, on Low as on High, by the glow shader's uniforms (no draw call of its own).
func _net_sway() -> void:
	var was: int = int(Game.settings.graphics)
	for run: Array in [["arena", "goal", Game.GFX_HIGH], ["hall", "goal", Game.GFX_HIGH], ["outdoor", "goal", Game.GFX_HIGH],
			["arena", "goal", Game.GFX_LOW], ["arena", "miss", Game.GFX_HIGH], ["hall", "miss", Game.GFX_LOW]]:
		var venue: String = run[0]
		var goal: bool = run[1] == "goal"
		Game.settings.graphics = int(run[2])
		var lv := "Low" if int(run[2]) == Game.GFX_LOW else "High"
		var m := _study_match(37, {"venue": venue})
		await _wait_live(m)
		var guard := 0
		while (m.holder == null or m.phase != "live") and guard < 600:
			await frames(1)
			guard += 1
		var t := m.holder.team if m.holder else 0
		var gs: Player = m.player_at(t, "GS")
		m.pass_info = {}
		m._release_holder()
		gs.p = Court.goal_post(gs.dir) + Vector2(-gs.dir * 2.5, 0.8)
		gs.vel = Vector2.ZERO
		gs.target = gs.p
		m._give(gs)
		m.ai._decide[gs] = 99.0
		m.shoot()
		m.shot_info.goal = goal
		var s := 1 if gs.dir > 0 else 0
		var peak := 0.0
		var ripple := 0.0
		var billow := 0.0
		var other := 0.0
		var hit_f := -1
		var stuck := 0.0
		var shader_peak := 0.0
		for f in 210:
			await frames(1)
			if hit_f < 0 and (m.phase == "goal" or m.shot_info.get("rebound", false) or (m.ball.state == "loose" and not goal)):
				hit_f = f
			var n: Dictionary = m.arena.nets[s]
			peak = maxf(peak, (n.sw as Vector2).length())
			ripple = maxf(ripple, float(n.amp))
			billow = maxf(billow, float(n.bil))
			other = maxf(other, (m.arena.nets[1 - s].sw as Vector2).length())
			var u: Array = m.arena._glow_mat.get_shader_parameter("net_swing")
			shader_peak = maxf(shader_peak, Vector2((u[s] as Vector4).x, (u[s] as Vector4).y).length())
			if hit_f >= 0 and f > hit_f + 150:
				stuck = maxf(stuck, (n.sw as Vector2).length())
		var what := "a goal" if goal else "a shot off the ring"
		print("  net: %s, %s, %s swings its foot %.1f cm (ripple %.1f cm, billow %.1f cm); 5 s on, %.1f mm" % [venue, lv, what, peak * 100.0, ripple * 100.0, billow * 100.0, stuck * 1000.0])
		if goal:
			check(hit_f >= 0 and peak >= 0.18 and peak <= Arena.NET_MAX + 0.001 and ripple >= 0.03 and billow >= 0.03,
				"%s, %s: a goal whips the net (%.1f cm at its foot, ripple %.1f cm, billow %.1f cm)" % [venue, lv, peak * 100.0, ripple * 100.0, billow * 100.0])
		else:
			check(hit_f >= 0 and peak >= 0.12, "%s, %s: a shot off the ring shakes the net (%.1f cm at its foot)" % [venue, lv, peak * 100.0])
		check(absf(shader_peak - peak) < 0.002, "%s, %s: the glow shader is given the swing (%.1f cm)" % [venue, lv, shader_peak * 100.0])
		check(stuck < 0.004, "%s, %s: then it settles within five seconds (%.1f mm)" % [venue, lv, stuck * 1000.0])
		check(other < 0.001, "%s, %s: the other net is still" % [venue, lv])
		check(String((m.arena._glow_mat as ShaderMaterial).shader.code).contains("net_billow"), "%s, %s: the nets move in the one glow shader" % [venue, lv])
		m.queue_free()
		await frames(2)
	Game.settings.graphics = was


## No throw crosses the floor faster than a real one (Ball.FLAT_MAX, about 17 m/s at most), however long; a long
## shoulder pass is a high throw (20 m: 1.2-1.5 s in the air, its top 2-3 m over the hands). A pass nobody catches
## carries on along its own parabola, is let go at its own speed (as Match lets it go), falls at g, lands where that
## parabola meets the floor (never further than its flight carries it) and bounces and rolls to a stop; a ball in the
## air when the whistle goes falls the same way (Ball.dead, moving), and a dead ball put on its spot stays there.
func _ball_uncaught() -> void:
	var dt := 1.0 / 30.0
	var hand := Vector3(0.0, 1.6, 0.0)
	var fastest := 0.0
	var fast_name := ""
	for kind: String in ["chest", "shoulder", "lob", "bounce"]:
		for i in 30:
			var d := 1.0 + i
			var to := Vector3(d * 0.8, 2.05 if kind == "lob" else (0.95 if kind == "bounce" else 1.3), d * 0.6)
			var pl := Ball.plan(kind, hand, to)
			for k: float in [0.0, 0.3, 0.7, 0.999]:
				var v := Ball.plan_vel(pl, k)
				var flat := Vector2(v.x, v.z).length()
				if flat > fastest:
					fastest = flat
					fast_name = "%s %.0f m" % [kind, d]
	check(fastest <= 17.0, "ball: no pass crosses the floor faster than 17 m/s, 1-30 m of every kind (fastest %.1f, a %s)" % [fastest, fast_name])
	for d: float in [15.0, 20.0, 25.0]:
		var sh := Ball.plan("shoulder", Vector3(0, 1.9, 0), Vector3(d, 1.4, 0))
		var v0 := Ball.plan_vel(sh, 0.0)
		var apex := v0.y * v0.y / (2.0 * Ball.G)
		print("  ball: shoulder %.0f m: %.2f s, %.1f m/s across, %.2f m over the hands at the top" % [d, float(sh.dur), Vector2(v0.x, v0.z).length(), apex])
		if d == 20.0:
			check(float(sh.dur) >= 1.2 and float(sh.dur) <= 1.5 and apex >= 2.0 and apex <= 3.0,
				"ball: a 20 m shoulder pass is in the air 1.2-1.5 s, its top 2-3 m over the hands (%.2f s, %.2f m)" % [float(sh.dur), apex])
	# Nobody catches it.
	for c: Array in [["chest", 7.0], ["shoulder", 18.0], ["lob", 9.0], ["bounce", 5.0]]:
		var kind: String = c[0]
		var d: float = c[1]
		var b := Ball.new()
		add_child(b)
		var lands: Array = []
		var fc := {"f": 0, "at": []}
		b.bounced.connect(func(at: Vector3, _sp: float):
			lands.append(at)
			fc.at.append(fc.f))
		var from := hand
		var to := Vector3(d, 2.05 if kind == "lob" else (0.95 if kind == "bounce" else 1.3), 1.0)
		b.throw(kind, from, to)
		var lg: Array = b.f_legs[b.f_legs.size() - 1]
		var p0: Vector3 = lg[1]
		var v0: Vector3 = lg[2]
		var tl := (v0.y + sqrt(v0.y * v0.y + 2.0 * Ball.G * (p0.y - Ball.R))) / Ball.G
		var meet := Vector2(p0.x + v0.x * tl, p0.z + v0.z * tl)   # where its parabola meets the floor
		var ps: Array = []
		var let_go := false
		for f in 360:
			fc.f = f
			b.step(dt)
			if b.state == "flight" and b.f_t >= b.f_dur:
				b.loose(b.pos, b.velocity())   # (as Match lets a pass she did not reach go)
				let_go = true
			ps.append(b.pos)
		var worst := 0.0
		var n := 0
		for i in range(1, ps.size() - 1):
			if minf(minf(ps[i - 1].y, ps[i].y), ps[i + 1].y) <= Ball.R + 0.01 or fc.at.has(i) or fc.at.has(i + 1) or (kind == "bounce" and absf(i * dt - b.f_dur * b.f_bounce) < 0.1):
				continue
			worst = maxf(worst, absf((ps[i + 1].y - 2.0 * ps[i].y + ps[i - 1].y) / (dt * dt) + Ball.G) / Ball.G)
			n += 1
		# (A bounce pass's first touch is its planned bounce: its landing is the next.)
		var first: Vector3 = lands[1 if kind == "bounce" else 0] if lands.size() > (1 if kind == "bounce" else 0) else Vector3.INF
		var at := Vector2(first.x, first.z)
		var reach := Vector2(from.x, from.z).distance_to(meet)
		var rest: Vector3 = ps[ps.size() - 1]
		var still: bool = (ps[ps.size() - 1] as Vector3).distance_to(ps[ps.size() - 2]) < 0.0005
		check(let_go and n > 10 and worst < 0.02, "ball: a %s nobody catches falls at g all the way down (%d frames, worst %.1f%% off)" % [kind, n, worst * 100.0])
		check(first != Vector3.INF and at.distance_to(meet) < 0.3 and Vector2(from.x, from.z).distance_to(at) <= reach + 0.3,
			"ball: and lands where its flight's parabola meets the floor, within its range (%.2f m off; %.1f m out of %.1f)" % [at.distance_to(meet), Vector2(from.x, from.z).distance_to(at), reach])
		check(lands.size() >= 2 and still and absf(rest.y - Ball.R) < 0.002, "ball: then bounces (%d times) and rolls to a stop on the floor" % lands.size())
		b.free()
	# The whistle with the ball in the air: dead, it carries on and falls; put on a spot, it stays.
	var b2 := Ball.new()
	add_child(b2)
	b2.throw("shoulder", hand, Vector3(16.0, 1.4, 0.0))
	for f in 8:
		b2.step(dt)
	var v_then := b2.velocity()
	b2.dead(b2.pos, true)
	var ys: Array = []
	for f in 150:
		b2.step(dt)
		ys.append(b2.pos)
	var bad := 0.0
	for i in range(1, 12):
		bad = maxf(bad, absf((ys[i + 1].y - 2.0 * ys[i].y + ys[i - 1].y) / (dt * dt) + Ball.G) / Ball.G)
	check(bad < 0.02 and absf((ys[1].x - ys[0].x) / dt - v_then.x) < 0.2 and absf(ys[ys.size() - 1].y - Ball.R) < 0.002,
		"ball: the whistle with it in the air: it goes on as it was going, falls at g (%.1f%% off) and comes to rest on the floor" % [bad * 100.0])
	b2.dead(Vector3(0, Ball.R, 0))
	b2.step(dt)
	check(b2.pos == Vector3(0, Ball.R, 0), "ball: a dead ball put on its spot stays there")
	b2.free()


## In a match: every frame the ball is free (in flight, loose, or dead and still falling) it falls at g, except in a
## net (the cords hold it) or as it meets the floor; no pass crosses the floor faster than 17 m/s; nothing holds it in
## the air (it hung where it was when the whistle went, before). Then a pass to nobody and a whistle in mid-pass.
func _ball_free_in_play() -> void:
	var m := _study_match(39)
	await _wait_live(m)
	var top := {"flat": 0.0}
	m.game_event.connect(func(k, _info):
		if k == "pass":
			var v: Vector3 = m.ball.flight_vel(0.0)
			top.flat = maxf(float(top.flat), Vector2(v.x, v.z).length()))
	var hist: Array = []
	var n := {"flight": 0, "loose": 0, "dead": 0}
	var off := {"flight": 0, "loose": 0, "dead": 0}
	var worst := 0.0
	var hung := 0
	var fr := {"f": 0, "at": []}
	m.ball.bounced.connect(func(_at, _sp): fr.at.append(fr.f))
	for f in 2400:
		fr.f = f + 1
		await frames(1)
		var b: Ball = m.ball
		hist.append([b.state, b.position, m.phase, b.f_kind, b.f_t > b.f_dur, b.f_bounce, b.f_t / maxf(b.f_dur, 0.001), b._moving])
		if hist.size() < 3:
			continue
		var a: Array = hist[-3]
		var bb: Array = hist[-2]
		var c: Array = hist[-1]
		if b.state == "dead" and not b._moving and b.carrier == null and b.position.y > 0.3:
			hung += 1
		if not (a[0] == bb[0] and bb[0] == c[0] and a[2] == c[2]) or a[0] == "held" or c[2] == "replay":
			continue
		if a[0] == "dead" and not (a[7] and c[7]):
			continue
		var p0: Vector3 = a[1]
		var p1: Vector3 = bb[1]
		var p2: Vector3 = c[1]
		if minf(minf(p0.y, p1.y), p2.y) <= Ball.R + 0.01 or p0.distance_to(p2) < 0.001 or fr.at.has(f) or fr.at.has(f + 1):
			continue
		if c[3] == "shot" and c[4]:
			continue   # (a shot stops on the ring: Match takes it on)
		if float(c[5]) > 0.0 and absf(float(bb[6]) - float(c[5])) < 0.08:
			continue   # (a bounce pass's bounce)
		var in_net := false
		for s: int in [-1, 1]:
			var rc := Court.ring_centre(s)
			if Vector2(p1.x - rc.x, p1.z - rc.z).length() < Court.RING_R + 0.05 and p1.y < rc.y + 0.1 and p1.y > rc.y - 0.6:
				in_net = true
		if in_net:
			continue
		var acc := (p2.y - 2.0 * p1.y + p0.y) * 900.0
		n[a[0]] += 1
		var e := absf(acc + Ball.G) / Ball.G
		worst = maxf(worst, e)
		if e > 0.02:
			off[a[0]] += 1
	check(n.flight > 200 and n.loose + n.dead > 20 and off.flight + off.loose + off.dead == 0,
		"ball in play: free, it falls at g every frame (checked %s; off by more than 2%%: %s, worst %.1f%%)" % [n, off, worst * 100.0])
	check(float(top.flat) > 5.0 and float(top.flat) <= 17.0, "ball in play: no pass faster across the floor than 17 m/s (fastest %.1f)" % float(top.flat))
	check(hung == 0, "ball in play: never left hanging in the air at a whistle (%d frames)" % hung)
	# A pass to nobody (she is back by the thrower): on along its own parabola past the catch, let go at its own
	# speed, down where that parabola meets the floor (unless someone takes it first), at g all the way.
	for trial in 2:
		var guard := 0
		while (m.holder == null or m.phase != "live" or m.shot_info.has("by")) and guard < 900:
			await frames(1)
			guard += 1
		var h: Player = m.holder
		m.ai._decide[h] = 99.0
		var to: Player = null
		for o: Player in m.players[h.team]:
			if o != h and not o.away() and o.p.distance_to(h.p) > 4.0 and o.p.distance_to(h.p) < 14.0 and (to == null or o.p.distance_to(h.p) > to.p.distance_to(h.p)):
				to = o
		if to == null:
			check(false, "ball in play: a team-mate to pass to")
			break
		m.restart["cp_done"] = true
		m.throw_pass(to, "shoulder" if trial == 0 else "chest")
		m.pass_info.cut = null
		var from := m.ball.f_from
		var lg: Array = m.ball.f_legs[0]
		var p00: Vector3 = lg[1]
		var v00: Vector3 = lg[2]
		var tl := (v00.y + sqrt(v00.y * v00.y + 2.0 * Ball.G * (p00.y - Ball.R))) / Ball.G
		var meet := Vector2(p00.x + v00.x * tl, p00.z + v00.z * tl)
		var reach := Vector2(from.x, from.z).distance_to(meet)
		to.p = Rules.onside_point(to.pos, h.p + (h.p - to.p).normalized() * 1.5, to.dir, 0.3)
		to.vel = Vector2.ZERO
		var off_arc := 0.0
		var land := {"at": Vector3.INF}
		var on_floor := func(at: Vector3, _sp: float):
			if land.at == Vector3.INF:
				land.at = at
		m.ball.bounced.connect(on_floor)
		var k := 0
		var let_go := false
		while k < 75 and (m.ball.state == "flight" or m.ball.state == "loose") and land.at == Vector3.INF:
			await frames(1)
			k += 1
			to.target = to.p
			if m.ball.state == "loose":
				let_go = true
			if m.ball.state == "held" or land.at != Vector3.INF:
				break
			var want := p00 + v00 * (k / 30.0) + Vector3(0, -0.5 * Ball.G * (k / 30.0) * (k / 30.0), 0)
			off_arc = maxf(off_arc, m.ball.position.distance_to(want))
		m.ball.bounced.disconnect(on_floor)
		var first: Vector3 = land.at
		var at := Vector2(first.x, first.z) if first != Vector3.INF else Vector2.INF
		var how := "lands %.2f m off the floor point, %.1f m out of %.1f" % [at.distance_to(meet), Vector2(from.x, from.z).distance_to(at), reach] if first != Vector3.INF else "taken first"
		check(let_go and off_arc < 0.03 and (first == Vector3.INF or (at.distance_to(meet) < 0.35 and Vector2(from.x, from.z).distance_to(at) <= reach + 0.35)),
			"ball in play: a pass to nobody flies on along its arc (%.3f m off it) and comes down within its range (%s)" % [off_arc, how])
	# A whistle in mid-pass: the ball carries on and falls.
	var guard2 := 0
	while (m.holder == null or m.phase != "live" or m.shot_info.has("by")) and guard2 < 900:
		await frames(1)
		guard2 += 1
	var h2: Player = m.holder
	m.ai._decide[h2] = 99.0
	var to2: Player = null
	for o: Player in m.players[h2.team]:
		if o != h2 and not o.away() and (to2 == null or o.p.distance_to(h2.p) > to2.p.distance_to(h2.p)) and o.p.distance_to(h2.p) < 14.0:
			to2 = o
	m.restart["cp_done"] = true
	m.throw_pass(to2, "chest")
	m.pass_info.cut = null
	await frames(3)
	var y0 := m.ball.position.y
	var someone: Player = m.players[1 - h2.team][2]
	m._infringe("offside", someone, someone.p)
	var ys: Array = []
	var bounces: Array = []
	m.ball.bounced.connect(func(_at, _sp): bounces.append(m.phase))
	var low := INF
	var stop_f := 0
	while m.ball.state == "dead" and bounces.is_empty() and stop_f < 75:
		await frames(1)
		stop_f += 1
		ys.append(m.ball.position)
		low = minf(low, m.ball.position.y)
	check(ys.size() > 10 and y0 > 0.8 and low < 0.35 and not bounces.is_empty() and (ys[1] as Vector3).distance_to(ys[0]) > 0.05,
		"ball in play: the whistle in mid-pass: the ball goes on and falls to the floor, play stopped (from %.2f m, down to %.2f m and bouncing in %d frames)" % [y0, low, stop_f])
	# A whistle with the ball in her hands: she keeps it through the stoppage, then hands it on to the thrower (a toss
	# that lands and bounces, or the thrower is she): never left in the air.
	var guard3 := 0
	while (m.holder == null or m.phase != "live" or m.shot_info.has("by")) and guard3 < 900:
		await frames(1)
		guard3 += 1
	var h3: Player = m.holder
	m.ai._decide[h3] = 99.0
	m._infringe("held_ball", h3, h3.p)
	var in_hands := 0
	var stop_n := 0
	var floating := 0
	var handed := false
	var tossed := {"n": 0}
	var on_floor := func(_at, _sp): tossed.n += 1
	m.ball.bounced.connect(on_floor)
	for f in 150:
		await frames(1)
		if m.phase == "stop":
			stop_n += 1
			if m.ball.carrier == h3 and m.ball.position.distance_to(h3.hand_point()) < 0.05:
				in_hands += 1
		if m.ball.state == "dead" and m.ball.carrier == null and not m.ball._moving and m.ball.position.y > 0.3:
			floating += 1
		if m.ball.state == "held":
			handed = true
			break
	m.ball.bounced.disconnect(on_floor)
	m.ai._decide.clear()
	check(stop_n > 10 and in_hands == stop_n and floating == 0 and handed and (tossed.n > 0 or m.holder == h3),
		"ball in play: a whistle with the ball in her hands: she keeps it (%d of %d frames), then hands it on (%d bounces; %d frames in the air on its own)" % [in_hands, stop_n, tossed.n, floating])
	m.queue_free()
	await frames(2)


## Whether the ball met the floor between three frames (it came down to them and went up after).
static func _bounce_between(a: Vector3, b: Vector3, c: Vector3) -> bool:
	return b.y < 0.6 and b.y - a.y < 0.0 and c.y - b.y > 0.0


## Penalty and free passes and throw-ins, as the umpire sets them: the penalised player stands out of play beside the
## thrower, 1.2-1.5 m off her (not touching, not crowding her) and never in front of her; nobody else of her side
## within 0.9 m of the thrower's landing foot from the whistle to the pass (obstruction, the game's own rule); in open
## play the AI never sets a defender nearer the ball than that, and stays out (TeamAI.keep_clear).
func _restart_spacing() -> void:
	var bad := 0
	var tried := 0
	var cramped := 0
	var worst := ""
	for i in 11:
		for j in 9:
			var spot := Vector2(-14.0 + 2.8 * i, -7.2 + 1.8 * j)
			for td: int in [-1, 1]:
				for pos: String in Rules.POSITIONS:
					if Rules.offside(pos, spot, -td):
						continue
					tried += 1
					var q := Rules.out_of_play_spot(pos, -td, spot, td)
					var u := (Court.goal_post(td) - spot).normalized()
					var d := q.distance_to(spot)
					if d < 1.2 or d > 1.55 or (q - spot).dot(u) > 0.3 or Rules.offside(pos, q, -td):
						# (Wrong unless no such place exists there: a corner of her areas by a line.)
						var could := false
						for a in 72:
							for r: float in [1.2, 1.3, 1.4, 1.5]:
								var c := Rules.onside_point(pos, spot + Vector2.from_angle(TAU * a / 72.0) * r, -td, 0.05)
								if c.distance_to(spot) >= 1.2 and c.distance_to(spot) <= 1.55 and (c - spot).dot(u) <= 0.3:
									could = true
						if could:
							bad += 1
							worst = "%s at %s: %.2f m, %.2f in front" % [pos, spot, d, (q - spot).dot(u)]
						else:
							cramped += 1
	check(bad == 0, "penalty: the penalised player's place beside the thrower is 1.2-1.5 m off her, not in front, on her own ground, all over the court (%d of %d wrong: %s; %d where none fits)" % [bad, tried, worst, cramped])
	var m := _study_match(41)
	await _wait_live(m)
	for kind: String in ["contact", "held_ball", "throw_in", "contact", "obstruction"]:
		var guard := 0
		while (m.holder == null or m.phase != "live" or m.shot_info.has("by") or (m.holder.pos in ["GS", "GA"] and Court.in_circle(m.holder.landing, m.holder.dir))) and guard < 1200:
			await frames(1)
			guard += 1
		var h: Player = m.holder
		if h == null:
			check(false, "restarts: a player with the ball")
			break
		m.ai._decide[h] = 99.0
		var dm: Player = m.ai.marker_of(h)
		if kind == "throw_in":
			m._award(Rules.throw_in(1 - h.team, Vector2(clampf(h.p.x, -12.0, 12.0), Court.HALF_W)), null, "throw_in")
		elif kind == "held_ball":
			m._infringe("held_ball", h, h.p)   # (a free pass to the other side, where she stands)
		else:
			dm.p = h.landing + (Court.goal_post(-dm.dir) - h.landing).normalized() * 1.0
			m._infringe(kind, dm, dm.p)
		m.ai._decide.clear()   # (the taker passes when she would)
		guard = 0
		while m.phase != "live" and guard < 400:
			await frames(1)
			guard += 1
		var taker: Player = m.holder
		var out: Player = m.restart.get("out")
		var out_d := INF
		var out_front := -INF
		var near := INF
		var frames_n := 0
		while m.holder == taker and taker != null and m.phase == "live" and frames_n < 150:
			var u := (Court.goal_post(taker.dir) - taker.landing).normalized()
			if out:
				out_d = minf(out_d, out.p.distance_to(taker.landing))
				out_front = maxf(out_front, (out.p - taker.landing).dot(u))
			for o: Player in m.players[1 - taker.team]:
				if o != out and o.suspended <= 0.0:
					near = minf(near, o.p.distance_to(taker.landing))
			await frames(1)
			frames_n += 1
		var what := String(m.restart.get("kind", ""))
		print("  restart: %s (%s): penalised player %s m off, %s m in front; nearest other %.2f m; %d frames to the pass" % [kind, what,
			"%.2f" % out_d if out else "-", "%.2f" % out_front if out else "-", near, frames_n])
		check(taker != null and frames_n > 0, "restart after %s: taken (%s)" % [kind, what])
		if what == Rules.PENALTY:
			check((out == null and dm.suspended > 0.0) or out != null and out_d >= 1.15 and out_d <= 1.55 and out_front <= 0.3,
				"restart after %s: the penalised player beside the thrower, 1.2-1.5 m off, not in front (%.2f m, %.2f in front)" % [kind, out_d, out_front])
		check(near >= Court.DEFEND_DIST, "restart after %s (%s): nobody else within 0.9 m of the thrower until the pass (%.2f m)" % [kind, what, near])
		m.ai._decide.clear()
	# Open play: no AI defender is sent nearer than 0.9 m to the ball, and after a second of holding none is there.
	var aimed := INF
	var held_close := 0
	var held_n := 0
	for f in 900:
		await frames(1)
		var h: Player = m.holder
		if h == null or m.phase != "live":
			continue
		for o: Player in m.players[1 - h.team]:
			if o.away() or o.suspended > 0.0 or m.ai._give_way.has(o):
				continue
			aimed = minf(aimed, o.target.distance_to(h.landing))
			if m.hold_t > 1.0:
				held_n += 1
				if o.p.distance_to(h.landing) < Court.DEFEND_DIST:
					held_close += 1
	check(aimed >= Court.DEFEND_DIST, "open play: no defender is sent within 0.9 m of the ball (nearest %.2f m)" % aimed)
	check(held_n > 100 and held_close <= held_n / 100, "open play: after a second's hold, no defender within 0.9 m (%d of %d)" % [held_close, held_n])
	m.queue_free()
	await frames(2)


## Advantage on a contact (R7): the defender who made it steps clear of the shooter: past 1.5 m within a second and
## a half, and not between her and the post.
func _advantage_clear() -> void:
	var m := _study_match(38)
	await _wait_live(m)
	var guard := 0
	while (m.holder == null or m.phase != "live") and guard < 600:
		await frames(1)
		guard += 1
	var t := m.holder.team if m.holder else 0
	for k in 2:
		var gs: Player = m.player_at(t, "GS" if k == 0 else "GA")
		var gk: Player = m.player_at(1 - t, "GK" if k == 0 else "GD")
		var post := Court.goal_post(gs.dir)
		m.pass_info = {}
		m.shot_info = {}
		m._release_holder()
		gs.p = post + Vector2(-gs.dir * (3.0 if k == 0 else 2.2), 1.2 if k == 0 else -3.0)
		gs.vel = Vector2.ZERO
		gs.target = gs.p
		m._give(gs)
		m.ai._decide[gs] = 99.0
		var u := (post - gs.p).normalized()
		gk.p = gs.p + u * 0.7
		gk.vel = Vector2.ZERO
		gk.target = gk.p
		await frames(1)
		m.hold_t = 0.0
		m._advantage("contact", gk)
		var when := -1.0
		for f in 60:
			await frames(1)
			m.hold_t = 0.0
			if when < 0.0 and gk.p.distance_to(gs.p) > 1.5:
				when = (f + 1) / 30.0
		print("  advantage: the %s past 1.5 m from the %s in %.2f s, %.1f m after 2 s" % [gk.pos, gs.pos, when, gk.p.distance_to(gs.p)])
		var rel := gk.p - gs.p
		var along := rel.dot(u)
		var across := absf(rel.cross(u))
		var between := along > 0.0 and along < gs.p.distance_to(post) and across < 1.0
		check(m.holder == gs and when > 0.0 and when <= 1.5, "advantage: the %s steps clear of the %s (past 1.5 m in %.2f s, %.1f m after 2 s)"
			% [gk.pos, gs.pos, when, gk.p.distance_to(gs.p)])
		check(not between, "advantage: and not between the %s and the post (%.1f m along, %.1f across)" % [gs.pos, along, across])
	# Once the shooter lets the ball go, she plays on.
	m.ai._decide.clear()
	var free_again := false
	for f in 120:
		await frames(1)
		if m.ai._give_way.is_empty():
			free_again = true
			break
	check(free_again, "advantage: once the ball has gone she is back in play")
	m.queue_free()
	await frames(2)


## Level after extra time, play goes on to a two-goal lead: the goal that makes it ends the match (it went on for
## ever before: Rules.match_over was not asked).
func _two_goal_lead() -> void:
	var m := _study_match(39, {"need_winner": true})
	await _wait_live(m)
	var gs: Player = m.player_at(0, "GS")
	m.q = 7
	m.time_left = INF
	m.score = [20, 20]
	m.pass_info = {}
	m._release_holder()
	m._goal(gs, 1)
	var on: bool = m.phase == "goal"
	m.pass_info = {}
	m._release_holder()
	m._goal(gs, 1)
	check(on and m.phase == "over", "on to a two-goal lead: one goal up plays on, two up ends it (%s, %s)" % [m.score, m.phase])
	m.queue_free()
	await frames(2)


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
					# (Steps a second: a stride pair is two.)
					var pair: float = Gait.pair_length(spd) * pl.body.scale.x
					if 2.0 * spd / pair > 4.5 or not pl.gait.striding:
						stride_bad += 1
	check(twice == 0, "each player's position written once a frame (%d frames otherwise)" % twice)
	check(worst_jump <= 0.0001, "no player moves faster than she can run in a frame (worst over by %.3f m)" % worst_jump)
	check(stride_bad == 0, "strides keep pace with speed (no more than 4.5 steps a second, sprinting)")
	# The players are the owner's model (HeroBody), and the umpires too, in the umpires' kit (the owner: "the referees
	# look too much like block figures, not humans"); her bib carries her position's letters.
	var pl0: Player = m.players[0][0]
	check(pl0.body is HeroBody and pl0.body.skeleton.get_bone_count() == ToonBody.BONES.size(), "a player is drawn with the owner's model, on the game's bones")
	var um: ShaderMaterial = m.umpires[0].body.mesh_instance.material_override
	check(m.umpires[0].body is HeroBody and float(um.get_shader_parameter("umpire")) > 0.5 and int(um.get_shader_parameter("letter")) == -1,
		"an umpire is the players' model in the umpires' kit (no bib)")
	var mat: ShaderMaterial = pl0.body.mesh_instance.material_override
	check(mat.get_shader_parameter("letter") == ToonBody.LETTERS.find(pl0.pos) and mat.get_shader_parameter("letters") != null, "her bib carries her position's letters (%s)" % pl0.pos)
	var ran := false
	for f in 300:
		await get_tree().process_frame
		for t in 2:
			for pl in m.players[t]:
				if pl.act == "run" and pl.vel.length() > 4.5 and pl.gait.striding and pl.body.pose.get("thigh_l") is Quaternion:
					ran = true
		if ran:
			break
	check(ran, "a player running at speed strides (her legs reaching her feet on the floor: Gait)")
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
	# (The side-step is the gait's now, not the slide's motion capture: tested in _gait_steps.)
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


## The run, as drawn, on the game's own bodies (Low; Medium and High too without the licensed clips): a planted foot
## stays where it came down (its ball or heel on the floor moves less than GAIT_SLIP over a stance) at a jog and a
## sprint, for a player and an umpire, marking and defending on the move too; running, the elbows are bent and the
## hands kept by her sides (the owner's "players gliding around, not running, arms just stretched out when
## running"); pulling up from a sprint takes steps and ends with her feet under her; and in a match nobody's planted
## foot skates and nobody runs with her arms out.
const GAIT_SLIP := 0.03


func _gait_steps() -> void:
	var was: int = int(Game.settings.graphics)
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM]:
		Game.settings.graphics = g
		var lv := "Low" if g == Game.GFX_LOW else "Medium"
		var sq: Array = DB.squad("NZL")
		for case: Array in [["run", 3.5, 0.0], ["run", 6.8, 0.0], ["run", 7.2, 0.0], ["mark", 4.0, 1.0], ["defend", 3.0, 0.0], ["run", 5.0, -1.0], ["run", 2.5, -1.0]]:
			var pl := Player.new(0, sq[2], "WA")
			add_child(pl)
			await frames(1)
			pl.fenced = false
			pl.place(Vector2.ZERO, 0.0)
			var act: String = case[0]
			var spd: float = case[1]
			var go := Vector2(1, 0) if float(case[2]) > 0.0 else Vector2(0, 1)
			var look: float = case[2]
			var st := {"slip": 0.0, "bend_lo": 999.0, "bend_hi": 0.0, "out": 0.0, "abd": 0.0, "steps": 0}
			for f in 120:
				pl.set_act(act)
				pl.target = pl.p + go * 8.0
				pl.want_speed = spd
				pl.look_on = look != 0.0
				pl.look_at_p = pl.p + Vector2(0, 10) if look > 0.0 else pl.p - go * 10.0
				pl.advance(1.0 / 30.0)
				_gait_measure(pl.gait, pl.body, st, f >= 30, f >= 40)
			var what := "%s, a player %s at %.1f m/s%s" % [lv, "running" if act == "run" else act + "ing", pl.vel.length(),
				" (sideways, eyes on the ball)" if look > 0.0 else (" (the ball behind her)" if look < 0.0 else "")]
			check(st.slip < GAIT_SLIP, "%s: a planted foot moves %.1f cm at most" % [what, st.slip * 100.0])
			check(st.bend_lo > 45.0 and st.bend_hi < 125.0, "%s: elbows bent %.0f-%.0f deg" % [what, st.bend_lo, st.bend_hi])
			check(st.out < 0.12 and st.abd < 30.0, "%s: hands by her sides (%.0f cm out from the shoulder, the upper arm %.0f deg from her side)" % [what, st.out * 100.0, st.abd])
			print("gait: %s: slip %.1f cm, elbows %.0f-%.0f deg, hands %.0f cm out, upper arm %.0f deg out" % [what, st.slip * 100.0, st.bend_lo, st.bend_hi, st.out * 100.0, st.abd])
			if act == "run" and is_equal_approx(spd, 6.8):
				# Pulling up: a step or two, then her feet under her, still.
				var stop := {"slip": 0.0, "bend_lo": 999.0, "bend_hi": 0.0, "out": 0.0, "abd": 0.0, "steps": 0}
				# (The feet down as she pulls up are not steps: only those that come down after.)
				_gait_measure(pl.gait, pl.body, stop, true, false)
				stop.steps = 0
				for f in 50:
					pl.set_act("run")
					pl.target = pl.p
					pl.want_speed = 0.0
					pl.advance(1.0 / 30.0)
					_gait_measure(pl.gait, pl.body, stop, true, false)
				var under := 0.0
				for ft in pl.gait.feet:
					under = maxf(under, (ft as Gait.Foot).at.distance_to(pl.p))
				check(stop.steps >= 1 and stop.steps <= 5, "%s: pulling up from a sprint takes %d steps" % [lv, stop.steps])
				check(stop.slip < GAIT_SLIP, "%s: pulling up, a planted foot moves %.1f cm at most" % [lv, stop.slip * 100.0])
				check(under < 0.25 and pl.vel.length() < 0.01, "%s: stopped, her feet under her (%.2f m)" % [lv, under])
				print("gait: %s: pulling up from 6.8 m/s: %d steps, slip %.1f cm, feet %.2f m from her" % [lv, stop.steps, stop.slip * 100.0, under])
			pl.queue_free()
		# An umpire jogging her line and catching up with play, her eyes on the ball across the court.
		for spd: float in [Umpire.JOG, Umpire.SPEED]:
			var u := Umpire.new(-1)
			add_child(u)
			await frames(1)
			u.p = Vector2.ZERO
			u.position = Vector3.ZERO
			var st := {"slip": 0.0, "bend_lo": 999.0, "bend_hi": 0.0, "out": 0.0, "abd": 0.0, "steps": 0}
			for f in 120:
				u.pace = spd
				u.target = u.p + Vector2(4.0, 0)
				u.advance(1.0 / 30.0, u.p + Vector2(0, -10))
				_gait_measure(u.gait, u.body, st, f >= 30, f >= 40)
			var what := "%s, an umpire at %.1f m/s" % [lv, spd]
			check(st.slip < GAIT_SLIP, "%s: a planted foot moves %.1f cm at most" % [what, st.slip * 100.0])
			check(st.bend_lo > 45.0 and st.bend_hi < 125.0, "%s: elbows bent %.0f-%.0f deg" % [what, st.bend_lo, st.bend_hi])
			check(st.out < 0.12 and st.abd < 30.0, "%s: hands by her sides (%.0f cm, %.0f deg)" % [what, st.out * 100.0, st.abd])
			check(not u.gait.feet[0].down or not u.gait.feet[1].down or u.gait.striding, "%s: she strides (not gliding)" % what)
			print("gait: %s: slip %.1f cm, elbows %.0f-%.0f deg, hands %.0f cm out, upper arm %.0f deg out" % [what, st.slip * 100.0, st.bend_lo, st.bend_hi, st.out * 100.0, st.abd])
			u.queue_free()
		await frames(1)
	# In a match (Low): every planted foot of every player and umpire, and every runner's arms.
	Game.settings.graphics = Game.GFX_LOW
	for mc: Array in [["arena", 6], ["hall", 9]]:
		await _gait_in_match(mc[0], mc[1])
	Game.settings.graphics = was


func _gait_in_match(venue: String, seed: int) -> void:
	var m: Match = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "AUS", "away": "NZL", "venue": venue, "user_team": -1, "demo": true, "seed": seed, "quarter": 15, "mode": "quick"}
	add_child(m)
	await frames(5)
	var all := {}
	var people: Array = m.players[0] + m.players[1] + m.umpires
	for q in people:
		all[q] = {"slip": 0.0, "bend_lo": 999.0, "bend_hi": 0.0, "out": 0.0, "abd": 0.0, "steps": 0}
	var worst_arm := 0.0
	var worst_who := ""
	var worst_slip := 0.0
	var slip_who := ""
	var runs := 0
	for f in 600:
		await get_tree().process_frame
		if m.phase in ["setup", "goal", "break"] and m.phase_t < 0.1:
			for q in people:
				all[q].erase("at_l")
				all[q].erase("at_r")
		for q in people:
			var running: bool = q.vel.length() > 3.0 and (not (q is Player) or q.act in ["run", "mark", "post", "ready", "defend", "defend_shot", "out_of_play", "huddle"])
			var st: Dictionary = all[q]
			var abd0: float = st.abd
			var slip0: float = st.slip
			# (Her feet measured while they are the gait's: not in a leap or the landing's motion capture.)
			var own: bool = not (q is Player) or (q.legs_w > 0.99 and q.land_w <= 0.0)
			_gait_measure(q.gait, q.body, st, own, running)
			if st.slip > slip0 and st.slip > worst_slip:
				worst_slip = st.slip
				slip_who = "%s (%s, %.1f m/s, f %d)" % [q.pos if q is Player else "umpire", q.act if q is Player else "", q.vel.length(), f]
			if running:
				runs += 1
			if st.abd > abd0 and st.abd > worst_arm:
				worst_arm = st.abd
				worst_who = "%s (%s, %.1f m/s)" % [q.pos if q is Player else "umpire", q.act if q is Player else "", q.vel.length()]
	var slip := 0.0
	var out := 0.0
	for q in people:
		slip = maxf(slip, all[q].slip)
		out = maxf(out, all[q].out)
	check(runs > 200, "a match (Low, %s): players and umpires run (%d frames)" % [venue, runs])
	check(slip < GAIT_SLIP, "a match (Low, %s): no planted foot moves more than %.1f cm (%s)" % [venue, slip * 100.0, slip_who])
	check(worst_arm < 30.0 and out < 0.12, "a match (Low, %s): nobody runs with her arms out (worst: %.0f deg, %.0f cm, %s)" % [venue, worst_arm, out * 100.0, worst_who])
	print("gait: a match (Low, %s): slip %.1f cm at most; arms %.0f deg out at most (%s), hands %.0f cm" % [venue, slip * 100.0, worst_arm, worst_who, out * 100.0])
	m.queue_free()
	await frames(2)


## One frame of a body's gait into st: the furthest a planted foot's contact (the ball or the heel on the floor) has
## moved since it came down (slip, when feet), how many feet came down (steps); and when arms, the elbows' bend, how
## far a hand is out from its shoulder (across her), and how far the upper arm is lifted out from her side (abd).
func _gait_measure(g: Gait, b: ToonBody, st: Dictionary, feet: bool, arms: bool) -> void:
	if int(st.get("epoch", -1)) != g.epoch:
		st.epoch = g.epoch
		st.erase("at_l")
		st.erase("at_r")
	for i in 2:
		var s := "l" if i == 0 else "r"
		var ft: Gait.Foot = g.feet[i]
		var c := g.contact(s)
		var bl := g.contact(s, true)
		if ft.down and feet:
			if not st.has("at_" + s):
				st["at_" + s] = Vector2(c.x, c.z)
				st["ball_" + s] = Vector2(bl.x, bl.z)
				st.steps += 1
			# (Rolling heel to toe keeps the spot under the ankle; pivoting keeps the ball of the foot: either stays.)
			st.slip = maxf(st.slip, minf(Vector2(c.x, c.z).distance_to(st["at_" + s]), Vector2(bl.x, bl.z).distance_to(st["ball_" + s])))
		else:
			st.erase("at_" + s)
	if not arms:
		return
	# (Against her chest: the arms' swing, not the turn of her shoulders to the ball.)
	var bz := (b.skeleton.global_transform * b.skeleton.get_bone_global_pose(b.bone("chest"))).basis
	var left := (bz.x).normalized()
	var up := (bz.y).normalized()
	for s in ["l", "r"]:
		var sh := b.bone_world("upperarm_" + s)
		var el := b.bone_world("forearm_" + s)
		var wr := b.bone_world("hand_" + s)
		var bend := rad_to_deg((el - sh).angle_to(wr - el))
		st.bend_lo = minf(st.bend_lo, bend)
		st.bend_hi = maxf(st.bend_hi, bend)
		var sx := 1.0 if s == "l" else -1.0
		st.out = maxf(st.out, (wr - sh).dot(left) * sx)
		var ua := el - sh
		st.abd = maxf(st.abd, rad_to_deg(atan2(ua.dot(left) * sx, -ua.dot(up))))


## Your controls: a scripted thumb plays a match as the team. With the ball it picks a team-mate and passes (or
## shoots when it may); in defence it switches to the defender nearest the ball and runs at the ball. Nothing is
## played for you: a thumb that does nothing gets called for held ball.
## The stick is the screen's in every camera (the owner: "switching to a camera angle not alongside the court, the
## joystick movement is all wrong"): pushed up, right, down or left, your player goes that way on the screen (within
## 10 degrees), from the broadcast camera, the courtside one and from behind either goal.
func _stick_camera() -> void:
	var keep_cam: int = int(Game.settings.camera)
	var keep_ctl: int = int(Game.settings.control)
	var keep_bib: String = String(Game.settings.bib)
	Game.settings.control = Game.CONTROL_BIB
	Game.settings.bib = "WD"
	# The screen as it stood when she set off (the camera follows the ball meanwhile): a still copy of the camera.
	var still := Camera3D.new()
	add_child(still)
	for cm in [[Game.CAM_TV, 0], [Game.CAM_LOW, 0], [Game.CAM_END, 0], [Game.CAM_END, 1]]:
		Game.settings.camera = cm[0]
		var m: Match = (load("res://game/match.gd") as Script).new()
		m.config = {"home": "ENG", "away": "WAL", "venue": "hall", "user_team": cm[1], "seed": 7, "quarter": 15, "mode": "quick", "difficulty": 1}
		add_child(m)
		var waited := 0
		while m.phase != "live" and waited < 400:
			waited += 1
			await get_tree().process_frame
		var worst := 0.0
		for d in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(1, -1).normalized(),
				Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(-1, -1).normalized()]:
			var off := 180.0
			# (A sample cut by a whistle or a restart, which puts everyone back on her spot, is taken again.)
			for attempt in 4:
				while m.phase != "live":
					await get_tree().process_frame
				var me: Player = m.me
				# In her own half of the centre third, room to move every way (she does not have the ball).
				me.place(Vector2(-me.dir * 2.4, 0.0), 0.0)
				for f in 20:
					m.controls.joystick = Vector2.ZERO
					await get_tree().process_frame
				var cam3 := get_viewport().get_camera_3d()
				still.global_transform = cam3.global_transform
				still.fov = cam3.fov
				var a: Vector2 = still.unproject_position(me.global_position)
				var cut := false
				for f in 18:
					m.controls.joystick = d
					await get_tree().process_frame
					cut = cut or m.phase != "live" or m.me != me
				var moved: Vector2 = still.unproject_position(me.global_position) - a
				if OS.get_cmdline_user_args().has("stick"):
					print("cam %d team %d stick %s: moved %s%s" % [cm[0], cm[1], d, moved, " (cut)" if cut else ""])
				if cut:
					continue
				off = rad_to_deg(absf(angle_difference(moved.angle(), d.angle()))) if moved.length() > 2.0 else 180.0
				break
			worst = maxf(worst, off)
		if cm[0] == Game.CAM_TV:
			# The camera changing mid-run (to behind the goal): the stick's way turns over about 0.2 s, not at once.
			var at := Vector3(m.me.p.x, 0.0, m.me.p.y)
			var before: Vector2 = m.cam.court_dir(Vector2(1, 0), at)
			m.cam.set_mode(Game.CAM_END)
			await get_tree().process_frame
			var first: Vector2 = m.cam.court_dir(Vector2(1, 0), at)
			for f in 12:
				await get_tree().process_frame
			var after: Vector2 = m.cam.court_dir(Vector2(1, 0), at)
			var turn := absf(angle_difference(before.angle(), after.angle()))
			check(turn > 0.5 and absf(angle_difference(before.angle(), first.angle())) < turn * 0.6,
				"a new camera turns the stick's way over a moment, not at once (%.0f of %.0f deg in the first frame)" %
				[rad_to_deg(absf(angle_difference(before.angle(), first.angle()))), rad_to_deg(turn)])
			m.cam.set_mode(Game.CAM_TV)
		m.controls.joystick = Vector2.ZERO
		check(worst <= 10.0, "camera %d (team %d): the stick moves your player that way on the screen (worst %.1f deg)" % [cm[0], cm[1], worst])
		m.queue_free()
		await get_tree().process_frame
	still.queue_free()
	Game.settings.camera = keep_cam
	Game.settings.control = keep_ctl
	Game.settings.bib = keep_bib

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
	# (Till 300 such frames are seen, or three minutes: a few dozen frames are too few to judge a share by.)
	for f in 5400:
		if deep >= 300:
			break
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
	# Back from what the pause menu opens goes back to it (soak test: Back resumed the match with the buttons still
	# being moved, or the rolling changes still over it).
	m.hud._move_buttons()
	await frames(2)
	Game.go_back()
	await frames(2)
	check(m.paused and m.hud._layout_panel == null and not m.controls.editing and m.hud._pause != null,
		"Back while moving buttons goes back to the pause menu")
	m.hud.show_pause(false)
	m.hud._rolling_changes()
	await frames(2)
	Game.go_back()
	await frames(2)
	check(m.paused and m.hud._changes_layer == null and m.hud._pause != null, "Back from rolling changes goes back to the pause menu")
	m.set_paused(false)
	# The home button, the screen going off, another window: the match pauses and waits for Resume.
	for n in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		Game.notification(n)
		check(m.paused, "notification %d pauses the match" % n)
		m.set_paused(false)
	Game.goto_menu()
	await frames(3)


## Every spectator faces the court (the owner's report: the near stand's crowd looked the wrong way), sits on a seat
## or stands on the floor (the owner's: people standing awkwardly inside their seats), in every venue: on High the
## shared foundation's 3D people, on Low its cards, both where the venue declares them (CrowdVenues; the foundation's
## crowd audit measures each body against its seat: tools/wsg/crowd_audit.gd). Each person, as drawn, faces the play
## (within 35 degrees of its nearest part, as the audit has it, and within 60 of the court's middle); seated ones on a
## seat 0.25-0.5 m over their feet, standing ones on the ground outdoors. People within 6 m of the camera are left out
## (a camera just behind a crowd), and only they.
func _crowd_facing() -> void:
	var was: int = int(Game.settings.graphics)
	for g in [Game.GFX_LOW, Game.GFX_HIGH]:
		Game.settings.graphics = g
		for venue in ["arena", "hall", "outdoor"]:
			var m: Match = (load("res://game/match.gd") as Script).new()
			m.config = {"home": "ENG", "away": "WAL", "venue": venue, "user_team": -1, "demo": true, "seed": 3, "quarter": 15, "mode": "quick"}
			add_child(m)
			await frames(3)
			var crowds := m.find_children("*", "Crowd", true, false)
			var n := 0
			var bad := 0
			var as_cards := 0
			var off := 0
			for c: Crowd in crowds:
				for e: Array in c.everyone():
					var xf: Transform3D = e[0]
					var f: Vector3 = e[1]
					var mid := Vector2(-xf.origin.x, -xf.origin.z).normalized()
					var near := c.venue.nearest_play(xf.origin, minf(c.venue.play_size.x, c.venue.play_size.y) / 3.0) - xf.origin
					var play := Vector2(near.x, near.z).normalized()
					n += 1
					as_cards += 1 if e[2] else 0
					# The way the place faces, and the body as placed.
					for d: Vector2 in [Vector2(f.x, f.z).normalized(), Vector2(xf.basis.z.x, xf.basis.z.z).normalized()]:
						if d.dot(play) < cos(deg_to_rad(35.5)) or d.dot(mid) < 0.5:
							bad += 1
							break
				for i in c.placed.spots.size():
					var seat: float = c.placed.seat[i]
					if venue == "outdoor" and (seat != 0.0 or absf(float(c.placed.floor[i])) > 0.01) or venue != "outdoor" and (seat < 0.25 or seat > 0.5):
						off += 1
			var lv := "Low" if g == Game.GFX_LOW else "High"
			check(n > 0 and bad == 0, "%s, %s: every spectator faces the court (%d of %d do not)" % [lv, venue, bad, n])
			check(as_cards == (n if g == Game.GFX_LOW else 0), "%s, %s: %s (%d cards of %d)" % [lv, venue,
				"cards" if g == Game.GFX_LOW else "3D people", as_cards, n])
			check(off == 0, "%s, %s: every spectator stands on the ground or sits on a seat (%d off)" % [lv, venue, off])
			if g == Game.GFX_LOW and venue == "outdoor" and not crowds.is_empty():
				# A camera just behind the near side's crowd: the cards within 6 m of it left out, no others.
				var c: Crowd = crowds[0]
				var at := Vector3(-12.0, 1.7, Court.HALF_W + Court.RUNOFF + 3.0)
				c._hide_for(at)
				var hid := 0
				var wrong := 0
				for k in c.cards.placed_cards.size():
					var p: Vector3 = c.cards.placed_cards[k][1].origin
					var hidden := c._hidden.has(Vector2i(c._groups.size() - 1, k))
					hid += 1 if hidden else 0
					if hidden != (Vector2(p.x - at.x, p.z - at.z).length() < Crowd.NEAR_HIDE):
						wrong += 1
				check(hid > 0 and wrong == 0, "Low, outdoor: the cards near the camera left out, no others (%d left out, %d wrong)" % [hid, wrong])
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
## 0.6.0-beta): Low loads exactly these, at these sizes; Medium and High load the sharper copies (Game.HD_TEX). Since the
## crowd placement (after 0.8.8) Low has a crowd in every venue, the shared foundation's cards (CrowdVenues): their
## four sheets (cards.png, cards_mask.png and the same from behind, cards_back*.png) are the only textures added.
const LOW_TEXTURES := {
	"arena": ["<ImageTexture> 128x64", "res://addons/wsg_foundation/crowd/cards.png 768x768",
		"res://addons/wsg_foundation/crowd/cards_back.png 768x768", "res://addons/wsg_foundation/crowd/cards_back_mask.png 768x768",
		"res://addons/wsg_foundation/crowd/cards_mask.png 768x768", "res://assets/player/hero_albedo.jpg 1024x1024", "res://assets/player/hero_mask.png 512x512",
		"res://assets/ui/bib_letters.png 896x128", "res://assets/venue/arena_atlas.jpg 1024x2048",
		"res://assets/venue/surfaces/white_maple_veneer_albedo_1k.jpg 1024x1024"],
	"hall": ["<ImageTexture> 128x64", "res://addons/wsg_foundation/crowd/cards.png 768x768",
		"res://addons/wsg_foundation/crowd/cards_back.png 768x768", "res://addons/wsg_foundation/crowd/cards_back_mask.png 768x768",
		"res://addons/wsg_foundation/crowd/cards_mask.png 768x768", "res://assets/player/hero_albedo.jpg 1024x1024", "res://assets/player/hero_mask.png 512x512",
		"res://assets/ui/bib_letters.png 896x128", "res://assets/venue/hall_atlas.jpg 1024x1024",
		"res://assets/venue/surfaces/ceiling_interior_albedo_1k.jpg 1024x1024",
		"res://assets/venue/surfaces/concrete_block_wall_normal_1k.jpg 1024x1024",
		"res://assets/venue/surfaces/white_maple_veneer_albedo_1k.jpg 1024x1024"],
	"outdoor": ["<ImageTexture> 128x64", "res://addons/wsg_foundation/crowd/cards.png 768x768",
		"res://addons/wsg_foundation/crowd/cards_back.png 768x768", "res://addons/wsg_foundation/crowd/cards_back_mask.png 768x768",
		"res://addons/wsg_foundation/crowd/cards_mask.png 768x768", "res://assets/player/hero_albedo.jpg 1024x1024", "res://assets/player/hero_mask.png 512x512",
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
				var cr: Crowd = m.arena.crowd
				check(cr != null and cr.people == null and cr.cards != null, "Low, %s: the crowd as cards, no 3D people" % venue)
			else:
				var hd := 0
				for t in got:
					for k in Game.HD_TEX:
						if t.begins_with(Game.tex_path(k, g) + " ") and Game.tex_path(k, g) != k:
							hd += 1
						check(not t.begins_with(String(k) + " "), "High, %s: not the Low copy of %s" % [venue, k])
				check(hd >= 3, "High, %s: the sharper textures (%d)" % [venue, hd])
				var cr: Crowd = m.arena.crowd
				check(cr != null and cr.people != null and not cr.people.meshes.is_empty(), "High, %s: the crowd's 3D people" % venue)
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


## The match study's venue and broadcast (docs/MATCH_STUDY.md): indoors on Medium and High, LED boards, the floor's
## wordmark and the goal lights in one draw call of their own, none of it on Low or outdoors; the goal light flashes
## at the post scored in; the TV camera's close shot of the post for every shot in an AI v AI match, in yours only
## after a goal, steering unchanged; the team card from the menus, skippable, again at half-time; the scoreboard's
## quarter and clock.
func _venue_study() -> void:
	var was: int = int(Game.settings.graphics)
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM]:
		Game.settings.graphics = g
		for venue in ["arena", "hall", "outdoor"]:
			var m: Match = (load("res://game/match.gd") as Script).new()
			m.config = {"home": "AUS", "away": "NZL", "venue": venue, "user_team": -1, "demo": true, "seed": 4, "quarter": 15, "mode": "quick"}
			add_child(m)
			await frames(2)
			var boards: MeshInstance3D = m.arena.get_node_or_null("Boards")
			var want: bool = g != Game.GFX_LOW and venue != "outdoor"
			check((boards != null) == want, "%s, graphics %d: LED boards %s" % [venue, g, "there" if want else "left out"])
			if boards and want:
				var mat := boards.material_override as ShaderMaterial
				check(mat.get_shader_parameter("msgs") is Texture2D, "%s: the boards' messages are loaded" % venue)
				check(boards.mesh.get_surface_count() == 1, "%s: boards, wordmark and goal lights are one draw call" % venue)
				m.game_event.emit("goal", {"team": 1, "by": "GS", "value": 1})
				await frames(2)
				var gt: float = mat.get_shader_parameter("goal_t")
				check(gt > 0.0 and gt < 1.0 and is_equal_approx(float(mat.get_shader_parameter("goal_side")), float(m.team_dir(1))),
					"%s: a goal flashes the goal light at the post scored in (t %.2f)" % [venue, gt])
				m.arena._goal_t = 5.99
				await frames(3)
				check(float(mat.get_shader_parameter("goal_t")) > 50.0, "%s: and the boards go back to their programme" % venue)
			m.queue_free()
			await frames(2)
	Game.settings.graphics = was
	# The close shot of the post.
	for demo in [true, false]:
		var m: Match = (load("res://game/match.gd") as Script).new()
		m.config = {"home": "AUS", "away": "NZL", "venue": "arena", "user_team": -1 if demo else 0, "demo": demo, "seed": 4,
			"quarter": 15, "mode": "quick"}
		add_child(m)
		await frames(3)
		m.cam.set_mode(Game.CAM_TV)
		var wide: Vector2 = m.cam.court_dir(Vector2(1, 0))
		var gs: Player = m.player_at(0, "GS")
		m.phase = "live"
		m.shot_info = {"by": gs, "goal": true, "value": 1, "dist": 2.0, "t": 0.0, "released": false}
		m.cam.track(m.ball.court_pos(), gs.dir, 1.0 / 30.0)
		check(m.cam.close_dir == (gs.dir if demo else 0), "a shot: the close shot of the post %s (%d)" % ["in an AI v AI match" if demo else "not in yours, mid-play", m.cam.close_dir])
		m.shot_info = {}
		m.phase = "goal"
		m.phase_t = 0.2
		m.ball.dead(Court.ring_centre(gs.dir) - Vector3(0, 1.0, 0))
		m.cam.track(m.ball.court_pos(), 0, 1.0 / 30.0)
		check(m.cam.close_dir == gs.dir, "a goal: the close shot of the post it went through (%d)" % m.cam.close_dir)
		check(m.cam.fov < 30.0 and m.cam.global_position.distance_to(Court.ring_centre(gs.dir)) < 15.0, "the close shot is close")
		check(m.cam.court_dir(Vector2(1, 0)).distance_to(wide) < 0.15, "the stick steers as on the wide shot through a close-up")
		m.phase_t = 2.0
		for i in 30:
			m.cam.track(m.ball.court_pos(), 0, 1.0 / 30.0)
		check(m.cam.close_dir == 0 and m.cam.fov > 30.0, "then back to the wide shot")
		m.cam.set_mode(Game.CAM_LOW)
		m.phase_t = 0.2
		m.cam.track(m.ball.court_pos(), 0, 1.0 / 30.0)
		check(m.cam.close_dir == 0, "no close-ups on the courtside camera")
		m.queue_free()
		await frames(2)
	# The team card, and the scoreboard.
	for card in [true, false]:
		var m: Match = (load("res://game/match.gd") as Script).new()
		m.config = {"home": "ENG", "away": "WAL", "venue": "hall", "user_team": 0, "seed": 5, "quarter": 15, "mode": "cup",
			"stage": tr("STAGE_SEMI"), "card": card}
		add_child(m)
		await frames(15)
		var c: TeamCard = m.hud.card
		check((c != null and is_instance_valid(c)) == card, "the team card %s" % ("opens a match from the menus" if card else "only from the menus"))
		if card:
			var texts := []
			for n in c.find_children("*", "Label", true, false):
				texts.append((n as Label).text)
			check(DB.team_name("ENG") in texts and DB.team_name("WAL") in texts and tr("VENUE_HALL") in texts
				and TeamCard.competition(m.config) in texts, "it names both teams, the competition and stage, and the venue (%s)" % [texts])
			check(c.modulate.a > 0.3, "it fades in")
			await frames(100)
			check(not is_instance_valid(c), "it goes after a couple of seconds")
			m.hud.show_break(2, 3)
			await frames(2)
			c = m.hud.card
			check(is_instance_valid(c) and c.half_time, "half-time brings it back, with the score")
			var tap := InputEventMouseButton.new()
			tap.button_index = MOUSE_BUTTON_LEFT
			tap.pressed = true
			c._gui_input(tap)
			await frames(20)
			check(not is_instance_valid(c), "a tap skips it")
			m.hud.hide_break()
		var hud = m.hud
		hud._process(0.0)
		check(hud._period_l.text == hud.period_name(m.q) and hud._period_l.text != "", "the scoreboard shows the quarter (%s)" % hud._period_l.text)
		check(hud._clock_l.text == "%d:%02d" % [int(m.time_left) / 60, int(m.time_left) % 60], "and the clock counting down (%s)" % hud._clock_l.text)
		m.queue_free()
		await frames(2)


# ---------------------------------------------------------------- the shared foundation (FoundationLink)

## With the licensed clip library (a build that has it; not CI's), on Medium and High every player, both umpires and
## the reserves are drawn by the shared foundation on the owner's model: a link each, its body shown and the game's
## hidden, posed (every frame near the camera, every 2nd or 3rd far from it); the ball in a player's hands is in the
## drawn hands (both palms on it) and drawn where they hold it. On Low nobody has one (the game's own bodies), nor
## anywhere without the clips.
func _foundation(available: bool) -> void:
	var was: int = int(Game.settings.graphics)
	Game.settings.graphics = Game.GFX_LOW
	var low := _study_match(41)
	await frames(3)
	var any := false
	for who in low.players[0] + low.players[1] + low.umpires:
		any = any or who.link != null
	check(not any and low.wsg_replay == null, "foundation: Low draws the game's own bodies (no links, no replay)")
	low.queue_free()
	await frames(2)
	Game.settings.graphics = Game.GFX_MEDIUM
	var m := _study_match(42)
	await frames(3)
	var people: Array = m.players[0] + m.players[1] + m.umpires
	if not available:
		check(people.all(func(p): return p.link == null) and m.wsg_replay == null, "foundation off (no licensed clips): nobody has a link, the game draws as before")
		m.queue_free()
		await frames(2)
		Game.settings.graphics = was
		return
	var posed := {}
	for who in people:
		if who.link:
			who.link.measure = true
			posed[who] = 0
			who.link.body.posed.connect(func(): posed[who] += 1)
	var res: Node = m.get_node_or_null("Reserves")
	var res_links := 0
	if res:
		for c in res.get_children():
			if c is FoundationLink and c.body.visible:
				res_links += 1
	await _wait_live(m)
	var missing := []
	var shown := []
	for who in people:
		if who.link == null or who.link.body == null:
			missing.append(who.name)
		elif not who.link.body.is_visible_in_tree() or who.body.mesh_instance.visible:
			shown.append(who.name)
	check(missing.is_empty(), "foundation: a link for every player and both umpires (%s)" % [missing])
	check(shown.is_empty(), "foundation: its body drawn, the game's hidden (%s)" % [shown])
	check(res_links == m.bench[0].size() + m.bench[1].size() and res_links > 0, "foundation: the reserves on the player's model (%d)" % res_links)
	# The ball in the drawn hands, over some seconds of play.
	var held := 0
	var off_hands := 0
	var off_ball := 0
	var gap := 0.0
	var stacked := 0
	var drift := 0.0
	for i in 600:
		await frames(1)
		# Each drawn body where its player is: its hips near her place in the game, and no two drawn together while
		# their players are apart (a body drawn at another player's place).
		# (Not in a replay: the bodies are where they were then.)
		var drawn: Array = [] if m.phase == "replay" else (m.players[0] + m.players[1]).filter(func(q): return q.link and q.link.body.is_visible_in_tree())
		var hips := {}
		for q: Player in drawn:
			var hp: Vector3 = q.link.body.bone_world("Hips").origin
			hips[q] = Vector2(hp.x, hp.z)
			var dq := (hips[q] as Vector2).distance_to(Vector2(q.position.x, q.position.z))
			if dq > 0.35 and drift <= 0.35:
				print("  drawn off her place: %s%d %.2f m, phase %s, act %s, mode %s" % [q.pos, q.team, dq, m.phase, q.act, q.link.mode])
			drift = maxf(drift, dq)
		for a_i in drawn.size():
			for b_i in range(a_i + 1, drawn.size()):
				var qa: Player = drawn[a_i]
				var qb: Player = drawn[b_i]
				if (hips[qa] as Vector2).distance_to(hips[qb]) < 0.3 and qa.position.distance_to(qb.position) > 0.6:
					stacked += 1
					if stacked <= 3:
						print("  drawn together: %s%d and %s%d, %.2f m apart in the game, phase %s" % [qa.pos, qa.team, qb.pos, qb.team, qa.position.distance_to(qb.position), m.phase])
		var h: Player = m.ball.holder
		if m.ball.state != "held" or h == null or h.link == null or not h.link.holding:
			continue
		held += 1
		var lh: Dictionary = h.link.last_hands
		if float(lh.get("Left", 1.0)) > 0.015 or float(lh.get("Right", 1.0)) > 0.015:
			off_hands += 1
			if off_hands <= 6:
				print("  palm off the ball: %s %s t=%.2f L %.1f cm R %.1f cm, mode %s, full %s" % [h.pos, h.act, h.act_t,
					float(lh.get("Left", 1.0)) * 100.0, float(lh.get("Right", 1.0)) * 100.0, h.link.mode, h.link.body.full])
		if m.ball.position.distance_to(h.link.ball_at) > 0.002:
			off_ball += 1
		gap = maxf(gap, m.ball.position.distance_to(h.game_hand_point()))
	check(held > 100 and off_hands <= held / 50, "foundation: both palms on the ball (%d of %d frames off it by over 1.5 cm)" % [off_hands, held])
	check(off_ball == 0, "foundation: the ball drawn where the drawn hands hold it (%d of %d frames not)" % [off_ball, held])
	check(stacked == 0 and drift < 0.35, "foundation: every body drawn at its own player's place (hips at most %.2f m off it; %d drawn pairs together while apart)" % [drift, stacked])
	print("foundation: %d frames held; the drawn ball at most %.1f cm from the game's own hands" % [held, gap * 100.0])
	var still := []
	for who in people:
		if who.visible and posed.has(who) and int(posed[who]) < 150:
			still.append("%s %d" % [who.name, posed[who]])
	check(still.is_empty(), "foundation: everyone posed through play (%s)" % [still])
	# The graphics lowered to Low mid-match (WsgAutoTier): the game's own bodies again, no reserves, no replay.
	Game.settings.auto_gfx = true
	m.lower_graphics()
	await frames(3)
	var back := true
	for who in people:
		back = back and who.link == null and who.body.mesh_instance.visible
	check(back and m.get_node_or_null("Reserves") == null and m.wsg_replay == null and m.find_children("Foundation", "", true, false).is_empty(),
		"foundation: lowered to Low mid-match, the game's own bodies again (no links, reserves or replay)")
	Game.settings.graphics = Game.GFX_MEDIUM
	m.queue_free()
	await frames(2)
	Game.settings.graphics = was


## The bodies on every path (the owner's notes of 0.8.6: feet that float, a shooter facing away, the ball in the
## forearms, a rigid stance, block umpires).
func _body_checks() -> void:
	await _foundation_steps()
	await _shots_and_hands()


## Every shot in AI matches, on Low and (with the licensed clips) Medium: the shooter's drawn body faces the post from
## her set to the release (within SHOT_FACE; the owner: "a player shooting, the woman facing the wrong direction and
## not at the hoop"); and every frame the ball is held, the ball in her hands, not her forearms: Low, each palm's skin
## within HAND_GAP of the ball's surface and neither forearm (elbow to wrist) inside the ball; the foundation's body,
## each palm on the ball (its ball centre within HAND_GAP of the drawn ball's) and its forearms clear of it.
const SHOT_FACE := 20.0
const HAND_GAP := 0.02


func _shots_and_hands() -> void:
	var was: int = int(Game.settings.graphics)
	var was_off := FoundationLink.off
	var levels := [Game.GFX_LOW]
	if WsgClips.available() and ResourceLoader.exists(FoundationLink.DIR + "hero_rig.json"):
		levels.append(Game.GFX_MEDIUM)
	for g in levels:
		Game.settings.graphics = g
		FoundationLink.off = g == Game.GFX_LOW
		var lv := "Low" if g == Game.GFX_LOW else "Medium (the foundation)"
		var shots := 0
		var face_worst := 0.0
		var face_frames := 0
		var held := 0
		var palm_worst := 0.0
		var arm_near := INF
		var off_n := 0
		var off_by := {}
		var palm_who := ""
		var who := ""
		for seed in [11, 12]:
			var m := _study_match(seed, {"venue": "hall" if seed == 12 else "arena"})
			await frames(3)
			var shooter: Player = null
			for f in 2700:
				await get_tree().process_frame
				if m.phase == "replay":
					continue
				var h: Player = m.holder
				if h and h.act == "shoot" and h.has_ball():
					if shooter != h:
						shots += 1
						shooter = h
					if h.act_t >= 0.25:
						# Her body as drawn: the foundation's when it draws her, else the game's.
						var bz: Vector3 = h.link.body.global_transform.basis.z if h.link and h.link.body.visible else h.body.global_transform.basis.z
						var post := Court.goal_post(h.dir)
						var err := absf(rad_to_deg(angle_difference(atan2(bz.x, bz.z), atan2(post.x - h.p.x, post.y - h.p.y))))
						face_frames += 1
						if err > face_worst:
							face_worst = err
							who = "%s, %.2f s into the shot" % [h.pos, h.act_t]
				else:
					shooter = null
				if h == null or not h.has_ball() or m.ball.state != "held":
					continue
				var c: Vector3 = m.ball.position
				if g == Game.GFX_LOW:
					held += 1
					for s in ["l", "r"]:
						var ht := h.body.skeleton.global_transform * h.body.skeleton.get_bone_global_pose(h.body.bone("hand_" + s))
						var palm := ht * Player.PALM
						var skin := absf(palm.distance_to(c) - Ball.R - Player.PALM_T * h.body.scale.x)
						if skin > HAND_GAP:
							off_n += 1
						if skin > palm_worst:
							palm_who = "%s %s t %.2f land %.2f" % [h.pos, h.act, h.act_t, h.land_w]
						palm_worst = maxf(palm_worst, skin)
						var e := h.body.bone_world("forearm_" + s)
						var w := h.body.bone_world("hand_" + s)
						arm_near = minf(arm_near, c.distance_to(Geometry3D.get_closest_point_to_segment(c, e, w)))
				elif h.link:
					h.link.measure = true
					if h.link.holding and not h.link.last_hands.is_empty():
						held += 1
						var pw := maxf(float(h.link.last_hands.get("Left", 0.0)), float(h.link.last_hands.get("Right", 0.0)))
						if pw > HAND_GAP:
							off_n += 1
							var key := "%s@%.1f" % [h.act, snappedf(h.act_t, 0.1)]
							off_by[key] = int(off_by.get(key, 0)) + 1
						if pw > palm_worst:
							palm_who = "%s %s t %.2f land %.2f mode %s w %.2f" % [h.pos, h.act, h.act_t, h.land_w, h.link.mode, h.link.legacy.weight]
						palm_worst = maxf(palm_worst, pw)
						arm_near = minf(arm_near, float(h.link.last_hands.get("forearm", INF)))
				if shots >= 6 and f > 900:
					break
			m.queue_free()
			await frames(2)
		check(shots >= 3 and face_frames > 0 and face_worst < SHOT_FACE, "%s: every shooter faces the post as she shoots (%d shots, %.0f deg off at most: %s)" % [lv, shots, face_worst, who])
		check(held > 200 and palm_worst < HAND_GAP and arm_near > Ball.R * 0.98, "%s: the ball in her hands (%d frames held: a palm %.1f cm off the ball at most, a forearm %.1f cm from its centre at nearest, the ball's radius %.1f cm)" % [lv, held, palm_worst * 100.0, arm_near * 100.0, Ball.R * 100.0])
		if not off_by.is_empty():
			print("body: palms off by move: ", off_by)
		print("body: %s: %d shots, the shooter %.1f deg off the post at most; %d frames held, a palm %.1f cm off the ball at most (%s; %d frames over %.0f cm), a forearm %.1f cm from its centre at nearest" % [lv, shots, face_worst, held, palm_worst * 100.0, palm_who, off_n, HAND_GAP * 100.0, arm_near * 100.0])
	Game.settings.graphics = was
	FoundationLink.off = was_off


## The run as the shared foundation draws it (Medium and High with the licensed clips; skipped without them, as on
## CI's machines without the library): a drawn foot on the floor stays where it came down (its ankle or its toe moves
## less than LINK_SLIP over the time it is down), running at a jog, a run and a sprint, side-stepping, defending on the
## move, passing on the run and pulling up; and in AI matches, every player's drawn feet, whatever her move, near the
## camera or far from it (posed every 2nd or 3rd frame). The owner's "players floating around and not moving legs".
const LINK_SLIP := 0.05


func _foundation_steps() -> void:
	if not WsgClips.available() or not ResourceLoader.exists(FoundationLink.DIR + "hero_rig.json"):
		print("foundation steps: skipped (no licensed clips here)")
		return
	var was_off := FoundationLink.off
	FoundationLink.off = false
	var was: int = int(Game.settings.graphics)
	Game.settings.graphics = Game.GFX_MEDIUM
	var sq: Array = DB.squad("NZL")
	for case: Array in [["run", 2.0, 0.0], ["run", 3.5, 0.0], ["run", 5.0, 0.0], ["run", 6.8, 0.0], ["run", 7.2, 0.0],
			["mark", 4.0, 1.0], ["defend", 3.0, 0.0], ["pass", 4.0, 0.0], ["catch", 5.0, 0.0], ["run", 3.0, -1.0]]:
		var pl := Player.new(0, sq[2], "WA")
		add_child(pl)
		await frames(1)
		if pl.link == null:
			check(false, "foundation steps: a link (Medium, the clips here)")
			pl.queue_free()
			break
		pl.fenced = false
		pl.place(Vector2.ZERO, 0.0)
		var act: String = case[0]
		var spd: float = case[1]
		var look: float = case[2]
		var go := Vector2(1, 0) if look > 0.0 else Vector2(0, 1)
		var st := _rig_state()
		for f in 150:
			pl.set_act(act, "chest" if act == "pass" else "")
			if act in ["pass", "catch"] and f % 20 == 0:
				pl.act_t = 0.0
			pl.target = pl.p + go * 8.0
			pl.want_speed = spd
			pl.look_on = look != 0.0
			pl.look_at_p = pl.p + Vector2(0, 10) if look > 0.0 else pl.p - go * 10.0
			pl.advance(1.0 / 30.0)
			await get_tree().process_frame      # (the drawn body's modifiers run at the frame's end)
			_rig_measure(pl.link, st, f >= 30)
		var what := "foundation, a player %s at %.1f m/s%s" % ["running" if act == "run" else act + "ing", pl.vel.length(),
			" (sideways)" if look > 0.0 else (" (the ball behind her)" if look < 0.0 else "")]
		check(st.slip < LINK_SLIP and st.steps >= 4, "%s: a drawn foot on the floor moves %.1f cm at most (%d steps, mode %s)" % [what, st.slip * 100.0, st.steps, pl.link.mode])
		print("foundation steps: %s: slip %.1f cm, %d steps, mode %s, keep_pose %s (%s)" % [what, st.slip * 100.0, st.steps, pl.link.mode, pl.link.loco.planter.get("keep_pose"), st.get("slip_at", "")])
		if act == "run" and is_equal_approx(spd, 6.8):
			var stop := _rig_state()
			for f in 60:
				pl.target = pl.p
				pl.want_speed = 0.0
				pl.advance(1.0 / 30.0)
				await get_tree().process_frame
				_rig_measure(pl.link, stop, true)
			check(stop.slip < LINK_SLIP, "foundation, pulling up from a sprint: a drawn foot moves %.1f cm at most" % [stop.slip * 100.0])
			print("foundation steps: pulling up from 6.8 m/s: slip %.1f cm, %d steps (%s)" % [stop.slip * 100.0, stop.steps, stop.get("slip_at", "")])
		pl.queue_free()
		await frames(1)
	for mc: Array in [["arena", 6], ["hall", 9]]:
		await _foundation_match(mc[0], mc[1])
	Game.settings.graphics = was
	FoundationLink.off = was_off


func _rig_state() -> Dictionary:
	return {"slip": 0.0, "steps": 0}


## One frame of a drawn body's feet into st, as drawn: where its skeleton last put them (kept as it is posed: the
## bones read anywhere else are without its modifiers), carried along with the body between its poses. Each foot's
## heel, ball and the spot under its ankle (on the floor, standing) are followed: a foot is on the floor while the
## lower of its heel and ball is within 3 cm of the floor and the foot is down (the game's gait, which the drawn feet
## are put on: a swinging foot skims the floor too, walking); slip is the furthest it has moved since it came down (the
## heel's, the ball's or the ankle's spot, whichever moved least: rolling heel to toe keeps one of them still), as
## _gait_measure has it for the game's own bodies.
func _rig_measure(l: FoundationLink, st: Dictionary, on: bool) -> void:
	var b := l.body
	if not b.has_meta("hooked"):
		_rig_hook(l)
	if not b.has_meta("feet"):
		return      # (not posed since: its bones read now would be without its modifiers)
	var sk := b.skeleton
	var pts: Array = b.get_meta("feet")
	var at := Vector2(l.global_position.x, l.global_position.z)
	if st.has("pos") and at.distance_to(st.pos) > 1.0:
		on = false      # (put somewhere new: a restart)
	st.pos = at
	for i in 2:
		var heel: Vector3 = sk.global_transform * (pts[i * 3] as Vector3)
		var ball: Vector3 = sk.global_transform * (pts[i * 3 + 1] as Vector3)
		var mid: Vector3 = sk.global_transform * (pts[i * 3 + 2] as Vector3)
		var h := minf(heel.y, ball.y)
		var k := str(i)
		var down := float(l.loco.planter.contact[i]) > 0.5
		if l.get("feet") and l.who.get("gait"):
			down = (l.who.gait.feet[i] as Gait.Foot).down
		if on and h < 0.03 and down:
			if not st.has("a" + k):
				st["a" + k] = Vector2(heel.x, heel.z)
				st["t" + k] = Vector2(ball.x, ball.z)
				st["m" + k] = Vector2(mid.x, mid.z)
				st.steps += 1
			var d := minf(minf(Vector2(heel.x, heel.z).distance_to(st["a" + k]), Vector2(ball.x, ball.z).distance_to(st["t" + k])),
				Vector2(mid.x, mid.z).distance_to(st["m" + k]))
			st["d" + k] = d
			st["n" + k] = int(st.get("n" + k, 0)) + 1
			if d > st.slip:
				st.slip_at = "foot %d, %d frames down, h %.3f, %s" % [i, st["n" + k], h, l.mode]
			st.slip = maxf(st.slip, d)
		else:
			st.erase("a" + k)
			st.erase("d" + k)
			st.erase("n" + k)


## Keeps a drawn body's heels and balls of the feet as each pose leaves them (skeleton space): each a point fixed in
## its foot, found standing at rest (under the ankle 5 cm back, under the toes, and under the ankle, on the floor).
func _rig_hook(l: FoundationLink) -> void:
	var b := l.body
	var sk := b.skeleton
	var feet := []
	for side in ["Left", "Right"]:
		var fi := sk.find_bone(side + "Foot")
		var rest := sk.get_bone_global_rest(fi)
		var ank := rest.origin
		var toe := sk.get_bone_global_rest(sk.find_bone(side + "ToeBase")).origin
		feet.append([fi, rest.affine_inverse() * Vector3(ank.x, 0.0, ank.z - 0.05), rest.affine_inverse() * Vector3(toe.x, 0.0, toe.z),
			rest.affine_inverse() * Vector3(ank.x, 0.0, ank.z)])
	var keep := func():
		var out := []
		for f in feet:
			var t := sk.get_bone_global_pose(f[0])
			out.append(t * (f[1] as Vector3))
			out.append(t * (f[2] as Vector3))
			out.append(t * (f[3] as Vector3))
		b.set_meta("feet", out)
	b.set_meta("hooked", true)
	b.posed.connect(keep)


## An AI match on Medium with the foundation drawing everyone: every player's drawn feet, every frame (as drawn, posed
## or carried along between poses), and who skates and what she was doing.
func _foundation_match(venue: String, seed: int) -> void:
	var m := _study_match(seed, {"venue": venue})
	await frames(5)
	var people: Array = m.players[0] + m.players[1] + m.umpires
	var all := {}
	var own := {}
	for q in people:
		all[q] = _rig_state()
		own[q] = {"slip": 0.0, "bend_lo": 999.0, "bend_hi": 0.0, "out": 0.0, "abd": 0.0, "steps": 0}
	var worst := 0.0
	var game_worst := 0.0
	var who := ""
	var over := {}
	var frames_n := 0
	for f in 600:
		await get_tree().process_frame
		if m.phase == "replay" or (m.phase in ["setup", "goal", "break"] and m.phase_t < 0.1):
			for q in people:
				all[q] = _rig_state()
				own[q] = {"slip": 0.0, "bend_lo": 999.0, "bend_hi": 0.0, "out": 0.0, "abd": 0.0, "steps": 0}
			continue
		for q in people:
			if q.link == null or not q.link.body.is_visible_in_tree():
				continue
			var st: Dictionary = all[q]
			var s0: float = st.slip
			var own_legs: bool = not (q is Player) or (q.legs_w > 0.99 and q.land_w <= 0.0)
			# (Her feet measured while they are the gait's, as on Low: not in a leap or the landing's motion capture.)
			_rig_measure(q.link, st, own_legs)
			# (The game's own feet, which the drawn ones are put on: the same measure as _gait_in_match's.)
			_gait_measure(q.gait, q.body, own[q], own_legs, false)
			game_worst = maxf(game_worst, float(own[q].slip))
			frames_n += 1
			for k in ["d0", "d1"]:
				if float(st.get(k, 0.0)) > LINK_SLIP:
					var key := "%s/%s/%s" % [q.act if q is Player else "umpire", q.link.mode, "fast" if q.vel.length() > 5.5 else ("run" if q.vel.length() > 1.5 else "slow")]
					over[key] = int(over.get(key, 0)) + 1
			if st.slip > s0 and st.slip > worst:
				worst = st.slip
				who = "%s (%s, %s, %.1f m/s, posed every %d, keep_pose %s, f %d; %s; the game's own foot %.1f cm)" % [q.pos + str(q.team) if q is Player else "umpire",
					q.act if q is Player else "", q.link.mode, q.vel.length(), q.pose_every if q is Player else 1, q.link.loco.planter.get("keep_pose"), f,
					st.get("slip_at", ""), float(own[q].slip) * 100.0]
	check(worst < LINK_SLIP, "foundation, a match (Medium, %s): no drawn foot on the floor moves more than %.1f cm (%s)" % [venue, worst * 100.0, who])
	print("foundation steps: a match (Medium, %s): slip %.1f cm at most (%s); the game's own feet %.1f cm at most; frames over %.0f cm by act/mode/pace: %s" % [venue, worst * 100.0, who, game_worst * 100.0, LINK_SLIP * 100.0, over])
	m.queue_free()
	await frames(2)


## The replays (with the foundation; Medium): a goal's after the TV camera's close shot of the post, never with it
## (its own camera while the close shot is over), slowed, a tap skipping it to the centre pass; an intercept's at the
## next stoppage, then the award; none on Low.
func _replays() -> void:
	if not WsgClips.available():
		return
	var was: int = int(Game.settings.graphics)
	Game.settings.graphics = Game.GFX_MEDIUM
	Game.settings.camera = Game.CAM_TV
	var m := _study_match(43, {"demo": false, "user_team": -1, "headless_hud": true})
	await _wait_live(m)
	await frames(200)
	check(m.wsg_replay != null, "replay: the foundation's bodies kept in a match")
	var gs: Player = m.player_at(0, "GS")
	m.pass_info = {}
	m._release_holder()
	m._goal(gs, 1)
	var close_seen := false
	var stacked := false
	var guard := 0
	while m.phase != "replay" and guard < 200:
		await frames(1)
		guard += 1
		close_seen = close_seen or (m.cam.close_dir != 0 and get_viewport().get_camera_3d() == m.cam)
	var rc := get_viewport().get_camera_3d()
	check(close_seen and m.phase == "replay" and m.wsg_replay.playing and rc != m.cam,
		"replay: after the goal's close shot of the post, the replay from its own camera (close shot %s, phase %s)" % [close_seen, m.phase])
	var t0: float = m._replay.t
	for i in 30:
		await frames(1)
		stacked = stacked or get_viewport().get_camera_3d() == m.cam
	check(not stacked and m.phase == "replay" and absf(float(m._replay.t) - t0 - 1.0 * m.REPLAY_RATE) < 0.05,
		"replay: slowed, never stacked with the close shot (%.2f s in 1 s)" % [float(m._replay.t) - t0])
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = Vector2(400, 300)
	Input.parse_input_event(tap)
	await frames(3)
	check(m.phase == "setup" and not m.wsg_replay.playing and get_viewport().get_camera_3d() == m.cam and m.cam.close_dir == 0,
		"replay: a tap skips it, to the centre pass (phase %s)" % m.phase)
	tap = tap.duplicate()
	tap.pressed = false
	Input.parse_input_event(tap)
	# An intercept, shown again at the next stoppage, then the award.
	await _wait_live(m)
	await frames(90)
	var gd: Player = m.player_at(1, "GD")
	m._mark_highlight(gd)
	await frames(60)
	m._infringe("offside", m.player_at(0, "WA"), m.player_at(0, "WA").p)
	guard = 0
	while m.phase != "replay" and guard < 120:
		await frames(1)
		guard += 1
	check(m.phase == "replay" and String(m._replay.kind) == "gain" and get_viewport().get_camera_3d() != m.cam,
		"replay: an intercept at the next stoppage (phase %s)" % m.phase)
	guard = 0
	while m.phase == "replay" and guard < 400:
		await frames(1)
		guard += 1
	await frames(2)     # (the award is applied the frame after the replay hands the stoppage back)
	check(m.phase in ["setup", "live"] and not m.wsg_replay.playing and get_viewport().get_camera_3d() == m.cam,
		"replay: the stoppage's award after the intercept's replay (phase %s, %d frames)" % [m.phase, guard])
	m.queue_free()
	await frames(2)
	Game.settings.graphics = was


# ---------------------------------------------------------------- Watch AI

## Watch AI (the owner's request): the home screen's entry opens its team sheet; Watch starts an AI v AI match with
## nobody's buttons, the scoreboard and clock, the broadcast camera; 2x takes two of the match's steps a frame (game
## time twice as fast, each step as at 1x) and back; pause holds it and Back resumes it; leaving goes home at 1x; a
## match with short quarters reaches the result screen and counts in no records; its words are in every language.
func _watch_ai() -> void:
	var keep_records: Dictionary = Game.records.duplicate(true)
	var had_file := FileAccess.file_exists(Game.RECORDS_PATH)
	var file_before := FileAccess.get_file_as_string(Game.RECORDS_PATH) if had_file else ""
	Game.goto_menu()
	await frames(4)
	var menu: Node = Game.current
	var entry: CourtThird = menu.find_child("WatchAI", true, false)
	check(entry != null and entry.is_visible_in_tree(), "watch: the home screen has a Watch AI entry")
	var kinds := []
	for ct in menu.find_children("*", "CourtThird", true, false):
		kinds.append((ct as CourtThird).kind)
	check("goal_left_top" in kinds and "goal_left_bottom" in kinds and "centre" in kinds and "goal_right_top" in kinds,
		"watch: the home screen keeps its thirds, the competitions halved (%s)" % [kinds])
	if entry == null:
		return
	var words := ""
	for l in entry.find_children("*", "Label", true, false):
		words += (l as Label).text + " "
	check(words.contains(tr("MENU_WATCH")), "watch: the entry says %s (%s)" % [tr("MENU_WATCH"), words])
	entry.pressed.emit()
	await frames(4)
	var setup: Node = Game.current
	check(String(setup.get_script().resource_path).ends_with("watch_setup.gd") and setup.watch, "watch: the entry opens Watch AI's team sheet")
	var go := _button_with(setup, tr("WATCH_GO"))
	check(go != null, "watch: the team sheet has Watch")
	if go == null:
		return
	go.pressed.emit()
	await _loaded()
	var m = Game.current
	check(m is Match, "watch: Watch starts a match")
	if not (m is Match):
		return
	check(m.user_team == -1 and m.demo and m.watch and String(m.config.mode) == "watch", "watch: AI v AI (user_team %d)" % m.user_team)
	check(m.controls == null and m.find_children("*", "TouchControls", true, false).is_empty() and m.me == null, "watch: no touch controls, nobody to play")
	check(m.hud != null and m.hud.coach == null, "watch: the HUD, no coach's tips")
	check(m.cam.mode == Game.CAM_TV, "watch: the broadcast camera")
	check(m.heard(), "watch: the match is heard (the home screen's is not)")
	if m.hud.card:
		m.hud.card.close()
	await frames(20)
	check(m.hud._board.is_visible_in_tree() and m.hud._clock_l.is_visible_in_tree() and m.hud._clock_l.text.contains(":"),
		"watch: the scoreboard and clock show (%s)" % m.hud._clock_l.text)
	var chip: Button = m.hud.speed_button()
	check(chip != null and chip.is_visible_in_tree() and m.hud.pause_button().is_visible_in_tree(), "watch: the speed chip and the pause button show")
	var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	check(chip != null and view.encloses(chip.get_global_rect()) and not chip.get_global_rect().intersects(m.hud.pause_button().get_global_rect())
		and not chip.get_global_rect().intersects(m.hud._board.get_global_rect()), "watch: the chip on screen, clear of the pause button and scoreboard")
	if chip == null:
		return
	await _wait_live(m)
	# 1x, 2x and back: game time a frame.
	var c0: float = m.clock
	await frames(30)
	var d1: float = m.clock - c0
	chip.pressed.emit()
	await frames(1)
	check(m.speed == 2 and m.hud._speed_l.text == "2×" and chip.button_pressed, "watch: the chip turns 2x on")
	c0 = m.clock
	var t0: float = m.time_left
	await frames(30)
	var d2: float = m.clock - c0
	check(absf(d2 - 2.0 * d1) < 0.05 and d1 > 0.5, "watch: 2x doubles game time a frame (%.2f s, then %.2f s in 30 frames)" % [d1, d2])
	check(Engine.time_scale == 1.0, "watch: 2x leaves the engine's time scale alone")
	check(t0 - m.time_left > 1.5 or m.phase != "live", "watch: the match clock runs at 2x too (%.2f s)" % [t0 - m.time_left])
	chip.pressed.emit()
	await frames(1)
	c0 = m.clock
	await frames(30)
	check(m.speed == 1 and absf(m.clock - c0 - d1) < 0.05 and m.hud._speed_l.text == "1×", "watch: and back to 1x (%.2f s)" % [m.clock - c0])
	# Pause, the pause menu's speed, and resume (the pause button; Back).
	m.hud.pause_button().pressed.emit()
	await frames(2)
	check(m.paused and m.hud._pause != null and not chip.is_visible_in_tree(), "watch: the pause button pauses it")
	c0 = m.clock
	await frames(10)
	check(m.clock == c0, "watch: nothing moves while paused")
	var sp: Node = m.hud._pause.find_child("Speed", true, false)
	check(sp != null and _button_with(m.hud._pause, tr("MOVE_BUTTONS")) == null, "watch: the pause menu has the speed, not Move buttons")
	if sp:
		_button_with(sp, "2×").pressed.emit()
		await frames(1)
		check(m.speed == 2 and m.hud._speed_l.text == "2×", "watch: 2x from the pause menu")
	Game.go_back()
	await frames(2)
	check(not m.paused and chip.is_visible_in_tree(), "watch: Back resumes it")
	c0 = m.clock
	await frames(10)
	check(m.clock > c0 + 0.5, "watch: it plays on after resuming, at 2x (%.2f s in 10 frames)" % [m.clock - c0])
	# Leaving: the pause menu's Leave match (tapped twice) goes home; the next match starts at 1x.
	m.set_paused(true)
	await frames(2)
	var quit := _button_with(m.hud._pause, tr("QUIT_MATCH"))
	quit.pressed.emit()
	quit.pressed.emit()
	await frames(3)
	check(String(Game.current.get_script().resource_path).ends_with("main_menu.gd") and Engine.time_scale == 1.0,
		"watch: Leave match goes home, the engine at 1x")
	# A whole match, short quarters at 2x: the interval screen comes up and goes by itself; the result screen at the
	# end with the box score; Back to the home screen; no records.
	Game.test_quarter_s = 5.0
	setup = Game.show_screen("res://ui/watch_setup.gd")
	await frames(3)
	_button_with(setup, tr("WATCH_GO")).pressed.emit()
	Game.test_quarter_s = 0.0
	await _loaded()
	m = Game.current
	check(m is Match and m.speed == 1 and m.watch, "watch: a new match starts at 1x")
	m.set_speed(2)
	var break_shown := false
	var guard := 0
	while guard < 6000 and is_instance_valid(m) and Game.current == m:
		await frames(1)
		guard += 1
		break_shown = break_shown or (m.phase == "break" and m.hud._break != null)
	var r: Node = Game.current
	check(break_shown, "watch: the interval screen shows between quarters")
	var on_result: bool = r != null and String(r.get_script().resource_path).ends_with("result_screen.gd")
	check(on_result, "watch: the match reaches the result screen (%d frames)" % guard)
	if on_result:
		var res: Dictionary = r.result
		check(int(res.user_team) == -1 and res.q_scores.size() >= 4, "watch: a whole match's result (%s)" % [res.score])
		var heads := []
		for l in r.find_children("*", "Label", true, false):
			heads.append((l as Label).text)
		check(tr("BOX_FEEDS") in heads and tr("BOX_INT") in heads, "watch: the result screen has the box score")
		Game.go_back()
		await frames(3)
		check(String(Game.current.get_script().resource_path).ends_with("main_menu.gd"), "watch: Back from the result goes home")
	check(Game.records == keep_records and FileAccess.file_exists(Game.RECORDS_PATH) == had_file
		and (not had_file or FileAccess.get_file_as_string(Game.RECORDS_PATH) == file_before), "watch: the match is in no records")
	# The words, in every language (translated: none left in English).
	var keys := ["MENU_WATCH", "MENU_WATCH_DESC", "WATCH_HOME", "WATCH_AWAY", "WATCH_GO", "WATCH_NOTE", "SPEED"]
	TranslationServer.set_locale("en")
	var en := {}
	for k in keys:
		en[k] = tr(k)
	for pair in Game.LANGUAGES:
		TranslationServer.set_locale(pair[0])
		for k in keys:
			var s := tr(k)
			check(s != k and s != "" and (pair[0] == "en" or s != String(en[k])), "watch: %s in %s (%s)" % [k, pair[0], s])
	TranslationServer.set_locale("en")


## How to Play's positions: each of the seven has its own court (owner: "the same image over and over"), drawn from
## the game's rules: the areas lit are the ones Rules.AREAS gives her, her bib and her opposite number's stand onside,
## apart, and no two positions' pictures are alike. In a window (not headless) the pictures themselves are rendered
## and read: each third and circle lit or dimmed as her areas say, and two positions' pictures differ.
func _howto_positions() -> void:
	var all_areas := PositionCourt.AREA_ORDER.duplicate()
	all_areas.sort()
	var seen := {}
	for pos in Rules.POSITIONS:
		var lay := PositionCourt.layout(pos)
		var lit: Array = lay.lit.duplicate()
		lit.sort()
		var want: Array = Rules.AREAS[pos].duplicate()
		want.sort()
		check(lit == want, "howto: %s's court lights her areas %s (lit %s)" % [pos, want, lit])
		var both: Array = lay.lit + lay.dim
		both.sort()
		check(both == all_areas, "howto: %s's court dims every other area" % pos)
		check(lay.opp == Rules.OPPOSITE[pos], "howto: %s's opposite number is the %s" % [pos, Rules.OPPOSITE[pos]])
		check(not Rules.offside(pos, lay.at, 1) and Court.area_of(lay.at, 1) in lay.lit,
			"howto: %s's bib stands in her areas (%s)" % [pos, lay.at])
		check(not Rules.offside(lay.opp, lay.opp_at, -1), "howto: %s's opposite number stands in hers (%s)" % [pos, lay.opp_at])
		check(absf(lay.at.y - lay.opp_at.y) >= 4.9, "howto: %s's two bibs do not cover each other" % pos)
		check(int(lay.attacks) == 1, "howto: %s's team attacks to the right, as every court shows" % pos)
		var sig := "%s|%s|%s" % [lay.lit, lay.at, lay.opp]
		check(not seen.has(sig), "howto: %s's court differs from %s's" % [pos, seen.get(sig, "")])
		seen[sig] = pos
	# The screen: seven courts, one per position, in the rules' order.
	var s := Game.show_screen("res://ui/howto_screen.gd", {"tab": 1})
	await frames(3)
	var courts := []
	for c in s.find_children("*", "PositionCourt", true, false):
		courts.append((c as PositionCourt).pos)
	check(courts == Rules.POSITIONS, "howto: the positions page draws a court for each position (%s)" % [courts])
	if DisplayServer.get_name() == "headless":
		return
	# The pictures, rendered: the middle of each third near the side line (clear of the bibs), and each circle by
	# its edge: lime where she may go, dark where she may not.
	var shots := {}
	for pos in Rules.POSITIONS:
		var vp := SubViewport.new()
		vp.size = Vector2i(472, 278)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var pc := PositionCourt.make(pos)
		pc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vp.add_child(pc)
		await frames(3)
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		vp.queue_free()
		if img == null:
			check(false, "howto: %s's court renders" % pos)
			continue
		shots[pos] = img
		var h := minf(img.get_height() / 1.18, img.get_width() * 0.5)
		var o := Vector2((img.get_width() - h * 2.0) * 0.5, (img.get_height() - h * 1.18) * 0.5)
		var probes := {Court.A_DEF_THIRD: Vector2(-Court.THIRD, -6.1), Court.A_CENTRE: Vector2(0.0, -6.1),
			Court.A_ATT_THIRD: Vector2(Court.THIRD, -6.1), Court.A_DEF_CIRCLE: Vector2(-10.8, -0.2),
			Court.A_ATT_CIRCLE: Vector2(10.8, -0.2)}
		for area in probes:
			var m: Vector2 = probes[area]
			var px := o + Vector2(m.x + Court.HALF_L, m.y + Court.HALF_W) * (h / Court.WIDTH)
			var c := img.get_pixelv(Vector2i(px))
			var lime := c.g > 0.65 and c.r > 0.5 and c.b < 0.4
			var dark := c.g < 0.3 and c.r < 0.25
			var want_lit := Rules.may_enter(pos, area)
			check(lime if want_lit else dark, "howto: %s's %s drawn %s (%s)" % [pos, area, "lit" if want_lit else "dim", c])
	if shots.size() == Rules.POSITIONS.size():
		for i in Rules.POSITIONS.size():
			for j in range(i + 1, Rules.POSITIONS.size()):
				var a: Image = shots[Rules.POSITIONS[i]]
				var b: Image = shots[Rules.POSITIONS[j]]
				check(a.get_data() != b.get_data(), "howto: %s's and %s's pictures differ" % [Rules.POSITIONS[i], Rules.POSITIONS[j]])


## The first button under n whose text is t.
## The loading overlay on every Start button (Game.start_match_loading: the shared foundation's WsgLoading). The owner:
## "when you click start game there is a loading delay ... users might think the game has frozen". Quick Match's Play,
## Watch AI's Watch, the Nations Cup's and the Club Season's Play and the result screen's Rematch: the tap puts the
## overlay up in its own frame and turns the screen's buttons off; a second tap and Back start nothing; the work
## starts two frames later; the bar only moves forward and reaches the end; the match takes the screen's place and
## plays. The match built in steps is the one start_match builds at once.
func _loading_overlay() -> void:
	for f in DirAccess.get_files_at("res://ui"):
		if f.ends_with(".gd"):
			check(not FileAccess.get_file_as_string("res://ui/" + f).contains("Game.start_match("),
				"loading: ui/%s starts its matches under the overlay (Game.start_match_loading)" % f)
	Game.delete_cup()
	Game.new_cup("ENG")
	Game.delete_league()
	Game.new_league(String(DB.club_ids()[0]))
	var fake: Dictionary = (load("res://tests/fit_audit.gd") as Script).fake_result()
	var paths := [["quick", "res://ui/quick_setup.gd", {}, "PLAY"], ["watch", "res://ui/watch_setup.gd", {}, "WATCH_GO"],
		["cup", "res://ui/cup_screen.gd", {}, "PLAY"], ["league", "res://ui/league_screen.gd", {}, "PLAY"],
		["rematch", "res://ui/result_screen.gd", {"result": fake}, "REMATCH"]]
	var want_steps := ["Match", "Venue", "Court", "Crowd", "Home team", "Away team", "Bench", "Umpires", "Scoreboard", "Centre pass", "Warming up"]
	for pth in paths:
		var e: String = pth[0]
		var s := Game.show_screen(pth[1], pth[2])
		await frames(3)
		var b := _button_with(s, tr(pth[3]))
		check(b != null and b.is_visible_in_tree() and not b.disabled, "loading: %s: the screen has its %s button" % [e, pth[3]])
		if b == null:
			continue
		var live := []
		for x in s.find_children("*", "BaseButton", true, false):
			if not (x as BaseButton).disabled:
				live.append(x)
		var f0 := Engine.get_process_frames()
		b.pressed.emit()
		var ld := WsgLoading.current()
		check(ld != null and ld.is_inside_tree() and Engine.get_process_frames() == f0 and (ld.parts().root as Control).is_visible_in_tree(),
			"loading: %s: the tap puts the overlay up in its own frame" % e)
		check(live.all(func(x): return (x as BaseButton).disabled), "loading: %s: the screen's %d buttons go off" % [e, live.size()])
		if ld == null:
			continue
		var name_l: Label = ld.parts().root.find_child("GameName", true, false)
		check(name_l != null and name_l.text == tr("GAME_TITLE") and (ld.parts().title as Label).text == tr("LOADING")
			and (ld.parts().bar as ColorRect).color == Game.C_ACCENT and (ld.parts().tip as Label).text != "",
			"loading: %s: the game's name, its loading line, the lime bar and a tip" % e)
		var started := [-1]
		ld.load_started.connect(func(): started[0] = Engine.get_process_frames())
		var fr := []
		ld.progressed.connect(func(f, _l): fr.append(f))
		var rep_ := {}
		ld.finished.connect(func(): rep_.merge(ld.report))
		check(not await Game.start_match_loading({"home": "AUS", "away": "NZL"}), "loading: %s: a second start is refused" % e)
		b.pressed.emit()
		check(WsgLoading.current() == ld, "loading: %s: a second tap starts nothing" % e)
		Game.go_back()
		check(Game.current == s and WsgLoading.current() == ld, "loading: %s: Back does nothing while it loads" % e)
		var shown := []
		var guard := 0
		var held_ok := true
		var held_frames := 0
		while WsgLoading.busy() and guard < 60000:
			shown.append(ld.shown())
			var hm = Game.current
			if hm is Match and hm.held:
				held_frames += 1
				held_ok = held_ok and hm.phase == "setup" and (hm.hud == null or not hm.hud.visible)
			await frames(1)
			guard += 1
		check(held_ok and held_frames > 0, "loading: %s: behind the overlay the match waits (%d frames: no whistle, no HUD)" % [e, held_frames])
		if is_instance_valid(ld) and rep_.is_empty():
			rep_.merge(ld.report)    # (done() has written it: the settle over, the fade under way)
		var mono := true
		for i in range(1, fr.size()):
			mono = mono and float(fr[i]) >= float(fr[i - 1])
		for i in range(1, shown.size()):
			mono = mono and float(shown[i]) >= float(shown[i - 1])
		check(started[0] - f0 >= 2, "loading: %s: the work starts once the overlay has been drawn (frame %d after the tap)" % [e, started[0] - f0])
		check(mono and not fr.is_empty() and is_equal_approx(float(fr[-1]), 1.0) and shown.size() > 5,
			"loading: %s: the bar only moves forward and reaches the end (%d steps, %d frames, last %.2f)" % [e, fr.size(), shown.size(), fr[-1] if not fr.is_empty() else -1.0])
		await frames(2)
		check(not rep_.is_empty() and (rep_.failed as Array).is_empty() and want_steps.all(func(k): return (rep_.steps as Dictionary).has(k))
			and int((rep_.get("warm", {}) as Dictionary).get("looks", 0)) > 0 and rep_.has("settled"),
			"loading: %s: every step ran, the warm-up and the settle (%s, %s)" % [e, (rep_.get("steps", {}) as Dictionary).keys(), rep_.get("warm")])
		var m = Game.current
		var matches := get_children().filter(func(n): return n is Match).size()
		check(m is Match and matches == 1 and not is_instance_valid(s) and m.process_mode == Node.PROCESS_MODE_INHERIT and not m.held
			and m.cam.current and (m.hud == null or (m.hud.visible and m.hud.process_mode == Node.PROCESS_MODE_INHERIT)) and not get_viewport().disable_3d,
			"loading: %s: the match takes the screen's place and kicks off, one match (%d)" % [e, matches])
		if not (m is Match):
			continue
		check(String(m.config.mode) == {"quick": "quick", "watch": "watch", "cup": "cup", "league": "league", "rematch": "quick"}[e],
			"loading: %s: the %s match" % [e, m.config.mode])
		await frames(12)
		var layers_ok := true
		for g in m.find_children("*", "GeometryInstance3D", true, false):
			layers_ok = layers_ok and (g as GeometryInstance3D).layers != 0
		check(m.find_children("*", "Camera3D", true, false).size() == 1 and layers_ok,
			"loading: %s: nothing of the warm-up left in the match (its camera, hidden layers)" % e)
		check(ld == null or not is_instance_valid(ld), "loading: %s: the overlay has gone" % e)
		if m.hud and m.hud.card:
			m.hud.card.close()
		await _wait_live(m)
		var c0: float = m.clock
		await frames(20)
		check(m.phase != "setup" and m.clock > c0, "loading: %s: the match plays (%s, %.2f s)" % [e, m.phase, m.clock - c0])
	# The same match, built in steps or all at once.
	var cfg := {"home": "JAM", "away": "RSA", "venue": "outdoor", "quarter": 15, "mode": "quick", "user_team": 0, "seed": 21, "difficulty": 1}
	Game.show_screen("res://ui/quick_setup.gd")
	await frames(2)
	# (As built: when the warm-up starts, before it has run a frame; and at once.)
	var sig := []
	Game.start_match_loading(cfg.duplicate())
	WsgLoading.current().progressed.connect(func(_f, l):
		if l == "Warming up" and sig.is_empty():
			for c in get_children():
				if c is Match:
					sig.append(_match_sig(c)))
	await _loaded()
	var a: Array = sig[0] if sig.size() == 1 else []
	Game.start_match(cfg.duplicate())
	var bsig := _match_sig(Game.current)
	check(a == bsig and a.size() > 20, "loading: the match built in steps is the one built at once (%d parts)" % a.size())
	if a != bsig:
		for i in mini(a.size(), bsig.size()):
			if a[i] != bsig[i]:
				print("  first difference: %s / %s" % [a[i], bsig[i]])
				break
	Game.goto_menu()
	await frames(3)
	Game.delete_cup()
	Game.delete_league()


## What a match is made of, as built: the toss, the players and where they stand, the bench, the venue's nodes and
## their meshes, the crowd, the officials, the HUD's parts, the match's random state.
func _match_sig(m: Match) -> Array:
	var rs := m.restart.duplicate()
	for k in rs:
		if rs[k] is Player:
			rs[k] = (rs[k] as Player).data.id
	var out := [m.cp_first, m.first_dir, m.rng.state, m.phase, rs, m.me.data.id if m.me else ""]
	for t in 2:
		for pl in m.players[t]:
			out.append([pl.data.id, pl.pos, pl.position.snapped(Vector3.ONE * 0.001), pl.dir, pl.body.get_class()])
		out.append(m.bench[t].map(func(x): return x.id))
	for c in m.arena.get_children():
		var v := [c.get_class(), String(c.name).get_slice("@", 1) if String(c.name).begins_with("@") else String(c.name)]  # (made-up names: their kind)
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var mesh: Mesh = (c as MeshInstance3D).mesh
			for i in mesh.get_surface_count():
				v.append(mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX].size())
		out.append(v)
	if m.arena.crowd:
		var cr: Crowd = m.arena.crowd
		out.append([(cr.placed.get("spots", []) as Array).size(), cr.used.size(), cr.shirts.size(), cr.people != null, cr.cards != null])
	for u in m.umpires:
		out.append(u.position.snapped(Vector3.ONE * 0.001))
	out.append(m.ball.position.snapped(Vector3.ONE * 0.001))
	for c in m.get_children():
		out.append([c.get_class(), String(c.name).get_slice("@", 1) if String(c.name).begins_with("@") else String(c.name)])
	out.append(m.hud.root.find_children("*", "Control", true, false).size() if m.hud else -1)
	return out


## A Start button's match: till the loading overlay (Game.start_match_loading) has built it and gone.
func _loaded(limit := 60000) -> void:
	var guard := 0
	while WsgLoading.busy() and guard < limit:
		await frames(1)
		guard += 1
	await frames(1)


func _button_with(n: Node, t: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).text == t:
			return b
	return null
