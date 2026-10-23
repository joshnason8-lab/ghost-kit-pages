extends Node
## The test suite CI runs before building (headless):
##   godot --headless --path . --fixed-fps 30 res://tests/test_runner.tscn
## The playing rules, one by one (Rules, Pitch): docs/RULES.md lists each with its number. Every screen opens in
## every language; every scrolling page scrolls when dragged on its text; the championship plays through to its
## champion and saves; the simulated results are scores hurling can have; an AI match plays to full time with a legal
## score; and the movement audit: one writer per player, nothing jumps in a frame, strides match speed.
## Exits 1 on any failure.

var failures := 0
var checks := 0


func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	# Headless there is no window: give the screens a phone's shape.
	get_tree().root.size = Vector2i(1280, 720)
	await frames(1)
	var keep: Dictionary = Game.settings.duplicate(true)
	_rules_scores()
	_rules_time()
	_rules_carry()
	_rules_restarts()
	_rules_fouls()
	_rules_cards()
	_rules_shootout()
	_pitch()
	_sliotar()
	_plurals()
	await _screens()
	await _scroll_on_text()
	_championship()
	_sim_scores()
	_clock_lengths()
	_coach()
	await _subs()
	await _tactics()
	await _playtest_fixes()
	await _nets()
	await _scenery()
	await _hero_body()
	await _replay()
	await _match_and_motion()
	Game.settings = keep
	Game.delete_champ()
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


# ---------------------------------------------------------------- the rules

func _rules_scores() -> void:
	check(Rules.total(2, 18) == 24, "Scores: 2-18 is 24")
	check(Rules.total(1, 0) == Rules.total(0, 3), "Scores: a goal is worth three points")
	check(Rules.fmt(2, 18) == "2-18" and Rules.fmt(0, 7) == "0-7", "Scores: written goals-points")
	check(Pitch.score_kind(Vector3(70, 1.0, 0)) == "goal", "Scores: under the bar between the posts is a goal")
	check(Pitch.score_kind(Vector3(70, 3.0, 2.0)) == "point", "Scores: over the bar between the posts is a point")
	check(Pitch.score_kind(Vector3(70, 3.0, 3.4)) == "", "Scores: outside the posts is wide")
	check(Pitch.score_kind(Vector3(70, 25.0, 1.0)) == "point", "Scores: high over the posts, inside their line, is a point")
	check(not Rules.score_counts("goal", "hand_pass"), "Scores: no goal from a hand-pass")
	check(Rules.score_counts("point", "hand_pass"), "Scores: a hand-passed point stands")
	check(not Rules.score_counts("point", "throw") and not Rules.score_counts("goal", "carry"), "Scores: nothing thrown or carried over the line")
	check(Rules.score_counts("goal", "strike") and Rules.score_counts("goal", "deflect") and Rules.score_counts("point", "65"), "Scores: struck, deflected, from a 65")
	check(Rules.shootout_counts("goal") and not Rules.shootout_counts("point"), "Shoot-out: only goals count")


func _rules_time() -> void:
	check(Rules.half_minutes(Rules.GRADE_SENIOR) == 35 and Rules.half_minutes(Rules.GRADE_CLUB) == 30, "Time: halves of 35 (senior county) and 30 (club)")
	check(Rules.half_time_minutes(Rules.GRADE_SENIOR) == 15 and Rules.half_time_minutes(Rules.GRADE_CLUB) == 10, "Time: half-time 15 and 10 minutes")
	check(Rules.EXTRA_HALF == 10, "Time: extra time is two halves of ten")
	check(Rules.subs_allowed(false) == 5 and Rules.subs_allowed(true) == 8, "Substitutes: five, three more in extra time")
	check(Rules.throw_in_players() == 2, "Throw-in: two from each side")


func _rules_carry() -> void:
	var c := Rules.Carry.new()
	check(Rules.take_in_hand(c) == "", "Carry: the first catch")
	check(Rules.carry_step(c, 4, 1.0) == "", "Carry: four steps in the hand")
	check(Rules.carry_step(c, 1, 0.2) == "FOUL_STEPS", "Carry: a fifth step is a foul")
	c = Rules.Carry.new()
	Rules.take_in_hand(c)
	check(Rules.carry_step(c, 0, Rules.MAX_HOLD_S + 0.1) == "FOUL_HOLD", "Carry: held longer than four steps take is a foul")
	c = Rules.Carry.new()
	Rules.take_in_hand(c)
	Rules.carry_step(c, 3, 0.5)
	Rules.to_hurley(c)
	check(Rules.carry_step(c, 40, 5.0) == "", "Carry: on the hurley, no limit")
	check(Rules.take_in_hand(c) == "", "Carry: back into the hand, the second catch")
	check(c.steps == 0, "Carry: the steps start again on the second catch")
	Rules.to_hurley(c)
	check(Rules.take_in_hand(c) == "FOUL_CATCH_3", "Carry: a third catch is a foul")
	Rules.release(c)
	check(c.catches == 0 and Rules.take_in_hand(c) == "", "Carry: played away, a new possession starts at one")
	check(not Rules.ground_lift_ok("hand") and Rules.ground_lift_ok("hurley") and Rules.ground_lift_ok("foot"), "Ground: lifted with the hurley or the foot, never the hand")
	check(Rules.hand_pass_ok(true) and not Rules.hand_pass_ok(false), "Hand-pass: struck, not thrown")
	check(not Rules.recatch_ok(false) and Rules.recatch_ok(true), "Recatch: only after playing it on the hurley")


func _rules_restarts() -> void:
	# Team 0 attacks +x (dir 1).
	var wide := Rules.over_end_line(Vector3(70, 2, 10), 0, 0, 1.0)
	check(String(wide.kind) == "puck_out" and int(wide.team) == 1, "Wide: a puck-out to the defenders")
	check(Pitch.in_small_rect(wide.spot, 1.0), "Puck-out: from the small rectangle")
	var s65 := Rules.over_end_line(Vector3(70, 1, -12), 1, 0, 1.0)
	check(String(s65.kind) == "65" and int(s65.team) == 0, "65: a defender put it over his own end line")
	check(is_equal_approx(Pitch.from_goal_line(s65.spot, 1.0), 65.0) and is_equal_approx(s65.spot.z, -12.0), "65: from the 65 m line opposite where it crossed")
	var sc := Rules.after_score(0, 1.0)
	check(String(sc.kind) == "puck_out" and int(sc.team) == 1 and Pitch.in_small_rect(sc.spot, 1.0), "After a score: a puck-out by the side scored against")
	var sl := Rules.over_side_line(Vector3(10, 1, 43), 1)
	check(String(sl.kind) == "sideline" and int(sl.team) == 0 and is_equal_approx(sl.spot.x, 10.0), "Sideline: to the other side, where it crossed")
	check(not Rules.restart_lift("sideline") and Rules.restart_lift("free") and Rules.restart_lift("65"), "Sideline cut off the ground; frees and 65s may be lifted")
	check(Rules.restart_from_hand("puck_out") and not Rules.restart_from_hand("free"), "Only the puck-out from the hand")
	# Positions.
	check(not Rules.position_ok("free", Vector3(0, 0, 0), 0, Vector3(5, 0, 5), 1, 1.0), "Free: an opponent 7 m away is too near")
	check(Rules.position_ok("free", Vector3(0, 0, 0), 0, Vector3(13.1, 0, 0), 1, 1.0), "Free: 13 m is far enough")
	check(Rules.position_ok("free", Vector3(0, 0, 0), 0, Vector3(1, 0, 0), 0, 1.0), "Free: teammates may stand near")
	check(not Rules.position_ok("puck_out", Vector3(-68, 0, 0), 0, Vector3(-55, 0, 0), 1, 1.0), "Puck-out: inside the 20 m line is not allowed")
	check(Rules.position_ok("puck_out", Vector3(-68, 0, 0), 0, Vector3(-49, 0, 0), 1, 1.0), "Puck-out: outside the 20 m line")
	check(Rules.position_ok("puck_out", Vector3(-68, 0, 0), 0, Vector3(-69, 0, 0), 0, 1.0, true), "Puck-out: the goalkeeper in his area")
	check(Rules.PUCK_OUT_TRAVEL == 13.0, "Puck-out: travels 13 m before the taker's side plays it")
	check(Rules.position_ok("penalty", Pitch.penalty_spot(1.0), 0, Vector3(70, 0, 0), 1, 1.0, true), "Penalty: one defender on the goal line")
	check(not Rules.position_ok("penalty", Pitch.penalty_spot(1.0), 0, Vector3(55, 0, 0), 1, 1.0), "Penalty: no one else inside the 20 m line")
	check(not Rules.position_ok("penalty", Pitch.penalty_spot(1.0), 0, Vector3(45, 0, 2), 0, 1.0), "Penalty: no one inside the arc")
	check(Rules.line_defenders("penalty") == 1 and Rules.line_defenders("free20") == 5, "Penalty one on the line, a 20 m free up to five")
	check(Rules.penalty_strike_ok(Pitch.penalty_spot(1.0) - Vector3(3, 0, 0), 1.0) and not Rules.penalty_strike_ok(Vector3(55, 0, 0), 1.0), "Penalty: struck on or outside the 20 m line")
	check(Rules.PENALTY_RUNUP == 7.0, "Penalty: placed up to 7 m back for a run-up")


func _rules_fouls() -> void:
	# Fouls by team 1 on team 0, which attacks +x.
	var f := Rules.free_for("FOUL_PUSH", Vector3(0, 0, 10), 0, 1.0)
	check(String(f.kind) == "free" and f.spot.distance_to(Vector3(0, 0, 10)) < 0.01, "Free: where the foul was")
	var p := Rules.free_for("FOUL_PULL_DOWN", Vector3(62, 0, 3), 0, 1.0)
	check(String(p.kind) == "penalty" and p.spot.distance_to(Pitch.penalty_spot(1.0)) < 0.01, "Aggressive foul in the large rectangle: a penalty")
	var t := Rules.free_for("FOUL_STEPS", Vector3(62, 0, 3), 0, 1.0)
	check(String(t.kind) == "free" and t.spot.distance_to(Pitch.penalty_spot(1.0)) < 0.01, "Technical foul in the large rectangle: a free from the centre of the 20 m line")
	var t20 := Rules.free_for("FOUL_PUSH", Vector3(58, 0, 20), 0, 1.0)
	check(String(t20.kind) == "free" and is_equal_approx(Pitch.from_goal_line(t20.spot, 1.0), 20.0) and is_equal_approx(t20.spot.z, 20.0), "Inside the 20 m line, outside the large rectangle: a free on the 20 m line opposite")
	var d := Rules.free_for("FOUL_TRIP", Vector3(54, 0, 8), 0, 1.0, true)
	check(String(d.kind) == "penalty", "A foul denying a goal chance inside the 20 m line: a penalty")
	var da := Rules.free_for("FOUL_TRIP", Vector3(40, 0, 0), 0, 1.0, true)
	check(String(da.kind) == "penalty", "... or inside the arc")
	var dout := Rules.free_for("FOUL_TRIP", Vector3(20, 0, 0), 0, 1.0, true)
	check(String(dout.kind) == "free", "... but not out the field")
	check(Rules.aggressive("FOUL_TRIP") and not Rules.aggressive("FOUL_STEPS"), "Aggressive and technical fouls apart")
	var ds := Rules.dissent_spot(Vector3(0, 0, 4), 1.0)
	check(is_equal_approx(ds.x, 30.0), "Dissent: the free moves on 30 m")
	check(is_equal_approx(Rules.dissent_spot(Vector3(40, 0, 0), 1.0).x, Pitch.HALF_L - 20.0), "Dissent: no nearer than the 20 m line")
	check(Rules.may_play_advantage("FOUL_STEPS", false, true), "Advantage: for a technical foul with space")
	check(not Rules.may_play_advantage("FOUL_PULL_DOWN", false, false), "Advantage: not for an aggressive foul on a man held up")
	check(Rules.may_play_advantage("FOUL_PULL_DOWN", true, false), "Advantage: for an aggressive foul with a goal chance")
	check(Rules.ADVANTAGE_S == 5.0, "Advantage: up to five seconds")
	check(Rules.FREE_DISTANCE == 13.0, "Opponents 13 m from a free")


func _rules_cards() -> void:
	check(Rules.card_for("FOUL_STRIKE", false, false, 0, 0, 0) == "red", "Striking an opponent: red")
	check(Rules.card_for("FOUL_PULL_DOWN", true, false, 0, 0, 0) == "yellow", "A cynical pull-down: yellow")
	check(Rules.card_for("FOUL_PULL_DOWN", true, false, 0, 1, 0) == "red", "A second yellow is a red")
	check(Rules.card_for("FOUL_TRIP", true, true, Rules.GRADE_SENIOR, 0, 0) == "black", "Denying a goal chance (senior county): black, the sin bin")
	check(Rules.card_for("FOUL_TRIP", true, true, Rules.GRADE_SENIOR, 1, 0) == "red", "A black after a yellow: red")
	check(Rules.card_for("FOUL_TRIP", true, true, Rules.GRADE_CLUB, 0, 0) == "yellow", "Club hurling has no black card")
	check(Rules.card_for("FOUL_STEPS", false, false, 0, 0, 0) == "", "A technical foul: no card")
	check(Rules.SIN_BIN_MIN == 10, "The sin bin: ten minutes")


func _rules_shootout() -> void:
	check(Rules.shootout_winner([3, 0], [3, 3]) == 0, "Shoot-out: 3-0 after three each cannot be caught")
	check(Rules.shootout_winner([3, 1], [3, 2]) == -1, "Shoot-out: 3-1 with three to come for one side goes on")
	check(Rules.shootout_winner([4, 4], [5, 5]) == -1, "Shoot-out: level after five each: sudden death")
	check(Rules.shootout_winner([5, 4], [6, 6]) == 0, "Shoot-out: sudden death decided in a round")
	check(Rules.shootout_winner([5, 5], [6, 5]) == -1, "Shoot-out: a round is finished first")


func _pitch() -> void:
	check(Pitch.LENGTH >= 130.0 and Pitch.LENGTH <= 145.0 and Pitch.WIDTH >= 80.0 and Pitch.WIDTH <= 90.0, "Pitch: 130-145 m by 80-90 m")
	check(Pitch.POST_GAP == 6.5 and Pitch.BAR_H == 2.5 and Pitch.POST_H >= 7.0, "Goals: posts 6.5 m apart, at least 7 m high, the bar at 2.5 m")
	check(Pitch.SMALL_W == 14.0 and Pitch.SMALL_D == 4.5 and Pitch.LARGE_W == 19.0 and Pitch.LARGE_D == 13.0, "Rectangles: 14 x 4.5 m and 19 x 13 m")
	check(Pitch.LINES == [13.0, 20.0, 45.0, 65.0], "Lines at 13, 20, 45 and 65 m")
	check(Pitch.ARC_R == 13.0, "The arc: 13 m from the centre of the 20 m line")
	check(Pitch.in_play(Vector3(Pitch.HALF_L, 0, 0)) and not Pitch.in_play(Vector3(Pitch.HALF_L + 0.2, 0, 0)), "A ball on the line is in play")
	check(Pitch.attack_dir(0, 1) == -Pitch.attack_dir(0, 2), "Ends change at half time")


func _sliotar() -> void:
	# A long puck-out carries about 80-100 m: struck at 40 m/s at 32 degrees.
	var v := Vector3(cos(deg_to_rad(32.0)), sin(deg_to_rad(32.0)), 0) * 40.0
	var land: Array = Sliotar.first_at_height(Vector3(0, 1, 0), v, 0.1)
	check(not land.is_empty() and land[1].x > 70.0 and land[1].x < 110.0, "Sliotar: a 40 m/s puck-out carries 70-110 m (%.0f)" % (land[1].x if not land.is_empty() else 0.0))
	var sol: Array = Sliotar.solve(Vector3(0, 1, 0), Vector3(40, 6, 0), 30.0)
	check(not sol.is_empty(), "Sliotar: a 40 m point at 30 m/s can be aimed")
	if not sol.is_empty():
		var at := Sliotar.predict(Vector3(0, 1, 0), sol[0], float(sol[1]))
		check(at.distance_to(Vector3(40, 6, 0)) < 1.2, "Sliotar: the aimed ball passes the target (%.2f m off)" % at.distance_to(Vector3(40, 6, 0)))


func _plurals() -> void:
	check(Plural.category("en", 1) == "one" and Plural.category("en", 5) == "other", "Plurals: English one/other")
	check(Plural.category("ga", 1) == "one" and Plural.category("ga", 2) == "two" and Plural.category("ga", 4) == "few"
		and Plural.category("ga", 8) == "many" and Plural.category("ga", 15) == "other", "Plurals: Irish one/two/few/many/other")


# ---------------------------------------------------------------- screens

const SCREENS := ["res://ui/main_menu.gd", "res://ui/quick_setup.gd", "res://ui/settings_screen.gd", "res://ui/howto_screen.gd",
	"res://ui/champ_screen.gd", "res://ui/licences_screen.gd", "res://ui/buttons_screen.gd"]


func _screens() -> void:
	Game.delete_champ()
	for pair in Game.LANGUAGES:
		Game.settings.language = pair[0]
		TranslationServer.set_locale(pair[0])
		Game._size_theme()
		check(tr("GAME_TITLE") != "GAME_TITLE", "%s: translations load" % pair[0])
		check(tr("BTN_STRIKE") != "BTN_STRIKE" and tr("BTN_STRIKE") != "", "%s: button labels" % pair[0])
		for path in SCREENS:
			var s := Game.show_screen(path)
			await frames(3)
			check(is_instance_valid(s) and s.get_child_count() > 0, "%s: %s builds" % [pair[0], path])
		Game.new_champ("KIL")
		var h := Game.show_screen("res://ui/champ_screen.gd")
		await frames(3)
		check(is_instance_valid(h) and h.get_child_count() > 0, "%s: the championship hub builds" % pair[0])
		Game.delete_champ()
		var r := Game.show_screen("res://ui/result_screen.gd", {"result": _fake_result()})
		await frames(3)
		check(is_instance_valid(r) and r.get_child_count() > 0, "%s: the result screen builds" % pair[0])
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	Game._size_theme()


func _fake_result() -> Dictionary:
	var ps := {}
	ps["KIL_14"] = {"goals": 1, "points": 3, "free_g": 0, "free_p": 2, "wides": 1, "team": 0, "num": 14}
	ps["TIP_11"] = {"goals": 0, "points": 6, "free_g": 0, "free_p": 5, "wides": 0, "team": 1, "num": 11}
	var ts := {"shots": 20, "wides": 6, "frees": 7, "s65": 2, "sidelines": 3, "puckouts": 14, "yellow": 1, "black": 0, "red": 0,
		"scores_play": 10, "scores_placed": 4}
	return {"config": {"mode": "quick", "stage": "Final"}, "home": "KIL", "away": "TIP", "score": [[2, 15], [1, 17]], "winner": 0,
		"user_team": 0, "pstats": ps, "tstats": [ts, ts.duplicate()], "events": [], "extra_time": true,
		"shootout": {}, "star": "KIL_14"}


## Each scrolling page scrolls when a drag starts on its words (Kabaddi's How to Play did not).
func _scroll_on_text() -> void:
	Game.new_champ("KIL")
	for path in ["res://ui/howto_screen.gd", "res://ui/licences_screen.gd", "res://ui/settings_screen.gd", "res://ui/quick_setup.gd", "res://ui/result_screen.gd"]:
		var args := {"result": _fake_result()} if path.ends_with("result_screen.gd") else {}
		var s := Game.show_screen(path, args)
		await frames(4)
		var sc := _first_scroll(s)
		check(sc != null, "%s has a scrolling box" % path)
		if sc == null:
			continue
		var bar := sc.get_v_scroll_bar()
		if bar.max_value <= bar.page + 1.0:
			continue
		var lab := _first_label(sc, sc.get_global_rect())
		check(lab != null, "%s: text to drag on" % path)
		if lab == null:
			continue
		check(lab.mouse_filter != Control.MOUSE_FILTER_STOP, "%s: its text lets the touch through" % path)
		var from: Vector2 = lab.get_meta("drag_at")
		await _drag(from, from - Vector2(0, 200))
		check(sc.scroll_vertical > 20, "%s scrolls when dragged on its text (%d)" % [path, sc.scroll_vertical])
	Game.delete_champ()


func _first_scroll(n: Node) -> ScrollContainer:
	if n is ScrollContainer and (n as ScrollContainer).is_visible_in_tree():
		return n
	for c in n.get_children():
		var f := _first_scroll(c)
		if f:
			return f
	return null


## A label or rich text in the lower part of the box, where a drag up has room.
func _first_label(n: Node, inside: Rect2) -> Control:
	if (n is Label or n is RichTextLabel) and (n as Control).is_visible_in_tree() and String(n.get("text")) != "":
		var r := (n as Control).get_global_rect()
		var band := Rect2(inside.position.x, inside.position.y + inside.size.y * 0.55, inside.size.x, inside.size.y * 0.4)
		if band.intersects(r):
			n.set_meta("drag_at", Vector2(r.get_center().x, clampf(r.get_center().y, band.position.y + 4, band.end.y - 4)))
			return n
	for c in n.get_children():
		var f := _first_label(c, inside)
		if f:
			return f
	return null


func _drag(from: Vector2, to: Vector2) -> void:
	_mouse(from, true)
	for i in 12:
		_move(from.lerp(to, float(i + 1) / 12.0))
		await frames(1)
	await frames(6)
	_mouse(to, false)
	await frames(2)


func _mouse(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = at
	e.global_position = at
	e.button_index = MOUSE_BUTTON_LEFT
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	e.pressed = down
	get_viewport().push_input(e)


func _move(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e)


# ---------------------------------------------------------------- the championship, results

func _championship() -> void:
	for team in ["KIL", "LAO", "CLA", "WEX", "DOW"]:
		var c: Championship = Game.new_champ(team)
		var guard := 0
		while c.phase != "done" and guard < 40:
			guard += 1
			# As the hub does: a round without your county (its bye, or out) is played on to your next game.
			c.play_byes()
			var f := c.next_fixture()
			if f.is_empty():
				check(c.phase == "done", "%s: never stuck without a game (%s, round %d)" % [team, c.phase, c.round])
				break
			var r := Sim.play(String(f.home), String(f.away), null, bool(f.knockout))
			c.record_user_result({"home": f.home, "away": f.away, "score": r.score, "winner": r.winner, "extra_time": r.extra_time,
				"shootout": {"goals": r.pens} if not (r.pens as Array).is_empty() else {}})
		check(c.phase == "done" and c.champion != "", "%s: the championship reaches a champion (%s)" % [team, c.champion])
		for g in c.groups:
			for row in c.table(g):
				check(int(row.p) == 4, "%s: each county plays four group games (%s %d)" % [team, row.id, int(row.p)])
				check(int(row.pts) == int(row.w) * 2 + int(row.d), "%s: two points a win, one a draw" % team)
		for f in c.fixtures:
			if bool(f.knockout):
				check(int(f.winner) >= 0, "%s: every knock-out game has a winner" % team)
		var ko := 0
		for f in c.fixtures:
			if bool(f.knockout):
				ko += 1
		check(ko == (7 if c.tier == 1 else 3), "%s: the knock-out games (%d)" % [team, ko])
		Game.save_champ()
		Game.champ = null
		var back = Game.get_champ()
		check(back != null and back.champion == c.champion and back.fixtures.size() == c.fixtures.size(), "%s: it saves and loads" % team)
	Game.delete_champ()


func _sim_scores() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var tot := 0
	var goals := 0
	for i in 200:
		var r := Sim.play("KIL", "COR", rng, i % 2 == 0)
		for k in 2:
			tot += Rules.total(r.score[k][0], r.score[k][1])
			goals += int(r.score[k][0])
		if i % 2 == 0:
			check(int(r.winner) >= 0, "Sim: a knock-out game has a winner")
	var avg := float(tot) / 400.0
	check(avg > 20.0 and avg < 34.0, "Sim: a side scores about 20-34 points' worth (%.1f)" % avg)
	check(float(goals) / 200.0 > 1.2 and float(goals) / 200.0 < 4.0, "Sim: about two or three goals a game (%.1f)" % (float(goals) / 200.0))


## The clock fitted to the match length: at the longest the ball live in real time (so the match scores as a real
## one, tests/score_check); shorter lengths faster, in proportion.
func _clock_lengths() -> void:
	var M: GDScript = load("res://game/match.gd")
	var full := 70.0 * 60.0
	check(M.live_clock_k(full, float(Game.LENGTHS[-1])) < 1.1, "Clock: at the longest length the ball is live at about real time")
	var last := 99.0
	for n in Game.LENGTHS:
		var k: float = M.live_clock_k(full, float(n))
		check(k >= 1.0 and k <= last, "Clock: %d min runs %.2fx, no faster than a shorter length" % [n, k])
		last = k
	check(M.live_clock_k(full, 8.0) > 3.0, "Clock: an 8-minute match runs the clock over 3x")
	# A real match has the ball in play about 38% of its time: what stoppages cost on the watch.
	check(is_equal_approx(M.LIVE_SHARE, 0.38), "Clock: the ball live 38% of the watch")
	check(float(M.STOP_COST.puck_out) >= 15.0 and float(M.STOP_COST.free) >= float(M.STOP_COST.puck_out), "Clock: a free costs more time than a puck-out")


## The coach's tips: each when it is needed, once.
func _coach() -> void:
	var none := {}
	check(Coach.pick({"taker": "puck_out"}, none) == "PUCK_OUT", "Coach: your puck-out")
	check(Coach.pick({"taker": "65"}, none) == "FREE", "Coach: your 65 is a free's tip")
	check(Coach.pick({"taker": "penalty"}, none) == "PENALTY", "Coach: your penalty")
	check(Coach.pick({"carrying": true, "in_hand": true, "buttons": ["STRIKE", "PASS", "SOLO"]}, none) == "IN_HAND", "Coach: the ball in your hand: the four steps")
	check(Coach.pick({"carrying": true, "in_hand": false, "buttons": ["STRIKE", "PASS", "HAND"], "goal_dist": 80.0}, none) == "ON_STICK", "Coach: on the hurley")
	check(Coach.pick({"carrying": true, "in_hand": false, "buttons": ["STRIKE", "PASS", "GOAL"], "goal_dist": 22.0}, none) == "GOAL", "Coach: close in, the goal")
	check(Coach.pick({"carrying": true, "goal_dist": 35.0}, {"ON_STICK": true}) == "SHOOT", "Coach: in range, the point")
	check(Coach.pick({"buttons": ["CATCH", "PULL", "SWITCH"]}, none) == "LOOSE", "Coach: the ball near you")
	check(Coach.pick({"buttons": ["TACKLE", "SWITCH"]}, {"MOVE": true}) == "TACKLE", "Coach: tackle")
	check(Coach.pick({"buttons": ["SWITCH"]}, none) == "MOVE", "Coach: first, how to run")
	check(Coach.pick({"buttons": ["SWITCH"], "ball_far": true, "live_s": 30.0}, {"MOVE": true}) == "SWITCH", "Coach: the ball far away: switch")
	check(Coach.pick({"buttons": ["SWITCH"], "ball_far": true, "live_s": 5.0}, {"MOVE": true}) == "", "Coach: not in the first seconds")
	var c := Coach.new()
	var st := {"buttons": ["SWITCH"]}
	check(c.step(0.1, st) == "MOVE", "Coach: a tip shows")
	check(c.step(0.1, st) == "", "Coach: one at a time")
	for i in 120:
		c.step(0.1, st)
	check(c.step(0.1, st) == "" and c.seen.has("MOVE"), "Coach: each tip once")
	check(c.event("STEPS") == "STEPS" and c.event("STEPS") == "", "Coach: the steps tip once, at once")
	for id in Coach.TIPS + ["STEPS", "INTRO"]:
		check(tr(Coach.text_key(id)) != Coach.text_key(id), "Coach: COACH_%s has words" % id)


## Substitutions: five, made at a break; not for a man sent off; the substitute takes the place in the shape.
func _subs() -> void:
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "KIL", "away": "COR", "venue": "county", "user_team": 0, "seed": 4, "length": 8.0, "mode": "test"}
	m.set_meta("test", true)
	add_child(m)
	await frames(3)
	var t: Dictionary = m.teams[0]
	var off: Player = m.player_by_num(0, 11)
	var pd: Dictionary = t.bench[0]
	var bench_n: int = t.bench.size()
	check(m.subs_left(0) == 5, "Subs: five a match")
	check(m.ask_sub(off, pd), "Subs: one asked for")
	check(not m.ask_sub(off, t.bench[1]), "Subs: not the same man twice")
	check(m.subs_left(0) == 4, "Subs: the one asked for counts")
	off.fatigue = 0.8
	m._run_subs()
	check(off.data.id == pd.id and off.pos_num == 11 and off.num == int(pd.num), "Subs: the substitute takes the place in the shape (%s, wearing %d)" % [off.data.id, off.num])
	check(off.fatigue == 0.0 and off.came_on == 1, "Subs: fresh legs")
	check(t.bench.size() == bench_n - 1 and int(t.subs) == 1, "Subs: off the bench, one made")
	var red: Player = m.player_by_num(0, 5)
	red.sent_off = true
	check(not m.sub_ok(red, t.bench[0]), "Subs: a man sent off is not replaced")
	red.sent_off = false
	for i in 4:
		m.ask_sub(m.player_by_num(0, 2 + i), t.bench[i])
	m._run_subs()
	check(m.subs_left(0) == 0 and not m.sub_ok(m.player_by_num(0, 13), t.bench[0]), "Subs: no sixth in normal time")
	m.half = 3
	check(m.subs_left(0) == 3, "Subs: three more in extra time")
	# The drop ring: a high ball coming down near your player is marked where it reaches hand height.
	var me: Player = m.player_by_num(0, 8)
	m.hud.set_active(me)
	m.ball.place(me.global_position)
	m.ball.global_position = me.global_position + Vector3(-25, 12, 0)
	m.ball.vel = Vector3(9, 4, 0)
	m.ball.state = Sliotar.FREE
	var drop: Vector3 = m.hud._drop_spot()
	var hit: Array = Sliotar.first_at_height(m.ball.global_position, m.ball.vel, m.CATCH_H)
	check(drop != Vector3.INF and not hit.is_empty() and Vector2(drop.x - hit[1].x, drop.z - hit[1].z).length() < 0.01, "Ball: a high ball is marked where it comes down")
	m.ball.global_position = me.global_position + Vector3(0, 1, 0)
	check(m.hud._drop_spot() == Vector3.INF, "Ball: no ring for a ball at hand height")
	# Tiredness: a sprint tires a man more than a walk, and a man with stamina less.
	var a := Player.new({"stamina": 90, "speed": 80}, 0, {})
	var b := Player.new({"stamina": 50, "speed": 80}, 0, {})
	for i in 300:
		a.want_vel = Vector3(8, 0, 0)
		b.want_vel = Vector3(8, 0, 0)
		a.integrate(1.0 / 30.0, 0.0)
		b.integrate(1.0 / 30.0, 0.0)
	check(a.fatigue > 0.0 and b.fatigue > a.fatigue * 1.2, "Tiredness: stamina tells (%.3f v %.3f)" % [a.fatigue, b.fatigue])
	check(a.top_speed() < Player.speed_of({"speed": 80}), "Tiredness: a tired man is slower")
	a.free()
	b.free()
	m.queue_free()
	await frames(2)


## Tactics: the sweeper sits in front of his full-back line marking no one; two inside sends the corner-forward out;
## the puck-out style changes how often it goes short.
func _tactics() -> void:
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "KIL", "away": "COR", "venue": "county", "user_team": -1, "seed": 6, "length": 8.0, "mode": "test",
		"tactics": [{"sweeper": true, "two_ff": true, "puckout": 0}, {"sweeper": false, "two_ff": false, "puckout": 2}]}
	m.set_meta("test", true)
	add_child(m)
	await frames(3)
	m.ball.place(Vector3.ZERO)
	var t: TeamAI = m.ai[0]
	var sw: Player = m.player_by_num(0, 12)
	var from_own := func(p: Vector3, k: int) -> float: return Pitch.HALF_L + p.x * m.dir(k)
	var sx: float = from_own.call(t.home_spot(sw), 0)
	var fb: float = from_own.call(t.home_spot(m.player_by_num(0, 3)), 0)
	var hb: float = from_own.call(t.home_spot(m.player_by_num(0, 6)), 0)
	check(sx > fb and sx < hb and t.mark_of(sw) == null, "Tactics: the sweeper between his full-backs (%.0f m) and half-backs (%.0f m), at %.0f m, marking no one" % [fb, hb, sx])
	var out13: float = from_own.call(t.home_spot(m.player_by_num(0, 13)), 0)
	var in14: float = from_own.call(t.home_spot(m.player_by_num(0, 14)), 0)
	check(in14 - out13 > 15.0, "Tactics: two inside, the corner-forward out the field (%.0f m behind the full-forward)" % (in14 - out13))
	var u: TeamAI = m.ai[1]
	check(u.mark_of(m.player_by_num(1, 12)) != null and absf(from_own.call(u.home_spot(m.player_by_num(1, 13)), 1) - from_own.call(u.home_spot(m.player_by_num(1, 14)), 1)) < 6.0, "Tactics: without them, the lines as usual")
	var shorts := [0, 0]
	for k in 2:
		for i in 200:
			if String(m.ai[k].puck_out_choice(m.player_by_num(k, 1)).kind) == "short":
				shorts[k] += 1
	check(shorts[0] > shorts[1] * 2, "Tactics: short puck-outs go short more than long ones (%d v %d in 200)" % shorts)
	m.queue_free()
	await frames(2)


## What the browser playtest found (docs/PLAYTEST.md), each held to its fix.
func _playtest_fixes() -> void:
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "KIL", "away": "TIP", "venue": "parish", "user_team": 0, "seed": 8, "length": 8.0, "mode": "test"}
	add_child(m)
	await frames(3)
	var keep: Dictionary = Game.settings.duplicate(true)
	# The coach's card never covers a button: every size, either hand, the most buttons there are.
	m.controls.set_buttons(["STRIKE", "PASS", "SOLO", "GOAL", "SWITCH"])
	var clear := true
	for lh in [false, true]:
		for size in 3:
			Game.settings.left_handed = lh
			Game.settings.btn_size = size
			m.hud.coach("SHOOT")
			await frames(2)
			var card: Rect2 = m.hud._coach.get_global_rect()
			for b in m.controls._layout():
				var c: Vector2 = b[1]
				var r: float = b[2]
				var near := Vector2(clampf(c.x, card.position.x, card.end.x), clampf(c.y, card.position.y, card.end.y))
				if near.distance_to(c) < r:
					clear = false
	check(clear, "Playtest: the coach's card clear of every button (each size, either hand)")
	Game.settings.left_handed = keep.left_handed
	Game.settings.btn_size = keep.btn_size
	# Your pass goes to the free man the way you point, not the marked one straight ahead.
	var me: Player = m.player_by_num(0, 6)
	var d: float = m.dir(0)
	for q in m.all_players():
		(q as Player).global_position = Vector3(0, 0, 60)    # everyone out of the way
	me.global_position = Vector3(0, 0, 0)
	var marked: Player = m.player_by_num(0, 11)
	var free: Player = m.player_by_num(0, 12)
	marked.global_position = Vector3(d * 30.0, 0, 0)
	free.global_position = Vector3(d * 26.0, 0, 14.0)
	m.player_by_num(1, 6).global_position = Vector3(d * 29.0, 0, 0.8)     # his marker, tight
	m.player_by_num(1, 7).global_position = Vector3(d * 15.0, 0, 0.3)     # and one in the lane
	var j: Vector2 = Vector2.ZERO
	for i in 64:
		var a := TAU * i / 64.0
		var cand := Vector2(cos(a), sin(a))
		if m._cam_dir(cand).dot(Vector3(d, 0, 0)) > 0.99:
			j = cand
	check(m._pass_option(me, j) == free, "Playtest: PASS toward goal finds the free man, not the marked one straight ahead")
	TouchControls.touch_seen = false
	var t := InputEventScreenTouch.new()
	t.position = Vector2(900, 300)
	t.pressed = true
	m.controls._input(t)
	t.pressed = false
	m.controls._input(t)
	check(TouchControls.touch_seen, "Playtest: no keyboard hints on the buttons once the screen is touched")
	TouchControls.touch_seen = false
	m.queue_free()
	await frames(2)
	# No floodlight mast between the television gantry and the field.
	var in_way := 0
	var brown := 0
	for id in DB.VENUES:
		var st := Stadium.new(String(id), [Color.WHITE, Color.BLACK])
		add_child(st)
		await frames(1)
		for p in st.mast_spots:
			if p.z > 0.0 and p.z < CameraRig.GANTRY_Z:
				in_way += 1
		var we: WorldEnvironment = st.find_children("*", "WorldEnvironment", true, false)[0]
		# A photographed sky (its horizon's own haze below the skyline), never the engine's default brown ground.
		var sm := we.environment.sky.sky_material
		if not (sm is PanoramaSkyMaterial and (sm as PanoramaSkyMaterial).panorama != null):
			brown += 1
		st.queue_free()
	check(in_way == 0, "Playtest: no floodlight mast in front of the camera (%d)" % in_way)
	check(brown == 0, "Playtest: past the fields, a real sky's horizon, not the sky's default brown (%d grounds)" % brown)
	# On a touch screen a button looks the same hovered as not (a finger leaves the emulated mouse where it lifts).
	var th: Theme = Game.theme.duplicate()
	Game.flatten_hover(th)
	check(th.get_stylebox("hover", "ChipButton") == th.get_stylebox("normal", "ChipButton") and th.get_stylebox("hover", "Button") == th.get_stylebox("normal", "Button"), "Playtest: no hover look on a touch screen")
	# Match setup remembers the ground.
	Game.settings.venue = "stadium"
	var q: Control = load("res://ui/quick_setup.gd").new()
	add_child(q)
	await frames(2)
	check(String(q._venue) == "stadium", "Playtest: match setup remembers the ground")
	q.queue_free()
	Game.settings = keep
	await frames(1)


## Over the end line the ball flies on into a net and drops (round three: it used to stop dead in the air).
func _nets() -> void:
	var b := Sliotar.new()
	add_child(b)
	await frames(1)
	b.backstop = Vector3(9.0, 24.0, 14.0)
	# A wide, high and hard: it reaches the ball-stop net and no further.
	b.place(Vector3(Pitch.HALF_L - 30.0, 0, 15.0))
	b.global_position = Vector3(Pitch.HALF_L - 30.0, 1.0, 15.0)
	b.launch(Vector3(32.0, 9.0, 3.0), null, "strike")
	for i in 240:
		b.step(1.0 / 60.0)
		if b.global_position.x > Pitch.HALF_L and b.state == Sliotar.FREE:
			b.state = Sliotar.OUT
	check(b.global_position.x <= Pitch.HALF_L + 9.05 and b.global_position.x > Pitch.HALF_L + 5.0 and b.global_position.y < 0.5, "Nets: a wide flies on into the ball-stop net and drops (%.1f m behind, %.1f m up)" % [b.global_position.x - Pitch.HALF_L, b.global_position.y])
	# A goal: it stops in the goal's net.
	b.place(Vector3(Pitch.HALF_L - 12.0, 0, 0))
	b.global_position = Vector3(Pitch.HALF_L - 12.0, 0.8, 0.5)
	b.launch(Vector3(34.0, 0.6, 0.0), null, "strike")
	for i in 180:
		b.step(1.0 / 60.0)
		if b.global_position.x > Pitch.HALF_L and b.state == Sliotar.FREE:
			b.state = Sliotar.OUT
	check(b.global_position.x <= Pitch.HALF_L + Pitch.NET_DEPTH + 0.05 and b.global_position.x > Pitch.HALF_L, "Nets: a goal stays in the net (%.2f m behind the line)" % (b.global_position.x - Pitch.HALF_L))
	b.queue_free()
	await frames(1)


# ---------------------------------------------------------------- the grounds' surrounds

## Every ground dressed from the shared assets: trees and hedgerows round it, the parish field's village and lough,
## the towns round the county ground and the stadium; nothing of it on the field or in the camera's foreground; a
## real sky; one draw call a kind of thing, so the surrounds stay a dozen draws at most.
func _scenery() -> void:
	var keep := int(Game.settings.graphics)
	Game.settings.graphics = Game.GFX_LOW
	for v in ["parish", "county", "stadium", "night"]:
		var st := Stadium.new(v)
		add_child(st)
		await frames(1)
		var sc: Scenery = st.scenery
		var trees := sc.count("oak_tree_card") + sc.count("broadleaf_tree_dark_card")
		check(trees >= 20 and sc.count("small_broadleaf_card") >= 100, "Scenery %s: trees (%d) and hedgerows (%d bushes)" % [v, trees, sc.count("small_broadleaf_card")])
		if v == "parish":
			check(sc.count("thatched_cottage_low") >= 3 and sc.count("mossy_rocks_low") > 0 and sc.count("painted_bench_low") > 0, "Scenery parish: the village, the stone wall, the subs' benches")
			var through := 0
			for name in ["small_broadleaf_card", "grass_wispy_card", "grass_clumps_card", "fern_card"]:
				for t: Transform3D in sc.placed(name):
					if Stadium.VILLAGE.has_point(Vector2(t.origin.x, t.origin.z)):
						through += 1
			check(through == 0, "Scenery parish: no hedgerow through the village's houses (%d)" % through)
		else:
			check(sc.count("terrace_row_low") >= 8 and sc.count("street_lamp_tall_low") > 0, "Scenery %s: the town's terraced rows and street lamps" % v)
		var bad := 0
		for name in sc.names():
			for t: Transform3D in sc.placed(name):
				var o := t.origin
				var on_field := absf(o.x) < Pitch.HALF_L + 1.0 and absf(o.z) < Pitch.HALF_W + 1.0
				var foreground := o.z > Pitch.HALF_W + 3.0 and o.z < CameraRig.GANTRY_Z and absf(o.x) < Pitch.HALF_L
				if on_field or foreground:
					bad += 1
					if bad < 4:
						print("  ", v, " ", name, " at ", o)
		check(bad == 0, "Scenery %s: nothing on the field or in front of the camera (%d)" % [v, bad])
		check(sc.get_child_count() <= 12, "Scenery %s: %d draw calls" % [v, sc.get_child_count()])
		# The crowd faces the play: every spectator toward the centre of the field; from the television gantry (behind
		# the near stand) the near stand is seen from behind, the far one from the front (round four: "the crowd to the
		# near side is looking the wrong direction").
		var cr: Crowd = st.crowd
		var wrong := 0
		var near_back := 0
		var near := 0
		var far_front := 0
		var far := 0
		var gantry := Vector3(0.0, CameraRig.GANTRY_H, CameraRig.GANTRY_Z)
		for i in cr.spots.size():
			var sp: Vector3 = cr.spots[i]
			var f: Vector3 = cr.facings[i]
			if f.dot(Vector3(-sp.x, 0.0, -sp.z).normalized()) <= 0.7:
				wrong += 1
			# Opposite the gantry (people further along face the centre at an angle, so a camera at halfway is in front).
			if sp.z > Pitch.HALF_W and absf(sp.x) < 20.0:
				near += 1
				near_back += 1 if Crowd.seen_from_behind(sp, f, gantry) else 0
			elif sp.z < -Pitch.HALF_W and absf(sp.x) < 20.0:
				far += 1
				far_front += 0 if Crowd.seen_from_behind(sp, f, gantry) else 1
		check(cr.spots.size() > 0 and wrong == 0, "Crowd %s: all %d face the field (%d do not)" % [v, cr.spots.size(), wrong])
		check(near > 0 and near_back == near and far_front == far, "Crowd %s: from the gantry the near side's %d seen from behind, the far side's %d from the front" % [v, near, far])
		var we: WorldEnvironment = st.find_children("*", "WorldEnvironment", false, false)[0]
		check(we.environment.sky.sky_material is PanoramaSkyMaterial, "Scenery %s: a real sky (%s)" % [v, st.sky_name()])
		st.queue_free()
		await frames(1)
	Game.settings.graphics = keep


# ---------------------------------------------------------------- the owner's model, its clips, the replay

## The owner's player model as baked for phones (tools/player): small enough, on the game's seventeen bones; the
## Mixamo clips in step with the game: the sprint's left thigh forward at the stride's phase pi/2, the swing's bas
## coming past the striker the way he faces at the moment of contact.
func _hero_body() -> void:
	var hi: ArrayMesh = load("res://assets/player/hero_hi.res")
	var lo: ArrayMesh = load("res://assets/player/hero_lo.res")
	var tris_hi := hi.surface_get_array_index_len(0) / 3
	var tris_lo := lo.surface_get_array_index_len(0) / 3
	check(tris_hi <= 6500 and tris_lo <= 2000, "Player model: %d triangles (%d on Low)" % [tris_hi, tris_lo])
	var tex: Texture2D = load("res://assets/player/hero_albedo.jpg")
	check(tex.get_width() <= 1024 and tex.get_height() <= 1024, "Player model: its texture at most 1024 square")
	var pl := Player.new({"num": 9, "line": 4, "speed": 70}, 0, {"jersey": Color("c8202f"), "trim": Color.WHITE, "kind": "player"})
	add_child(pl)
	await frames(1)
	check(pl.body is HeroBody and pl.body.skeleton.get_bone_count() == ToonBody.BONES.size(), "A hurler is drawn with the owner's model, on the game's bones")
	var ref := Player.new({}, -1, {"kind": "referee"}, "referee")
	add_child(ref)
	await frames(1)
	check(not (ref.body is HeroBody), "An official keeps the cel-shaded figure")
	# The sprint: at full speed, phase pi/2, the left thigh swung forward and the right back.
	pl.vel = Vector3(0, 0, 7.5)
	pl._ph = PI * 0.5
	var p: Dictionary = pl._pose(0.0)
	var lt := HeroBody.turn(p.thigh_l) * Vector3.DOWN
	var rt := HeroBody.turn(p.thigh_r) * Vector3.DOWN
	check(lt.z > 0.25 and rt.z < lt.z, "The sprint clip: the left thigh forward at the stride's phase pi/2 (%.2f, the right %.2f)" % [lt.z, rt.z])
	# The swings: at the contact time the bas comes past him going the way he faces (where the ball goes), within
	# his reach, below the shoulder.
	pl.vel = Vector3.ZERO
	pl.yaw = 0.0
	pl.body.rotation.y = 0.0
	for a in ["strike", "ground", "pull"]:
		pl.play(a)
		var at := []
		for dt in [-0.02, 0.0, 0.02]:
			pl.action_t = pl.contact_time(a) + dt
			pl.animate(0.0)
			at.append(pl.body.bas_world() - pl.global_position)
		var mv: Vector3 = at[2] - at[0]
		var bas: Vector3 = at[1]
		var ok := mv.z > absf(mv.x) and bas.z > -0.5 and Vector2(bas.x, bas.z).length() < 1.9 and bas.y < 1.7 * Player.DRAW_SCALE
		check(ok, "The %s clip: the bas comes past him going forward at contact (at %.2f across, %.2f forward, %.2f up; moving %.2f across, %.2f forward)" % [a, bas.x, bas.z, bas.y, mv.x, mv.z])
	pl.queue_free()
	ref.queue_free()
	await frames(1)


## A wide shown again: from its own camera, the HUD's tag and tap-to-skip up, the controls hidden; at its end (or a
## tap) everyone and the ball back where they were, the match camera and the controls back.
func _replay() -> void:
	Game.settings.coach = false
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "KIL", "away": "WEX", "venue": "county", "user_team": 0, "seed": 3, "length": 4.0, "mode": "test"}
	m.set_meta("test", true)
	add_child(m)
	await frames(200)
	var before := {}
	for pl in m.all_players():
		before[pl] = (pl as Player).position
	var ball0: Vector3 = m.ball.global_position
	m.replay.start(m.now - 1.0, 1.0, Vector3(Pitch.HALF_L, 2.0, 9.0))
	check(m.replay.playing and not m.controls.visible and m.hud._replay != null and not m.cam.camera.current, "Replay: its own camera, the tag and tap-to-skip, no controls")
	var n := 0
	var moved := false
	while m.replay.playing and n < 400:
		await frames(1)
		n += 1
		if n == 20:
			for pl in m.all_players():
				moved = moved or (pl as Player).position.distance_to(before[pl]) > 0.3
	check(n > 60 and n < 300 and moved, "Replay: plays the last seconds again (%d frames)" % n)
	var back := true
	for pl in m.all_players():
		back = back and (pl as Player).position.distance_to(before[pl]) < 0.001
	check(back and m.ball.global_position.distance_to(ball0) < 0.001, "Replay: everyone and the ball back where they were")
	check(m.controls.visible and m.hud._replay == null and m.cam.camera.current, "Replay: the match camera and the controls back")
	m.replay.start(m.now - 1.0, -1.0, Vector3(-Pitch.HALF_L, 2.0, -9.0))
	await frames(5)
	m.replay.stop()
	check(not m.replay.playing and m.controls.visible, "Replay: a tap skips it")
	m.queue_free()
	await frames(2)
	# Watching a match (no side yours): nothing kept for a replay, the scoreboard still running.
	var w: Node = load("res://game/match.gd").new()
	w.config = {"home": "KIL", "away": "WEX", "venue": "county", "user_team": -1, "seed": 3, "length": 4.0, "mode": "test"}
	add_child(w)
	await frames(30)
	check(w.replay._buf.is_empty() and w.hud._half.text != "", "Watching a match: no replay kept, the scoreboard ticking")
	w.queue_free()
	await frames(2)


# ---------------------------------------------------------------- a match, and the movement audit

## An AI match at the shortest length plays to full time with a legal score; every frame, no player moves further
## than his top speed allows (nothing snaps), his speed changes no faster than his acceleration, and his strides
## (counted steps) match how far he ran.
func _match_and_motion() -> void:
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "CLA", "away": "GAL", "venue": "parish", "user_team": -1, "seed": 9, "length": 4.0, "mode": "test"}
	add_child(m)
	await frames(2)
	var last := {}
	var lastv := {}
	var worst_jump := 0.0
	var worst_acc := 0.0
	var dist := 0.0
	var steps := 0
	var probe: Player = m.player_by_num(0, 8)
	var came := {}
	var guard := 0
	while m.phase != m.P.OVER and guard < 30 * 60 * 14:
		await get_tree().process_frame
		guard += 1
		var dt := 1.0 / 30.0
		for p in m.all_players():
			var pl: Player = p
			if not pl.visible:
				continue
			var pos := pl.global_position
			if came.get(pl, 0) != pl.came_on:
				# A substitute has taken this place: he comes on from the line.
				came[pl] = pl.came_on
				last.erase(pl)
			if last.has(pl) and m.phase != m.P.HALF_TIME and m.phase != m.P.INTRO:
				var d: float = pos.distance_to(last[pl])
				worst_jump = maxf(worst_jump, d / (dt * pl.max_speed * 1.25))
				var dv: float = (pl.vel - (lastv[pl] as Vector3)).length()
				worst_acc = maxf(worst_acc, dv / (dt * maxf(Player.ACCEL, Player.DECEL) * 1.6))
			if pl == probe and last.has(pl):
				dist += pos.distance_to(last[pl])
			last[pl] = pos
			lastv[pl] = pl.vel
		steps += probe.steps_taken
		probe.steps_taken = 0
	check(m.phase == m.P.OVER, "Match: an AI match reaches full time (%d frames)" % guard)
	var s: Array = m.score
	check(int(s[0][0]) >= 0 and int(s[0][1]) >= 0 and int(s[0][0]) + int(s[0][1]) + int(s[1][0]) + int(s[1][1]) > 0, "Match: there are scores (%s v %s)" % [Rules.fmt(s[0][0], s[0][1]), Rules.fmt(s[1][0], s[1][1])])
	check(worst_jump <= 1.0, "Motion: no player moves faster than his top speed in a frame (worst %.2f of the limit)" % worst_jump)
	check(worst_acc <= 1.0, "Motion: speed changes no faster than a player accelerates (worst %.2f of the limit)" % worst_acc)
	var stride := dist / maxf(1.0, float(steps))
	check(steps > 50 and stride > 0.6 and stride < 2.3, "Motion: strides match the ground covered (%.2f m a step, %d steps)" % [stride, steps])
	for k in 2:
		check(int(m.teams[k].subs) <= Rules.subs_allowed(false), "Subs: the manager makes no more than five (%d)" % int(m.teams[k].subs))
	check(int(m.teams[0].subs) + int(m.teams[1].subs) > 0, "Subs: the managers bring on fresh legs in the second half")
	m.queue_free()
	await frames(2)
